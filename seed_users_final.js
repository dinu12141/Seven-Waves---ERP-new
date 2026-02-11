import { createClient } from '@supabase/supabase-js'

const supabaseUrl = 'https://mvvuegptxjykhzpatsmn.supabase.co'
const supabaseKey =
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im12dnVlZ3B0eGp5a2h6cGF0c21uIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njg5ODg0MzEsImV4cCI6MjA4NDU2NDQzMX0.orDxecxqi_58T-sewtexcl_ilRa_JvRzAJVkFp2NR7k'

const supabase = createClient(supabaseUrl, supabaseKey)

const users = [
  { email: 'admin@sevenwaves.com', password: 'password123', role: 'Z_ALL', name: 'System Admin' },
]

async function seedUsers() {
  console.log('🚀 Seeding Admin on mvvuegptxjykhzpatsmn...')

  for (const user of users) {
    try {
      console.log(`Checking/Creating user: ${user.email}...`)

      // 1. Try Login first (to see if exists)
      const { data: loginData, error: loginError } = await supabase.auth.signInWithPassword({
        email: user.email,
        password: user.password,
      })

      let userId = loginData?.user?.id

      if (userId) {
        console.log(`✅ User exists and logged in: ${userId}`)
      } else {
        console.log(`User not found or login failed. Attempting signup...`)
        // 2. Sign Up User
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
          console.error(`❌ Signup Failed:`, error.message)
          continue
        }
        userId = data.user.id
        console.log(`✅ Created User: ${userId}`)
      }

      // 3. Ensure Profile
      if (userId) {
        const { error: profileError } = await supabase.from('profiles').upsert({
          id: userId,
          full_name: user.name,
          role: user.role,
        })
        if (profileError) console.error('  -> Profile Error:', profileError.message)
        else console.log('  -> Profile Synced')

        // 4. Assign Role
        const { data: roleData, error: roleError } = await supabase
          .from('roles')
          .select('id')
          .eq('code', user.role)
          .single()
        if (roleData) {
          const { error: urError } = await supabase.from('user_roles').upsert(
            {
              user_id: userId,
              role_id: roleData.id,
            },
            { onConflict: 'user_id, role_id' },
          )
          if (urError) console.error('  -> User Role Error:', urError.message)
          else console.log('  -> Role Assigned')
        } else {
          console.log('  -> Role Z_ALL not found in DB! (Check migration)')
        }
      }
    } catch (err) {
      console.error(`❌ Error processing ${user.email}:`, err)
    }
  }
}

seedUsers()
