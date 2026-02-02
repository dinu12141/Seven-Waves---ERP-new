<template>
  <q-page class="sap-page">
    <!-- Toolbar -->
    <SAPToolbar
      title="Stock Requests"
      icon="assignment"
      :badge="stockRequests.length"
      add-label="New Request"
      :show-export="true"
      @add="openCreateDialog"
      @refresh="loadData"
    />

    <!-- Status Filter Cards -->
    <div class="sap-page-content">
      <div class="row q-col-gutter-md q-mb-md">
        <div class="col-6 col-md-3">
          <SAPCard flat bordered class="cursor-pointer" @click="statusFilter = 'all'">
            <div class="stat-card" :class="{ active: statusFilter === 'all' }">
              <q-icon name="list" size="28px" color="primary" />
              <div class="stat-info">
                <div class="stat-value">{{ stockRequests.length }}</div>
                <div class="stat-label">All Requests</div>
              </div>
            </div>
          </SAPCard>
        </div>
        <div class="col-6 col-md-3">
          <SAPCard flat bordered class="cursor-pointer" @click="statusFilter = 'Pending'">
            <div class="stat-card" :class="{ active: statusFilter === 'Pending' }">
              <q-icon name="pending" size="28px" color="warning" />
              <div class="stat-info">
                <div class="stat-value">{{ pendingCount }}</div>
                <div class="stat-label">Pending Approval</div>
              </div>
            </div>
          </SAPCard>
        </div>
        <div class="col-6 col-md-3">
          <SAPCard flat bordered class="cursor-pointer" @click="statusFilter = 'Approved'">
            <div class="stat-card" :class="{ active: statusFilter === 'Approved' }">
              <q-icon name="check_circle" size="28px" color="positive" />
              <div class="stat-info">
                <div class="stat-value">{{ approvedCount }}</div>
                <div class="stat-label">Approved</div>
              </div>
            </div>
          </SAPCard>
        </div>
        <div class="col-6 col-md-3">
          <SAPCard flat bordered class="cursor-pointer" @click="statusFilter = 'Issued'">
            <div class="stat-card" :class="{ active: statusFilter === 'Issued' }">
              <q-icon name="local_shipping" size="28px" color="info" />
              <div class="stat-info">
                <div class="stat-value">{{ issuedCount }}</div>
                <div class="stat-label">Issued</div>
              </div>
            </div>
          </SAPCard>
        </div>
      </div>

      <!-- Requests Table -->
      <SAPCard title="Request List" icon="list" no-padding>
        <SAPTable
          :rows="filteredRequests"
          :columns="columns"
          :loading="loading"
          row-key="id"
          @row-click="viewRequest"
        >
          <template #body-cell-doc_number="props">
            <q-td :props="props">
              <span class="doc-number">{{ props.value }}</span>
              <GoldenArrow @click="viewRequest(props.row)" />
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
                v-if="props.row.status === 'Pending'"
                flat
                dense
                round
                size="sm"
                icon="check"
                color="positive"
                @click.stop="approveRequest(props.row)"
              >
                <q-tooltip>Approve</q-tooltip>
              </q-btn>
              <q-btn
                v-if="props.row.status === 'Approved'"
                flat
                dense
                round
                size="sm"
                icon="local_shipping"
                color="primary"
                @click.stop="issueRequest(props.row)"
              >
                <q-tooltip>Issue Items</q-tooltip>
              </q-btn>
              <q-btn
                flat
                dense
                round
                size="sm"
                icon="visibility"
                color="grey"
                @click.stop="viewRequest(props.row)"
              />
            </q-td>
          </template>
        </SAPTable>
      </SAPCard>
    </div>

    <!-- Create Request Dialog -->
    <SAPDialog
      v-model="showCreateDialog"
      title="Good Request Note"
      icon="assignment"
      width="1000px"
      :loading="saving"
      confirm-label="Confirm Request"
      @confirm="submitRequest"
    >
      <q-form ref="formRef" @submit.prevent>
        <div class="row q-col-gutter-md">
          <!-- Item Request Section -->
          <div class="col-12">
            <div class="section-header">
              <q-icon name="search" class="q-mr-sm" />
              Item Request
              <span class="text-caption text-grey q-ml-sm">
                Search and select items to request
              </span>
            </div>
          </div>

          <!-- Search Box -->
          <div class="col-12">
            <q-select
              v-model="selectedItem"
              :options="searchResults"
              option-label="item_name"
              option-value="id"
              use-input
              input-debounce="300"
              clearable
              placeholder="🔍 Search Item Name or Code..."
              :loading="searchLoading"
              class="search-input"
              @filter="onItemSearch"
              @update:model-value="addItemToRequest"
            >
              <template #option="{ opt, itemProps }">
                <q-item v-bind="itemProps" class="search-option">
                  <q-item-section avatar>
                    <q-badge
                      :color="opt.available > 0 ? 'positive' : 'negative'"
                      class="stock-badge"
                    >
                      {{ opt.available }}
                    </q-badge>
                  </q-item-section>
                  <q-item-section>
                    <q-item-label>{{ opt.item_name }}</q-item-label>
                    <q-item-label caption>{{ opt.item_code }}</q-item-label>
                  </q-item-section>
                  <q-item-section side>
                    <q-item-label class="text-grey">Stock: {{ opt.available }}</q-item-label>
                  </q-item-section>
                </q-item>
              </template>
              <template #no-option>
                <q-item>
                  <q-item-section class="text-grey">No items found</q-item-section>
                </q-item>
              </template>
            </q-select>
          </div>

          <!-- Request Lines Table -->
          <div class="col-12">
            <q-table
              :rows="requestLines"
              :columns="lineColumns"
              row-key="lineNum"
              flat
              bordered
              dense
              hide-pagination
              class="lines-table"
            >
              <template #body="props">
                <q-tr :props="props">
                  <q-td key="item_name">{{ props.row.item_name }}</q-td>
                  <q-td key="item_code">{{ props.row.item_code }}</q-td>
                  <q-td key="stock" class="text-center">
                    <q-badge :color="props.row.available > 0 ? 'blue' : 'negative'">
                      {{ props.row.available }}
                    </q-badge>
                  </q-td>
                  <q-td key="r_qty">
                    <q-input
                      v-model.number="props.row.requested_quantity"
                      type="number"
                      dense
                      outlined
                      min="1"
                      :max="props.row.available"
                      style="width: 80px"
                    />
                  </q-td>
                  <q-td key="confirmation" class="text-center">
                    <q-checkbox v-model="props.row.confirmation" color="positive" />
                  </q-td>
                  <q-td key="actions">
                    <q-btn
                      flat
                      round
                      dense
                      size="sm"
                      icon="delete"
                      color="negative"
                      @click="removeLine(props.rowIndex)"
                    />
                  </q-td>
                </q-tr>
              </template>
              <template #no-data>
                <div class="text-center text-grey q-pa-lg">
                  <q-icon name="search" size="48px" class="q-mb-sm" /><br />
                  Search and select items above
                </div>
              </template>
            </q-table>
          </div>

          <q-separator class="col-12" />

          <!-- Request Details -->
          <div class="col-12 col-md-6">
            <SAPSelect
              v-model="form.from_warehouse_id"
              label="Where House"
              :options="stockStore.warehouses"
              option-label="name"
              option-value="id"
              :rules="requiredRules"
            />
          </div>
          <div class="col-12 col-md-6">
            <SAPInput
              v-model="form.need_date"
              label="Need Date"
              type="date"
              :rules="requiredRules"
            />
          </div>
          <div class="col-12">
            <SAPInput v-model="form.remarks" label="Remarks" type="textarea" rows="2" />
          </div>
        </div>
      </q-form>
    </SAPDialog>

    <!-- View/Approve Dialog -->
    <SAPDialog
      v-model="showViewDialog"
      :title="`Request: ${selectedRequest?.doc_number || ''}`"
      icon="assignment"
      width="900px"
      :show-default-footer="false"
    >
      <template v-if="selectedRequest">
        <div class="row q-col-gutter-md q-mb-md">
          <div class="col-4">
            <div class="detail-label">Status</div>
            <q-badge
              :color="getStatusColor(selectedRequest.status)"
              :label="selectedRequest.status"
              class="q-pa-sm"
            />
          </div>
          <div class="col-4">
            <div class="detail-label">Requested By</div>
            <div class="detail-value">{{ selectedRequest.requester?.full_name }}</div>
          </div>
          <div class="col-4">
            <div class="detail-label">Need Date</div>
            <div class="detail-value">{{ selectedRequest.need_date }}</div>
          </div>
        </div>

        <SAPTable
          :rows="selectedRequest.stock_request_lines || []"
          :columns="viewLineColumns"
          :show-search="false"
          row-key="id"
          dense
        >
          <template #body-cell-item_code="props">
            <q-td :props="props">
              <span class="text-bold">{{ props.value }}</span>
              <GoldenArrow @click="goToItem(props.row.item_id)" />
            </q-td>
          </template>
        </SAPTable>

        <!-- Action Buttons -->
        <div class="q-mt-md text-right">
          <template v-if="selectedRequest.status === 'Pending'">
            <q-btn
              flat
              color="negative"
              label="Reject"
              icon="close"
              class="q-mr-sm"
              @click="rejectRequest"
            />
            <q-btn color="positive" label="Approve" icon="check" @click="confirmApproval" />
          </template>
          <template v-else-if="selectedRequest.status === 'Approved'">
            <q-btn
              color="primary"
              label="Issue Items (GIN)"
              icon="local_shipping"
              @click="issueRequest(selectedRequest)"
            />
          </template>
        </div>
      </template>
    </SAPDialog>

    <!-- Issue Dialog -->
    <SAPDialog
      v-model="showIssueDialog"
      title="Good Issue Note"
      icon="local_shipping"
      width="900px"
      :loading="issuingItems"
      confirm-label="Confirm Issue"
      @confirm="confirmIssue"
    >
      <template v-if="issueRequest">
        <div class="row q-col-gutter-md q-mb-md">
          <div class="col-6">
            <div class="detail-label">Request #</div>
            <div class="detail-value">{{ issueData?.doc_number }}</div>
          </div>
          <div class="col-6">
            <SAPSelect
              v-model="issueForm.issued_by"
              label="Issued Person"
              :options="users"
              option-label="full_name"
              option-value="id"
            />
          </div>
        </div>

        <q-table
          :rows="issueLines"
          :columns="issueLineColumns"
          row-key="id"
          flat
          bordered
          dense
          hide-pagination
        >
          <template #body-cell-issue_qty="props">
            <q-td :props="props">
              <q-input
                v-model.number="props.row.issue_quantity"
                type="number"
                dense
                outlined
                min="0"
                :max="props.row.approved_quantity"
                style="width: 80px"
              />
            </q-td>
          </template>
        </q-table>

        <div class="q-mt-md">
          <SAPInput v-model="issueForm.remarks" label="Remark" />
          <q-checkbox
            v-model="issueForm.gin_confirmation"
            label="GIN Confirmation"
            color="positive"
            class="q-mt-sm"
          />
        </div>
      </template>
    </SAPDialog>
  </q-page>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useQuasar } from 'quasar'
