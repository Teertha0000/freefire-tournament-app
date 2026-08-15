-- PostgreSQL Schema for FreeFire Tournament App (v2)

-- Clean up existing tables and types (Safe to run since the database is empty right now)
DROP TABLE IF EXISTS notifications CASCADE;
DROP TABLE IF EXISTS match_results CASCADE;
DROP TABLE IF EXISTS withdrawals CASCADE;
DROP TABLE IF EXISTS transactions CASCADE;
DROP TABLE IF EXISTS match_participants CASCADE;
DROP TABLE IF EXISTS match_secrets CASCADE;
DROP TABLE IF EXISTS matches CASCADE;
DROP TABLE IF EXISTS device_bonuses CASCADE;
DROP TABLE IF EXISTS otps CASCADE;
DROP TABLE IF EXISTS users CASCADE;
DROP TABLE IF EXISTS disputes CASCADE;
DROP TABLE IF EXISTS match_categories CASCADE;

DROP TYPE IF EXISTS user_status CASCADE;
DROP TYPE IF EXISTS match_status CASCADE;
DROP TYPE IF EXISTS transaction_type CASCADE;
DROP TYPE IF EXISTS withdrawal_status CASCADE;
-- Enums
CREATE TYPE user_status AS ENUM ('active', 'banned');
CREATE TYPE match_status AS ENUM ('upcoming', 'ongoing', 'calculating', 'completed', 'cancelled', 'delayed');
CREATE TYPE transaction_type AS ENUM ('deposit', 'withdrawal', 'match_fee', 'prize', 'refund', 'manual_adjustment', 'referral_bonus', 'prize_reversal', 'dispute_correction');
CREATE TYPE withdrawal_status AS ENUM ('pending', 'approved', 'rejected');

-- Users Table
CREATE TABLE users (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email VARCHAR(255) UNIQUE NOT NULL,
    ign VARCHAR(50),
    uid VARCHAR(20),
    bonus_balance DECIMAL(10, 2) DEFAULT 0.00,
    withdrawable_balance DECIMAL(10, 2) DEFAULT 0.00,
    status user_status DEFAULT 'active',
    role VARCHAR(20) DEFAULT 'user',
    referral_code VARCHAR(20) UNIQUE NOT NULL,
    referred_by UUID REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- We no longer need the custom otps table because Supabase Auth handles it natively!
-- DROP TABLE IF EXISTS otps CASCADE;

-- Match Categories (Dynamic Tabs)
CREATE TABLE match_categories (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) UNIQUE NOT NULL,
    sort_order INT DEFAULT 0
);

-- Device Tracking (For Bonus Farming Prevention)
CREATE TABLE device_bonuses (
    device_token VARCHAR(255) PRIMARY KEY,
    user_id UUID REFERENCES users(id),
    claimed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Matches Table
CREATE TABLE matches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(100) NOT NULL,
    category VARCHAR(50) REFERENCES match_categories(name) ON DELETE CASCADE,
    entry_fee DECIMAL(10, 2) NOT NULL,
    total_spots INT NOT NULL,
    prize_pool DECIMAL(10, 2) NOT NULL,
    per_kill_prize DECIMAL(10, 2) DEFAULT 0.00,
    first_prize DECIMAL(10, 2) DEFAULT 0.00,
    second_prize DECIMAL(10, 2) DEFAULT 0.00,
    third_prize DECIMAL(10, 2) DEFAULT 0.00,
    status match_status DEFAULT 'upcoming',
    start_time TIMESTAMP WITH TIME ZONE NOT NULL,
    min_players INT DEFAULT 10,
    result_submission_deadline TIMESTAMP WITH TIME ZONE,
    filled_spots INTEGER DEFAULT 0,
    admin_proof_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Match Secrets (Sensitive Room Details)
CREATE TABLE match_secrets (
    match_id UUID PRIMARY KEY REFERENCES matches(id) ON DELETE CASCADE,
    room_id VARCHAR(50),
    room_password VARCHAR(50)
);

-- Match Participants (Joining a match)
CREATE TABLE match_participants (
    match_id UUID REFERENCES matches(id),
    user_id UUID REFERENCES users(id),
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (match_id, user_id) -- Prevents duplicate joining
);

-- Transactions Ledger (Immutable Audit Trail)
CREATE TABLE transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) NOT NULL,
    amount DECIMAL(10, 2) NOT NULL, -- Positive for deposits/prizes, Negative for fees/withdrawals
    type transaction_type NOT NULL,
    reference_id VARCHAR(100), -- Can be match_id, withdrawal_id, or deposit_id
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Withdrawals Table
CREATE TABLE withdrawals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) NOT NULL,
    amount DECIMAL(10, 2) NOT NULL,
    payment_method VARCHAR(20) NOT NULL, -- e.g., 'bkash', 'nagad'
    phone_number VARCHAR(15) NOT NULL,
    status withdrawal_status DEFAULT 'pending',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Match Results & Proofs
