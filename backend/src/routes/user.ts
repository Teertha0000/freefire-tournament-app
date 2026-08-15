import { Router } from 'express';
import { supabaseAdmin } from '../supabaseClient';
import { requireAuth } from '../middleware';

export const userRoutes = Router();

// 1. Update Profile (Since RLS blocks direct DB writes from mobile app)
userRoutes.post('/update-profile', requireAuth, async (req: any, res: any) => {
    const userId = req.user.sub;
    const { ign, uid, phone, referral_code } = req.body;

    try {
        let referredById = null;
        
        // If they provided a referral code, look up the user who owns it
        if (referral_code && referral_code.trim() !== '') {
            const { data: refUser } = await supabaseAdmin
                .from('users')
                .select('id')
                .eq('referral_code', referral_code.trim())
                .single();
                
            if (refUser) {
                referredById = refUser.id;
            }
        }

        // Update the profile fields (ign, uid, phone) and optionally referred_by
        const updateData: any = { ign, uid, phone };
        if (referredById) {
            updateData.referred_by = referredById;
        }

        const { error } = await supabaseAdmin
            .from('users')
            .update(updateData)
            .eq('id', userId);

        if (error) throw error;
        res.status(200).json({ message: 'Profile updated successfully.' });
    } catch (err: any) {
        console.error('Update profile error:', err);
        res.status(500).json({ error: 'Failed to update profile.' });
    }
});
// 2. Fetch Profile
userRoutes.get('/profile', requireAuth, async (req: any, res: any) => {
    const userId = req.user.sub || req.user.id;
    console.log(`[USER] Fetching profile for: ${userId} (from token: ${JSON.stringify(req.user)})`);
    try {
        const { data, error } = await supabaseAdmin.from('users').select('*').eq('id', userId).single();
        if (error) throw error;
        res.status(200).json(data);
    } catch (err: any) {
        console.error('Fetch profile error:', err);
        res.status(500).json({ error: 'Failed to fetch profile' });
    }
});

// 3. Fetch Transactions
userRoutes.get('/transactions', requireAuth, async (req: any, res: any) => {
    const userId = req.user.sub || req.user.id;
    console.log(`[USER] Fetching transactions for: ${userId}`);
    try {
        const { data, error } = await supabaseAdmin.from('transactions').select('*').eq('user_id', userId).order('created_at', { ascending: false });
        if (error) throw error;
        res.status(200).json(data);
    } catch (err: any) {
        console.error('Fetch transactions error:', err);
        res.status(500).json({ error: 'Failed to fetch transactions' });
    }
});
