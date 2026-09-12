import { Router } from 'express';
import { supabaseAdmin } from '../supabaseClient';
import { requireAuth as authenticate } from '../middleware';

export const challengeRoutes = Router();

// ==========================================
// 1. GET LIVE CHALLENGES (Lobby Feed)
// ==========================================
challengeRoutes.get('/live', async (req, res) => {
    try {
        const { data, error } = await supabaseAdmin
            .from('challenges')
            .select(`
                *,
                host:users!host_id(id, ign, phone, avatar_id),
                opponent:users!opponent_id(id, ign, phone, avatar_id)
            `)
            .in('status', ['open', 'room_setup', 'ongoing', 'claimed'])
            .order('created_at', { ascending: false })
            .limit(50);

        if (error) throw error;
        res.status(200).json(data || []);
    } catch (e: any) {
        res.status(500).json({ error: e.message });
    }
});

// ==========================================
// 2. GET MY CHALLENGES
// ==========================================
challengeRoutes.get('/my', authenticate, async (req: any, res: any) => {
    const userId = req.user.sub || req.user.id;
    try {
        const { data, error } = await supabaseAdmin
            .from('challenges')
            .select(`
                *,
                host:users!host_id(id, ign, phone, avatar_id),
                opponent:users!opponent_id(id, ign, phone, avatar_id)
            `)
            .or(`host_id.eq.${userId},opponent_id.eq.${userId}`)
            .order('created_at', { ascending: false });

        if (error) throw error;
        res.status(200).json(data || []);
    } catch (e: any) {
        res.status(500).json({ error: e.message });
    }
});

// ==========================================
// 3. GET SINGLE CHALLENGE DETAILS
// ==========================================
challengeRoutes.get('/:id', authenticate, async (req: any, res: any) => {
    const { id } = req.params;
    try {
        const { data, error } = await supabaseAdmin
            .from('challenges')
            .select(`
                *,
                host:users!host_id(id, ign, phone, avatar_id),
                opponent:users!opponent_id(id, ign, phone, avatar_id),
                claimed_winner:users!claimed_winner_id(id, ign),
                winner:users!winner_id(id, ign)
            `)
            .eq('id', id)
            .single();

        if (error) throw error;
        res.status(200).json(data);
    } catch (e: any) {
        res.status(500).json({ error: e.message });
    }
});

// ==========================================
// 4. CREATE CHALLENGE
// ==========================================
challengeRoutes.post('/create', authenticate, async (req: any, res: any) => {
    const userId = req.user.sub || req.user.id;
    const { stake, mode = '1v1_cs', map = 'Bermuda', rules = {} } = req.body;

    const numericStake = parseFloat(stake);
    if (isNaN(numericStake) || numericStake < 10) {
        return res.status(400).json({ error: 'Minimum stake is 10 Tk.' });
    }

    try {
        const { data, error } = await supabaseAdmin.rpc('p2p_create_challenge', {
            p_host_id: userId,
            p_stake: numericStake,
            p_mode: mode,
            p_map: map,
            p_rules: rules
        });

        if (error) throw error;
        res.status(201).json({ success: true, challenge: data });
    } catch (e: any) {
        res.status(400).json({ error: e.message });
    }
});

// ==========================================
// 5. CANCEL CHALLENGE (Host Only, when open)
// ==========================================
challengeRoutes.post('/cancel', authenticate, async (req: any, res: any) => {
    const userId = req.user.sub || req.user.id;
    const { challenge_id } = req.body;

    if (!challenge_id) return res.status(400).json({ error: 'challenge_id is required' });

    try {
        const { data, error } = await supabaseAdmin.rpc('p2p_cancel_challenge', {
            p_challenge_id: challenge_id,
            p_user_id: userId
        });

        if (error) throw error;
        res.status(200).json(data);
    } catch (e: any) {
        res.status(400).json({ error: e.message });
    }
});

// ==========================================
// 6. ACCEPT CHALLENGE
// ==========================================
challengeRoutes.post('/accept', authenticate, async (req: any, res: any) => {
    const userId = req.user.sub || req.user.id;
    const { challenge_id } = req.body;

    if (!challenge_id) return res.status(400).json({ error: 'challenge_id is required' });

    try {
        const { data, error } = await supabaseAdmin.rpc('p2p_accept_challenge', {
            p_challenge_id: challenge_id,
            p_user_id: userId
        });

        if (error) throw error;
        res.status(200).json({ success: true, challenge: data });
    } catch (e: any) {
        res.status(400).json({ error: e.message });
    }
});

// ==========================================
// 7. SUBMIT ROOM DETAILS (Host)
// ==========================================
challengeRoutes.post('/room-details', authenticate, async (req: any, res: any) => {
    const userId = req.user.sub || req.user.id;
    const { challenge_id, room_id, room_password } = req.body;

    if (!challenge_id || !room_id || !room_password) {
        return res.status(400).json({ error: 'challenge_id, room_id and room_password are required' });
    }

    try {
        const { data, error } = await supabaseAdmin.rpc('p2p_submit_room', {
            p_challenge_id: challenge_id,
            p_user_id: userId,
            p_room_id: room_id.trim(),
            p_room_pass: room_password.trim()
        });

        if (error) throw error;
        res.status(200).json({ success: true, challenge: data });
    } catch (e: any) {
        res.status(400).json({ error: e.message });
    }
});

