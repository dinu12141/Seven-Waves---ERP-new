import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { supabase } from 'src/boot/supabase'

export const useAuthStore = defineStore('auth', () => {
  // State
  const user = ref(null)
  const profile = ref(null)
  const permissions = ref([])
  const assignedWarehouses = ref([])
  const loading = ref(false)
  const error = ref(null)

  // Admin state
  const allUsers = ref([])
  const allPermissionsList = ref([])

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
    Z_KITCHEN: 'Kitchen Staff',
    Z_WAITER: 'Waiter',
    Z_CASHIER: 'Cashier',
    // Legacy mappings
    admin: 'Administrator',
    manager: 'Manager',
    cashier: 'Cashier',
    kitchen: 'Kitchen',
    waiter: 'Waiter',
    hr_manager: 'HR Manager',
    hr_officer: 'HR Officer',
  }

  const roleOptions = [
    { label: 'Administrator', value: 'Z_ALL' },
    { label: 'Store Manager', value: 'Z_STOCK_MGR' },
    { label: 'Inventory Clerk', value: 'Z_INV_CLERK' },
    { label: 'Kitchen/Production Staff', value: 'Z_PROD_STAFF' },
    { label: 'Cashier/Waiter', value: 'Z_SALES_STAFF' },
    { label: 'HR Manager', value: 'Z_HR_MANAGER' },
    { label: 'HR Officer', value: 'Z_HR_OFFICER' },
    { label: 'Finance User', value: 'Z_FINANCE' },
    { label: 'Kitchen Staff', value: 'Z_KITCHEN' },
    { label: 'Waiter', value: 'Z_WAITER' },
    { label: 'Cashier', value: 'Z_CASHIER' },
  ]

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

  async function fetchProfile(retry = true) {
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
            user_id: user.value.id,
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

          // If create fails with duplicate key (race condition), retry fetch once
          if (createError) {
            if (createError.code === '23505' && retry) {
              console.log('Profile exists (race condition), retrying fetch...')
              return await fetchProfile(false)
            }
            throw createError
          }

          profile.value = createdProfile
          return
        }
        throw fetchError
      }
      profile.value = data
    } catch (err) {
      console.error('Error fetching profile:', err)
      // Only show meaningful errors, ignore harmless "duplicate" if handled
      if (err.code !== '23505') {
        error.value = err.message
      }

      // Fallback for dev - enable basic access even on error
      if (!profile.value) {
        // Only set fallback if absolutely critical, but avoid confusing error message
        profile.value = { id: user.value.id, role: 'Z_ALL', full_name: 'Dev User' }
      }
    }
  }

  async function fetchPermissions() {
    if (!user.value) return

    try {
      // Try v2 function first (includes user overrides)
      const { data, error: fetchError } = await supabase.rpc('get_user_permissions_v2', {
        p_user_id: user.value.id,
      })

      if (fetchError) {
        console.warn('V2 permissions failed, trying fallback:', fetchError)
        // Fallback to v1
        const { data: v1Data, error: v1Error } = await supabase.rpc('get_user_permissions', {
          p_user_id: user.value.id,
        })

        if (v1Error) {
          console.warn('V1 permissions also failed, using role fallback:', v1Error)
          if (profile.value?.role === 'Z_ALL' || profile.value?.role === 'admin') {
            permissions.value = [{ resource: '*', action: '*', module: '*' }]
          }
          return
        }

        permissions.value = v1Data || []
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
      const detailedError =
        err.message +
        (err.details ? `\nDetails: ${err.details}` : '') +
        (err.hint ? `\nHint: ${err.hint}` : '')
      error.value = detailedError
      return { success: false, error: detailedError }
    } finally {
      loading.value = false
    }
  }

  async function logout() {
    try {
      loading.value = true

      // Optimistic logout: Clear local state immediately so UI updates instantly

      user.value = null
      profile.value = null
      permissions.value = []
      assignedWarehouses.value = []

      // Perform network logout in background
      const { error: logoutError } = await supabase.auth.signOut()
      if (logoutError) {
        console.warn('Supabase signOut error:', logoutError)
        // We don't throw here because we want to enforce local logout regardless
      }

      return { success: true }
    } catch (err) {
      console.error('Logout error:', err)
      // Even if something explodes, we return success so the router can redirect
      return { success: true, error: err.message }
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

  // ============================================================
  // ADMIN USER MANAGEMENT
  // ============================================================

  /**
   * Generate a secure random password
   * @returns {string} Random password like "Sw8kX3mP!"
   */
  function generateTempPassword() {
    const upper = 'ABCDEFGHJKLMNPQRSTUVWXYZ'
    const lower = 'abcdefghjkmnpqrstuvwxyz'
    const digits = '23456789'
    const special = '!@#$%'
    let password = ''

    // Guarantee one of each type
    password += upper[Math.floor(Math.random() * upper.length)]
    password += lower[Math.floor(Math.random() * lower.length)]
    password += digits[Math.floor(Math.random() * digits.length)]
    password += special[Math.floor(Math.random() * special.length)]

    // Fill remaining with mix
    const all = upper + lower + digits
    for (let i = 0; i < 6; i++) {
      password += all[Math.floor(Math.random() * all.length)]
    }

    // Shuffle
    return password
      .split('')
      .sort(() => Math.random() - 0.5)
      .join('')
  }

  /**
   * Admin: Create a new user via secure RPC
   * @param {Object} params
   * @returns {Promise<Object>}
   */
  async function adminCreateUser({
    email,
    password,
    fullName,
    roleCode,
    permissions: perms = [],
    employeeId = null,
  }) {
    try {
      loading.value = true
      error.value = null

      const { data, error: rpcError } = await supabase.rpc('admin_create_user', {
        p_email: email,
        p_password: password,
        p_full_name: fullName || email.split('@')[0] || 'New User',
        p_role_code: roleCode || 'Z_SALES_STAFF',
        p_permissions: perms,
        p_employee_id: employeeId,
      })

      if (rpcError) throw rpcError

      if (data && data.success === false) {
        throw new Error(data.error || 'Unknown error creating user')
      }

      return { success: true, data, password }
    } catch (err) {
      console.error('Admin create user error:', err)
      error.value = err.message
      return { success: false, error: err.message }
    } finally {
      loading.value = false
    }
  }

  /**
   * Delete an Employee and their associated User account
   */
  async function adminDeleteEmployee(employeeId) {
    try {
      loading.value = true
      error.value = null

      // Call the RPC function created in migration 041
      const { data, error: rpcError } = await supabase.rpc('admin_delete_employee', {
        p_employee_id: employeeId,
      })

      if (rpcError) throw rpcError

      if (data && data.success === false) {
        throw new Error(data.error || 'Unknown error deleting employee')
      }

      return { success: true, message: data.message }
    } catch (err) {
      console.error('Admin delete employee error:', err)
      error.value = err.message
      return { success: false, error: err.message }
    } finally {
      loading.value = false
    }
  }

  /**
   * Fetch all users for admin management page
   */
  async function fetchAllUsers() {
    try {
      loading.value = true
      const { data, error: fetchError } = await supabase
        .from('profiles')
        .select('*')
        .order('created_at', { ascending: false })

      if (fetchError) throw fetchError
      allUsers.value = data || []
      return { success: true, data: allUsers.value }
    } catch (err) {
      console.error('Error fetching users:', err)
      return { success: false, error: err.message }
    } finally {
      loading.value = false
    }
  }

  /**
   * Update user permissions via secure RPC
   */
  async function updateUserPermissions(targetUserId, permissionsArray) {
    try {
      loading.value = true
      error.value = null

      const { data, error: rpcError } = await supabase.rpc('update_user_permissions', {
        p_target_user_id: targetUserId,
        p_permissions: permissionsArray,
      })

      if (rpcError) throw rpcError

      if (data && data.success === false) {
        throw new Error(data.error || 'Unknown error updating permissions')
      }

      return { success: true }
    } catch (err) {
      console.error('Update permissions error:', err)
      error.value = err.message
      return { success: false, error: err.message }
    } finally {
      loading.value = false
    }
  }

  /**
   * Fetch user-level permission overrides for a specific user
   */
  async function fetchUserPermissions(targetUserId) {
    try {
      const { data, error: fetchError } = await supabase
        .from('user_permissions')
        .select('permission_id, grant_type')
        .eq('user_id', targetUserId)

      if (fetchError) throw fetchError
      return { success: true, data: data || [] }
    } catch (err) {
      console.error('Error fetching user permissions:', err)
      return { success: false, error: err.message, data: [] }
    }
  }

  /**
   * Update a user's profile (role, etc.)
   */
  async function updateUserProfile(userId, updates) {
    try {
      loading.value = true
      const { data, error: updateError } = await supabase
        .from('profiles')
        .update(updates)
        .eq('id', userId)
        .select()
        .single()

      if (updateError) throw updateError
      return { success: true, data }
    } catch (err) {
      console.error('Error updating user profile:', err)
      return { success: false, error: err.message }
    } finally {
      loading.value = false
    }
  }

  // ============================================================
  // PERMISSION CHECK HELPERS
  // ============================================================

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
        return '/dashboard'

      case 'Z_INV_CLERK':
        return '/stock/grn'

      case 'Z_PROD_STAFF':
      case 'Z_KITCHEN':
      case 'kitchen':
        return '/operations/kitchen'

      case 'Z_CASHIER':
      case 'cashier':
        return '/billing'

      case 'Z_WAITER':
      case 'waiter':
        return '/operations/waiter'

      case 'Z_SALES_STAFF':
        return '/billing'

      case 'Z_HR_MANAGER':
      case 'Z_HR_OFFICER':
      case 'hr_manager':
      case 'hr_officer':
        return '/hrm/employees'

      case 'Z_FINANCE':
      case 'finance_manager':
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
    allUsers,
    allPermissionsList,
    // Getters
    isAuthenticated,
    userRole,
    isAdmin,
    isManager,
    userName,
    roleDisplayName,
    roleDisplayNames,
    roleOptions,
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
    // Admin actions
    generateTempPassword,
    adminCreateUser,
    fetchAllUsers,
    updateUserPermissions,
    fetchUserPermissions,
    updateUserProfile,
    adminDeleteEmployee,
  }
})
