<template>
  <q-page class="sap-page">
    <SAPToolbar
      title="Price Lists"
      icon="sell"
      :badge="inventoryStore.priceLists.length"
      add-label="New Price List"
      :show-export="true"
      @add="openCreateDialog"
      @refresh="loadData"
    />

    <div class="sap-page-content">
      <div class="row q-col-gutter-md">
        <!-- Price Lists Panel -->
        <div class="col-12 col-md-4">
          <SAPCard title="Price Lists" icon="list" no-padding style="height: calc(100vh - 200px)">
            <q-list separator dense class="price-list-nav">
              <q-item
                v-for="pl in inventoryStore.priceLists"
                :key="pl.id"
                clickable
                :active="selectedPriceList?.id === pl.id"
                active-class="bg-primary-1"
                @click="selectPriceList(pl)"
              >
                <q-item-section avatar>
                  <q-icon name="sell" :color="pl.is_active ? 'primary' : 'grey'" />
                </q-item-section>
                <q-item-section>
                  <q-item-label>{{ pl.price_list_name }}</q-item-label>
                  <q-item-label caption>{{ pl.price_list_code }} • {{ pl.currency }}</q-item-label>
                </q-item-section>
                <q-item-section side>
                  <div class="row items-center">
                    <q-icon
                      v-if="pl.is_default"
                      name="star"
                      color="warning"
                      size="16px"
                      class="q-mr-xs"
                    />
                    <q-badge v-if="!pl.is_active" color="grey" label="Inactive" />
                  </div>
                </q-item-section>
                <q-item-section side>
                  <q-btn flat dense round size="sm" icon="edit" @click.stop="editPriceList(pl)" />
                </q-item-section>
              </q-item>
            </q-list>
          </SAPCard>
        </div>

        <!-- Price List Items Panel -->
        <div class="col-12 col-md-8">
          <SAPCard
            :title="
              selectedPriceList
                ? `Items - ${selectedPriceList.price_list_name}`
                : 'Select a Price List'
            "
            icon="inventory_2"
            no-padding
          >
            <template #header-right v-if="selectedPriceList">
              <q-btn color="primary" dense icon="add" label="Add Item" @click="openAddItemDialog" />
            </template>

            <div v-if="!selectedPriceList" class="text-center q-pa-xl text-grey-6">
              <q-icon name="touch_app" size="64px" class="q-mb-md" />
              <div>Select a price list to view items</div>
            </div>

            <SAPTable
              v-else
              :rows="inventoryStore.priceListItems"
              :columns="itemColumns"
              :loading="loadingItems"
              row-key="id"
            >
              <template #body-cell-item="props">
                <q-td :props="props">
                  <div class="row items-center no-wrap">
                    <span class="text-bold">{{ props.row.item?.item_code }}</span>
                    <GoldenArrow @click="viewItem(props.row.item)" />
                  </div>
                  <div class="text-caption text-grey-7">{{ props.row.item?.item_name }}</div>
                </q-td>
              </template>

              <template #body-cell-price="props">
                <q-td :props="props" class="text-right">
                  <q-input
                    v-model.number="props.row.price"
                    type="number"
                    dense
                    outlined
                    style="width: 110px"
                    @blur="updateItemPrice(props.row)"
                  />
                </q-td>
              </template>

              <template #body-cell-discount="props">
                <q-td :props="props" class="text-right">
                  <q-input
                    v-model.number="props.row.discount_percent"
                    type="number"
                    dense
                    outlined
                    suffix="%"
                    style="width: 80px"
                    @blur="updateItemPrice(props.row)"
                  />
                </q-td>
              </template>

              <template #body-cell-net_price="props">
                <q-td :props="props" class="text-right text-bold text-positive">
                  {{ formatCurrency(getNetPrice(props.row)) }}
                </q-td>
              </template>

              <template #body-cell-is_active="props">
                <q-td :props="props" class="text-center">
                  <q-toggle
                    v-model="props.row.is_active"
                    dense
                    @update:model-value="updateItemPrice(props.row)"
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
                    icon="delete"
                    color="negative"
                    @click.stop="removeItem(props.row)"
                  >
                    <q-tooltip>Remove</q-tooltip>
                  </q-btn>
                </q-td>
              </template>
            </SAPTable>
          </SAPCard>
        </div>
      </div>
    </div>

    <!-- Create/Edit Price List Dialog -->
    <SAPDialog
      v-model="showPriceListDialog"
      :title="isEditing ? 'Edit Price List' : 'New Price List'"
      icon="sell"
      width="600px"
      :loading="saving"
      :confirm-label="isEditing ? 'Update' : 'Create'"
      @confirm="savePriceList"
    >
      <q-form ref="formRef">
        <div class="row q-col-gutter-md">
          <div class="col-12 col-md-6">
            <SAPInput
              v-model="form.price_list_code"
              label="Price List Code"
              placeholder="PL01"
              required
              :rules="requiredRules"
            />
          </div>
          <div class="col-12 col-md-6">
            <SAPInput
              v-model="form.price_list_name"
              label="Price List Name"
              placeholder="Standard Retail"
              required
              :rules="requiredRules"
            />
          </div>
          <div class="col-12 col-md-6">
            <label class="sap-label">Base Price List</label>
            <SAPSelect
              v-model="form.base_price_list_id"
              :options="inventoryStore.priceLists.filter((p) => p.id !== form.id)"
              option-label="price_list_name"
              option-value="id"
              placeholder="None (Manual Entry)"
              clearable
            />
          </div>
          <div class="col-12 col-md-6">
            <SAPInput
              v-model.number="form.factor"
              label="Factor (Multiplier)"
              type="number"
              step="0.01"
              min="0"
            />
          </div>
          <div class="col-12 col-md-6">
            <SAPInput v-model="form.valid_from" label="Valid From" type="date" />
          </div>
          <div class="col-12 col-md-6">
            <SAPInput v-model="form.valid_to" label="Valid To" type="date" />
          </div>
          <div class="col-12">
            <SAPInput v-model="form.notes" label="Notes" type="textarea" rows="2" />
          </div>
          <div class="col-12">
            <div class="row q-gutter-md">
              <q-checkbox v-model="form.is_active" label="Active" dense />
              <q-checkbox v-model="form.is_default" label="Default Price List" dense />
            </div>
          </div>
        </div>
      </q-form>
    </SAPDialog>

    <!-- Add Item to Price List Dialog -->
    <SAPDialog
      v-model="showAddItemDialog"
      title="Add Item to Price List"
      icon="add_shopping_cart"
      width="700px"
      :loading="saving"
      confirm-label="Add"
      @confirm="addItemToPriceList"
    >
      <q-form ref="addItemFormRef">
        <div class="row q-col-gutter-md">
          <div class="col-12">
            <label class="sap-label required">Item</label>
            <SAPSelect
              v-model="itemForm.item_id"
              :options="availableItems"
              option-label="item_name"
              option-value="id"
              searchable
              :rules="requiredRules"
            >
              <template #option="{ opt }">
                <q-item dense>
                  <q-item-section>
                    <q-item-label>{{ opt.item_code }} - {{ opt.item_name }}</q-item-label>
                    <q-item-label caption
                      >Base Price: {{ formatCurrency(opt.selling_price) }}</q-item-label
                    >
                  </q-item-section>
                </q-item>
              </template>
            </SAPSelect>
          </div>
          <div class="col-12 col-md-6">
            <SAPInput
              v-model.number="itemForm.price"
              label="Price"
              type="number"
              step="0.01"
              min="0"
              required
              :rules="requiredRules"
            />
          </div>
          <div class="col-12 col-md-6">
            <SAPInput
              v-model.number="itemForm.discount_percent"
              label="Discount %"
              type="number"
              step="0.1"
              min="0"
              max="100"
            />
          </div>
          <div class="col-12 col-md-6">
            <SAPInput
              v-model.number="itemForm.min_quantity"
              label="Min Quantity"
              type="number"
              min="1"
            />
          </div>
          <div class="col-12 col-md-6">
            <SAPInput
              v-model.number="itemForm.max_quantity"
              label="Max Quantity"
              type="number"
              min="1"
            />
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
import { supabase } from 'src/boot/supabase'
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
const showPriceListDialog = ref(false)
const showAddItemDialog = ref(false)
const isEditing = ref(false)
const saving = ref(false)
const loadingItems = ref(false)
const formRef = ref(null)
const addItemFormRef = ref(null)
const selectedPriceList = ref(null)

