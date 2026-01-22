<template>
  <q-page class="sap-page">
    <!-- Toolbar -->
    <SAPToolbar
      title="Purchase Orders"
      icon="shopping_cart"
      :badge="stockStore.purchaseOrders.length"
      add-label="New PO"
      @add="openCreateDialog"
      @refresh="loadData"
    />

    <!-- Main Content -->
    <div class="sap-page-content">
      <!-- Status Cards -->
      <div class="row q-col-gutter-md q-mb-md">
        <div class="col-12 col-md-3">
          <SAPCard flat bordered>
            <div class="stat-card">
              <q-icon name="edit_note" size="28px" color="grey" />
              <div class="stat-info">
                <div class="stat-value">{{ draftCount }}</div>
                <div class="stat-label">Draft</div>
              </div>
            </div>
          </SAPCard>
        </div>
        <div class="col-12 col-md-3">
          <SAPCard flat bordered>
            <div class="stat-card">
              <q-icon name="pending" size="28px" color="warning" />
              <div class="stat-info">
                <div class="stat-value">{{ pendingCount }}</div>
                <div class="stat-label">Pending Approval</div>
              </div>
            </div>
          </SAPCard>
        </div>
        <div class="col-12 col-md-3">
          <SAPCard flat bordered>
            <div class="stat-card">
              <q-icon name="check_circle" size="28px" color="info" />
              <div class="stat-info">
                <div class="stat-value">{{ approvedCount }}</div>
                <div class="stat-label">Approved</div>
              </div>
            </div>
          </SAPCard>
        </div>
        <div class="col-12 col-md-3">
          <SAPCard flat bordered>
            <div class="stat-card">
              <q-icon name="task_alt" size="28px" color="positive" />
              <div class="stat-info">
                <div class="stat-value">{{ completedCount }}</div>
                <div class="stat-label">Completed</div>
              </div>
            </div>
          </SAPCard>
        </div>
      </div>

      <!-- PO Table -->
      <SAPCard title="Purchase Orders" icon="list" no-padding>
        <SAPTable
          :rows="stockStore.purchaseOrders"
          :columns="columns"
          :loading="stockStore.loading"
          :show-drill-down="true"
          row-key="id"
          @row-click="viewPO"
          @drill-down="viewPO"
        >
          <!-- Doc Number -->
          <template #body-cell-doc_number="props">
            <q-td :props="props">
              <span class="doc-number">{{ props.value }}</span>
            </q-td>
          </template>

          <!-- Status -->
          <template #body-cell-status="props">
            <q-td :props="props">
              <q-badge
                :color="getStatusColor(props.value)"
                :label="props.value"
                class="status-badge"
              />
            </q-td>
          </template>

          <!-- Total -->
          <template #body-cell-total_amount="props">
            <q-td :props="props" class="text-right text-bold">
              {{ formatCurrency(props.value) }}
            </q-td>
          </template>

          <!-- Actions -->
          <template #body-cell-actions="props">
            <q-td :props="props" class="actions-cell">
              <q-btn
                v-if="props.row.status === 'draft'"
                flat
                dense
                round
                size="sm"
                icon="send"
                color="primary"
                @click.stop="submitForApproval(props.row)"
              >
                <q-tooltip>Submit for Approval</q-tooltip>
              </q-btn>
              <q-btn
                v-if="props.row.status === 'pending'"
                flat
                dense
                round
                size="sm"
                icon="check"
                color="positive"
                @click.stop="approvePO(props.row)"
              >
                <q-tooltip>Approve</q-tooltip>
              </q-btn>
              <q-btn
                v-if="props.row.status === 'approved'"
                flat
                dense
                round
                size="sm"
                icon="move_to_inbox"
                color="info"
                @click.stop="createGRN(props.row)"
              >
                <q-tooltip>Create GRN</q-tooltip>
              </q-btn>
              <q-btn
                flat
                dense
                round
                size="sm"
                icon="visibility"
                color="grey"
                @click.stop="viewPO(props.row)"
              />
            </q-td>
          </template>
        </SAPTable>
      </SAPCard>
    </div>

    <!-- Create PO Dialog -->
    <SAPDialog
      v-model="showCreateDialog"
      title="Create Purchase Order"
      icon="shopping_cart"
      width="1000px"
      :loading="saving"
      confirm-label="Create PO"
      @confirm="submitForm"
    >
      <q-form ref="poFormRef" @submit.prevent>
        <div class="row q-col-gutter-md">
          <!-- Header -->
          <div class="col-12 col-md-6">
            <label class="sap-label required">Supplier</label>
            <SAPSelect
              v-model="poForm.supplier_id"
              :options="stockStore.activeSuppliers"
              option-label="name"
              option-value="id"
              placeholder="Select supplier"
              searchable
              :rules="requiredRules"
            />
          </div>
          <div class="col-12 col-md-3">
            <SAPInput
              v-model="poForm.doc_date"
              label="Document Date"
              type="date"
              required
              :rules="requiredRules"
            />
          </div>
          <div class="col-12 col-md-3">
            <SAPInput v-model="poForm.delivery_date" label="Delivery Date" type="date" />
          </div>
          <div class="col-12 col-md-6">
            <label class="sap-label required">Warehouse</label>
            <SAPSelect
              v-model="poForm.warehouse_id"
              :options="stockStore.activeWarehouses"
              option-label="name"
              option-value="id"
              placeholder="Select warehouse"
              :rules="requiredRules"
            />
          </div>
          <div class="col-12 col-md-6">
            <SAPInput v-model="poForm.remarks" label="Remarks" />
          </div>

          <!-- Line Items -->
          <div class="col-12">
            <div class="section-title q-mt-md q-mb-sm">
              Line Items
              <q-btn
                dense
                flat
                color="primary"
                icon="add"
                label="Add Item"
                size="sm"
                @click="addLine"
              />
            </div>

            <q-table
              :rows="poLines"
              :columns="lineColumns"
              row-key="lineNum"
              hide-pagination
              flat
              bordered
              dense
              class="lines-table"
            >
              <template #body="props">
                <q-tr :props="props">
                  <q-td key="lineNum">{{ props.row.lineNum }}</q-td>
                  <q-td key="item_id">
                    <SAPSelect
                      v-model="props.row.item_id"
                      :options="stockStore.activeItems"
                      option-label="item_name"
                      option-value="id"
                      placeholder="Select item"
                      searchable
                      style="min-width: 200px"
                      @update:model-value="onItemSelect(props.row)"
                    />
                  </q-td>
                  <q-td key="quantity">
                    <q-input
                      v-model.number="props.row.quantity"
                      type="number"
                      dense
                      outlined
                      min="0"
                      style="width: 80px"
                      @update:model-value="calcLineTotal(props.row)"
                    />
                  </q-td>
                  <q-td key="uom_id">
                    <SAPSelect
                      v-model="props.row.uom_id"
                      :options="stockStore.unitsOfMeasure"
                      option-label="code"
                      option-value="id"
                      style="width: 80px"
                    />
                  </q-td>
                  <q-td key="unit_price">
                    <q-input
                      v-model.number="props.row.unit_price"
                      type="number"
                      dense
                      outlined
                      step="0.01"
                      style="width: 100px"
                      @update:model-value="calcLineTotal(props.row)"
                    />
                  </q-td>
                  <q-td key="line_total" class="text-right text-bold">
                    {{ formatCurrency(props.row.line_total) }}
                  </q-td>
                  <q-td key="actions">
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
                </q-tr>
              </template>

              <template #bottom>
                <div class="po-totals">
                  <div>
                    Subtotal: <strong>{{ formatCurrency(poSubtotal) }}</strong>
                  </div>
                </div>
              </template>
            </q-table>
          </div>
        </div>
      </q-form>
    </SAPDialog>

    <!-- View PO Dialog -->
    <SAPDialog
      v-model="showViewDialog"
      :title="`Purchase Order: ${selectedPO?.doc_number || ''}`"
      icon="shopping_cart"
      width="900px"
      :show-default-footer="false"
    >
      <template v-if="selectedPO">
        <div class="row q-col-gutter-md q-mb-md">
          <div class="col-4">
            <div class="detail-label">Supplier</div>
            <div class="row items-center no-wrap">
              <div class="detail-value q-mr-xs">{{ selectedPO.supplier?.name }}</div>
              <GoldenArrow @click="goToSupplierMaster(selectedPO.supplier?.id)" />
            </div>
          </div>
          <div class="col-4">
            <div class="detail-label">Document Date</div>
            <div class="detail-value">{{ selectedPO.doc_date }}</div>
          </div>
          <div class="col-4">
            <div class="detail-label">Status</div>
            <q-badge :color="getStatusColor(selectedPO.status)" :label="selectedPO.status" />
          </div>
          <div class="col-4">
            <div class="detail-label">Warehouse</div>
            <div class="detail-value">{{ selectedPO.warehouse?.name }}</div>
          </div>
          <div class="col-4">
            <div class="detail-label">Total Amount</div>
            <div class="detail-value text-bold">{{ formatCurrency(selectedPO.total_amount) }}</div>
          </div>
          <div class="col-4">
            <div class="detail-label">Created By</div>
            <div class="detail-value">{{ selectedPO.created_by_user?.full_name || '—' }}</div>
          </div>
        </div>

        <q-separator class="q-my-md" />

        <div class="section-title q-mb-sm">Line Items</div>
        <SAPTable
          :rows="selectedPO.po_lines || []"
          :columns="viewLineColumns"
          :show-search="false"
          :show-count="false"
          row-key="id"
        >
          <template #body-cell-item_code="props">
            <q-td :props="props">
              <div class="row items-center no-wrap">
                <span class="text-bold q-mr-xs">{{ props.value }}</span>
                <GoldenArrow @click="goToItemMaster(props.row.item?.id)" />
              </div>
            </q-td>
          </template>

          <template #body-cell-line_total="props">
            <q-td :props="props" class="text-right text-bold">
              {{ formatCurrency(props.value) }}
            </q-td>
          </template>
        </SAPTable>
      </template>
    </SAPDialog>
  </q-page>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { useQuasar } from 'quasar'
