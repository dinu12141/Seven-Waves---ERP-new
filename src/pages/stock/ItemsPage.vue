<template>
  <q-page class="sap-page">
    <!-- Toolbar -->
    <SAPToolbar
      title="Item Master Data"
      icon="inventory_2"
      :badge="stockStore.items.length"
      add-label="New Item"
      :show-export="true"
      :show-filter="true"
      @add="openCreateDialog"
      @refresh="loadData"
      @export="exportItems"
      @filter="showFilterDialog = true"
    />

    <!-- Main Content -->
    <div class="sap-page-content">
      <!-- Stats Cards -->
      <div class="row q-col-gutter-md q-mb-md">
        <div class="col-12 col-md-3">
          <SAPCard flat bordered>
            <div class="stat-card">
              <q-icon name="inventory_2" size="32px" color="primary" />
              <div class="stat-info">
                <div class="stat-value">{{ stockStore.items.length }}</div>
                <div class="stat-label">Total Items</div>
              </div>
            </div>
          </SAPCard>
        </div>
        <div class="col-12 col-md-3">
          <SAPCard flat bordered>
            <div class="stat-card">
              <q-icon name="check_circle" size="32px" color="positive" />
              <div class="stat-info">
                <div class="stat-value">{{ stockStore.activeItems.length }}</div>
                <div class="stat-label">Active Items</div>
              </div>
            </div>
          </SAPCard>
        </div>
        <div class="col-12 col-md-3">
          <SAPCard flat bordered>
            <div class="stat-card">
              <q-icon name="warning" size="32px" color="warning" />
              <div class="stat-info">
                <div class="stat-value">{{ lowStockItems.length }}</div>
                <div class="stat-label">Low Stock</div>
              </div>
            </div>
          </SAPCard>
        </div>
        <div class="col-12 col-md-3">
          <SAPCard flat bordered>
            <div class="stat-card">
              <q-icon name="category" size="32px" color="accent" />
              <div class="stat-info">
                <div class="stat-value">{{ stockStore.categories.length }}</div>
                <div class="stat-label">Categories</div>
              </div>
            </div>
          </SAPCard>
        </div>
      </div>

      <!-- Items Table -->
      <SAPCard title="Items List" icon="list" no-padding>
        <template #header-right>
          <q-btn-toggle
            v-model="viewMode"
            dense
            flat
            :options="[
              { value: 'all', label: 'All' },
              { value: 'active', label: 'Active' },
              { value: 'inactive', label: 'Inactive' },
            ]"
            toggle-color="primary"
            class="view-toggle"
          />
        </template>

        <SAPTable
          :rows="filteredItems"
          :columns="columns"
          :loading="stockStore.loading"
          :show-drill-down="true"
          row-key="id"
          @row-click="viewItem"
          @drill-down="viewItem"
        >
          <!-- Item Code Column -->
          <template #body-cell-item_code="props">
            <q-td :props="props">
              <div class="row items-center no-wrap">
                <span class="text-bold">{{ props.value }}</span>
                <GoldenArrow @click="viewItem(props.row)" />
              </div>
            </q-td>
          </template>

          <!-- Available Stock Column -->
          <template #body-cell-available="props">
            <q-td :props="props" class="text-right">
              <span :class="getStockClass(props.row)">
                {{ formatNumber(getStockInfo(props.row).available) }}
              </span>
            </q-td>
          </template>

          <!-- In Stock Column -->
          <template #body-cell-in_stock="props">
            <q-td :props="props" class="text-right text-grey-8">
              {{ formatNumber(getStockInfo(props.row).inStock) }}
            </q-td>
          </template>

          <!-- Price Column -->
          <template #body-cell-purchase_price="props">
            <q-td :props="props" class="text-right">
              {{ formatCurrency(props.value) }}
            </q-td>
          </template>

          <!-- Status Column -->
          <template #body-cell-is_active="props">
            <q-td :props="props" class="text-center">
              <q-badge
                :color="props.value ? 'positive' : 'grey'"
                :label="props.value ? 'Active' : 'Inactive'"
                class="status-badge"
              />
            </q-td>
          </template>

          <!-- Actions Column -->
          <template #body-cell-actions="props">
            <q-td :props="props" class="actions-cell">
              <q-btn
                flat
                dense
                round
                size="sm"
                icon="edit"
                color="primary"
                @click.stop="editItem(props.row)"
              >
                <q-tooltip>Edit</q-tooltip>
              </q-btn>
              <q-btn
                flat
                dense
                round
                size="sm"
                icon="visibility"
                color="info"
                @click.stop="viewItem(props.row)"
              >
                <q-tooltip>View Details</q-tooltip>
              </q-btn>
              <q-btn
                flat
                dense
                round
                size="sm"
                icon="delete"
                color="negative"
                @click.stop="confirmDelete(props.row)"
              >
                <q-tooltip>Delete</q-tooltip>
              </q-btn>
            </q-td>
          </template>
        </SAPTable>
      </SAPCard>
    </div>

    <!-- Create/Edit Item Dialog -->
    <SAPDialog
      v-model="showItemDialog"
      :title="isEditing ? 'Edit Item' : 'Create New Item'"
      icon="inventory_2"
      width="800px"
      :loading="saving"
      :confirm-label="isEditing ? 'Update' : 'Create'"
      @confirm="submitForm"
    >
      <q-form ref="itemFormRef" @submit.prevent="saveItem">
        <div class="row q-col-gutter-md" @keydown.enter.prevent="onEnterKey">
          <!-- Basic Info -->
          <div class="col-12">
            <div class="section-title">Basic Information</div>
          </div>

          <div class="col-12 col-md-4">
            <SAPInput
              v-model="itemForm.item_code"
              label="Item Code"
              placeholder="e.g., ITM001"
              required
              :rules="requiredRules"
            />
          </div>

          <div class="col-12 col-md-8">
            <SAPInput
              v-model="itemForm.item_name"
              label="Item Name"
              placeholder="Item name"
              required
              :rules="requiredRules"
            />
          </div>

          <div class="col-12 col-md-6">
            <label class="sap-label">Category</label>
            <SAPSelect
              v-model="itemForm.category_id"
              :options="stockStore.categories"
              option-label="name"
              option-value="id"
              placeholder="Select category"
              searchable
              :rules="requiredRules"
            />
          </div>

          <div class="col-12 col-md-6">
            <label class="sap-label required">Base Unit of Measure</label>
            <SAPSelect
              v-model="itemForm.base_uom_id"
              :options="stockStore.unitsOfMeasure"
              option-label="name"
              option-value="id"
              placeholder="Select UoM"
              searchable
              :rules="requiredRules"
            />
          </div>

          <!-- Pricing -->
          <div class="col-12">
            <div class="section-title q-mt-md">Pricing</div>
          </div>

          <div class="col-12 col-md-6">
            <SAPInput
              v-model.number="itemForm.purchase_price"
              label="Purchase Price"
              type="number"
              step="0.01"
              min="0"
            />
          </div>

          <div class="col-12 col-md-6">
            <SAPInput
              v-model.number="itemForm.selling_price"
              label="Selling Price"
              type="number"
              step="0.01"
              min="0"
            />
          </div>

          <!-- Stock Control -->
          <div class="col-12">
            <div class="section-title q-mt-md">Stock Control</div>
          </div>

          <div class="col-12 col-md-3">
            <SAPInput
              v-model.number="itemForm.min_stock_level"
              label="Min Stock"
              type="number"
              min="0"
            />
          </div>

          <div class="col-12 col-md-3">
            <SAPInput
              v-model.number="itemForm.max_stock_level"
              label="Max Stock"
              type="number"
              min="0"
            />
          </div>

          <div class="col-12 col-md-3">
            <SAPInput
              v-model.number="itemForm.reorder_point"
              label="Reorder Point"
              type="number"
              min="0"
            />
          </div>

          <div class="col-12 col-md-3">
            <SAPInput
              v-model.number="itemForm.reorder_quantity"
              label="Reorder Qty"
              type="number"
              min="0"
            />
          </div>

          <!-- Opening Stock (Only for Create) -->
          <div class="col-12" v-if="!isEditing">
            <div class="section-title q-mt-md">Opening Stock</div>
          </div>

          <div class="col-12 col-md-6" v-if="!isEditing">
            <SAPInput
              v-model.number="itemForm.opening_stock"
              label="Opening Stock Quantity"
              type="number"
              min="0"
              placeholder="0"
            />
          </div>

          <div class="col-12 col-md-6" v-if="!isEditing">
            <label class="sap-label" :class="{ required: itemForm.opening_stock > 0 }">
              Warehouse
            </label>
            <SAPSelect
              v-model="itemForm.opening_stock_warehouse_id"
              :options="stockStore.activeWarehouses"
              option-label="name"
              option-value="id"
              placeholder="Select warehouse"
              :rules="itemForm.opening_stock > 0 ? requiredRules : []"
            />
          </div>

          <!-- Defaults -->
          <div class="col-12">
            <div class="section-title q-mt-md">Defaults</div>
          </div>

          <div class="col-12 col-md-6">
            <label class="sap-label">Default Warehouse</label>
            <SAPSelect
              v-model="itemForm.default_warehouse_id"
              :options="stockStore.warehouses"
              option-label="name"
              option-value="id"
              placeholder="Select warehouse"
            />
          </div>

          <div class="col-12 col-md-6">
            <label class="sap-label">Default Supplier</label>
            <SAPSelect
              v-model="itemForm.default_supplier_id"
              :options="stockStore.suppliers"
              option-label="name"
              option-value="id"
              placeholder="Select supplier"
              searchable
            />
          </div>

          <!-- Description -->
          <div class="col-12">
            <SAPInput v-model="itemForm.description" label="Description" type="textarea" rows="2" />
          </div>

          <!-- Flags -->
          <div class="col-12">
            <div class="row q-gutter-md">
              <q-checkbox v-model="itemForm.is_active" label="Active" dense />
              <q-checkbox v-model="itemForm.is_purchase_item" label="Purchase Item" dense />
              <q-checkbox v-model="itemForm.is_sales_item" label="Sales Item" dense />
            </div>
          </div>
        </div>
      </q-form>
    </SAPDialog>

    <!-- View Item Dialog -->
    <SAPDialog
      v-model="showViewDialog"
      :title="selectedItem?.item_name || 'Item Details'"
      icon="inventory_2"
      width="900px"
      :show-default-footer="false"
    >
      <template v-if="selectedItem">
        <q-tabs v-model="detailTab" dense class="text-grey" active-color="primary">
          <q-tab name="info" label="Basic Info" icon="info" />
          <q-tab name="stock" label="Warehouse Stock" icon="warehouse" />
          <q-tab name="uom" label="Units of Measure" icon="straighten" />
          <q-tab name="history" label="Transaction History" icon="history" />
        </q-tabs>

        <q-separator />

        <q-tab-panels v-model="detailTab" animated class="detail-panels">
          <!-- Basic Info Tab -->
          <q-tab-panel name="info">
            <div class="row q-col-gutter-md">
              <div class="col-6">
                <div class="detail-row">
                  <span class="detail-label">Item Code:</span>
                  <span class="detail-value">{{ selectedItem.item_code }}</span>
                </div>
                <div class="detail-row">
                  <span class="detail-label">Item Name:</span>
                  <span class="detail-value">{{ selectedItem.item_name }}</span>
                </div>
                <div class="detail-row">
                  <span class="detail-label">Category:</span>
                  <span class="detail-value">{{ selectedItem.category?.name || '—' }}</span>
                </div>
                <div class="detail-row">
                  <span class="detail-label">Base UoM:</span>
                  <span class="detail-value"
                    >{{ selectedItem.base_uom?.name }} ({{ selectedItem.base_uom?.code }})</span
                  >
                </div>
              </div>
              <div class="col-6">
                <div class="detail-row">
                  <span class="detail-label">Purchase Price:</span>
                  <span class="detail-value">{{
                    formatCurrency(selectedItem.purchase_price)
                  }}</span>
                </div>
                <div class="detail-row">
                  <span class="detail-label">Selling Price:</span>
                  <span class="detail-value">{{ formatCurrency(selectedItem.selling_price) }}</span>
                </div>
                <div class="detail-row">
                  <span class="detail-label">Status:</span>
                  <q-badge :color="selectedItem.is_active ? 'positive' : 'grey'">
                    {{ selectedItem.is_active ? 'Active' : 'Inactive' }}
                  </q-badge>
                </div>
              </div>
            </div>
          </q-tab-panel>

          <!-- Warehouse Stock Tab -->
          <q-tab-panel name="stock">
            <SAPTable
              :rows="selectedItem.warehouse_stock || []"
              :columns="stockColumns"
              :show-search="false"
              :show-count="false"
              row-key="id"
            >
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
            </SAPTable>
          </q-tab-panel>

          <!-- UoM Tab -->
          <q-tab-panel name="uom">
            <SAPTable
              :rows="selectedItem.item_uom || []"
              :columns="uomColumns"
              :show-search="false"
              row-key="id"
            />
          </q-tab-panel>

          <!-- History Tab -->
          <q-tab-panel name="history">
            <SAPTable
              :rows="stockStore.stockTransactions"
              :columns="historyColumns"
              :loading="loadingHistory"
              :show-search="false"
              row-key="id"
            />
          </q-tab-panel>
        </q-tab-panels>
      </template>
    </SAPDialog>

    <!-- Delete Confirmation -->
    <q-dialog v-model="showDeleteConfirm">
      <q-card style="min-width: 350px">
        <q-card-section class="row items-center">
          <q-icon name="warning" color="negative" size="32px" class="q-mr-md" />
          <span class="text-body1">Delete this item?</span>
        </q-card-section>
        <q-card-section class="q-pt-none">
          <strong>{{ itemToDelete?.item_code }}</strong> - {{ itemToDelete?.item_name }}
        </q-card-section>
        <q-card-actions align="right">
          <q-btn flat label="Cancel" v-close-popup />
          <q-btn flat color="negative" label="Delete" @click="deleteItem" :loading="deleting" />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { useQuasar } from 'quasar'
