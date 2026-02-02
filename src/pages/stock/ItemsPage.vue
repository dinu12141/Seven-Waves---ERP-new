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
      <!-- Items Grid (SAP Style List) -->
      <SAPCard title="Items List" icon="list" no-padding>
        <template #header-right>
          <div class="row q-gutter-sm items-center">
            <q-btn-toggle
              v-model="stockViewMode"
              dense
              flat
              rounded
              :options="[
                { value: 'list', icon: 'list', slot: 'list' },
                { value: 'kanban', icon: 'grid_view', slot: 'kanban' },
              ]"
            />
          </div>
        </template>

        <SAPTable
          :rows="filteredItems"
          :columns="columns"
          :loading="stockStore.loading"
          :show-drill-down="true"
          row-key="id"
          sticky-header
          height="calc(100vh - 250px)"
          @row-click="viewItem"
          @drill-down="viewItem"
        >
          <!-- Item Code & Name -->
          <template #body-cell-item_code="props">
            <q-td :props="props">
              <div class="row items-center no-wrap">
                <span class="text-bold text-primary">{{ props.value }}</span>
                <GoldenArrow @click="viewItem(props.row)" />
              </div>
            </q-td>
          </template>

          <template #body-cell-item_types="props">
            <q-td :props="props" class="text-center">
              <div class="row inline q-gutter-xs">
                <q-icon
                  v-if="props.row.is_inventory_item"
                  name="inventory"
                  color="primary"
                  size="xs"
                >
                  <q-tooltip>Inventory Item</q-tooltip>
                </q-icon>
                <q-icon v-if="props.row.is_sales_item" name="point_of_sale" color="green" size="xs">
                  <q-tooltip>Sales Item</q-tooltip>
                </q-icon>
                <q-icon
                  v-if="props.row.is_purchase_item"
                  name="shopping_cart"
                  color="orange"
                  size="xs"
                >
                  <q-tooltip>Purchase Item</q-tooltip>
                </q-icon>
              </div>
            </q-td>
          </template>

          <!-- Stock Columns -->
          <template #body-cell-in_stock="props">
            <q-td :props="props" class="text-right num-cell">
              {{ formatNumber(getStockInfo(props.row).inStock) }}
            </q-td>
          </template>
          <template #body-cell-committed="props">
            <q-td :props="props" class="text-right num-cell text-grey-8">
              {{ formatNumber(getStockInfo(props.row).committed) }}
            </q-td>
          </template>
          <template #body-cell-ordered="props">
            <q-td :props="props" class="text-right num-cell text-grey-8">
              {{ formatNumber(getStockInfo(props.row).ordered) }}
            </q-td>
          </template>
          <template #body-cell-available="props">
            <q-td
              :props="props"
              class="text-right num-cell text-bold"
              :class="getStockClass(props.row)"
            >
              {{ formatNumber(getStockInfo(props.row).available) }}
            </q-td>
          </template>
        </SAPTable>
      </SAPCard>
    </div>

    <!-- Item Master Data Dialog (Tabbed SAP Style) -->
    <SAPDialog
      v-model="showItemDialog"
      :title="isEditing ? 'Item Master Data - ' + itemForm.item_code : 'Item Master Data - Create'"
      icon="inventory_2"
      width="900px"
      :loading="saving"
      :confirm-label="isEditing ? 'Update' : 'Add'"
      @confirm="submitForm"
    >
      <q-form ref="itemFormRef" @submit.prevent="submitForm">
        <!-- Header Section (Always Visible) -->
        <div class="row q-col-gutter-md q-mb-md">
          <div class="col-12 col-md-6">
            <SAPInput
              v-model="itemForm.item_code"
              label="Item No."
              required
              :readonly="true"
              hint="Auto-assigned"
            />
            <SAPInput
              v-model="itemForm.item_name"
              label="Item Name"
              hint="Enter item name or leave blank for testing"
            />
            <SAPSelect
              v-model="itemForm.item_type"
              label="Material Type"
              :options="[
                'Raw Material',
                'Finished Good',
                'Semi-Finished',
                'Trading Good',
                'Service',
                'Fixed Asset',
              ]"
              @update:model-value="onItemTypeChange"
            />
          </div>
          <div class="col-12 col-md-6">
            <div class="row q-col-gutter-sm">
              <div class="col-12">
                <SAPSelect
                  v-model="itemForm.category_id"
                  label="Item Group"
                  :options="stockStore.categories"
                  option-label="name"
                  option-value="id"
                />
              </div>
              <div class="col-12">
                <SAPSelect
                  v-model="itemForm.item_identity"
                  label="Item Identity"
                  :options="['Servable', 'Non-Servable']"
                  hint="Servable: Can be served to customers"
                />
              </div>
              <div class="col-12">
                <SAPSelect
                  v-model="itemForm.item_category"
                  label="Material Category"
                  :options="['Raw Material', 'Finished Good', 'Packing Set', 'Semi-Finished']"
                />
              </div>
              <div class="col-12">
                <div class="q-gutter-sm q-pt-sm">
                  <q-checkbox v-model="itemForm.is_inventory_item" label="Inventory Item" dense />
                  <q-checkbox v-model="itemForm.is_sales_item" label="Sales Item" dense />
                  <q-checkbox v-model="itemForm.is_purchase_item" label="Purchase Item" dense />
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- TABS -->
        <q-tabs
          v-model="activeTab"
          dense
          class="text-grey"
          active-color="primary"
          indicator-color="primary"
          align="justify"
          narrow-indicator
        >
          <q-tab name="general" label="General" />
        </q-tabs>

        <q-separator />

        <q-tab-panels v-model="activeTab" animated class="q-mt-sm" style="min-height: 300px">
          <!-- General Tab -->
          <q-tab-panel name="general">
            <div class="row q-col-gutter-md">
              <div class="col-12 col-md-6">
                <SAPSelect
                  v-model="itemForm.base_uom_id"
                  label="Unit of Measure"
                  :options="stockStore.unitsOfMeasure"
                  option-label="name"
                  option-value="id"
                  required
                />
                <SAPSelect
                  v-model="itemForm.default_supplier_id"
                  label="Preferred Vendor"
                  :options="stockStore.suppliers"
                  option-label="name"
                  option-value="id"
                />
                <SAPInput v-model="itemForm.barcode" label="Barcode" />
                <SAPInput v-model="itemForm.purchase_price" label="Purchase Price" type="number" />
                <SAPInput v-model="itemForm.selling_price" label="Selling Price" type="number" />
              </div>
              <div class="col-12 col-md-6">
                <SAPSelect
                  v-model="itemForm.default_warehouse_id"
                  label="Default Warehouse"
                  :options="stockStore.warehouses"
                  option-label="name"
                  option-value="id"
                />
                <SAPInput v-model="itemForm.min_stock_level" label="Minimum Stock" type="number" />
                <SAPInput v-model="itemForm.max_stock_level" label="Maximum Stock" type="number" />
                <SAPInput v-model="itemForm.reorder_point" label="Reorder Point" type="number" />
                <q-checkbox v-model="itemForm.is_active" label="Active" dense class="q-mt-md" />
                <SAPInput v-model="itemForm.description" label="Remarks" type="textarea" rows="2" />
              </div>
            </div>
          </q-tab-panel>
        </q-tab-panels>
      </q-form>
    </SAPDialog>
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
const stockViewMode = ref('list')
const showItemDialog = ref(false)
const showFilterDialog = ref(false)
const isEditing = ref(false)
const saving = ref(false)
const activeTab = ref('general')
const itemFormRef = ref(null)
const selectedItem = ref(null)

