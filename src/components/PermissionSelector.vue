<template>
  <div class="permission-selector">
    <!-- Header -->
    <div class="row items-center q-mb-md" v-if="!hideHeader">
      <q-icon name="admin_panel_settings" size="24px" color="primary" class="q-mr-sm" />
      <div class="text-subtitle1 text-weight-bold">Permission Selector</div>
      <q-space />
      <q-btn
        flat
        dense
        size="sm"
        label="Select All"
        color="primary"
        @click="selectAll"
        v-if="!readonly"
        class="q-mr-sm"
      />
      <q-btn
        flat
        dense
        size="sm"
        label="Clear All"
        color="negative"
        @click="clearAll"
        v-if="!readonly"
      />
    </div>

    <!-- Loading -->
    <div v-if="loading" class="text-center q-pa-lg">
      <q-spinner color="primary" size="40px" />
      <div class="q-mt-sm text-grey">Loading permissions...</div>
    </div>

    <!-- Permission Tree -->
    <div v-else class="permission-modules">
      <q-card
        v-for="mod in groupedPermissions"
        :key="mod.module"
        flat
        bordered
        class="q-mb-sm permission-module-card"
      >
        <q-expansion-item
          :icon="moduleIcons[mod.module] || 'settings'"
          :label="moduleLabels[mod.module] || mod.module"
          :caption="`${getModuleSelectedCount(mod)} of ${getModuleTotalCount(mod)} permissions`"
          header-class="permission-module-header"
          :default-opened="defaultExpanded"
        >
          <q-card-section class="q-pt-none">
            <div class="row q-mb-sm justify-end">
              <q-btn
                flat
                dense
                size="sm"
                color="primary"
                label="Select All"
                icon="done_all"
                @click.stop="selectModule(mod)"
                :disable="readonly"
                class="q-mr-sm"
              />
              <q-btn
                flat
                dense
                size="sm"
                color="negative"
                label="Clear"
                icon="clear"
                @click.stop="clearModule(mod)"
                :disable="readonly"
              />
            </div>
            <q-markup-table flat dense bordered class="permission-table">
              <thead>
                <tr>
                  <th class="text-left" style="width: 200px">Resource</th>
                  <th
                    v-for="action in allActions"
                    :key="action"
                    class="text-center"
                    style="width: 80px"
                  >
                    {{ actionLabels[action] || action }}
                  </th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="resource in mod.resources" :key="resource.name">
                  <td class="text-weight-medium">
                    <q-icon
                      :name="resourceIcons[resource.name] || 'article'"
                      size="18px"
                      class="q-mr-xs"
                      color="grey-7"
                    />
                    {{ resourceLabels[resource.name] || resource.name }}
                  </td>
                  <td v-for="action in allActions" :key="action" class="text-center">
                    <template v-if="resource.actions.includes(action)">
                      <q-checkbox
                        :model-value="isChecked(resource.name, action)"
                        @update:model-value="(val) => togglePermission(resource.name, action, val)"
                        :disable="readonly"
                        dense
                        :color="getCheckColor(resource.name, action)"
                      />
                    </template>
                    <template v-else>
                      <q-icon name="remove" size="16px" color="grey-4" />
                    </template>
                  </td>
                </tr>
              </tbody>
            </q-markup-table>
          </q-card-section>
        </q-expansion-item>
      </q-card>
    </div>

    <!-- Summary -->
    <div class="q-mt-sm text-caption text-grey-7" v-if="!loading">
      <q-icon name="info" size="14px" class="q-mr-xs" />
      {{ selectedCount }} permission(s) selected
      <span v-if="rolePermissionIds.length > 0" class="q-ml-sm">
        ({{ rolePermissionIds.length }} from role, {{ userOverrideCount }} custom)
      </span>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, watch, onMounted } from 'vue'
import { supabase } from 'src/boot/supabase'

