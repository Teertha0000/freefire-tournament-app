const { Client } = require('pg');

async function run() {
    const client = new Client({
        connectionString: 'postgresql://postgres:ihri7bpmrgswqcwbbhirewevnyzix43j@187.127.207.189:5432/postgres'
    });

    try {
        await client.connect();
        console.log('Connected to Postgres DB.');

        // 1. RLS policies for notifications, match_results, matches, transactions
        await client.query(`
            ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
            DROP POLICY IF EXISTS "Users can view own notifications" ON notifications;
            CREATE POLICY "Users can view own notifications" ON notifications FOR SELECT USING (true);
            DROP POLICY IF EXISTS "Allow inserting notifications" ON notifications;
            CREATE POLICY "Allow inserting notifications" ON notifications FOR INSERT WITH CHECK (true);

            ALTER TABLE match_results ENABLE ROW LEVEL SECURITY;
            DROP POLICY IF EXISTS "Results are viewable by everyone" ON match_results;
            CREATE POLICY "Results are viewable by everyone" ON match_results FOR SELECT USING (true);
            DROP POLICY IF EXISTS "Allow updating match results" ON match_results;
            CREATE POLICY "Allow updating match results" ON match_results FOR UPDATE USING (true) WITH CHECK (true);
            DROP POLICY IF EXISTS "Allow inserting match results" ON match_results;
            CREATE POLICY "Allow inserting match results" ON match_results FOR INSERT WITH CHECK (true);
            DROP POLICY IF EXISTS "Allow deleting match results" ON match_results;
            CREATE POLICY "Allow deleting match results" ON match_results FOR DELETE USING (true);

            ALTER TABLE matches ENABLE ROW LEVEL SECURITY;
            DROP POLICY IF EXISTS "Matches are viewable by everyone" ON matches;
            CREATE POLICY "Matches are viewable by everyone" ON matches FOR SELECT USING (true);
            DROP POLICY IF EXISTS "Allow updating matches" ON matches;
            CREATE POLICY "Allow updating matches" ON matches FOR UPDATE USING (true) WITH CHECK (true);

            ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
            DROP POLICY IF EXISTS "Users can view own transactions" ON transactions;
            CREATE POLICY "Users can view own transactions" ON transactions FOR SELECT USING (true);
            DROP POLICY IF EXISTS "Allow inserting transactions" ON transactions;
            CREATE POLICY "Allow inserting transactions" ON transactions FOR INSERT WITH CHECK (true);
        `);
        console.log('✅ RLS Policies updated successfully.');

        // 2. Storage bucket match_proofs and policies
        await client.query(`
            INSERT INTO storage.buckets (id, name, public) 
            VALUES ('match_proofs', 'match_proofs', true)
            ON CONFLICT (id) DO UPDATE SET public = true;

            DROP POLICY IF EXISTS "Public Access to Match Proofs" ON storage.objects;
            CREATE POLICY "Public Access to Match Proofs" 
            ON storage.objects FOR SELECT 
            USING (bucket_id = 'match_proofs');

            DROP POLICY IF EXISTS "Allow uploading Match Proofs" ON storage.objects;
            CREATE POLICY "Allow uploading Match Proofs" 
            ON storage.objects FOR INSERT 
            WITH CHECK (bucket_id = 'match_proofs');

            DROP POLICY IF EXISTS "Allow updating Match Proofs" ON storage.objects;
            CREATE POLICY "Allow updating Match Proofs" 
            ON storage.objects FOR UPDATE 
            USING (bucket_id = 'match_proofs');
        `);
        console.log('✅ Storage bucket match_proofs configured.');

        // 3. Stored procedure for atomic result review
        await client.query(`
            CREATE OR REPLACE FUNCTION admin_review_result(
                p_result_id UUID,
                p_action TEXT,
                p_prize_amount DECIMAL,
                p_comment TEXT,
                p_user_id UUID DEFAULT NULL,
                p_match_id UUID DEFAULT NULL,
                p_rank INT DEFAULT NULL,
                p_kills INT DEFAULT NULL
            ) RETURNS void AS $$
            BEGIN
                UPDATE match_results 
                SET status = p_action, 
                    prize_awarded = p_prize_amount, 
                    admin_comment = p_comment 
                WHERE id = p_result_id;

                IF p_action = 'rejected' AND p_user_id IS NOT NULL THEN
                    INSERT INTO notifications (user_id, title, message)
                    VALUES (p_user_id, 'Result Rejected', COALESCE(p_comment, 'Your result submission has been rejected.'));
                END IF;

                IF p_action = 'approved' AND p_prize_amount > 0 AND p_user_id IS NOT NULL THEN
                    UPDATE users 
                    SET withdrawable_balance = withdrawable_balance + p_prize_amount 
                    WHERE id = p_user_id;

                    INSERT INTO transactions (user_id, amount, type, reference_id, description)
                    VALUES (
                        p_user_id, 
                        p_prize_amount, 
                        'prize', 
                        COALESCE(p_match_id::text, ''), 
                        'Prize for Match (Rank: ' || COALESCE(p_rank::text, '0') || ', Kills: ' || COALESCE(p_kills::text, '0') || ')'
                    );
                END IF;
            END;
            $$ LANGUAGE plpgsql SECURITY DEFINER;
        `);
        console.log('✅ Stored procedure admin_review_result created.');

        await client.query("NOTIFY pgrst, 'reload schema';");
        console.log('✅ Notified PostgREST schema reload.');

        await client.end();
    } catch (e) {
        console.error('❌ Migration Error:', e);
    }
}

run();
