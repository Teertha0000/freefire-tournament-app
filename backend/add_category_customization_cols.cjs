require('dotenv').config();
const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_KEY
);

async function run() {
  console.log("Altering match_categories table...");
  const { error } = await supabase.rpc('exec_sql', {
    query: `
      ALTER TABLE match_categories ADD COLUMN IF NOT EXISTS image_url TEXT;
      ALTER TABLE match_categories ADD COLUMN IF NOT EXISTS image_opacity DECIMAL(3,2) DEFAULT 0.40;
      ALTER TABLE match_categories ADD COLUMN IF NOT EXISTS icon_name VARCHAR(50) DEFAULT 'sports_esports';
      ALTER TABLE match_categories ADD COLUMN IF NOT EXISTS tag VARCHAR(50);

      -- Storage policies for category_banners
      INSERT INTO storage.buckets (id, name, public) 
      VALUES ('category_banners', 'category_banners', true)
      ON CONFLICT (id) DO UPDATE SET public = true;

      DROP POLICY IF EXISTS "Public Access to Category Banners" ON storage.objects;
      CREATE POLICY "Public Access to Category Banners" 
      ON storage.objects FOR SELECT 
      USING (bucket_id = 'category_banners');

      DROP POLICY IF EXISTS "Allow uploading Category Banners" ON storage.objects;
      CREATE POLICY "Allow uploading Category Banners" 
      ON storage.objects FOR ALL 
      USING (bucket_id = 'category_banners')
      WITH CHECK (bucket_id = 'category_banners');

      NOTIFY pgrst, 'reload schema';
    `
  });

  if (error) {
    console.error("RPC Error:", error);
  } else {
    console.log('✅ match_categories columns & storage policies updated successfully.');
  }

  // Let's verify by selecting columns
  const { data, error: selectErr } = await supabase.from('match_categories').select('*');
  console.log('Categories in DB now:', data, selectErr);
}

run();
