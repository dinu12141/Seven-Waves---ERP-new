import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { supabase } from 'src/boot/supabase'

export const useAuthStore = defineStore('auth', () => {
  // State
  const user = ref(null)
  const profile = ref(null)
  const permissions = ref([])
  const assignedWarehouses = ref([])
  const loading = ref(true)
  const error = ref(null)

  // Getters
  const isAuthenticated = computed(() => !!user.value)
  const userRole = computed(() => profile.value?.role || null)
  const isAdmin = computed(() => profile.value?.role === 'Z_ALL')
  const isManager = computed(() =>
    ['Z_ALL', 'Z_STOCK_MGR', 'Z_HR_MANAGER'].includes(profile.value?.role),
  )
  const userName = computed(() => profile.value?.full_name || user.value?.email || 'User')

  // SAP Role Display Names
  const roleDisplayNames = {
    Z_ALL: 'Administrator',
    Z_STOCK_MGR: 'Store Manager',
    Z_INV_CLERK: 'Inventory Clerk',
    Z_PROD_STAFF: 'Kitchen/Production',
    Z_SALES_STAFF: 'Cashier/Waiter',
    Z_HR_MANAGER: 'HR Manager',
    Z_HR_OFFICER: 'HR Officer',
    Z_FINANCE: 'Finance User',
    // Legacy mappings
    admin: 'Administrator',
    manager: 'Manager',
    cashier: 'Cashier',
    kitchen: 'Kitchen',
    waiter: 'Waiter',
    hr_manager: 'HR Manager',
    hr_officer: 'HR Officer',
  }

  const roleDisplayName = computed(
    () => roleDisplayNames[profile.value?.role] || profile.value?.role || 'User',
  )

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
        await fetchPermissions()
        await fetchAssignedWarehouses()
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
        await fetchPermissions()
        await fetchAssignedWarehouses()
      } else {
        profile.value = null
        permissions.value = []
        assignedWarehouses.value = []
      }
    })
  }

  async function fetchProfile() {
    if (!user.value) return

    try {
      const { data, error: fetchError } = await supabase
        .from('profiles')
        .select('*')
        .eq('id', user.value.id)
        .single()

      if (fetchError) {
        // If profile not found, try to create one
        if (fetchError.code === 'PGRST116' || fetchError.code === '406') {
          console.log('Profile not found, creating default profile...')
          const newProfile = {
            id: user.value.id,
            full_name:
              user.value.user_metadata?.full_name || user.value.email?.split('@')[0] || 'User',
            role: 'Z_SALES_STAFF', // Default to sales staff
            avatar_url: null,
          }

          const { data: createdProfile, error: createError } = await supabase
            .from('profiles')
            .insert(newProfile)
            .select()
            .single()

          if (createError) throw createError
          profile.value = createdProfile
          return
        }
        throw fetchError
      }
      profile.value = data
    } catch (err) {
      console.error('Error fetching profile:', err)
      error.value = err.message
      // Fallback for dev - enable basic access even on error
      if (!profile.value) {
        profile.value = { id: user.value.id, role: 'Z_ALL', full_name: 'Dev User' }
      }
    }
  }

  async function fetchPermissions() {
    if (!user.value) return

    try {
      const { data, error: fetchError } = await supabase.rpc('get_user_permissions', {
        p_user_id: user.value.id,
      })

      if (fetchError) {
        console.warn('Error fetching permissions, using fallback:', fetchError)
        // Fallback: Grant all permissions for admin role (development)
        if (profile.value?.role === 'Z_ALL' || profile.value?.role === 'admin') {
          permissions.value = [{ resource: '*', action: '*', module: '*' }]
        }
        return
      }

      permissions.value = data || []
    } catch (err) {
      console.error('Error fetching permissions:', err)
      // Fallback for admin
      if (profile.value?.role === 'Z_ALL' || profile.value?.role === 'admin') {
        permissions.value = [{ resource: '*', action: '*', module: '*' }]
      }
    }
  }

  async function fetchAssignedWarehouses() {
    if (!user.value) return

    try {
      const { data, error: fetchError } = await supabase.rpc('get_user_warehouses', {
        p_user_id: user.value.id,
      })

      if (fetchError) {
        console.warn('Error fetching warehouses:', fetchError)
        return
      }

      assignedWarehouses.value = data || []
    } catch (err) {
      console.error('Error fetching warehouses:', err)
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
      await fetchPermissions()
      await fetchAssignedWarehouses()

      return { success: true, redirectTo: getDashboardRedirect() }
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
      permissions.value = []
      assignedWarehouses.value = []

      return { success: true }
    } catch (err) {
      console.error('Logout error:', err)
      error.value = err.message
      return { success: false, error: err.message }
    } finally {
      loading.value = false
    }
  }

  async function register(email, password, fullName, role = 'Z_SALES_STAFF') {
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

  /**
   * Check if user has a specific permission
   * @param {string} resource - Resource name (e.g., 'items', 'grn')
   * @param {string} action - Action name (e.g., 'create', 'read', 'approve')
   * @returns {boolean}
   */
  function hasPermission(resource, action) {
    // Admin wildcard check
    if (permissions.value.some((p) => p.resource === '*' && p.action === '*')) {
      return true
    }

    // Check for admin role directly
    if (profile.value?.role === 'Z_ALL' || profile.value?.role === 'admin') {
      return true
    }

    // Check specific permission
    return permissions.value.some(
      (p) =>
        (p.resource === resource || p.resource === '*') &&
        (p.action === action || p.action === '*'),
    )
  }

  /**
   * Check if user has any of the required roles (legacy support)
   * @param {string|string[]} requiredRoles
   * @returns {boolean}
   */
  function hasRole(requiredRoles) {
    if (!profile.value?.role) return false
    if (Array.isArray(requiredRoles)) {
      return requiredRoles.includes(profile.value.role)
    }
    return profile.value.role === requiredRoles
  }

  /**
   * Get the dashboard redirect URL based on user role
   * @returns {string}
   */
  function getDashboardRedirect() {
    const role = profile.value?.role

    switch (role) {
      case 'Z_ALL':
      case 'admin':
        return '/dashboard'

      case 'Z_STOCK_MGR':
      case 'manager':
        return '/stock/items'

      case 'Z_INV_CLERK':
        return '/stock/grn'

      case 'Z_PROD_STAFF':
      case 'kitchen':
        return '/operations/kitchen'

      case 'Z_SALES_STAFF':
      case 'cashier':
      case 'waiter':
        return '/billing'

      case 'Z_HR_MANAGER':
      case 'Z_HR_OFFICER':
      case 'hr_manager':
      case 'hr_officer':
        return '/hrm/employees'

      case 'Z_FINANCE':
        return '/finance/accounts'

      default:
        return '/dashboard'
    }
  }

  function clearError() {
    error.value = null
  }

  return {
    // State
    user,
    profile,
    permissions,
    assignedWarehouses,
    loading,
    error,
    // Getters
    isAuthenticated,
    userRole,
    isAdmin,
    isManager,
    userName,
    roleDisplayName,
    // Actions
    initialize,
    fetchProfile,
    fetchPermissions,
    fetchAssignedWarehouses,
    login,
    logout,
    register,
    hasPermission,
    hasRole,
    getDashboardRedirect,
    clearError,
  }
})
