import { createClient } from '@supabase/supabase-js'

const supabaseUrl = 'https://mvvuegptxjykhzpatsmn.supabase.co'
const supabaseAnonKey =
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im12dnVlZ3B0eGp5a2h6cGF0c21uIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njg5ODg0MzEsImV4cCI6MjA4NDU2NDQzMX0.orDxecxqi_58T-sewtexcl_ilRa_JvRzAJVkFp2NR7k'

const supabase = createClient(supabaseUrl, supabaseAnonKey)

async function testLogin() {
  const email = 'emp-2026-0013@sevenwaves.com'
  const password = '2J#4QrPEHb'

  console.log(`Attempting login for: ${email}`)

  const { data, error } = await supabase.auth.signInWithPassword({
    email,
    password,
  })

  if (error) {
    console.error('Login Failed:', error.message)
    return
  }

  console.log('Login Successful!')
  console.log('User ID:', data.user.id)

  // Now try to fetch profile (this is where the error likely happens)
  console.log('Fetching profile...')
  const { data: profile, error: profileError } = await supabase
    .from('profiles')
    .select('*')
    .eq('id', data.user.id)
    .single()

  if (profileError) {
    console.error('Profile Fetch Failed:', profileError.message)
    console.error('Profile Error Details:', profileError)
  } else {
    console.log('Profile Fetched Successfully:', profile)
  }
}

testLogin()