import { useRouter } from 'vue-router'
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
const router = useRouter()
const stockStore = useStockStore()
const authStore = useAuthStore()

// State
const showCreateDialog = ref(false)
const showViewDialog = ref(false)
const saving = ref(false)
const poFormRef = ref(null)
const poForm = ref(getEmptyForm())
const requiredRules = [(val) => !!val || 'Field is required']
const poLines = ref([])
const selectedPO = ref(null)

// Counts
const draftCount = computed(
  () => stockStore.purchaseOrders.filter((po) => po.status === 'draft').length,
)
const pendingCount = computed(
  () => stockStore.purchaseOrders.filter((po) => po.status === 'pending').length,
)
const approvedCount = computed(
  () => stockStore.purchaseOrders.filter((po) => po.status === 'approved').length,
)
const completedCount = computed(
  () => stockStore.purchaseOrders.filter((po) => po.status === 'completed').length,
)

const poSubtotal = computed(() => poLines.value.reduce((sum, l) => sum + (l.line_total || 0), 0))

// Columns
const columns = [
  { name: 'doc_number', label: 'Doc #', field: 'doc_number', sortable: true, align: 'left' },
  { name: 'doc_date', label: 'Date', field: 'doc_date', sortable: true, align: 'left' },
  {
    name: 'supplier',
    label: 'Supplier',
    field: (row) => row.supplier?.name,
    sortable: true,
    align: 'left',
  },
  { name: 'warehouse', label: 'Warehouse', field: (row) => row.warehouse?.name, align: 'left' },
  { name: 'status', label: 'Status', field: 'status', align: 'center' },
  { name: 'total_amount', label: 'Total', field: 'total_amount', sortable: true, align: 'right' },
  { name: 'actions', label: 'Actions', field: 'actions', align: 'center' },
]