import { useRoute } from 'vue-router'
import { useStockStore } from 'src/stores/stockStore'
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
const stockStore = useStockStore()

// State
const viewMode = ref('all')
const showItemDialog = ref(false)
const showViewDialog = ref(false)
const showFilterDialog = ref(false)
const showDeleteConfirm = ref(false)
const isEditing = ref(false)
const saving = ref(false)
const deleting = ref(false)
const loadingHistory = ref(false)
const detailTab = ref('info')
const itemFormRef = ref(null)
const itemForm = ref(getEmptyForm())
const selectedItem = ref(null)
const itemToDelete = ref(null)

// Columns
const columns = [
  {
    name: 'item_code',
    label: 'Item No.',
    field: 'item_code',
    sortable: true,
    align: 'left',
    style: 'width: 150px',
  },
  { name: 'item_name', label: 'Description', field: 'item_name', sortable: true, align: 'left' },
  {
    name: 'category',
    label: 'Category',
    field: (row) => row.category?.name || '—',
    sortable: true,
    align: 'left',
  },
  {
    name: 'base_uom',
    label: 'UoM',
    field: (row) => row.base_uom?.code,
    sortable: true,
    align: 'center',
  },
  {
    name: 'in_stock',
    label: 'In Stock',
    field: (row) => getStockInfo(row).inStock,
    sortable: true,
    align: 'right',
  },
  {
    name: 'committed',
    label: 'Committed',
    field: (row) => getStockInfo(row).committed,
    sortable: true,
    align: 'right',
  },
  {
    name: 'ordered',
    label: 'Ordered',
    field: (row) => getStockInfo(row).ordered,
    sortable: true,
    align: 'right',
  },
  {
    name: 'available',
    label: 'Available',
    field: (row) => getStockInfo(row).available,
    sortable: true,
    align: 'right',
    classes: 'text-bold',
  },
  {
    name: 'purchase_price',
    label: 'Item Cost',
    field: 'purchase_price',
    sortable: true,
    align: 'right',
  },
  { name: 'is_active', label: 'Active', field: 'is_active', sortable: true, align: 'center' },
  { name: 'actions', label: 'Actions', field: 'actions', align: 'center' },
]

