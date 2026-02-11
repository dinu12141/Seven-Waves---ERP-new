/**
 * Routes Configuration - SAP HANA Authorization Model
 * Seven Waves ERP
 *
 * Route metadata:
 * - public: Route is publicly accessible (no auth required)
 * - roles: Legacy role-based access (admin, manager, cashier, kitchen, waiter)
 * - permission: Permission-based access in format 'resource.action'
 * - module: Module-level access check
 */

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

  // Customer Menu - Public route for table devices
  {
    path: '/menu',
    component: () => import('pages/CustomerMenuPage.vue'),
    meta: { public: true },
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
        meta: {
          permission: 'dashboard.view',
          roles: [
            'admin',
            'manager',
            'cashier',
            'kitchen',
            'waiter',
            'Z_ALL',
            'Z_STOCK_MGR',
            'Z_INV_CLERK',
            'Z_PROD_STAFF',
            'Z_SALES_STAFF',
          ],
        },
      },

      // HRM Routes
      {
        path: 'hrm/employees',
        component: () => import('pages/hrm/EmployeesPage.vue'),
        meta: {
          permission: 'employees.read',
          module: 'hr',
          roles: ['admin', 'manager', 'Z_ALL', 'Z_HR_MANAGER', 'Z_HR_OFFICER'],
        },
      },
      {
        path: 'hrm/attendance',
        component: () => import('pages/hrm/AttendancePage.vue'),
        meta: {
          permission: 'attendance.view',
          module: 'hr',
          roles: ['admin', 'manager', 'Z_ALL', 'Z_HR_MANAGER', 'Z_HR_OFFICER'],
        },
      },
      {
        path: 'hrm/leaves',
        component: () => import('pages/hrm/LeavesPage.vue'),
        meta: {
          permission: 'leaves.view',
          module: 'hr',
          roles: ['admin', 'manager', 'Z_ALL', 'Z_HR_MANAGER', 'Z_HR_OFFICER'],
        },
      },
      {
        path: 'hrm/salary',
        component: () => import('pages/hrm/SalaryPage.vue'),
        meta: {
          permission: 'salary.view',
          module: 'hr',
          roles: ['admin', 'manager', 'Z_ALL', 'Z_HR_MANAGER'],
        },
      },
      {
        path: 'hrm/register',
        component: () => import('pages/hrm/EmployeeRegistrationPage.vue'),
        meta: {
          permission: 'employees.create',
          module: 'hr',
          roles: ['admin', 'manager', 'Z_ALL', 'Z_HR_MANAGER', 'Z_HR_OFFICER'],
        },
      },

      // Stock Routes - SAP B1 HANA Inventory Module
      {
        path: 'stock/items',
        component: () => import('pages/stock/ItemsPage.vue'),
        meta: {
          permission: 'items.read',
          module: 'inventory',
          roles: ['admin', 'manager', 'Z_ALL', 'Z_STOCK_MGR', 'Z_INV_CLERK'],
        },
      },
      {
        path: 'stock/suppliers',
        component: () => import('pages/stock/SuppliersPage.vue'),
        meta: {
          permission: 'purchase_orders.read',
          module: 'procurement',
          roles: ['admin', 'manager', 'Z_ALL', 'Z_STOCK_MGR', 'Z_INV_CLERK'],
        },
      },
      {
        path: 'stock/warehouses',
        component: () => import('pages/stock/WarehousesPage.vue'),
        meta: {
          permission: 'warehouses.read',
          module: 'inventory',
          roles: ['admin', 'manager', 'Z_ALL', 'Z_STOCK_MGR'],
        },
      },
      {
        path: 'stock/price-lists',
        component: () => import('pages/stock/PriceListsPage.vue'),
        meta: {
          permission: 'items.update_price',
          module: 'inventory',
          roles: ['admin', 'manager', 'Z_ALL', 'Z_STOCK_MGR'],
        },
      },
      {
        path: 'stock/procurement',
        component: () => import('pages/stock/ProcurementPage.vue'),
        meta: {
          permission: 'purchase_orders.read',
          module: 'procurement',
          roles: ['admin', 'manager', 'Z_ALL', 'Z_STOCK_MGR', 'Z_INV_CLERK'],
        },
      },
      {
        path: 'stock/po',
        component: () => import('pages/stock/PurchaseOrderPage.vue'),
        meta: {
          permission: 'purchase_orders.read',
          module: 'procurement',
          roles: ['admin', 'manager', 'Z_ALL', 'Z_STOCK_MGR', 'Z_INV_CLERK'],
        },
      },
      {
        path: 'stock/grn',
        component: () => import('pages/stock/GRNPage.vue'),
        meta: {
          permission: 'grn.read',
          module: 'procurement',
          roles: ['admin', 'manager', 'Z_ALL', 'Z_STOCK_MGR', 'Z_INV_CLERK'],
        },
      },
      {
        path: 'stock/gin',
        component: () => import('pages/stock/GINPage.vue'),
        meta: {
          permission: 'gin.read',
          module: 'procurement',
          roles: ['admin', 'manager', 'Z_ALL', 'Z_STOCK_MGR', 'Z_INV_CLERK'],
        },
      },
      {
        path: 'stock/cycle-count',
        component: () => import('pages/stock/CycleCountPage.vue'),
        meta: {
          permission: 'stock.adjust',
          module: 'inventory',
          roles: ['admin', 'manager', 'Z_ALL', 'Z_STOCK_MGR'],
        },
      },
      {
        path: 'stock/pick-pack',
        component: () => import('pages/stock/PickPackPage.vue'),
        meta: {
          permission: 'stock.view',
          module: 'inventory',
          roles: ['admin', 'manager', 'Z_ALL', 'Z_STOCK_MGR', 'Z_INV_CLERK'],
        },
      },
      {
        path: 'stock/recipes',
        component: () => import('pages/stock/RecipesPage.vue'),
        meta: {
          permission: 'recipes.read',
          module: 'production',
          roles: ['admin', 'manager', 'Z_ALL', 'Z_STOCK_MGR', 'Z_PROD_STAFF'],
        },
      },
      {
        path: 'stock/transfers',
        component: () => import('pages/stock/StockTransferPage.vue'),
        meta: {
          permission: 'stock.transfer',
          module: 'inventory',
          roles: ['admin', 'manager', 'Z_ALL', 'Z_STOCK_MGR', 'Z_INV_CLERK'],
        },
      },
      {
        path: 'stock/requests',
        component: () => import('pages/stock/StockRequestPage.vue'),
        meta: {
          permission: 'stock_requests.read',
          module: 'inventory',
          roles: ['admin', 'manager', 'Z_ALL', 'Z_STOCK_MGR', 'Z_INV_CLERK'],
        },
      },
      {
        path: 'stock/production',
        component: () => import('pages/stock/ProductionOrderPage.vue'),
        meta: {
          permission: 'production_orders.read',
          module: 'production',
          roles: ['admin', 'manager', 'Z_ALL', 'Z_STOCK_MGR', 'Z_PROD_STAFF'],
        },
      },

      // Billing Routes
      {
        path: 'billing',
        component: () => import('pages/billing/POSPage.vue'),
        meta: {
          permission: 'billing.process',
          module: 'sales',
          roles: ['admin', 'manager', 'cashier', 'Z_ALL', 'Z_STOCK_MGR', 'Z_SALES_STAFF'],
        },
      },

      // Operations Routes
      {
        path: 'operations/tables',
        component: () => import('pages/operations/TablesPage.vue'),
        meta: {
          permission: 'tables.view',
          module: 'operations',
          roles: ['admin', 'manager', 'cashier', 'waiter', 'Z_ALL', 'Z_STOCK_MGR', 'Z_SALES_STAFF'],
        },
      },
      {
        path: 'operations/orders',
        component: () => import('pages/operations/OrdersPage.vue'),
        meta: {
          permission: 'orders.read',
          module: 'sales',
          roles: ['admin', 'manager', 'cashier', 'waiter', 'Z_ALL', 'Z_STOCK_MGR', 'Z_SALES_STAFF'],
        },
      },
      {
        path: 'operations/kitchen',
        component: () => import('pages/operations/KitchenDisplayPage.vue'),
        meta: {
          permission: 'kitchen.view',
          module: 'operations',
          roles: ['admin', 'manager', 'kitchen', 'Z_ALL', 'Z_STOCK_MGR', 'Z_PROD_STAFF'],
        },
      },
      {
        path: 'operations/menu',
        component: () => import('pages/operations/MenuPage.vue'),
        meta: {
          permission: 'recipes.read',
          module: 'production',
          roles: ['admin', 'manager', 'Z_ALL', 'Z_STOCK_MGR'],
        },
      },

      // Finance Routes
      {
        path: 'finance/accounts',
        component: () => import('pages/finance/AccountsPage.vue'),
        meta: {
          permission: 'accounts.view',
          module: 'finance',
          roles: ['admin', 'manager', 'Z_ALL', 'Z_FINANCE'],
        },
      },
      {
        path: 'finance/transactions',
        component: () => import('pages/finance/TransactionsPage.vue'),
        meta: {
          permission: 'transactions.view',
          module: 'finance',
          roles: ['admin', 'manager', 'Z_ALL', 'Z_FINANCE'],
        },
      },
      {
        path: 'finance/daily-cash',
        component: () => import('pages/finance/DailyCashPage.vue'),
        meta: {
          permission: 'daily_cash.view',
          module: 'finance',
          roles: ['admin', 'manager', 'Z_ALL', 'Z_FINANCE'],
        },
      },

      // Sales Routes
      {
        path: 'sales',
        component: () => import('pages/sales/SalesPage.vue'),
        meta: {
          permission: 'reports.sales',
          module: 'reports',
          roles: ['admin', 'manager', 'Z_ALL', 'Z_STOCK_MGR'],
        },
      },

      // Reports Routes
      {
        path: 'reports/daily-sales',
        component: () => import('pages/reports/DailySalesReportPage.vue'),
        meta: {
          permission: 'reports.sales',
          module: 'reports',
          roles: ['admin', 'manager', 'Z_ALL', 'Z_STOCK_MGR'],
        },
      },
      {
        path: 'reports/kitchen-sales',
        component: () => import('pages/reports/KitchenSalesPage.vue'),
        meta: {
          permission: 'reports.sales',
          module: 'reports',
          roles: ['admin', 'manager', 'Z_ALL', 'Z_STOCK_MGR'],
        },
      },
      {
        path: 'reports/table-sales',
        component: () => import('pages/reports/TableSalesPage.vue'),
        meta: {
          permission: 'reports.sales',
          module: 'reports',
          roles: ['admin', 'manager', 'Z_ALL', 'Z_STOCK_MGR'],
        },
      },
      {
        path: 'reports/grn',
        component: () => import('pages/reports/GRNReportPage.vue'),
        meta: {
          permission: 'reports.inventory',
          module: 'reports',
          roles: ['admin', 'manager', 'Z_ALL', 'Z_STOCK_MGR'],
        },
      },
      {
        path: 'reports/gin',
        component: () => import('pages/reports/GINReportPage.vue'),
        meta: {
          permission: 'reports.inventory',
          module: 'reports',
          roles: ['admin', 'manager', 'Z_ALL', 'Z_STOCK_MGR'],
        },
      },
      {
        path: 'reports/po',
        component: () => import('pages/reports/POReportPage.vue'),
        meta: {
          permission: 'reports.inventory',
          module: 'reports',
          roles: ['admin', 'manager', 'Z_ALL', 'Z_STOCK_MGR'],
        },
      },
      {
        path: 'reports/inventory-audit',
        component: () => import('pages/reports/InventoryAuditReport.vue'),
        meta: {
          permission: 'reports.inventory',
          module: 'reports',
          roles: ['admin', 'manager', 'Z_ALL', 'Z_STOCK_MGR'],
        },
      },
      {
        path: 'reports/inventory-status',
        component: () => import('pages/reports/InventoryStatusReport.vue'),
        meta: {
          permission: 'reports.inventory',
          module: 'reports',
          roles: ['admin', 'manager', 'Z_ALL', 'Z_STOCK_MGR'],
        },
      },

      // Admin Routes
      {
        path: 'admin/users',
        component: () => import('pages/admin/UsersPage.vue'),
        meta: {
          permission: 'users.view',
          module: 'admin',
          roles: ['admin', 'Z_ALL'],
        },
      },
      {
        path: 'admin/settings',
        component: () => import('pages/admin/SettingsPage.vue'),
        meta: {
          permission: 'settings.view',
          module: 'admin',
          roles: ['admin', 'Z_ALL'],
        },
      },

      // Pending Approvals (Managers only)
      {
        path: 'admin/approvals',
        component: () => import('pages/admin/ApprovalsPage.vue'),
        meta: {
          permission: 'pending_approvals.view',
          module: 'workflow',
          roles: ['admin', 'manager', 'Z_ALL', 'Z_STOCK_MGR', 'Z_HR_MANAGER'],
        },
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
