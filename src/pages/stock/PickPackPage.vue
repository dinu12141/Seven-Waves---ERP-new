<template>
  <q-page class="sap-page">
    <SAPToolbar
      title="Pick & Pack Manager"
      icon="local_shipping"
      :badge="inventoryStore.pickLists.length"
      add-label="New Pick List"
      :show-export="true"
      @add="openCreateDialog"
      @refresh="loadData"
    />

    <div class="sap-page-content">
      <!-- Stats -->
      <div class="row q-col-gutter-md q-mb-md">
        <div class="col-6 col-md-3">
          <SAPCard flat bordered>
            <div class="stat-card">
              <q-icon name="assignment" size="32px" color="warning" />
              <div class="stat-info">
                <div class="stat-value">{{ openPickLists }}</div>
                <div class="stat-label">Open</div>
              </div>
            </div>
          </SAPCard>
        </div>
        <div class="col-6 col-md-3">
          <SAPCard flat bordered>
            <div class="stat-card">
              <q-icon name="inventory_2" size="32px" color="info" />
              <div class="stat-info">
                <div class="stat-value">{{ inProgressLists }}</div>
                <div class="stat-label">Picking</div>
              </div>
            </div>
          </SAPCard>
        </div>
        <div class="col-6 col-md-3">
          <SAPCard flat bordered>
            <div class="stat-card">
              <q-icon name="check_box" size="32px" color="positive" />
              <div class="stat-info">
                <div class="stat-value">{{ pickedLists }}</div>
                <div class="stat-label">Picked</div>
              </div>
            </div>
          </SAPCard>
        </div>
        <div class="col-6 col-md-3">
          <SAPCard flat bordered>
            <div class="stat-card">
              <q-icon name="local_shipping" size="32px" color="accent" />
              <div class="stat-info">
                <div class="stat-value">{{ shippedLists }}</div>
                <div class="stat-label">Shipped</div>
              </div>
            </div>
          </SAPCard>
        </div>
      </div>

      <!-- Tabs -->
      <SAPCard no-padding>
        <q-tabs
          v-model="activeTab"
          dense
          class="text-grey"
          active-color="primary"
          indicator-color="primary"
        >
          <q-tab name="all" label="All Lists" />
          <q-tab name="open" label="Open" />
          <q-tab name="picking" label="In Progress" />
          <q-tab name="packed" label="Packed" />
        </q-tabs>

        <q-separator />

        <SAPTable
          :rows="filteredLists"
          :columns="columns"
          :loading="inventoryStore.loading"
          :show-drill-down="true"
          row-key="id"
          @row-click="viewPickList"
        >
          <template #body-cell-doc_number="props">
            <q-td :props="props">
              <div class="row items-center no-wrap">
                <span class="text-bold">{{ props.value }}</span>
                <GoldenArrow @click="viewPickList(props.row)" />
              </div>
            </q-td>
          </template>

          <template #body-cell-priority="props">
            <q-td :props="props" class="text-center">
              <q-badge
                :color="getPriorityColor(props.value)"
                :label="props.value"
                class="text-capitalize"
              />
            </q-td>
          </template>

          <template #body-cell-status="props">
            <q-td :props="props" class="text-center">
              <q-badge :color="getStatusColor(props.value)" :label="formatStatus(props.value)" />
            </q-td>
          </template>

          <template #body-cell-progress="props">
            <q-td :props="props">
              <div class="row items-center no-wrap">
                <q-linear-progress
                  :value="getProgress(props.row)"
                  :color="getProgress(props.row) === 1 ? 'positive' : 'primary'"
                  style="width: 80px"
                  class="q-mr-sm"
                />
                <span class="text-caption">{{ getProgressText(props.row) }}</span>
              </div>
            </q-td>
          </template>

          <template #body-cell-actions="props">
            <q-td :props="props" class="actions-cell">
              <q-btn
                v-if="props.row.status === 'open'"
                flat
                dense
                round
                size="sm"
                icon="play_arrow"
                color="primary"
                @click.stop="startPicking(props.row)"
              >
                <q-tooltip>Start Picking</q-tooltip>
              </q-btn>
              <q-btn
                v-if="props.row.status === 'in_progress'"
                flat
                dense
                round
                size="sm"
                icon="edit"
                color="primary"
                @click.stop="continuePicking(props.row)"
              >
                <q-tooltip>Continue Picking</q-tooltip>
              </q-btn>
              <q-btn
                v-if="props.row.status === 'picked'"
                flat
                dense
                round
                size="sm"
                icon="inventory_2"
                color="accent"
                @click.stop="startPacking(props.row)"
              >
                <q-tooltip>Start Packing</q-tooltip>
              </q-btn>
              <q-btn
                flat
                dense
                round
                size="sm"
                icon="visibility"
                color="info"
                @click.stop="viewPickList(props.row)"
              >
                <q-tooltip>View</q-tooltip>
              </q-btn>
              <q-btn
                flat
                dense
                round
                size="sm"
                icon="print"
                color="grey-7"
                @click.stop="printPickList(props.row)"
              >
                <q-tooltip>Print</q-tooltip>
              </q-btn>
            </q-td>
          </template>
        </SAPTable>
      </SAPCard>
    </div>

    <!-- Create Pick List Dialog -->
    <SAPDialog
      v-model="showCreateDialog"
      title="Create Pick List"
      icon="local_shipping"
      width="800px"
      :loading="saving"
      confirm-label="Create"
      @confirm="createPickList"
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
            />
          </div>
          <div class="col-12 col-md-6">
            <label class="sap-label">Priority</label>
            <SAPSelect
              v-model="form.priority"
              :options="priorities"
              option-label="label"
              option-value="value"
            />
          </div>
          <div class="col-12 col-md-6">
            <label class="sap-label">Assigned To</label>
            <SAPSelect
              v-model="form.assigned_to"
              :options="users"
              option-label="full_name"
              option-value="id"
              placeholder="Select picker"
            />
          </div>
          <div class="col-12 col-md-6">
            <SAPInput v-model="form.ship_date" label="Ship Date" type="date" />
          </div>
          <div class="col-12">
            <SAPInput v-model="form.notes" label="Notes" type="textarea" rows="2" />
          </div>

          <!-- Source: Pending Sales Orders -->
          <div class="col-12">
            <div class="section-title q-mb-sm">Pending Sales Orders</div>
            <q-table
              :rows="pendingSalesOrders"
              :columns="soColumns"
              row-key="id"
              selection="multiple"
              v-model:selected="selectedOrders"
              dense
              flat
              bordered
              class="sap-table"
              :pagination="{ rowsPerPage: 5 }"
            >
              <template #body-cell-total="props">
                <q-td :props="props" class="text-right">
                  {{ formatCurrency(props.row.total_amount) }}
                </q-td>
              </template>
            </q-table>
          </div>
        </div>
      </q-form>
    </SAPDialog>

    <!-- Picking/Packing Dialog -->
    <SAPDialog
      v-model="showPickDialog"
      :title="pickDialogTitle"
      icon="local_shipping"
      width="900px"
      :show-default-footer="isPickingMode"
      :confirm-label="'Complete Picking'"
      @confirm="completePicking"
    >
      <template v-if="selectedList">
        <div class="row q-col-gutter-md q-mb-md">
          <div class="col-3">
            <div class="detail-label">Pick List</div>
            <div class="detail-value">{{ selectedList.doc_number }}</div>
          </div>
          <div class="col-3">
            <div class="detail-label">Warehouse</div>
            <div class="detail-value">{{ selectedList.warehouse?.name }}</div>
          </div>
          <div class="col-3">
            <div class="detail-label">Status</div>
            <q-badge
              :color="getStatusColor(selectedList.status)"
              :label="formatStatus(selectedList.status)"
            />
          </div>
          <div class="col-3">
            <div class="detail-label">Progress</div>
            <div class="detail-value">{{ getProgressText(selectedList) }}</div>
          </div>
        </div>

        <q-separator class="q-mb-md" />

        <SAPTable
          :rows="selectedList.pick_list_lines || []"
          :columns="lineColumns"
          :show-search="false"
          row-key="id"
        >
          <template #body-cell-from_bin="props">
            <q-td :props="props">
              <span class="text-primary">{{ props.row.from_bin?.bin_code || '—' }}</span>
            </q-td>
          </template>

          <template #body-cell-picked_quantity="props">
            <q-td :props="props">
              <q-input
                v-if="isPickingMode && selectedList.status === 'in_progress'"
                v-model.number="props.row.picked_quantity"
                type="number"
                :max="props.row.required_quantity"
                min="0"
                dense
                outlined
                style="width: 80px"
                @blur="updatePickedQty(props.row)"
              />
              <span v-else>{{ props.value || 0 }}</span>
            </q-td>
          </template>

          <template #body-cell-pick_status="props">
            <q-td :props="props" class="text-center">
              <q-badge
                :color="getLineStatusColor(props.value)"
                :label="props.value"
                class="text-capitalize"
              />
            </q-td>
          </template>

          <template #body-cell-actions="props">
            <q-td :props="props" class="actions-cell" v-if="isPickingMode">
              <q-btn
                flat
                dense
                round
                size="sm"
                icon="check"
                color="positive"
                @click.stop="pickFullQty(props.row)"
              >
                <q-tooltip>Pick Full Qty</q-tooltip>
              </q-btn>
            </q-td>
          </template>
        </SAPTable>
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
const activeTab = ref('all')
const showCreateDialog = ref(false)
const showPickDialog = ref(false)
const saving = ref(false)
const isPickingMode = ref(false)
const formRef = ref(null)
const selectedList = ref(null)
const selectedOrders = ref([])
const users = ref([])

