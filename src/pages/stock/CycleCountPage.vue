<template>
  <q-page class="sap-page">
    <SAPToolbar
      title="Cycle Counting & Inventory Posting"
      icon="fact_check"
      :badge="inventoryStore.cycleCounts.length"
      add-label="New Count"
      :show-export="true"
      @add="openCreateDialog"
      @refresh="loadData"
    />

    <div class="sap-page-content">
      <!-- Stats -->
      <div class="row q-col-gutter-md q-mb-md">
        <div class="col-12 col-md-3">
          <SAPCard flat bordered>
            <div class="stat-card">
              <q-icon name="fact_check" size="32px" color="primary" />
              <div class="stat-info">
                <div class="stat-value">{{ inventoryStore.cycleCounts.length }}</div>
                <div class="stat-label">Total Counts</div>
              </div>
            </div>
          </SAPCard>
        </div>
        <div class="col-12 col-md-3">
          <SAPCard flat bordered>
            <div class="stat-card">
              <q-icon name="pending" size="32px" color="warning" />
              <div class="stat-info">
                <div class="stat-value">{{ inventoryStore.pendingCycleCounts.length }}</div>
                <div class="stat-label">In Progress</div>
              </div>
            </div>
          </SAPCard>
        </div>
        <div class="col-12 col-md-3">
          <SAPCard flat bordered>
            <div class="stat-card">
              <q-icon name="check_circle" size="32px" color="positive" />
              <div class="stat-info">
                <div class="stat-value">{{ completedCounts }}</div>
                <div class="stat-label">Completed</div>
              </div>
            </div>
          </SAPCard>
        </div>
        <div class="col-12 col-md-3">
          <SAPCard flat bordered>
            <div class="stat-card">
              <q-icon name="trending_down" size="32px" color="negative" />
              <div class="stat-info">
                <div class="stat-value">{{ formatCurrency(totalVariance) }}</div>
                <div class="stat-label">Total Variance</div>
              </div>
            </div>
          </SAPCard>
        </div>
      </div>

      <!-- Cycle Counts Table -->
      <SAPCard title="Cycle Count Documents" icon="list" no-padding>
        <SAPTable
          :rows="inventoryStore.cycleCounts"
          :columns="columns"
          :loading="inventoryStore.loading"
          :show-drill-down="true"
          row-key="id"
          @row-click="viewCycleCount"
          @drill-down="viewCycleCount"
        >
          <template #body-cell-doc_number="props">
            <q-td :props="props">
              <div class="row items-center no-wrap">
                <span class="text-bold">{{ props.value }}</span>
                <GoldenArrow @click="viewCycleCount(props.row)" />
              </div>
            </q-td>
          </template>

          <template #body-cell-status="props">
            <q-td :props="props">
              <q-badge :color="getStatusColor(props.value)" :label="formatStatus(props.value)" />
            </q-td>
          </template>

          <template #body-cell-count_type="props">
            <q-td :props="props" class="text-capitalize">
              {{ props.value }}
            </q-td>
          </template>

          <template #body-cell-variance="props">
            <q-td :props="props" class="text-right">
              <span :class="getVarianceClass(props.row)">
                {{ formatCurrency(getTotalVariance(props.row)) }}
              </span>
            </q-td>
          </template>

          <template #body-cell-actions="props">
            <q-td :props="props" class="actions-cell">
              <q-btn
                v-if="props.row.status === 'in_progress'"
                flat
                dense
                round
                size="sm"
                icon="edit"
                color="primary"
                @click.stop="enterCounts(props.row)"
              >
                <q-tooltip>Enter Counts</q-tooltip>
              </q-btn>
              <q-btn
                v-if="props.row.status === 'pending_approval'"
                flat
                dense
                round
                size="sm"
                icon="check"
                color="positive"
                @click.stop="approveCount(props.row)"
              >
                <q-tooltip>Approve & Post</q-tooltip>
              </q-btn>
              <q-btn
                flat
                dense
                round
                size="sm"
                icon="visibility"
                color="info"
                @click.stop="viewCycleCount(props.row)"
              >
                <q-tooltip>View Details</q-tooltip>
              </q-btn>
            </q-td>
          </template>
        </SAPTable>
      </SAPCard>
    </div>

    <!-- Create Cycle Count Dialog -->
    <SAPDialog
      v-model="showCreateDialog"
      title="Create Cycle Count"
      icon="fact_check"
      width="700px"
      :loading="saving"
      confirm-label="Create"
      @confirm="createCycleCount"
    >
      <q-form ref="formRef">
        <div class="row q-col-gutter-md">
          <div class="col-12 col-md-6">
            <label class="sap-label required">Warehouse</label>
            <SAPSelect
              v-model="form.warehouse_id"
              :options="stockStore.activeWarehouses"
              option-label="name"
              option-value="id"
              :rules="requiredRules"
              @update:model-value="loadItemsForCount"
            />
          </div>
          <div class="col-12 col-md-6">
            <SAPInput
              v-model="form.count_date"
              label="Count Date"
              type="date"
              required
              :rules="requiredRules"
            />
          </div>
          <div class="col-12 col-md-6">
            <label class="sap-label">Count Type</label>
            <SAPSelect
              v-model="form.count_type"
              :options="countTypes"
              option-label="label"
              option-value="value"
            />
          </div>
          <div class="col-12 col-md-6">
            <label class="sap-label">Assigned To</label>
            <SAPSelect
              v-model="form.counted_by"
              :options="users"
              option-label="full_name"
              option-value="id"
              placeholder="Select user"
            />
          </div>
          <div class="col-12">
            <SAPInput v-model="form.notes" label="Notes" type="textarea" rows="2" />
          </div>

          <!-- Item Selection -->
          <div class="col-12">
            <div class="section-title">Items to Count</div>
            <q-table
              :rows="availableItems"
              :columns="itemColumns"
              row-key="id"
              selection="multiple"
              v-model:selected="selectedItems"
              dense
              flat
              bordered
              class="sap-table"
              :pagination="{ rowsPerPage: 10 }"
            >
              <template #body-cell-current_stock="props">
                <q-td :props="props" class="text-right">
                  {{ formatNumber(getItemStock(props.row)) }}
                </q-td>
              </template>
            </q-table>
          </div>
        </div>
      </q-form>
    </SAPDialog>

    <!-- View/Enter Counts Dialog -->
    <SAPDialog
      v-model="showViewDialog"
      :title="selectedCount?.doc_number || 'Cycle Count'"
      icon="fact_check"
      width="900px"
      :show-default-footer="selectedCount?.status === 'in_progress'"
      :confirm-label="'Submit for Approval'"
      @confirm="submitForApproval"
    >
      <template v-if="selectedCount">
        <div class="row q-col-gutter-md q-mb-md">
          <div class="col-4">
            <div class="detail-label">Warehouse</div>
            <div class="detail-value">{{ selectedCount.warehouse?.name }}</div>
          </div>
          <div class="col-4">
            <div class="detail-label">Count Date</div>
            <div class="detail-value">{{ formatDate(selectedCount.count_date) }}</div>
          </div>
          <div class="col-4">
            <div class="detail-label">Status</div>
            <q-badge
              :color="getStatusColor(selectedCount.status)"
              :label="formatStatus(selectedCount.status)"
            />
          </div>
        </div>

        <q-separator class="q-mb-md" />

        <SAPTable
          :rows="selectedCount.cycle_count_lines || []"
          :columns="lineColumns"
          :show-search="false"
          row-key="id"
        >
          <template #body-cell-counted_quantity="props">
            <q-td :props="props">
              <q-input
                v-if="selectedCount.status === 'in_progress'"
                v-model.number="props.row.counted_quantity"
                type="number"
                dense
                outlined
                style="width: 100px"
                @blur="updateLine(props.row)"
              />
              <span v-else>{{ formatNumber(props.value) }}</span>
            </q-td>
          </template>

          <template #body-cell-variance_quantity="props">
            <q-td :props="props" class="text-right">
              <span
                :class="props.value < 0 ? 'text-negative' : props.value > 0 ? 'text-positive' : ''"
              >
                {{ formatNumber(props.value) }}
              </span>
            </q-td>
          </template>

          <template #body-cell-variance_value="props">
            <q-td :props="props" class="text-right">
              <span
                :class="props.value < 0 ? 'text-negative' : props.value > 0 ? 'text-positive' : ''"
              >
                {{ formatCurrency(props.value) }}
              </span>
            </q-td>
          </template>
        </SAPTable>

        <div class="row q-mt-md" v-if="selectedCount.cycle_count_lines?.length">
          <q-space />
          <div class="text-right">
            <div class="text-caption text-grey">Total Variance</div>
            <div
              class="text-h6"
              :class="getTotalVariance(selectedCount) < 0 ? 'text-negative' : 'text-positive'"
            >
              {{ formatCurrency(getTotalVariance(selectedCount)) }}
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
import { useAuthStore } from 'src/stores/authStore'
import {
  SAPTable,
  SAPCard,
  SAPToolbar,
  SAPDialog,
  SAPInput,
  SAPSelect,
  GoldenArrow,
} from 'src/components/sap'