// ==========================================
// 8. CLAIM VICTORY (Winner submits screenshot)
// ==========================================
challengeRoutes.post('/claim-win', authenticate, async (req: any, res: any) => {
    const userId = req.user.sub || req.user.id;
    const { challenge_id, proof_url } = req.body;

    if (!challenge_id || !proof_url) {
        return res.status(400).json({ error: 'challenge_id and proof_url are required' });
    }

    try {
        const { data, error } = await supabaseAdmin.rpc('p2p_claim_victory', {
            p_challenge_id: challenge_id,
            p_user_id: userId,
            p_proof_url: proof_url
        });

        if (error) throw error;
        res.status(200).json({ success: true, challenge: data });
    } catch (e: any) {
        res.status(400).json({ error: e.message });
    }
});

// ==========================================
// 9. CONFIRM LOSS (Instant payout to winner)
// ==========================================
challengeRoutes.post('/confirm-loss', authenticate, async (req: any, res: any) => {
    const userId = req.user.sub || req.user.id;
    const { challenge_id } = req.body;

    if (!challenge_id) return res.status(400).json({ error: 'challenge_id is required' });

    try {
        const { data, error } = await supabaseAdmin.rpc('p2p_confirm_loss', {
            p_challenge_id: challenge_id,
            p_user_id: userId
        });

        if (error) throw error;
        res.status(200).json(data);
    } catch (e: any) {
        res.status(400).json({ error: e.message });
    }
});

// ==========================================
// 10. OPPOSE CLAIM (Dispute winner's claim)
// ==========================================
challengeRoutes.post('/oppose-claim', authenticate, async (req: any, res: any) => {
    const userId = req.user.sub || req.user.id;
    const { challenge_id, reason, proof_url = '', comment = '' } = req.body;

    if (!challenge_id || !reason) {
        return res.status(400).json({ error: 'challenge_id and reason are required' });
    }

    try {
        const { data, error } = await supabaseAdmin.rpc('p2p_oppose_claim', {
            p_challenge_id: challenge_id,
            p_user_id: userId,
            p_reason: reason,
            p_proof_url: proof_url,
            p_comment: comment
        });

        if (error) throw error;
        res.status(200).json(data);
    } catch (e: any) {
        res.status(400).json({ error: e.message });
    }
});

// ==========================================
// 11. REPORT ISSUE (Pre-game / In-game problems)
// ==========================================
challengeRoutes.post('/report-issue', authenticate, async (req: any, res: any) => {
    const userId = req.user.sub || req.user.id;
    const { challenge_id, reason, proof_url = '', comment = '' } = req.body;

    if (!challenge_id || !reason) {
        return res.status(400).json({ error: 'challenge_id and reason are required' });
    }

    try {
        const { data, error } = await supabaseAdmin.rpc('p2p_report_issue', {
            p_challenge_id: challenge_id,
            p_user_id: userId,
            p_reason: reason,
            p_proof_url: proof_url,
            p_comment: comment
        });

        if (error) throw error;
        res.status(200).json(data);
    } catch (e: any) {
        res.status(400).json({ error: e.message });
    }
});

// ==========================================
// 12. ADMIN: GET DISPUTED CHALLENGES
// ==========================================
challengeRoutes.get('/admin/disputes', authenticate, async (req: any, res: any) => {
    const userId = req.user.sub || req.user.id;
    try {
        const { data: user } = await supabaseAdmin.from('users').select('role').eq('id', userId).single();
        if (user?.role !== 'admin') {
            return res.status(403).json({ error: 'Admin access required' });
        }

        const { data, error } = await supabaseAdmin
            .from('challenges')
            .select(`
                *,
                host:users!host_id(id, ign, phone, uid, avatar_id),
                opponent:users!opponent_id(id, ign, phone, uid, avatar_id),
                claimed_winner:users!claimed_winner_id(id, ign, uid),
                disputed_by:users!disputed_by_id(id, ign, uid)
            `)
            .eq('status', 'disputed')
            .order('disputed_at', { ascending: false });

        if (error) throw error;
        res.status(200).json(data || []);
    } catch (e: any) {
        res.status(500).json({ error: e.message });
    }
});

// ==========================================
// 13. ADMIN: RESOLVE DISPUTED CHALLENGE
// ==========================================
challengeRoutes.post('/admin/resolve', authenticate, async (req: any, res: any) => {
    const userId = req.user.sub || req.user.id;
    const { challenge_id, resolution, apply_penalty = false } = req.body;

    if (!challenge_id || !resolution) {
        return res.status(400).json({ error: 'challenge_id and resolution are required' });
    }

    try {
        const { data: user } = await supabaseAdmin.from('users').select('role').eq('id', userId).single();
        if (user?.role !== 'admin') {
            return res.status(403).json({ error: 'Admin access required' });
        }

        const { data, error } = await supabaseAdmin.rpc('p2p_admin_resolve', {
            p_challenge_id: challenge_id,
            p_resolution: resolution,
            p_apply_penalty: Boolean(apply_penalty)
        });

        if (error) throw error;
        res.status(200).json(data);
    } catch (e: any) {
        res.status(400).json({ error: e.message });
    }
});