const itemForm = ref(getEmptyForm())

// Lifecycle
onMounted(async () => {
  stockStore.subscribeToRealtime()

  await Promise.all([
    stockStore.fetchItems(),
    stockStore.fetchCategories(),
    stockStore.fetchUnitsOfMeasure(),
    stockStore.fetchWarehouses(),
    stockStore.fetchSuppliers(),
  ])

  // Deep Linking Check
  if (route.query.code) {
    const code = route.query.code
    const item = stockStore.items.find((i) => i.item_code === code)
    if (item) {
      viewItem(item)
    } else {
      $q.notify({
        type: 'warning',
        message: `Item code ${code} not found.`,
      })
    }
  }
})

onUnmounted(() => {
  stockStore.unsubscribeRealtime()
})

// Columns
const columns = [
  {
    name: 'item_code',
    label: 'Item No.',
    field: 'item_code',
    sortable: true,
    align: 'left',
    style: 'width: 120px',
  },
  {
    name: 'item_name',
    label: 'Item Description',
    field: 'item_name',
    sortable: true,
    align: 'left',
  },
  // { name: 'foreign_name', label: 'Foreign Name', field: 'foreign_name', align: 'left' },
  { name: 'item_types', label: 'Type', field: 'item_types', align: 'center' },
  {
    name: 'in_stock',
    label: 'In Stock',
    field: (row) => getStockInfo(row).inStock,
    align: 'right',
  },
  {
    name: 'committed',
    label: 'Committed',
    field: (row) => getStockInfo(row).committed,
    align: 'right',
  },
  { name: 'ordered', label: 'Ordered', field: (row) => getStockInfo(row).ordered, align: 'right' },
  {
    name: 'available',
    label: 'Available',
    field: (row) => getStockInfo(row).available,
    align: 'right',
  },
  { name: 'uom', label: 'UoM', field: (row) => row.base_uom?.code, align: 'center' },
  { name: 'price', label: 'Price', field: 'purchase_price', align: 'right' },
]

