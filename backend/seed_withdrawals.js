import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';

dotenv.config();

const supabaseUrl = 'https://api.teertha.space'; 
const supabaseKey = process.env.SUPABASE_SERVICE_KEY;

if (!supabaseKey) {
  console.error("Missing SUPABASE_SERVICE_KEY");
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseKey);

async function seedWithdrawals() {
  console.log('Seeding demo withdrawals...');

  // Get a user to assign these to
  const { data: users, error: userError } = await supabase.from('users').select('id').limit(1);
  if (userError || !users || users.length === 0) {
    console.error('Error fetching users:', userError);
    return;
  }
  
  const userId = users[0].id;

  const demoWithdrawals = [
    {
      user_id: userId,
      amount: 500.00,
      payment_method: 'bkash',
      phone_number: '01711111111',
      status: 'pending'
    },
    {
      user_id: userId,
      amount: 1000.00,
      payment_method: 'nagad',
      phone_number: '01822222222',
      status: 'pending'
    },
    {
      user_id: userId,
      amount: 250.00,
      payment_method: 'bkash',
      phone_number: '01933333333',
      status: 'approved'
    },
    {
      user_id: userId,
      amount: 750.00,
      payment_method: 'rocket',
      phone_number: '01544444444',
      status: 'rejected'
    }
  ];

  const { error: insertError } = await supabase.from('withdrawals').insert(demoWithdrawals);
  
  if (insertError) {
    console.error('Error inserting withdrawals:', insertError);
  } else {
    console.log('Demo withdrawals seeded successfully!');
  }
}

seedWithdrawals();