import { useRouter } from 'vue-router'
import { supabase } from 'src/boot/supabase'
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
const loading = ref(false)
const saving = ref(false)
const stockRequests = ref([])
const statusFilter = ref('all')
const showCreateDialog = ref(false)
const showViewDialog = ref(false)
const showIssueDialog = ref(false)
const formRef = ref(null)
const selectedRequest = ref(null)
const selectedItem = ref(null)
const searchResults = ref([])
const searchLoading = ref(false)
const requestLines = ref([])
const users = ref([])
const issuingItems = ref(false)
const issueData = ref(null)
const issueLines = ref([])

const form = ref({
  from_warehouse_id: null,
  need_date: new Date().toISOString().split('T')[0],
  remarks: '',
})

const issueForm = ref({
  issued_by: null,
  remarks: '',
  gin_confirmation: false,
})

const requiredRules = [(val) => !!val || 'Required']

// Computed
const pendingCount = computed(
  () => stockRequests.value.filter((r) => r.status === 'Pending').length,
)
const approvedCount = computed(
  () => stockRequests.value.filter((r) => r.status === 'Approved').length,
)
const issuedCount = computed(() => stockRequests.value.filter((r) => r.status === 'Issued').length)

const filteredRequests = computed(() => {
  if (statusFilter.value === 'all') return stockRequests.value
  return stockRequests.value.filter((r) => r.status === statusFilter.value)
})

