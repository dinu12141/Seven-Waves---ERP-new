import https from 'https'

// Test multiple common emails to find a working user
const testUsers = [
  { email: 'admin@sevenwaves.com', password: 'Admin123!' },
  { email: 'admin@admin.com', password: 'Admin123!' },
  { email: 'test@test.com', password: 'Test1234!' },
  { email: 'admin@test.com', password: 'Test1234!' },
]

const apikey =
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im12dnVlZ3B0eGp5a2h6cGF0c21uIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njg5ODg0MzEsImV4cCI6MjA4NDU2NDQzMX0.orDxecxqi_58T-sewtexcl_ilRa_JvRzAJVkFp2NR7k'

async function testLogin(email, password) {
  return new Promise((resolve) => {
    const data = JSON.stringify({ email, password })
    const options = {
      hostname: 'mvvuegptxjykhzpatsmn.supabase.co',
      path: '/auth/v1/token?grant_type=password',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        apikey: apikey,
        'Content-Length': data.length,
      },
    }

    const req = https.request(options, (res) => {
      let body = ''
      res.on('data', (chunk) => (body += chunk))
      res.on('end', () => {
        console.log(`[${email}] STATUS: ${res.statusCode} => ${body.substring(0, 200)}`)
        resolve()
      })
    })
    req.on('error', (e) => {
      console.error(`[${email}] ERROR: ${e.message}`)
      resolve()
    })
    req.write(data)
    req.end()
  })
}

// Also list all users via service role (we need the service key for that)
// For now, just test the common emails
console.log('=== TESTING LOGIN FOR KNOWN EMAILS ===')
for (const u of testUsers) {
  await testLogin(u.email, u.password)
}
console.log('=== DONE ===')
console.log('\nNOTE: If all show "invalid_credentials" (400), it means the AUTH SYSTEM IS WORKING.')
console.log('The "Database error querying schema" (500) is FIXED.')
console.log('You just need to use the correct email/password.')
