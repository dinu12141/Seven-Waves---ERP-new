<template>
  <q-page class="sap-page">
    <!-- Toolbar -->
    <SAPToolbar
      title="Goods Issue Notes (GIN)"
      icon="outbox"
      :badge="stockStore.goodsIssueNotes.length"
      add-label="New GIN"
      :show-export-excel="true"
      :show-export-pdf="true"
      @add="openCreateDialog"
      @refresh="loadData"
      @export-excel="exportExcel"
      @export-pdf="exportPDF"
    />

    <!-- Main Content -->
    <div class="sap-page-content">
      <!-- Issue Type Cards -->
      <div class="row q-col-gutter-md q-mb-md">
        <div class="col-12 col-md-3">
          <SAPCard flat bordered class="cursor-pointer" @click="filterType = 'all'">
            <div class="stat-card" :class="{ active: filterType === 'all' }">
              <q-icon name="list" size="28px" color="primary" />
              <div class="stat-info">
                <div class="stat-value">{{ stockStore.goodsIssueNotes.length }}</div>
                <div class="stat-label">All Issues</div>
              </div>
            </div>
          </SAPCard>
        </div>
        <div class="col-12 col-md-3">
          <SAPCard flat bordered class="cursor-pointer" @click="filterType = 'kitchen_transfer'">
            <div class="stat-card" :class="{ active: filterType === 'kitchen_transfer' }">
              <q-icon name="restaurant" size="28px" color="warning" />
              <div class="stat-info">
                <div class="stat-value">{{ kitchenTransfers }}</div>
                <div class="stat-label">Kitchen Transfers</div>
              </div>
            </div>
          </SAPCard>
        </div>
        <div class="col-12 col-md-3">
          <SAPCard flat bordered class="cursor-pointer" @click="filterType = 'internal_use'">
            <div class="stat-card" :class="{ active: filterType === 'internal_use' }">
              <q-icon name="home_work" size="28px" color="info" />
              <div class="stat-info">
                <div class="stat-value">{{ internalUse }}</div>
                <div class="stat-label">Internal Use</div>
              </div>
            </div>
          </SAPCard>
        </div>
        <div class="col-12 col-md-3">
          <SAPCard flat bordered class="cursor-pointer" @click="filterType = 'waste'">
            <div class="stat-card" :class="{ active: filterType === 'waste' }">
              <q-icon name="delete" size="28px" color="negative" />
              <div class="stat-info">
                <div class="stat-value">{{ wasteCount }}</div>
                <div class="stat-label">Waste</div>
              </div>
            </div>
          </SAPCard>
        </div>
      </div>

      <!-- GIN Table -->
      <SAPCard title="Issue Notes" icon="list" no-padding>
        <SAPTable
          :rows="filteredGINs"
          :columns="columns"
          :loading="stockStore.loading"
          row-key="id"
          @row-click="viewGIN"
        >
          <template #body-cell-doc_number="props">
            <q-td :props="props">
              <span class="doc-number">{{ props.value }}</span>
            </q-td>
          </template>

          <template #body-cell-issue_type="props">
            <q-td :props="props">
              <q-badge :color="getTypeColor(props.value)" :label="formatType(props.value)" />
            </q-td>
          </template>

          <template #body-cell-status="props">
            <q-td :props="props">
              <q-badge :color="getStatusColor(props.value)" :label="props.value" />
            </q-td>
          </template>

          <template #body-cell-actions="props">
            <q-td :props="props" class="actions-cell">
              <q-btn
                v-if="props.row.status === 'draft' || props.row.status === 'pending'"
                flat
                dense
                round
                size="sm"
                icon="check_circle"
                color="positive"
                @click.stop="completeGIN(props.row)"
              >
                <q-tooltip>Complete (Update Stock)</q-tooltip>
              </q-btn>
              <q-btn
                flat
                dense
                round
                size="sm"
                icon="visibility"
                color="grey"
                @click.stop="viewGIN(props.row)"
              />
            </q-td>
          </template>
        </SAPTable>
      </SAPCard>
    </div>

    <!-- Create GIN Dialog -->
    <SAPDialog
      v-model="showCreateDialog"
      title="Create Goods Issue Note"
      icon="outbox"
      width="1000px"
      :loading="saving"
      confirm-label="Create GIN"
      @confirm="submitForm"
    >
      <q-form ref="ginFormRef" @submit.prevent>
        <div class="row q-col-gutter-md">
          <div class="col-12 col-md-4">
            <label class="sap-label required">Issue Type</label>
            <SAPSelect
              v-model="ginForm.issue_type"
              :options="issueTypes"
              option-label="label"
              option-value="value"
              placeholder="Select type"
              :rules="requiredRules"
            />
          </div>
          <div class="col-12 col-md-4">
            <label class="sap-label required">From Warehouse</label>
            <SAPSelect
              v-model="ginForm.from_warehouse_id"
              :options="stockStore.warehouses"
              option-label="name"
              option-value="id"
              placeholder="Source warehouse"
              :rules="requiredRules"
            />
          </div>
          <div class="col-12 col-md-4">
            <label class="sap-label" :class="{ required: isTransfer }"
              >To Warehouse (for transfers)</label
            >
            <SAPSelect
              v-model="ginForm.to_warehouse_id"
              :options="availableTargetWarehouses"
              option-label="name"
              option-value="id"
              placeholder="Target warehouse"
              :disable="!isTransfer"
              :rules="isTransfer ? requiredRules : []"
            />
          </div>
          <div class="col-12 col-md-6">
            <SAPInput v-model="ginForm.doc_date" label="Document Date" type="date" />
          </div>
          <div class="col-12 col-md-6">
            <SAPInput v-model="ginForm.remarks" label="Remarks" />
          </div>

          <!-- Line Items -->
          <div class="col-12">
            <div class="section-title q-mt-md q-mb-sm">
              Items to Issue
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
              :rows="ginLines"
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
                  <q-td key="available">
                    <span :class="props.row.available > 0 ? 'text-positive' : 'text-negative'">
                      {{ props.row.available || 0 }}
                    </span>
                  </q-td>
                  <q-td key="quantity">
                    <q-input
                      v-model.number="props.row.quantity"
                      type="number"
                      dense
                      outlined
                      min="0"
                      :max="props.row.available"
                      style="width: 80px"
                    />
                  </q-td>
                  <q-td key="uom">{{ props.row.uom_code || '—' }}</q-td>
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
            </q-table>
          </div>
        </div>
      </q-form>
    </SAPDialog>

    <!-- View GIN Dialog -->
    <SAPDialog
      v-model="showViewDialog"
      :title="`GIN: ${selectedGIN?.doc_number || ''}`"
      icon="outbox"
      width="800px"
      :show-default-footer="false"
    >
      <template v-if="selectedGIN">
        <div class="row q-col-gutter-md q-mb-md">
          <div class="col-4">
            <div class="detail-label">Issue Type</div>
            <q-badge
              :color="getTypeColor(selectedGIN.issue_type)"
              :label="formatType(selectedGIN.issue_type)"
            />
          </div>
          <div class="col-4">
            <div class="detail-label">From Warehouse</div>
            <div class="detail-value">{{ selectedGIN.from_warehouse?.name }}</div>
          </div>
          <div class="col-4">
            <div class="detail-label">To Warehouse</div>
            <div class="detail-value">{{ selectedGIN.to_warehouse?.name || '—' }}</div>
          </div>
        </div>

        <SAPTable
          :rows="selectedGIN.gin_lines || []"
          :columns="viewLineColumns"
          :show-search="false"
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
import { useExport } from 'src/composables/useExport'

