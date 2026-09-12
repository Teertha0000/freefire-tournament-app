import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';
import crypto from 'crypto';

dotenv.config();

const supabaseUrl = 'https://api.teertha.space'; 
const supabaseKey = process.env.SUPABASE_SERVICE_KEY;

if (!supabaseKey) {
  console.error("Missing SUPABASE_SERVICE_KEY");
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseKey);

async function main() {
  console.log("Looking up user mredulxyz@gmail.com...");
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
  
  const userId = user.id;
  console.log("Found User ID:", userId);

  // Define Matches
  const now = new Date();
  const matches = [
    {
      id: crypto.randomUUID(),
      title: 'CS Ranked Showdown (Upcoming)',
      category: 'CS',
      entry_fee: 20,
      prize_pool: 200,
      status: 'upcoming',
      start_time: new Date(now.getTime() + 60 * 60000).toISOString(),
      total_spots: 48,
      filled_spots: 12
    },
    {
      id: crypto.randomUUID(),
      title: 'BR Cash Cup (Ongoing)',
      category: 'BR',
      entry_fee: 50,
      prize_pool: 500,
      status: 'ongoing',
      start_time: new Date(now.getTime() - 15 * 60000).toISOString(),
      total_spots: 48,
      filled_spots: 48
    },
    {
      id: crypto.randomUUID(),
      title: 'Daily Scrims (Calculating)',
      category: 'BR',
      entry_fee: 10,
      prize_pool: 100,
      status: 'calculating',
      start_time: new Date(now.getTime() - 60 * 60000).toISOString(),
      result_submission_deadline: new Date(now.getTime() + 10 * 60000).toISOString(),
      total_spots: 48,
      filled_spots: 48
    },
    {
      id: crypto.randomUUID(),
      title: 'Weekend Brawl (Completed - Win)',
      category: 'CS',
      entry_fee: 100,
      prize_pool: 1000,
      status: 'completed',
      start_time: new Date(now.getTime() - 24 * 60 * 60000).toISOString(),
      total_spots: 48,
      filled_spots: 48
    },
    {
      id: crypto.randomUUID(),
      title: 'Midnight Madness (Completed - Loss)',
      category: 'BR',
      entry_fee: 30,
      prize_pool: 300,
      status: 'completed',
      start_time: new Date(now.getTime() - 48 * 60 * 60000).toISOString(),
      total_spots: 48,
      filled_spots: 48
    }
  ];

  console.log("Inserting matches...");
  const { error: matchErr } = await supabase.from('matches').insert(matches);
  if (matchErr) {
    console.error("Error inserting matches:", matchErr);
    return;
  }

  // Join user to all these matches
  console.log("Joining user to matches...");
  const participants = matches.map(m => ({
    match_id: m.id,
    user_id: userId
  }));
  
  const { error: partErr } = await supabase.from('match_participants').insert(participants);
  if (partErr) {
    console.error("Error inserting participants:", partErr);
    return;
  }

  // Insert match results for the completed/calculating matches
  console.log("Inserting match results...");
  const results = [
    {
      match_id: matches[2].id, // Calculating
      user_id: userId,
      kills: 5,
      rank: 2,
      screenshot_url: 'https://example.com/proof1.jpg',
      status: 'pending'
    },
    {
      match_id: matches[3].id, // Completed - Win
      user_id: userId,
      kills: 12,
      rank: 1,
      screenshot_url: 'https://example.com/proof2.jpg',
      status: 'approved'
    },
    {
      match_id: matches[4].id, // Completed - Loss
      user_id: userId,
      kills: 1,
      rank: 45,
      screenshot_url: 'https://example.com/proof3.jpg',
      status: 'rejected'
    }
  ];

  const { error: resErr } = await supabase.from('match_results').insert(results);
  if (resErr) {
    console.error("Error inserting results:", resErr);
    return;
  }

  console.log("Successfully seeded My Matches data!");
}

main();
