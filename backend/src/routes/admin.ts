import { Router } from 'express';
import { supabaseAdmin } from '../supabaseClient';
import { requireAdmin } from '../middleware';

export const adminRoutes = Router();

adminRoutes.use(requireAdmin);

// 1. Mark Match as Finished (Starts the Result Collection Timer)
adminRoutes.post('/matches/mark-finished', async (req, res) => {
    const { match_id, timer_hours = 2 } = req.body;
    try {
        const deadline = new Date();
        deadline.setHours(deadline.getHours() + timer_hours);

        const { error } = await supabaseAdmin.from('matches').update({
            status: 'calculating',
            result_submission_deadline: deadline.toISOString()
        }).eq('id', match_id);

        if (error) throw error;
        res.status(200).json({ message: `Match moved to calculating. Deadline set for ${timer_hours} hours.` });
    } catch (err: any) {
        res.status(500).json({ error: err.message });
    }
});

// 1.1 Review Individual User Result
adminRoutes.post('/matches/review-result', async (req, res) => {
    const { result_id, action, prize_amount = 0, comment } = req.body; 
    // action: 'approved' | 'rejected'

    try {
        // Fetch the result
        const { data: result } = await supabaseAdmin.from('match_results').select('*').eq('id', result_id).single();
        if (!result) return res.status(404).json({ error: 'Result not found' });
        if (result.status !== 'pending') return res.status(400).json({ error: 'Already reviewed' });

        // Update result
        await supabaseAdmin.from('match_results').update({
            status: action,
            prize_awarded: prize_amount,
            admin_comment: comment
        }).eq('id', result_id);

        if (action === 'rejected') {
            await supabaseAdmin.from('notifications').insert({
                user_id: result.user_id,
                title: 'Result Rejected',
                message: `Your result for match has been rejected. Reason: ${comment}`
            });
        }

        // If approved and prize > 0, credit wallet securely
        if (action === 'approved' && prize_amount > 0) {
            const { data: user } = await supabaseAdmin.from('users').select('withdrawable_balance').eq('id', result.user_id).single();
            if (user) {
                await supabaseAdmin.rpc('adjust_balance', { p_user_id: result.user_id, p_amount: prize_amount, p_balance_type: 'withdrawable' });
                
                await supabaseAdmin.from('transactions').insert({
                    user_id: result.user_id,
                    amount: prize_amount,
                    type: 'prize',
                    reference_id: result.match_id,
                    description: `Prize for Match (Rank: ${result.rank}, Kills: ${result.kills})`
                });
            }
        }

        res.status(200).json({ message: `Result ${action} successfully.` });
    } catch (err: any) {
        res.status(500).json({ error: err.message });
    }
});

// 1.2 Close Match Officially
adminRoutes.post('/matches/close', async (req, res) => {
    const { match_id } = req.body;
    try {
        // Check if there are any pending results left
        const { count } = await supabaseAdmin.from('match_results').select('*', { count: 'exact', head: true })
            .eq('match_id', match_id).eq('status', 'pending');
            
        if (count && count > 0) {
            return res.status(400).json({ error: `Cannot close match. There are ${count} pending submissions.` });
        }

        const { error } = await supabaseAdmin.from('matches').update({ status: 'completed' }).eq('id', match_id);
        if (error) throw error;

        res.status(200).json({ message: 'Match officially closed and moved to History.' });
    } catch (err: any) {
        res.status(500).json({ error: err.message });
    }
});

// 1.5 Create Match
adminRoutes.post('/matches/create', async (req, res) => {
    const { title, category, entry_fee, total_spots, prize_pool, start_time, room_id, room_password, per_kill_prize, first_prize, second_prize, third_prize } = req.body;
    try {
        if (!title || !category || entry_fee < 0 || total_spots <= 0 || prize_pool < 0 || !start_time) {
            return res.status(400).json({ error: 'Invalid or missing match data.' });
        }
        if (new Date(start_time) <= new Date()) {
            return res.status(400).json({ error: 'Start time must be in the future.' });
        }

        const { data: match, error } = await supabaseAdmin.from('matches').insert({
            title,
            category,
            entry_fee,
            total_spots,
            prize_pool,
            per_kill_prize: per_kill_prize || 0,
            first_prize: first_prize || 0,
            second_prize: second_prize || 0,
            third_prize: third_prize || 0,
            start_time,
            status: 'upcoming'
        }).select().single();

        if (error) throw error;

        if (room_id || room_password) {
            await supabaseAdmin.from('match_secrets').insert({
                match_id: match.id,
                room_id,
                room_password
            });
        }

        res.status(200).json({ message: 'Match created successfully', match });
    } catch (err: any) {
        res.status(500).json({ error: err.message });
    }
});

