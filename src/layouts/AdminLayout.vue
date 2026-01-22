<template>
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
            {{ userInitials }}
          </q-avatar>
          <q-menu>
            <q-list style="min-width: 200px">
              <q-item-label header>{{ authStore.userName }}</q-item-label>
              <q-item-label caption class="q-px-md">{{ authStore.userRole }}</q-item-label>
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
      show-if-above
      :mini="miniState"
      @mouseover="miniState = false"
      @mouseout="miniState = true"
      bordered
      class="app-drawer"
    >
      <q-scroll-area class="fit">
        <q-list padding>
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
            v-if="authStore.hasPermission(['admin', 'manager'])"
          >
            <q-item
              clickable
              v-ripple
              to="/hrm/employees"
              active-class="nav-active"
              :inset-level="1"
            >
              <q-item-section>Employees</q-item-section>
            </q-item>
            <q-item
              clickable
              v-ripple
              to="/hrm/attendance"
              active-class="nav-active"
              :inset-level="1"
            >
              <q-item-section>Attendance</q-item-section>
            </q-item>
            <q-item clickable v-ripple to="/hrm/leaves" active-class="nav-active" :inset-level="1">
              <q-item-section>Leaves</q-item-section>
            </q-item>
            <q-item clickable v-ripple to="/hrm/salary" active-class="nav-active" :inset-level="1">
              <q-item-section>Salary</q-item-section>
            </q-item>
          </q-expansion-item>

          <!-- Stock Management -->
          <q-expansion-item
            icon="inventory_2"
            label="Stock"
            v-if="authStore.hasPermission(['admin', 'manager'])"
          >
            <q-item clickable v-ripple to="/stock/items" active-class="nav-active" :inset-level="1">
              <q-item-section>Items</q-item-section>
            </q-item>
            <q-item
              clickable
              v-ripple
              to="/stock/suppliers"
              active-class="nav-active"
              :inset-level="1"
            >
              <q-item-section>Suppliers</q-item-section>
            </q-item>
            <q-item clickable v-ripple to="/stock/po" active-class="nav-active" :inset-level="1">
              <q-item-section>Purchase Orders</q-item-section>
            </q-item>
            <q-item clickable v-ripple to="/stock/grn" active-class="nav-active" :inset-level="1">
              <q-item-section>GRN</q-item-section>
            </q-item>
            <q-item clickable v-ripple to="/stock/gin" active-class="nav-active" :inset-level="1">
              <q-item-section>GIN</q-item-section>
            </q-item>
          </q-expansion-item>

          <!-- Billing -->
          <q-item
            clickable
            v-ripple
            to="/billing"
            active-class="nav-active"
            v-if="authStore.hasPermission(['admin', 'manager', 'cashier'])"
          >
            <q-item-section avatar>
              <q-icon name="point_of_sale" />
            </q-item-section>
            <q-item-section>Billing</q-item-section>
          </q-item>

          <!-- Operations -->
          <q-expansion-item icon="restaurant" label="Operations">
            <q-item
              clickable
              v-ripple
              to="/operations/tables"
              active-class="nav-active"
              :inset-level="1"
            >
              <q-item-section>Tables</q-item-section>
            </q-item>
            <q-item
              clickable
              v-ripple
              to="/operations/orders"
              active-class="nav-active"
              :inset-level="1"
            >
              <q-item-section>Orders</q-item-section>
            </q-item>
            <q-item
              clickable
              v-ripple
              to="/operations/kitchen"
              active-class="nav-active"
              :inset-level="1"
              v-if="authStore.hasPermission(['admin', 'manager', 'kitchen'])"
            >
              <q-item-section>Kitchen Display</q-item-section>
            </q-item>
            <q-item
              clickable
              v-ripple
              to="/operations/menu"
              active-class="nav-active"
              :inset-level="1"
              v-if="authStore.hasPermission(['admin', 'manager'])"
            >
              <q-item-section>Menu</q-item-section>
            </q-item>
          </q-expansion-item>

          <!-- Finance -->
          <q-expansion-item
            icon="account_balance"
            label="Finance"
            v-if="authStore.hasPermission(['admin', 'manager'])"
          >
            <q-item
              clickable
              v-ripple
              to="/finance/accounts"
              active-class="nav-active"
              :inset-level="1"
            >
              <q-item-section>Accounts</q-item-section>
            </q-item>
            <q-item
              clickable
              v-ripple
              to="/finance/transactions"
              active-class="nav-active"
              :inset-level="1"
            >
              <q-item-section>Transactions</q-item-section>
            </q-item>
            <q-item
              clickable
              v-ripple
              to="/finance/daily-cash"
              active-class="nav-active"
              :inset-level="1"
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
            v-if="authStore.hasPermission(['admin', 'manager'])"
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
            v-if="authStore.hasPermission(['admin', 'manager'])"
          >
            <q-item
              clickable
              v-ripple
              to="/reports/daily-sales"
              active-class="nav-active"
              :inset-level="1"
            >
              <q-item-section>Daily Sales</q-item-section>
            </q-item>
            <q-item
              clickable
              v-ripple
              to="/reports/kitchen-sales"
              active-class="nav-active"
              :inset-level="1"
            >
              <q-item-section>Kitchen-wise Sales</q-item-section>
            </q-item>
            <q-item
              clickable
              v-ripple
              to="/reports/table-sales"
              active-class="nav-active"
              :inset-level="1"
            >
              <q-item-section>Table-wise Sales</q-item-section>
            </q-item>
            <q-item clickable v-ripple to="/reports/grn" active-class="nav-active" :inset-level="1">
              <q-item-section>GRN Report</q-item-section>
            </q-item>
            <q-item clickable v-ripple to="/reports/gin" active-class="nav-active" :inset-level="1">
              <q-item-section>GIN Report</q-item-section>
            </q-item>
            <q-item clickable v-ripple to="/reports/po" active-class="nav-active" :inset-level="1">
              <q-item-section>PO Report</q-item-section>
            </q-item>
          </q-expansion-item>

          <!-- Admin Only -->
          <template v-if="authStore.isAdmin">
            <q-separator class="q-my-sm" />
            <q-item-label header class="text-grey-7">ADMIN</q-item-label>

            <q-item clickable v-ripple to="/admin/users" active-class="nav-active">
              <q-item-section avatar>
                <q-icon name="manage_accounts" />
              </q-item-section>
              <q-item-section>User Management</q-item-section>
            </q-item>

            <q-item clickable v-ripple to="/admin/settings" active-class="nav-active">
              <q-item-section avatar>
                <q-icon name="settings" />
              </q-item-section>
              <q-item-section>Settings</q-item-section>
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
</template>

<script setup>
import { ref, computed } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from 'src/stores/authStore'

const router = useRouter()
const authStore = useAuthStore()

const drawerOpen = ref(true)
const miniState = ref(true)

const userInitials = computed(() => {
  const name = authStore.userName
  if (!name) return 'U'
  return name
    .split(' ')
    .map((n) => n[0])
    .join('')
    .toUpperCase()
    .substring(0, 2)
})

function toggleDrawer() {
  drawerOpen.value = !drawerOpen.value
}

async function handleLogout() {
  await authStore.logout()
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
