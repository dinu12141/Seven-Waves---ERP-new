<template>
  <q-page class="sap-page">
    <!-- Toolbar -->
    <SAPToolbar
      title="Warehouse & Bin Management"
      icon="warehouse"
      :badge="stockStore.warehouses.length"
      add-label="New Warehouse"
      :show-export="true"
      @add="openWarehouseDialog"
      @refresh="loadData"
    />

    <div class="sap-page-content">
      <!-- Stats Row -->
      <div class="row q-col-gutter-md q-mb-md">
        <div class="col-12 col-md-3">
          <SAPCard flat bordered>
            <div class="stat-card">
              <q-icon name="warehouse" size="32px" color="primary" />
              <div class="stat-info">
                <div class="stat-value">{{ stockStore.warehouses.length }}</div>
                <div class="stat-label">Warehouses</div>
              </div>
            </div>
          </SAPCard>
        </div>
        <div class="col-12 col-md-3">
          <SAPCard flat bordered>
            <div class="stat-card">
              <q-icon name="check_circle" size="32px" color="positive" />
              <div class="stat-info">
                <div class="stat-value">{{ stockStore.activeWarehouses.length }}</div>
                <div class="stat-label">Active</div>
              </div>
            </div>
          </SAPCard>
        </div>
        <div class="col-12 col-md-3">
          <SAPCard flat bordered>
            <div class="stat-card">
              <q-icon name="grid_view" size="32px" color="accent" />
              <div class="stat-info">
                <div class="stat-value">{{ inventoryStore.binLocations.length }}</div>
                <div class="stat-label">Bin Locations</div>
              </div>
            </div>
          </SAPCard>
        </div>
        <div class="col-12 col-md-3">
          <SAPCard flat bordered>
            <div class="stat-card">
              <q-icon name="inventory" size="32px" color="info" />
              <div class="stat-info">
                <div class="stat-value">{{ totalStockValue }}</div>
                <div class="stat-label">Total Items</div>
              </div>
            </div>
          </SAPCard>
        </div>
      </div>

      <!-- Tabs for Warehouses and Bin Locations -->
      <SAPCard no-padding>
        <q-tabs
          v-model="activeTab"
          dense
          class="text-grey"
          active-color="primary"
          indicator-color="primary"
        >
          <q-tab name="warehouses" label="Warehouses" icon="warehouse" />
          <q-tab name="bins" label="Bin Locations" icon="grid_view" />
        </q-tabs>

        <q-separator />

        <q-tab-panels v-model="activeTab" animated>
          <!-- Warehouses Tab -->
          <q-tab-panel name="warehouses" class="q-pa-none">
            <SAPTable
              :rows="stockStore.warehouses"
              :columns="warehouseColumns"
              :loading="stockStore.loading"
              row-key="id"
              @row-click="viewWarehouse"
            >
              <template #body-cell-code="props">
                <q-td :props="props">
                  <div class="row items-center no-wrap">
                    <span class="text-bold">{{ props.value }}</span>
                    <GoldenArrow @click="viewWarehouse(props.row)" />
                  </div>
                </q-td>
              </template>

              <template #body-cell-is_active="props">
                <q-td :props="props" class="text-center">
                  <q-badge
                    :color="props.value ? 'positive' : 'grey'"
                    :label="props.value ? 'Active' : 'Inactive'"
                  />
                </q-td>
              </template>

              <template #body-cell-is_default="props">
                <q-td :props="props" class="text-center">
                  <q-icon v-if="props.value" name="star" color="warning" size="18px" />
                </q-td>
              </template>

              <template #body-cell-bin_count="props">
                <q-td :props="props" class="text-right">
                  <q-badge color="info" :label="getBinCount(props.row.id)" />
                </q-td>
              </template>

              <template #body-cell-actions="props">
                <q-td :props="props" class="actions-cell">
                  <q-btn
                    flat
                    dense
                    round
                    size="sm"
                    icon="edit"
                    color="primary"
                    @click.stop="editWarehouse(props.row)"
                  >
                    <q-tooltip>Edit</q-tooltip>
                  </q-btn>
                  <q-btn
                    flat
                    dense
                    round
                    size="sm"
                    icon="grid_view"
                    color="accent"
                    @click.stop="manageBins(props.row)"
                  >
                    <q-tooltip>Manage Bins</q-tooltip>
                  </q-btn>
                </q-td>
              </template>
            </SAPTable>
          </q-tab-panel>

          <!-- Bin Locations Tab -->
          <q-tab-panel name="bins" class="q-pa-none">
            <div class="q-pa-sm bg-grey-2 row items-center">
              <SAPSelect
                v-model="selectedWarehouseFilter"
                :options="[{ id: null, name: 'All Warehouses' }, ...stockStore.warehouses]"
                option-label="name"
                option-value="id"
                dense
                style="width: 250px"
                @update:model-value="filterBins"
              />
              <q-space />
              <q-btn color="primary" dense icon="add" label="Add Bin" @click="openBinDialog" />
            </div>

            <SAPTable
              :rows="filteredBins"
              :columns="binColumns"
              :loading="inventoryStore.loading"
              row-key="id"
            >
              <template #body-cell-bin_code="props">
                <q-td :props="props">
                  <span class="text-bold text-primary">{{ props.value }}</span>
                </q-td>
              </template>

              <template #body-cell-warehouse="props">
                <q-td :props="props">
                  {{ props.row.warehouse?.name || '—' }}
                </q-td>
              </template>

              <template #body-cell-bin_type="props">
                <q-td :props="props">
                  <q-badge
                    :color="getBinTypeColor(props.value)"
                    :label="props.value"
                    class="text-capitalize"
                  />
                </q-td>
              </template>

              <template #body-cell-is_active="props">
                <q-td :props="props" class="text-center">
                  <q-icon
                    :name="props.value ? 'check_circle' : 'cancel'"
                    :color="props.value ? 'positive' : 'grey'"
                    size="18px"
                  />
                </q-td>
              </template>

              <template #body-cell-actions="props">
                <q-td :props="props" class="actions-cell">
                  <q-btn
                    flat
                    dense
                    round
                    size="sm"
                    icon="edit"
                    color="primary"
                    @click.stop="editBin(props.row)"
                  >
                    <q-tooltip>Edit</q-tooltip>
                  </q-btn>
                </q-td>
              </template>
            </SAPTable>
          </q-tab-panel>
        </q-tab-panels>
      </SAPCard>
    </div>

    <!-- Warehouse Dialog -->
    <SAPDialog
      v-model="showWarehouseDialog"
      :title="isEditingWarehouse ? 'Edit Warehouse' : 'New Warehouse'"
      icon="warehouse"
      width="600px"
      :loading="saving"
      :confirm-label="isEditingWarehouse ? 'Update' : 'Create'"
      @confirm="saveWarehouse"
    >
      <q-form ref="warehouseFormRef" @submit.prevent="saveWarehouse">
        <div class="row q-col-gutter-md">
          <div class="col-12 col-md-4">
            <SAPInput
              v-model="warehouseForm.code"
              label="Warehouse Code"
              placeholder="WH01"
              required
              :rules="requiredRules"
            />
          </div>
          <div class="col-12 col-md-8">
            <SAPInput
              v-model="warehouseForm.name"
              label="Warehouse Name"
              placeholder="Main Warehouse"
              required
              :rules="requiredRules"
            />
          </div>
          <div class="col-12">
            <SAPInput
              v-model="warehouseForm.location"
              label="Location / Address"
              type="textarea"
              rows="2"
            />
          </div>
          <div class="col-12 col-md-6">
            <label class="sap-label">Warehouse Type</label>
            <SAPSelect
              v-model="warehouseForm.warehouse_type"
              :options="warehouseTypes"
              option-label="label"
              option-value="value"
            />
          </div>
          <div class="col-12 col-md-6">
            <label class="sap-label">Manager</label>
            <SAPSelect
              v-model="warehouseForm.manager_id"
              :options="managers"
              option-label="full_name"
              option-value="id"
              placeholder="Select manager"
            />
          </div>
          <div class="col-12">
            <div class="row q-gutter-md">
              <q-checkbox v-model="warehouseForm.is_active" label="Active" dense />
              <q-checkbox v-model="warehouseForm.is_default" label="Default Warehouse" dense />
            </div>
          </div>
        </div>
      </q-form>
    </SAPDialog>

    <!-- Bin Location Dialog -->
    <SAPDialog
      v-model="showBinDialog"
      :title="isEditingBin ? 'Edit Bin Location' : 'New Bin Location'"
      icon="grid_view"
      width="600px"
      :loading="saving"
      :confirm-label="isEditingBin ? 'Update' : 'Create'"
      @confirm="saveBin"
    >
      <q-form ref="binFormRef" @submit.prevent="saveBin">
        <div class="row q-col-gutter-md">
          <div class="col-12 col-md-6">
            <label class="sap-label required">Warehouse</label>
            <SAPSelect
              v-model="binForm.warehouse_id"
              :options="stockStore.activeWarehouses"
              option-label="name"
              option-value="id"
              :rules="requiredRules"
            />
          </div>
          <div class="col-12 col-md-6">
            <SAPInput
              v-model="binForm.bin_code"
              label="Bin Code"
              placeholder="A-01-01"
              required
              :rules="requiredRules"
            />
          </div>
          <div class="col-12">
            <SAPInput
              v-model="binForm.bin_description"
              label="Description"
              placeholder="Aisle A, Rack 1, Shelf 1"
            />
          </div>
          <div class="col-6 col-md-3">
            <SAPInput v-model="binForm.aisle" label="Aisle" placeholder="A" />
          </div>
          <div class="col-6 col-md-3">
            <SAPInput v-model="binForm.rack" label="Rack" placeholder="01" />
          </div>
          <div class="col-6 col-md-3">
            <SAPInput v-model="binForm.shelf" label="Shelf" placeholder="01" />
          </div>
          <div class="col-6 col-md-3">
            <SAPInput v-model="binForm.level" label="Level" placeholder="1" />
          </div>
          <div class="col-12 col-md-6">
            <label class="sap-label">Bin Type</label>
            <SAPSelect
              v-model="binForm.bin_type"
              :options="binTypes"
              option-label="label"
              option-value="value"
            />
          </div>
          <div class="col-12 col-md-6">
            <div class="row q-gutter-md q-mt-lg">
              <q-checkbox v-model="binForm.is_active" label="Active" dense />
              <q-checkbox v-model="binForm.is_default" label="Default Bin" dense />
            </div>
          </div>
        </div>
      </q-form>
    </SAPDialog>
  </q-page>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useQuasar } from 'quasar'
