import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';
dotenv.config();
const supabase = createClient('https://api.teertha.space', process.env.SUPABASE_SERVICE_KEY);
async function main() {
  const { data: matches } = await supabase.from('matches').select('id, title');
  for (const m of matches) {
    const newTitle = m.title.replace(/\s*\(.*?\)/g, '');
    if (newTitle !== m.title) {
      await supabase.from('matches').update({ title: newTitle }).eq('id', m.id);
    }
  }
  console.log('Cleaned up titles');
}
main();
