<template>
  <q-page class="sap-page">
    <!-- Toolbar -->
    <SAPToolbar
      title="Recipes / Bill of Materials"
      icon="receipt_long"
      :badge="stockStore.recipes.length"
      add-label="New Recipe"
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
              <q-icon name="receipt_long" size="32px" color="primary" />
              <div class="stat-info">
                <div class="stat-value">{{ stockStore.recipes.length }}</div>
                <div class="stat-label">Total Recipes</div>
              </div>
            </div>
          </SAPCard>
        </div>
        <div class="col-12 col-md-4">
          <SAPCard flat bordered>
            <div class="stat-card">
              <q-icon name="check_circle" size="32px" color="positive" />
              <div class="stat-info">
                <div class="stat-value">{{ stockStore.activeRecipes.length }}</div>
                <div class="stat-label">Active Recipes</div>
              </div>
            </div>
          </SAPCard>
        </div>
        <div class="col-12 col-md-4">
          <SAPCard flat bordered>
            <div class="stat-card">
              <q-icon name="kitchen" size="32px" color="accent" />
              <div class="stat-info">
                <div class="stat-value">{{ salesItemsCount }}</div>
                <div class="stat-label">Sales Items</div>
              </div>
            </div>
          </SAPCard>
        </div>
      </div>

      <!-- Recipes Table -->
      <SAPCard title="Recipes List" icon="list" no-padding>
        <SAPTable
          :rows="stockStore.recipes"
          :columns="columns"
          :loading="stockStore.loading"
          row-key="id"
          @row-click="editRecipe"
        >
          <!-- Recipe Code Column -->
          <template #body-cell-recipe_code="props">
            <q-td :props="props">
              <div class="row items-center no-wrap">
                <span class="text-bold">{{ props.value }}</span>
                <GoldenArrow @click="editRecipe(props.row)" />
              </div>
            </q-td>
          </template>

          <!-- Sales Item Column -->
          <template #body-cell-sales_item="props">
            <q-td :props="props">
              {{ props.row.sales_item?.item_name || '—' }}
            </q-td>
          </template>

          <!-- Target Warehouse Column -->
          <template #body-cell-warehouse="props">
            <q-td :props="props" class="text-center">
              <q-badge :color="getWarehouseColor(props.row.target_warehouse?.code)">
                {{ props.row.target_warehouse?.code || '—' }}
              </q-badge>
            </q-td>
          </template>

          <!-- Yield Column -->
          <template #body-cell-yield="props">
            <q-td :props="props" class="text-right">
              {{ formatNumber(props.row.yield_quantity) }}
              {{ props.row.yield_uom?.code || '' }}
            </q-td>
          </template>

          <!-- Cost Column -->
          <template #body-cell-cost="props">
            <q-td :props="props" class="text-right">
              <span v-if="recipeCosts[props.row.id]" class="text-bold">
                {{ formatCurrency(recipeCosts[props.row.id]) }}
              </span>
              <q-btn
                v-else
                flat
                dense
                size="sm"
                icon="calculate"
                color="primary"
                @click.stop="loadRecipeCost(props.row.id)"
              >
                <q-tooltip>Calculate Cost</q-tooltip>
              </q-btn>
            </q-td>
          </template>

          <!-- Status Column -->
          <template #body-cell-is_active="props">
            <q-td :props="props" class="text-center">
              <q-badge
                :color="props.value ? 'positive' : 'grey'"
                :label="props.value ? 'Active' : 'Inactive'"
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
                @click.stop="editRecipe(props.row)"
              >
                <q-tooltip>Edit</q-tooltip>
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

    <!-- Create/Edit Dialog -->
    <SAPDialog
      v-model="showDialog"
      :title="isEditing ? 'Edit Recipe' : 'New Recipe'"
      icon="receipt_long"
      width="900px"
      :loading="saving"
      @confirm="submitForm"
    >
      <q-form ref="formRef" @submit.prevent>
        <div class="row q-col-gutter-md">
          <!-- Header Section -->
          <div class="col-12">
            <div class="section-title">Recipe Information</div>
          </div>

          <div class="col-12 col-md-6">
            <label class="sap-label required">Sales Item</label>
            <SAPSelect
              v-model="form.sales_item_id"
              :options="salesItems"
              option-label="item_name"
              option-value="id"
              placeholder="Select sales item"
              searchable
              :rules="requiredRules"
            >
              <template #option="{ opt }">
                <div>
                  <div class="text-body2">{{ opt.item_name }}</div>
                  <div class="text-caption text-grey">{{ opt.item_code }}</div>
                </div>
              </template>
            </SAPSelect>
          </div>

          <div class="col-12 col-md-6">
            <SAPInput
              v-model="form.recipe_name"
              label="Recipe Name"
              required
              :rules="requiredRules"
            />
          </div>

          <div class="col-12 col-md-4">
            <label class="sap-label required">Target Warehouse</label>
            <SAPSelect
              v-model="form.target_warehouse_id"
              :options="targetWarehouses"
              option-label="name"
              option-value="id"
              placeholder="Select warehouse"
              :rules="requiredRules"
            />
          </div>

          <div class="col-12 col-md-4">
            <SAPInput
              v-model.number="form.yield_quantity"
              label="Yield Quantity"
              type="number"
              step="0.01"
              min="0"
              :rules="requiredRules"
            />
          </div>

          <div class="col-12 col-md-4">
            <label class="sap-label">Yield UoM</label>
            <SAPSelect
              v-model="form.yield_uom_id"
              :options="stockStore.unitsOfMeasure"
              option-label="name"
              option-value="id"
              placeholder="Select UoM"
            />
          </div>

          <div class="col-12">
            <SAPInput v-model="form.description" label="Description" type="textarea" rows="2" />
          </div>

          <!-- Ingredients Section -->
          <div class="col-12">
            <div class="section-title q-mt-md q-mb-sm">Ingredients</div>
          </div>

          <div class="col-12">
            <div class="ingredients-section">
              <!-- Ingredients Table -->
              <q-table
                :rows="form.lines"
                :columns="ingredientColumns"
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
                    label="Add Ingredient"
                    @click="addIngredient"
                  />
                </template>

                <template #body-cell-item="props">
                  <q-td :props="props">
                    <SAPSelect
                      v-model="props.row.item_id"
                      :options="purchasedItems"
                      option-label="item_name"
                      option-value="id"
                      placeholder="Select item"
                      dense
                      searchable
                      @update:model-value="onIngredientChange(props.row)"
                    />
                  </q-td>
                </template>

                <template #body-cell-quantity="props">
                  <q-td :props="props">
                    <SAPInput
                      v-model.number="props.row.quantity"
                      type="number"
                      step="0.01"
                      min="0"
                      dense
                      @update:model-value="calculateLineCost(props.row)"
                    />
                  </q-td>
                </template>

                <template #body-cell-uom="props">
                  <q-td :props="props">
                    <SAPSelect
                      v-model="props.row.uom_id"
                      :options="stockStore.unitsOfMeasure"
                      option-label="code"
                      option-value="id"
                      dense
                    />
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
                      @click="removeIngredient(props.rowIndex)"
                    />
                  </q-td>
                </template>
              </q-table>

              <!-- Total Cost Display -->
              <div class="total-cost-display q-mt-md">
                <div class="text-h6">Total Recipe Cost: {{ formatCurrency(totalRecipeCost) }}</div>
                <div class="text-caption text-grey">Based on current average costs</div>
              </div>
            </div>
          </div>

          <!-- Flags -->
          <div class="col-12">
            <q-checkbox v-model="form.is_active" label="Active" dense />
          </div>
        </div>
      </q-form>
    </SAPDialog>

    <!-- Delete Confirmation -->
    <q-dialog v-model="showDeleteConfirm">
      <q-card style="min-width: 350px">
        <q-card-section class="row items-center">
          <q-icon name="warning" color="negative" size="32px" class="q-mr-md" />
          <span class="text-body1">Delete this recipe?</span>
        </q-card-section>
        <q-card-section class="q-pt-none">
          <strong>{{ recipeToDelete?.recipe_code }}</strong> - {{ recipeToDelete?.recipe_name }}
        </q-card-section>
        <q-card-actions align="right">
          <q-btn flat label="Cancel" v-close-popup />
          <q-btn flat color="negative" label="Delete" @click="deleteRecipe" :loading="deleting" />
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
const showDeleteConfirm = ref(false)
const isEditing = ref(false)
const saving = ref(false)
const deleting = ref(false)
const formRef = ref(null)
const form = ref(getEmptyForm())
const recipeToDelete = ref(null)
const recipeCosts = ref({})

