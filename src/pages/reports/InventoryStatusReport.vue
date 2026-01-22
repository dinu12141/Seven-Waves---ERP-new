<template>
  <q-page class="sap-page">
    <SAPToolbar
      title="Inventory Status Report"
      icon="assessment"
      :show-add="false"
      :show-export="true"
      :show-filter="true"
      @refresh="loadData"
      @export="exportReport"
      @filter="showFilters = !showFilters"
    />

    <div class="sap-page-content">
      <!-- Filters -->
      <transition name="slide">
        <SAPCard v-if="showFilters" class="q-mb-md" flat bordered>
          <div class="row q-col-gutter-md items-end">
            <div class="col-12 col-md-3">
              <label class="sap-label">Warehouse</label>
              <SAPSelect
                v-model="filters.warehouse_id"
                :options="[{ id: null, name: 'All Warehouses' }, ...stockStore.warehouses]"
                option-label="name"
                option-value="id"
                dense
              />
            </div>
            <div class="col-12 col-md-3">
              <label class="sap-label">Category</label>
              <SAPSelect
                v-model="filters.category_id"
                :options="[{ id: null, name: 'All Categories' }, ...stockStore.categories]"
                option-label="name"
                option-value="id"
                dense
              />
            </div>
            <div class="col-12 col-md-2">
              <label class="sap-label">Stock Status</label>
              <SAPSelect
                v-model="filters.stock_status"
                :options="stockStatuses"
                option-label="label"
                option-value="value"
                dense
              />
            </div>
            <div class="col-12 col-md-2">
              <label class="sap-label">Item Type</label>
              <SAPSelect
                v-model="filters.item_type"
                :options="itemTypes"
                option-label="label"
                option-value="value"
                dense
              />
            </div>
            <div class="col-12 col-md-2">
              <q-btn color="primary" label="Apply" dense @click="applyFilters" class="full-width" />
            </div>
          </div>
        </SAPCard>
      </transition>

      <!-- Summary Cards -->
      <div class="row q-col-gutter-md q-mb-md">
        <div class="col-6 col-md-2">
          <SAPCard flat bordered>
            <div class="stat-card compact">
              <div class="stat-value text-primary">{{ filteredItems.length }}</div>
              <div class="stat-label">Total Items</div>
            </div>
          </SAPCard>
        </div>
        <div class="col-6 col-md-2">
          <SAPCard flat bordered>
            <div class="stat-card compact">
              <div class="stat-value text-positive">{{ formatNumber(totals.inStock) }}</div>
              <div class="stat-label">In Stock</div>
            </div>
          </SAPCard>
        </div>
        <div class="col-6 col-md-2">
          <SAPCard flat bordered>
            <div class="stat-card compact">
              <div class="stat-value text-warning">{{ formatNumber(totals.committed) }}</div>
              <div class="stat-label">Committed</div>
            </div>
          </SAPCard>
        </div>
        <div class="col-6 col-md-2">
          <SAPCard flat bordered>
            <div class="stat-card compact">
              <div class="stat-value text-info">{{ formatNumber(totals.ordered) }}</div>
              <div class="stat-label">Ordered</div>
            </div>
          </SAPCard>
        </div>
        <div class="col-6 col-md-2">
          <SAPCard flat bordered>
            <div class="stat-card compact">
              <div class="stat-value text-accent">{{ formatNumber(totals.available) }}</div>
              <div class="stat-label">Available</div>
            </div>
          </SAPCard>
        </div>
        <div class="col-6 col-md-2">
          <SAPCard flat bordered>
            <div class="stat-card compact">
              <div class="stat-value">{{ formatCurrency(totals.value) }}</div>
              <div class="stat-label">Total Value</div>
            </div>
          </SAPCard>
        </div>
      </div>

      <!-- Inventory Status Table -->
      <SAPCard title="Inventory Status" icon="inventory" no-padding>
        <template #header-right>
          <q-btn-toggle
            v-model="viewMode"
            dense
            flat
            :options="[
              { value: 'summary', label: 'Summary' },
              { value: 'warehouse', label: 'By Warehouse' },
            ]"
            toggle-color="primary"
          />
        </template>

        <!-- Summary View -->
        <SAPTable
          v-if="viewMode === 'summary'"
          :rows="filteredItems"
          :columns="summaryColumns"
          :loading="stockStore.loading"
          :show-drill-down="true"
          row-key="id"
          @drill-down="viewItemDetail"
        >
          <template #body-cell-item_code="props">
            <q-td :props="props">
              <div class="row items-center no-wrap">
                <span class="text-bold">{{ props.value }}</span>
                <GoldenArrow @click="viewItemDetail(props.row)" />
              </div>
            </q-td>
          </template>

          <template #body-cell-in_stock="props">
            <q-td :props="props" class="text-right">
              <span class="text-bold">{{ formatNumber(props.value) }}</span>
            </q-td>
          </template>

          <template #body-cell-committed="props">
            <q-td :props="props" class="text-right text-warning">
              {{ formatNumber(props.value) }}
            </q-td>
          </template>

          <template #body-cell-ordered="props">
            <q-td :props="props" class="text-right text-info">
              {{ formatNumber(props.value) }}
            </q-td>
          </template>

          <template #body-cell-available="props">
            <q-td :props="props" class="text-right">
              <span :class="getAvailableClass(props.row)" class="text-bold">
                {{ formatNumber(props.value) }}
              </span>
            </q-td>
          </template>

          <template #body-cell-stock_status="props">
            <q-td :props="props" class="text-center">
              <q-badge :color="getStockStatusColor(props.row)" :label="getStockStatus(props.row)" />
            </q-td>
          </template>

          <template #body-cell-stock_value="props">
            <q-td :props="props" class="text-right">
              {{ formatCurrency(props.value) }}
            </q-td>
          </template>
        </SAPTable>

        <!-- Warehouse Detail View -->
        <SAPTable
          v-else
          :rows="warehouseDetails"
          :columns="warehouseColumns"
          :loading="stockStore.loading"
          row-key="id"
        >
          <template #body-cell-item="props">
            <q-td :props="props">
              <div class="row items-center no-wrap">
                <span class="text-bold">{{ props.row.item?.item_code }}</span>
                <GoldenArrow @click="viewItemDetail(props.row.item)" />
              </div>
              <div class="text-caption text-grey-7">{{ props.row.item?.item_name }}</div>
            </q-td>
          </template>

          <template #body-cell-warehouse="props">
            <q-td :props="props">
              <q-badge color="primary" :label="props.row.warehouse?.code" class="q-mr-xs" />
              {{ props.row.warehouse?.name }}
            </q-td>
          </template>

          <template #body-cell-quantity_on_hand="props">
            <q-td :props="props" class="text-right text-bold">
              {{ formatNumber(props.value) }}
            </q-td>
          </template>

          <template #body-cell-average_cost="props">
            <q-td :props="props" class="text-right">
              {{ formatCurrency(props.value) }}
            </q-td>
          </template>

          <template #body-cell-stock_value="props">
            <q-td :props="props" class="text-right text-bold">
              {{ formatCurrency(props.row.quantity_on_hand * (props.row.average_cost || 0)) }}
            </q-td>
          </template>
        </SAPTable>
      </SAPCard>
    </div>

    <!-- Item Detail Dialog -->
    <SAPDialog
      v-model="showDetailDialog"
      :title="selectedItem?.item_name || 'Item Details'"
      icon="inventory_2"
      width="900px"
      :show-default-footer="false"
    >
      <template v-if="selectedItem">
        <q-tabs v-model="detailTab" dense class="text-grey" active-color="primary">
          <q-tab name="stock" label="Stock by Warehouse" icon="warehouse" />
          <q-tab name="transactions" label="Recent Transactions" icon="history" />
        </q-tabs>

        <q-separator />

        <q-tab-panels v-model="detailTab" animated>
          <q-tab-panel name="stock">
            <div class="row q-col-gutter-md q-mb-md">
              <div class="col-3">
                <div class="detail-label">Item Code</div>
                <div class="detail-value text-bold">{{ selectedItem.item_code }}</div>
              </div>
              <div class="col-3">
                <div class="detail-label">Total In Stock</div>
                <div class="detail-value text-h6 text-positive">
                  {{ formatNumber(getItemTotals(selectedItem).inStock) }}
                </div>
              </div>
              <div class="col-3">
                <div class="detail-label">Available</div>
                <div class="detail-value text-h6" :class="getAvailableClass(selectedItem)">
                  {{ formatNumber(getItemTotals(selectedItem).available) }}
                </div>
              </div>
              <div class="col-3">
                <div class="detail-label">Total Value</div>
                <div class="detail-value text-h6">
                  {{ formatCurrency(getItemTotals(selectedItem).value) }}
                </div>
              </div>
            </div>

            <SAPTable
              :rows="selectedItem.warehouse_stock || []"
              :columns="itemWarehouseColumns"
              :show-search="false"
              row-key="id"
            >
              <template #body-cell-warehouse="props">
                <q-td :props="props">
                  {{ props.row.warehouse?.name }}
                </q-td>
              </template>
              <template #body-cell-average_cost="props">
                <q-td :props="props" class="text-right">
                  {{ formatCurrency(props.value) }}
                </q-td>
              </template>
              <template #body-cell-stock_value="props">
                <q-td :props="props" class="text-right text-bold">
                  {{ formatCurrency(props.row.quantity_on_hand * (props.row.average_cost || 0)) }}
                </q-td>
              </template>
            </SAPTable>
          </q-tab-panel>

          <q-tab-panel name="transactions">
            <SAPTable
              :rows="itemTransactions"
              :columns="transactionColumns"
              :loading="loadingTransactions"
              :show-search="false"
              row-key="id"
            >
              <template #body-cell-quantity="props">
                <q-td :props="props" class="text-right">
                  <span :class="props.value >= 0 ? 'text-positive' : 'text-negative'">
                    {{ props.value >= 0 ? '+' : '' }}{{ formatNumber(props.value) }}
                  </span>
                </q-td>
              </template>
            </SAPTable>
          </q-tab-panel>
        </q-tab-panels>
      </template>
    </SAPDialog>
  </q-page>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useQuasar } from 'quasar'
