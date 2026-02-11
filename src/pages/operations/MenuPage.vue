<template>
  <q-page class="menu-page">
    <div class="page-header">
      <h1 class="page-title">Menu Management</h1>
      <p class="page-subtitle">Configure menu items and categories</p>
    </div>

    <q-tabs v-model="activeTab" class="menu-tabs" align="left" indicator-color="primary">
      <q-tab name="items" label="Menu Items" icon="restaurant_menu" />
      <q-tab name="categories" label="Categories" icon="category" />
      <q-tab name="availability" label="Availability" icon="schedule" />
    </q-tabs>

    <q-tab-panels v-model="activeTab" animated>
      <!-- Menu Items Tab -->
      <q-tab-panel name="items">
        <div class="panel-header">
          <q-input
            v-model="itemSearch"
            placeholder="Search items..."
            outlined
            dense
            class="search-input"
          >
            <template v-slot:prepend><q-icon name="search" /></template>
          </q-input>
          <q-select
            v-model="filterCategory"
            :options="categoryOptions"
            label="Category"
            outlined
            dense
            class="filter-select"
          />
          <q-toggle v-model="showServableOnly" label="Servable Only" />
        </div>

        <q-table
          :rows="filteredItems"
          :columns="itemColumns"
          row-key="id"
          :loading="loading"
          :pagination="{ rowsPerPage: 15 }"
          flat
          bordered
        >
          <template v-slot:body-cell-item_identity="props">
            <q-td :props="props">
              <q-badge :color="props.row.item_identity === 'Servable' ? 'positive' : 'grey'">
                {{ props.row.item_identity }}
              </q-badge>
            </q-td>
          </template>

          <template v-slot:body-cell-selling_price="props">
            <q-td :props="props">
              <span class="price">Rs. {{ props.row.selling_price?.toFixed(2) }}</span>
            </q-td>
          </template>

          <template v-slot:body-cell-is_active="props">
            <q-td :props="props">
              <q-toggle
                :model-value="props.row.is_active"
                @update:model-value="toggleActive(props.row)"
                color="positive"
              />
            </q-td>
          </template>

          <template v-slot:body-cell-actions="props">
            <q-td :props="props">
              <q-btn
                flat
                round
                icon="edit"
                size="sm"
                @click="editItem(props.row)"
                color="primary"
              />
              <q-btn
                flat
                round
                icon="visibility"
                size="sm"
                @click="viewRecipe(props.row)"
                color="secondary"
              />
            </q-td>
          </template>
        </q-table>
      </q-tab-panel>

      <!-- Categories Tab -->
      <q-tab-panel name="categories">
        <div class="panel-header">
          <q-btn
            color="primary"
            icon="add"
            label="Add Category"
            @click="showCategoryDialog = true"
          />
        </div>

        <div class="categories-grid">
          <q-card v-for="cat in categories" :key="cat.id" class="category-card">
            <q-card-section class="category-header">
              <q-icon :name="cat.icon || 'category'" size="32px" color="primary" />
              <div class="category-info">
                <h3>{{ cat.name }}</h3>
                <p>{{ cat.item_count || 0 }} items</p>
              </div>
            </q-card-section>
            <q-card-actions>
              <q-btn flat icon="edit" label="Edit" size="sm" @click="editCategory(cat)" />
              <q-btn
                flat
                icon="delete"
                label="Delete"
                size="sm"
                color="negative"
                @click="deleteCategory(cat)"
              />
            </q-card-actions>
          </q-card>
        </div>
      </q-tab-panel>

      <!-- Availability Tab -->
      <q-tab-panel name="availability">
        <q-banner class="bg-info text-white q-mb-md">
          <template v-slot:avatar><q-icon name="info" /></template>
          Mark items as unavailable when out of stock. This hides them from the customer menu.
        </q-banner>

        <div class="availability-list">
          <q-card v-for="item in servableItems" :key="item.id" class="availability-card">
            <q-card-section horizontal>
              <q-card-section class="col-8">
                <div class="item-code">{{ item.item_code }}</div>
                <div class="item-name">{{ item.item_name }}</div>
                <div class="item-category">{{ item.category_name }}</div>
              </q-card-section>
              <q-card-section class="col-4 flex items-center justify-end">
                <div class="availability-toggle">
                  <span :class="{ available: item.is_available !== false }">
                    {{ item.is_available !== false ? 'Available' : 'Unavailable' }}
                  </span>
                  <q-toggle
                    :model-value="item.is_available !== false"
                    @update:model-value="toggleAvailability(item, $event)"
                    color="positive"
                  />
                </div>
              </q-card-section>
            </q-card-section>
          </q-card>
        </div>
      </q-tab-panel>
    </q-tab-panels>

    <!-- Category Dialog -->
    <q-dialog v-model="showCategoryDialog">
      <q-card style="min-width: 400px">
        <q-card-section>
          <div class="text-h6">{{ editingCategory ? 'Edit' : 'Add' }} Category</div>
        </q-card-section>
        <q-card-section>
          <q-input
            v-model="categoryForm.name"
            label="Category Name"
            outlined
            dense
            class="q-mb-md"
          />
          <q-input
            v-model="categoryForm.description"
            label="Description"
            outlined
            dense
            type="textarea"
          />
        </q-card-section>
        <q-card-actions align="right">
          <q-btn flat label="Cancel" v-close-popup />
          <q-btn color="primary" label="Save" @click="saveCategory" />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <!-- Item Dialog -->
    <q-dialog v-model="showItemDialog" full-width>
      <q-card style="max-width: 600px">
        <q-card-section>
          <div class="text-h6">Edit Menu Item</div>
        </q-card-section>
        <q-card-section v-if="editingItem">
          <q-form class="row q-col-gutter-md">
            <div class="col-6">
              <q-input v-model="editingItem.item_code" label="Item Code" outlined dense readonly />
            </div>
            <div class="col-6">
              <q-input v-model="editingItem.item_name" label="Item Name" outlined dense />
            </div>
            <div class="col-6">
              <q-input
                v-model.number="editingItem.selling_price"
                label="Selling Price"
                type="number"
                outlined
                dense
                prefix="Rs."
              />
            </div>
            <div class="col-6">
              <q-select
                v-model="editingItem.category_id"
                :options="categoryOptions.filter((c) => c.value)"
                emit-value
                map-options
                label="Category"
                outlined
                dense
              />
            </div>
            <div class="col-6">
              <q-select
                v-model="editingItem.item_identity"
                :options="['Servable', 'Non-Servable']"
                label="Item Identity"
                outlined
                dense
              />
            </div>
            <div class="col-6">
              <q-toggle v-model="editingItem.is_sales_item" label="Is Sales Item" />
            </div>
            <div class="col-12">
              <q-input
                v-model="editingItem.description"
                label="Description"
                outlined
                dense
                type="textarea"
              />
            </div>
          </q-form>
        </q-card-section>
        <q-card-actions align="right">
          <q-btn flat label="Cancel" v-close-popup />
          <q-btn color="primary" label="Save Changes" @click="saveItem" />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase } from 'src/boot/supabase'