// Columns
const columns = [
  { name: 'doc_number', label: 'Request No.', field: 'doc_number', sortable: true, align: 'left' },
  { name: 'need_date', label: 'Need Date', field: 'need_date', sortable: true, align: 'left' },
  {
    name: 'requester',
    label: 'Requested By',
    field: (row) => row.requester?.full_name,
    align: 'left',
  },
  {
    name: 'warehouse',
    label: 'Warehouse',
    field: (row) => row.from_warehouse?.name,
    align: 'left',
  },
  { name: 'status', label: 'Status', field: 'status', align: 'center' },
  { name: 'actions', label: 'Actions', align: 'center' },
]

const lineColumns = [
  { name: 'item_name', label: 'Item Name', align: 'left' },
  { name: 'item_code', label: 'Item Code', align: 'left' },
  { name: 'stock', label: 'Stock', align: 'center' },
  { name: 'r_qty', label: 'R.Qty', align: 'center' },
  { name: 'confirmation', label: 'Confirmation', align: 'center' },
  { name: 'actions', label: '', align: 'center' },
]

const viewLineColumns = [
  { name: 'item_code', label: 'Item Code', field: 'item_code', align: 'left' },
  { name: 'item_name', label: 'Item Name', field: (row) => row.item?.item_name, align: 'left' },
  { name: 'requested', label: 'Requested', field: 'requested_quantity', align: 'right' },
  { name: 'approved', label: 'Approved', field: 'approved_quantity', align: 'right' },
  { name: 'issued', label: 'Issued', field: 'issued_quantity', align: 'right' },
]