const $q = useQuasar()
const stockStore = useStockStore()
const inventoryStore = useInventoryStore()
const authStore = useAuthStore()

// State
const showCreateDialog = ref(false)
const showViewDialog = ref(false)
const saving = ref(false)
const formRef = ref(null)
const selectedCount = ref(null)
const selectedItems = ref([])
const availableItems = ref([])
const users = ref([])

const form = ref({
  warehouse_id: null,
  count_date: new Date().toISOString().split('T')[0],
  count_type: 'full',
  counted_by: null,
  notes: '',
})

const countTypes = [
  { value: 'full', label: 'Full Count' },
  { value: 'abc', label: 'ABC Analysis' },
  { value: 'random', label: 'Random Sample' },
  { value: 'zone', label: 'Zone Count' },
]

const columns = [
  {
    name: 'doc_number',
    label: 'Doc No.',
    field: 'doc_number',
    sortable: true,
    align: 'left',
    style: 'width: 120px',
  },
  {
    name: 'warehouse',
    label: 'Warehouse',
    field: (row) => row.warehouse?.name,
    sortable: true,
    align: 'left',
  },
  {
    name: 'count_date',
    label: 'Count Date',
    field: (row) => formatDate(row.count_date),
    sortable: true,
    align: 'left',
  },
  { name: 'count_type', label: 'Type', field: 'count_type', align: 'center' },
  { name: 'status', label: 'Status', field: 'status', sortable: true, align: 'center' },
  {
    name: 'lines',
    label: 'Items',
    field: (row) => row.cycle_count_lines?.length || 0,
    align: 'right',
  },
  { name: 'variance', label: 'Variance', field: 'variance', align: 'right' },
  { name: 'actions', label: 'Actions', field: 'actions', align: 'center' },
]

