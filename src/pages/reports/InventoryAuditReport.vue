<template>
  <q-page class="sap-page">
    <SAPToolbar
      title="Inventory Audit Report (OINM)"
      icon="history"
      :show-add="false"
      :show-export-excel="true"
      :show-export-pdf="true"
      :show-filter="true"
      @refresh="loadData"
      @export-excel="exportExcel"
      @export-pdf="exportPDF"
      @filter="showFilters = !showFilters"
    />

    <div class="sap-page-content">
      <!-- Filters Panel -->
      <transition name="slide">
        <SAPCard v-if="showFilters" class="q-mb-md" flat bordered>
          <div class="row q-col-gutter-md items-end">
            <div class="col-12 col-md-3">
              <label class="sap-label">Item</label>
              <SAPSelect
                v-model="filters.item_id"
                :options="[{ id: null, item_name: 'All Items' }, ...stockStore.items]"
                option-label="item_name"
                option-value="id"
                dense
                searchable
              />
            </div>
            <div class="col-12 col-md-2">
              <label class="sap-label">Warehouse</label>
              <SAPSelect
                v-model="filters.warehouse_id"
                :options="[{ id: null, name: 'All Warehouses' }, ...stockStore.warehouses]"
                option-label="name"
                option-value="id"
                dense
              />
            </div>
            <div class="col-12 col-md-2">
              <label class="sap-label">Document Type</label>
              <SAPSelect
                v-model="filters.doc_type"
                :options="docTypes"
                option-label="label"
                option-value="value"
                dense
              />
            </div>
            <div class="col-12 col-md-2">
              <SAPInput v-model="filters.from_date" label="From Date" type="date" dense />
            </div>
            <div class="col-12 col-md-2">
              <SAPInput v-model="filters.to_date" label="To Date" type="date" dense />
            </div>
            <div class="col-12 col-md-1">
              <q-btn color="primary" label="Apply" dense @click="loadData" class="full-width" />
            </div>
          </div>
        </SAPCard>
      </transition>

      <!-- Summary Cards -->
      <div class="row q-col-gutter-md q-mb-md">
        <div class="col-6 col-md-3">
          <SAPCard flat bordered>
            <div class="stat-card">
              <q-icon name="swap_horiz" size="28px" color="primary" />
              <div class="stat-info">
                <div class="stat-value">{{ inventoryStore.stockAuditTrail.length }}</div>
                <div class="stat-label">Transactions</div>
              </div>
            </div>
          </SAPCard>
        </div>
        <div class="col-6 col-md-3">
          <SAPCard flat bordered>
            <div class="stat-card">
              <q-icon name="arrow_upward" size="28px" color="positive" />
              <div class="stat-info">
                <div class="stat-value">{{ formatNumber(totalIn) }}</div>
                <div class="stat-label">Total In</div>
              </div>
            </div>
          </SAPCard>
        </div>
        <div class="col-6 col-md-3">
          <SAPCard flat bordered>
            <div class="stat-card">
              <q-icon name="arrow_downward" size="28px" color="negative" />
              <div class="stat-info">
                <div class="stat-value">{{ formatNumber(totalOut) }}</div>
                <div class="stat-label">Total Out</div>
              </div>
            </div>
          </SAPCard>
        </div>
        <div class="col-6 col-md-3">
          <SAPCard flat bordered>
            <div class="stat-card">
              <q-icon name="attach_money" size="28px" color="accent" />
              <div class="stat-info">
                <div class="stat-value">{{ formatCurrency(totalValue) }}</div>
                <div class="stat-label">Total Value</div>
              </div>
            </div>
          </SAPCard>
        </div>
      </div>

      <!-- Audit Trail Table -->
      <SAPCard title="Stock Audit Trail" icon="list" no-padding>
        <SAPTable
          :rows="inventoryStore.stockAuditTrail"
          :columns="columns"
          :loading="inventoryStore.loading"
          :show-drill-down="true"
          row-key="id"
          @drill-down="viewTransaction"
        >
          <template #body-cell-transaction_date="props">
            <q-td :props="props">
              {{ formatDateTime(props.value) }}
            </q-td>
          </template>

          <template #body-cell-item="props">
            <q-td :props="props">
              <div class="row items-center no-wrap">
                <span class="text-bold">{{ props.row.item?.item_code }}</span>
                <GoldenArrow @click="viewItem(props.row.item)" />
              </div>
              <div class="text-caption text-grey-7">{{ props.row.item?.item_name }}</div>
            </q-td>
          </template>

          <template #body-cell-doc_number="props">
            <q-td :props="props">
              <div class="row items-center no-wrap">
                <q-badge
                  :color="getDocTypeColor(props.row.doc_type)"
                  :label="props.row.doc_type"
                  class="q-mr-xs"
                />
                <span class="text-primary cursor-pointer" @click="viewDocument(props.row)">{{
                  props.value
                }}</span>
                <GoldenArrow @click="viewDocument(props.row)" />
              </div>
            </q-td>
          </template>

          <template #body-cell-quantity="props">
            <q-td :props="props" class="text-right">
              <span :class="props.value >= 0 ? 'text-positive' : 'text-negative'" class="text-bold">
                {{ props.value >= 0 ? '+' : '' }}{{ formatNumber(props.value) }}
              </span>
            </q-td>
          </template>

          <template #body-cell-balance_after="props">
            <q-td :props="props" class="text-right text-bold">
              {{ formatNumber(props.value) }}
            </q-td>
          </template>

          <template #body-cell-total_cost="props">
            <q-td :props="props" class="text-right">
              {{ formatCurrency(props.value) }}
            </q-td>
          </template>

          <template #body-cell-trans_direction="props">
            <q-td :props="props" class="text-center">
              <q-icon
                :name="props.value === 'IN' ? 'arrow_downward' : 'arrow_upward'"
                :color="props.value === 'IN' ? 'positive' : 'negative'"
                size="18px"
              />
            </q-td>
          </template>
        </SAPTable>
      </SAPCard>
    </div>

    <!-- Transaction Detail Dialog -->
    <SAPDialog
      v-model="showDetailDialog"
      :title="`Transaction: ${selectedTransaction?.doc_number || ''}`"
      icon="receipt"
      width="700px"
      :show-default-footer="false"
    >
      <template v-if="selectedTransaction">
        <div class="row q-col-gutter-md">
          <div class="col-6">
            <div class="detail-group">
              <div class="detail-label">Document</div>
              <div class="detail-value">
                <q-badge
                  :color="getDocTypeColor(selectedTransaction.doc_type)"
                  :label="selectedTransaction.doc_type"
                  class="q-mr-xs"
                />
                {{ selectedTransaction.doc_number }}
              </div>
            </div>
          </div>
          <div class="col-6">
            <div class="detail-group">
              <div class="detail-label">Date & Time</div>
              <div class="detail-value">
                {{ formatDateTime(selectedTransaction.transaction_date) }}
              </div>
            </div>
          </div>
          <div class="col-6">
            <div class="detail-group">
              <div class="detail-label">Item</div>
              <div class="detail-value">
                {{ selectedTransaction.item?.item_code }} -
                {{ selectedTransaction.item?.item_name }}
              </div>
            </div>
          </div>
          <div class="col-6">
            <div class="detail-group">
              <div class="detail-label">Warehouse</div>
              <div class="detail-value">{{ selectedTransaction.warehouse?.name }}</div>
            </div>
          </div>
          <div class="col-6">
            <div class="detail-group">
              <div class="detail-label">Transaction Type</div>
              <div class="detail-value text-capitalize">
                {{ selectedTransaction.transaction_type?.replace(/_/g, ' ') }}
              </div>
            </div>
          </div>
          <div class="col-6">
            <div class="detail-group">
              <div class="detail-label">Direction</div>
              <div class="detail-value">
                <q-icon
                  :name="
                    selectedTransaction.trans_direction === 'IN' ? 'arrow_downward' : 'arrow_upward'
                  "
                  :color="selectedTransaction.trans_direction === 'IN' ? 'positive' : 'negative'"
                  size="18px"
                  class="q-mr-xs"
                />
                {{ selectedTransaction.trans_direction }}
              </div>
            </div>
          </div>

          <div class="col-12">
            <q-separator class="q-my-sm" />
          </div>

          <div class="col-4">
            <div class="detail-group">
              <div class="detail-label">Quantity</div>
              <div
                class="detail-value text-h6"
                :class="selectedTransaction.quantity >= 0 ? 'text-positive' : 'text-negative'"
              >
                {{ selectedTransaction.quantity >= 0 ? '+' : ''
                }}{{ formatNumber(selectedTransaction.quantity) }}
              </div>
            </div>
          </div>
          <div class="col-4">
            <div class="detail-group">
              <div class="detail-label">Unit Cost</div>
              <div class="detail-value text-h6">
                {{ formatCurrency(selectedTransaction.unit_cost) }}
              </div>
            </div>
          </div>
          <div class="col-4">
            <div class="detail-group">
              <div class="detail-label">Total Value</div>
              <div class="detail-value text-h6">
                {{ formatCurrency(selectedTransaction.total_cost) }}
              </div>
            </div>
          </div>

          <div class="col-6">
            <div class="detail-group">
              <div class="detail-label">Balance Before</div>
              <div class="detail-value">{{ formatNumber(selectedTransaction.balance_before) }}</div>
            </div>
          </div>
          <div class="col-6">
            <div class="detail-group">
              <div class="detail-label">Balance After</div>
              <div class="detail-value text-bold">
                {{ formatNumber(selectedTransaction.balance_after) }}
              </div>
            </div>
          </div>

          <div class="col-12" v-if="selectedTransaction.remarks">
            <div class="detail-group">
              <div class="detail-label">Remarks</div>
              <div class="detail-value">{{ selectedTransaction.remarks }}</div>
            </div>
          </div>

          <div class="col-12" v-if="selectedTransaction.base_doc_type">
            <div class="detail-group">
              <div class="detail-label">Base Document</div>
              <div class="detail-value">
                <q-badge
                  :color="getDocTypeColor(selectedTransaction.base_doc_type)"
                  :label="selectedTransaction.base_doc_type"
                  class="q-mr-xs"
                />
                <span class="text-primary cursor-pointer">View Original</span>
              </div>
            </div>
          </div>

          <div class="col-12" v-if="selectedTransaction.journal_entry_id">
            <div class="detail-group">
              <div class="detail-label">Journal Entry</div>
              <div class="detail-value text-primary cursor-pointer" @click="viewJournalEntry">
                View Accounting Entry
                <q-icon name="launch" size="14px" class="q-ml-xs" />
              </div>
            </div>
          </div>
        </div>
      </template>
    </SAPDialog>
  </q-page>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useQuasar } from 'quasar'