const form = ref(getEmptyForm())
const itemForm = ref(getEmptyItemForm())

const itemColumns = [
  { name: 'item', label: 'Item', field: 'item', align: 'left', style: 'width: 300px' },
  { name: 'uom', label: 'UoM', field: (row) => row.uom?.code || '—', align: 'center' },
  { name: 'min_quantity', label: 'Min Qty', field: 'min_quantity', align: 'right' },
  {
    name: 'max_quantity',
    label: 'Max Qty',
    field: (row) => row.max_quantity || '—',
    align: 'right',
  },
  { name: 'price', label: 'Price', field: 'price', align: 'right' },
  { name: 'discount', label: 'Discount', field: 'discount_percent', align: 'right' },
  { name: 'net_price', label: 'Net Price', field: 'net_price', align: 'right' },
  { name: 'is_active', label: 'Active', field: 'is_active', align: 'center' },
  { name: 'actions', label: '', field: 'actions', align: 'center' },
]

const requiredRules = [(val) => !!val || val === 0 || 'Required']

// Computed
const availableItems = computed(() => {
  const existingIds = inventoryStore.priceListItems.map((i) => i.item_id)
  return stockStore.activeItems.filter((i) => !existingIds.includes(i.id))
})

// Methods
function getEmptyForm() {
  return {
    price_list_code: '',
    price_list_name: '',
    base_price_list_id: null,
    currency: 'LKR',
    factor: 1,
    valid_from: null,
    valid_to: null,
    notes: '',
    is_active: true,
    is_default: false,
  }
}

