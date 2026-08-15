const { Client } = require('pg');

async function run() {
    const client = new Client({
        connectionString: `postgresql://postgres:ihri7bpmrgswqcwbbhirewevnyzix43j@187.127.207.189:5432/postgres`
    });

    try {
        await client.connect();
        console.log(`Connected to database.`);
        
        await client.query(`
            ALTER TABLE match_categories ENABLE ROW LEVEL SECURITY;
            DROP POLICY IF EXISTS "Categories viewable by everyone" ON match_categories;
            CREATE POLICY "Categories viewable by everyone" ON match_categories FOR SELECT USING (true);
        `);
        
        const res = await client.query(`SELECT * FROM match_categories;`);
        console.log(`Categories:`, res.rows);
        await client.end();
    } catch (e) {
        console.log(`Failed. Error: ${e.message}`);
    }
}

run();