const stockColumns = [
  { name: 'warehouse', label: 'Warehouse', field: (row) => row.warehouse?.name, align: 'left' },
  { name: 'quantity_on_hand', label: 'On Hand', field: 'quantity_on_hand', align: 'right' },
  { name: 'quantity_committed', label: 'Committed', field: 'quantity_committed', align: 'right' },
  { name: 'quantity_ordered', label: 'Ordered', field: 'quantity_ordered', align: 'right' },
  { name: 'average_cost', label: 'Avg Cost', field: 'average_cost', align: 'right' },
]

const uomColumns = [
  { name: 'uom', label: 'Unit', field: (row) => row.uom?.name, align: 'left' },
  { name: 'code', label: 'Code', field: (row) => row.uom?.code, align: 'center' },
  {
    name: 'conversion_factor',
    label: 'Conversion Factor',
    field: 'conversion_factor',
    align: 'right',
  },
  {
    name: 'is_default_purchase',
    label: 'Default Purchase',
    field: 'is_default_purchase',
    align: 'center',
  },
  { name: 'is_default_sales', label: 'Default Sales', field: 'is_default_sales', align: 'center' },
]

const historyColumns = [
  { name: 'date', label: 'Date', field: (row) => formatDate(row.transaction_date), align: 'left' },
  { name: 'type', label: 'Type', field: 'transaction_type', align: 'center' },
  { name: 'doc', label: 'Document', field: 'doc_number', align: 'left' },
  { name: 'warehouse', label: 'Warehouse', field: (row) => row.warehouse?.name, align: 'left' },
  { name: 'quantity', label: 'Qty', field: 'quantity', align: 'right' },
  { name: 'balance', label: 'Balance After', field: 'balance_after', align: 'right' },
]