function getEmptyItemForm() {
  return {
    item_id: null,
    price: 0,
    discount_percent: 0,
    min_quantity: 1,
    max_quantity: null,
    is_active: true,
  }
}

function formatCurrency(value) {
  if (value == null) return '—'
  return new Intl.NumberFormat('en-US', { style: 'currency', currency: 'LKR' }).format(value)
}

function getNetPrice(item) {
  if (!item.price) return 0
  return item.price * (1 - (item.discount_percent || 0) / 100)
}

async function loadData() {
  await Promise.all([stockStore.initializeStore(), inventoryStore.fetchPriceLists()])
  if (inventoryStore.priceLists.length > 0 && !selectedPriceList.value) {
    selectPriceList(inventoryStore.priceLists[0])
  }
}

async function selectPriceList(pl) {
  selectedPriceList.value = pl
  loadingItems.value = true
  await inventoryStore.fetchPriceListItems(pl.id)
  loadingItems.value = false
}

function openCreateDialog() {
  isEditing.value = false
  form.value = getEmptyForm()
  showPriceListDialog.value = true
}

function editPriceList(pl) {
  isEditing.value = true
  form.value = { ...pl }
  showPriceListDialog.value = true
}

async function savePriceList() {
  const valid = await formRef.value?.validate()
  if (!valid) return

  saving.value = true
  try {
    let result
    if (isEditing.value) {
      const { data, error } = await supabase
        .from('price_lists')
        .update({ ...form.value, updated_at: new Date().toISOString() })
        .eq('id', form.value.id)
        .select()
        .single()
      if (error) throw error
      result = { success: true, data }
    } else {
      result = await inventoryStore.createPriceList(form.value)
    }

    if (result.success) {
      $q.notify({
        type: 'positive',
        message: isEditing.value ? 'Price list updated' : 'Price list created',
        position: 'top',
      })
      showPriceListDialog.value = false
      await inventoryStore.fetchPriceLists()
    } else {
      $q.notify({ type: 'negative', message: result.error, position: 'top' })
    }
  } catch (err) {
    $q.notify({ type: 'negative', message: err.message, position: 'top' })
  } finally {
    saving.value = false
  }
}

function openAddItemDialog() {
  itemForm.value = getEmptyItemForm()
  showAddItemDialog.value = true
}

async function addItemToPriceList() {
  const valid = await addItemFormRef.value?.validate()
  if (!valid) return

  saving.value = true
  try {
    const result = await inventoryStore.addPriceListItem({
      ...itemForm.value,
      price_list_id: selectedPriceList.value.id,
    })

    if (result.success) {
      $q.notify({ type: 'positive', message: 'Item added to price list', position: 'top' })
      showAddItemDialog.value = false
    } else {
      $q.notify({ type: 'negative', message: result.error, position: 'top' })
    }
  } finally {
    saving.value = false
  }
}

async function updateItemPrice(item) {
  try {
    await supabase
      .from('price_list_items')
      .update({
        price: item.price,
        discount_percent: item.discount_percent,
        is_active: item.is_active,
        updated_at: new Date().toISOString(),
      })
      .eq('id', item.id)
  } catch (err) {
    $q.notify({ type: 'negative', message: err.message, position: 'top' })
  }
}

async function removeItem(item) {
  $q.dialog({
    title: 'Remove Item',
    message: 'Remove this item from the price list?',
    cancel: true,
  }).onOk(async () => {
    try {
      await supabase.from('price_list_items').delete().eq('id', item.id)
      await inventoryStore.fetchPriceListItems(selectedPriceList.value.id)
      $q.notify({ type: 'positive', message: 'Item removed', position: 'top' })
    } catch (err) {
      $q.notify({ type: 'negative', message: err.message, position: 'top' })
    }
  })
}

function viewItem(item) {
  $q.notify({ type: 'info', message: `Navigate to item: ${item?.item_code}`, position: 'top' })
}

onMounted(loadData)
</script>

<style lang="scss" scoped>
.price-list-nav {
  max-height: calc(100vh - 280px);
  overflow-y: auto;
}

.bg-primary-1 {
  background: rgba(var(--q-primary-rgb), 0.08);
}

.actions-cell {
  white-space: nowrap;
}
</style>
