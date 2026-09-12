require('dotenv').config();
const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(
  process.env.SUPABASE_URL || 'https://api.teertha.space',
  process.env.SUPABASE_SERVICE_KEY
);

async function migrate() {
    console.log('Starting challenges migration via exec_sql RPC...');

    const sql = `
        CREATE TABLE IF NOT EXISTS challenges (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            host_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
            opponent_id UUID REFERENCES users(id) ON DELETE SET NULL,
            mode VARCHAR(50) DEFAULT '1v1_cs',
            map VARCHAR(50) DEFAULT 'Bermuda',
            rules JSONB DEFAULT '{"unlimited_ammo": true, "character_skill": false, "gun_attributes": false, "headshot_only": false}'::jsonb,
            stake DECIMAL(10, 2) NOT NULL,
            prize_pool DECIMAL(10, 2) NOT NULL,
            platform_fee DECIMAL(10, 2) NOT NULL,
            status VARCHAR(30) DEFAULT 'open',
            room_id VARCHAR(50),
            room_password VARCHAR(50),
            room_submitted_at TIMESTAMP WITH TIME ZONE,
            claimed_winner_id UUID REFERENCES users(id),
            claim_proof_url TEXT,
            claim_submitted_at TIMESTAMP WITH TIME ZONE,
            objection_deadline TIMESTAMP WITH TIME ZONE,
            opponent_confirmed_loss BOOLEAN DEFAULT FALSE,
            disputed_by_id UUID REFERENCES users(id),
            dispute_reason VARCHAR(100),
            dispute_proof_url TEXT,
            dispute_comment TEXT,
            disputed_at TIMESTAMP WITH TIME ZONE,
            admin_resolution VARCHAR(50),
            admin_penalty_applied BOOLEAN DEFAULT FALSE,
            winner_id UUID REFERENCES users(id),
            created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
        );

        CREATE INDEX IF NOT EXISTS idx_challenges_status ON challenges(status);
        CREATE INDEX IF NOT EXISTS idx_challenges_host ON challenges(host_id);
        CREATE INDEX IF NOT EXISTS idx_challenges_opponent ON challenges(opponent_id);

        ALTER TABLE challenges ENABLE ROW LEVEL SECURITY;
        DROP POLICY IF EXISTS "Challenges are viewable by everyone" ON challenges;
        CREATE POLICY "Challenges are viewable by everyone" ON challenges FOR SELECT USING (true);
        DROP POLICY IF EXISTS "Allow all for authenticated/service" ON challenges;
        CREATE POLICY "Allow all for authenticated/service" ON challenges FOR ALL USING (true) WITH CHECK (true);

        DO $$
        BEGIN
            IF NOT EXISTS (
                SELECT 1 FROM pg_publication_tables 
                WHERE pubname = 'supabase_realtime' AND tablename = 'challenges'
            ) THEN
                ALTER PUBLICATION supabase_realtime ADD TABLE challenges;
            END IF;
        END $$;

        -- 1. Atomic Function: p2p_create_challenge
        CREATE OR REPLACE FUNCTION p2p_create_challenge(
            p_host_id UUID,
            p_stake DECIMAL,
            p_mode TEXT DEFAULT '1v1_cs',
            p_map TEXT DEFAULT 'Bermuda',
            p_rules JSONB DEFAULT '{"unlimited_ammo": true, "character_skill": false}'::jsonb
        ) RETURNS JSONB AS $body$
        DECLARE
            v_user RECORD;
            v_bonus_deduct DECIMAL := 0.00;
            v_withdrawable_deduct DECIMAL := 0.00;
            v_prize_pool DECIMAL;
            v_platform_fee DECIMAL;
            v_challenge_id UUID;
            v_result JSONB;
        BEGIN
            SELECT * INTO v_user FROM users WHERE id = p_host_id FOR UPDATE;
            IF NOT FOUND THEN
                RAISE EXCEPTION 'User not found';
            END IF;
            IF v_user.status = 'banned' THEN
                RAISE EXCEPTION 'User account is suspended';
            END IF;

            IF (v_user.bonus_balance + v_user.withdrawable_balance) < p_stake THEN
                RAISE EXCEPTION 'Insufficient balance to create challenge';
            END IF;

            IF v_user.bonus_balance >= p_stake THEN
                v_bonus_deduct := p_stake;
            ELSE
                v_bonus_deduct := v_user.bonus_balance;
                v_withdrawable_deduct := p_stake - v_user.bonus_balance;
            END IF;

            UPDATE users 
            SET bonus_balance = bonus_balance - v_bonus_deduct,
                withdrawable_balance = withdrawable_balance - v_withdrawable_deduct
            WHERE id = p_host_id;

            v_platform_fee := ROUND(p_stake * 2 * 0.10, 2);
            v_prize_pool := (p_stake * 2) - v_platform_fee;

            INSERT INTO challenges (
                host_id, mode, map, rules, stake, prize_pool, platform_fee, status
            ) VALUES (
                p_host_id, p_mode, p_map, p_rules, p_stake, v_prize_pool, v_platform_fee, 'open'
            ) RETURNING id INTO v_challenge_id;

            INSERT INTO transactions (
                user_id, amount, type, reference_id, description
            ) VALUES (
                p_host_id, -p_stake, 'match_fee', v_challenge_id::text, 'Created 1v1 Challenge (' || p_mode || ')'
            );

            SELECT to_jsonb(c.*) INTO v_result FROM challenges c WHERE c.id = v_challenge_id;
            RETURN v_result;
        END;
        $body$ LANGUAGE plpgsql SECURITY DEFINER;

        -- 2. Atomic Function: p2p_cancel_challenge
        CREATE OR REPLACE FUNCTION p2p_cancel_challenge(
            p_challenge_id UUID,
            p_user_id UUID
        ) RETURNS JSONB AS $body$
        DECLARE
            v_challenge RECORD;
        BEGIN
            SELECT * INTO v_challenge FROM challenges WHERE id = p_challenge_id FOR UPDATE;
            IF NOT FOUND THEN
                RAISE EXCEPTION 'Challenge not found';
            END IF;
            IF v_challenge.host_id != p_user_id THEN
                RAISE EXCEPTION 'Only host can cancel challenge';
            END IF;
            IF v_challenge.status != 'open' THEN
                RAISE EXCEPTION 'Cannot cancel challenge that is already matched or completed';
            END IF;

            UPDATE users 
            SET withdrawable_balance = withdrawable_balance + v_challenge.stake 
            WHERE id = p_user_id;

            UPDATE challenges 
            SET status = 'cancelled', updated_at = NOW() 
            WHERE id = p_challenge_id;

            INSERT INTO transactions (
                user_id, amount, type, reference_id, description
            ) VALUES (
                p_user_id, v_challenge.stake, 'refund', p_challenge_id::text, 'Cancelled 1v1 Challenge'
            );

            RETURN jsonb_build_object('success', true, 'message', 'Challenge cancelled and refunded');
        END;
        $body$ LANGUAGE plpgsql SECURITY DEFINER;

        -- 3. Atomic Function: p2p_accept_challenge
        CREATE OR REPLACE FUNCTION p2p_accept_challenge(
            p_challenge_id UUID,
            p_user_id UUID
        ) RETURNS JSONB AS $body$
        DECLARE
            v_challenge RECORD;
            v_user RECORD;
            v_bonus_deduct DECIMAL := 0.00;
            v_withdrawable_deduct DECIMAL := 0.00;
            v_result JSONB;
        BEGIN
            SELECT * INTO v_challenge FROM challenges WHERE id = p_challenge_id FOR UPDATE;
            IF NOT FOUND THEN
                RAISE EXCEPTION 'Challenge not found';
            END IF;
            IF v_challenge.status != 'open' THEN
                RAISE EXCEPTION 'Challenge is no longer open';
            END IF;
            IF v_challenge.host_id = p_user_id THEN
                RAISE EXCEPTION 'You cannot accept your own challenge';
            END IF;

            SELECT * INTO v_user FROM users WHERE id = p_user_id FOR UPDATE;
            IF NOT FOUND THEN
                RAISE EXCEPTION 'User not found';
            END IF;
            IF v_user.status = 'banned' THEN
                RAISE EXCEPTION 'User account is suspended';
            END IF;
            IF (v_user.bonus_balance + v_user.withdrawable_balance) < v_challenge.stake THEN
                RAISE EXCEPTION 'Insufficient balance to accept challenge';
            END IF;

            IF v_user.bonus_balance >= v_challenge.stake THEN
                v_bonus_deduct := v_challenge.stake;
            ELSE
                v_bonus_deduct := v_user.bonus_balance;
                v_withdrawable_deduct := v_challenge.stake - v_user.bonus_balance;
            END IF;

            UPDATE users 
            SET bonus_balance = bonus_balance - v_bonus_deduct,
                withdrawable_balance = withdrawable_balance - v_withdrawable_deduct
            WHERE id = p_user_id;

            UPDATE challenges 
            SET opponent_id = p_user_id,
                status = 'room_setup',
                updated_at = NOW()
            WHERE id = p_challenge_id;

            INSERT INTO transactions (
                user_id, amount, type, reference_id, description
            ) VALUES (
                p_user_id, -v_challenge.stake, 'match_fee', p_challenge_id::text, 'Accepted 1v1 Challenge'
            );

            INSERT INTO notifications (
                user_id, title, message
            ) VALUES (
                v_challenge.host_id, 
                '⚔️ Challenger Joined!', 
                'A player accepted your 1v1 challenge. Please submit Room ID & Password now!'
            );

            SELECT to_jsonb(c.*) INTO v_result FROM challenges c WHERE c.id = p_challenge_id;
            RETURN v_result;
        END;
        $body$ LANGUAGE plpgsql SECURITY DEFINER;

        -- 4. Atomic Function: p2p_submit_room
        CREATE OR REPLACE FUNCTION p2p_submit_room(
            p_challenge_id UUID,
            p_user_id UUID,
            p_room_id TEXT,
            p_room_pass TEXT
        ) RETURNS JSONB AS $body$
        DECLARE
            v_challenge RECORD;
            v_result JSONB;
        BEGIN
            SELECT * INTO v_challenge FROM challenges WHERE id = p_challenge_id FOR UPDATE;
            IF NOT FOUND THEN
                RAISE EXCEPTION 'Challenge not found';
            END IF;
            IF v_challenge.host_id != p_user_id AND v_challenge.opponent_id != p_user_id THEN
                RAISE EXCEPTION 'Not a participant of this challenge';
            END IF;
            IF v_challenge.status NOT IN ('room_setup', 'open') THEN
                RAISE EXCEPTION 'Cannot update room details in current status';
            END IF;

            UPDATE challenges
            SET room_id = p_room_id,
                room_password = p_room_pass,
                room_submitted_at = NOW(),
                status = 'ongoing',
                updated_at = NOW()
            WHERE id = p_challenge_id;

            IF v_challenge.opponent_id IS NOT NULL THEN
                INSERT INTO notifications (
                    user_id, title, message
                ) VALUES (
                    v_challenge.opponent_id,
                    '🔑 Room Credentials Ready!',
                    'Room ID: ' || p_room_id || ' | Pass: ' || p_room_pass || '. Open Free Fire and join now!'
                );
            END IF;

            SELECT to_jsonb(c.*) INTO v_result FROM challenges c WHERE c.id = p_challenge_id;
            RETURN v_result;
        END;
        $body$ LANGUAGE plpgsql SECURITY DEFINER;

        -- 5. Atomic Function: p2p_claim_victory
        CREATE OR REPLACE FUNCTION p2p_claim_victory(
            p_challenge_id UUID,
            p_user_id UUID,
            p_proof_url TEXT
        ) RETURNS JSONB AS $body$
        DECLARE
            v_challenge RECORD;
            v_opponent_id UUID;
            v_result JSONB;
        BEGIN
            SELECT * INTO v_challenge FROM challenges WHERE id = p_challenge_id FOR UPDATE;
            IF NOT FOUND THEN
                RAISE EXCEPTION 'Challenge not found';
            END IF;
            IF v_challenge.host_id != p_user_id AND v_challenge.opponent_id != p_user_id THEN
                RAISE EXCEPTION 'Not a participant of this challenge';
            END IF;
            IF v_challenge.status != 'ongoing' THEN
                RAISE EXCEPTION 'Match is not in ongoing state';
            END IF;

            v_opponent_id := CASE WHEN v_challenge.host_id = p_user_id THEN v_challenge.opponent_id ELSE v_challenge.host_id END;

            UPDATE challenges
            SET claimed_winner_id = p_user_id,
                claim_proof_url = p_proof_url,
                claim_submitted_at = NOW(),
                objection_deadline = NOW() + INTERVAL '15 minutes',
                status = 'claimed',
                updated_at = NOW()
            WHERE id = p_challenge_id;

            IF v_opponent_id IS NOT NULL THEN
                INSERT INTO notifications (
                    user_id, title, message
                ) VALUES (
                    v_opponent_id,
                    '⚠️ Victory Claim Submitted',
                    'Your opponent claimed victory! You have 15 minutes to confirm or submit an objection with proof.'
                );
            END IF;

            SELECT to_jsonb(c.*) INTO v_result FROM challenges c WHERE c.id = p_challenge_id;
            RETURN v_result;
        END;
        $body$ LANGUAGE plpgsql SECURITY DEFINER;

        -- 6. Atomic Function: p2p_confirm_loss
        CREATE OR REPLACE FUNCTION p2p_confirm_loss(
            p_challenge_id UUID,
            p_user_id UUID
        ) RETURNS JSONB AS $body$
        DECLARE
            v_challenge RECORD;
        BEGIN
            SELECT * INTO v_challenge FROM challenges WHERE id = p_challenge_id FOR UPDATE;
            IF NOT FOUND THEN
                RAISE EXCEPTION 'Challenge not found';
            END IF;
            IF v_challenge.status != 'claimed' THEN
                RAISE EXCEPTION 'No victory claim pending confirmation';
            END IF;
            IF v_challenge.claimed_winner_id = p_user_id THEN
                RAISE EXCEPTION 'Winner cannot confirm their own loss';
            END IF;
            IF v_challenge.host_id != p_user_id AND v_challenge.opponent_id != p_user_id THEN
                RAISE EXCEPTION 'Not a participant of this challenge';
            END IF;

            UPDATE users 
            SET withdrawable_balance = withdrawable_balance + v_challenge.prize_pool
            WHERE id = v_challenge.claimed_winner_id;

            UPDATE challenges
            SET status = 'completed',
                winner_id = v_challenge.claimed_winner_id,
                opponent_confirmed_loss = TRUE,
                updated_at = NOW()
            WHERE id = p_challenge_id;

            INSERT INTO transactions (
                user_id, amount, type, reference_id, description
            ) VALUES (
                v_challenge.claimed_winner_id, v_challenge.prize_pool, 'prize', p_challenge_id::text, 'Won 1v1 Challenge'
            );

            INSERT INTO notifications (
                user_id, title, message
            ) VALUES (
                v_challenge.claimed_winner_id,
                '🏆 Victory Confirmed!',
                'Opponent confirmed your victory! ' || v_challenge.prize_pool || ' Tk has been credited to your wallet.'
            );

            RETURN jsonb_build_object('success', true, 'message', 'Result confirmed and prize released.');
        END;
        $body$ LANGUAGE plpgsql SECURITY DEFINER;

        -- 7. Atomic Function: p2p_oppose_claim
        CREATE OR REPLACE FUNCTION p2p_oppose_claim(
            p_challenge_id UUID,
            p_user_id UUID,
            p_reason TEXT,
            p_proof_url TEXT,
            p_comment TEXT DEFAULT ''
        ) RETURNS JSONB AS $body$
        DECLARE
            v_challenge RECORD;
        BEGIN
            SELECT * INTO v_challenge FROM challenges WHERE id = p_challenge_id FOR UPDATE;
            IF NOT FOUND THEN
                RAISE EXCEPTION 'Challenge not found';
            END IF;
            IF v_challenge.status != 'claimed' THEN
                RAISE EXCEPTION 'Challenge is not in claimed status';
            END IF;
            IF v_challenge.claimed_winner_id = p_user_id THEN
                RAISE EXCEPTION 'Claimant cannot oppose own claim';
            END IF;
            IF v_challenge.host_id != p_user_id AND v_challenge.opponent_id != p_user_id THEN
                RAISE EXCEPTION 'Not a participant of this challenge';
            END IF;

            UPDATE challenges
            SET status = 'disputed',
                disputed_by_id = p_user_id,
                dispute_reason = p_reason,
                dispute_proof_url = p_proof_url,
                dispute_comment = p_comment,
                disputed_at = NOW(),
                updated_at = NOW()
            WHERE id = p_challenge_id;

            INSERT INTO notifications (user_id, title, message)
            VALUES 
                (v_challenge.host_id, '🚨 Challenge Disputed', 'An objection was raised on your 1v1 match. Admin Tribunal is reviewing evidence.'),
                (v_challenge.opponent_id, '🚨 Challenge Disputed', 'Your objection was recorded. Admin Tribunal is reviewing evidence.');

            RETURN jsonb_build_object('success', true, 'message', 'Objection recorded. Escalated to Admin Tribunal.');
        END;
        $body$ LANGUAGE plpgsql SECURITY DEFINER;

        -- 8. Atomic Function: p2p_report_issue
        CREATE OR REPLACE FUNCTION p2p_report_issue(
            p_challenge_id UUID,
            p_user_id UUID,
            p_reason TEXT,
            p_proof_url TEXT DEFAULT '',
            p_comment TEXT DEFAULT ''
        ) RETURNS JSONB AS $body$
        DECLARE
            v_challenge RECORD;
        BEGIN
            SELECT * INTO v_challenge FROM challenges WHERE id = p_challenge_id FOR UPDATE;
            IF NOT FOUND THEN
                RAISE EXCEPTION 'Challenge not found';
            END IF;
            IF v_challenge.host_id != p_user_id AND v_challenge.opponent_id != p_user_id THEN
                RAISE EXCEPTION 'Not a participant of this challenge';
            END IF;

            UPDATE challenges
            SET status = 'disputed',
                disputed_by_id = p_user_id,
                dispute_reason = p_reason,
                dispute_proof_url = p_proof_url,
                dispute_comment = p_comment,
                disputed_at = NOW(),
                updated_at = NOW()
            WHERE id = p_challenge_id;

            INSERT INTO notifications (user_id, title, message)
            VALUES 
                (v_challenge.host_id, '🚨 Match Problem Reported', 'A problem was reported (' || p_reason || '). Admin is reviewing.'),
                (v_challenge.opponent_id, '🚨 Match Problem Reported', 'A problem was reported (' || p_reason || '). Admin is reviewing.');

            RETURN jsonb_build_object('success', true, 'message', 'Problem reported to admin.');
        END;
        $body$ LANGUAGE plpgsql SECURITY DEFINER;

        -- 9. Atomic Function: p2p_auto_settle_expired
        CREATE OR REPLACE FUNCTION p2p_auto_settle_expired()
        RETURNS INTEGER AS $body$
        DECLARE
            v_rec RECORD;
            v_count INT := 0;
        BEGIN
            FOR v_rec IN 
                SELECT * FROM challenges 
                WHERE status = 'claimed' 
                  AND objection_deadline <= NOW() 
                FOR UPDATE SKIP LOCKED
            LOOP
                UPDATE users
                SET withdrawable_balance = withdrawable_balance + v_rec.prize_pool
                WHERE id = v_rec.claimed_winner_id;

                UPDATE challenges
                SET status = 'completed',
                    winner_id = v_rec.claimed_winner_id,
                    updated_at = NOW()
                WHERE id = v_rec.id;

                INSERT INTO transactions (
                    user_id, amount, type, reference_id, description
                ) VALUES (
                    v_rec.claimed_winner_id, v_rec.prize_pool, 'prize', v_rec.id::text, 'Won 1v1 Challenge (Auto-settled)'
                );

                INSERT INTO notifications (user_id, title, message)
                VALUES 
                    (v_rec.claimed_winner_id, '🎉 Auto-Payout Complete!', '15-minute objection window passed with 0 disputes. ' || v_rec.prize_pool || ' Tk credited to your wallet!'),
                    (CASE WHEN v_rec.host_id = v_rec.claimed_winner_id THEN v_rec.opponent_id ELSE v_rec.host_id END, 'Match Finalized', 'Match concluded. Prize awarded to winner.');

                v_count := v_count + 1;
            END LOOP;

            RETURN v_count;
        END;
        $body$ LANGUAGE plpgsql SECURITY DEFINER;

        -- 10. Atomic Function: p2p_admin_resolve
        CREATE OR REPLACE FUNCTION p2p_admin_resolve(
            p_challenge_id UUID,
            p_resolution TEXT,
            p_apply_penalty BOOLEAN DEFAULT FALSE
        ) RETURNS JSONB AS $body$
        DECLARE
            v_challenge RECORD;
            v_winner_id UUID;
            v_loser_id UUID;
        BEGIN
            SELECT * INTO v_challenge FROM challenges WHERE id = p_challenge_id FOR UPDATE;
            IF NOT FOUND THEN
                RAISE EXCEPTION 'Challenge not found';
            END IF;
            IF v_challenge.status != 'disputed' THEN
                RAISE EXCEPTION 'Challenge is not disputed';
            END IF;

            IF p_resolution = 'award_host' THEN
                v_winner_id := v_challenge.host_id;
                v_loser_id := v_challenge.opponent_id;
            ELSIF p_resolution = 'award_opponent' THEN
                v_winner_id := v_challenge.opponent_id;
                v_loser_id := v_challenge.host_id;
            ELSIF p_resolution = 'refund_both' THEN
                UPDATE users SET withdrawable_balance = withdrawable_balance + v_challenge.stake WHERE id = v_challenge.host_id;
                UPDATE users SET withdrawable_balance = withdrawable_balance + v_challenge.stake WHERE id = v_challenge.opponent_id;

                INSERT INTO transactions (user_id, amount, type, reference_id, description)
                VALUES 
                    (v_challenge.host_id, v_challenge.stake, 'refund', p_challenge_id::text, '1v1 Match Disputed - Refunded'),
                    (v_challenge.opponent_id, v_challenge.stake, 'refund', p_challenge_id::text, '1v1 Match Disputed - Refunded');

                UPDATE challenges 
                SET status = 'cancelled', admin_resolution = 'refund_both', updated_at = NOW() 
                WHERE id = p_challenge_id;

                RETURN jsonb_build_object('success', true, 'message', 'Both players refunded.');
            ELSE
                RAISE EXCEPTION 'Invalid resolution';
            END IF;

            UPDATE users SET withdrawable_balance = withdrawable_balance + v_challenge.prize_pool WHERE id = v_winner_id;
            INSERT INTO transactions (user_id, amount, type, reference_id, description)
            VALUES (v_winner_id, v_challenge.prize_pool, 'prize', p_challenge_id::text, 'Awarded 1v1 Challenge by Admin Tribunal');

            IF p_apply_penalty AND v_loser_id IS NOT NULL THEN
                UPDATE users SET withdrawable_balance = withdrawable_balance - 10.00 WHERE id = v_loser_id;
                UPDATE users SET withdrawable_balance = withdrawable_balance + 10.00 WHERE id = v_winner_id;

                INSERT INTO transactions (user_id, amount, type, reference_id, description)
                VALUES 
                    (v_loser_id, -10.00, 'dispute_correction', p_challenge_id::text, 'Penalty: False dispute submission'),
                    (v_winner_id, 10.00, 'dispute_correction', p_challenge_id::text, 'Compensation: False dispute by opponent');
            END IF;

            UPDATE challenges
            SET status = 'completed',
                winner_id = v_winner_id,
                admin_resolution = p_resolution,
                admin_penalty_applied = p_apply_penalty,
                updated_at = NOW()
            WHERE id = p_challenge_id;

            INSERT INTO notifications (user_id, title, message)
            VALUES 
                (v_winner_id, '🏆 Admin Tribunal Decision: WIN', 'Admin reviewed the dispute and awarded you victory! ' || v_challenge.prize_pool || ' Tk credited.'),
                (v_loser_id, 'Admin Tribunal Decision', 'Admin reviewed the dispute and resolved in favor of your opponent.');

            RETURN jsonb_build_object('success', true, 'message', 'Challenge resolved by admin.');
        END;
        $body$ LANGUAGE plpgsql SECURITY DEFINER;

        NOTIFY pgrst, 'reload schema';
    `;

    const { data, error } = await supabase.rpc('exec_sql', { query: sql });
    if (error) {
        console.error('❌ RPC Error:', error);
        process.exit(1);
    } else {
        console.log('🎉 Successfully created challenges table and all 10 stored functions via exec_sql RPC!');
    }

    // Quick verification
    const { data: check, error: checkErr } = await supabase.from('challenges').select('*').limit(1);
    console.log('Verification check on challenges table:', { count: check?.length, error: checkErr });
}

migrate();