const form = ref({
  warehouse_id: null,
  priority: 'normal',
  assigned_to: null,
  ship_date: null,
  notes: '',
})

const priorities = [
  { value: 'low', label: 'Low' },
  { value: 'normal', label: 'Normal' },
  { value: 'high', label: 'High' },
  { value: 'urgent', label: 'Urgent' },
]

const columns = [
  {
    name: 'doc_number',
    label: 'Pick List No.',
    field: 'doc_number',
    sortable: true,
    align: 'left',
    style: 'width: 130px',
  },
  {
    name: 'warehouse',
    label: 'Warehouse',
    field: (row) => row.warehouse?.name,
    sortable: true,
    align: 'left',
  },
  {
    name: 'pick_date',
    label: 'Date',
    field: (row) => formatDate(row.pick_date),
    sortable: true,
    align: 'left',
  },
  { name: 'priority', label: 'Priority', field: 'priority', align: 'center' },
  {
    name: 'assigned',
    label: 'Assigned To',
    field: (row) => row.assigned_user?.full_name || '—',
    align: 'left',
  },
  { name: 'progress', label: 'Progress', field: 'progress', align: 'left' },
  { name: 'status', label: 'Status', field: 'status', sortable: true, align: 'center' },
  { name: 'actions', label: 'Actions', field: 'actions', align: 'center' },
]

