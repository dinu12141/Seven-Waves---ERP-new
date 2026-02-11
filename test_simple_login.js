import { createClient } from '@supabase/supabase-js'

const supabaseUrl = 'https://iqbloarmocgkfqkgboen.supabase.co'
const supabaseKey =
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlxYmxvYXJtb2Nna2Zxa2dib2VuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjkxMzk4MjQsImV4cCI6MjA4NDcxNTgyNH0.QT1gfHCmQ0XM58zOkUiLigh5g-RqD-NV5JCssjV523U'

// Disable autoRefreshToken to isolate login issue
const supabase = createClient(supabaseUrl, supabaseKey, {
  auth: {
    autoRefreshToken: false,
    persistSession: false,
  },
})

async function testSimpleLogin() {
  console.log('Testing simple login...')
  try {
    const { data, error } = await supabase.auth.signInWithPassword({
      email: 'admin@sevenwaves.com',
      password: 'password123',
    })

    if (error) {
      console.log('Error Details:', JSON.stringify(error, null, 2))
    } else {
      console.log('Success:', data.user.id)
    }
  } catch (e) {
    console.log('Exception:', e)
  }
}

testSimpleLogin()
