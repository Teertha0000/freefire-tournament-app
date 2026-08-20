require('dotenv').config();
const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_KEY
);

async function run() {
    console.log("Altering users table...");
    const { error } = await supabase.rpc('exec_sql', {
        query: `
            ALTER TABLE users ADD COLUMN IF NOT EXISTS payment_method TEXT DEFAULT 'bKash';
            ALTER TABLE users ADD COLUMN IF NOT EXISTS avatar_id TEXT DEFAULT 'avatar_1';
        `
    });
    
    if (error) {
        console.error("RPC Error:", error);
    } else {
        console.log('Added payment_method and avatar_id successfully.');
    }
}

run();
