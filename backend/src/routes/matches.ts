import { Router } from 'express';
import { supabaseAdmin } from '../supabaseClient';
import { requireAuth as authenticate } from '../middleware';

export const matchRoutes = Router();

// ==========================================
// 1. JOIN A MATCH
// ==========================================
matchRoutes.post('/join', authenticate, async (req, res) => {
    // We already wrote the transaction logic for this in previous phases.
    // I am reconstructing the endpoint structure to ensure it remains intact.
    const { match_id } = req.body;
    const user_id = (req as any).user.sub;

    if (!match_id) return res.status(400).json({ error: 'match_id is required' });

    try {
        // 1. Get Match and User
        const { data: match } = await supabaseAdmin.from('matches').select('*').eq('id', match_id).single();
        const { data: user } = await supabaseAdmin.from('users').select('*').eq('id', user_id).single();
        
        if (!match || !user) return res.status(400).json({ error: 'Invalid match or user.' });
        if (user.status === 'banned') return res.status(403).json({ error: 'Your account is banned.' });
        
        // 1.5 Check if already joined (Fixes double charge bug)
        const { data: existingParticipant } = await supabaseAdmin.from('match_participants').select('user_id').eq('match_id', match_id).eq('user_id', user_id).single();
        if (existingParticipant) {
            return res.status(400).json({ error: 'You have already joined this match.' });
        }
        
        // 2. Check Spots
        const { count } = await supabaseAdmin.from('match_participants').select('*', { count: 'exact', head: true }).eq('match_id', match_id);
        if (count !== null && count >= match.total_spots) {
            return res.status(400).json({ error: 'Match is full.' });
        }

        // 3. Check Balance
        const totalBalance = user.bonus_balance + user.withdrawable_balance;
        if (totalBalance < match.entry_fee) {
            return res.status(400).json({ error: 'Insufficient balance.' });
        }

        // Calculate Deduction (Bonus first)
        let deductBonus = 0;
        let deductWithdrawable = 0;
        
        if (user.bonus_balance >= match.entry_fee) {
            deductBonus = match.entry_fee;
        } else {
            deductBonus = user.bonus_balance;
            deductWithdrawable = match.entry_fee - user.bonus_balance;
        }

        // 4. Update Balances, Ledger & Add Participant (Atomic RPC)
        if (deductBonus > 0) {
            await supabaseAdmin.rpc('adjust_balance', { p_user_id: user_id, p_amount: -deductBonus, p_balance_type: 'bonus' });
        }
        if (deductWithdrawable > 0) {
            await supabaseAdmin.rpc('adjust_balance', { p_user_id: user_id, p_amount: -deductWithdrawable, p_balance_type: 'withdrawable' });
        }

        await supabaseAdmin.from('transactions').insert({
            user_id,
            amount: -match.entry_fee,
            type: 'match_fee',
            reference_id: match_id,
            description: `Joined Match: ${match.title}`
        });

        await supabaseAdmin.from('match_participants').insert({ match_id, user_id });

        res.status(200).json({ message: 'Successfully joined match' });
    } catch (e: any) {
        res.status(500).json({ error: e.message });
    }
});

// ==========================================
// 2. SUBMIT MATCH RESULT (PROOF)
// ==========================================
matchRoutes.post('/submit-result', authenticate, async (req, res) => {
    const { match_id, kills, rank, screenshot_url } = req.body;
    const user_id = (req as any).user.sub;

    if (!match_id || kills === undefined || rank === undefined || !screenshot_url) {
        return res.status(400).json({ error: 'Missing required fields.' });
    }

    try {
        // 1. Verify match exists and is in 'calculating' (Result Collection) status
        const { data: match, error: matchErr } = await supabaseAdmin
            .from('matches')
            .select('status, result_submission_deadline')
            .eq('id', match_id)
            .single();

        if (matchErr || !match) throw new Error('Match not found');
        if (match.status !== 'calculating') {
            return res.status(400).json({ error: 'This match is not currently accepting results.' });
        }

        // Enforce Deadline
        if (match.result_submission_deadline && new Date() > new Date(match.result_submission_deadline)) {
            return res.status(400).json({ error: 'The result submission deadline has passed.' });
        }

        // 2. Verify user actually joined the match
        const { data: participant, error: partErr } = await supabaseAdmin
            .from('match_participants')
            .select('*')
            .eq('match_id', match_id)
            .eq('user_id', user_id)
            .single();

        if (partErr || !participant) {
            return res.status(403).json({ error: 'You did not join this match.' });
        }

        // 3. Upsert the result (in case they are fixing a typo or re-submitting after rejection)
        const { error: upsertErr } = await supabaseAdmin
            .from('match_results')
            .upsert({
                match_id,
                user_id,
                kills,
                rank,
                status: 'pending',
                proof_image_url: screenshot_url
            }, { onConflict: 'match_id, user_id' });

        if (upsertErr) throw upsertErr;

        res.status(200).json({ message: 'Proof submitted successfully.' });
    } catch (e: any) {
        res.status(500).json({ error: e.message });
    }
});

// ==========================================
// 3. GET MATCH SECRETS (ROOM ID/PASS)
// ==========================================
matchRoutes.get('/:match_id/secrets', authenticate, async (req: any, res: any) => {
    const { match_id } = req.params;
    const user_id = req.user.sub || req.user.id;
    try {
        // 1. Verify user joined the match
        const { data: participant } = await supabaseAdmin
            .from('match_participants')
            .select('*')
            .eq('match_id', match_id)
            .eq('user_id', user_id)
            .single();

        if (!participant) {
            return res.status(403).json({ error: 'You are not a participant in this match.' });
        }

        // 2. Fetch secrets
        const { data: secrets } = await supabaseAdmin
            .from('match_secrets')
            .select('*')
            .eq('match_id', match_id)
            .maybeSingle();

        res.status(200).json(secrets || null);
    } catch (e: any) {
        res.status(500).json({ error: e.message });
    }
});
