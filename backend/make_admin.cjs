const { createClient } = require('@supabase/supabase-js');
const supabaseUrl = 'https://api.teertha.space';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpYXQiOjE3ODY0MTkxNDIsImV4cCI6MTg5MzQ1NjAwMCwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlzcyI6InN1cGFiYXNlIn0.O1NRiV49GQUJRfBnCvRSofylezR03L7eD3UTioSMMNY';
const supabase = createClient(supabaseUrl, supabaseKey);

async function makeAdmin() {
  const { data: user, error: fetchError } = await supabase
    .from('users')
    .select('id')
    .eq('email', 'mredulxyz@gmail.com')
    .single();

  if (fetchError) {
    console.error('Error finding user:', fetchError);
    return;
  }

  const { data, error } = await supabase
    .from('users')
    .update({ role: 'admin' })
    .eq('id', user.id);

  if (error) {
    console.error('Error updating user:', error);
  } else {
    console.log('User made admin successfully!', data);
  }
}

makeAdmin();