// Logic
const filteredItems = computed(() => stockStore.items)

function onItemTypeChange(type) {
  // SAP Standard Defaults
  const prefixMap = {
    'Raw Material': 'RM',
    'Finished Good': 'FG',
    'Semi-Finished': 'SF',
    'Trading Good': 'TG',
    Service: 'SR',
    'Fixed Asset': 'FA',
  }

  // Update flags
  switch (type) {
    case 'Raw Material':
      itemForm.value.is_inventory_item = true
      itemForm.value.is_purchase_item = true
      itemForm.value.is_sales_item = false
      break
    case 'Finished Good':
      itemForm.value.is_inventory_item = true
      itemForm.value.is_purchase_item = false // Usually manufactured
      itemForm.value.is_sales_item = true
      break
    case 'Trading Good':
      itemForm.value.is_inventory_item = true
      itemForm.value.is_purchase_item = true
      itemForm.value.is_sales_item = true
      break
    case 'Service':
      itemForm.value.is_inventory_item = false
      itemForm.value.is_purchase_item = false
      itemForm.value.is_sales_item = true
      break
    case 'Fixed Asset':
      itemForm.value.is_inventory_item = false // Tracked in Asset Master
      break
  }

  // Auto-generate code if designing new item
  if (!isEditing.value && prefixMap[type]) {
    generateCode(prefixMap[type])
  }
}

async function generateCode(prefix) {
  itemForm.value.item_code = 'Generating...'
  const result = await stockStore.getNextItemCode(prefix)
  if (result.success) {
    itemForm.value.item_code = result.code
  } else {
    itemForm.value.item_code = `${prefix}-${Date.now().toString().slice(-4)}`
  }
}

function getEmptyForm() {
  return {
    item_code: '',
    item_name: '',
    // foreign_name: '', // Removed
    item_type: 'Raw Material',
    item_identity: 'Non-Servable', // Seven Waves specific
    item_category: 'Raw Material', // Seven Waves specific
    category_id: null,
    base_uom_id: null,
    uom_group_id: null,
    tax_group_id: null,
    purchase_price: 0,
    selling_price: 0,
    min_stock_level: 0,
    max_stock_level: 0,
    reorder_point: 0,
    reorder_quantity: 0,
    valuation_method: 'Moving Average',
    procurement_method: 'Buy',
    default_warehouse_id: null,
    default_supplier_id: null, // Preferred Vendor
    description: '',
    manufacturer: '',
    shipping_type: '',
    barcode: '',
    manage_serial_numbers: false,
    manage_batch_numbers: false,
    is_active: true,
    is_inventory_item: true,
    is_purchase_item: true,
    is_sales_item: true,
    // Opening stock handled separately ideally, or via transaction
    opening_stock: 0,
    opening_stock_warehouse_id: null,
  }
}