CREATE TABLE match_results (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    match_id UUID REFERENCES matches(id) NOT NULL,
    user_id UUID REFERENCES users(id),
    kills INT NOT NULL DEFAULT 0,
    rank INT NOT NULL DEFAULT 0,
    proof_image_url TEXT,
    prize_awarded DECIMAL(10, 2) DEFAULT 0.00,
    status VARCHAR(20) DEFAULT 'pending',
    admin_comment TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(match_id, user_id) -- One result per user per match
);

-- Notifications
CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) NOT NULL,
    title VARCHAR(100) NOT NULL,
    message TEXT NOT NULL,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Disputes (User-to-Admin Problem Reports)
CREATE TABLE disputes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    match_id UUID REFERENCES matches(id) NOT NULL,
    user_id UUID REFERENCES users(id) NOT NULL,
    message TEXT NOT NULL,
    status VARCHAR(20) DEFAULT 'pending',  -- pending, investigating, resolved
    admin_response TEXT,
    prize_correction DECIMAL(10, 2) DEFAULT 0.00,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    resolved_at TIMESTAMP WITH TIME ZONE
);

-- ==========================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ==========================================
-- This secures the database so hackers cannot manipulate the app via the Supabase API.

ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE device_bonuses ENABLE ROW LEVEL SECURITY;
ALTER TABLE matches ENABLE ROW LEVEL SECURITY;
ALTER TABLE match_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE withdrawals ENABLE ROW LEVEL SECURITY;
ALTER TABLE match_results ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE disputes ENABLE ROW LEVEL SECURITY;
ALTER TABLE match_secrets ENABLE ROW LEVEL SECURITY;

-- 1. Matches & Participants are public to READ (so the app can show them)
CREATE POLICY "Matches are viewable by everyone" ON matches FOR SELECT USING (true);
CREATE POLICY "Participants are viewable by everyone" ON match_participants FOR SELECT USING (true);
CREATE POLICY "Results are viewable by everyone" ON match_results FOR SELECT USING (true);

-- Participants can view secrets
CREATE POLICY "Participants can view secrets" ON match_secrets FOR SELECT
USING (EXISTS (SELECT 1 FROM match_participants WHERE match_id = match_secrets.match_id AND user_id::text = current_setting('request.jwt.claims', true)::json->>'sub'));

-- 2. Users can only READ their own private data
CREATE POLICY "Users can view own profile" ON users FOR SELECT USING (id::text = current_setting('request.jwt.claims', true)::json->>'sub');
CREATE POLICY "Users can view own transactions" ON transactions FOR SELECT USING (user_id::text = current_setting('request.jwt.claims', true)::json->>'sub');
CREATE POLICY "Users can view own withdrawals" ON withdrawals FOR SELECT USING (user_id::text = current_setting('request.jwt.claims', true)::json->>'sub');
CREATE POLICY "Users can view own notifications" ON notifications FOR SELECT USING (user_id::text = current_setting('request.jwt.claims', true)::json->>'sub');
CREATE POLICY "Users can view own disputes" ON disputes FOR SELECT USING (user_id::text = current_setting('request.jwt.claims', true)::json->>'sub');

-- ALL WRITES (Inserts, Updates, Deletes) are strictly blocked for the mobile app. 
-- The Node.js Backend (using the SERVICE_ROLE_KEY) will handle all writes securely!

-- ==========================================
-- ATOMIC BALANCE UPDATE FUNCTION (Race-Condition Proof)
-- ==========================================
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

-- ==========================================
-- FILLED SPOTS COUNTER TRIGGER
-- ==========================================
CREATE OR REPLACE FUNCTION update_filled_spots()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE matches SET filled_spots = filled_spots + 1 WHERE id = NEW.match_id;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE matches SET filled_spots = filled_spots - 1 WHERE id = OLD.match_id;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trigger_update_filled_spots
AFTER INSERT OR DELETE ON match_participants
FOR EACH ROW EXECUTE FUNCTION update_filled_spots();

-- ==========================================
-- STORAGE BUCKETS & POLICIES (Supabase Storage)
-- ==========================================
-- Create the match_proofs bucket if it doesn't exist
INSERT INTO storage.buckets (id, name, public) 
VALUES ('match_proofs', 'match_proofs', true)
ON CONFLICT (id) DO NOTHING;

-- Storage RLS: Anyone can read, but only authenticated users can upload
DROP POLICY IF EXISTS "Public Access to Match Proofs" ON storage.objects;
CREATE POLICY "Public Access to Match Proofs" 
ON storage.objects FOR SELECT 
USING (bucket_id = 'match_proofs');

DROP POLICY IF EXISTS "Authenticated Users can upload Match Proofs" ON storage.objects;
CREATE POLICY "Authenticated Users can upload Match Proofs" 
ON storage.objects FOR INSERT 
WITH CHECK (
    bucket_id = 'match_proofs' 
    AND auth.role() = 'authenticated'
);

NOTIFY pgrst, 'reload schema';

-- Trigger to sync auth.users to public.users
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.users (id, email, referral_code)
  VALUES (new.id, new.email, upper(substr(md5(random()::text), 1, 8)));
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