import { useStockStore } from 'src/stores/stockStore'
import {
  SAPTable,
  SAPCard,
  SAPToolbar,
  SAPDialog,
  SAPSelect,
  GoldenArrow,
} from 'src/components/sap'

const $q = useQuasar()
const stockStore = useStockStore()

// State
const showFilters = ref(true)
const showDetailDialog = ref(false)
const viewMode = ref('summary')
const detailTab = ref('stock')
const selectedItem = ref(null)
const itemTransactions = ref([])
const loadingTransactions = ref(false)

const filters = ref({
  warehouse_id: null,
  category_id: null,
  stock_status: null,
  item_type: null,
})

const stockStatuses = [
  { value: null, label: 'All' },
  { value: 'in_stock', label: 'In Stock' },
  { value: 'low_stock', label: 'Low Stock' },
  { value: 'out_of_stock', label: 'Out of Stock' },
  { value: 'over_stock', label: 'Over Stock' },
]

const itemTypes = [
  { value: null, label: 'All' },
  { value: 'purchase', label: 'Purchase Items' },
  { value: 'sales', label: 'Sales Items' },
]

const summaryColumns = [
  {
    name: 'item_code',
    label: 'Item No.',
    field: 'item_code',
    sortable: true,
    align: 'left',
    style: 'width: 120px',
  },
  { name: 'item_name', label: 'Description', field: 'item_name', sortable: true, align: 'left' },
  { name: 'category', label: 'Category', field: (row) => row.category?.name || '—', align: 'left' },
  { name: 'uom', label: 'UoM', field: (row) => row.base_uom?.code, align: 'center' },
  {
    name: 'in_stock',
    label: 'In Stock',
    field: (row) => getItemTotals(row).inStock,
    sortable: true,
    align: 'right',
  },
  {
    name: 'committed',
    label: 'Committed',
    field: (row) => getItemTotals(row).committed,
    align: 'right',
  },
  { name: 'ordered', label: 'Ordered', field: (row) => getItemTotals(row).ordered, align: 'right' },
  {
    name: 'available',
    label: 'Available',
    field: (row) => getItemTotals(row).available,
    sortable: true,
    align: 'right',
  },
  { name: 'stock_status', label: 'Status', field: 'stock_status', align: 'center' },
  {
    name: 'stock_value',
    label: 'Value',
    field: (row) => getItemTotals(row).value,
    sortable: true,
    align: 'right',
  },
]

