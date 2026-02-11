import { createClient } from '@supabase/supabase-js'

const url = 'https://mvvuegptxjykhzpatsmn.supabase.co'
const key =
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im12dnVlZ3B0eGp5a2h6cGF0c21uIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njg5ODg0MzEsImV4cCI6MjA4NDU2NDQzMX0.orDxecxqi_58T-sewtexcl_ilRa_JvRzAJVkFp2NR7k'

const supabase = createClient(url, key)

async function checkConnection() {
  console.log('Testing connection to mvvuegptxjykhzpatsmn...')

  // Try to pick a public table or just check health via a simple query
  // Since I don't know what tables exist for sure, I'll try to select from 'restaurant_tables' which should be there if migration ran,
  // or just handle the error.

  try {
    const { data, error } = await supabase
      .from('restaurant_tables')
      .select('count', { count: 'exact', head: true })

    if (error) {
      console.log('Result:', error.message)
      if (error.code === 'PGRST204') {
        console.log('✅ Connection Successful (Table might be missing, but API reached)')
      } else if (error.message.includes('JWT')) {
        console.log('❌ Connection Failed: Invalid Credentials')
      } else {
        console.log('⚠️ Connection reached but error:', error.message)
      }
    } else {
      console.log('✅ Connection Successful!')
    }
  } catch (e) {
    console.log('Exception:', e.message)
  }
}

checkConnection()
