<template>
  <q-page class="sap-page">
    <!-- Toolbar -->
    <SAPToolbar
      title="Stock Transfers"
      icon="swap_horiz"
      :badge="stockStore.stockTransfers.length"
      add-label="New Transfer"
      @add="openCreateDialog"
      @refresh="loadData"
    />

    <!-- Main Content -->
    <div class="sap-page-content">
      <!-- Stats Cards -->
      <div class="row q-col-gutter-md q-mb-md">
        <div class="col-12 col-md-4">
          <SAPCard flat bordered>
            <div class="stat-card">
              <q-icon name="swap_horiz" size="32px" color="primary" />
              <div class="stat-info">
                <div class="stat-value">{{ stockStore.stockTransfers.length }}</div>
                <div class="stat-label">Total Transfers</div>
              </div>
            </div>
          </SAPCard>
        </div>
        <div class="col-12 col-md-4">
          <SAPCard flat bordered>
            <div class="stat-card">
              <q-icon name="pending_actions" size="32px" color="warning" />
              <div class="stat-info">
                <div class="stat-value">{{ stockStore.pendingTransfers.length }}</div>
                <div class="stat-label">Pending Transfers</div>
              </div>
            </div>
          </SAPCard>
        </div>
        <div class="col-12 col-md-4">
          <SAPCard flat bordered>
            <div class="stat-card">
              <q-icon name="check_circle" size="32px" color="positive" />
              <div class="stat-info">
                <div class="stat-value">{{ completedTransfersCount }}</div>
                <div class="stat-label">Completed</div>
              </div>
            </div>
          </SAPCard>
        </div>
      </div>

      <!-- Transfers Table -->
      <SAPCard title="Transfer List" icon="list" no-padding>
        <SAPTable
          :rows="stockStore.stockTransfers"
          :columns="columns"
          :loading="stockStore.loading"
          row-key="id"
          @row-click="viewTransfer"
        >
          <!-- Doc Number Column -->
          <template #body-cell-doc_number="props">
            <q-td :props="props">
              <div class="row items-center no-wrap">
                <span class="text-bold">{{ props.value }}</span>
                <GoldenArrow @click="viewTransfer(props.row)" />
              </div>
            </q-td>
          </template>

          <!-- From Warehouse Column -->
          <template #body-cell-from_warehouse="props">
            <q-td :props="props">
              <q-badge :color="getWarehouseColor(props.row.from_warehouse?.code)">
                {{ props.row.from_warehouse?.name }}
              </q-badge>
            </q-td>
          </template>

          <!-- To Warehouse Column -->
          <template #body-cell-to_warehouse="props">
            <q-td :props="props">
              <q-badge :color="getWarehouseColor(props.row.to_warehouse?.code)">
                {{ props.row.to_warehouse?.name }}
              </q-badge>
            </q-td>
          </template>

          <!-- Total Items Column -->
          <template #body-cell-total_items="props">
            <q-td :props="props" class="text-center">
              {{ props.row.stock_transfer_lines?.length || 0 }}
            </q-td>
          </template>

          <!-- Total Cost Column -->
          <template #body-cell-total_cost="props">
            <q-td :props="props" class="text-right text-bold">
              {{ formatCurrency(props.value) }}
            </q-td>
          </template>

          <!-- Status Column -->
          <template #body-cell-status="props">
            <q-td :props="props" class="text-center">
              <q-badge :color="getStatusColor(props.value)" :label="getStatusLabel(props.value)" />
            </q-td>
          </template>

          <!-- Actions Column -->
          <template #body-cell-actions="props">
            <q-td :props="props" class="actions-cell">
              <q-btn
                v-if="props.row.status === 'draft'"
                flat
                dense
                round
                size="sm"
                icon="check_circle"
                color="positive"
                @click.stop="confirmComplete(props.row)"
              >
                <q-tooltip>Complete Transfer</q-tooltip>
              </q-btn>
              <q-btn
                v-if="props.row.status === 'draft'"
                flat
                dense
                round
                size="sm"
                icon="cancel"
                color="negative"
                @click.stop="confirmCancel(props.row)"
              >
                <q-tooltip>Cancel Transfer</q-tooltip>
              </q-btn>
              <q-btn
                flat
                dense
                round
                size="sm"
                icon="visibility"
                color="info"
                @click.stop="viewTransfer(props.row)"
              >
                <q-tooltip>View Details</q-tooltip>
              </q-btn>
            </q-td>
          </template>
        </SAPTable>
      </SAPCard>
    </div>

    <!-- Create Transfer Dialog -->
    <SAPDialog
      v-model="showDialog"
      title="New Stock Transfer"
      icon="swap_horiz"
      width="900px"
      :loading="saving"
      @confirm="submitForm"
    >
      <q-form ref="formRef" @submit.prevent>
        <div class="row q-col-gutter-md">
          <!-- Header Section -->
          <div class="col-12">
            <div class="section-title">Transfer Information</div>
          </div>

          <div class="col-12 col-md-4">
            <SAPInput
              v-model="form.transfer_date"
              label="Transfer Date"
              type="date"
              required
              :rules="requiredRules"
            />
          </div>

          <div class="col-12 col-md-4">
            <label class="sap-label required">From Warehouse</label>
            <SAPSelect
              v-model="form.from_warehouse_id"
              :options="stockStore.activeWarehouses"
              option-label="name"
              option-value="id"
              placeholder="Select source warehouse"
              :rules="requiredRules"
              @update:model-value="onWarehouseChange"
            />
          </div>

          <div class="col-12 col-md-4">
            <label class="sap-label required">To Warehouse</label>
            <SAPSelect
              v-model="form.to_warehouse_id"
              :options="toWarehouseOptions"
              option-label="name"
              option-value="id"
              placeholder="Select destination"
              :rules="requiredRules"
            />
          </div>

          <div class="col-12">
            <SAPInput v-model="form.notes" label="Notes" type="textarea" rows="2" />
          </div>

          <!-- Items Section -->
          <div class="col-12">
            <div class="section-title q-mt-md q-mb-sm">Transfer Items</div>
          </div>

          <div class="col-12">
            <div class="items-section">
              <!-- Items Table -->
              <q-table
                :rows="form.lines"
                :columns="lineColumns"
                row-key="temp_id"
                dense
                flat
                bordered
                hide-pagination
                :rows-per-page-options="[0]"
              >
                <template #top-right>
                  <q-btn
                    dense
                    color="primary"
                    icon="add"
                    label="Add Item"
                    @click="addLine"
                    :disable="!form.from_warehouse_id"
                  />
                </template>

                <template #body-cell-item="props">
                  <q-td :props="props">
                    <SAPSelect
                      v-model="props.row.item_id"
                      :options="availableItems"
                      option-label="item_name"
                      option-value="id"
                      placeholder="Select item"
                      dense
                      searchable
                      @update:model-value="onItemChange(props.row)"
                    >
                      <template #option="{ opt }">
                        <div>
                          <div class="text-body2">{{ opt.item_name }}</div>
                          <div class="text-caption text-grey">
                            Available: {{ getAvailableStock(opt.id) }} {{ opt.base_uom?.code }}
                          </div>
                        </div>
                      </template>
                    </SAPSelect>
                  </q-td>
                </template>

                <template #body-cell-quantity="props">
                  <q-td :props="props">
                    <SAPInput
                      v-model.number="props.row.quantity"
                      type="number"
                      step="0.01"
                      min="0"
                      :max="getAvailableStock(props.row.item_id)"
                      dense
                      @update:model-value="calculateLineCost(props.row)"
                    >
                      <template #append>
                        <span class="text-caption text-grey"
                          >/ {{ getAvailableStock(props.row.item_id) }}</span
                        >
                      </template>
                    </SAPInput>
                  </q-td>
                </template>

                <template #body-cell-uom="props">
                  <q-td :props="props" class="text-center">
                    {{ getItemUom(props.row.item_id) }}
                  </q-td>
                </template>

                <template #body-cell-unit_cost="props">
                  <q-td :props="props" class="text-right">
                    {{ formatCurrency(props.row.unit_cost || 0) }}
                  </q-td>
                </template>

                <template #body-cell-line_total="props">
                  <q-td :props="props" class="text-right text-bold">
                    {{ formatCurrency((props.row.quantity || 0) * (props.row.unit_cost || 0)) }}
                  </q-td>
                </template>

                <template #body-cell-actions="props">
                  <q-td :props="props" class="text-center">
                    <q-btn
                      flat
                      dense
                      round
                      size="sm"
                      icon="delete"
                      color="negative"
                      @click="removeLine(props.rowIndex)"
                    />
                  </q-td>
                </template>
              </q-table>

              <!-- Total Cost Display -->
              <div class="total-cost-display q-mt-md">
                <div class="text-h6">
                  Total Transfer Cost: {{ formatCurrency(totalTransferCost) }}
                </div>
              </div>
            </div>
          </div>
        </div>
      </q-form>
    </SAPDialog>

    <!-- View Transfer Dialog -->
    <SAPDialog
      v-model="showViewDialog"
      :title="`Transfer ${selectedTransfer?.doc_number || ''}`"
      icon="swap_horiz"
      width="800px"
      :show-default-footer="false"
    >
      <template v-if="selectedTransfer">
        <div class="transfer-details">
          <div class="row q-col-gutter-md">
            <div class="col-6">
              <div class="detail-row">
                <span class="detail-label">Doc Number:</span>
                <span class="detail-value">{{ selectedTransfer.doc_number }}</span>
              </div>
              <div class="detail-row">
                <span class="detail-label">Transfer Date:</span>
                <span class="detail-value">{{ formatDate(selectedTransfer.transfer_date) }}</span>
              </div>
              <div class="detail-row">
                <span class="detail-label">From Warehouse:</span>
                <span class="detail-value">{{ selectedTransfer.from_warehouse?.name }}</span>
              </div>
            </div>
            <div class="col-6">
              <div class="detail-row">
                <span class="detail-label">To Warehouse:</span>
                <span class="detail-value">{{ selectedTransfer.to_warehouse?.name }}</span>
              </div>
              <div class="detail-row">
                <span class="detail-label">Status:</span>
                <q-badge :color="getStatusColor(selectedTransfer.status)">
                  {{ getStatusLabel(selectedTransfer.status) }}
                </q-badge>
              </div>
              <div class="detail-row">
                <span class="detail-label">Total Cost:</span>
                <span class="detail-value text-bold">{{
                  formatCurrency(selectedTransfer.total_cost)
                }}</span>
              </div>
            </div>
          </div>

          <q-separator class="q-my-md" />

          <div class="text-subtitle2 q-mb-sm">Transfer Items</div>
          <q-table
            :rows="selectedTransfer.stock_transfer_lines || []"
            :columns="viewLineColumns"
            row-key="id"
            dense
            flat
            bordered
            hide-pagination
            :rows-per-page-options="[0]"
          >
            <template #body-cell-quantity="props">
              <q-td :props="props" class="text-right text-bold">
                {{ formatNumber(props.value) }}
              </q-td>
            </template>
            <template #body-cell-unit_cost="props">
              <q-td :props="props" class="text-right">
                {{ formatCurrency(props.value) }}
              </q-td>
            </template>
            <template #body-cell-line_total="props">
              <q-td :props="props" class="text-right text-bold">
                {{ formatCurrency(props.value) }}
              </q-td>
            </template>
          </q-table>
        </div>
      </template>
    </SAPDialog>

    <!-- Complete Confirmation -->
    <q-dialog v-model="showCompleteConfirm">
      <q-card style="min-width: 350px">
        <q-card-section class="row items-center">
          <q-icon name="check_circle" color="positive" size="32px" class="q-mr-md" />
          <span class="text-body1">Complete this stock transfer?</span>
        </q-card-section>
        <q-card-section class="q-pt-none">
          This will move stock from
          <strong>{{ transferToComplete?.from_warehouse?.name }}</strong> to
          <strong>{{ transferToComplete?.to_warehouse?.name }}</strong
          >.
        </q-card-section>
        <q-card-actions align="right">
          <q-btn flat label="Cancel" v-close-popup />
          <q-btn
            flat
            color="positive"
            label="Complete"
            @click="completeTransfer"
            :loading="completing"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <!-- Cancel Confirmation -->
    <q-dialog v-model="showCancelConfirm">
      <q-card style="min-width: 350px">
        <q-card-section class="row items-center">
          <q-icon name="warning" color="negative" size="32px" class="q-mr-md" />
          <span class="text-body1">Cancel this transfer?</span>
        </q-card-section>
        <q-card-section class="q-pt-none">
          <strong>{{ transferToCancel?.doc_number }}</strong> - This action cannot be undone
        </q-card-section>
        <q-card-actions align="right">
          <q-btn flat label="No" v-close-popup />
          <q-btn
            flat
            color="negative"
            label="Yes, Cancel"
            @click="cancelTransfer"
            :loading="cancelling"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useQuasar } from 'quasar'
