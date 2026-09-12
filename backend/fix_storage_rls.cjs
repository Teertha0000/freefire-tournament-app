require('dotenv').config();
const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_KEY
);

async function run() {
  console.log('Fixing storage RLS policies in Supabase...');

  const sql = `
    -- Enable public/authenticated access to avatars and match_proofs buckets
    DROP POLICY IF EXISTS "Allow all uploads to avatars" ON storage.objects;
    CREATE POLICY "Allow all uploads to avatars" ON storage.objects
      FOR ALL
      TO public
      USING (bucket_id = 'avatars')
      WITH CHECK (bucket_id = 'avatars');

    DROP POLICY IF EXISTS "Allow all uploads to match_proofs" ON storage.objects;
    CREATE POLICY "Allow all uploads to match_proofs" ON storage.objects
      FOR ALL
      TO public
      USING (bucket_id = 'match_proofs')
      WITH CHECK (bucket_id = 'match_proofs');

    -- Ensure buckets are marked as public
    UPDATE storage.buckets SET public = true WHERE id IN ('avatars', 'match_proofs');
  `;

  const { data, error } = await supabase.rpc('exec_sql', { query: sql });
  if (error) {
    console.error('RPC Error:', error);
  } else {
    console.log('✅ Successfully created storage RLS policies for avatars and match_proofs!');
  }
}

run();