const props = defineProps({
  modelValue: {
    type: Array,
    default: () => [],
    // Array of { permission_id, grant_type } objects
  },
  roleCode: {
    type: String,
    default: null,
    // If provided, shows role-based permissions as pre-checked (readonly base)
  },
  readonly: {
    type: Boolean,
    default: false,
  },
  hideHeader: {
    type: Boolean,
    default: false,
  },
  defaultExpanded: {
    type: Boolean,
    default: false,
  },
})

const emit = defineEmits(['update:modelValue'])

const loading = ref(false)
const allPermissions = ref([])
const rolePermissionIds = ref([])

// Module metadata
const moduleLabels = {
  dashboard: 'Dashboard',
  hr: 'Human Resources (HRM)',
  inventory: 'Inventory Management',
  procurement: 'Procurement',
  production: 'Production / Kitchen',
  sales: 'Sales & Billing',
  operations: 'Operations',
  finance: 'Finance',
  reports: 'Reports',
  admin: 'Administration',
  workflow: 'Workflow / Approvals',
}

const moduleIcons = {
  dashboard: 'dashboard',
  hr: 'people',
  inventory: 'inventory_2',
  procurement: 'shopping_cart',
  production: 'precision_manufacturing',
  sales: 'point_of_sale',
  operations: 'restaurant',
  finance: 'account_balance',
  reports: 'assessment',
  admin: 'admin_panel_settings',
  workflow: 'approval',
}

const actionLabels = {
  view: 'View',
  read: 'View',
  create: 'Create',
  update: 'Edit',
  delete: 'Delete',
  approve: 'Approve',
  process: 'Process',
  void: 'Void',
  manage: 'Manage',
  cancel: 'Cancel',
  transfer: 'Transfer',
  adjust: 'Adjust',
  update_price: 'Price',
  assign_waiter: 'Assign',
  sales: 'Sales',
  inventory: 'Inventory',
  finance: 'Finance',
  hr: 'HR',
}

const resourceLabels = {
  dashboard: 'Dashboard',
  employees: 'Employees',
  attendance: 'Attendance',
  leaves: 'Leaves',
  salary: 'Salary',
  items: 'Items',
  warehouses: 'Warehouses',
  stock: 'Stock',
  stock_requests: 'Stock Requests',
  purchase_orders: 'Purchase Orders',
  grn: 'Goods Receipt (GRN)',
  gin: 'Goods Issue (GIN)',
  recipes: 'Recipes / BOM',
  production_orders: 'Production Orders',
  billing: 'Billing',
  orders: 'Orders',
  tables: 'Tables',
  kitchen: 'Kitchen Display',
  customer_menu: 'Customer Menu',
  kot: 'Kitchen Order Tickets',
  accounts: 'Accounts',
  transactions: 'Transactions',
  daily_cash: 'Daily Cash',
  reports: 'Reports',
  users: 'Users',
  settings: 'Settings',
  pending_approvals: 'Approvals',
}

const resourceIcons = {
  employees: 'badge',
  attendance: 'schedule',
  leaves: 'event_busy',
  salary: 'payments',
  items: 'inventory',
  warehouses: 'warehouse',
  stock: 'storage',
  purchase_orders: 'receipt_long',
  grn: 'move_to_inbox',
  gin: 'outbox',
  recipes: 'menu_book',
  production_orders: 'factory',
  billing: 'point_of_sale',
  orders: 'shopping_bag',
  tables: 'table_restaurant',
  kitchen: 'countertops',
  accounts: 'account_balance_wallet',
  transactions: 'swap_horiz',
  daily_cash: 'monetization_on',
  reports: 'bar_chart',
  users: 'manage_accounts',
  settings: 'settings',
  pending_approvals: 'approval',
}

// Compute all unique actions across permissions
const allActions = computed(() => {
  const actions = new Set()
  allPermissions.value.forEach((p) => actions.add(p.action))
  // Preferred order
  const order = [
    'view',
    'read',
    'create',
    'update',
    'delete',
    'approve',
    'process',
    'void',
    'manage',
    'cancel',
    'transfer',
    'adjust',
    'update_price',
    'assign_waiter',
    'sales',
    'inventory',
    'finance',
    'hr',
  ]
  return order.filter((a) => actions.has(a))
})