const soColumns = [
  { name: 'doc_number', label: 'SO Number', field: 'doc_number', align: 'left' },
  { name: 'customer', label: 'Customer', field: 'customer_name', align: 'left' },
  { name: 'order_date', label: 'Date', field: (row) => formatDate(row.order_date), align: 'left' },
  {
    name: 'items',
    label: 'Items',
    field: (row) => row.sales_order_lines?.length || 0,
    align: 'right',
  },
  { name: 'total', label: 'Total', field: 'total_amount', align: 'right' },
]

const lineColumns = [
  {
    name: 'item',
    label: 'Item',
    field: (row) => `${row.item?.item_code} - ${row.item?.item_name}`,
    align: 'left',
  },
  { name: 'from_bin', label: 'Bin Location', field: 'from_bin', align: 'left' },
  { name: 'uom', label: 'UoM', field: (row) => row.uom?.code || '—', align: 'center' },
  { name: 'required_quantity', label: 'Required', field: 'required_quantity', align: 'right' },
  { name: 'picked_quantity', label: 'Picked', field: 'picked_quantity', align: 'right' },
  { name: 'pick_status', label: 'Status', field: 'pick_status', align: 'center' },
  { name: 'actions', label: '', field: 'actions', align: 'center' },
]

const requiredRules = [(val) => !!val || 'Required']

// Computed
const filteredLists = computed(() => {
  const lists = inventoryStore.pickLists
  switch (activeTab.value) {
    case 'open':
      return lists.filter((l) => l.status === 'open')
    case 'picking':
      return lists.filter((l) => l.status === 'in_progress')
    case 'packed':
      return lists.filter((l) => ['picked', 'packed', 'shipped'].includes(l.status))
    default:
      return lists
  }
})

const pendingSalesOrders = computed(() => inventoryStore.pendingSalesOrders)

const openPickLists = computed(
  () => inventoryStore.pickLists.filter((l) => l.status === 'open').length,
)
const inProgressLists = computed(
  () => inventoryStore.pickLists.filter((l) => l.status === 'in_progress').length,
)
const pickedLists = computed(
  () => inventoryStore.pickLists.filter((l) => l.status === 'picked').length,
)
const shippedLists = computed(
  () => inventoryStore.pickLists.filter((l) => l.status === 'shipped').length,
)

const pickDialogTitle = computed(() => {
  if (!selectedList.value) return 'Pick List'
  if (isPickingMode.value) return `Picking: ${selectedList.value.doc_number}`
  return selectedList.value.doc_number
})

// Methods
function formatDate(date) {
  if (!date) return '—'
  return new Date(date).toLocaleDateString()
}

function formatCurrency(value) {
  if (value == null) return '—'
  return new Intl.NumberFormat('en-US', { style: 'currency', currency: 'LKR' }).format(value)
}

function formatStatus(status) {
  const map = {
    open: 'Open',
    in_progress: 'Picking',
    picked: 'Picked',
    packed: 'Packed',
    shipped: 'Shipped',
    cancelled: 'Cancelled',
  }
  return map[status] || status
}

function getStatusColor(status) {
  const colors = {
    open: 'warning',
    in_progress: 'info',
    picked: 'positive',
    packed: 'accent',
    shipped: 'primary',
    cancelled: 'negative',
  }
  return colors[status] || 'grey'
}

