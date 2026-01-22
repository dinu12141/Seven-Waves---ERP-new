import { useAuthStore } from 'src/stores/authStore'

export function authGuard(to, from, next) {
  const authStore = useAuthStore()

  // Skip guard for public routes
  if (to.meta.public) {
    // If user is already logged in and trying to access login page, redirect to dashboard
    if (to.path === '/login' && authStore.isAuthenticated) {
      next('/dashboard')
      return
    }
    next()
    return
  }

  // Check if user is authenticated
  if (!authStore.isAuthenticated) {
    // Redirect to login
    next('/login')
    return
  }

  // Check role-based access
  if (to.meta.roles && to.meta.roles.length > 0) {
    if (!authStore.hasPermission(to.meta.roles)) {
      // User doesn't have required role, redirect to dashboard
      next('/dashboard')
      return
    }
  }

  next()
}

export function roleGuard(requiredRoles) {
  return (to, from, next) => {
    const authStore = useAuthStore()

    if (authStore.hasPermission(requiredRoles)) {
      next()
    } else {
      next('/dashboard')
    }
  }
}