import { useStockStore } from 'src/stores/stockStore'
import { useInventoryStore } from 'src/stores/inventoryStore'
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

// State
const activeTab = ref('warehouses')
const showWarehouseDialog = ref(false)
const showBinDialog = ref(false)
const isEditingWarehouse = ref(false)
const isEditingBin = ref(false)
const saving = ref(false)
const selectedWarehouseFilter = ref(null)
const warehouseFormRef = ref(null)
const binFormRef = ref(null)
const managers = ref([])

const warehouseForm = ref(getEmptyWarehouseForm())
const binForm = ref(getEmptyBinForm())

// Constants
const warehouseTypes = [
  { value: 'main', label: 'Main Warehouse' },
  { value: 'branch', label: 'Branch Warehouse' },
  { value: 'transit', label: 'Transit' },
  { value: 'external', label: 'External' },
]

const binTypes = [
  { value: 'storage', label: 'Storage' },
  { value: 'receiving', label: 'Receiving' },
  { value: 'shipping', label: 'Shipping' },
  { value: 'staging', label: 'Staging' },
  { value: 'quarantine', label: 'Quarantine' },
]

// Columns
const warehouseColumns = [
  {
    name: 'code',
    label: 'Code',
    field: 'code',
    sortable: true,
    align: 'left',
    style: 'width: 120px',
  },
  { name: 'name', label: 'Warehouse Name', field: 'name', sortable: true, align: 'left' },
  {
    name: 'warehouse_type',
    label: 'Type',
    field: 'warehouse_type',
    sortable: true,
    align: 'left',
    classes: 'text-capitalize',
  },
  { name: 'location', label: 'Location', field: 'location', align: 'left' },
  {
    name: 'manager',
    label: 'Manager',
    field: (row) => row.manager?.full_name || '—',
    align: 'left',
  },
  { name: 'bin_count', label: 'Bins', field: 'bin_count', align: 'right' },
  { name: 'is_default', label: 'Default', field: 'is_default', align: 'center' },
  { name: 'is_active', label: 'Status', field: 'is_active', sortable: true, align: 'center' },
  { name: 'actions', label: 'Actions', field: 'actions', align: 'center' },
]