function getPriorityColor(priority) {
  const colors = { low: 'grey', normal: 'primary', high: 'warning', urgent: 'negative' }
  return colors[priority] || 'grey'
}

function getLineStatusColor(status) {
  const colors = { pending: 'grey', partial: 'warning', picked: 'positive', short: 'negative' }
  return colors[status] || 'grey'
}

function getProgress(list) {
  const lines = list.pick_list_lines || []
  if (lines.length === 0) return 0
  const picked = lines.filter((l) => l.picked_quantity >= l.required_quantity).length
  return picked / lines.length
}

function getProgressText(list) {
  const lines = list.pick_list_lines || []
  if (lines.length === 0) return '0/0'
  const picked = lines.filter((l) => l.picked_quantity >= l.required_quantity).length
  return `${picked}/${lines.length}`
}

async function loadData() {
  await Promise.all([
    stockStore.initializeStore(),
    inventoryStore.fetchPickLists(),
    inventoryStore.fetchSalesOrders(),
  ])
}

function openCreateDialog() {
  form.value = {
    warehouse_id: stockStore.defaultWarehouse?.id,
    priority: 'normal',
    assigned_to: null,
    ship_date: null,
    notes: '',
  }
  selectedOrders.value = []
  showCreateDialog.value = true
}

async function createPickList() {
  const valid = await formRef.value?.validate()
  if (!valid) return

  if (selectedOrders.value.length === 0) {
    $q.notify({
      type: 'warning',
      message: 'Please select at least one sales order',
      position: 'top',
    })
    return
  }

  saving.value = true
  try {
    // Build lines from selected SO lines
    const lines = []
    for (const so of selectedOrders.value) {
      for (const soLine of so.sales_order_lines || []) {
        if (soLine.open_quantity > 0) {
          lines.push({
            item_id: soLine.item_id,
            source_doc_type: 'sales_order',
            source_doc_id: so.id,
            source_line_id: soLine.id,
            required_quantity: soLine.open_quantity,
            uom_id: soLine.uom_id,
          })
        }
      }
    }

    const result = await inventoryStore.createPickList(
      {
        ...form.value,
        created_by: authStore.user?.id,
      },
      lines,
    )

    if (result.success) {
      $q.notify({ type: 'positive', message: 'Pick list created', position: 'top' })
      showCreateDialog.value = false
    } else {
      $q.notify({ type: 'negative', message: result.error, position: 'top' })
    }
  } finally {
    saving.value = false
  }
}

function viewPickList(list) {
  selectedList.value = list
  isPickingMode.value = false
  showPickDialog.value = true
}

async function startPicking(list) {
  // Update status to in_progress
  const { supabase } = await import('src/boot/supabase')
  await supabase
    .from('pick_lists')
    .update({
      status: 'in_progress',
      pick_started_at: new Date().toISOString(),
      picked_by: authStore.user?.id,
    })
    .eq('id', list.id)

  await inventoryStore.fetchPickLists()
  selectedList.value = inventoryStore.pickLists.find((l) => l.id === list.id)
  isPickingMode.value = true
  showPickDialog.value = true
}

function continuePicking(list) {
  selectedList.value = list
  isPickingMode.value = true
  showPickDialog.value = true
}

async function updatePickedQty(line) {
  if (line.picked_quantity == null) return
  await inventoryStore.updatePickListLine(line.id, line.picked_quantity)
  await inventoryStore.fetchPickLists()
  selectedList.value = inventoryStore.pickLists.find((l) => l.id === selectedList.value.id)
}

async function pickFullQty(line) {
  line.picked_quantity = line.required_quantity
  await updatePickedQty(line)
}

async function completePicking() {
  const lines = selectedList.value.pick_list_lines || []
  const allPicked = lines.every((l) => l.picked_quantity >= l.required_quantity)

  if (!allPicked) {
    $q.dialog({
      title: 'Incomplete Picking',
      message: 'Some items are not fully picked. Complete anyway?',
      cancel: true,
    }).onOk(async () => {
      await finalizePicking()
    })
  } else {
    await finalizePicking()
  }
}

async function finalizePicking() {
  const { supabase } = await import('src/boot/supabase')
  await supabase
    .from('pick_lists')
    .update({
      status: 'picked',
      pick_completed_at: new Date().toISOString(),
    })
    .eq('id', selectedList.value.id)

  await inventoryStore.fetchPickLists()
  showPickDialog.value = false
  $q.notify({ type: 'positive', message: 'Picking completed', position: 'top' })
}

function startPacking() {
  $q.notify({ type: 'info', message: 'Packing workflow - Coming soon', position: 'top' })
}

function printPickList() {
  $q.notify({ type: 'info', message: 'Print pick list - Coming soon', position: 'top' })
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