const issueLineColumns = [
  { name: 'item_code', label: 'Item Code', field: 'item_code', align: 'left' },
  { name: 'item_name', label: 'Item Name', field: (row) => row.item?.item_name, align: 'left' },
  { name: 'approved', label: 'Approved Qty', field: 'approved_quantity', align: 'right' },
  { name: 'issue_qty', label: 'Issue Qty', align: 'center' },
]

// Methods
function getStatusColor(status) {
  const colors = {
    Pending: 'warning',
    Approved: 'positive',
    Rejected: 'negative',
    Issued: 'info',
    Cancelled: 'grey',
  }
  return colors[status] || 'grey'
}

async function loadData() {
  loading.value = true
  try {
    await Promise.all([
      stockStore.fetchWarehouses(),
      stockStore.fetchItems(),
      loadStockRequests(),
      loadUsers(),
    ])
  } finally {
    loading.value = false
  }
}

async function loadStockRequests() {
  const { data, error } = await supabase
    .from('stock_requests')
    .select(
      `
      *,
      requester:profiles!requester_id(full_name),
      from_warehouse:warehouses!from_warehouse_id(name),
      approved_by_user:profiles!approved_by(full_name),
      stock_request_lines(
        *, item:items(item_code, item_name)
      )
    `,
    )
    .order('created_at', { ascending: false })

  if (!error) {
    stockRequests.value = data || []
  }
}

async function loadUsers() {
  const { data } = await supabase.from('profiles').select('id, full_name')
  users.value = data || []
}

function openCreateDialog() {
  form.value = {
    from_warehouse_id: stockStore.warehouses[0]?.id || null,
    need_date: new Date().toISOString().split('T')[0],
    remarks: '',
  }
  requestLines.value = []
  showCreateDialog.value = true
}

async function onItemSearch(val, update) {
  if (val.length < 2) {
    update(() => {
      searchResults.value = []
    })
    return
  }

  searchLoading.value = true
  try {
    const { data } = await supabase
      .from('items')
      .select(
        `
        id, item_code, item_name, base_uom_id,
        warehouse_stock(warehouse_id, quantity_on_hand, quantity_committed, quantity_ordered)
      `,
      )
      .or(`item_name.ilike.%${val}%,item_code.ilike.%${val}%`)
      .eq('is_active', true)
      .limit(20)

    update(() => {
      searchResults.value = (data || []).map((item) => {
        const stock = item.warehouse_stock?.find(
          (ws) => ws.warehouse_id === form.value.from_warehouse_id,
        )
        return {
          ...item,
          available: stock
            ? stock.quantity_on_hand - stock.quantity_committed + stock.quantity_ordered
            : 0,
        }
      })
    })
  } finally {
    searchLoading.value = false
  }
}

function addItemToRequest(item) {
  if (!item) return

  // Check if already added
  if (requestLines.value.find((l) => l.item_id === item.id)) {
    $q.notify({ type: 'warning', message: 'Item already added' })
    selectedItem.value = null
    return
  }

  requestLines.value.push({
    lineNum: requestLines.value.length + 1,
    item_id: item.id,
    item_code: item.item_code,
    item_name: item.item_name,
    available: item.available,
    requested_quantity: 1,
    confirmation: false,
    uom_id: item.base_uom_id,
  })

  selectedItem.value = null
}

function removeLine(index) {
  requestLines.value.splice(index, 1)
}