const $q = useQuasar()
const router = useRouter()
const stockStore = useStockStore()
const authStore = useAuthStore()
const { exportToExcel, exportToPDF } = useExport()

const showCreateDialog = ref(false)
const showViewDialog = ref(false)
const saving = ref(false)
const filterType = ref('all')
const ginFormRef = ref(null)
const ginForm = ref(getEmptyForm())
const requiredRules = [(val) => !!val || 'Field is required']
const ginLines = ref([])
const selectedGIN = ref(null)

const issueTypes = [
  { value: 'kitchen_transfer', label: 'Kitchen Transfer' },
  { value: 'internal_use', label: 'Internal Use' },
  { value: 'waste', label: 'Waste / Spoilage' },
  { value: 'adjustment', label: 'Stock Adjustment' },
]

const kitchenTransfers = computed(
  () => stockStore.goodsIssueNotes.filter((g) => g.issue_type === 'kitchen_transfer').length,
)
const internalUse = computed(
  () => stockStore.goodsIssueNotes.filter((g) => g.issue_type === 'internal_use').length,
)
const wasteCount = computed(
  () => stockStore.goodsIssueNotes.filter((g) => g.issue_type === 'waste').length,
)

const filteredGINs = computed(() => {
  if (filterType.value === 'all') return stockStore.goodsIssueNotes
  return stockStore.goodsIssueNotes.filter((g) => g.issue_type === filterType.value)
})