const warehouseColumns = [
  { name: 'item', label: 'Item', field: 'item', align: 'left', style: 'width: 250px' },
  { name: 'warehouse', label: 'Warehouse', field: 'warehouse', align: 'left' },
  {
    name: 'quantity_on_hand',
    label: 'On Hand',
    field: 'quantity_on_hand',
    sortable: true,
    align: 'right',
  },
  { name: 'quantity_committed', label: 'Committed', field: 'quantity_committed', align: 'right' },
  { name: 'quantity_ordered', label: 'Ordered', field: 'quantity_ordered', align: 'right' },
  { name: 'average_cost', label: 'Avg Cost', field: 'average_cost', align: 'right' },
  { name: 'stock_value', label: 'Value', field: 'stock_value', sortable: true, align: 'right' },
]

const itemWarehouseColumns = [
  { name: 'warehouse', label: 'Warehouse', field: 'warehouse', align: 'left' },
  { name: 'quantity_on_hand', label: 'On Hand', field: 'quantity_on_hand', align: 'right' },
  { name: 'quantity_committed', label: 'Committed', field: 'quantity_committed', align: 'right' },
  { name: 'quantity_ordered', label: 'Ordered', field: 'quantity_ordered', align: 'right' },
  { name: 'average_cost', label: 'Avg Cost', field: 'average_cost', align: 'right' },
  { name: 'stock_value', label: 'Value', field: 'stock_value', align: 'right' },
]