const lineColumns = [
  { name: 'lineNum', label: '#', field: 'lineNum', align: 'center' },
  { name: 'item_id', label: 'Item', field: 'item_id', align: 'left' },
  { name: 'quantity', label: 'Qty', field: 'quantity', align: 'center' },
  { name: 'uom_id', label: 'UoM', field: 'uom_id', align: 'center' },
  { name: 'unit_price', label: 'Unit Price', field: 'unit_price', align: 'right' },
  { name: 'line_total', label: 'Total', field: 'line_total', align: 'right' },
  { name: 'actions', label: '', field: 'actions', align: 'center' },
]

const viewLineColumns = [
  { name: 'line_num', label: '#', field: 'line_num', align: 'center' },
  { name: 'item_code', label: 'Item Code', field: (row) => row.item?.item_code, align: 'left' },
  {
    name: 'item',
    label: 'Description',
    field: (row) => row.item?.item_name,
    align: 'left',
  },
  { name: 'quantity', label: 'Quantity', field: 'quantity', align: 'right' },
  { name: 'uom', label: 'UoM', field: (row) => row.uom?.code, align: 'center' },
  { name: 'unit_price', label: 'Unit Price', field: 'unit_price', align: 'right' },
  { name: 'received_quantity', label: 'Received', field: 'received_quantity', align: 'right' },
  { name: 'line_total', label: 'Total', field: 'line_total', align: 'right' },
]

// Methods
function getEmptyForm() {
  return {
    supplier_id: null,
    warehouse_id: null,
    doc_date: new Date().toISOString().split('T')[0],
    delivery_date: '',
    remarks: '',
  }
}

function getStatusColor(status) {
  const colors = {
    draft: 'grey',
    pending: 'warning',
    approved: 'info',
    completed: 'positive',
    cancelled: 'negative',
  }
  return colors[status] || 'grey'
}

function formatCurrency(value) {
  if (value == null) return '—'
  return new Intl.NumberFormat('en-US', { style: 'currency', currency: 'LKR' }).format(value)
}

