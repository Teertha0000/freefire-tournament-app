import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';
dotenv.config();
const supabase = createClient('https://api.teertha.space', process.env.SUPABASE_SERVICE_KEY);
async function run() {
  const { error } = await supabase.rpc('exec_sql', {
      query: `
          CREATE POLICY "Admins can view all withdrawals" 
          ON withdrawals FOR SELECT 
          USING (EXISTS (SELECT 1 FROM users WHERE users.id = auth.uid() AND users.role = 'admin'));
      `
  });
  console.log(error || 'Success');
}
run();
