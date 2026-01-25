const routes = [
  // Public routes
  {
    path: '/login',
    component: () => import('layouts/AuthLayout.vue'),
    meta: { public: true },
    children: [
      {
        path: '',
        component: () => import('pages/auth/LoginPage.vue'),
      },
    ],
  },

  // Admin/Dashboard routes
  {
    path: '/',
    component: () => import('layouts/AdminLayout.vue'),
    children: [
      {
        path: '',
        redirect: '/dashboard',
      },
      {
        path: 'dashboard',
        component: () => import('pages/DashboardPage.vue'),
        meta: { roles: ['admin', 'manager', 'cashier', 'kitchen', 'waiter'] },
      },

      // HRM Routes
      {
        path: 'hrm/employees',
        component: () => import('pages/hrm/EmployeesPage.vue'),
        meta: { roles: ['admin', 'manager'] },
      },
      {
        path: 'hrm/attendance',
        component: () => import('pages/hrm/AttendancePage.vue'),
        meta: { roles: ['admin', 'manager'] },
      },
      {
        path: 'hrm/leaves',
        component: () => import('pages/hrm/LeavesPage.vue'),
        meta: { roles: ['admin', 'manager'] },
      },
      {
        path: 'hrm/salary',
        component: () => import('pages/hrm/SalaryPage.vue'),
        meta: { roles: ['admin', 'manager'] },
      },

      // Stock Routes - SAP B1 HANA Inventory Module
      {
        path: 'stock/items',
        component: () => import('pages/stock/ItemsPage.vue'),
        meta: { roles: ['admin', 'manager'] },
      },
      {
        path: 'stock/suppliers',
        component: () => import('pages/stock/SuppliersPage.vue'),
        meta: { roles: ['admin', 'manager'] },
      },
      {
        path: 'stock/warehouses',
        component: () => import('pages/stock/WarehousesPage.vue'),
        meta: { roles: ['admin', 'manager'] },
      },
      {
        path: 'stock/price-lists',
        component: () => import('pages/stock/PriceListsPage.vue'),
        meta: { roles: ['admin', 'manager'] },
      },
      {
        path: 'stock/procurement',
        component: () => import('pages/stock/ProcurementPage.vue'),
        meta: { roles: ['admin', 'manager'] },
      },
      {
        path: 'stock/po',
        component: () => import('pages/stock/PurchaseOrderPage.vue'),
        meta: { roles: ['admin', 'manager'] },
      },
      {
        path: 'stock/grn',
        component: () => import('pages/stock/GRNPage.vue'),
        meta: { roles: ['admin', 'manager'] },
      },
      {
        path: 'stock/gin',
        component: () => import('pages/stock/GINPage.vue'),
        meta: { roles: ['admin', 'manager'] },
      },
      {
        path: 'stock/cycle-count',
        component: () => import('pages/stock/CycleCountPage.vue'),
        meta: { roles: ['admin', 'manager'] },
      },
      {
        path: 'stock/pick-pack',
        component: () => import('pages/stock/PickPackPage.vue'),
        meta: { roles: ['admin', 'manager'] },
      },
      {
        path: 'stock/recipes',
        component: () => import('pages/stock/RecipesPage.vue'),
        meta: { roles: ['admin', 'manager'] },
      },
      {
        path: 'stock/transfers',
        component: () => import('pages/stock/StockTransferPage.vue'),
        meta: { roles: ['admin', 'manager'] },
      },

      // Billing Routes
      {
        path: 'billing',
        component: () => import('pages/billing/POSPage.vue'),
        meta: { roles: ['admin', 'manager', 'cashier'] },
      },

      // Operations Routes
      {
        path: 'operations/tables',
        component: () => import('pages/operations/TablesPage.vue'),
        meta: { roles: ['admin', 'manager', 'cashier', 'waiter'] },
      },
      {
        path: 'operations/orders',
        component: () => import('pages/operations/OrdersPage.vue'),
        meta: { roles: ['admin', 'manager', 'cashier', 'waiter'] },
      },
      {
        path: 'operations/kitchen',
        component: () => import('pages/operations/KitchenDisplayPage.vue'),
        meta: { roles: ['admin', 'manager', 'kitchen'] },
      },
      {
        path: 'operations/menu',
        component: () => import('pages/operations/MenuPage.vue'),
        meta: { roles: ['admin', 'manager'] },
      },

      // Finance Routes
      {
        path: 'finance/accounts',
        component: () => import('pages/finance/AccountsPage.vue'),
        meta: { roles: ['admin', 'manager'] },
      },
      {
        path: 'finance/transactions',
        component: () => import('pages/finance/TransactionsPage.vue'),
        meta: { roles: ['admin', 'manager'] },
      },
      {
        path: 'finance/daily-cash',
        component: () => import('pages/finance/DailyCashPage.vue'),
        meta: { roles: ['admin', 'manager'] },
      },

      // Sales Routes
      {
        path: 'sales',
        component: () => import('pages/sales/SalesPage.vue'),
        meta: { roles: ['admin', 'manager'] },
      },

      // Reports Routes
      {
        path: 'reports/daily-sales',
        component: () => import('pages/reports/DailySalesReportPage.vue'),
        meta: { roles: ['admin', 'manager'] },
      },
      {
        path: 'reports/kitchen-sales',
        component: () => import('pages/reports/KitchenSalesPage.vue'),
        meta: { roles: ['admin', 'manager'] },
      },
      {
        path: 'reports/table-sales',
        component: () => import('pages/reports/TableSalesPage.vue'),
        meta: { roles: ['admin', 'manager'] },
      },
      {
        path: 'reports/grn',
        component: () => import('pages/reports/GRNReportPage.vue'),
        meta: { roles: ['admin', 'manager'] },
      },
      {
        path: 'reports/gin',
        component: () => import('pages/reports/GINReportPage.vue'),
        meta: { roles: ['admin', 'manager'] },
      },
      {
        path: 'reports/po',
        component: () => import('pages/reports/POReportPage.vue'),
        meta: { roles: ['admin', 'manager'] },
      },
      {
        path: 'reports/inventory-audit',
        component: () => import('pages/reports/InventoryAuditReport.vue'),
        meta: { roles: ['admin', 'manager'] },
      },
      {
        path: 'reports/inventory-status',
        component: () => import('pages/reports/InventoryStatusReport.vue'),
        meta: { roles: ['admin', 'manager'] },
      },

      // Admin Routes
      {
        path: 'admin/users',
        component: () => import('pages/admin/UsersPage.vue'),
        meta: { roles: ['admin'] },
      },
      {
        path: 'admin/settings',
        component: () => import('pages/admin/SettingsPage.vue'),
        meta: { roles: ['admin'] },
      },
    ],
  },

  // Always leave this as last one
  {
    path: '/:catchAll(.*)*',
    component: () => import('pages/ErrorNotFound.vue'),
  },
]

export default routes
