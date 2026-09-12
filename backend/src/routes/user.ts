import { Router } from 'express';
import { supabaseAdmin } from '../supabaseClient';
import { requireAuth } from '../middleware';

export const userRoutes = Router();

// 1. Update Profile (Since RLS blocks direct DB writes from mobile app)
userRoutes.post('/update-profile', requireAuth, async (req: any, res: any) => {
    const userId = req.user.sub;
    const { ign, uid, phone, referral_code, payment_method, avatar_id } = req.body;

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

        // Update the profile fields (ign, uid, phone, payment_method, avatar_id) and optionally referred_by
        const updateData: any = { 
            ign, 
            uid, 
            phone,
            payment_method: payment_method || 'bKash', // Default fallback
            avatar_id: avatar_id || 'avatar_1'
        };
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

// 1b. Upload Avatar Image (Bypasses Storage RLS)
userRoutes.post('/upload-avatar', requireAuth, async (req: any, res: any) => {
    const userId = req.user.sub || req.user.id;
    const { image_base64, file_ext } = req.body;

    if (!image_base64) {
        return res.status(400).json({ error: 'No image data provided.' });
    }

    try {
        const ext = file_ext || 'jpg';
        const fileName = `${userId}_${Date.now()}.${ext}`;
        const buffer = Buffer.from(image_base64, 'base64');

        const { error } = await supabaseAdmin.storage
            .from('avatars')
            .upload(fileName, buffer, {
                contentType: `image/${ext === 'png' ? 'png' : 'jpeg'}`,
                upsert: true,
            });

        if (error) throw error;

        const { data: urlData } = supabaseAdmin.storage.from('avatars').getPublicUrl(fileName);
        res.status(200).json({ publicUrl: urlData.publicUrl });
    } catch (err: any) {
        console.error('Avatar upload error:', err);
        res.status(500).json({ error: 'Failed to upload avatar: ' + (err.message || err) });
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
// 4. Submit Dispute
userRoutes.post('/disputes', requireAuth, async (req: any, res: any) => {
    const userId = req.user.sub || req.user.id;
    const { match_id, message } = req.body;
    
    if (!match_id || !message) {
        return res.status(400).json({ error: 'match_id and message are required' });
    }

    try {
        const { error } = await supabaseAdmin.from('disputes').insert({
            user_id: userId,
            match_id,
            message,
            status: 'pending'
        });

        if (error) throw error;
        res.status(200).json({ message: 'Dispute submitted successfully. We will investigate shortly.' });
    } catch (err: any) {
        console.error('Submit dispute error:', err);
        res.status(500).json({ error: 'Failed to submit dispute.' });
    }
});
