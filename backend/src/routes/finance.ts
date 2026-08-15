import { Router } from 'express';
import { supabaseAdmin } from '../supabaseClient';
import { requireAuth } from '../middleware';

export const financeRoutes = Router();

// 1. Request a Withdrawal
financeRoutes.post('/withdraw', requireAuth, async (req: any, res: any) => {
    const userId = req.user.sub;
    const { amount, payment_method, phone_number } = req.body;

    if (amount < 50) return res.status(400).json({ error: 'Minimum withdrawal is 50 Tk.' });

    try {
        // Fetch current balance
        const { data: user, error: userError } = await supabaseAdmin
            .from('users')
            .select('withdrawable_balance')
            .eq('id', userId)
            .single();

        if (userError || !user) return res.status(404).json({ error: 'User not found' });

        if (user.withdrawable_balance < amount) {
            return res.status(400).json({ error: 'Insufficient withdrawable balance.' });
        }

        // Deduct balance instantly to prevent double-withdrawals
        await supabaseAdmin.rpc('adjust_balance', { p_user_id: userId, p_amount: -amount, p_balance_type: 'withdrawable' });

        // Create pending withdrawal request
        const { error: withdrawError } = await supabaseAdmin.from('withdrawals').insert({
            user_id: userId,
            amount: amount,
            payment_method: payment_method,
            phone_number: phone_number,
            status: 'pending'
        });

        if (withdrawError) throw withdrawError;

        // Log transaction
        await supabaseAdmin.from('transactions').insert({
            user_id: userId,
            amount: -amount,
            type: 'withdrawal',
            description: `Requested Withdrawal via ${payment_method}`
        });

        res.status(200).json({ message: 'Withdrawal request submitted successfully.' });
    } catch (err: any) {
        console.error('Withdrawal Error:', err);
        res.status(500).json({ error: 'Failed to process withdrawal request.' });
    }
});

// 2. Initialize a Deposit via Paymently
financeRoutes.post('/deposit/create', requireAuth, async (req: any, res: any) => {
    const userId = req.user.sub;
    const { amount } = req.body;

    if (amount < 10) return res.status(400).json({ error: 'Minimum deposit is 10 Tk.' });

    try {
        // We need the user's details for Paymently
        const { data: user, error: userError } = await supabaseAdmin
            .from('users')
            .select('ign, email, phone')
            .eq('id', userId)
            .single();

        if (userError || !user) return res.status(404).json({ error: 'User not found' });

        const orderId = `DEP-${userId.substring(0, 8)}-${Date.now()}`;
        
        // Ensure env variables exist
        const baseUrl = process.env.PAYMENTLY_BASE_URL;
        const apiKey = process.env.PAYMENTLY_API_KEY;
        
        if (!baseUrl || !apiKey) {
            console.error('Paymently credentials missing in .env');
            return res.status(500).json({ error: 'Payment gateway not configured' });
        }

        const response = await fetch(`${baseUrl}/api/checkout/redirect`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'MHS-PAYMENTLY-API-KEY': apiKey
            },
            body: JSON.stringify({
                full_name: user.ign || 'FreeFire Player',
                email_address: user.email || 'player@teertha.space',
                mobile_number: user.phone || '01700000000',
                amount: amount,
                currency: 'BDT',
                return_url: 'https://payment-successful', // This won't actually be loaded by the user directly; the webview will catch it
                webhook_url: `https://api.teertha.space/finance/deposit/webhook`,
                metadata: {
                    user_id: userId,
                    order_id: orderId
                }
            })
        });

        const result = await response.json();

        if (result.error) {
            console.error("Paymently error:", result.error);
            return res.status(400).json({ error: result.error.message || 'Paymently API failed' });
        }

        // Result will contain pp_url and pp_id
        res.status(200).json({ 
            payment_url: result.pp_url, 
            payment_id: result.pp_id 
        });

    } catch (err: any) {
        console.error('Deposit Init Error:', err);
        res.status(500).json({ error: 'Failed to initialize deposit.' });
    }
});

// 3. Paymently Webhook (Receives notification on successful payment)
financeRoutes.post('/deposit/webhook', async (req: any, res: any) => {
    // Note: Webhook is NOT authenticated via requireAuth. It comes from Paymently servers.
    const { pp_id, metadata } = req.body;

    if (!pp_id || !metadata || !metadata.user_id) {
        return res.status(400).json({ error: 'Invalid webhook payload' });
    }

    try {
        const userId = metadata.user_id;
        const referenceId = pp_id;

        // Idempotency check: has this transaction been processed?
        const { data: existingTx } = await supabaseAdmin
            .from('transactions')
            .select('id')
            .eq('reference_id', referenceId)
            .single();

        if (existingTx) {
            // Already processed!
            return res.status(200).json({ received: true, note: 'Already processed' });
        }

        // Verify the payment securely with Paymently
        const baseUrl = process.env.PAYMENTLY_BASE_URL;
        const apiKey = process.env.PAYMENTLY_API_KEY;

        const verifyRes = await fetch(`${baseUrl}/api/verify-payment`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'MHS-PAYMENTLY-API-KEY': apiKey!
            },
            body: JSON.stringify({ pp_id })
        });

        const payment = await verifyRes.json();

        if (payment.status === 'completed') {
            // Give them the local net amount (or original amount)
            const amountAdded = parseFloat(payment.amount);

            // Add to withdrawable balance (as requested)
            await supabaseAdmin.rpc('adjust_balance', { 
                p_user_id: userId, 
                p_amount: amountAdded, 
                p_balance_type: 'withdrawable' 
            });

            // Log transaction
            await supabaseAdmin.from('transactions').insert({
                user_id: userId,
                amount: amountAdded,
                type: 'deposit',
                reference_id: referenceId,
                description: `Deposit via ${payment.gateway || 'Paymently'}`
            });

            return res.status(200).json({ received: true });
        } else {
            console.error("Paymently webhook arrived but verify said status was:", payment.status);
            return res.status(200).json({ received: true, note: 'Not completed' });
        }
    } catch (err: any) {
        console.error('Webhook Error:', err);
        res.status(500).json({ error: 'Webhook processing failed' });
    }
});
