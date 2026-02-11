import { createClient } from '@supabase/supabase-js'

const supabaseUrl = 'https://iqbloarmocgkfqkgboen.supabase.co'
const supabaseKey =
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlxYmxvYXJtb2Nna2Zxa2dib2VuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjkxMzk4MjQsImV4cCI6MjA4NDcxNTgyNH0.QT1gfHCmQ0XM58zOkUiLigh5g-RqD-NV5JCssjV523U'

const supabase = createClient(supabaseUrl, supabaseKey)

async function createBackupAdmin() {
  const email = 'sysadmin@sevenwaves.com'
  const password = 'password123'

  console.log(`Creating backup admin: ${email}...`)

  const { data, error } = await supabase.auth.signUp({
    email,
    password,
    options: {
      data: {
        full_name: 'System Administrator',
        role: 'Z_ALL',
      },
    },
  })

  if (error) {
    console.error('Error creating user:', error.message)
    // If user already exists, we might not know the password.
    // In that case, we can try to sign in (to verify)
    const { error: signInError } = await supabase.auth.signInWithPassword({ email, password })
    if (signInError) {
      console.error(
        'User exists but password does not match. Please try a different email or check console.',
      )
    } else {
      console.log('User already exists and password is correct.')
    }
  } else {
    console.log('User created successfully:', data.user?.id)
    console.log('Please run the SQL script to ensure roles/permissions are assigned.')
  }
}

createBackupAdmin()
