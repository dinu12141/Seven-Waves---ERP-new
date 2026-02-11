import { createClient } from '@supabase/supabase-js'

const supabaseUrl = 'https://iqbloarmocgkfqkgboen.supabase.co'
const supabaseKey =
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlxYmxvYXJtb2Nna2Zxa2dib2VuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjkxMzk4MjQsImV4cCI6MjA4NDcxNTgyNH0.QT1gfHCmQ0XM58zOkUiLigh5g-RqD-NV5JCssjV523U'

const supabase = createClient(supabaseUrl, supabaseKey)

async function createFreshAdmin() {
  const email = 'admin@sevenwaves.com'
  const password = 'password123'

  console.log(`Creating fresh admin: ${email}...`)

  // Note: I already deleted it via SQL, so this should work if API is OK
  const { data, error } = await supabase.auth.signUp({
    email,
    password,
    options: {
      data: {
        full_name: 'System Admin',
        role: 'Z_ALL',
      },
    },
  })

  if (error) {
    console.error('Error creating user:', error.message)
    console.error('Error status:', error.status)
  } else {
    console.log('User created successfully:', data.user?.id)
  }
}

createFreshAdmin()
