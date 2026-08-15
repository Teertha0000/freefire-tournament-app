require('dotenv').config();
const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_KEY
);

async function run() {
    console.log("Seeding categories...");
    const categories = [
        { name: 'BR', sort_order: 1 },
        { name: 'CS', sort_order: 2 },
        { name: 'Lone Wolf', sort_order: 3 },
        { name: 'Tournament', sort_order: 4 }
    ];
    
    for (const cat of categories) {
        const { error } = await supabase.from('match_categories').upsert(cat, { onConflict: 'name' });
        if (error) {
            console.error("Error inserting", cat.name, error);
        } else {
            console.log("Inserted", cat.name);
        }
    }
    console.log("Done.");
}

run();
