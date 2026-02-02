/**
 * usePermissions - Vue 3 Composable for RBAC Permission Checks
 * Seven Waves ERP - SAP HANA Authorization Model
 */

import { computed } from 'vue'
import { useAuthStore } from 'src/stores/authStore'

/**
 * Permission-based access control composable
 * @returns {Object} Permission check functions and computed properties
 */
export function usePermissions() {
  const authStore = useAuthStore()

  /**
   * Check if user has a specific permission
   * @param {string} resource - Resource name (e.g., 'items', 'grn', 'orders')
   * @param {string} action - Action name (e.g., 'create', 'read', 'update', 'delete', 'approve')
   * @returns {boolean}
   */
  const hasPermission = (resource, action) => {
    return authStore.hasPermission(resource, action)
  }

  /**
   * Check if user can create records for a resource
   * @param {string} resource
   * @returns {boolean}
   */
  const canCreate = (resource) => hasPermission(resource, 'create')

  /**
   * Check if user can read/view records for a resource
   * @param {string} resource
   * @returns {boolean}
   */
  const canRead = (resource) => hasPermission(resource, 'read')

  /**
   * Check if user can update records for a resource
   * @param {string} resource
   * @returns {boolean}
   */
  const canUpdate = (resource) => hasPermission(resource, 'update')

  /**
   * Check if user can delete records for a resource
   * @param {string} resource
   * @returns {boolean}
   */
  const canDelete = (resource) => hasPermission(resource, 'delete')

  /**
   * Check if user can approve records for a resource
   * @param {string} resource
   * @returns {boolean}
   */
  const canApprove = (resource) => hasPermission(resource, 'approve')

  /**
   * Check if user has access to a module
   * @param {string} module - Module name (e.g., 'inventory', 'sales', 'hr')
   * @returns {boolean}
   */
  const hasModuleAccess = (module) => {
    const permissions = authStore.permissions || []
    return permissions.some((p) => p.module === module)
  }

  /**
   * Check if user has any of the specified permissions
   * @param {Array<{resource: string, action: string}>} permissionList
   * @returns {boolean}
   */
  const hasAnyPermission = (permissionList) => {
    return permissionList.some(({ resource, action }) => hasPermission(resource, action))
  }

  /**
   * Check if user has all of the specified permissions
   * @param {Array<{resource: string, action: string}>} permissionList
   * @returns {boolean}
   */
  const hasAllPermissions = (permissionList) => {
    return permissionList.every(({ resource, action }) => hasPermission(resource, action))
  }

  // Computed properties for common role checks
  const isAdmin = computed(() => authStore.userRole === 'Z_ALL')
  const isStockManager = computed(() => ['Z_ALL', 'Z_STOCK_MGR'].includes(authStore.userRole))
  const isInventoryClerk = computed(() =>
    ['Z_ALL', 'Z_STOCK_MGR', 'Z_INV_CLERK'].includes(authStore.userRole),
  )
  const isProductionStaff = computed(() => ['Z_ALL', 'Z_PROD_STAFF'].includes(authStore.userRole))
  const isSalesStaff = computed(() => ['Z_ALL', 'Z_SALES_STAFF'].includes(authStore.userRole))
  const isHRManager = computed(() => ['Z_ALL', 'Z_HR_MANAGER'].includes(authStore.userRole))
  const isHROfficer = computed(() =>
    ['Z_ALL', 'Z_HR_MANAGER', 'Z_HR_OFFICER'].includes(authStore.userRole),
  )
  const isFinanceUser = computed(() => ['Z_ALL', 'Z_FINANCE'].includes(authStore.userRole))

  // Computed properties for module access
  const canAccessInventory = computed(
    () => hasModuleAccess('inventory') || hasModuleAccess('procurement'),
  )
  const canAccessSales = computed(() => hasModuleAccess('sales') || hasModuleAccess('operations'))
  const canAccessHR = computed(() => hasModuleAccess('hr'))
  const canAccessFinance = computed(() => hasModuleAccess('finance'))
  const canAccessReports = computed(() => hasModuleAccess('reports'))
  const canAccessAdmin = computed(() => hasModuleAccess('admin'))

  // Warehouse access
  const accessibleWarehouses = computed(() => authStore.assignedWarehouses || [])
  const hasWarehouseAccess = (warehouseId) => {
    if (isAdmin.value) return true
    return accessibleWarehouses.value.some((w) => w.warehouse_id === warehouseId)
  }

  return {
    // Core permission checks
    hasPermission,
    canCreate,
    canRead,
    canUpdate,
    canDelete,
    canApprove,
    hasModuleAccess,
    hasAnyPermission,
    hasAllPermissions,

    // Role checks
    isAdmin,
    isStockManager,
    isInventoryClerk,
    isProductionStaff,
    isSalesStaff,
    isHRManager,
    isHROfficer,
    isFinanceUser,

    // Module access
    canAccessInventory,
    canAccessSales,
    canAccessHR,
    canAccessFinance,
    canAccessReports,
    canAccessAdmin,

    // Warehouse access
    accessibleWarehouses,
    hasWarehouseAccess,
  }
}

export default usePermissions