import { useStockStore } from 'src/stores/stockStore'
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
const authStore = useAuthStore()

// State
const showDialog = ref(false)
const showViewDialog = ref(false)
const showCompleteConfirm = ref(false)
const showCancelConfirm = ref(false)
const saving = ref(false)
const completing = ref(false)
const cancelling = ref(false)
const formRef = ref(null)
const form = ref(getEmptyForm())
const selectedTransfer = ref(null)
const transferToComplete = ref(null)
const transferToCancel = ref(null)

// Validation rules
const requiredRules = [(val) => !!val || 'Required']

// Columns
const columns = [
  { name: 'doc_number', label: 'Doc Number', field: 'doc_number', sortable: true, align: 'left' },
  {
    name: 'transfer_date',
    label: 'Date',
    field: (row) => formatDate(row.transfer_date),
    sortable: true,
    align: 'left',
  },
  { name: 'from_warehouse', label: 'From', field: 'from_warehouse', sortable: true, align: 'left' },
  { name: 'to_warehouse', label: 'To', field: 'to_warehouse', sortable: true, align: 'left' },
  { name: 'total_items', label: 'Items', field: 'total_items', sortable: true, align: 'center' },
  { name: 'total_cost', label: 'Total Cost', field: 'total_cost', sortable: true, align: 'right' },
  { name: 'status', label: 'Status', field: 'status', sortable: true, align: 'center' },
  { name: 'actions', label: 'Actions', field: 'actions', align: 'center' },
]

