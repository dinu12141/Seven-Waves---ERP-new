<template>
  <q-page class="sap-page">
    <!-- Toolbar -->
    <SAPToolbar
      title="Goods Receipt Notes (GRN)"
      icon="move_to_inbox"
      :badge="stockStore.goodsReceiptNotes.length"
      add-label="New GRN"
      @add="openCreateDialog"
      @refresh="loadData"
    />

    <!-- Main Content -->
    <div class="sap-page-content">
      <!-- GRN Table -->
      <SAPCard title="GRN List" icon="list" no-padding>
        <SAPTable
          :rows="stockStore.goodsReceiptNotes"
          :columns="columns"
          :loading="stockStore.loading"
          :show-drill-down="true"
          row-key="id"
          @row-click="viewGRN"
          @drill-down="viewGRN"
        >
          <template #body-cell-doc_number="props">
            <q-td :props="props">
              <span class="doc-number">{{ props.value }}</span>
            </q-td>
          </template>

          <template #body-cell-status="props">
            <q-td :props="props">
              <q-badge :color="getStatusColor(props.value)" :label="props.value" />
            </q-td>
          </template>

          <template #body-cell-total_amount="props">
            <q-td :props="props" class="text-right text-bold">
              {{ formatCurrency(props.value) }}
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
                @click.stop="completeGRN(props.row)"
              >
                <q-tooltip>Complete GRN (Update Stock)</q-tooltip>
              </q-btn>
              <q-btn
                flat
                dense
                round
                size="sm"
                icon="visibility"
                color="grey"
                @click.stop="viewGRN(props.row)"
              />
            </q-td>
          </template>
        </SAPTable>
      </SAPCard>
    </div>

    <!-- Create GRN Dialog -->
    <SAPDialog
      v-model="showCreateDialog"
      title="Create Goods Receipt Note"
      icon="move_to_inbox"
      width="1000px"
      :loading="saving"
      confirm-label="Create GRN"
      @confirm="submitForm"
    >
      <q-form ref="grnFormRef" @submit.prevent>
        <div class="row q-col-gutter-md">
          <div class="col-12 col-md-6">
            <label class="sap-label">From Purchase Order</label>
            <SAPSelect
              v-model="selectedPOId"
              :options="approvedPOs"
              option-label="doc_number"
              option-value="id"
              placeholder="Select PO to receive"
              @update:model-value="onPOSelect"
            />
          </div>
          <div class="col-12 col-md-3">
            <SAPInput
              v-model="grnForm.doc_date"
              label="Document Date"
              type="date"
              required
              :rules="requiredRules"
            />
          </div>
          <div class="col-12 col-md-3">
            <label class="sap-label required">Supplier</label>
            <SAPSelect
              v-model="grnForm.supplier_id"
              :options="stockStore.suppliers"
              option-label="name"
              option-value="id"
              placeholder="Select supplier"
              :disable="!!selectedPOId"
              :rules="requiredRules"
            />
          </div>
          <div class="col-12 col-md-6">
            <label class="sap-label required">Warehouse</label>
            <SAPSelect
              v-model="grnForm.warehouse_id"
              :options="stockStore.warehouses"
              option-label="name"
              option-value="id"
              placeholder="Select warehouse"
              :rules="requiredRules"
            />
          </div>
          <div class="col-12 col-md-6">
            <SAPInput v-model="grnForm.remarks" label="Remarks" />
          </div>

          <!-- Line Items -->
          <div class="col-12">
            <div class="section-title q-mt-md q-mb-sm">
              Items to Receive
              <q-btn
                v-if="!selectedPOId"
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
              :rows="grnLines"
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
                  <q-td key="item">
                    {{ props.row.item_description || getItemName(props.row.item_id) }}
                  </q-td>
                  <q-td key="ordered">{{ props.row.ordered_qty || '—' }}</q-td>
                  <q-td key="received">{{ props.row.already_received || 0 }}</q-td>
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
                  <q-td key="unit_cost">
                    <q-input
                      v-model.number="props.row.unit_cost"
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
                </q-tr>
              </template>
            </q-table>
          </div>
        </div>
      </q-form>
    </SAPDialog>

    <!-- View GRN Dialog -->
    <SAPDialog
      v-model="showViewDialog"
      :title="`GRN: ${selectedGRN?.doc_number || ''}`"
      icon="move_to_inbox"
      width="900px"
      :show-default-footer="false"
    >
      <template v-if="selectedGRN">
        <div class="row q-col-gutter-md q-mb-md">
          <div class="col-4">
            <div class="detail-label">Supplier</div>
            <div class="detail-value">{{ selectedGRN.supplier?.name }}</div>
          </div>
          <div class="col-4">
            <div class="detail-label">PO Reference</div>
            <div class="detail-value">
              {{ selectedGRN.purchase_order?.doc_number || 'Direct Receipt' }}
            </div>
          </div>
          <div class="col-4">
            <div class="detail-label">Status</div>
            <q-badge :color="getStatusColor(selectedGRN.status)" :label="selectedGRN.status" />
          </div>
        </div>

        <SAPTable
          :rows="selectedGRN.grn_lines || []"
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
import { useRoute, useRouter } from 'vue-router'
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
const route = useRoute()
const router = useRouter()
const stockStore = useStockStore()
const authStore = useAuthStore()

