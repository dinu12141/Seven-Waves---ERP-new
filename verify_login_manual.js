import { createClient } from '@supabase/supabase-js'

// Config from .env
const SUPABASE_URL = 'https://mvvuegptxjykhzpatsmn.supabase.co'
const SUPABASE_KEY =
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im12dnVlZ3B0eGp5a2h6cGF0c21uIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njg5ODg0MzEsImV4cCI6MjA4NDU2NDQzMX0.orDxecxqi_58T-sewtexcl_ilRa_JvRzAJVkFp2NR7k'

const supabase = createClient(SUPABASE_URL, SUPABASE_KEY)

async function testLogin(label, email, password) {
  console.log(`\n--- Testing ${label} (${email}) ---`)
  try {
    const { data, error } = await supabase.auth.signInWithPassword({
      email,
      password,
    })

    if (error) {
      console.log('RESULT: FAIL')
      console.log('Error Message:', error.message)
      console.log('Error Status:', error.status)
    } else {
      console.log('RESULT: SUCCESS')
      console.log('User ID:', data.user.id)
      console.log('Role:', data.user.role)
    }
  } catch (err) {
    console.log('RESULT: CRASH')
    console.error(err)
  }
}

// Run Main
console.log('STARTING TEST...')

// 1. Test Admin (Should work if DB is alive)
await testLogin('ADMIN', 'admin@sevenwaves.com', 'Admin123!')

// 2. Test User from Screenshot
await testLogin('NEW EMP', 'emp-2026-0005@sevenwaves.com', 'Employee123!')

// 3. Test Manual Fix User
await testLogin('MANUAL EMP', 'emp-2026-0003@sevenwaves.com', 'Employee123!')

console.log('FINISHED TEST.')