// 1.6 Update Match Room Details
adminRoutes.post('/matches/update-room', async (req, res) => {
    const { match_id, room_id, room_password } = req.body;
    try {
        if (!match_id) return res.status(400).json({ error: 'match_id is required' });

        const { data: match } = await supabaseAdmin.from('matches').select('title, status').eq('id', match_id).single();
        if (!match) return res.status(404).json({ error: 'Match not found' });
        if (match.status === 'cancelled' || match.status === 'completed') {
            return res.status(400).json({ error: 'Cannot update room details for this match.' });
        }

        await supabaseAdmin.from('match_secrets').upsert({
            match_id,
            room_id,
            room_password
        }, { onConflict: 'match_id' });

        // Update match status to 'ongoing' so it disappears from the joinable list!
        await supabaseAdmin.from('matches').update({ status: 'ongoing' }).eq('id', match_id);

        // Notify participants
        const { data: participants } = await supabaseAdmin.from('match_participants').select('user_id').eq('match_id', match_id);
        if (participants && participants.length > 0) {
            const notifications = participants.map(p => ({
                user_id: p.user_id,
                title: 'Room Details Updated!',
                message: `The Room ID and Password for "${match.title}" are now available!`
            }));
            await supabaseAdmin.from('notifications').insert(notifications);
        }

        res.status(200).json({ message: 'Room details updated and players notified.' });
    } catch (err: any) {
        res.status(500).json({ error: err.message });
    }
});

// 1.7 Auto-Verify Match Results (Smart Verification)
adminRoutes.post('/matches/auto-verify', async (req, res) => {
    const { match_id, actual_players } = req.body;
    try {
        if (!match_id) return res.status(400).json({ error: 'match_id is required' });

        const { data: match } = await supabaseAdmin.from('matches').select('*').eq('id', match_id).single();
        if (!match) return res.status(404).json({ error: 'Match not found' });
        if (match.status !== 'calculating') {
            return res.status(400).json({ error: 'Match is not in calculating state.' });
        }

        const { data: pendingResults } = await supabaseAdmin.from('match_results').select('*').eq('match_id', match_id).eq('status', 'pending');
        if (!pendingResults || pendingResults.length === 0) {
            return res.status(400).json({ error: 'No pending results found.' });
        }

        // We used to block this if not all players submitted, but if the Admin 
        // rejected someone or manually wants to distribute, we should let them!
        const totalSubmissionsCount = pendingResults.length;
        const expectedPlayers = actual_players ?? match.filled_spots;
        
        /*
        const isDeadlinePassed = match.result_submission_deadline && (new Date() > new Date(match.result_submission_deadline));
        
        if (!isDeadlinePassed && totalSubmissionsCount < expectedPlayers) {
            return res.status(400).json({ 
                error: `Cannot verify yet: Only ${totalSubmissionsCount}/${expectedPlayers} players submitted. Please wait until they submit or the deadline passes.` 
            });
        }
        */

        // Constraints
        const maxKills = Math.max(0, expectedPlayers - 1);
        let totalClaimedKills = 0;
        const claimedRanks = new Set<number>();
        let hasConflict = false;

        for (const result of pendingResults) {
            totalClaimedKills += result.kills;
            // Check rank uniqueness for top 3
            if (result.rank >= 1 && result.rank <= 3) {
                if (claimedRanks.has(result.rank)) {
                    hasConflict = true;
                    break;
                }
                claimedRanks.add(result.rank);
            }
        }

        if (hasConflict) {
            return res.status(400).json({ error: 'Conflict Detected: Multiple players claimed the same top 3 rank. Please verify manually.' });
        }

        if (totalClaimedKills > maxKills) {
            return res.status(400).json({ error: `Conflict Detected: Claimed kills (${totalClaimedKills}) exceed max possible kills (${maxKills}). Please verify manually.` });
        }

        // If all checks pass, approve them all!
        let approvedCount = 0;
        let totalPrizeAwarded = 0;

        for (const result of pendingResults) {
            let prize = result.kills * match.per_kill_prize;
            if (result.rank === 1) prize += match.first_prize;
            else if (result.rank === 2) prize += match.second_prize;
            else if (result.rank === 3) prize += match.third_prize;

            // Update result
            await supabaseAdmin.from('match_results').update({
                status: 'approved',
                prize_awarded: prize,
                admin_comment: 'Auto-Verified'
            }).eq('id', result.id);

            // Credit wallet securely if prize > 0
            if (prize > 0) {
                await supabaseAdmin.rpc('adjust_balance', { p_user_id: result.user_id, p_amount: prize, p_balance_type: 'withdrawable' });
                
                await supabaseAdmin.from('transactions').insert({
                    user_id: result.user_id,
                    amount: prize,
                    type: 'prize',
                    reference_id: result.match_id,
                    description: `Prize for Match (Rank: ${result.rank}, Kills: ${result.kills}) - Auto-Verified`
                });
            }
            approvedCount++;
            totalPrizeAwarded += prize;
        }

        res.status(200).json({ message: `Successfully auto-verified ${approvedCount} results. Awarded ${totalPrizeAwarded} Tk total.` });
    } catch (err: any) {
        res.status(500).json({ error: err.message });
    }
});

