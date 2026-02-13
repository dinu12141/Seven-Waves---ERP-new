<template>
  <q-no-ssr>
    <q-layout view="lHh LpR lFf" class="admin-layout">
      <!-- Header -->
      <q-header elevated class="app-header">
        <q-toolbar>
          <q-btn
            flat
            dense
            round
            icon="menu"
            aria-label="Menu"
            @click="toggleDrawer"
            class="menu-btn"
          />

          <q-toolbar-title class="header-title">
            <q-icon name="waves" size="28px" class="header-logo-icon" />
            <span>Seven Waves ERP</span>
          </q-toolbar-title>

          <q-space />

          <!-- Notifications -->
          <q-btn flat round icon="notifications" class="header-btn">
            <q-badge color="negative" floating>3</q-badge>
          </q-btn>

          <!-- User Menu -->
          <q-btn flat round class="user-btn">
            <q-avatar size="36px" color="primary" text-color="white">
              {{ isMounted ? userInitials : 'U' }}
            </q-avatar>
            <q-menu v-if="isMounted">
              <q-list style="min-width: 200px">
                <q-item-label header>{{ authStore.userName }}</q-item-label>
                <q-item-label caption class="q-px-md">{{ authStore.roleDisplayName }}</q-item-label>
                <q-separator />
                <q-item clickable v-close-popup>
                  <q-item-section avatar>
                    <q-icon name="person" />
                  </q-item-section>
                  <q-item-section>Profile</q-item-section>
                </q-item>
                <q-item clickable v-close-popup>
                  <q-item-section avatar>
                    <q-icon name="settings" />
                  </q-item-section>
                  <q-item-section>Settings</q-item-section>
                </q-item>
                <q-separator />
                <q-item clickable v-close-popup @click="handleLogout">
                  <q-item-section avatar>
                    <q-icon name="logout" color="negative" />
                  </q-item-section>
                  <q-item-section class="text-negative">Logout</q-item-section>
                </q-item>
              </q-list>
            </q-menu>
          </q-btn>
        </q-toolbar>
      </q-header>

      <!-- Sidebar -->
      <q-drawer
        v-model="drawerOpen"
        :mini="miniState"
        @mouseover="miniState = false"
        @mouseout="miniState = true"
        bordered
        class="app-drawer"
      >
        <q-scroll-area class="fit">
          <q-list padding v-if="isMounted">
            <!-- Dashboard -->
            <q-item clickable v-ripple to="/dashboard" active-class="nav-active">
              <q-item-section avatar>
                <q-icon name="dashboard" />
              </q-item-section>
              <q-item-section>Dashboard</q-item-section>
            </q-item>

            <q-separator class="q-my-sm" />
            <q-item-label header class="text-grey-7">MANAGEMENT</q-item-label>

            <!-- HRM -->
            <q-expansion-item
              icon="people"
              label="HRM"
              v-if="can('employees', 'read') || can('attendance', 'view') || can('salary', 'view')"
            >
              <q-item
                clickable
                v-ripple
                to="/hrm/employees"
                active-class="nav-active"
                :inset-level="1"
                v-if="can('employees', 'read')"
              >
                <q-item-section>Employees</q-item-section>
              </q-item>
              <q-item
                clickable
                v-ripple
                to="/hrm/register"
                active-class="nav-active"
                :inset-level="1"
                v-if="can('employees', 'create')"
              >
                <q-item-section>Register Employee</q-item-section>
              </q-item>
              <q-item
                clickable
                v-ripple
                to="/hrm/attendance"
                active-class="nav-active"
                :inset-level="1"
                v-if="can('attendance', 'view')"
              >
                <q-item-section>Attendance</q-item-section>
              </q-item>
              <q-item
                clickable
                v-ripple
                to="/hrm/leaves"
                active-class="nav-active"
                :inset-level="1"
                v-if="can('leaves', 'view')"
              >
                <q-item-section>Leaves</q-item-section>
              </q-item>
              <q-item
                clickable
                v-ripple
                to="/hrm/salary"
                active-class="nav-active"
                :inset-level="1"
                v-if="can('salary', 'view')"
              >
                <q-item-section>Salary</q-item-section>
              </q-item>
            </q-expansion-item>

            <!-- Stock Management - SAP B1 HANA -->
            <q-expansion-item
              icon="inventory_2"
              label="Stock"
              v-if="can('items', 'read') || can('purchase_orders', 'read') || can('stock', 'view')"
              default-opened
            >
              <!-- Master Data -->
              <q-item-label header class="text-grey-7 q-pl-lg" style="font-size: 10px"
                >MASTER DATA</q-item-label
              >
              <q-item
                clickable
                v-ripple
                to="/stock/items"
                active-class="nav-active"
                :inset-level="1"
                v-if="can('items', 'read')"
              >
                <q-item-section>Items</q-item-section>
              </q-item>
              <q-item
                clickable
                v-ripple
                to="/stock/suppliers"
                active-class="nav-active"
                :inset-level="1"
                v-if="can('purchase_orders', 'read')"
              >
                <q-item-section>Suppliers</q-item-section>
              </q-item>
              <q-item
                clickable
                v-ripple
                to="/stock/warehouses"
                active-class="nav-active"
                :inset-level="1"
                v-if="can('warehouses', 'read')"
              >
                <q-item-section>Warehouses & Bins</q-item-section>
              </q-item>
              <q-item
                clickable
                v-ripple
                to="/stock/price-lists"
                active-class="nav-active"
                :inset-level="1"
                v-if="can('items', 'update_price')"
              >
                <q-item-section>Price Lists</q-item-section>
              </q-item>
              <q-item
                clickable
                v-ripple
                to="/stock/recipes"
                active-class="nav-active"
                :inset-level="1"
                v-if="can('recipes', 'read')"
              >
                <q-item-section>Recipes / BOM</q-item-section>
              </q-item>

              <!-- Transactions -->
              <q-item-label header class="text-grey-7 q-pl-lg" style="font-size: 10px"
                >TRANSACTIONS</q-item-label
              >
              <q-item
                clickable
                v-ripple
                to="/stock/po"
                active-class="nav-active"
                :inset-level="1"
                v-if="can('purchase_orders', 'read')"
              >
                <q-item-section>Purchase Orders</q-item-section>
              </q-item>
              <q-item
                clickable
                v-ripple
                to="/stock/grn"
                active-class="nav-active"
                :inset-level="1"
                v-if="can('grn', 'read')"
              >
                <q-item-section>Goods Receipt (GRN)</q-item-section>
              </q-item>
              <q-item
                clickable
                v-ripple
                to="/stock/gin"
                active-class="nav-active"
                :inset-level="1"
                v-if="can('gin', 'read')"
              >
                <q-item-section>Goods Issue (GIN)</q-item-section>
              </q-item>
              <q-item
                clickable
                v-ripple
                to="/stock/transfers"
                active-class="nav-active"
                :inset-level="1"
                v-if="can('stock', 'transfer')"
              >
                <q-item-section>Stock Transfers</q-item-section>
              </q-item>

              <!-- Inventory Operations -->
              <q-item-label header class="text-grey-7 q-pl-lg" style="font-size: 10px"
                >OPERATIONS</q-item-label
              >
              <q-item
                clickable
                v-ripple
                to="/stock/cycle-count"
                active-class="nav-active"
                :inset-level="1"
                v-if="can('stock', 'adjust')"
              >
                <q-item-section>Cycle Counting</q-item-section>
              </q-item>
              <q-item
                clickable
                v-ripple
                to="/stock/procurement"
                active-class="nav-active"
                :inset-level="1"
                v-if="can('purchase_orders', 'read')"
              >
                <q-item-section>Procurement Dashboard</q-item-section>
              </q-item>
              <q-item
                clickable
                v-ripple
                to="/stock/pick-pack"
                active-class="nav-active"
                :inset-level="1"
                v-if="can('stock', 'view')"
              >
                <q-item-section>Pick & Pack</q-item-section>
              </q-item>
            </q-expansion-item>

            <!-- Billing -->
            <q-item
              clickable
              v-ripple
              to="/billing"
              active-class="nav-active"
              v-if="can('billing', 'process')"
            >
              <q-item-section avatar>
                <q-icon name="point_of_sale" />
              </q-item-section>
              <q-item-section>Billing</q-item-section>
            </q-item>

            <!-- Operations -->
            <q-expansion-item
              icon="restaurant"
              label="Operations"
              v-if="can('orders', 'read') || can('tables', 'view') || can('kitchen', 'view')"
            >
              <q-item
                clickable
                v-ripple
                to="/operations/tables"
                active-class="nav-active"
                :inset-level="1"
                v-if="can('tables', 'view')"
              >
                <q-item-section>Tables</q-item-section>
              </q-item>
              <q-item
                clickable
                v-ripple
                to="/operations/orders"
                active-class="nav-active"
                :inset-level="1"
                v-if="can('orders', 'read')"
              >
                <q-item-section>Orders</q-item-section>
              </q-item>
              <q-item
                clickable
                v-ripple
                to="/operations/kitchen"
                active-class="nav-active"
                :inset-level="1"
                v-if="can('kitchen', 'view')"
              >
                <q-item-section>Kitchen Display</q-item-section>
              </q-item>
              <q-item
                clickable
                v-ripple
                to="/operations/menu"
                active-class="nav-active"
                :inset-level="1"
                v-if="can('recipes', 'read')"
              >
                <q-item-section>Menu</q-item-section>
              </q-item>
            </q-expansion-item>

            <!-- Finance -->
            <q-expansion-item
              icon="account_balance"
              label="Finance"
              v-if="
                can('accounts', 'view') || can('transactions', 'view') || can('daily_cash', 'view')
              "
            >
              <q-item
                clickable
                v-ripple
                to="/finance/accounts"
                active-class="nav-active"
                :inset-level="1"
                v-if="can('accounts', 'view')"
              >
                <q-item-section>Accounts</q-item-section>
              </q-item>
              <q-item
                clickable
                v-ripple
                to="/finance/transactions"
                active-class="nav-active"
                :inset-level="1"
                v-if="can('transactions', 'view')"
              >
                <q-item-section>Transactions</q-item-section>
              </q-item>
              <q-item
                clickable
                v-ripple
                to="/finance/daily-cash"
                active-class="nav-active"
                :inset-level="1"
                v-if="can('daily_cash', 'view')"
              >
                <q-item-section>Daily Cash</q-item-section>
              </q-item>
            </q-expansion-item>

            <!-- Sales -->
            <q-item
              clickable
              v-ripple
              to="/sales"
              active-class="nav-active"
              v-if="can('reports', 'sales')"
            >
              <q-item-section avatar>
                <q-icon name="trending_up" />
              </q-item-section>
              <q-item-section>Sales</q-item-section>
            </q-item>

            <q-separator class="q-my-sm" />
            <q-item-label header class="text-grey-7">REPORTS</q-item-label>

            <!-- Reports -->
            <q-expansion-item
              icon="assessment"
              label="Reports"
              v-if="can('reports', 'sales') || can('reports', 'inventory')"
            >
              <q-item
                clickable
                v-ripple
                to="/reports/daily-sales"
                active-class="nav-active"
                :inset-level="1"
                v-if="can('reports', 'sales')"
              >
                <q-item-section>Daily Sales</q-item-section>
              </q-item>
              <q-item
                clickable
                v-ripple
                to="/reports/kitchen-sales"
                active-class="nav-active"
                :inset-level="1"
                v-if="can('reports', 'sales')"
              >
                <q-item-section>Kitchen-wise Sales</q-item-section>
              </q-item>
              <q-item
                clickable
                v-ripple
                to="/reports/table-sales"
                active-class="nav-active"
                :inset-level="1"
                v-if="can('reports', 'sales')"
              >
                <q-item-section>Table-wise Sales</q-item-section>
              </q-item>
              <q-item
                clickable
                v-ripple
                to="/reports/grn"
                active-class="nav-active"
                :inset-level="1"
                v-if="can('reports', 'inventory')"
              >
                <q-item-section>GRN Report</q-item-section>
              </q-item>
              <q-item
                clickable
                v-ripple
                to="/reports/gin"
                active-class="nav-active"
                :inset-level="1"
                v-if="can('reports', 'inventory')"
              >
                <q-item-section>GIN Report</q-item-section>
              </q-item>
              <q-item
                clickable
                v-ripple
                to="/reports/po"
                active-class="nav-active"
                :inset-level="1"
                v-if="can('reports', 'inventory')"
              >
                <q-item-section>PO Report</q-item-section>
              </q-item>

              <!-- Inventory Reports - SAP Style -->
              <q-item-label header class="text-grey-7 q-pl-lg" style="font-size: 10px"
                >INVENTORY</q-item-label
              >
              <q-item
                clickable
                v-ripple
                to="/reports/inventory-audit"
                active-class="nav-active"
                :inset-level="1"
                v-if="can('reports', 'inventory')"
              >
                <q-item-section>Audit Trail (OINM)</q-item-section>
              </q-item>
              <q-item
                clickable
                v-ripple
                to="/reports/inventory-status"
                active-class="nav-active"
                :inset-level="1"
                v-if="can('reports', 'inventory')"
              >
                <q-item-section>Inventory Status</q-item-section>
              </q-item>
            </q-expansion-item>

            <!-- Admin Only -->
            <template v-if="can('users', 'view') || authStore.isAdmin">
              <q-separator class="q-my-sm" />
              <q-item-label header class="text-grey-7">ADMIN</q-item-label>

              <q-item
                clickable
                v-ripple
                to="/admin/users"
                active-class="nav-active"
                v-if="can('users', 'view')"
              >
                <q-item-section avatar>
                  <q-icon name="manage_accounts" />
                </q-item-section>
                <q-item-section>User Management</q-item-section>
              </q-item>

              <q-item
                clickable
                v-ripple
                to="/admin/settings"
                active-class="nav-active"
                v-if="can('settings', 'view')"
              >
                <q-item-section avatar>
                  <q-icon name="settings" />
                </q-item-section>
                <q-item-section>Settings</q-item-section>
              </q-item>

              <q-item
                clickable
                v-ripple
                to="/admin/approvals"
                active-class="nav-active"
                v-if="can('pending_approvals', 'view')"
              >
                <q-item-section avatar>
                  <q-icon name="approval" />
                </q-item-section>
                <q-item-section>Pending Approvals</q-item-section>
              </q-item>
            </template>
          </q-list>
        </q-scroll-area>
      </q-drawer>

      <!-- Page Container -->
      <q-page-container>
        <router-view />
      </q-page-container>
    </q-layout>
  </q-no-ssr>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useQuasar } from 'quasar'
