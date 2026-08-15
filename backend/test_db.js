const { Client } = require('pg');

async function testConnection(port) {
    const client = new Client({
        connectionString: `postgresql://postgres:ihri7bpmrgswqcwbbhirewevnyzix43j@187.127.207.189:${port}/postgres`
    });

    try {
        await client.connect();
        console.log(`✅ Successfully connected to database on port ${port}!`);
        await client.end();
        return true;
    } catch (e) {
        console.log(`❌ Failed to connect on port ${port}. Error: ${e.message}`);
        return false;
    }
}

async function run() {
    const success5432 = await testConnection(5432);
    if (!success5432) {
        await testConnection(6543);
    }
}

run();
