import { createClient } from '@supabase/supabase-js'

const url = 'https://mvvuegptxjykhzpatsmn.supabase.co'
const key =
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im12dnVlZ3B0eGp5a2h6cGF0c21uIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njg5ODg0MzEsImV4cCI6MjA4NDU2NDQzMX0.orDxecxqi_58T-sewtexcl_ilRa_JvRzAJVkFp2NR7k'

const supabase = createClient(url, key)

async function verifyFix() {
  console.log('Verifying Admin Login & Roles...')

  const { data, error } = await supabase.auth.signInWithPassword({
    email: 'admin@sevenwaves.com',
    password: 'password123',
  })

  if (error) {
    console.log('❌ Login Failed:', error.message)
    if (error.message.includes('Invalid login credentials')) {
      console.log(
        '   (User might not exist or password wrong. Please run the SQL script provided.)',
      )
    }
    return
  }

  console.log('✅ Login Successful!')
  console.log('   User ID:', data.user.id)

  // Check Profile
  const { data: profile } = await supabase
    .from('profiles')
    .select('*')
    .eq('id', data.user.id)
    .single()

  if (profile) {
    console.log('✅ Profile Found:', profile.full_name)
    console.log('   Role in Profile:', profile.role || '❌ MISSING (NULL)')

    if (profile.role === 'Z_ALL') {
      console.log('🎉 SUCCESS! Admin access should be working.')
    } else {
      console.log('⚠️ Profile exists but Role is incorrect. Please run the SQL script.')
    }
  } else {
    console.log('❌ Profile Missing. Please run the SQL script.')
  }
}

verifyFix()
