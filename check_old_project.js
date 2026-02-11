import { createClient } from '@supabase/supabase-js'

const oldUrl = 'https://mvvuegptxjykhzpatsmn.supabase.co'
const oldKey =
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im12dnVlZ3B0eGp5a2h6cGF0c21uIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njg5ODg0MzEsImV4cCI6MjA4NDcxNDQzMX0.orDxecxqi_58T-sewtexcl_ilRa_JvRzAJVkFp2NR7k'

const supabase = createClient(oldUrl, oldKey)

async function checkOldProject() {
  console.log('Checking OLD Project (mvvuegptxjykhzpatsmn)...')

  // 1. Check Tables
  try {
    const { data: tables, error } = await supabase
      .from('restaurant_tables')
      .select('count', { count: 'exact', head: true })
    if (error) {
      console.log('❌ Error accessing restaurant_tables:', error.message)
    } else {
      console.log('✅ restaurant_tables exists!')
    }
  } catch (e) {
    console.log('Error checking tables:', e)
  }

  // 2. Check Auth Login (Test User)
  try {
    const { data, error } = await supabase.auth.signInWithPassword({
      email: 'test@test.com',
      password: 'password123',
    })
    console.log(
      'Auth Check Result:',
      error
        ? `❌ Error: ${error.message}`
        : '✅ Login Succeeded (or invalid creds but active service)',
    )
    if (error?.status === 500) console.log('⚠️ THIS PROJECT ALSO HAS 500 ERROR?')
  } catch (e) {
    console.log('Auth Exception:', e)
  }
}

checkOldProject()
