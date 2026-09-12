import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';
dotenv.config();

const supabaseUrl = process.env.SUPABASE_URL || 'https://api.teertha.space';
const supabaseKey = process.env.SUPABASE_SERVICE_KEY;

if (!supabaseKey) {
  console.error('SUPABASE_SERVICE_KEY missing in .env');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseKey);

async function seedMatchResults() {
  console.log('--- SEEDING DEMO MATCH RESULTS ---');

  // 1. Fetch calculating match or an ongoing match
  let { data: calculatingMatches } = await supabase
    .from('matches')
    .select('*')
    .eq('status', 'calculating')
    .limit(1);

  let targetMatch = calculatingMatches && calculatingMatches.length > 0 ? calculatingMatches[0] : null;

  if (!targetMatch) {
    console.log('No calculating match found, looking for any match to move to calculating...');
    let { data: anyMatch } = await supabase
      .from('matches')
      .select('*')
      .neq('status', 'cancelled')
      .order('created_at', { ascending: false })
      .limit(1);

    if (anyMatch && anyMatch.length > 0) {
      targetMatch = anyMatch[0];
      await supabase.from('matches').update({ status: 'calculating' }).eq('id', targetMatch.id);
      console.log(`Updated match "${targetMatch.title}" (${targetMatch.id}) status to "calculating".`);
    } else {
      // Create a demo match in calculating state
      console.log('Creating a demo match in calculating state...');
      const { data: newMatch, error: createMatchErr } = await supabase
        .from('matches')
        .insert({
          title: 'PRO CHAMPIONSHIP CS 4V4 [DEMO]',
          category: 'CS',
          entry_fee: 50,
          total_spots: 8,
          filled_spots: 8,
          prize_pool: 350,
          per_kill_prize: 15,
          position_prizes: [200, 100],
          status: 'calculating',
          start_time: new Date().toISOString(),
        })
        .select()
        .single();

      if (createMatchErr) {
        console.error('Error creating demo match:', createMatchErr);
        return;
      }
      targetMatch = newMatch;
    }
  }

  console.log(`Target Match: "${targetMatch.title}" (${targetMatch.id})`);

  // 2. Fetch users to assign results to
  let { data: users } = await supabase.from('users').select('id, ign, phone').limit(5);

  if (!users || users.length === 0) {
    console.error('No users found in database.');
    return;
  }

  console.log(`Found ${users.length} users for demo results.`);

  // High quality demo game screenshot proofs
  const demoProofs = [
    'https://images.unsplash.com/photo-1542751371-adc38448a05e?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1511512578047-dfb367046420?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1538481199705-c710c4e965fc?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1550745165-9bc0b252726f?auto=format&fit=crop&w=800&q=80',
  ];

  const demoSubmissions = [
    { rank: 1, kills: 6, proof_image_url: demoProofs[0] },
    { rank: 2, kills: 4, proof_image_url: demoProofs[1] },
    { rank: 3, kills: 2, proof_image_url: demoProofs[2] },
    { rank: 4, kills: 1, proof_image_url: demoProofs[3] },
  ];

  // Delete previous results on this match to start fresh
  await supabase.from('match_results').delete().eq('match_id', targetMatch.id);

  let insertedCount = 0;
  for (let i = 0; i < Math.min(users.length, demoSubmissions.length); i++) {
    const user = users[i];
    const sub = demoSubmissions[i];

    const { error: insertErr } = await supabase.from('match_results').insert({
      match_id: targetMatch.id,
      user_id: user.id,
      rank: sub.rank,
      kills: sub.kills,
      proof_image_url: sub.proof_image_url,
      status: 'pending',
    });

    if (insertErr) {
      console.error(`Error inserting result for user ${user.ign || user.id}:`, insertErr.message);
    } else {
      console.log(`Inserted Result -> User: ${user.ign || 'Player'}, Rank: ${sub.rank}, Kills: ${sub.kills}`);
      insertedCount++;
    }
  }

  console.log(`--- SUCCESS: Seeded ${insertedCount} demo match results for "${targetMatch.title}" ---`);
}

seedMatchResults();