// 1.8 Upload Admin Proof
adminRoutes.post('/matches/admin-proof', async (req, res) => {
    const { match_id, proof_url } = req.body;
    try {
        if (!match_id || !proof_url) {
            return res.status(400).json({ error: 'match_id and proof_url are required.' });
        }
        
        const { error } = await supabaseAdmin.from('matches').update({ admin_proof_url: proof_url }).eq('id', match_id);
        if (error) throw error;

        res.status(200).json({ message: 'Admin proof uploaded successfully.' });
    } catch (err: any) {
        res.status(500).json({ error: err.message });
    }
});

// 2. Cancel Upcoming/Ongoing Match
adminRoutes.post('/matches/cancel-upcoming', async (req, res) => {
    const { match_id, reason } = req.body;

    try {
        // Fetch match and all participants
        const { data: match } = await supabaseAdmin.from('matches').select('*').eq('id', match_id).single();
        if (!match) return res.status(404).json({ error: 'Match not found' });
        if (match.status === 'completed' || match.status === 'calculating') return res.status(400).json({ error: 'Cannot cancel a match in this state.' });

        const { data: participants } = await supabaseAdmin.from('match_participants').select('user_id').eq('match_id', match_id);

        if (participants && participants.length > 0) {
            // Refund everyone precisely their entry fee
            const refundAmount = match.entry_fee;

            for (const p of participants) {
                const { data: user } = await supabaseAdmin.from('users').select('withdrawable_balance').eq('id', p.user_id).single();
                if (user) {
                    await supabaseAdmin.rpc('adjust_balance', { p_user_id: p.user_id, p_amount: refundAmount, p_balance_type: 'withdrawable' });
                    
                    await supabaseAdmin.from('transactions').insert({
                        user_id: p.user_id,
                        amount: refundAmount,
                        type: 'refund',
                        reference_id: match_id,
                        description: `Match Cancelled: ${reason}`
                    });

                    await supabaseAdmin.from('notifications').insert({
                        user_id: p.user_id,
                        title: 'Match Cancelled & Refunded',
                        message: `The match "${match.title}" has been cancelled. Reason: ${reason}. Your entry fee of ${refundAmount} Tk has been refunded to your Withdrawable balance.`
                    });
                }
            }
        }

        // Cancel the match entirely
        await supabaseAdmin.from('matches').update({ status: 'cancelled' }).eq('id', match_id);

        res.status(200).json({ message: `Nuclear rollback successful. Refunded ${participants?.length || 0} players.` });

    } catch (err: any) {
        console.error('Cancel Upcoming Error:', err);
        res.status(500).json({ error: err.message });
    }
});

