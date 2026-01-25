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
    <q-no-ssr>
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
                  <q-icon
                    v-if="props.row.is_sales_item"
                    name="point_of_sale"
                    color="green"
                    size="xs"
                  >
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
    </q-no-ssr>

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
              label="Description"
              required
              :rules="[(val) => !!val || 'Description is required']"
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
                <SAPInput v-model="itemForm.foreign_name" label="Foreign Name" />
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
          <q-tab name="purchasing" label="Purchasing Data" />
          <q-tab name="sales" label="Sales Data" />
          <q-tab name="inventory" label="Inventory Data" />
          <q-tab name="planning" label="Planning Data" />
        </q-tabs>

        <q-separator />

        <q-tab-panels v-model="activeTab" animated class="q-mt-sm" style="min-height: 300px">
          <!-- General Tab -->
          <q-tab-panel name="general">
            <div class="row q-col-gutter-md">
              <div class="col-12 col-md-6">
                <q-checkbox
                  v-model="itemForm.manage_serial_numbers"
                  label="Manage Serial Numbers"
                  dense
                />
                <br />
                <q-checkbox
                  v-model="itemForm.manage_batch_numbers"
                  label="Manage Batch Numbers"
                  dense
                />
                <br /><br />
                <SAPInput v-model="itemForm.manufacturer" label="Manufacturer" />
                <SAPInput v-model="itemForm.shipping_type" label="Shipping Type" />
              </div>
              <div class="col-12 col-md-6">
                <q-checkbox v-model="itemForm.is_active" label="Active" dense />
                <br />
                <SAPInput v-model="itemForm.description" label="Remarks" type="textarea" rows="3" />
              </div>
            </div>
          </q-tab-panel>

          <!-- Purchasing Tab -->
          <q-tab-panel name="purchasing">
            <div class="row q-col-gutter-md">
              <div class="col-12 col-md-6">
                <SAPSelect
                  v-model="itemForm.default_supplier_id"
                  label="Preferred Vendor"
                  :options="stockStore.suppliers"
                  option-label="name"
                  option-value="id"
                />
                <SAPInput v-model="itemForm.barcode" label="Mfr Catalog No. (Barcode)" />
                <SAPSelect
                  v-model="itemForm.base_uom_id"
                  label="Purchasing UoM"
                  :options="stockStore.unitsOfMeasure"
                  option-label="name"
                  option-value="id"
                />
              </div>
              <div class="col-12 col-md-6">
                <SAPInput v-model="itemForm.purchase_price" label="Purchase Price" type="number" />
                <SAPInput
                  v-model="itemForm.tax_group_id"
                  label="Tax Group"
                  placeholder="Input Tax"
                />
              </div>
            </div>
          </q-tab-panel>

          <!-- Sales Tab -->
          <q-tab-panel name="sales">
            <div class="row q-col-gutter-md">
              <div class="col-12 col-md-6">
                <SAPSelect
                  v-model="itemForm.base_uom_id"
                  label="Sales UoM"
                  :options="stockStore.unitsOfMeasure"
                  option-label="name"
                  option-value="id"
                  hint="Using Base UoM for now"
                />
                <SAPInput v-model="itemForm.selling_price" label="Sales Price" type="number" />
              </div>
              <div class="col-12 col-md-6">
                <SAPInput
                  v-model="itemForm.tax_group_id"
                  label="Tax Group"
                  placeholder="Output Tax"
                />
              </div>
            </div>
          </q-tab-panel>

          <!-- Inventory Tab -->
          <q-tab-panel name="inventory">
            <div class="row q-col-gutter-md q-mb-md">
              <div class="col-12 col-md-4">
                <SAPSelect
                  v-model="itemForm.valuation_method"
                  label="Valuation Method"
                  :options="['Moving Average', 'Standard', 'FIFO']"
                />
              </div>
              <div class="col-12 col-md-4">
                <SAPInput
                  v-model="itemForm.base_uom_id"
                  label="Inv. UoM"
                  :readonly="true"
                  :value="getUomName(itemForm.base_uom_id)"
                />
              </div>
              <div class="col-12 col-md-4">
                <SAPSelect
                  v-model="itemForm.default_warehouse_id"
                  label="Default Warehouse"
                  :options="stockStore.warehouses"
                  option-label="name"
                  option-value="id"
                />
              </div>
            </div>

            <!-- Stock Grid -->
            <SAPTable
              :rows="isEditing ? selectedItem?.warehouse_stock : []"
              :columns="stockColumns"
              :show-search="false"
              :show-count="false"
              dense
              flat
              bordered
            >
              <template #body-cell-quantity_on_hand="props">
                <q-td :props="props" class="text-right">{{ formatNumber(props.value) }}</q-td>
              </template>
              <template #body-cell-quantity_committed="props">
                <q-td :props="props" class="text-right">{{ formatNumber(props.value) }}</q-td>
              </template>
              <template #body-cell-quantity_ordered="props">
                <q-td :props="props" class="text-right">{{ formatNumber(props.value) }}</q-td>
              </template>
            </SAPTable>
          </q-tab-panel>

          <!-- Planning Tab -->
          <q-tab-panel name="planning">
            <div class="row q-col-gutter-md">
              <div class="col-12 col-md-6">
                <SAPSelect
                  v-model="itemForm.procurement_method"
                  label="Procurement Method"
                  :options="['Buy', 'Make']"
                />
                <SAPInput
                  v-model="itemForm.reorder_point"
                  label="Order Interval"
                  placeholder="N/A"
                  disable
                />
                <SAPInput
                  v-model="itemForm.reorder_quantity"
                  label="Order Multiple"
                  placeholder="N/A"
                  disable
                />
                <SAPInput v-model="itemForm.min_stock_level" label="Minimum Stock" type="number" />
                <SAPInput v-model="itemForm.max_stock_level" label="Maximum Stock" type="number" />
              </div>
              <div class="col-12 col-md-6">
                <SAPInput
                  v-model="itemForm.reorder_point"
                  label="Required (Reorder Point)"
                  type="number"
                />
              </div>
            </div>
          </q-tab-panel>
        </q-tab-panels>
      </q-form>
    </SAPDialog>
  </q-page>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useQuasar } from 'quasar'
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
onMounted(() => {
  stockStore.fetchItems()
  stockStore.fetchCategories()
  stockStore.fetchUnitsOfMeasure()
  stockStore.fetchWarehouses()
  stockStore.fetchSuppliers()
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
  { name: 'foreign_name', label: 'Foreign Name', field: 'foreign_name', align: 'left' },
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

const stockColumns = [
  {
    name: 'warehouse',
    label: 'Warehouse',
    field: (row) => row.warehouse?.name || row.warehouse_id,
    align: 'left',
  },
  { name: 'quantity_on_hand', label: 'In Stock', field: 'quantity_on_hand', align: 'right' },
  { name: 'quantity_committed', label: 'Committed', field: 'quantity_committed', align: 'right' },
  { name: 'quantity_ordered', label: 'Ordered', field: 'quantity_ordered', align: 'right' },
  {
    name: 'available',
    label: 'Available',
    field: (row) => row.quantity_on_hand - row.quantity_committed + row.quantity_ordered,
    align: 'right',
  },
]

// Logic
const filteredItems = computed(() => stockStore.items)

function onItemTypeChange(type) {
  // SAP Standard Defaults
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
}

function getEmptyForm() {
  return {
    item_code: '',
    item_name: '',
    foreign_name: '',
    item_type: 'Raw Material',
    category_id: null,
    base_uom_id: null,
    uom_group_id: null,
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

function getUomName(id) {
  const uom = stockStore.unitsOfMeasure.find((u) => u.id === id)
  return uom ? uom.name : ''
}

async function openCreateDialog() {
  itemForm.value = getEmptyForm()
  isEditing.value = false

  // Auto-generate Item Code
  const result = await stockStore.generateDocNumber('ITM')
  if (result.success) {
    itemForm.value.item_code = result.docNumber
  }

  showItemDialog.value = true
}

function viewItem(row) {
  selectedItem.value = row
  itemForm.value = { ...getEmptyForm(), ...row }
  isEditing.value = true
  showItemDialog.value = true
}

async function submitForm() {
  const success = await itemFormRef.value.validate()
  if (!success) {
    $q.notify({ type: 'warning', message: 'Please fill in required fields' })
    return
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
      $q.notify({ type: 'positive', message: 'Item saved successfully' })
      showItemDialog.value = false
    } else {
      $q.notify({ type: 'negative', message: result.error })
    }
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
