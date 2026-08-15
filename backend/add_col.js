require('dotenv').config();
const { Client } = require('pg');

async function run() {
    const client = new Client({ connectionString: process.env.DATABASE_URL });
    await client.connect();
    console.log('Connected to DB. Altering table...');
    try {
        await client.query("ALTER TABLE matches ADD COLUMN IF NOT EXISTS admin_proof_url TEXT;");
        console.log('Added admin_proof_url successfully.');
    } catch (e) {
        console.error('Error:', e);
    } finally {
        await client.end();
    }
}
run();
