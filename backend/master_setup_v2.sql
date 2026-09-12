-- =========================================================================
-- PLAYRIFT (FREEFIRE TOURNAMENT V2) COMPLETE DATABASE RESTORATION SCRIPT
-- Run this in Supabase SQL Editor to restore all tables, functions, RLS & RPCs
-- =========================================================================

-- 1. ENUMS & TYPES
DO $$ BEGIN
    CREATE TYPE user_status AS ENUM ('active', 'banned');
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE match_status AS ENUM ('upcoming', 'ongoing', 'calculating', 'completed', 'delayed', 'cancelled');
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE transaction_type AS ENUM ('deposit', 'withdrawal', 'match_fee', 'prize', 'refund', 'manual_adjustment', 'referral_bonus', 'prize_reversal', 'dispute_correction');
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE withdrawal_status AS ENUM ('pending', 'approved', 'rejected');
EXCEPTION WHEN duplicate_object THEN null; END $$;

-- 2. USERS TABLE
CREATE TABLE IF NOT EXISTS public.users (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email VARCHAR(255) UNIQUE NOT NULL,
    ign VARCHAR(50),
    uid VARCHAR(20),
    phone VARCHAR(15),
    payment_method TEXT DEFAULT 'bKash',
    avatar_id TEXT DEFAULT 'avatar_1',
    bonus_balance DECIMAL(10, 2) DEFAULT 0.00,
    withdrawable_balance DECIMAL(10, 2) DEFAULT 0.00,
    status user_status DEFAULT 'active',
    role VARCHAR(20) DEFAULT 'user',
    referral_code VARCHAR(20) UNIQUE NOT NULL,
    referred_by UUID REFERENCES public.users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 3. MATCH CATEGORIES
CREATE TABLE IF NOT EXISTS public.match_categories (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) UNIQUE NOT NULL,
    sort_order INT DEFAULT 0,
    icon_name VARCHAR(50) DEFAULT 'sports_esports_rounded',
    accent_color_hex VARCHAR(20) DEFAULT '#00E5FF',
    subtitle VARCHAR(100) DEFAULT '',
    is_enabled BOOLEAN DEFAULT TRUE
);

-- Seed default categories if empty
INSERT INTO public.match_categories (name, sort_order, icon_name, accent_color_hex, subtitle, is_enabled)
VALUES 
    ('Bermuda', 1, 'sports_esports_rounded', '#00E5FF', 'Classic Battle Royale', true),
    ('Kalahari', 2, 'fireplace_rounded', '#FF6D00', 'Desert Warfare', true),
    ('Purgatory', 3, 'military_tech_rounded', '#7C4DFF', 'High Altitude Combat', true),
    ('Clash Squad', 4, 'groups_rounded', '#00E676', '4v4 Tactical Duel', true),
    ('Lone Wolf', 5, 'person_rounded', '#FFD600', '1v1 / 2v2 Pure Skill', true)
ON CONFLICT (name) DO NOTHING;

-- 4. MATCHES TABLE (Classic Tournaments)
CREATE TABLE IF NOT EXISTS public.matches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(100) NOT NULL,
    category VARCHAR(50) REFERENCES public.match_categories(name) ON DELETE CASCADE,
    entry_fee DECIMAL(10, 2) NOT NULL,
    total_spots INT NOT NULL,
    prize_pool DECIMAL(10, 2) NOT NULL,
    per_kill_prize DECIMAL(10, 2) DEFAULT 0.00,
    position_prizes JSONB DEFAULT '[]'::jsonb,
    status match_status DEFAULT 'upcoming',
    start_time TIMESTAMP WITH TIME ZONE NOT NULL,
    min_players INT DEFAULT 10,
    result_submission_deadline TIMESTAMP WITH TIME ZONE,
    filled_spots INTEGER DEFAULT 0,
    admin_proof_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 5. MATCH SECRETS (Room ID & Password)
CREATE TABLE IF NOT EXISTS public.match_secrets (
    match_id UUID PRIMARY KEY REFERENCES public.matches(id) ON DELETE CASCADE,
    room_id VARCHAR(50),
    room_password VARCHAR(50)
);