function getStockInfo(item) {
  if (!item.warehouse_stock) return { inStock: 0, committed: 0, ordered: 0, available: 0 }
  const inStock = item.warehouse_stock.reduce((s, x) => s + (x.quantity_on_hand || 0), 0)
  const committed = item.warehouse_stock.reduce((s, x) => s + (x.quantity_committed || 0), 0)
  const ordered = item.warehouse_stock.reduce((s, x) => s + (x.quantity_ordered || 0), 0)
  return { inStock, committed, ordered, available: inStock - committed + ordered }
}

function getStockClass(row) {
  const info = getStockInfo(row)
  if (info.available <= (row.min_stock_level || 0)) return 'text-negative'
  return 'text-positive'
}

function formatNumber(val) {
  if (!val) return '0.00'
  return parseFloat(val).toFixed(2)
}

async function openCreateDialog() {
  // Initialize form
  itemForm.value = getEmptyForm()
  isEditing.value = false

  // Set default UoM if available (e.g., 'Each' or 'Unit' or just the first one)
  if (stockStore.unitsOfMeasure.length > 0) {
    const defaultUom =
      stockStore.unitsOfMeasure.find((u) => u.name === 'Each' || u.name === 'Unit') ||
      stockStore.unitsOfMeasure[0]
    itemForm.value.base_uom_id = defaultUom.id
  }

  // Default to Raw Material (RM)
  await generateCode('RM')

  showItemDialog.value = true
}

function viewItem(row) {
  selectedItem.value = row
  itemForm.value = { ...getEmptyForm(), ...row }
  isEditing.value = true
  showItemDialog.value = true
}

async function submitForm() {
  // Validate Item Code first
  if (
    !isEditing.value &&
    (!itemForm.value.item_code || itemForm.value.item_code === 'Loading...')
  ) {
    $q.notify({
      type: 'negative',
      message: 'Item Code is required. Please wait for generation or close and try again.',
      position: 'top',
    })
    return
  }

  // Validate Item Name
  if (!itemForm.value.item_name || itemForm.value.item_name.trim() === '') {
    $q.notify({
      type: 'warning',
      message: 'Please enter an Item Name',
      position: 'top',
    })
    return
  }

  // Validate Base UoM
  if (!itemForm.value.base_uom_id) {
    // Try to auto-fix if UoMs are loaded
    if (stockStore.unitsOfMeasure.length > 0) {
      const defaultUom =
        stockStore.unitsOfMeasure.find((u) => u.name === 'Each' || u.name === 'Unit') ||
        stockStore.unitsOfMeasure[0]
      itemForm.value.base_uom_id = defaultUom.id
    } else {
      $q.notify({
        type: 'warning',
        message: 'Please select a Unit of Measure (UoM)',
        position: 'top',
      })
      return
    }
  }

  saving.value = true
  try {
    let result
    if (isEditing.value) {
      const cleanPayload = { ...itemForm.value }
      // Remove fields not in items table or read-only
      delete cleanPayload.opening_stock
      delete cleanPayload.opening_stock_warehouse_id
      delete cleanPayload.warehouse_stock
      delete cleanPayload.category
      delete cleanPayload.base_uom
      delete cleanPayload.default_warehouse
      delete cleanPayload.default_supplier
      delete cleanPayload.item_uom
      result = await stockStore.updateItem(selectedItem.value.id, cleanPayload)
    } else {
      result = await stockStore.createItem(itemForm.value)
    }

    if (result.success) {
      $q.notify({
        type: 'positive',
        message: isEditing.value ? 'Item updated successfully' : 'Item created successfully',
        position: 'top',
        timeout: 2000,
      })
      showItemDialog.value = false
      // Refresh the list to show new item immediately
      await stockStore.fetchItems()
    } else {
      $q.notify({
        type: 'negative',
        message: result.error || 'Failed to save item',
        position: 'top',
      })
    }
  } catch (err) {
    console.error('Error saving item:', err)
    $q.notify({
      type: 'negative',
      message: err.message || 'An error occurred while saving the item',
      position: 'top',
    })
  } finally {
    saving.value = false
  }
}

function exportItems() {
  // Implement standard export
}

function loadData() {
  stockStore.fetchItems()
}
</script>

<style lang="scss" scoped>
.num-cell {
  font-family: 'Roboto Mono', monospace;
  font-size: 0.9em;
}
</style>
