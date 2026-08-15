require('dotenv').config();
const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_KEY
);

async function run() {
    console.log("Updating users to admin...");
    const { data, error } = await supabase
        .from('users')
        .update({ role: 'admin' })
        .eq('phone', '01535461363')
        .select();
        
    if (error) {
        console.error("Error:", error);
    } else {
        console.log("Success! Updated user:", data);
    }
}

run();
