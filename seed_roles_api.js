import { createClient } from '@supabase/supabase-js'

const url = 'https://mvvuegptxjykhzpatsmn.supabase.co'
const key =
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im12dnVlZ3B0eGp5a2h6cGF0c21uIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njg5ODg0MzEsImV4cCI6MjA4NDU2NDQzMX0.orDxecxqi_58T-sewtexcl_ilRa_JvRzAJVkFp2NR7k'

const supabase = createClient(url, key)

async function seedRoles() {
  console.log('Attempting to seed ROLES via API...')

  const roles = [
    {
      code: 'Z_ALL',
      name: 'Administrator',
      description: 'Full system access',
      is_system_role: true,
    },
    {
      code: 'Z_STOCK_MGR',
      name: 'Store Manager',
      description: 'Inventory reports',
      is_system_role: true,
    },
    { code: 'Z_SALES_STAFF', name: 'Cashier/Waiter', description: 'Sales', is_system_role: true },
  ]

  const { error } = await supabase.from('roles').upsert(roles, { onConflict: 'code' })

  if (error) {
    console.log('❌ Failed to insert roles:', error.message)
    console.log('   (Likely RLS blocking. We need SQL access to fix this.)')
  } else {
    console.log('✅ Roles inserted successfully!')
  }
}

seedRoles()
