import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';

dotenv.config();

// Use the production API URL but with the service key
const supabaseUrl = 'https://api.teertha.space'; 
const supabaseKey = process.env.SUPABASE_SERVICE_KEY;

if (!supabaseKey) {
  console.error("Missing SUPABASE_SERVICE_KEY");
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseKey);

async function main() {
  console.log("Looking up user mredulxyz@gmail.com...");
  
  // Use auth admin API to find the user by email
  const { data: users, error: err1 } = await supabase.auth.admin.listUsers();
  
  if (err1) {
    console.error("Failed to list users:", err1);
    return;
  }
  
  const user = users.users.find(u => u.email === 'mredulxyz@gmail.com');
  
  if (!user) {
    console.error("User mredulxyz@gmail.com not found!");
    return;
  }
  
  console.log("Found User ID:", user.id);
  
  const notifications = [
    {
      user_id: user.id,
      title: 'Welcome to PlayRift! 🎮',
      message: 'Thanks for joining the platform. Start browsing matches and win real cash!',
      is_read: false,
      created_at: new Date(Date.now() - 5 * 60000).toISOString()
    },
    {
      user_id: user.id,
      title: 'Match Starting Soon',
      message: 'Your match "CS Ranked Cash Cup" is starting in 15 minutes. Get ready!',
      is_read: false,
      created_at: new Date(Date.now() - 60 * 60000).toISOString()
    },
    {
      user_id: user.id,
      title: 'Deposit Successful',
      message: 'Your deposit of ৳50 was successful. The amount has been added to your deposit wallet.',
      is_read: true,
      created_at: new Date(Date.now() - 2 * 24 * 60 * 60000).toISOString()
    }
  ];
  
  const { error: err2 } = await supabase.from('notifications').insert(notifications);
  
  if (err2) {
    console.error("Failed to insert notifications:", err2);
  } else {
    console.log("Successfully inserted dummy notifications!");
  }
}

main();