const lineColumns = [
  { name: 'item', label: 'Item', field: 'item_id', style: 'width: 300px', align: 'left' },
  { name: 'quantity', label: 'Quantity', field: 'quantity', style: 'width: 150px', align: 'right' },
  { name: 'uom', label: 'UoM', field: 'uom_id', style: 'width: 80px', align: 'center' },
  {
    name: 'unit_cost',
    label: 'Unit Cost',
    field: 'unit_cost',
    style: 'width: 120px',
    align: 'right',
  },
  {
    name: 'line_total',
    label: 'Line Total',
    field: 'line_total',
    style: 'width: 120px',
    align: 'right',
  },
  { name: 'actions', label: '', field: 'actions', style: 'width: 60px', align: 'center' },
]

const viewLineColumns = [
  { name: 'item', label: 'Item', field: (row) => row.item?.item_name, align: 'left' },
  { name: 'quantity', label: 'Quantity', field: 'quantity', align: 'right' },
  { name: 'uom', label: 'UoM', field: (row) => row.uom?.code, align: 'center' },
  { name: 'unit_cost', label: 'Unit Cost', field: 'unit_cost', align: 'right' },
  { name: 'line_total', label: 'Line Total', field: 'line_total', align: 'right' },
]

// Computed
const completedTransfersCount = computed(() => {
  return stockStore.stockTransfers.filter((t) => t.status === 'completed').length
})

