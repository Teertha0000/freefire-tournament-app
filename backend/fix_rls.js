require('dotenv').config();
const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_KEY
);

async function run() {
    console.log("Fixing RLS for match_categories...");
    
    // Enable RLS and add a SELECT policy
    const { error } = await supabase.rpc('exec_sql', {
        query: `
            ALTER TABLE match_categories ENABLE ROW LEVEL SECURITY;
            DROP POLICY IF EXISTS "Categories viewable by everyone" ON match_categories;
            CREATE POLICY "Categories viewable by everyone" ON match_categories FOR SELECT USING (true);
        `
    });
    
    if (error) {
        console.error("RPC exec_sql might not exist. Let's create it or use another method.", error);
    }
}

run();