// Rules
const requiredRules = [(val) => !!val || 'Required']

// Computed
const filteredItems = computed(() => {
  let items = stockStore.items
  if (viewMode.value === 'active') {
    items = items.filter((i) => i.is_active)
  } else if (viewMode.value === 'inactive') {
    items = items.filter((i) => !i.is_active)
  }
  return items
})

const lowStockItems = computed(() => {
  return stockStore.items.filter((item) => {
    const total = getTotalStock(item)
    return total > 0 && total <= (item.reorder_point || 0)
  })
})

// Methods
function getEmptyForm() {
  return {
    item_code: '',
    item_name: '',
    category_id: null,
    base_uom_id: null,
    purchase_price: 0,
    selling_price: 0,
    min_stock_level: 0,
    max_stock_level: 0,
    reorder_point: 0,
    reorder_quantity: 0,
    opening_stock: 0,
    opening_stock_warehouse_id: null,
    default_warehouse_id: null,
    default_supplier_id: null,
    description: '',
    is_active: true,
    is_purchase_item: true,
    is_sales_item: true,
  }
}

function getStockInfo(item) {
  if (!item.warehouse_stock) return { inStock: 0, committed: 0, ordered: 0, available: 0 }

  const inStock = item.warehouse_stock.reduce((sum, ws) => sum + (ws.quantity_on_hand || 0), 0)
  const committed = item.warehouse_stock.reduce((sum, ws) => sum + (ws.quantity_committed || 0), 0)
  const ordered = item.warehouse_stock.reduce((sum, ws) => sum + (ws.quantity_ordered || 0), 0)

  // SAP Formula: Available = In Stock - Committed + Ordered
  const available = inStock - committed + ordered

  return { inStock, committed, ordered, available }
}

