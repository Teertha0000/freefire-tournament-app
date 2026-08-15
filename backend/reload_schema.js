const { Client } = require('pg');

async function run() {
    const client = new Client({
        connectionString: `postgresql://postgres:ihri7bpmrgswqcwbbhirewevnyzix43j@187.127.207.189:5432/postgres`
    });

    try {
        await client.connect();
        console.log(`Connected to database.`);
        await client.query(`NOTIFY pgrst, 'reload schema';`);
        console.log(`Successfully sent NOTIFY pgrst, 'reload schema'`);
        await client.end();
    } catch (e) {
        console.log(`Failed. Error: ${e.message}`);
    }
}

run();
