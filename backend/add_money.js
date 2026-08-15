require('dotenv').config();
const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_KEY
);

async function run() {
    console.log("Adding money to admin accounts...");
    
    // Add 1000 to both withdrawable and bonus balance for all admins
    const { data, error } = await supabase
        .from('users')
        .update({ 
            withdrawable_balance: 5000,
            bonus_balance: 5000
        })
        .eq('role', 'admin')
        .select();

    if (error) {
        console.error("Error updating balances:", error);
    } else {
        console.log("Success! Added money to:", data.map(u => u.ign || u.id));
    }
}

run();