// Validation rules
const requiredRules = [(val) => !!val || 'Required']

// Columns
const columns = [
  {
    name: 'recipe_code',
    label: 'Recipe Code',
    field: 'recipe_code',
    sortable: true,
    align: 'left',
  },
  { name: 'sales_item', label: 'Sales Item', field: 'sales_item', sortable: true, align: 'left' },
  { name: 'warehouse', label: 'Kitchen', field: 'warehouse', sortable: true, align: 'center' },
  { name: 'yield', label: 'Yield', field: 'yield_quantity', sortable: true, align: 'right' },
  { name: 'cost', label: 'Total Cost', field: 'cost', align: 'right' },
  { name: 'is_active', label: 'Status', field: 'is_active', sortable: true, align: 'center' },
  { name: 'actions', label: 'Actions', field: 'actions', align: 'center' },
]

const ingredientColumns = [
  { name: 'item', label: 'Ingredient', field: 'item_id', style: 'width: 300px', align: 'left' },
  { name: 'quantity', label: 'Quantity', field: 'quantity', style: 'width: 120px', align: 'right' },
  { name: 'uom', label: 'UoM', field: 'uom_id', style: 'width: 100px', align: 'center' },
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

// Computed
const salesItems = computed(() => stockStore.salesItems)
const salesItemsCount = computed(() => salesItems.value.length)

const purchasedItems = computed(() => stockStore.purchaseItems)

const targetWarehouses = computed(() => {
  // Filter for WH02 and WH03 warehouses (Kitchens)
  return stockStore.warehouses.filter((w) => w.code === 'WH02' || w.code === 'WH03')
})

const totalRecipeCost = computed(() => {
  return form.value.lines.reduce((sum, line) => {
    return sum + (line.quantity || 0) * (line.unit_cost || 0)
  }, 0)
})

// Methods
function getEmptyForm() {
  return {
    sales_item_id: null,
    target_warehouse_id: null,
    recipe_name: '',
    description: '',
    yield_quantity: 1,
    yield_uom_id: null,
    is_active: true,
    lines: [],
  }
}

let tempIdCounter = 1
function addIngredient() {
  form.value.lines.push({
    temp_id: tempIdCounter++,
    item_id: null,
    quantity: 0,
    uom_id: null,
    unit_cost: 0,
    notes: '',
  })
}

function removeIngredient(index) {
  form.value.lines.splice(index, 1)
}

async function onIngredientChange(line) {
  const item = stockStore.items.find((i) => i.id === line.item_id)
  if (item) {
    // Set default UoM
    line.uom_id = item.base_uom_id

    // Get average cost from warehouse stock
    const warehouseStock = item.warehouse_stock?.find(
      (ws) => ws.warehouse_id === form.value.target_warehouse_id,
    )
    line.unit_cost = warehouseStock?.average_cost || item.purchase_price || 0
  }
}

function calculateLineCost(line) {
  line.line_total = (line.quantity || 0) * (line.unit_cost || 0)
}

function getWarehouseColor(code) {
  if (code === 'WH01') return 'primary'
  if (code === 'WH02') return 'deep-orange'
  if (code === 'WH03') return 'purple'
  return 'primary'
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

async function loadData() {
  await stockStore.fetchRecipes()
}

async function loadRecipeCost(recipeId) {
  const result = await stockStore.calculateRecipeCost(recipeId)
  if (result.success) {
    recipeCosts.value[recipeId] = result.totalCost
  }
}

function openCreateDialog() {
  isEditing.value = false
  form.value = getEmptyForm()
  showDialog.value = true
}

function editRecipe(recipe) {
  isEditing.value = true
  form.value = {
    id: recipe.id,
    sales_item_id: recipe.sales_item_id,
    target_warehouse_id: recipe.target_warehouse_id,
    recipe_name: recipe.recipe_name,
    description: recipe.description,
    yield_quantity: recipe.yield_quantity,
    yield_uom_id: recipe.yield_uom_id,
    is_active: recipe.is_active,
    lines: (recipe.recipe_lines || []).map((line) => ({
      temp_id: tempIdCounter++,
      item_id: line.item_id,
      quantity: line.quantity,
      uom_id: line.uom_id,
      unit_cost: line.unit_cost,
      notes: line.notes,
    })),
  }
  showDialog.value = true
}

async function submitForm() {
  const success = await formRef.value?.validate()
  if (!success) {
    $q.notify({ type: 'warning', message: 'Please fill in required fields' })
    return
  }

  if (form.value.lines.length === 0) {
    $q.notify({ type: 'warning', message: 'Please add at least one ingredient' })
    return
  }

  saving.value = true
  try {
    const payload = {
      sales_item_id: form.value.sales_item_id,
      target_warehouse_id: form.value.target_warehouse_id,
      recipe_name: form.value.recipe_name,
      description: form.value.description,
      yield_quantity: form.value.yield_quantity,
      yield_uom_id: form.value.yield_uom_id,
      is_active: form.value.is_active,
      created_by: authStore.user?.id,
    }

    const lines = form.value.lines.map((line) => ({
      item_id: line.item_id,
      quantity: line.quantity,
      uom_id: line.uom_id,
      unit_cost: line.unit_cost,
      notes: line.notes,
    }))

    let result
    if (isEditing.value) {
      result = await stockStore.updateRecipe(form.value.id, payload, lines)
    } else {
      result = await stockStore.createRecipe(payload, lines)
    }

    if (result.success) {
      $q.notify({
        type: 'positive',
        message: isEditing.value ? 'Recipe updated successfully' : 'Recipe created successfully',
      })
      showDialog.value = false
    } else {
      $q.notify({ type: 'negative', message: result.error })
    }
  } finally {
    saving.value = false
  }
}

function confirmDelete(recipe) {
  recipeToDelete.value = recipe
  showDeleteConfirm.value = true
}

async function deleteRecipe() {
  deleting.value = true
  try {
    const result = await stockStore.deleteRecipe(recipeToDelete.value.id)
    if (result.success) {
      $q.notify({ type: 'positive', message: 'Recipe deleted successfully' })
      showDeleteConfirm.value = false
    } else {
      $q.notify({ type: 'negative', message: result.error })
    }
  } finally {
    deleting.value = false
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

.ingredients-section {
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

.actions-cell {
  width: 100px;
}
</style>
