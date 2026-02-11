import { createClient } from '@supabase/supabase-js'

// Using the NEW credentials that were updated in .env
const supabaseUrl = 'https://iqbloarmocgkfqkgboen.supabase.co'
const supabaseKey =
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlxYmxvYXJtb2Nna2Zxa2dib2VuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjkxMzk4MjQsImV4cCI6MjA4NDcxNTgyNH0.QT1gfHCmQ0XM58zOkUiLigh5g-RqD-NV5JCssjV523U'

const supabase = createClient(supabaseUrl, supabaseKey)

async function testLoginFlow() {
  console.log('1. Attempting Login with admin@sevenwaves.com...')

  const { data: authData, error: authError } = await supabase.auth.signInWithPassword({
    email: 'admin@sevenwaves.com',
    password: 'password123',
  })

  if (authError) {
    console.error('❌ Login Failed:', authError)
    return
  }

  console.log('✅ Login Successful! User ID:', authData.user.id)
  const userId = authData.user.id

  console.log('2. Fetching Profile...')
  const { data: profileData, error: profileError } = await supabase
    .from('profiles')
    .select('*')
    .eq('id', userId)
    .single()

  if (profileError) {
    console.error('❌ Profile Fetch Failed:', profileError)
    // Don't return, let's see if other things work
  } else {
    console.log('✅ Profile Fetched:', profileData)
  }

  console.log('3. Fetching Permissions (RPC)...')
  const { data: permData, error: permError } = await supabase.rpc('get_user_permissions', {
    p_user_id: userId,
  })

  if (permError) {
    console.error('❌ Permissions Fetch Failed:', permError)
  } else {
    console.log(`✅ Permissions Fetched: ${permData?.length || 0} permissions found`)
  }
}

testLoginFlow()
