<template>
  <q-page class="sap-page">
    <!-- Toolbar -->
    <SAPToolbar
      title="Production Orders"
      icon="precision_manufacturing"
      :badge="productionOrders.length"
      add-label="New Production"
      @add="openCreateDialog"
      @refresh="loadData"
    />

    <!-- Stats Cards -->
    <div class="sap-page-content">
      <div class="row q-col-gutter-md q-mb-md">
        <div class="col-6 col-md-3">
          <SAPCard flat bordered class="cursor-pointer" @click="statusFilter = 'all'">
            <div class="stat-card" :class="{ active: statusFilter === 'all' }">
              <q-icon name="factory" size="28px" color="primary" />
              <div class="stat-info">
                <div class="stat-value">{{ productionOrders.length }}</div>
                <div class="stat-label">All Orders</div>
              </div>
            </div>
          </SAPCard>
        </div>
        <div class="col-6 col-md-3">
          <SAPCard flat bordered class="cursor-pointer" @click="statusFilter = 'Planned'">
            <div class="stat-card" :class="{ active: statusFilter === 'Planned' }">
              <q-icon name="schedule" size="28px" color="orange" />
              <div class="stat-info">
                <div class="stat-value">{{ plannedCount }}</div>
                <div class="stat-label">Planned</div>
              </div>
            </div>
          </SAPCard>
        </div>
        <div class="col-6 col-md-3">
          <SAPCard flat bordered class="cursor-pointer" @click="statusFilter = 'In Progress'">
            <div class="stat-card" :class="{ active: statusFilter === 'In Progress' }">
              <q-icon name="construction" size="28px" color="blue" />
              <div class="stat-info">
                <div class="stat-value">{{ inProgressCount }}</div>
                <div class="stat-label">In Progress</div>
              </div>
            </div>
          </SAPCard>
        </div>
        <div class="col-6 col-md-3">
          <SAPCard flat bordered class="cursor-pointer" @click="statusFilter = 'Finished'">
            <div class="stat-card" :class="{ active: statusFilter === 'Finished' }">
              <q-icon name="check_circle" size="28px" color="positive" />
              <div class="stat-info">
                <div class="stat-value">{{ finishedCount }}</div>
                <div class="stat-label">Finished</div>
              </div>
            </div>
          </SAPCard>
        </div>
      </div>

      <!-- Orders Table -->
      <SAPCard title="Production Orders" icon="list" no-padding>
        <SAPTable
          :rows="filteredOrders"
          :columns="columns"
          :loading="loading"
          row-key="id"
          @row-click="viewOrder"
        >
          <template #body-cell-doc_number="props">
            <q-td :props="props">
              <span class="doc-number">{{ props.value }}</span>
              <GoldenArrow @click="viewOrder(props.row)" />
            </q-td>
          </template>

          <template #body-cell-status="props">
            <q-td :props="props">
              <q-badge :color="getStatusColor(props.value)" :label="props.value" />
            </q-td>
          </template>

          <template #body-cell-actions="props">
            <q-td :props="props">
              <q-btn
                v-if="props.row.status === 'Planned'"
                flat
                dense
                round
                size="sm"
                icon="play_arrow"
                color="blue"
                @click.stop="startProduction(props.row)"
              >
                <q-tooltip>Start Production</q-tooltip>
              </q-btn>
              <q-btn
                v-if="props.row.status === 'In Progress'"
                flat
                dense
                round
                size="sm"
                icon="done_all"
                color="positive"
                @click.stop="openFinishDialog(props.row)"
              >
                <q-tooltip>Finish Production</q-tooltip>
              </q-btn>
              <q-btn flat dense round size="sm" icon="visibility" color="grey" />
            </q-td>
          </template>
        </SAPTable>
      </SAPCard>
    </div>

    <!-- Create Production Order Dialog -->
    <SAPDialog
      v-model="showCreateDialog"
      title="Create Production Order"
      icon="precision_manufacturing"
      width="800px"
      :loading="saving"
      confirm-label="Create Order"
      @confirm="createOrder"
    >
      <q-form ref="formRef" @submit.prevent>
        <div class="row q-col-gutter-md">
          <!-- Recipe Selection -->
          <div class="col-12">
            <SAPSelect
              v-model="form.recipe_id"
              label="Select Recipe (Menu Item)"
              :options="recipes"
              option-label="recipe_code"
              option-value="id"
              :rules="requiredRules"
              @update:model-value="onRecipeSelected"
            >
              <template #option="{ opt, itemProps }">
                <q-item v-bind="itemProps">
                  <q-item-section>
                    <q-item-label
                      >{{ opt.recipe_code }} - {{ opt.sales_item?.item_name }}</q-item-label
                    >
                    <q-item-label caption
                      >{{ opt.recipe_lines?.length || 0 }} components</q-item-label
                    >
                  </q-item-section>
                </q-item>
              </template>
            </SAPSelect>
          </div>

          <!-- Selected Recipe Info -->
          <div v-if="selectedRecipe" class="col-12">
            <SAPCard flat bordered>
              <div class="text-subtitle2 q-mb-sm">
                <q-icon name="restaurant_menu" class="q-mr-sm" />
                {{ selectedRecipe.sales_item?.item_name }}
              </div>
              <div class="text-caption text-grey q-mb-md">
                Components will be auto-deducted (backflushed) when production is finished
              </div>

              <!-- BOM Components Preview -->
              <q-table
                :rows="selectedRecipe.recipe_lines || []"
                :columns="componentColumns"
                flat
                dense
                bordered
                hide-pagination
              >
                <template #body-cell-available="props">
                  <q-td :props="props">
                    <q-badge
                      :color="
                        props.value >= props.row.quantity * (form.target_quantity || 1)
                          ? 'positive'
                          : 'negative'
                      "
                    >
                      {{ props.value }}
                    </q-badge>
                  </q-td>
                </template>
                <template #body-cell-required="props">
                  <q-td :props="props">
                    {{ (props.row.quantity * (form.target_quantity || 1)).toFixed(2) }}
                  </q-td>
                </template>
              </q-table>
            </SAPCard>
          </div>

          <div class="col-12 col-md-6">
            <SAPInput
              v-model.number="form.target_quantity"
              label="Production Quantity"
              type="number"
              min="1"
              :rules="requiredRules"
            />
          </div>
          <div class="col-12 col-md-6">
            <SAPSelect
              v-model="form.production_warehouse_id"
              label="Production Warehouse"
              :options="
                stockStore.warehouses.filter((w) => w.category === 'Production' || !w.category)
              "
              option-label="name"
              option-value="id"
              :rules="requiredRules"
            />
          </div>
          <div class="col-12 col-md-6">
            <SAPInput v-model="form.planned_start_date" label="Planned Start Date" type="date" />
          </div>
          <div class="col-12">
            <SAPInput v-model="form.remarks" label="Remarks" type="textarea" rows="2" />
          </div>
        </div>
      </q-form>
    </SAPDialog>

    <!-- View Order Dialog -->
    <SAPDialog
      v-model="showViewDialog"
      :title="`Production Order: ${selectedOrder?.doc_number || ''}`"
      icon="precision_manufacturing"
      width="900px"
      :show-default-footer="false"
    >
      <template v-if="selectedOrder">
        <div class="row q-col-gutter-md q-mb-md">
          <div class="col-4">
            <div class="detail-label">Status</div>
            <q-badge
              :color="getStatusColor(selectedOrder.status)"
              :label="selectedOrder.status"
              class="q-pa-sm"
            />
          </div>
          <div class="col-4">
            <div class="detail-label">Recipe</div>
            <div class="detail-value">{{ selectedOrder.recipe?.recipe_code }}</div>
          </div>
          <div class="col-4">
            <div class="detail-label">Finished Item</div>
            <div class="detail-value">{{ selectedOrder.finished_item?.item_name }}</div>
          </div>
          <div class="col-4">
            <div class="detail-label">Target Qty</div>
            <div class="detail-value">{{ selectedOrder.target_quantity }}</div>
          </div>
          <div class="col-4">
            <div class="detail-label">Actual Qty</div>
            <div class="detail-value">{{ selectedOrder.actual_quantity || '-' }}</div>
          </div>
          <div class="col-4">
            <div class="detail-label">Warehouse</div>
            <div class="detail-value">{{ selectedOrder.production_warehouse?.name }}</div>
          </div>
        </div>

        <div class="text-subtitle2 q-mb-sm">
          <q-icon name="inventory_2" class="q-mr-sm" />
          BOM Components
          <q-chip
            v-if="selectedOrder.status === 'Finished'"
            color="positive"
            text-color="white"
            size="sm"
          >
            Backflushed
          </q-chip>
        </div>

        <SAPTable
          :rows="selectedOrder.production_order_components || []"
          :columns="viewComponentColumns"
          :show-search="false"
          row-key="id"
          dense
        />

        <!-- Action Buttons -->
        <div class="q-mt-md text-right">
          <template v-if="selectedOrder.status === 'Planned'">
            <q-btn
              color="primary"
              label="Start Production"
              icon="play_arrow"
              @click="startProduction(selectedOrder)"
            />
          </template>
          <template v-else-if="selectedOrder.status === 'In Progress'">
            <q-btn
              color="positive"
              label="Finish Production"
              icon="done_all"
              @click="openFinishDialog(selectedOrder)"
            />
          </template>
        </div>
      </template>
    </SAPDialog>

    <!-- Finish Production Dialog -->
    <SAPDialog
      v-model="showFinishDialog"
      title="Product Finishing Note"
      icon="done_all"
      width="600px"
      :loading="finishing"
      confirm-label="Confirm Finish"
      @confirm="confirmFinish"
    >
      <template v-if="finishOrder">
        <div class="q-mb-md">
          <q-banner dense class="bg-blue-1 text-blue-8">
            <template #avatar>
              <q-icon name="info" />
            </template>
            When you confirm, the BOM components will be automatically deducted (backflushed) from
            stock, and the finished goods will be added to inventory.
          </q-banner>
        </div>

        <div class="row q-col-gutter-md">
          <div class="col-12">
            <div class="detail-label">Finishing Product</div>
            <div class="detail-value text-h6">{{ finishOrder.finished_item?.item_name }}</div>
          </div>
          <div class="col-6">
            <div class="detail-label">Target Quantity</div>
            <div class="detail-value">{{ finishOrder.target_quantity }}</div>
          </div>
          <div class="col-6">
            <SAPInput
              v-model.number="finishForm.actual_quantity"
              label="Actual Quantity Produced"
              type="number"
              min="1"
              :rules="requiredRules"
            />
          </div>
          <div class="col-12">
            <q-checkbox v-model="finishForm.confirmation" color="positive">
              I confirm that production is complete and components should be backflushed
            </q-checkbox>
          </div>
        </div>
      </template>
    </SAPDialog>
  </q-page>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useQuasar } from 'quasar'
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
const stockStore = useStockStore()
const authStore = useAuthStore()

