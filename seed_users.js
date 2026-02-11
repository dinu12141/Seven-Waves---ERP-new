import { createClient } from '@supabase/supabase-js'

const supabaseUrl = 'https://todvadutluzjkjwzugpi.supabase.co'
const supabaseKey =
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRvZHZhZHV0bHV6amtqd3p1Z3BpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzAwODk1ODQsImV4cCI6MjA4NTY2NTU4NH0.gql4tP6qIFBdkktmrZBONlnzcacLOurb2Yyh8G8Vx9g'

const supabase = createClient(supabaseUrl, supabaseKey)

const users = [
  { email: 'admin@sevenwaves.com', password: 'password123', role: 'Z_ALL', name: 'System Admin' },
  {
    email: 'manager@sevenwaves.com',
    password: 'password123',
    role: 'Z_STOCK_MGR',
    name: 'Store Manager',
  },
  {
    email: 'kitchen@sevenwaves.com',
    password: 'password123',
    role: 'Z_PROD_STAFF',
    name: 'Head Chef',
  },
  {
    email: 'waiter@sevenwaves.com',
    password: 'password123',
    role: 'Z_SALES_STAFF',
    name: 'Main Waiter',
  },
  {
    email: 'cashier@sevenwaves.com',
    password: 'password123',
    role: 'Z_SALES_STAFF',
    name: 'Front Desk Cashier',
  },
  {
    email: 'finance@sevenwaves.com',
    password: 'password123',
    role: 'Z_FINANCE',
    name: 'Finance Officer',
  },
  { email: 'hr@sevenwaves.com', password: 'password123', role: 'Z_HR_MANAGER', name: 'HR Manager' },
]

async function seedUsers() {
  console.log('🚀 Starting user seeding for NEW PROJECT (Seven Waves ERP)...')

  for (const user of users) {
    try {
      console.log(`Creating user: ${user.email}...`)
      // 1. Sign Up User
      const { data, error } = await supabase.auth.signUp({
        email: user.email,
        password: user.password,
        options: {
          data: {
            full_name: user.name,
            role: user.role,
          },
        },
      })

      if (error) {
        console.error(`❌ Failed to create ${user.email}:`, error.message)
      } else if (data.user) {
        console.log(`✅ Created ${user.email} (ID: ${data.user.id})`)

        // 2. Ensure Profile Exists (Trigger might do it if I had one, but manual is safer)
        const { error: profileError } = await supabase.from('profiles').upsert({
          id: data.user.id,
          full_name: user.name,
          role: user.role,
        })
        if (profileError) console.error('  -> Profile Error:', profileError.message)

        // 3. Assign User Role
        const { data: roleData } = await supabase
          .from('roles')
          .select('id')
          .eq('code', user.role)
          .single()
        if (roleData) {
          const { error: urError } = await supabase.from('user_roles').upsert(
            {
              user_id: data.user.id,
              role_id: roleData.id,
            },
            { onConflict: 'user_id, role_id' },
          )
          if (urError) console.error('  -> User Role Error:', urError.message)
          else console.log('  -> Role Assigned')
        }
      }
    } catch (err) {
      console.error(`❌ Error processing ${user.email}:`, err)
    }
    // Wait a bit to avoid rate limits
    await new Promise((r) => setTimeout(r, 1000))
  }
}

seedUsers()