const availableItems = computed(() => {
  return stockStore.items.filter((i) => i.is_active && i.is_inventory_item)
})

const toWarehouseOptions = computed(() => {
  // Exclude the selected from_warehouse
  return stockStore.activeWarehouses.filter((w) => w.id !== form.value.from_warehouse_id)
})

const totalTransferCost = computed(() => {
  return form.value.lines.reduce((sum, line) => {
    return sum + (line.quantity || 0) * (line.unit_cost || 0)
  }, 0)
})

// Methods
function getEmptyForm() {
  const today = new Date().toISOString().split('T')[0]
  return {
    transfer_date: today,
    from_warehouse_id: null,
    to_warehouse_id: null,
    notes: '',
    lines: [],
  }
}

let tempIdCounter = 1
function addLine() {
  form.value.lines.push({
    temp_id: tempIdCounter++,
    item_id: null,
    item_description: '',
    quantity: 0,
    uom_id: null,
    unit_cost: 0,
  })
}

function removeLine(index) {
  form.value.lines.splice(index, 1)
}

function onWarehouseChange() {
  // Clear lines when warehouse changes
  form.value.lines = []
}

function onItemChange(line) {
  const item = stockStore.items.find((i) => i.id === line.item_id)
  if (item) {
    line.item_description = item.item_name
    line.uom_id = item.base_uom_id

    // Get stock and cost from source warehouse
    const stockInWarehouse = item.warehouse_stock?.find(
      (ws) => ws.warehouse_id === form.value.from_warehouse_id,
    )
    line.unit_cost = stockInWarehouse?.average_cost || item.purchase_price || 0
  }
}