// State
const loading = ref(false)
const saving = ref(false)
const finishing = ref(false)
const productionOrders = ref([])
const recipes = ref([])
const statusFilter = ref('all')
const showCreateDialog = ref(false)
const showViewDialog = ref(false)
const showFinishDialog = ref(false)
const formRef = ref(null)
const selectedRecipe = ref(null)
const selectedOrder = ref(null)
const finishOrder = ref(null)

const form = ref({
  recipe_id: null,
  target_quantity: 1,
  production_warehouse_id: null,
  planned_start_date: new Date().toISOString().split('T')[0],
  remarks: '',
})

const finishForm = ref({
  actual_quantity: 0,
  confirmation: false,
})

const requiredRules = [(val) => !!val || 'Required']

// Computed
const plannedCount = computed(
  () => productionOrders.value.filter((o) => o.status === 'Planned').length,
)
const inProgressCount = computed(
  () => productionOrders.value.filter((o) => o.status === 'In Progress').length,
)
const finishedCount = computed(
  () => productionOrders.value.filter((o) => o.status === 'Finished').length,
)

const filteredOrders = computed(() => {
  if (statusFilter.value === 'all') return productionOrders.value
  return productionOrders.value.filter((o) => o.status === statusFilter.value)
})

// Columns
const columns = [
  { name: 'doc_number', label: 'Order No.', field: 'doc_number', sortable: true, align: 'left' },
  {
    name: 'finished_item',
    label: 'Finished Item',
    field: (row) => row.finished_item?.item_name,
    align: 'left',
  },
  { name: 'target_quantity', label: 'Target Qty', field: 'target_quantity', align: 'right' },
  { name: 'actual_quantity', label: 'Actual Qty', field: 'actual_quantity', align: 'right' },
  {
    name: 'warehouse',
    label: 'Warehouse',
    field: (row) => row.production_warehouse?.name,
    align: 'left',
  },
  { name: 'status', label: 'Status', field: 'status', align: 'center' },
  { name: 'actions', label: 'Actions', align: 'center' },
]