-- 6. MATCH PARTICIPANTS
CREATE TABLE IF NOT EXISTS public.match_participants (
    match_id UUID REFERENCES public.matches(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (match_id, user_id)
);

-- 7. TRANSACTIONS LEDGER
CREATE TABLE IF NOT EXISTS public.transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.users(id) NOT NULL,
    amount DECIMAL(10, 2) NOT NULL,
    type transaction_type NOT NULL,
    reference_id VARCHAR(100),
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 8. WITHDRAWALS
CREATE TABLE IF NOT EXISTS public.withdrawals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.users(id) NOT NULL,
    amount DECIMAL(10, 2) NOT NULL,
    payment_method VARCHAR(20) NOT NULL,
    phone_number VARCHAR(15) NOT NULL,
    status withdrawal_status DEFAULT 'pending',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 9. MATCH RESULTS
CREATE TABLE IF NOT EXISTS public.match_results (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    match_id UUID REFERENCES public.matches(id) ON DELETE CASCADE NOT NULL,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    kills INT NOT NULL DEFAULT 0,
    rank INT NOT NULL DEFAULT 0,
    proof_image_url TEXT,
    prize_awarded DECIMAL(10, 2) DEFAULT 0.00,
    status VARCHAR(20) DEFAULT 'pending',
    admin_comment TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(match_id, user_id)
);

-- 10. NOTIFICATIONS
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    title VARCHAR(100) NOT NULL,
    message TEXT NOT NULL,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 11. DISPUTES
CREATE TABLE IF NOT EXISTS public.disputes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    match_id UUID REFERENCES public.matches(id) ON DELETE CASCADE NOT NULL,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    message TEXT NOT NULL,
    status VARCHAR(20) DEFAULT 'pending',
    admin_response TEXT,
    prize_correction DECIMAL(10, 2) DEFAULT 0.00,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    resolved_at TIMESTAMP WITH TIME ZONE
);