const isTransfer = computed(() => ['kitchen_transfer'].includes(ginForm.value.issue_type))

const availableTargetWarehouses = computed(() =>
  stockStore.warehouses.filter((w) => w.id !== ginForm.value.from_warehouse_id),
)

const columns = [
  { name: 'doc_number', label: 'Doc #', field: 'doc_number', sortable: true, align: 'left' },
  { name: 'doc_date', label: 'Date', field: 'doc_date', sortable: true, align: 'left' },
  { name: 'issue_type', label: 'Type', field: 'issue_type', align: 'center' },
  { name: 'from', label: 'From', field: (row) => row.from_warehouse?.name, align: 'left' },
  { name: 'to', label: 'To', field: (row) => row.to_warehouse?.name || '—', align: 'left' },
  { name: 'status', label: 'Status', field: 'status', align: 'center' },
  { name: 'actions', label: 'Actions', align: 'center' },
]

const lineColumns = [
  { name: 'lineNum', label: '#', align: 'center' },
  { name: 'item_id', label: 'Item', align: 'left' },
  { name: 'available', label: 'Available', align: 'center' },
  { name: 'quantity', label: 'Issue Qty', align: 'center' },
  { name: 'uom', label: 'UoM', align: 'center' },
  { name: 'actions', label: '', align: 'center' },
]

const viewLineColumns = [
  { name: 'line_num', label: '#', field: 'line_num', align: 'center' },
  { name: 'item_code', label: 'Item Code', field: (row) => row.item?.item_code, align: 'left' },
  { name: 'item', label: 'Description', field: (row) => row.item?.item_name, align: 'left' },
  { name: 'quantity', label: 'Quantity', field: 'quantity', align: 'right' },
  { name: 'uom', label: 'UoM', field: (row) => row.uom?.code, align: 'center' },
]

function getEmptyForm() {
  return {
    issue_type: 'kitchen_transfer',
    from_warehouse_id: null,
    to_warehouse_id: null,
    doc_date: new Date().toISOString().split('T')[0],
    remarks: '',
  }
}

function getStatusColor(status) {
  return (
    { draft: 'grey', pending: 'warning', completed: 'positive', cancelled: 'negative' }[status] ||
    'grey'
  )
}

function getTypeColor(type) {
  return (
    {
      kitchen_transfer: 'warning',
      internal_use: 'info',
      waste: 'negative',
      adjustment: 'grey',
    }[type] || 'grey'
  )
}

function formatType(type) {
  return (
    type
      ?.split('_')
      .map((w) => w.charAt(0).toUpperCase() + w.slice(1))
      .join(' ') || type
  )
}

async function loadData() {
  await Promise.all([
    stockStore.fetchGoodsIssueNotes(),
    stockStore.fetchWarehouses(),
    stockStore.fetchItems(),
  ])
}

function openCreateDialog() {
  ginForm.value = getEmptyForm()
  ginLines.value = [getEmptyLine(1)]
  showCreateDialog.value = true
}

function getEmptyLine(lineNum) {
  return { lineNum, item_id: null, quantity: 0, uom_id: null, uom_code: '', available: 0 }
}

function addLine() {
  ginLines.value.push(getEmptyLine(ginLines.value.length + 1))
}

function removeLine(index) {
  ginLines.value.splice(index, 1)
  ginLines.value.forEach((l, i) => (l.lineNum = i + 1))
}

function onItemSelect(line) {
  const item = stockStore.items.find((i) => i.id === line.item_id)
  if (item) {
    line.uom_id = item.base_uom_id
    line.uom_code = item.base_uom?.code
    line.item_description = item.item_name

    // Get available stock from selected warehouse
    const warehouseStock = item.warehouse_stock?.find(
      (ws) => ws.warehouse_id === ginForm.value.from_warehouse_id,
    )
    line.available = warehouseStock?.quantity_on_hand || 0
  }
}