import { useStockStore } from 'src/stores/stockStore'
import { useInventoryStore } from 'src/stores/inventoryStore'
import {
  SAPTable,
  SAPCard,
  SAPToolbar,
  SAPDialog,
  SAPInput,
  SAPSelect,
  GoldenArrow,
} from 'src/components/sap'
import { useExport } from 'src/composables/useExport'

const $q = useQuasar()
const stockStore = useStockStore()
const inventoryStore = useInventoryStore()
const { exportToExcel, exportToPDF } = useExport()

// State
const showFilters = ref(true)
const showDetailDialog = ref(false)
const selectedTransaction = ref(null)

const filters = ref({
  item_id: null,
  warehouse_id: null,
  doc_type: null,
  from_date: null,
  to_date: null,
})

const docTypes = [
  { value: null, label: 'All Types' },
  { value: 'GRN', label: 'Goods Receipt Note' },
  { value: 'GIN', label: 'Goods Issue Note' },
  { value: 'DEL', label: 'Delivery' },
  { value: 'PO', label: 'Purchase Order' },
  { value: 'CC', label: 'Cycle Count' },
  { value: 'OP', label: 'Opening Balance' },
]

const columns = [
  {
    name: 'transaction_date',
    label: 'Date/Time',
    field: 'transaction_date',
    format: (val) => formatDateTime(val),
    sortable: true,
    align: 'left',
    style: 'width: 140px',
  },
  { name: 'item', label: 'Item', field: 'item', align: 'left', style: 'width: 250px' },
  {
    name: 'warehouse',
    label: 'Warehouse',
    field: (row) => row.warehouse?.name,
    sortable: true,
    align: 'left',
  },
  { name: 'doc_number', label: 'Document', field: 'doc_number', align: 'left' },
  {
    name: 'transaction_type',
    label: 'Type',
    field: (row) => row.transaction_type?.replace(/_/g, ' '),
    align: 'left',
    classes: 'text-capitalize',
  },
  {
    name: 'trans_direction',
    label: 'Dir',
    field: 'trans_direction',
    align: 'center',
    style: 'width: 50px',
  },
  { name: 'quantity', label: 'Qty', field: 'quantity', sortable: true, align: 'right' },
  {
    name: 'unit_cost',
    label: 'Unit Cost',
    field: (row) => formatCurrency(row.unit_cost),
    align: 'right',
  },
  { name: 'total_cost', label: 'Value', field: 'total_cost', align: 'right' },
  { name: 'balance_after', label: 'Balance', field: 'balance_after', align: 'right' },
]