// 2.1 Refund Historical Match
adminRoutes.post('/matches/refund-historical', async (req, res) => {
    const { match_id, reason } = req.body;

    try {
        const { data: match } = await supabaseAdmin.from('matches').select('*').eq('id', match_id).single();
        if (!match) return res.status(404).json({ error: 'Match not found' });
        if (match.status !== 'completed') return res.status(400).json({ error: 'Can only historically refund completed matches.' });

        // 1. Fetch Winners and reverse prizes
        const { data: results } = await supabaseAdmin.from('match_results').select('*').eq('match_id', match_id).gt('prize_awarded', 0);
        
        if (results && results.length > 0) {
            for (const result of results) {
                const { data: user } = await supabaseAdmin.from('users').select('withdrawable_balance').eq('id', result.user_id).single();
                if (user) {
                    await supabaseAdmin.rpc('adjust_balance', { p_user_id: result.user_id, p_amount: -result.prize_awarded, p_balance_type: 'withdrawable' });
                    
                    await supabaseAdmin.from('transactions').insert({
                        user_id: result.user_id,
                        amount: -result.prize_awarded,
                        type: 'prize_reversal',
                        reference_id: match_id,
                        description: `Historical Match Reversal: Prize Deducted. Reason: ${reason}`
                    });
                }
            }
        }

        // 2. Refund entry fees to everyone
        const { data: participants } = await supabaseAdmin.from('match_participants').select('user_id').eq('match_id', match_id);
        
        if (participants && participants.length > 0) {
            const refundAmount = match.entry_fee;
            for (const p of participants) {
                const { data: user } = await supabaseAdmin.from('users').select('withdrawable_balance').eq('id', p.user_id).single();
                if (user) {
                    await supabaseAdmin.rpc('adjust_balance', { p_user_id: p.user_id, p_amount: refundAmount, p_balance_type: 'withdrawable' });
                    
                    await supabaseAdmin.from('transactions').insert({
                        user_id: p.user_id,
                        amount: refundAmount,
                        type: 'refund',
                        reference_id: match_id,
                        description: `Historical Match Reversal Refund: ${reason}`
                    });

                    await supabaseAdmin.from('notifications').insert({
                        user_id: p.user_id,
                        title: 'Historical Match Reversed & Refunded',
                        message: `The historical match "${match.title}" has been reversed. Reason: ${reason}. Your entry fee has been refunded. Any prizes awarded were retracted.`
                    });
                }
            }
        }

        // 3. Mark match as cancelled
        await supabaseAdmin.from('matches').update({ status: 'cancelled' }).eq('id', match_id);

        res.status(200).json({ message: 'Historical match reversed and refunded successfully.' });
    } catch (err: any) {
        console.error('Historical Refund Error:', err);
        res.status(500).json({ error: err.message });
    }
});

// 3. Admin Stats (Dashboard)
adminRoutes.get('/stats', async (req, res) => {
    try {
        const [{ count: userCount }, { count: matchCount }, { count: wdCount }] = await Promise.all([
            supabaseAdmin.from('users').select('*', { count: 'exact', head: true }),
            supabaseAdmin.from('matches').select('*', { count: 'exact', head: true }).in('status', ['upcoming', 'ongoing']),
            supabaseAdmin.from('withdrawals').select('*', { count: 'exact', head: true }).eq('status', 'pending')
        ]);

        // Simple revenue calculation (sum of all entry fees paid minus prizes distributed)
        // For now, we'll just return a mock revenue or calculate sum of deposits.
        // Let's do sum of all 'match_fee' transactions (they are negative, so we'll abs them)
        const { data: revData } = await supabaseAdmin.from('transactions').select('amount').eq('type', 'match_fee');
        const revenue = revData ? revData.reduce((acc, curr) => acc + Math.abs(curr.amount), 0) : 0;

        res.status(200).json({
            totalUsers: userCount || 0,
            activeMatches: matchCount || 0,
            pendingWithdrawalsCount: wdCount || 0,
            totalRevenue: revenue
        });
    } catch (err: any) {
        res.status(500).json({ error: err.message });
    }
});

// 4. Approve Withdrawal
adminRoutes.post('/withdrawals/approve', async (req, res) => {
    const { withdrawal_id } = req.body;
    try {
        await supabaseAdmin.from('withdrawals').update({ status: 'approved', updated_at: new Date().toISOString() }).eq('id', withdrawal_id);
        res.status(200).json({ message: 'Withdrawal approved.' });
    } catch (err: any) {
        res.status(500).json({ error: err.message });
    }
});