const componentColumns = [
  { name: 'item_code', label: 'Item Code', field: (row) => row.item?.item_code, align: 'left' },
  { name: 'item_name', label: 'Item Name', field: (row) => row.item?.item_name, align: 'left' },
  { name: 'quantity', label: 'Per Unit', field: 'quantity', align: 'right' },
  { name: 'required', label: 'Required', align: 'right' },
  {
    name: 'available',
    label: 'Available',
    field: (row) => row.item?.available || 0,
    align: 'center',
  },
]

const viewComponentColumns = [
  { name: 'item_code', label: 'Item Code', field: 'item_code', align: 'left' },
  { name: 'item_name', label: 'Item Name', field: (row) => row.item?.item_name, align: 'left' },
  { name: 'required', label: 'Required', field: 'required_quantity', align: 'right' },
  { name: 'issued', label: 'Issued', field: 'issued_quantity', align: 'right' },
  {
    name: 'backflushed',
    label: 'Backflushed',
    field: 'backflushed',
    align: 'center',
    format: (val) => (val ? '✓' : '-'),
  },
]

// Methods
function getStatusColor(status) {
  const colors = {
    Planned: 'orange',
    Released: 'cyan',
    'In Progress': 'blue',
    Finished: 'positive',
    Cancelled: 'grey',
  }
  return colors[status] || 'grey'
}