function calculateLineCost(line) {
  line.line_total = (line.quantity || 0) * (line.unit_cost || 0)
}

function getAvailableStock(itemId) {
  if (!itemId || !form.value.from_warehouse_id) return 0

  const item = stockStore.items.find((i) => i.id === itemId)
  if (!item) return 0

  const stockInWarehouse = item.warehouse_stock?.find(
    (ws) => ws.warehouse_id === form.value.from_warehouse_id,
  )
  return stockInWarehouse?.quantity_on_hand || 0
}

function getItemUom(itemId) {
  const item = stockStore.items.find((i) => i.id === itemId)
  return item?.base_uom?.code || '—'
}

function getWarehouseColor(code) {
  if (code === 'WH01') return 'primary'
  if (code === 'WH02') return 'deep-orange'
  if (code === 'WH03') return 'purple'
  return 'grey'
}

function getStatusColor(status) {
  if (status === 'completed') return 'positive'
  if (status === 'draft') return 'warning'
  if (status === 'cancelled') return 'negative'
  return 'grey'
}

function getStatusLabel(status) {
  return status ? status.charAt(0).toUpperCase() + status.slice(1) : '—'
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
  return new Intl.NumberFormat('en-US', {
    minimumFractionDigits: 0,
    maximumFractionDigits: 3,
  }).format(value)
}

function formatDate(date) {
  if (!date) return '—'
  return new Date(date).toLocaleDateString()
}

async function loadData() {
  await stockStore.fetchStockTransfers()
}

function openCreateDialog() {
  form.value = getEmptyForm()
  showDialog.value = true
}