const itemColumns = [
  { name: 'item_code', label: 'Item Code', field: 'item_code', align: 'left' },
  { name: 'item_name', label: 'Item Name', field: 'item_name', align: 'left' },
  { name: 'category', label: 'Category', field: (row) => row.category?.name, align: 'left' },
  { name: 'current_stock', label: 'System Qty', field: 'current_stock', align: 'right' },
]

const lineColumns = [
  {
    name: 'item',
    label: 'Item',
    field: (row) => `${row.item?.item_code} - ${row.item?.item_name}`,
    align: 'left',
  },
  { name: 'system_quantity', label: 'System Qty', field: 'system_quantity', align: 'right' },
  { name: 'counted_quantity', label: 'Counted Qty', field: 'counted_quantity', align: 'right' },
  { name: 'variance_quantity', label: 'Variance', field: 'variance_quantity', align: 'right' },
  {
    name: 'unit_cost',
    label: 'Unit Cost',
    field: (row) => formatCurrency(row.unit_cost),
    align: 'right',
  },
  { name: 'variance_value', label: 'Variance Value', field: 'variance_value', align: 'right' },
]

const requiredRules = [(val) => !!val || 'Required']

// Computed
const completedCounts = computed(
  () => inventoryStore.cycleCounts.filter((c) => c.status === 'completed').length,
)

const totalVariance = computed(() => {
  return inventoryStore.cycleCounts
    .filter((c) => c.status === 'completed')
    .reduce((sum, c) => sum + getTotalVariance(c), 0)
})

// Methods
function formatDate(date) {
  if (!date) return '—'
  return new Date(date).toLocaleDateString()
}

function formatCurrency(value) {
  if (value == null) return '—'
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'LKR',
    minimumFractionDigits: 2,
  }).format(value)
}

function formatNumber(value) {
  if (value == null) return '—'
  return new Intl.NumberFormat('en-US', { maximumFractionDigits: 3 }).format(value)
}

function formatStatus(status) {
  const map = {
    draft: 'Draft',
    in_progress: 'In Progress',
    pending_approval: 'Pending Approval',
    completed: 'Completed',
    cancelled: 'Cancelled',
  }
  return map[status] || status
}

function getStatusColor(status) {
  const colors = {
    draft: 'grey',
    in_progress: 'warning',
    pending_approval: 'info',
    completed: 'positive',
    cancelled: 'negative',
  }
  return colors[status] || 'grey'
}

function getTotalVariance(count) {
  if (!count?.cycle_count_lines) return 0
  return count.cycle_count_lines.reduce((sum, l) => sum + (l.variance_value || 0), 0)
}

function getVarianceClass(count) {
  const variance = getTotalVariance(count)
  if (variance < 0) return 'text-negative text-bold'
  if (variance > 0) return 'text-positive text-bold'
  return ''
}