// Computed
const totalIn = computed(() => {
  return inventoryStore.stockAuditTrail
    .filter((t) => t.quantity > 0)
    .reduce((sum, t) => sum + t.quantity, 0)
})

const totalOut = computed(() => {
  return Math.abs(
    inventoryStore.stockAuditTrail
      .filter((t) => t.quantity < 0)
      .reduce((sum, t) => sum + t.quantity, 0),
  )
})

const totalValue = computed(() => {
  return inventoryStore.stockAuditTrail.reduce((sum, t) => sum + Math.abs(t.total_cost || 0), 0)
})

// Methods
function formatDateTime(date) {
  if (!date) return '—'
  return new Date(date).toLocaleString('en-US', {
    year: 'numeric',
    month: 'short',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  })
}

function formatNumber(value) {
  if (value == null) return '—'
  return new Intl.NumberFormat('en-US', { maximumFractionDigits: 3 }).format(value)
}

function formatCurrency(value) {
  if (value == null) return '—'
  return new Intl.NumberFormat('en-US', { style: 'currency', currency: 'LKR' }).format(value)
}

function getDocTypeColor(type) {
  const colors = {
    GRN: 'positive',
    GIN: 'negative',
    DEL: 'info',
    PO: 'primary',
    CC: 'warning',
    OP: 'accent',
  }
  return colors[type] || 'grey'
}

