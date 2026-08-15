const { Client } = require('pg');
require('dotenv').config();

const client = new Client({
  connectionString: process.env.DATABASE_URL
});

async function run() {
  await client.connect();
  try {
    await client.query(`ALTER TABLE public.users ADD COLUMN phone VARCHAR(15);`);
    console.log("Added phone column!");
  } catch (e) {
    console.error("Error adding phone:", e.message);
  }
  
  try {
    await client.query(`NOTIFY pgrst, 'reload schema';`);
    console.log("Reloaded schema!");
  } catch (e) {
    console.error("Error reloading schema:", e.message);
  }
  await client.end();
}

run();