function getTotalStock(item) {
  return getStockInfo(item).inStock
}

function getStockClass(item) {
  const { available } = getStockInfo(item)
  if (available <= 0) return 'text-negative text-bold'
  if (available <= (item.reorder_point || 0)) return 'text-warning text-bold'
  return 'text-positive text-bold'
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
  return new Date(date).toLocaleString()
}

async function loadData() {
  await stockStore.initializeStore()
}

function submitForm() {
  if (!itemFormRef.value) return

  itemFormRef.value.validate().then((success) => {
    if (success) {
      saveItem()
    } else {
      $q.notify({
        type: 'warning',
        message: 'Please fill in required fields',
        position: 'top',
      })
    }
  })
}

function onEnterKey() {
  // Prevent double submission if focus is on a button or something that handles enter natively differently
  // defaulting to submit form
  submitForm()
}

function openCreateDialog() {
  isEditing.value = false
  itemForm.value = getEmptyForm()
  showItemDialog.value = true
}

function editItem(item) {
  isEditing.value = true
  itemForm.value = {
    item_code: item.item_code,
    item_name: item.item_name,
    category_id: item.category_id,
    base_uom_id: item.base_uom_id,
    purchase_price: item.purchase_price,
    selling_price: item.selling_price,
    min_stock_level: item.min_stock_level,
    max_stock_level: item.max_stock_level,
    reorder_point: item.reorder_point,
    reorder_quantity: item.reorder_quantity,
    default_warehouse_id: item.default_warehouse_id,
    default_supplier_id: item.default_supplier_id,
    description: item.description,
    is_active: item.is_active,
    is_purchase_item: item.is_purchase_item,
    is_sales_item: item.is_sales_item,
    id: item.id,
  }
  showItemDialog.value = true
}