const binColumns = [
  {
    name: 'bin_code',
    label: 'Bin Code',
    field: 'bin_code',
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
  { name: 'bin_description', label: 'Description', field: 'bin_description', align: 'left' },
  { name: 'aisle', label: 'Aisle', field: 'aisle', align: 'center' },
  { name: 'rack', label: 'Rack', field: 'rack', align: 'center' },
  { name: 'shelf', label: 'Shelf', field: 'shelf', align: 'center' },
  { name: 'bin_type', label: 'Type', field: 'bin_type', align: 'center' },
  { name: 'is_active', label: 'Active', field: 'is_active', align: 'center' },
  { name: 'actions', label: 'Actions', field: 'actions', align: 'center' },
]

const requiredRules = [(val) => !!val || 'Required']

// Computed
const filteredBins = computed(() => {
  if (!selectedWarehouseFilter.value) return inventoryStore.binLocations
  return inventoryStore.binLocations.filter((b) => b.warehouse_id === selectedWarehouseFilter.value)
})

const totalStockValue = computed(() => {
  return stockStore.items.reduce((sum, item) => {
    const stock = item.warehouse_stock?.reduce((s, ws) => s + (ws.quantity_on_hand || 0), 0) || 0
    return sum + stock
  }, 0)
})

// Methods
function getEmptyWarehouseForm() {
  return {
    code: '',
    name: '',
    location: '',
    warehouse_type: 'main',
    manager_id: null,
    is_active: true,
    is_default: false,
  }
}

function getEmptyBinForm() {
  return {
    warehouse_id: null,
    bin_code: '',
    bin_description: '',
    aisle: '',
    rack: '',
    shelf: '',
    level: '',
    bin_type: 'storage',
    is_active: true,
    is_default: false,
  }
}

function getBinCount(warehouseId) {
  return inventoryStore.binLocations.filter((b) => b.warehouse_id === warehouseId).length
}

function getBinTypeColor(type) {
  const colors = {
    storage: 'primary',
    receiving: 'positive',
    shipping: 'info',
    staging: 'warning',
    quarantine: 'negative',
  }
  return colors[type] || 'grey'
}

async function loadData() {
  await Promise.all([stockStore.fetchWarehouses(), inventoryStore.fetchBinLocations()])
}

function openWarehouseDialog() {
  isEditingWarehouse.value = false
  warehouseForm.value = getEmptyWarehouseForm()
  showWarehouseDialog.value = true
}

function editWarehouse(wh) {
  isEditingWarehouse.value = true
  warehouseForm.value = { ...wh }
  showWarehouseDialog.value = true
}

function viewWarehouse(wh) {
  selectedWarehouseFilter.value = wh.id
  activeTab.value = 'bins'
}

function manageBins(wh) {
  selectedWarehouseFilter.value = wh.id
  activeTab.value = 'bins'
}

async function saveWarehouse() {
  const valid = await warehouseFormRef.value?.validate()
  if (!valid) return

  saving.value = true
  try {
    let result
    if (isEditingWarehouse.value) {
      result = await stockStore.updateWarehouse(warehouseForm.value.id, warehouseForm.value)
    } else {
      result = await stockStore.createWarehouse(warehouseForm.value)
    }

    if (result.success) {
      $q.notify({
        type: 'positive',
        message: isEditingWarehouse.value ? 'Warehouse updated' : 'Warehouse created',
        position: 'top',
      })
      showWarehouseDialog.value = false
    } else {
      $q.notify({ type: 'negative', message: result.error, position: 'top' })
    }
  } finally {
    saving.value = false
  }
}

function openBinDialog() {
  isEditingBin.value = false
  binForm.value = getEmptyBinForm()
  if (selectedWarehouseFilter.value) {
    binForm.value.warehouse_id = selectedWarehouseFilter.value
  }
  showBinDialog.value = true
}

function editBin(bin) {
  isEditingBin.value = true
  binForm.value = { ...bin }
  showBinDialog.value = true
}

async function saveBin() {
  const valid = await binFormRef.value?.validate()
  if (!valid) return

  saving.value = true
  try {
    let result
    if (isEditingBin.value) {
      result = await inventoryStore.updateBinLocation(binForm.value.id, binForm.value)
    } else {
      result = await inventoryStore.createBinLocation(binForm.value)
    }

    if (result.success) {
      $q.notify({
        type: 'positive',
        message: isEditingBin.value ? 'Bin updated' : 'Bin created',
        position: 'top',
      })
      showBinDialog.value = false
    } else {
      $q.notify({ type: 'negative', message: result.error, position: 'top' })
    }
  } finally {
    saving.value = false
  }
}

function filterBins() {
  // Filter handled by computed property
}

onMounted(async () => {
  await loadData()
})
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

.actions-cell {
  white-space: nowrap;
}
</style>