function getItemStock(item) {
  if (!item.warehouse_stock) return 0
  const ws = item.warehouse_stock.find((s) => s.warehouse_id === form.value.warehouse_id)
  return ws?.quantity_on_hand || 0
}

async function loadData() {
  await Promise.all([stockStore.initializeStore(), inventoryStore.fetchCycleCounts()])
}

function loadItemsForCount() {
  if (!form.value.warehouse_id) {
    availableItems.value = []
    return
  }
  availableItems.value = stockStore.activeItems.filter((item) => {
    const ws = item.warehouse_stock?.find((s) => s.warehouse_id === form.value.warehouse_id)
    return ws && ws.quantity_on_hand > 0
  })
}

function openCreateDialog() {
  form.value = {
    warehouse_id: null,
    count_date: new Date().toISOString().split('T')[0],
    count_type: 'full',
    counted_by: authStore.user?.id,
    notes: '',
  }
  selectedItems.value = []
  availableItems.value = []
  showCreateDialog.value = true
}

async function createCycleCount() {
  const valid = await formRef.value?.validate()
  if (!valid) return

  if (selectedItems.value.length === 0) {
    $q.notify({ type: 'warning', message: 'Please select items to count', position: 'top' })
    return
  }

  saving.value = true
  try {
    const lines = selectedItems.value.map((item) => ({
      item_id: item.id,
      system_quantity: getItemStock(item),
      unit_cost: item.purchase_price || 0,
    }))

    const result = await inventoryStore.createCycleCount(
      {
        ...form.value,
        status: 'in_progress',
        created_by: authStore.user?.id,
      },
      lines,
    )

    if (result.success) {
      $q.notify({ type: 'positive', message: 'Cycle count created', position: 'top' })
      showCreateDialog.value = false
    } else {
      $q.notify({ type: 'negative', message: result.error, position: 'top' })
    }
  } finally {
    saving.value = false
  }
}

function viewCycleCount(count) {
  selectedCount.value = count
  showViewDialog.value = true
}

function enterCounts(count) {
  selectedCount.value = count
  showViewDialog.value = true
}

async function updateLine(line) {
  if (line.counted_quantity == null) return
  await inventoryStore.updateCycleCountLine(line.id, line.counted_quantity)
  await inventoryStore.fetchCycleCounts()
  selectedCount.value = inventoryStore.cycleCounts.find((c) => c.id === selectedCount.value.id)
}

async function submitForApproval() {
  // Check all items are counted
  const uncounted = selectedCount.value.cycle_count_lines.filter((l) => l.counted_quantity == null)
  if (uncounted.length > 0) {
    $q.notify({
      type: 'warning',
      message: `${uncounted.length} items not yet counted`,
      position: 'top',
    })
    return
  }

  // Update status to pending_approval
  saving.value = true
  try {
    if (!inventoryStore.supabase) throw new Error('Supabase not initialized')

    const { error } = await inventoryStore.supabase
      .from('cycle_counts')
      .update({ status: 'pending_approval', updated_at: new Date().toISOString() })
      .eq('id', selectedCount.value.id)

    if (error) throw error

    await inventoryStore.fetchCycleCounts()
    showViewDialog.value = false
    $q.notify({ type: 'positive', message: 'Submitted for approval', position: 'top' })
  } finally {
    saving.value = false
  }
}

async function approveCount(count) {
  $q.dialog({
    title: 'Approve & Post Variance',
    message: `This will post the inventory variance of ${formatCurrency(getTotalVariance(count))} to the system. Continue?`,
    cancel: true,
    persistent: true,
  }).onOk(async () => {
    const result = await inventoryStore.completeCycleCount(count.id, authStore.user?.id)
    if (result.success) {
      $q.notify({
        type: 'positive',
        message: 'Cycle count completed and variance posted',
        position: 'top',
      })
    } else {
      $q.notify({ type: 'negative', message: result.error, position: 'top' })
    }
  })
}

onMounted(loadData)
</script>

<style lang="scss" scoped>
.stat-card {
  display: flex;
  align-items: center;
  gap: 16px;
  padding: 16px;
}

.stat-info {
  .stat-value {
    font-size: 24px;
    font-weight: 700;
    color: #333;
  }
  .stat-label {
    font-size: 12px;
    color: #666;
    text-transform: uppercase;
  }
}

.detail-label {
  font-size: 11px;
  color: #666;
  text-transform: uppercase;
}
.detail-value {
  font-size: 14px;
  font-weight: 600;
  color: #333;
}

.actions-cell {
  white-space: nowrap;
}
</style>