async function saveGIN() {
  if (!ginForm.value.issue_type || !ginForm.value.from_warehouse_id) {
    $q.notify({ type: 'warning', message: 'Please select issue type and source warehouse' })
    return
  }

  saving.value = true
  try {
    const result = await stockStore.createGoodsIssueNote(
      { ...ginForm.value, created_by: authStore.profile?.id },
      ginLines.value.filter((l) => l.item_id && l.quantity > 0),
    )

    if (result.success) {
      $q.notify({ type: 'positive', message: 'GIN created successfully' })
      showCreateDialog.value = false
    } else {
      $q.notify({ type: 'negative', message: result.error })
    }
  } finally {
    saving.value = false
  }
}

async function submitForm() {
  const success = await ginFormRef.value.validate()
  if (success) {
    saveGIN()
  }
}

function viewGIN(gin) {
  selectedGIN.value = gin
  showViewDialog.value = true
}

async function completeGIN(gin) {
  $q.dialog({
    title: 'Complete GIN',
    message: 'This will update stock levels. Are you sure?',
    cancel: true,
  }).onOk(async () => {
    const result = await stockStore.completeGoodsIssueNote(gin.id, authStore.profile?.id)
    if (result.success) {
      $q.notify({ type: 'positive', message: 'GIN completed. Stock updated!' })
    } else {
      $q.notify({ type: 'negative', message: result.error })
    }
  })
}

function goToItemMaster(itemId) {
  if (!itemId) return
  router.push({ path: '/stock/items', query: { id: itemId } })
}

function exportExcel() {
  const flattenedData = getExportData()
  const exportCols = getExportColumns()
  const filename = `GIN_Detailed_Report_${new Date().toISOString().split('T')[0]}`
  const title = 'Goods Issue Notes (GIN) - Detailed Report'
  exportToExcel(flattenedData, exportCols, title, filename)
  $q.notify({ type: 'positive', message: 'Excel download started', position: 'top' })
}

function exportPDF() {
  const flattenedData = getExportData()
  const exportCols = getExportColumns()
  const filename = `GIN_Detailed_Report_${new Date().toISOString().split('T')[0]}`
  const title = 'Goods Issue Notes (GIN) - Detailed Report'
  exportToPDF(flattenedData, exportCols, title, filename)
  $q.notify({ type: 'positive', message: 'PDF download started', position: 'top' })
}

function getExportData() {
  const flattenedData = []
  stockStore.goodsIssueNotes.forEach((gin) => {
    if (gin.gin_lines && gin.gin_lines.length > 0) {
      gin.gin_lines.forEach((line) => {
        flattenedData.push({
          doc_number: gin.doc_number,
          doc_date: gin.doc_date,
          issue_type: formatType(gin.issue_type),
          source: gin.from_warehouse?.name,
          destination: gin.to_warehouse?.name || 'Internal/Waste',
          item_code: line.item?.item_code,
          item_name: line.item?.item_name,
          quantity: line.quantity,
          uom: line.uom?.code,
        })
      })
    }
  })
  return flattenedData
}

function getExportColumns() {
  return [
    { label: 'GIN Number', field: 'doc_number' },
    { label: 'Date', field: 'doc_date' },
    { label: 'Issue Type', field: 'issue_type' },
    { label: 'From Warehouse', field: 'source' },
    { label: 'Department/Kitchen', field: 'destination' },
    { label: 'Item Code', field: 'item_code' },
    { label: 'Item Name', field: 'item_name' },
    { label: 'Quantity', field: 'quantity' },
    { label: 'UoM', field: 'uom' },
  ]
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
  border-radius: 4px;
  transition: all 0.2s;

  &.active {
    background: rgba($primary, 0.1);
  }
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

.section-title {
  display: flex;
  justify-content: space-between;
  font-size: 13px;
  font-weight: 600;
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

.lines-table :deep(th),
.lines-table :deep(td) {
  font-size: 12px;
  padding: 6px 8px;
}

.detail-label {
  font-size: 11px;
  color: #666;
}
.detail-value {
  font-size: 13px;
}
.actions-cell {
  width: 100px;
}
</style>
