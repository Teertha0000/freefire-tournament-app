require('dotenv').config();
const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_KEY
);

async function run() {
    console.log("Fetching categories...");
    const { data, error } = await supabase.from('match_categories').select('*');
    console.log(data);
}

run();
