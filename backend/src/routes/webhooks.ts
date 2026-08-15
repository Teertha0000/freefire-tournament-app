import { Router } from 'express';
import { supabaseAdmin } from '../supabaseClient';
import crypto from 'crypto';

export const webhookRoutes = Router();

// Paymently Webhook Endpoint
webhookRoutes.post('/paymently', async (req, res) => {
    // 1. Verify the signature (Security to ensure it actually comes from Paymently)
    const signature = req.headers['x-paymently-signature'];
    const payload = JSON.stringify(req.body);
    const secret = process.env.PAYMENTLY_WEBHOOK_SECRET || 'test_secret';

    const expectedSignature = crypto.createHmac('sha256', secret).update(payload).digest('hex');
    
    // NOTE: Enabled for production
    if (signature !== expectedSignature) {
       return res.status(401).json({ error: 'Invalid signature. Hacker attempt blocked.' });
    }

    const { transaction_id, status, amount, metadata } = req.body;
    
    // We expect the Flutter app to send the user_id inside the Paymently metadata field
    const userId = metadata?.user_id;

    if (status !== 'successful') {
        return res.status(200).json({ message: 'Ignored non-successful payment.' });
    }

    try {
        // 1. Check if transaction already exists (Idempotency - prevents double crediting)
        const { data: existingTx } = await supabaseAdmin
            .from('transactions')
            .select('id')
            .eq('reference_id', transaction_id)
            .single();

        if (existingTx) {
            return res.status(200).json({ message: 'Transaction already processed.' });
        }

        // 2. Log it securely in the Ledger
        const { error: txError } = await supabaseAdmin.from('transactions').insert({
            user_id: userId,
            amount: amount,
            type: 'deposit',
            reference_id: transaction_id,
            description: 'Deposit via Paymently'
        });

        if (txError) throw txError;

        // 3. Update the user's wallet using atomic RPC
        await supabaseAdmin.rpc('adjust_balance', { p_user_id: userId, p_amount: amount, p_balance_type: 'withdrawable' });

        res.status(200).json({ message: 'Deposit successful! User wallet credited.' });
    } catch (err) {
        console.error('Webhook Error:', err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});