async function loadData() {
  await Promise.all([
    stockStore.fetchPurchaseOrders(),
    stockStore.fetchSuppliers(),
    stockStore.fetchWarehouses(),
    stockStore.fetchItems(),
  ])
}

function openCreateDialog() {
  poForm.value = getEmptyForm()
  poLines.value = [getEmptyLine(1)]
  showCreateDialog.value = true
}

function getEmptyLine(lineNum) {
  return { lineNum, item_id: null, quantity: 1, uom_id: null, unit_price: 0, line_total: 0 }
}

function addLine() {
  poLines.value.push(getEmptyLine(poLines.value.length + 1))
}

function removeLine(index) {
  poLines.value.splice(index, 1)
  poLines.value.forEach((l, i) => (l.lineNum = i + 1))
}

function onItemSelect(line) {
  const item = stockStore.items.find((i) => i.id === line.item_id)
  if (item) {
    line.uom_id = item.base_uom_id
    line.unit_price = item.purchase_price || 0
    line.item_description = item.item_name
    calcLineTotal(line)
  }
}

function calcLineTotal(line) {
  line.line_total = (line.quantity || 0) * (line.unit_price || 0)
}

async function savePO() {
  if (!poForm.value.supplier_id || !poForm.value.warehouse_id) {
    $q.notify({ type: 'warning', message: 'Please select supplier and warehouse' })
    return
  }
  if (poLines.value.length === 0 || !poLines.value[0].item_id) {
    $q.notify({ type: 'warning', message: 'Please add at least one item' })
    return
  }

  saving.value = true
  try {
    const result = await stockStore.createPurchaseOrder(
      { ...poForm.value, created_by: authStore.profile?.id },
      poLines.value.filter((l) => l.item_id),
    )

    if (result.success) {
      $q.notify({ type: 'positive', message: 'Purchase Order created successfully' })
      showCreateDialog.value = false
    } else {
      $q.notify({ type: 'negative', message: result.error })
    }
  } finally {
    saving.value = false
  }
}

async function submitForm() {
  const success = await poFormRef.value.validate()
  if (success) {
    savePO()
  }
}

function viewPO(po) {
  selectedPO.value = po
  showViewDialog.value = true
}

async function submitForApproval(po) {
  const { error } = await stockStore.approvePurchaseOrder(po.id, null) // Just update status to pending
  if (!error) {
    $q.notify({ type: 'positive', message: 'PO submitted for approval' })
    await loadData()
  }
}

async function approvePO(po) {
  const result = await stockStore.approvePurchaseOrder(po.id, authStore.profile?.id)
  if (result.success) {
    $q.notify({ type: 'positive', message: 'PO approved successfully' })
  }
}

function createGRN(po) {
  router.push({ path: '/stock/grn', query: { po_id: po.id } })
}

function goToItemMaster(itemId) {
  if (!itemId) return
  router.push({ path: '/stock/items', query: { id: itemId } })
}

function goToSupplierMaster(supplierId) {
  if (!supplierId) return
  router.push({ path: '/stock/suppliers', query: { id: supplierId } })
}

// Keyboard Shortcuts
function handleKeydown(e) {
  // Ctrl + A: Add Record
  if (e.ctrlKey && e.key === 'a') {
    e.preventDefault()
    openCreateDialog()
  }
  // Esc: Close Dialogs
  if (e.key === 'Escape') {
    showCreateDialog.value = false
    showViewDialog.value = false
  }
}

onMounted(async () => {
  window.addEventListener('keydown', handleKeydown)
  await loadData()
})

onUnmounted(() => {
  window.removeEventListener('keydown', handleKeydown)
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
  gap: 12px;
  padding: 4px;
}

.stat-value {
  font-size: 20px;
  font-weight: 700;
}

.stat-label {
  font-size: 11px;
  color: #666;
}

.doc-number {
  font-family: 'Consolas', monospace;
  font-weight: 600;
  color: $primary;
}

.status-badge {
  font-size: 10px;
  text-transform: capitalize;
}

.section-title {
  display: flex;
  align-items: center;
  justify-content: space-between;
  font-size: 13px;
  font-weight: 600;
  color: #333;
}

.sap-label {
  display: block;
  font-size: 12px;
  font-weight: 500;
  color: #555;
  margin-bottom: 4px;

  &.required::after {
    content: ' *';
    color: $negative;
  }
}

.lines-table {
  :deep(th),
  :deep(td) {
    font-size: 12px;
    padding: 6px 8px;
  }
}

.po-totals {
  display: flex;
  justify-content: flex-end;
  padding: 12px;
  font-size: 14px;
}

.detail-label {
  font-size: 11px;
  color: #666;
  margin-bottom: 2px;
}

.detail-value {
  font-size: 13px;
}

.actions-cell {
  width: 140px;
}
</style>