import { useAuthStore } from 'src/stores/authStore'

const $q = useQuasar()
const router = useRouter()
const authStore = useAuthStore()

const drawerOpen = ref(false) // Default closed to avoid server mismatch
const miniState = ref(true)
const isMounted = ref(false)

onMounted(() => {
  isMounted.value = true
  if ($q.screen.gt.sm) {
    drawerOpen.value = true
  }
})

const userInitials = computed(() => {
  if (!isMounted.value) return 'U'
  const name = authStore.userName
  if (!name) return 'U'
  return name
    .split(' ')
    .map((n) => n[0])
    .join('')
    .toUpperCase()
    .substring(0, 2)
})

function can(resource, action) {
  return authStore.hasPermission(resource, action)
}

function toggleDrawer() {
  drawerOpen.value = !drawerOpen.value
}

function handleLogout() {
  authStore.logout()
  router.push('/login')
}
</script>

<style lang="scss" scoped>
.admin-layout {
  background: #f5f7fa;
}

.app-header {
  background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%);

  .header-title {
    display: flex;
    align-items: center;
    gap: 12px;
    font-weight: 600;
    font-size: 1.1rem;

    .header-logo-icon {
      color: $primary;
    }
  }

  .header-btn,
  .menu-btn,
  .user-btn {
    color: rgba(255, 255, 255, 0.9);
  }
}

.app-drawer {
  background: #ffffff;

  .nav-active {
    background: linear-gradient(135deg, rgba($primary, 0.1) 0%, rgba($accent, 0.1) 100%);
    border-left: 3px solid $primary;
    color: $primary;
    font-weight: 600;
  }

  :deep(.q-item) {
    border-radius: 0 8px 8px 0;
    margin-right: 8px;
    transition: all 0.2s ease;

    &:hover {
      background: rgba($primary, 0.05);
    }
  }

  :deep(.q-expansion-item__toggle-icon) {
    color: $dark;
  }
}

:deep(.q-page-container) {
  background: #f5f7fa;
}
</style>