import { useQuasar } from 'quasar'

const $q = useQuasar()

// State
const items = ref([])
const categories = ref([])
const loading = ref(true)
const activeTab = ref('items')
const itemSearch = ref('')
const filterCategory = ref(null)
const showServableOnly = ref(false)
const showCategoryDialog = ref(false)
const showItemDialog = ref(false)
const editingCategory = ref(null)
const editingItem = ref(null)
const categoryForm = ref({ name: '', description: '' })

// Columns
const itemColumns = [
  { name: 'item_code', label: 'Code', field: 'item_code', sortable: true },
  { name: 'item_name', label: 'Name', field: 'item_name', sortable: true },
  { name: 'category_name', label: 'Category', field: 'category_name', sortable: true },
  { name: 'selling_price', label: 'Price', field: 'selling_price', sortable: true },
  { name: 'item_identity', label: 'Type', field: 'item_identity' },
  { name: 'is_active', label: 'Active', field: 'is_active' },
  { name: 'actions', label: 'Actions', field: 'actions' },
]

// Computed
const categoryOptions = computed(() => [
  { label: 'All Categories', value: null },
  ...categories.value.map((c) => ({ label: c.name, value: c.id })),
])

const filteredItems = computed(() => {
  let result = items.value

  if (itemSearch.value) {
    const search = itemSearch.value.toLowerCase()
    result = result.filter(
      (i) =>
        i.item_name.toLowerCase().includes(search) || i.item_code.toLowerCase().includes(search),
    )
  }

  if (filterCategory.value) {
    result = result.filter((i) => i.category_id === filterCategory.value)
  }

  if (showServableOnly.value) {
    result = result.filter((i) => i.item_identity === 'Servable')
  }

  return result
})

const servableItems = computed(() => items.value.filter((i) => i.item_identity === 'Servable'))

// Methods
const fetchItems = async () => {
  loading.value = true
  try {
    const { data, error } = await supabase
      .from('items')
      .select('*, category:category_id(name)')
      .order('item_name')

    if (error) throw error

    items.value = data.map((i) => ({
      ...i,
      category_name: i.category?.name || 'Uncategorized',
    }))
  } catch (err) {
    console.error('Error fetching items:', err)
    $q.notify({ type: 'negative', message: 'Failed to load items' })
  } finally {
    loading.value = false
  }
}

const fetchCategories = async () => {
  try {
    const { data, error } = await supabase.from('item_categories').select('*').order('name')

    if (error) throw error
    categories.value = data || []
  } catch (err) {
    console.error('Error fetching categories:', err)
  }
}

