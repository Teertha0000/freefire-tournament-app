const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_KEY
);

async function run() {
  console.log('--- Adding columns to match_categories via Supabase ---');
  
  // We can test if columns exist by selecting them
  const { data, error } = await supabase.from('match_categories').select('*').limit(1);
  console.log('Current sample row:', data);

  // Let's create category_banners storage bucket in Supabase if not exists
  const { data: buckets, error: bErr } = await supabase.storage.getBucket('hero_banners');
  console.log('hero_banners bucket exists:', !!buckets);

  // Let's also ensure category_banners bucket is available or hero_banners is public
  const { data: catBucket, error: cErr } = await supabase.storage.createBucket('category_banners', {
    public: true
  });
  console.log('Created category_banners bucket or status:', catBucket, cErr?.message);
}

run();
