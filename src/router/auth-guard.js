/**
 * Auth Guard - Permission-based route protection
 * Seven Waves ERP - SAP HANA Authorization Model
 */

import { useAuthStore } from 'src/stores/authStore'

/**
 * Main auth guard for route protection
 * Supports both legacy role-based and new permission-based access control
 */
export function authGuard(to, from, next) {
  const authStore = useAuthStore()

  // Skip guard for public routes
  if (to.meta.public) {
    // If user is already logged in and trying to access login page
    if (to.path === '/login' && authStore.isAuthenticated) {
      // Redirect to role-appropriate dashboard
      next(authStore.getDashboardRedirect())
      return
    }
    next()
    return
  }

  // Check if user is authenticated
  if (!authStore.isAuthenticated) {
    // Redirect to login with return URL
    next({ path: '/login', query: { redirect: to.fullPath } })
    return
  }

  // Check permission-based access (new system)
  if (to.meta.permission) {
    const [resource, action] = to.meta.permission.split('.')
    if (!authStore.hasPermission(resource, action)) {
      console.warn(`Access denied: Missing permission ${to.meta.permission}`)
      next(authStore.getDashboardRedirect())
      return
    }
  }

  // Check role-based access (legacy support)
  if (to.meta.roles && to.meta.roles.length > 0) {
    const userRole = authStore.userRole

    // SAP role code mapping for legacy routes
    const roleMapping = {
      admin: ['Z_ALL'],
      manager: ['Z_ALL', 'Z_STOCK_MGR', 'Z_HR_MANAGER'],
      cashier: ['Z_ALL', 'Z_SALES_STAFF'],
      kitchen: ['Z_ALL', 'Z_PROD_STAFF'],
      waiter: ['Z_ALL', 'Z_SALES_STAFF'],
      hr_manager: ['Z_ALL', 'Z_HR_MANAGER'],
      hr_officer: ['Z_ALL', 'Z_HR_MANAGER', 'Z_HR_OFFICER'],
    }

    // Check if user's SAP role is in any of the allowed legacy roles
    let hasAccess = false

    for (const legacyRole of to.meta.roles) {
      // Direct match
      if (legacyRole === userRole) {
        hasAccess = true
        break
      }
      // Check SAP role mapping
      const mappedRoles = roleMapping[legacyRole] || []
      if (mappedRoles.includes(userRole)) {
        hasAccess = true
        break
      }
    }

    // Also check if user has the role directly (for SAP codes in meta.roles)
    if (!hasAccess && to.meta.roles.includes(userRole)) {
      hasAccess = true
    }

    // Admin always has access
    if (authStore.isAdmin) {
      hasAccess = true
    }

    if (!hasAccess) {
      console.warn(`Access denied: User role ${userRole} not in ${to.meta.roles.join(', ')}`)
      next(authStore.getDashboardRedirect())
      return
    }
  }

  // All checks passed
  next()
}

/**
 * Permission guard factory - for granular permission checks
 * @param {string} resource - Resource name
 * @param {string} action - Action name
 */
export function permissionGuard(resource, action) {
  return (to, from, next) => {
    const authStore = useAuthStore()

    if (authStore.hasPermission(resource, action)) {
      next()
    } else {
      console.warn(`Permission denied: ${resource}.${action}`)
      next(authStore.getDashboardRedirect())
    }
  }
}

/**
 * Role guard factory - for role-based checks (legacy support)
 * @param {string[]} requiredRoles - Array of allowed roles
 */
export function roleGuard(requiredRoles) {
  return (to, from, next) => {
    const authStore = useAuthStore()

    if (authStore.hasRole(requiredRoles) || authStore.isAdmin) {
      next()
    } else {
      next(authStore.getDashboardRedirect())
    }
  }
}

/**
 * Module access guard - for module-level protection
 * @param {string} module - Module name (inventory, sales, hr, finance)
 */
export function moduleGuard(module) {
  return (to, from, next) => {
    const authStore = useAuthStore()
    const permissions = authStore.permissions || []

    const hasModuleAccess = permissions.some((p) => p.module === module) || authStore.isAdmin

    if (hasModuleAccess) {
      next()
    } else {
      console.warn(`Module access denied: ${module}`)
      next(authStore.getDashboardRedirect())
    }
  }
}
