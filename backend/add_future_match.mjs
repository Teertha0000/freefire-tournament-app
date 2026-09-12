import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';
import crypto from 'crypto';

dotenv.config();
const supabase = createClient('https://api.teertha.space', process.env.SUPABASE_SERVICE_KEY);

async function main() {
  const users = await supabase.auth.admin.listUsers();
  const user = users.data.users.find(u => u.email === 'mredulxyz@gmail.com');
  if (!user) {
    console.error('User not found');
    return;
  }
  
  const userId = user.id;
  const matchId = crypto.randomUUID();
  
  await supabase.from('matches').insert({
    id: matchId,
    title: 'Future Clash (Upcoming)',
    category: 'BR',
    entry_fee: 10,
    prize_pool: 100,
    status: 'upcoming',
    start_time: new Date(Date.now() + 24 * 60 * 60000).toISOString(),
    total_spots: 48,
    filled_spots: 1
  });
  
  await supabase.from('match_participants').insert({ match_id: matchId, user_id: userId });
  console.log('Added future upcoming match!');
}

main();