const showCreateDialog = ref(false)
const showViewDialog = ref(false)
const saving = ref(false)
const grnFormRef = ref(null)
const grnForm = ref(getEmptyForm())
const requiredRules = [(val) => !!val || 'Field is required']
const grnLines = ref([])
const selectedPOId = ref(null)
const selectedGRN = ref(null)

const approvedPOs = computed(() =>
  stockStore.purchaseOrders.filter((po) => po.status === 'approved'),
)

const columns = [
  { name: 'doc_number', label: 'Doc #', field: 'doc_number', sortable: true, align: 'left' },
  { name: 'doc_date', label: 'Date', field: 'doc_date', sortable: true, align: 'left' },
  {
    name: 'po_ref',
    label: 'PO Ref',
    field: (row) => row.purchase_order?.doc_number || '—',
    align: 'left',
  },
  { name: 'supplier', label: 'Supplier', field: (row) => row.supplier?.name, align: 'left' },
  { name: 'warehouse', label: 'Warehouse', field: (row) => row.warehouse?.name, align: 'left' },
  { name: 'status', label: 'Status', field: 'status', align: 'center' },
  { name: 'total_amount', label: 'Total', field: 'total_amount', align: 'right' },
  { name: 'actions', label: 'Actions', align: 'center' },
]

const lineColumns = [
  { name: 'lineNum', label: '#', align: 'center' },
  { name: 'item', label: 'Item', align: 'left' },
  { name: 'ordered', label: 'Ordered', align: 'center' },
  { name: 'received', label: 'Already Received', align: 'center' },
  { name: 'quantity', label: 'Receive Qty', align: 'center' },
  { name: 'unit_cost', label: 'Unit Cost', align: 'right' },
  { name: 'line_total', label: 'Total', align: 'right' },
]

const viewLineColumns = [
  { name: 'line_num', label: '#', field: 'line_num', align: 'center' },
  { name: 'item_code', label: 'Item Code', field: (row) => row.item?.item_code, align: 'left' },
  { name: 'item', label: 'Description', field: (row) => row.item?.item_name, align: 'left' },
  { name: 'quantity', label: 'Quantity', field: 'quantity', align: 'right' },
  { name: 'uom', label: 'UoM', field: (row) => row.uom?.code, align: 'center' },
  { name: 'unit_cost', label: 'Unit Cost', field: 'unit_cost', align: 'right' },
  { name: 'line_total', label: 'Total', field: 'line_total', align: 'right' },
]

function getEmptyForm() {
  return {
    supplier_id: null,
    warehouse_id: null,
    po_id: null,
    doc_date: new Date().toISOString().split('T')[0],
    remarks: '',
  }
}