const transactionColumns = [
  { name: 'date', label: 'Date', field: (row) => formatDate(row.transaction_date), align: 'left' },
  { name: 'doc', label: 'Document', field: 'doc_number', align: 'left' },
  {
    name: 'type',
    label: 'Type',
    field: (row) => row.transaction_type?.replace(/_/g, ' '),
    align: 'left',
    classes: 'text-capitalize',
  },
  { name: 'warehouse', label: 'Warehouse', field: (row) => row.warehouse?.name, align: 'left' },
  { name: 'quantity', label: 'Qty', field: 'quantity', align: 'right' },
  { name: 'balance', label: 'Balance', field: 'balance_after', align: 'right' },
]

// Computed
const filteredItems = computed(() => {
  let items = stockStore.items

  if (filters.value.category_id) {
    items = items.filter((i) => i.category_id === filters.value.category_id)
  }

  if (filters.value.item_type === 'purchase') {
    items = items.filter((i) => i.is_purchase_item)
  } else if (filters.value.item_type === 'sales') {
    items = items.filter((i) => i.is_sales_item)
  }

  if (filters.value.stock_status) {
    items = items.filter(
      (i) => getStockStatus(i).toLowerCase().replace(' ', '_') === filters.value.stock_status,
    )
  }

  if (filters.value.warehouse_id) {
    items = items.filter((i) =>
      i.warehouse_stock?.some(
        (ws) => ws.warehouse_id === filters.value.warehouse_id && ws.quantity_on_hand > 0,
      ),
    )
  }

  return items
})

const warehouseDetails = computed(() => {
  const details = []
  filteredItems.value.forEach((item) => {
    ;(item.warehouse_stock || []).forEach((ws) => {
      if (!filters.value.warehouse_id || ws.warehouse_id === filters.value.warehouse_id) {
        details.push({ ...ws, item })
      }
    })
  })
  return details
})