// Group permissions by module > resource
const groupedPermissions = computed(() => {
  const modules = {}
  allPermissions.value.forEach((p) => {
    if (!modules[p.module]) {
      modules[p.module] = { module: p.module, resources: {} }
    }
    if (!modules[p.module].resources[p.resource]) {
      modules[p.module].resources[p.resource] = {
        name: p.resource,
        actions: [],
        permissionMap: {},
      }
    }
    modules[p.module].resources[p.resource].actions.push(p.action)
    modules[p.module].resources[p.resource].permissionMap[p.action] = p.id
  })

  // Convert resources from object to array
  const moduleOrder = [
    'dashboard',
    'hr',
    'inventory',
    'procurement',
    'production',
    'sales',
    'operations',
    'finance',
    'reports',
    'admin',
    'workflow',
  ]

  return moduleOrder
    .filter((m) => modules[m])
    .map((m) => ({
      ...modules[m],
      resources: Object.values(modules[m].resources),
    }))
})

// Permission check helpers
const selectedPermissions = computed(() => props.modelValue || [])

function findPermissionId(resource, action) {
  const perm = allPermissions.value.find((p) => p.resource === resource && p.action === action)
  return perm?.id
}

function isChecked(resource, action) {
  const permId = findPermissionId(resource, action)
  if (!permId) return false

  // Check user overrides first
  const userOverride = selectedPermissions.value.find((p) => p.permission_id === permId)
  if (userOverride) {
    return userOverride.grant_type === 'allow'
  }

  // Fall back to role permissions
  return rolePermissionIds.value.includes(permId)
}

function getCheckColor(resource, action) {
  const permId = findPermissionId(resource, action)
  if (!permId) return 'primary'

  const userOverride = selectedPermissions.value.find((p) => p.permission_id === permId)
  if (userOverride) return 'orange' // Custom override shown in orange
  if (rolePermissionIds.value.includes(permId)) return 'green' // Role-based in green
  return 'primary'
}

function togglePermission(resource, action, checked) {
  const permId = findPermissionId(resource, action)
  if (!permId) return

  const current = [...selectedPermissions.value]
  const existingIdx = current.findIndex((p) => p.permission_id === permId)
  const isRolePerm = rolePermissionIds.value.includes(permId)

  if (checked) {
    if (existingIdx >= 0) {
      current[existingIdx] = { permission_id: permId, grant_type: 'allow' }
    } else if (!isRolePerm) {
      // Only add if not already granted by role
      current.push({ permission_id: permId, grant_type: 'allow' })
    } else {
      // Remove any deny override
      if (existingIdx >= 0) current.splice(existingIdx, 1)
    }
  } else {
    if (isRolePerm) {
      // Need explicit deny to revoke a role permission
      if (existingIdx >= 0) {
        current[existingIdx] = { permission_id: permId, grant_type: 'deny' }
      } else {
        current.push({ permission_id: permId, grant_type: 'deny' })
      }
    } else {
      // Just remove the allow
      if (existingIdx >= 0) current.splice(existingIdx, 1)
    }
  }

  emit('update:modelValue', current)
}

function selectAll() {
  const all = allPermissions.value.map((p) => ({
    permission_id: p.id,
    grant_type: 'allow',
  }))
  emit('update:modelValue', all)
}

function clearAll() {
  // Deny all role permissions, remove all allows
  const denies = rolePermissionIds.value.map((id) => ({
    permission_id: id,
    grant_type: 'deny',
  }))
  emit('update:modelValue', denies)
}

