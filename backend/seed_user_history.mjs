import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';
dotenv.config();

const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_KEY);

async function seed() {
    const { data: user } = await supabase.from('users').select('id').eq('email', 'mredulxyz@gmail.com').single();
    if (!user) {
        console.error("User mredulxyz@gmail.com not found");
        return;
    }
    const userId = user.id;

    console.log("Found user:", userId);

    // Create 3 completed matches
    const matches = [
        {
            title: "CS RANK PUSH - GRANDMASTER",
            category: "CS",
            entry_fee: 50,
            prize_pool: 200,
            first_prize: 200,
            second_prize: 0,
            third_prize: 0,
            per_kill_prize: 0,
            total_spots: 4,
            filled_spots: 4,
            status: "completed",
            start_time: new Date(Date.now() - 1000 * 60 * 60 * 24 * 2).toISOString(), // 2 days ago
            result_submission_deadline: new Date(Date.now() - 1000 * 60 * 60 * 24 * 1).toISOString(),
        },
        {
            title: "SOLO SURVIVAL BATTLE",
            category: "BR",
            entry_fee: 20,
            prize_pool: 500,
            first_prize: 300,
            second_prize: 150,
            third_prize: 50,
            per_kill_prize: 5,
            total_spots: 48,
            filled_spots: 48,
            status: "completed",
            start_time: new Date(Date.now() - 1000 * 60 * 60 * 24 * 5).toISOString(), // 5 days ago
            result_submission_deadline: new Date(Date.now() - 1000 * 60 * 60 * 24 * 4).toISOString(),
        }
    ];

    for (const m of matches) {
        const { data: insertedMatch, error: matchErr } = await supabase.from('matches').insert(m).select().single();
        if (matchErr) {
            console.error("Match insert error:", matchErr);
            continue;
        }

        const matchId = insertedMatch.id;

        // Add participant
        await supabase.from('match_participants').insert({ match_id: matchId, user_id: userId });

        // Add match result
        let prize = 0;
        let kills = 0;
        let rank = 1;
        
        if (m.category === 'CS') {
            prize = 200;
            kills = 12;
            rank = 1;
        } else {
            prize = 330; // 300 + 6*5
            kills = 6;
            rank = 1;
        }

        await supabase.from('match_results').insert({
            match_id: matchId,
            user_id: userId,
            kills: kills,
            rank: rank,
            status: 'approved',
            prize_awarded: prize,
            admin_comment: 'Auto-Verified'
        });

        // Add prize transaction
        await supabase.from('transactions').insert({
            user_id: userId,
            amount: prize,
            type: 'prize',
            reference_id: matchId,
            description: `Prize for Match (Rank: ${rank}, Kills: ${kills}) - Auto-Verified`
        });
        
        // Also deduct entry fee to make it realistic
        await supabase.from('transactions').insert({
            user_id: userId,
            amount: -m.entry_fee,
            type: 'match_fee',
            reference_id: matchId,
            description: `Joined Match: ${m.title}`
        });
        
        console.log(`Seeded match ${matchId} with prize ${prize}`);
    }

    console.log("Done seeding user history.");
}

seed().catch(console.error);