async function loadData() {
  await stockStore.initializeStore()
  await inventoryStore.fetchStockAuditTrail(filters.value)
}

function viewTransaction(trans) {
  selectedTransaction.value = trans
  showDetailDialog.value = true
}

function viewItem(item) {
  $q.notify({ type: 'info', message: `View item: ${item?.item_code}`, position: 'top' })
}

function viewDocument(trans) {
  $q.notify({
    type: 'info',
    message: `View document: ${trans.doc_type} - ${trans.doc_number}`,
    position: 'top',
  })
}

function viewJournalEntry() {
  $q.notify({ type: 'info', message: 'Navigate to Journal Entry', position: 'top' })
}

function exportExcel() {
  const filename = `Inventory_Audit_Report_${new Date().toISOString().split('T')[0]}`
  exportToExcel(inventoryStore.stockAuditTrail, columns, 'Inventory Audit Report (OINM)', filename)
  $q.notify({ type: 'positive', message: 'Excel download started', position: 'top' })
}

function exportPDF() {
  const filename = `Inventory_Audit_Report_${new Date().toISOString().split('T')[0]}`
  exportToPDF(inventoryStore.stockAuditTrail, columns, 'Inventory Audit Report (OINM)', filename)
  $q.notify({ type: 'positive', message: 'PDF download started', position: 'top' })
}

onMounted(loadData)
</script>

<style lang="scss" scoped>
.stat-card {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 12px;
}

.stat-info {
  .stat-value {
    font-size: 20px;
    font-weight: 700;
    color: #333;
  }
  .stat-label {
    font-size: 11px;
    color: #666;
    text-transform: uppercase;
  }
}

.detail-group {
  margin-bottom: 8px;
}

.detail-label {
  font-size: 11px;
  color: #666;
  text-transform: uppercase;
  margin-bottom: 2px;
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