async function submitForm() {
  const success = await formRef.value?.validate()
  if (!success) {
    $q.notify({ type: 'warning', message: 'Please fill in required fields' })
    return
  }

  if (form.value.lines.length === 0) {
    $q.notify({ type: 'warning', message: 'Please add at least one item' })
    return
  }

  // Validate stock availability
  for (const line of form.value.lines) {
    const available = getAvailableStock(line.item_id)
    if (line.quantity > available) {
      const item = stockStore.items.find((i) => i.id === line.item_id)
      $q.notify({
        type: 'negative',
        message: `Insufficient stock for ${item?.item_name}. Available: ${available}`,
      })
      return
    }
  }

  saving.value = true
  try {
    const payload = {
      transfer_date: form.value.transfer_date,
      from_warehouse_id: form.value.from_warehouse_id,
      to_warehouse_id: form.value.to_warehouse_id,
      notes: form.value.notes,
      status: 'draft',
      created_by: authStore.user?.id,
    }

    const lines = form.value.lines.map((line) => ({
      item_id: line.item_id,
      item_description: line.item_description,
      quantity: line.quantity,
      uom_id: line.uom_id,
      unit_cost: line.unit_cost,
    }))

    const result = await stockStore.createStockTransfer(payload, lines)

    if (result.success) {
      $q.notify({ type: 'positive', message: 'Stock transfer created successfully' })
      showDialog.value = false
    } else {
      $q.notify({ type: 'negative', message: result.error })
    }
  } finally {
    saving.value = false
  }
}

function viewTransfer(transfer) {
  selectedTransfer.value = transfer
  showViewDialog.value = true
}

function confirmComplete(transfer) {
  transferToComplete.value = transfer
  showCompleteConfirm.value = true
}

async function completeTransfer() {
  completing.value = true
  try {
    const result = await stockStore.completeStockTransfer(
      transferToComplete.value.id,
      authStore.user?.id,
    )
    if (result.success) {
      $q.notify({ type: 'positive', message: 'Stock transfer completed successfully' })
      showCompleteConfirm.value = false
    } else {
      $q.notify({ type: 'negative', message: result.error })
    }
  } finally {
    completing.value = false
  }
}

function confirmCancel(transfer) {
  transferToCancel.value = transfer
  showCancelConfirm.value = true
}

async function cancelTransfer() {
  cancelling.value = true
  try {
    const result = await stockStore.cancelStockTransfer(transferToCancel.value.id)
    if (result.success) {
      $q.notify({ type: 'positive', message: 'Stock transfer cancelled' })
      showCancelConfirm.value = false
    } else {
      $q.notify({ type: 'negative', message: result.error })
    }
  } finally {
    cancelling.value = false
  }
}

onMounted(async () => {
  await loadData()
})
</script>

<style lang="scss" scoped>
.sap-page {
  background: #f5f7fa;
  min-height: 100vh;
}

.sap-page-content {
  padding: 16px;
}

.stat-card {
  display: flex;
  align-items: center;
  padding: 16px;
  gap: 16px;
}

.stat-info {
  display: flex;
  flex-direction: column;
}

.stat-value {
  font-size: 24px;
  font-weight: 600;
  color: $primary;
  line-height: 1;
}

.stat-label {
  font-size: 12px;
  color: $grey-7;
  margin-top: 4px;
}

.section-title {
  font-size: 14px;
  font-weight: 600;
  color: $grey-8;
  margin-bottom: 8px;
}

.items-section {
  border: 1px solid $grey-4;
  border-radius: 4px;
  padding: 16px;
  background: white;
}

.total-cost-display {
  text-align: right;
  padding: 12px;
  background: $grey-2;
  border-radius: 4px;
}

.transfer-details {
  .detail-row {
    display: flex;
    justify-content: space-between;
    padding: 8px 0;
    border-bottom: 1px solid $grey-3;
  }

  .detail-label {
    font-size: 12px;
    color: $grey-7;
    font-weight: 500;
  }

  .detail-value {
    font-size: 12px;
    color: $grey-9;
  }
}

.actions-cell {
  width: 120px;
}
</style>
