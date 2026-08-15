require('dotenv').config();
const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_KEY
);

async function makeAdminAndAddBalance() {
    console.log("Updating user...");
    const { data, error } = await supabase
        .from('users')
        .update({ 
            role: 'admin', 
            bonus_balance: 5000, 
            withdrawable_balance: 5000 
        })
        .eq('email', 'YOUR_EMAIL@gmail.com')
        .select();

    if (error) {
        console.error("Error updating user:", error);
    } else {
        console.log("Successfully updated:", data);
    }
}

makeAdminAndAddBalance();