function getStatusColor(status) {
  const colors = { draft: 'grey', pending: 'warning', completed: 'positive', cancelled: 'negative' }
  return colors[status] || 'grey'
}

function formatCurrency(value) {
  if (value == null) return '—'
  return new Intl.NumberFormat('en-US', { style: 'currency', currency: 'LKR' }).format(value)
}

function getItemName(itemId) {
  const item = stockStore.items.find((i) => i.id === itemId)
  return item ? item.item_name : '—'
}

async function loadData() {
  await Promise.all([
    stockStore.fetchGoodsReceiptNotes(),
    stockStore.fetchPurchaseOrders(),
    stockStore.fetchSuppliers(),
    stockStore.fetchWarehouses(),
    stockStore.fetchItems(),
  ])
}

function openCreateDialog() {
  grnForm.value = getEmptyForm()
  grnLines.value = []
  selectedPOId.value = null

  // Check if coming from PO page
  if (route.query.po_id) {
    selectedPOId.value = route.query.po_id
    onPOSelect(route.query.po_id)
  }

  showCreateDialog.value = true
}

function onPOSelect(poId) {
  if (!poId) {
    grnLines.value = []
    return
  }

  const po = stockStore.purchaseOrders.find((p) => p.id === poId)
  if (po) {
    grnForm.value.supplier_id = po.supplier_id
    grnForm.value.warehouse_id = po.warehouse_id
    grnForm.value.po_id = po.id

    grnLines.value = (po.po_lines || []).map((line, idx) => ({
      lineNum: idx + 1,
      po_line_id: line.id,
      item_id: line.item_id,
      item_description: line.item?.item_name,
      ordered_qty: line.quantity,
      already_received: line.received_quantity || 0,
      quantity: line.quantity - (line.received_quantity || 0),
      uom_id: line.uom_id,
      unit_cost: line.unit_price,
      line_total: (line.quantity - (line.received_quantity || 0)) * line.unit_price,
    }))
  }
}

function addLine() {
  grnLines.value.push({
    lineNum: grnLines.value.length + 1,
    item_id: null,
    quantity: 1,
    uom_id: null,
    unit_cost: 0,
    line_total: 0,
  })
}

function calcLineTotal(line) {
  line.line_total = (line.quantity || 0) * (line.unit_cost || 0)
}

async function saveGRN() {
  if (!grnForm.value.supplier_id || !grnForm.value.warehouse_id) {
    $q.notify({ type: 'warning', message: 'Please select supplier and warehouse' })
    return
  }

  saving.value = true
  try {
    const result = await stockStore.createGoodsReceiptNote(
      { ...grnForm.value, created_by: authStore.profile?.id },
      grnLines.value.filter((l) => l.item_id && l.quantity > 0),
    )

    if (result.success) {
      $q.notify({ type: 'positive', message: 'GRN created successfully' })
      showCreateDialog.value = false
    } else {
      $q.notify({ type: 'negative', message: result.error })
    }
  } finally {
    saving.value = false
  }
}

async function submitForm() {
  const success = await grnFormRef.value.validate()
  if (success) {
    saveGRN()
  }
}

function viewGRN(grn) {
  selectedGRN.value = grn
  showViewDialog.value = true
}

async function completeGRN(grn) {
  $q.dialog({
    title: 'Complete GRN',
    message: 'This will update stock levels. Are you sure?',
    cancel: true,
  }).onOk(async () => {
    const result = await stockStore.completeGoodsReceiptNote(grn.id, authStore.profile?.id)
    if (result.success) {
      $q.notify({ type: 'positive', message: 'GRN completed. Stock updated!' })
    } else {
      $q.notify({ type: 'negative', message: result.error })
    }
  })
}

function goToItemMaster(itemId) {
  if (!itemId) return
  router.push({ path: '/stock/items', query: { id: itemId } })
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
}

.lines-table {
  :deep(th),
  :deep(td) {
    font-size: 12px;
    padding: 6px 8px;
  }
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