async function loadData() {
  loading.value = true
  try {
    await Promise.all([stockStore.fetchWarehouses(), loadRecipes(), loadProductionOrders()])
  } finally {
    loading.value = false
  }
}

async function loadRecipes() {
  const { data } = await supabase
    .from('recipes')
    .select(
      `
      *,
      sales_item:items!sales_item_id(id, item_code, item_name),
      recipe_lines(
        *,
        item:items(id, item_code, item_name, warehouse_stock(quantity_on_hand, quantity_committed))
      )
    `,
    )
    .eq('is_active', true)
    .order('recipe_code')

  // Calculate available for each component
  recipes.value = (data || []).map((recipe) => ({
    ...recipe,
    recipe_lines: recipe.recipe_lines?.map((line) => {
      const stock = line.item?.warehouse_stock?.[0]
      return {
        ...line,
        item: {
          ...line.item,
          available: stock ? stock.quantity_on_hand - stock.quantity_committed : 0,
        },
      }
    }),
  }))
}

async function loadProductionOrders() {
  const { data } = await supabase
    .from('production_orders')
    .select(
      `
      *,
      recipe:recipes(recipe_code),
      finished_item:items!finished_item_id(item_code, item_name),
      production_warehouse:warehouses!production_warehouse_id(name),
      production_order_components(
        *, item:items(item_code, item_name)
      )
    `,
    )
    .order('created_at', { ascending: false })

  productionOrders.value = data || []
}

