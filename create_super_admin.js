import { createClient } from '@supabase/supabase-js'

const supabaseUrl = 'https://iqbloarmocgkfqkgboen.supabase.co'
const supabaseKey =
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlxYmxvYXJtb2Nna2Zxa2dib2VuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjkxMzk4MjQsImV4cCI6MjA4NDcxNTgyNH0.QT1gfHCmQ0XM58zOkUiLigh5g-RqD-NV5JCssjV523U'

const supabase = createClient(supabaseUrl, supabaseKey)

async function createSuperAdmin() {
  const uniqueId = Date.now().toString().slice(-4)
  const email = `superadmin${uniqueId}@sevenwaves.com`
  const password = 'password123'

  console.log(`Creating unique superadmin: ${email}...`)

  const { data, error } = await supabase.auth.signUp({
    email,
    password,
    options: {
      data: {
        full_name: 'Super Administrator',
        role: 'Z_ALL',
      },
    },
  })

  if (error) {
    console.error('Error creating user:', error.message)
  } else {
    console.log(`SUCCESS: User created!`)
    console.log(`Email: ${email}`)
    console.log(`Password: ${password}`)
    console.log(`User ID: ${data.user?.id}`)

    // We can't run SQL here, but we'll print it for the MCP tool
    console.log('--- SQL TO RUN ---')
    console.log(`
      INSERT INTO profiles (id, full_name, role) VALUES ('${data.user?.id}', 'Super Administrator', 'Z_ALL') ON CONFLICT (id) DO UPDATE SET role = 'Z_ALL';
      INSERT INTO user_roles (user_id, role_id) SELECT '${data.user?.id}', id FROM roles WHERE code = 'Z_ALL' ON CONFLICT DO NOTHING;
    `)
  }
}

createSuperAdmin()
