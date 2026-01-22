import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { supabase } from 'src/boot/supabase'

export const useAuthStore = defineStore('auth', () => {
  // State
  const user = ref(null)
  const profile = ref(null)
  const loading = ref(true)
  const error = ref(null)

  // Getters
  const isAuthenticated = computed(() => !!user.value)
  const userRole = computed(() => profile.value?.role || null)
  const isAdmin = computed(() => profile.value?.role === 'admin')
  const isManager = computed(() => ['admin', 'manager'].includes(profile.value?.role))
  const userName = computed(() => profile.value?.full_name || user.value?.email || 'User')

  // Actions
  async function initialize() {
    try {
      loading.value = true
      const {
        data: { session },
      } = await supabase.auth.getSession()

      if (session?.user) {
        user.value = session.user
        await fetchProfile()
      }
    } catch (err) {
      console.error('Auth initialization error:', err)
      error.value = err.message
    } finally {
      loading.value = false
    }

    // Listen for auth changes
    supabase.auth.onAuthStateChange(async (event, session) => {
      user.value = session?.user || null
      if (session?.user) {
        await fetchProfile()
      } else {
        profile.value = null
      }
    })
  }

  async function fetchProfile() {
    if (!user.value) return

    try {
      const { data, error: fetchError } = await supabase
        .from('profiles')
        .select('*')
        .eq('user_id', user.value.id)
        .single()

      if (fetchError) throw fetchError
      profile.value = data
    } catch (err) {
      console.error('Error fetching profile:', err)
      error.value = err.message
    }
  }

  async function login(email, password) {
    try {
      loading.value = true
      error.value = null

      const { data, error: loginError } = await supabase.auth.signInWithPassword({
        email,
        password,
      })

      if (loginError) throw loginError

      user.value = data.user
      await fetchProfile()

      return { success: true }
    } catch (err) {
      console.error('Login error:', err)
      error.value = err.message
      return { success: false, error: err.message }
    } finally {
      loading.value = false
    }
  }

  async function logout() {
    try {
      loading.value = true
      const { error: logoutError } = await supabase.auth.signOut()
      if (logoutError) throw logoutError

      user.value = null
      profile.value = null

      return { success: true }
    } catch (err) {
      console.error('Logout error:', err)
      error.value = err.message
      return { success: false, error: err.message }
    } finally {
      loading.value = false
    }
  }

  async function register(email, password, fullName, role = 'waiter') {
    try {
      loading.value = true
      error.value = null

      const { data, error: signUpError } = await supabase.auth.signUp({
        email,
        password,
        options: {
          data: {
            full_name: fullName,
            role: role,
          },
        },
      })

      if (signUpError) throw signUpError

      return { success: true, user: data.user }
    } catch (err) {
      console.error('Registration error:', err)
      error.value = err.message
      return { success: false, error: err.message }
    } finally {
      loading.value = false
    }
  }

  function hasPermission(requiredRoles) {
    if (!profile.value?.role) return false
    if (Array.isArray(requiredRoles)) {
      return requiredRoles.includes(profile.value.role)
    }
    return profile.value.role === requiredRoles
  }

  function clearError() {
    error.value = null
  }

  return {
    // State
    user,
    profile,
    loading,
    error,
    // Getters
    isAuthenticated,
    userRole,
    isAdmin,
    isManager,
    userName,
    // Actions
    initialize,
    fetchProfile,
    login,
    logout,
    register,
    hasPermission,
    clearError,
  }
})
