const { Client } = require('pg');

async function run() {
  const client = new Client({
    connectionString: `postgresql://postgres:ihri7bpmrgswqcwbbhirewevnyzix43j@187.127.207.189:5432/postgres`
  });

  try {
    await client.connect();
    console.log('Connected to Postgres directly.');

    await client.query(`
      ALTER TABLE match_categories ADD COLUMN IF NOT EXISTS subtitle TEXT DEFAULT 'Tap to view matches';
      ALTER TABLE match_categories ADD COLUMN IF NOT EXISTS image_url TEXT;
      ALTER TABLE match_categories ADD COLUMN IF NOT EXISTS image_opacity NUMERIC DEFAULT 0.40;
      ALTER TABLE match_categories ADD COLUMN IF NOT EXISTS icon_name TEXT DEFAULT 'sports_esports';
      ALTER TABLE match_categories ADD COLUMN IF NOT EXISTS title_color_hex TEXT DEFAULT '#FFFFFF';
      ALTER TABLE match_categories ADD COLUMN IF NOT EXISTS subtitle_color_hex TEXT DEFAULT '#94A3B8';
      ALTER TABLE match_categories ADD COLUMN IF NOT EXISTS accent_color_hex TEXT DEFAULT '#00E5FF';

      -- Allow ALL operations on match_categories for anon, authenticated, and service_role
      DROP POLICY IF EXISTS "Categories viewable by everyone" ON match_categories;
      DROP POLICY IF EXISTS "Public read match_categories" ON match_categories;
      DROP POLICY IF EXISTS "Allow all match_categories" ON match_categories;
      
      CREATE POLICY "Allow all match_categories" ON match_categories
        FOR ALL
        TO public
        USING (true)
        WITH CHECK (true);

      -- Ensure category_banners bucket exists, is public, and has open access policy
      INSERT INTO storage.buckets (id, name, public)
      VALUES ('category_banners', 'category_banners', true)
      ON CONFLICT (id) DO UPDATE SET public = true;

      DROP POLICY IF EXISTS "Allow all access to category_banners" ON storage.objects;
      CREATE POLICY "Allow all access to category_banners" ON storage.objects
        FOR ALL
        TO public
        USING (bucket_id = 'category_banners')
        WITH CHECK (bucket_id = 'category_banners');
    `);

    // Notify PostgREST to reload schema cache
    await client.query(`NOTIFY pgrst, 'reload schema';`);

    const res = await client.query(`SELECT * FROM match_categories ORDER BY sort_order ASC;`);
    console.log('✅ Columns added successfully. Current categories in DB:');
    console.log(res.rows);

    await client.end();
  } catch (e) {
    console.error('Migration failed:', e.message);
  }
}

run();
