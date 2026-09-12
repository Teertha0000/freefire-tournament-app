import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';
dotenv.config();

const supabase = createClient('https://api.teertha.space', process.env.SUPABASE_SERVICE_KEY);

async function run() {
  console.log('Seeding demo disputes...');

  // Get a user
  const { data: users, error: userError } = await supabase.from('users').select('id, ign').limit(1);
  if (userError || !users || users.length === 0) {
    console.error('Error fetching users:', userError);
    return;
  }
  const userId = users[0].id;
  const ign = users[0].ign || 'Test Player';

  // Get a match
  const { data: matches, error: matchError } = await supabase.from('matches').select('id, title').limit(1);
  if (matchError || !matches || matches.length === 0) {
    console.error('Error fetching matches:', matchError);
    return;
  }
  const matchId = matches[0].id;

  const demoDisputes = [
    {
      user_id: userId,
      match_id: matchId,
      message: `The admin didn't give me the prize for my kills! I got 5 kills but was only paid for 3. Please check the screenshot I uploaded in the results.`,
      status: 'pending'
    },
    {
      user_id: userId,
      match_id: matchId,
      message: `Someone was using hacks in the game, they headshot everyone through walls. I want my entry fee back.`,
      status: 'resolved',
      admin_response: 'We investigated and banned the hacker. Your entry fee has been refunded.',
      prize_correction: 20
    }
  ];

  const { error: insertError } = await supabase.from('disputes').insert(demoDisputes);
  
  if (insertError) {
    console.error('Error inserting disputes:', insertError);
  } else {
    console.log('Demo disputes seeded successfully!');
  }
}

run();