-- 12. HERO SLIDES
CREATE TABLE IF NOT EXISTS public.hero_slides (
    id VARCHAR(100) PRIMARY KEY,
    title VARCHAR(150) DEFAULT '',
    subtitle TEXT DEFAULT '',
    tag VARCHAR(50) DEFAULT 'FEATURED',
    badge_color_hex VARCHAR(20) DEFAULT '#00E5FF',
    title_color_hex VARCHAR(20) DEFAULT '#FFFFFF',
    subtitle_color_hex VARCHAR(20) DEFAULT '#B0B7C3',
    image_url TEXT,
    image_opacity DECIMAL(4, 2) DEFAULT 0.45,
    action_type VARCHAR(50) DEFAULT 'none',
    action_value TEXT,
    title_font_size DECIMAL(5, 2) DEFAULT 24.0,
    subtitle_font_size DECIMAL(5, 2) DEFAULT 13.0,
    tag_font_size DECIMAL(5, 2) DEFAULT 10.0,
    card_height DECIMAL(5, 2) DEFAULT 185.0,
    tag_x DECIMAL(5, 3) DEFAULT 0.060,
    tag_y DECIMAL(5, 3) DEFAULT 0.120,
    title_x DECIMAL(5, 3) DEFAULT 0.060,
    title_y DECIMAL(5, 3) DEFAULT 0.320,
    subtitle_x DECIMAL(5, 3) DEFAULT 0.060,
    subtitle_y DECIMAL(5, 3) DEFAULT 0.680,
    sort_order INT DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 13. 1v1 P2P CHALLENGES TABLE
CREATE TABLE IF NOT EXISTS public.challenges (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    host_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    opponent_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
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
    claimed_winner_id UUID REFERENCES public.users(id),
    claim_proof_url TEXT,
    claim_submitted_at TIMESTAMP WITH TIME ZONE,
    objection_deadline TIMESTAMP WITH TIME ZONE,
    opponent_confirmed_loss BOOLEAN DEFAULT FALSE,
    disputed_by_id UUID REFERENCES public.users(id),
    dispute_reason VARCHAR(100),
    dispute_proof_url TEXT,
    dispute_comment TEXT,
    disputed_at TIMESTAMP WITH TIME ZONE,
    admin_resolution VARCHAR(50),
    admin_penalty_applied BOOLEAN DEFAULT FALSE,
    winner_id UUID REFERENCES public.users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_challenges_status ON public.challenges(status);
CREATE INDEX IF NOT EXISTS idx_challenges_host ON public.challenges(host_id);
CREATE INDEX IF NOT EXISTS idx_challenges_opponent ON public.challenges(opponent_id);

-- Enable Realtime for challenges and matches
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = 'challenges'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE challenges;
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = 'matches'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE matches;
    END IF;
END $$;

-- 14. ROW LEVEL SECURITY (RLS) POLICIES
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.matches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.match_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.match_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.withdrawals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.match_results ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.disputes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.match_secrets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hero_slides ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.challenges ENABLE ROW LEVEL SECURITY;

-- Public Reads
DROP POLICY IF EXISTS "Matches are viewable by everyone" ON matches;
CREATE POLICY "Matches are viewable by everyone" ON matches FOR SELECT USING (true);

DROP POLICY IF EXISTS "Categories viewable by everyone" ON match_categories;
CREATE POLICY "Categories viewable by everyone" ON match_categories FOR SELECT USING (true);

DROP POLICY IF EXISTS "Participants are viewable by everyone" ON match_participants;
CREATE POLICY "Participants are viewable by everyone" ON match_participants FOR SELECT USING (true);

DROP POLICY IF EXISTS "Results are viewable by everyone" ON match_results;
CREATE POLICY "Results are viewable by everyone" ON match_results FOR SELECT USING (true);

DROP POLICY IF EXISTS "Hero slides are viewable by everyone" ON hero_slides;
CREATE POLICY "Hero slides are viewable by everyone" ON hero_slides FOR SELECT USING (true);

DROP POLICY IF EXISTS "Challenges are viewable by everyone" ON challenges;
CREATE POLICY "Challenges are viewable by everyone" ON challenges FOR SELECT USING (true);

DROP POLICY IF EXISTS "Allow all for authenticated/service on challenges" ON challenges;
CREATE POLICY "Allow all for authenticated/service on challenges" ON challenges FOR ALL USING (true) WITH CHECK (true);

-- User Authenticated Reads
DROP POLICY IF EXISTS "Users can view own profile" ON users;
CREATE POLICY "Users can view own profile" ON users FOR SELECT USING (id::text = auth.uid()::text OR true);

DROP POLICY IF EXISTS "Users can view own transactions" ON transactions;
CREATE POLICY "Users can view own transactions" ON transactions FOR SELECT USING (user_id::text = auth.uid()::text);

DROP POLICY IF EXISTS "Users can view own withdrawals" ON withdrawals;
CREATE POLICY "Users can view own withdrawals" ON withdrawals FOR SELECT USING (user_id::text = auth.uid()::text);

DROP POLICY IF EXISTS "Users can view own notifications" ON notifications;
CREATE POLICY "Users can view own notifications" ON notifications FOR SELECT USING (user_id::text = auth.uid()::text);

DROP POLICY IF EXISTS "Users can view own disputes" ON disputes;
CREATE POLICY "Users can view own disputes" ON disputes FOR SELECT USING (user_id::text = auth.uid()::text);

DROP POLICY IF EXISTS "Participants can view secrets" ON match_secrets;
CREATE POLICY "Participants can view secrets" ON match_secrets FOR SELECT
USING (EXISTS (SELECT 1 FROM match_participants WHERE match_id = match_secrets.match_id AND user_id::text = auth.uid()::text));

-- Service role bypasses RLS
GRANT ALL ON ALL TABLES IN SCHEMA public TO service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO service_role;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA public TO service_role;

GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO anon;

-- 15. STORAGE BUCKETS & POLICIES
INSERT INTO storage.buckets (id, name, public) 
VALUES ('match_proofs', 'match_proofs', true)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "Public Access to Match Proofs" ON storage.objects;
CREATE POLICY "Public Access to Match Proofs" 
ON storage.objects FOR SELECT 
USING (bucket_id = 'match_proofs');

DROP POLICY IF EXISTS "Authenticated Users can upload Match Proofs" ON storage.objects;
CREATE POLICY "Authenticated Users can upload Match Proofs" 
ON storage.objects FOR INSERT 
WITH CHECK (bucket_id = 'match_proofs');

-- 16. AUTH SYNC TRIGGER (Creates public.users when a user signs up)
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.users (id, email, referral_code)
  VALUES (new.id, COALESCE(new.email, new.id::text || '@playrift.internal'), upper(substr(md5(random()::text), 1, 8)))
  ON CONFLICT (id) DO NOTHING;
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

-- 17. ATOMIC BALANCE HELPER
CREATE OR REPLACE FUNCTION adjust_balance(
    p_user_id UUID, p_amount DECIMAL, p_balance_type TEXT
) RETURNS void AS $$
BEGIN
    IF p_balance_type = 'bonus' THEN
        UPDATE users SET bonus_balance = bonus_balance + p_amount WHERE id = p_user_id;
    ELSE
        UPDATE users SET withdrawable_balance = withdrawable_balance + p_amount WHERE id = p_user_id;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 18. EXEC_SQL RPC (For automated migrations)
CREATE OR REPLACE FUNCTION exec_sql(query text)
RETURNS void AS $$
BEGIN
  EXECUTE query;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 19. ATOMIC P2P CHALLENGE STORED PROCEDURES (10 Functions)

-- RPC 1: p2p_create_challenge
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

-- RPC 2: p2p_cancel_challenge
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

-- RPC 3: p2p_accept_challenge
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

-- RPC 4: p2p_submit_room
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

-- RPC 5: p2p_claim_victory
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

-- RPC 6: p2p_confirm_loss
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

-- RPC 7: p2p_oppose_claim
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

-- RPC 8: p2p_report_issue
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

-- RPC 9: p2p_auto_settle_expired
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

-- RPC 10: p2p_admin_resolve
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

-- 20. RELOAD SCHEMA CACHE
NOTIFY pgrst, 'reload schema';