const totals = computed(() => {
  return filteredItems.value.reduce(
    (acc, item) => {
      const t = getItemTotals(item)
      acc.inStock += t.inStock
      acc.committed += t.committed
      acc.ordered += t.ordered
      acc.available += t.available
      acc.value += t.value
      return acc
    },
    { inStock: 0, committed: 0, ordered: 0, available: 0, value: 0 },
  )
})

// Methods
function formatNumber(value) {
  if (value == null) return '—'
  return new Intl.NumberFormat('en-US', { maximumFractionDigits: 3 }).format(value)
}

function formatCurrency(value) {
  if (value == null) return '—'
  return new Intl.NumberFormat('en-US', { style: 'currency', currency: 'LKR' }).format(value)
}

function formatDate(date) {
  if (!date) return '—'
  return new Date(date).toLocaleDateString()
}

function getItemTotals(item) {
  if (!item.warehouse_stock) return { inStock: 0, committed: 0, ordered: 0, available: 0, value: 0 }

  const inStock = item.warehouse_stock.reduce((s, ws) => s + (ws.quantity_on_hand || 0), 0)
  const committed = item.warehouse_stock.reduce((s, ws) => s + (ws.quantity_committed || 0), 0)
  const ordered = item.warehouse_stock.reduce((s, ws) => s + (ws.quantity_ordered || 0), 0)
  const available = inStock - committed + ordered
  const value = item.warehouse_stock.reduce(
    (s, ws) => s + (ws.quantity_on_hand || 0) * (ws.average_cost || 0),
    0,
  )

  return { inStock, committed, ordered, available, value }
}

function getStockStatus(item) {
  const { inStock, available } = getItemTotals(item)
  const reorderPoint = item.reorder_point || 0
  const maxStock = item.max_stock_level || Infinity

  if (inStock <= 0) return 'Out of Stock'
  if (available <= reorderPoint) return 'Low Stock'
  if (inStock > maxStock) return 'Over Stock'
  return 'In Stock'
}

function getStockStatusColor(item) {
  const status = getStockStatus(item)
  const colors = {
    'In Stock': 'positive',
    'Low Stock': 'warning',
    'Out of Stock': 'negative',
    'Over Stock': 'info',
  }
  return colors[status] || 'grey'
}

function getAvailableClass(item) {
  const { available } = getItemTotals(item)
  const reorderPoint = item.reorder_point || 0
  if (available <= 0) return 'text-negative'
  if (available <= reorderPoint) return 'text-warning'
  return 'text-positive'
}

async function loadData() {
  await stockStore.initializeStore()
}

function applyFilters() {
  // Filters applied via computed property
}

async function viewItemDetail(item) {
  selectedItem.value = item
  detailTab.value = 'stock'
  showDetailDialog.value = true

  // Load transactions
  loadingTransactions.value = true
  await stockStore.fetchStockTransactions({ item_id: item.id })
  itemTransactions.value = stockStore.stockTransactions
  loadingTransactions.value = false
}

function exportReport() {
  $q.notify({ type: 'info', message: 'Export to Excel - Coming soon', position: 'top' })
}

onMounted(loadData)
</script>

<style lang="scss" scoped>
.stat-card {
  padding: 12px;
  text-align: center;

  &.compact {
    .stat-value {
      font-size: 18px;
      font-weight: 700;
    }
    .stat-label {
      font-size: 10px;
      color: #666;
      text-transform: uppercase;
    }
  }
}

.detail-label {
  font-size: 11px;
  color: #666;
  text-transform: uppercase;
}

.detail-value {
  font-size: 14px;
  color: #333;
}

.slide-enter-active,
.slide-leave-active {
  transition: all 0.3s ease;
}

.slide-enter-from,
.slide-leave-to {
  opacity: 0;
  transform: translateY(-10px);
}
</style>
