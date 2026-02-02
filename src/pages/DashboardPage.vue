<template>
  <q-page class="dashboard-page">
    <div class="page-header">
      <h1 class="page-title">Dashboard</h1>
      <p class="page-subtitle">Welcome back, {{ authStore.userName }}!</p>
    </div>

    <!-- KPI Cards -->
    <div class="kpi-grid">
      <q-card class="kpi-card sales-card">
        <q-card-section>
          <div class="kpi-icon">
            <q-icon name="payments" size="32px" />
          </div>
          <div class="kpi-content">
            <span class="kpi-label">Today's Sales</span>
            <span class="kpi-value">Rs. 0.00</span>
            <span class="kpi-change positive">+0% from yesterday</span>
          </div>
        </q-card-section>
      </q-card>

      <q-card class="kpi-card orders-card">
        <q-card-section>
          <div class="kpi-icon">
            <q-icon name="receipt_long" size="32px" />
          </div>
          <div class="kpi-content">
            <span class="kpi-label">Total Orders</span>
            <span class="kpi-value">0</span>
            <span class="kpi-change">Today</span>
          </div>
        </q-card-section>
      </q-card>

      <q-card class="kpi-card tables-card">
        <q-card-section>
          <div class="kpi-icon">
            <q-icon name="table_restaurant" size="32px" />
          </div>
          <div class="kpi-content">
            <span class="kpi-label">Active Tables</span>
            <span class="kpi-value">0 / 0</span>
            <span class="kpi-change">Occupied</span>
          </div>
        </q-card-section>
      </q-card>

      <q-card class="kpi-card stock-card">
        <q-card-section>
          <div class="kpi-icon">
            <q-icon name="warning" size="32px" />
          </div>
          <div class="kpi-content">
            <span class="kpi-label">Low Stock Items</span>
            <span class="kpi-value">0</span>
            <span class="kpi-change negative">Needs attention</span>
          </div>
        </q-card-section>
      </q-card>
    </div>

    <!-- Quick Actions -->
    <div class="section-header">
      <h2>Quick Actions</h2>
    </div>
    <div class="quick-actions">
      <q-btn
        class="action-btn"
        color="primary"
        icon="add_shopping_cart"
        label="New Order"
        @click="$router.push('/operations/orders')"
      />
      <q-btn
        class="action-btn"
        color="secondary"
        icon="point_of_sale"
        label="Billing"
        @click="$router.push('/billing')"
      />
      <q-btn
        class="action-btn"
        color="accent"
        icon="inventory"
        label="Stock"
        @click="$router.push('/stock/items')"
        v-if="authStore.hasPermission(['admin', 'manager'])"
      />
      <q-btn
        class="action-btn"
        outline
        color="dark"
        icon="assessment"
        label="Reports"
        @click="$router.push('/reports/daily-sales')"
        v-if="authStore.hasPermission(['admin', 'manager'])"
      />
    </div>

    <!-- Placeholder for charts and recent activity -->
    <div class="charts-section">
      <q-card class="chart-card">
        <q-card-section class="card-header">
          <span class="card-title">Sales Overview</span>
        </q-card-section>
        <q-card-section class="chart-placeholder">
          <q-icon name="insert_chart" size="64px" color="grey-4" />
          <p>Sales chart will appear here</p>
        </q-card-section>
      </q-card>

      <q-card class="chart-card">
        <q-card-section class="card-header">
          <span class="card-title">Recent Orders</span>
        </q-card-section>
        <q-card-section class="chart-placeholder">
          <q-icon name="list_alt" size="64px" color="grey-4" />
          <p>Recent orders will appear here</p>
        </q-card-section>
      </q-card>
    </div>
  </q-page>
</template>

<script setup>
import { onMounted, onUnmounted } from 'vue'
import { useAuthStore } from 'src/stores/authStore'
import { useStockStore } from 'src/stores/stockStore'

const authStore = useAuthStore()
const stockStore = useStockStore()

onMounted(() => {
  stockStore.subscribeToRealtime()
  // Fetch initial data for KPIs
  stockStore.fetchItems()
  stockStore.fetchPurchaseOrders()
  stockStore.fetchGoodsReceiptNotes()
  stockStore.checkStockAlerts()
})

onUnmounted(() => {
  stockStore.unsubscribeRealtime()
})
</script>

<style lang="scss" scoped>
@use 'sass:color';

.dashboard-page {
  padding: 24px;
}

.page-header {
  margin-bottom: 30px;

  .page-title {
    font-size: 1.8rem;
    font-weight: 700;
    color: #1a1a2e;
    margin: 0;
  }

  .page-subtitle {
    color: #666;
    margin: 5px 0 0;
  }
}

.kpi-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
  gap: 20px;
  margin-bottom: 30px;
}

.kpi-card {
  border-radius: 16px;
  overflow: hidden;
  transition:
    transform 0.2s ease,
    box-shadow 0.2s ease;

  &:hover {
    transform: translateY(-4px);
    box-shadow: 0 12px 40px rgba(0, 0, 0, 0.15);
  }

  .q-card__section {
    display: flex;
    align-items: center;
    gap: 16px;
    padding: 20px;
  }

  .kpi-icon {
    width: 60px;
    height: 60px;
    border-radius: 12px;
    display: flex;
    align-items: center;
    justify-content: center;
    color: white;
  }

  .kpi-content {
    display: flex;
    flex-direction: column;
  }

  .kpi-label {
    font-size: 0.85rem;
    color: #666;
  }

  .kpi-value {
    font-size: 1.5rem;
    font-weight: 700;
    color: #1a1a2e;
  }

  .kpi-change {
    font-size: 0.8rem;
    color: #999;

    &.positive {
      color: #21ba45;
    }

    &.negative {
      color: #c10015;
    }
  }
}

.sales-card .kpi-icon {
  background: linear-gradient(135deg, $primary, color.adjust($primary, $lightness: -10%));
}

.orders-card .kpi-icon {
  background: linear-gradient(135deg, $secondary, color.adjust($secondary, $lightness: -10%));
}

.tables-card .kpi-icon {
  background: linear-gradient(135deg, $accent, color.adjust($accent, $lightness: -10%));
}

.stock-card .kpi-icon {
  background: linear-gradient(135deg, #c10015, color.adjust(#c10015, $lightness: -10%));
}

.section-header {
  margin-bottom: 16px;

  h2 {
    font-size: 1.2rem;
    font-weight: 600;
    color: #1a1a2e;
    margin: 0;
  }
}

.quick-actions {
  display: flex;
  gap: 12px;
  flex-wrap: wrap;
  margin-bottom: 30px;

  .action-btn {
    border-radius: 10px;
    font-weight: 500;
  }
}

.charts-section {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(400px, 1fr));
  gap: 20px;
}

.chart-card {
  border-radius: 16px;

  .card-header {
    border-bottom: 1px solid #eee;
    padding-bottom: 12px;
  }

  .card-title {
    font-weight: 600;
    color: #1a1a2e;
  }

  .chart-placeholder {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    min-height: 200px;
    color: #999;

    p {
      margin: 10px 0 0;
    }
  }
}
</style>