function selectModule(mod) {
  // Get all permission IDs in this module
  const modulePerms = []
  mod.resources.forEach((r) => {
    Object.values(r.permissionMap).forEach((permId) => {
      modulePerms.push(permId)
    })
  })

  // Create a new array based on current selection
  const current = [...selectedPermissions.value]

  modulePerms.forEach((permId) => {
    const existingIdx = current.findIndex((p) => p.permission_id === permId)
    const isRolePerm = rolePermissionIds.value.includes(permId)

    if (existingIdx >= 0) {
      // If it exists (either allow or deny), force it to allow
      current[existingIdx] = { permission_id: permId, grant_type: 'allow' }
    } else if (!isRolePerm) {
      // If not a role permission and not in overrides, add allow
      current.push({ permission_id: permId, grant_type: 'allow' })
    }
    // If it IS a role permission and not in overrides, it's already allowed by default, so do nothing.
  })

  emit('update:modelValue', current)
}

function clearModule(mod) {
  // Get all permission IDs in this module
  const modulePerms = []
  mod.resources.forEach((r) => {
    Object.values(r.permissionMap).forEach((permId) => {
      modulePerms.push(permId)
    })
  })

  // Create a new array based on current selection
  const current = [...selectedPermissions.value]

  modulePerms.forEach((permId) => {
    const existingIdx = current.findIndex((p) => p.permission_id === permId)
    const isRolePerm = rolePermissionIds.value.includes(permId)

    if (isRolePerm) {
      // If role perm, we must explicitly deny it
      if (existingIdx >= 0) {
        current[existingIdx] = { permission_id: permId, grant_type: 'deny' }
      } else {
        current.push({ permission_id: permId, grant_type: 'deny' })
      }
    } else {
      // If not role perm, just remove any 'allow' override
      if (existingIdx >= 0) {
        current.splice(
          current.findIndex((p) => p.permission_id === permId),
          1,
        )
      }
    }
  })

  emit('update:modelValue', current)
}

// Stats
const selectedCount = computed(() => {
  let count = 0
  allPermissions.value.forEach((p) => {
    if (isChecked(p.resource, p.action)) count++
  })
  return count
})

const userOverrideCount = computed(
  () => selectedPermissions.value.filter((p) => p.grant_type === 'allow').length,
)

function getModuleSelectedCount(mod) {
  let count = 0
  mod.resources.forEach((r) => {
    r.actions.forEach((a) => {
      if (isChecked(r.name, a)) count++
    })
  })
  return count
}

function getModuleTotalCount(mod) {
  let count = 0
  mod.resources.forEach((r) => {
    count += r.actions.length
  })
  return count
}

// Load permissions from database
async function loadPermissions() {
  loading.value = true
  try {
    const { data, error } = await supabase
      .from('permissions')
      .select('*')
      .order('module')
      .order('resource')
      .order('action')

    if (error) throw error
    allPermissions.value = data || []
  } catch (err) {
    console.error('Error loading permissions:', err)
  } finally {
    loading.value = false
  }
}

// Load role permissions when roleCode changes
async function loadRolePermissions() {
  if (!props.roleCode) {
    rolePermissionIds.value = []
    return
  }

  try {
    const { data, error } = await supabase
      .from('role_permissions')
      .select('permission_id, roles!inner(code)')
      .eq('roles.code', props.roleCode)

    if (error) throw error
    rolePermissionIds.value = (data || []).map((rp) => rp.permission_id)
  } catch (err) {
    console.error('Error loading role permissions:', err)
    rolePermissionIds.value = []
  }
}

watch(() => props.roleCode, loadRolePermissions, { immediate: false })

onMounted(async () => {
  await loadPermissions()
  if (props.roleCode) {
    await loadRolePermissions()
  }
})
</script>

<style scoped>
.permission-selector {
  max-width: 900px;
}

.permission-module-card {
  border-radius: 8px;
  overflow: hidden;
}

.permission-module-header {
  font-weight: 600;
}

.permission-table {
  font-size: 13px;
}

.permission-table th {
  background: #f5f7fa;
  font-weight: 600;
  text-transform: uppercase;
  font-size: 11px;
  letter-spacing: 0.5px;
  color: #555;
}

.permission-table td {
  vertical-align: middle;
}
</style>
