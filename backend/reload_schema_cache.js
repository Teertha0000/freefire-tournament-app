require('dotenv').config();
const { Client } = require('pg');

async function run() {
    const client = new Client({ connectionString: process.env.DATABASE_URL });
    await client.connect();
    console.log('Connected to DB. Reloading schema cache...');
    try {
        await client.query("NOTIFY pgrst, 'reload schema';");
        console.log('Schema cache reloaded successfully.');
    } catch (e) {
        console.error('Error:', e);
    } finally {
        await client.end();
    }
}
run();
