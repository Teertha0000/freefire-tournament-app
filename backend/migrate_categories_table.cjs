require('dotenv').config();
const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(
  process.env.SUPABASE_URL || 'https://api.teertha.space',
  process.env.SUPABASE_SERVICE_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpYXQiOjE3ODY0MTkxNDIsImV4cCI6MTg5MzQ1NjAwMCwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlzcyI6InN1cGFiYXNlIn0.O1NRiV49GQUJRfBnCvRSofylezR03L7eD3UTioSMMNY'
);

async function migrate() {
  console.log('Migrating match_categories table schema...');

  const sql = `
    ALTER TABLE match_categories ADD COLUMN IF NOT EXISTS subtitle TEXT DEFAULT 'Tap to view matches';
    ALTER TABLE match_categories ADD COLUMN IF NOT EXISTS image_url TEXT;
    ALTER TABLE match_categories ADD COLUMN IF NOT EXISTS image_opacity NUMERIC DEFAULT 0.40;
    ALTER TABLE match_categories ADD COLUMN IF NOT EXISTS icon_name TEXT DEFAULT 'sports_esports';
    ALTER TABLE match_categories ADD COLUMN IF NOT EXISTS title_color_hex TEXT DEFAULT '#FFFFFF';
    ALTER TABLE match_categories ADD COLUMN IF NOT EXISTS subtitle_color_hex TEXT DEFAULT '#94A3B8';
    ALTER TABLE match_categories ADD COLUMN IF NOT EXISTS accent_color_hex TEXT DEFAULT '#00E5FF';

    -- Enable RLS and add public select / service role all
    ALTER TABLE match_categories ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS "Public read match_categories" ON match_categories;
    CREATE POLICY "Public read match_categories" ON match_categories FOR SELECT USING (true);

    DROP POLICY IF EXISTS "Service role all match_categories" ON match_categories;
    CREATE POLICY "Service role all match_categories" ON match_categories FOR ALL USING (true);

    -- Ensure category_banners bucket is public and has full access
    INSERT INTO storage.buckets (id, name, public) 
    VALUES ('category_banners', 'category_banners', true)
    ON CONFLICT (id) DO UPDATE SET public = true;

    DROP POLICY IF EXISTS "Allow all access to category_banners" ON storage.objects;
    CREATE POLICY "Allow all access to category_banners" ON storage.objects
      FOR ALL
      TO public
      USING (bucket_id = 'category_banners')
      WITH CHECK (bucket_id = 'category_banners');
  `;

  const { data, error } = await supabase.rpc('exec_sql', { query: sql });
  if (error) {
    console.error('RPC Error executing migration:', error);
  } else {
    console.log('✅ Migration succeeded:', data);
  }

  const { data: cols, error: colErr } = await supabase.from('match_categories').select('*').limit(1);
  console.log('Current match_categories schema sample:', cols, colErr);
}

migrate();