async function viewItem(item) {
  selectedItem.value = item
  detailTab.value = 'info'
  showViewDialog.value = true

  // Load transaction history
  loadingHistory.value = true
  await stockStore.fetchStockTransactions({ item_id: item.id })
  loadingHistory.value = false
}

async function saveItem() {
  saving.value = true
  try {
    let result
    if (isEditing.value) {
      const { id, ...updates } = itemForm.value
      result = await stockStore.updateItem(id, updates)
    } else {
      result = await stockStore.createItem(itemForm.value)
    }

    if (result.success) {
      $q.notify({
        type: 'positive',
        message: isEditing.value ? 'Item updated successfully' : 'Item created successfully',
      })
      showItemDialog.value = false
    } else {
      $q.notify({ type: 'negative', message: result.error })
    }
  } finally {
    saving.value = false
  }
}

function confirmDelete(item) {
  itemToDelete.value = item
  showDeleteConfirm.value = true
}

async function deleteItem() {
  deleting.value = true
  try {
    const result = await stockStore.deleteItem(itemToDelete.value.id)
    if (result.success) {
      $q.notify({ type: 'positive', message: 'Item deleted successfully' })
      showDeleteConfirm.value = false
    } else {
      $q.notify({ type: 'negative', message: result.error })
    }
  } finally {
    deleting.value = false
  }
}

function exportItems() {
  // TODO: Implement CSV export
  $q.notify({ type: 'info', message: 'Export feature coming soon' })
}

// Keyboard Shortcuts
function handleKeydown(e) {
  // Ctrl + A: Add Record
  if (e.ctrlKey && e.key === 'a') {
    e.preventDefault()
    openCreateDialog()
  }
  // Ctrl + F: Find/Filter
  if (e.ctrlKey && e.key === 'f') {
    e.preventDefault()
    showFilterDialog.value = !showFilterDialog.value
  }
  // Esc: Close Dialogs
  if (e.key === 'Escape') {
    showItemDialog.value = false
    showViewDialog.value = false
    showFilterDialog.value = false
  }
}

// Lifecycle
onMounted(async () => {
  window.addEventListener('keydown', handleKeydown)
  await loadData()

  // Check for deep link
  if (route.query.id) {
    const item = stockStore.items.find((i) => i.id === route.query.id)
    if (item) {
      viewItem(item)
    }
  }
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
  gap: 16px;
  padding: 8px;
}

.stat-info {
  flex: 1;
}

.stat-value {
  font-size: 24px;
  font-weight: 700;
  color: #333;
}

.stat-label {
  font-size: 12px;
  color: #666;
}

.view-toggle {
  :deep(.q-btn) {
    font-size: 11px;
    padding: 4px 12px;
  }
}

.item-code {
  font-family: 'Consolas', monospace;
  font-weight: 600;
  color: $primary;
}

.status-badge {
  font-size: 10px;
  padding: 2px 8px;
}

.actions-cell {
  width: 120px;
}

.section-title {
  font-size: 13px;
  font-weight: 600;
  color: #333;
  padding-bottom: 8px;
  border-bottom: 1px solid #eee;
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

.detail-panels {
  min-height: 300px;
}

.detail-row {
  display: flex;
  padding: 8px 0;
  border-bottom: 1px solid #f0f0f0;
}

.detail-label {
  width: 140px;
  font-size: 12px;
  color: #666;
}

.detail-value {
  flex: 1;
  font-size: 12px;
  font-weight: 500;
  color: #333;
}
</style>
