import { createClient } from '@supabase/supabase-js'

const url = 'https://mvvuegptxjykhzpatsmn.supabase.co'
const key =
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im12dnVlZ3B0eGp5a2h6cGF0c21uIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njg5ODg0MzEsImV4cCI6MjA4NDU2NDQzMX0.orDxecxqi_58T-sewtexcl_ilRa_JvRzAJVkFp2NR7k'

const supabase = createClient(url, key)

async function checkSchema() {
  console.log('Checking Schema on mvvuegptxjykhzpatsmn...')

  const tables = ['restaurant_tables', 'roles', 'permissions', 'user_roles', 'profiles']

  for (const table of tables) {
    const { error } = await supabase.from(table).select('count', { count: 'exact', head: true })
    if (!error) {
      console.log(`✅ Table '${table}' exists.`)
    } else {
      console.log(`❌ Table '${table}' check failed: ${error.message}`)
    }
  }
}

checkSchema()