function openCreateDialog() {
  form.value = {
    recipe_id: null,
    target_quantity: 1,
    production_warehouse_id:
      stockStore.warehouses.find((w) => w.category === 'Production')?.id ||
      stockStore.warehouses[0]?.id,
    planned_start_date: new Date().toISOString().split('T')[0],
    remarks: '',
  }
  selectedRecipe.value = null
  showCreateDialog.value = true
}

function onRecipeSelected(recipeId) {
  selectedRecipe.value = recipes.value.find((r) => r.id === recipeId) || null
}

async function createOrder() {
  const valid = await formRef.value.validate()
  if (!valid || !selectedRecipe.value) return

  saving.value = true
  try {
    // Generate doc number
    const { data: docNum } = await supabase.rpc('generate_production_order_number')

    // Create production order
    const { data: order, error } = await supabase
      .from('production_orders')
      .insert({
        doc_number: docNum,
        recipe_id: form.value.recipe_id,
        finished_item_id: selectedRecipe.value.sales_item?.id,
        production_warehouse_id: form.value.production_warehouse_id,
        target_quantity: form.value.target_quantity,
        planned_start_date: form.value.planned_start_date,
        remarks: form.value.remarks,
        created_by: authStore.profile?.id,
        status: 'Planned',
      })
      .select()
      .single()

    if (error) throw error

    // Create components from recipe
    const components = selectedRecipe.value.recipe_lines?.map((line, idx) => ({
      production_order_id: order.id,
      line_num: idx + 1,
      item_id: line.item?.id,
      item_code: line.item?.item_code,
      required_quantity: line.quantity * form.value.target_quantity,
      uom_id: line.uom_id,
      warehouse_id: form.value.production_warehouse_id,
    }))

    if (components?.length) {
      await supabase.from('production_order_components').insert(components)
    }

    $q.notify({ type: 'positive', message: 'Production order created' })
    showCreateDialog.value = false
    loadProductionOrders()
  } catch (error) {
    $q.notify({ type: 'negative', message: error.message })
  } finally {
    saving.value = false
  }
}

function viewOrder(row) {
  selectedOrder.value = row
  showViewDialog.value = true
}

async function startProduction(order) {
  const { error } = await supabase
    .from('production_orders')
    .update({
      status: 'In Progress',
      actual_start_date: new Date().toISOString().split('T')[0],
    })
    .eq('id', order.id)

  if (!error) {
    $q.notify({ type: 'positive', message: 'Production started' })
    loadProductionOrders()
    showViewDialog.value = false
  }
}

function openFinishDialog(order) {
  finishOrder.value = order
  finishForm.value = {
    actual_quantity: order.target_quantity,
    confirmation: false,
  }
  showViewDialog.value = false
  showFinishDialog.value = true
}

async function confirmFinish() {
  if (!finishForm.value.confirmation) {
    $q.notify({ type: 'warning', message: 'Please confirm to proceed' })
    return
  }

  finishing.value = true
  try {
    // Update status to Finished - the trigger will handle backflushing
    const { error } = await supabase
      .from('production_orders')
      .update({
        status: 'Finished',
        actual_quantity: finishForm.value.actual_quantity,
        finished_by: authStore.profile?.id,
      })
      .eq('id', finishOrder.value.id)

    if (error) throw error

    $q.notify({
      type: 'positive',
      message: 'Production finished! Components have been backflushed.',
    })
    showFinishDialog.value = false
    loadProductionOrders()
  } catch (error) {
    $q.notify({ type: 'negative', message: error.message })
  } finally {
    finishing.value = false
  }
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

.detail-label {
  font-size: 11px;
  color: #666;
  margin-bottom: 4px;
}

.detail-value {
  font-size: 14px;
  font-weight: 500;
}
</style>