const toggleActive = async (item) => {
  try {
    const { error } = await supabase
      .from('items')
      .update({ is_active: !item.is_active })
      .eq('id', item.id)

    if (error) throw error

    item.is_active = !item.is_active
    $q.notify({ type: 'positive', message: 'Item updated' })
  } catch (err) {
    console.error('Error updating item:', err)
    $q.notify({ type: 'negative', message: 'Failed to update item' })
  }
}

const toggleAvailability = async (item, available) => {
  try {
    const { error } = await supabase
      .from('items')
      .update({ is_available: available })
      .eq('id', item.id)

    if (error) throw error

    item.is_available = available
    $q.notify({
      type: 'positive',
      message: `Item marked as ${available ? 'available' : 'unavailable'}`,
    })
  } catch (err) {
    console.error('Error updating availability:', err)
    $q.notify({ type: 'negative', message: 'Failed to update availability' })
  }
}

const editItem = (item) => {
  editingItem.value = { ...item }
  showItemDialog.value = true
}

const saveItem = async () => {
  try {
    const { error } = await supabase
      .from('items')
      .update({
        item_name: editingItem.value.item_name,
        selling_price: editingItem.value.selling_price,
        category_id: editingItem.value.category_id,
        item_identity: editingItem.value.item_identity,
        is_sales_item: editingItem.value.is_sales_item,
        description: editingItem.value.description,
      })
      .eq('id', editingItem.value.id)

    if (error) throw error

    $q.notify({ type: 'positive', message: 'Item updated successfully' })
    showItemDialog.value = false
    fetchItems()
  } catch (err) {
    console.error('Error saving item:', err)
    $q.notify({ type: 'negative', message: 'Failed to save item' })
  }
}

const viewRecipe = () => {
  $q.notify({ type: 'info', message: 'Recipe view coming soon' })
}

const editCategory = (cat) => {
  editingCategory.value = cat
  categoryForm.value = { name: cat.name, description: cat.description }
  showCategoryDialog.value = true
}

const deleteCategory = async (cat) => {
  $q.dialog({
    title: 'Delete Category',
    message: `Are you sure you want to delete "${cat.name}"?`,
    cancel: true,
    persistent: true,
  }).onOk(async () => {
    try {
      const { error } = await supabase.from('item_categories').delete().eq('id', cat.id)
      if (error) throw error
      $q.notify({ type: 'positive', message: 'Category deleted' })
      fetchCategories()
    } catch {
      $q.notify({ type: 'negative', message: 'Failed to delete category' })
    }
  })
}

const saveCategory = async () => {
  try {
    if (editingCategory.value) {
      const { error } = await supabase
        .from('item_categories')
        .update({ name: categoryForm.value.name, description: categoryForm.value.description })
        .eq('id', editingCategory.value.id)
      if (error) throw error
    } else {
      const { error } = await supabase.from('item_categories').insert([categoryForm.value])
      if (error) throw error
    }

    $q.notify({ type: 'positive', message: 'Category saved' })
    showCategoryDialog.value = false
    editingCategory.value = null
    categoryForm.value = { name: '', description: '' }
    fetchCategories()
  } catch {
    $q.notify({ type: 'negative', message: 'Failed to save category' })
  }
}

// Lifecycle
onMounted(() => {
  fetchItems()
  fetchCategories()
})
</script>

<style lang="scss" scoped>
.menu-page {
  padding: 24px;
}

.page-header {
  margin-bottom: 24px;

  .page-title {
    font-size: 1.8rem;
    font-weight: 700;
    color: #1a1a2e;
    margin: 0;
  }

  .page-subtitle {
    color: #666;
    margin: 4px 0 0;
  }
}

.menu-tabs {
  margin-bottom: 24px;
}

.panel-header {
  display: flex;
  gap: 16px;
  margin-bottom: 20px;
  flex-wrap: wrap;
  align-items: center;

  .search-input {
    width: 300px;
  }

  .filter-select {
    width: 200px;
  }
}

.price {
  font-weight: 700;
  color: #1a1a2e;
}

.categories-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(250px, 1fr));
  gap: 16px;
}

.category-card {
  border-radius: 12px;
  transition: all 0.3s;

  &:hover {
    transform: translateY(-4px);
    box-shadow: 0 8px 24px rgba(0, 0, 0, 0.12);
  }

  .category-header {
    display: flex;
    align-items: center;
    gap: 16px;
  }

  .category-info {
    h3 {
      margin: 0;
      font-weight: 600;
    }

    p {
      margin: 4px 0 0;
      color: #666;
      font-size: 0.9rem;
    }
  }
}

.availability-list {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.availability-card {
  border-radius: 12px;

  .item-code {
    font-size: 0.75rem;
    color: #666;
  }

  .item-name {
    font-weight: 600;
    font-size: 1.1rem;
  }

  .item-category {
    font-size: 0.85rem;
    color: #888;
  }

  .availability-toggle {
    display: flex;
    align-items: center;
    gap: 8px;

    span {
      font-size: 0.85rem;
      color: #c10015;

      &.available {
        color: #21ba45;
      }
    }
  }
}
</style>