async function submitRequest() {
  const valid = await formRef.value.validate()
  if (!valid) return

  const confirmedLines = requestLines.value.filter((l) => l.confirmation)
  if (confirmedLines.length === 0) {
    $q.notify({ type: 'warning', message: 'Please confirm at least one item' })
    return
  }

  saving.value = true
  try {
    // Generate doc number
    const { data: docNum } = await supabase.rpc('generate_stock_request_number')

    // Create header
    const { data: request, error: headerError } = await supabase
      .from('stock_requests')
      .insert({
        doc_number: docNum,
        requester_id: authStore.profile?.id,
        from_warehouse_id: form.value.from_warehouse_id,
        need_date: form.value.need_date,
        remarks: form.value.remarks,
        status: 'Pending',
      })
      .select()
      .single()

    if (headerError) throw headerError

    // Create lines
    const lines = confirmedLines.map((l, idx) => ({
      request_id: request.id,
      line_num: idx + 1,
      item_id: l.item_id,
      item_code: l.item_code,
      requested_quantity: l.requested_quantity,
      available_stock: l.available,
      uom_id: l.uom_id,
      confirmation: true,
    }))

    await supabase.from('stock_request_lines').insert(lines)

    $q.notify({ type: 'positive', message: 'Request created successfully' })
    showCreateDialog.value = false
    loadStockRequests()
  } catch (error) {
    $q.notify({ type: 'negative', message: error.message })
  } finally {
    saving.value = false
  }
}

function viewRequest(row) {
  selectedRequest.value = row
  showViewDialog.value = true
}

async function approveRequest(row) {
  selectedRequest.value = row
  showViewDialog.value = true
}

async function confirmApproval() {
  const { error } = await supabase
    .from('stock_requests')
    .update({
      status: 'Approved',
      approved_by: authStore.profile?.id,
    })
    .eq('id', selectedRequest.value.id)

  if (!error) {
    $q.notify({ type: 'positive', message: 'Request approved' })
    showViewDialog.value = false
    loadStockRequests()
  }
}

async function rejectRequest() {
  $q.dialog({
    title: 'Reject Request',
    message: 'Enter rejection reason:',
    prompt: { model: '', type: 'text' },
    cancel: true,
  }).onOk(async (reason) => {
    await supabase
      .from('stock_requests')
      .update({
        status: 'Rejected',
        rejected_reason: reason,
        approved_by: authStore.profile?.id,
      })
      .eq('id', selectedRequest.value.id)

    $q.notify({ type: 'info', message: 'Request rejected' })
    showViewDialog.value = false
    loadStockRequests()
  })
}

function issueRequest(row) {
  issueData.value = row
  issueLines.value = (row.stock_request_lines || []).map((l) => ({
    ...l,
    issue_quantity: l.approved_quantity || l.requested_quantity,
  }))
  issueForm.value = {
    issued_by: authStore.profile?.id,
    remarks: '',
    gin_confirmation: false,
  }
  showViewDialog.value = false
  showIssueDialog.value = true
}

async function confirmIssue() {
  if (!issueForm.value.gin_confirmation) {
    $q.notify({ type: 'warning', message: 'Please confirm GIN' })
    return
  }

  issuingItems.value = true
  try {
    // Update request status
    await supabase
      .from('stock_requests')
      .update({
        status: 'Issued',
        issued_by: issueForm.value.issued_by,
        issued_at: new Date().toISOString(),
      })
      .eq('id', issueData.value.id)

    // Update line issued quantities
    for (const line of issueLines.value) {
      await supabase
        .from('stock_request_lines')
        .update({ issued_quantity: line.issue_quantity })
        .eq('id', line.id)

      // Deduct stock
      await supabase.rpc('update_warehouse_stock', {
        p_item_id: line.item_id,
        p_warehouse_id: issueData.value.from_warehouse_id,
        p_quantity: -line.issue_quantity,
        p_transaction_type: 'STOCK_ISSUE',
        p_doc_number: issueData.value.doc_number,
      })
    }

    $q.notify({ type: 'positive', message: 'Items issued successfully' })
    showIssueDialog.value = false
    loadStockRequests()
  } catch (error) {
    $q.notify({ type: 'negative', message: error.message })
  } finally {
    issuingItems.value = false
  }
}

function goToItem(itemId) {
  router.push({ path: '/stock/items', query: { id: itemId } })
}

onMounted(() => {
  loadData()
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
  padding: 12px;
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

.section-header {
  font-size: 14px;
  font-weight: 600;
  color: #333;
  display: flex;
  align-items: center;
  padding: 8px;
  background: #f0f4f8;
  border-radius: 4px;
}

.search-input {
  :deep(.q-field__control) {
    background: #fff;
    border-radius: 8px;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.08);
  }
}

.search-option {
  border-bottom: 1px solid #eee;
}

.stock-badge {
  min-width: 40px;
  justify-content: center;
}

.lines-table {
  :deep(th),
  :deep(td) {
    font-size: 12px;
    padding: 8px;
  }
}

.detail-label {
  font-size: 11px;
  color: #666;
  margin-bottom: 4px;
}

.detail-value {
  font-size: 14px;
  font-weight: 500;
}

.actions-cell {
  white-space: nowrap;
}
</style>