// 5. Reject Withdrawal
adminRoutes.post('/withdrawals/reject', async (req, res) => {
    const { withdrawal_id, reason } = req.body;
    try {
        const { data: withdrawal } = await supabaseAdmin.from('withdrawals').select('*').eq('id', withdrawal_id).single();
        if (!withdrawal) return res.status(404).json({ error: 'Not found' });
        if (withdrawal.status !== 'pending') return res.status(400).json({ error: 'Already processed' });

        // Refund user
        const { data: user } = await supabaseAdmin.from('users').select('withdrawable_balance').eq('id', withdrawal.user_id).single();
        if (user) {
            await supabaseAdmin.rpc('adjust_balance', { p_user_id: withdrawal.user_id, p_amount: withdrawal.amount, p_balance_type: 'withdrawable' });
            await supabaseAdmin.from('transactions').insert({
                user_id: withdrawal.user_id,
                amount: withdrawal.amount,
                type: 'refund',
                description: `Withdrawal Rejected: ${reason || 'Admin discretion'}`
            });
        }

        await supabaseAdmin.from('withdrawals').update({ status: 'rejected', updated_at: new Date().toISOString() }).eq('id', withdrawal_id);
        res.status(200).json({ message: 'Withdrawal rejected and refunded.' });
    } catch (err: any) {
        res.status(500).json({ error: err.message });
    }
});

// 6. Manual Balance Adjustment
adminRoutes.post('/users/adjust-balance', async (req, res) => {
    const { user_id, amount, balance_type, reason } = req.body; 
    // balance_type is either 'bonus' or 'withdrawable'
    
    try {
        const { data: user } = await supabaseAdmin.from('users').select('*').eq('id', user_id).single();
        if (!user) return res.status(404).json({ error: 'User not found' });

        if (balance_type === 'bonus') {
            await supabaseAdmin.rpc('adjust_balance', { p_user_id: user_id, p_amount: amount, p_balance_type: 'bonus' });
        } else {
            await supabaseAdmin.rpc('adjust_balance', { p_user_id: user_id, p_amount: amount, p_balance_type: 'withdrawable' });
        }

        await supabaseAdmin.from('transactions').insert({
            user_id: user_id,
            amount: amount,
            type: 'manual_adjustment',
            description: `Manual Adj (${balance_type}): ${reason}`
        });

        res.status(200).json({ message: 'Balance adjusted successfully.' });
    } catch (err: any) {
        res.status(500).json({ error: err.message });
    }
});

// ==========================================
// 7. DISPUTE INVESTIGATION SYSTEM
// ==========================================

// 7.1 Get all pending disputes
adminRoutes.get('/disputes', async (req, res) => {
    try {
        const { data: disputes, error } = await supabaseAdmin
            .from('disputes')
            .select('*, matches(title), users(ign, phone)')
            .eq('status', 'pending')
            .order('created_at', { ascending: false });

        if (error) throw error;
        res.status(200).json(disputes);
    } catch (err: any) {
        res.status(500).json({ error: err.message });
    }
});

// 7.2 Resolve a dispute
adminRoutes.post('/disputes/resolve', async (req, res) => {
    const { dispute_id, status, admin_response, prize_correction } = req.body;
    // status can be 'resolved'
    
    try {
        // Fetch dispute
        const { data: dispute } = await supabaseAdmin.from('disputes').select('*').eq('id', dispute_id).single();
        if (!dispute) return res.status(404).json({ error: 'Dispute not found' });

        // If admin decided to award money
        if (prize_correction > 0) {
            await supabaseAdmin.rpc('adjust_balance', { p_user_id: dispute.user_id, p_amount: prize_correction, p_balance_type: 'withdrawable' });
            
            await supabaseAdmin.from('transactions').insert({
                user_id: dispute.user_id,
                amount: prize_correction,
                type: 'dispute_correction',
                reference_id: dispute.match_id,
                description: `Dispute Resolved: Corrected Prize`
            });
        }

        // Update dispute
        await supabaseAdmin.from('disputes').update({
            status,
            admin_response,
            prize_correction,
            resolved_at: new Date().toISOString()
        }).eq('id', dispute_id);

        res.status(200).json({ message: 'Dispute resolved successfully.' });
    } catch (err: any) {
        res.status(500).json({ error: err.message });
    }
});
