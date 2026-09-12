import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';
dotenv.config();
const supabase = createClient('https://api.teertha.space', process.env.SUPABASE_SERVICE_KEY);
async function run() {
  const { data, error } = await supabase.from('withdrawals').select('*, users(ign, phone)');
  console.log('DATA:', JSON.stringify(data, null, 2));
  console.log('ERROR:', error);
}
run();
