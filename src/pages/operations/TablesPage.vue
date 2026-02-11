<template>
  <q-page class="tables-page">
    <div class="page-header">
      <div class="header-left">
        <h1 class="page-title">Floor Plan</h1>
        <p class="page-subtitle">{{ occupiedCount }}/{{ tables.length }} tables occupied</p>
      </div>
      <div class="header-right">
        <q-btn-toggle
          v-model="viewMode"
          toggle-color="primary"
          :options="[
            { label: 'Floor', value: 'floor', icon: 'grid_view' },
            { label: 'List', value: 'list', icon: 'list' },
          ]"
          rounded
          unelevated
        />
        <q-btn color="primary" icon="add" label="Add Table" @click="showAddDialog = true" />
      </div>
    </div>

    <!-- Status Legend -->
    <div class="status-legend">
      <div class="legend-item">
        <div class="legend-dot available"></div>
        <span>Available ({{ statusCounts.available }})</span>
      </div>
      <div class="legend-item">
        <div class="legend-dot occupied"></div>
        <span>Occupied ({{ statusCounts.occupied }})</span>
      </div>
      <div class="legend-item">
        <div class="legend-dot reserved"></div>
        <span>Reserved ({{ statusCounts.reserved }})</span>
      </div>
      <div class="legend-item">
        <div class="legend-dot cleaning"></div>
        <span>Cleaning ({{ statusCounts.cleaning }})</span>
      </div>
    </div>

    <!-- Section Filter -->
    <div class="section-filters">
      <q-chip
        v-for="section in sections"
        :key="section"
        :selected="selectedSection === section"
        @click="selectedSection = section"
        clickable
        color="primary"
        :outline="selectedSection !== section"
        text-color="white"
      >
        {{ section }}
      </q-chip>
    </div>

    <!-- Loading State -->
    <div v-if="loading" class="loading-container">
      <q-spinner-dots size="50px" color="primary" />
    </div>

    <!-- Floor View -->
    <div v-else-if="viewMode === 'floor'" class="floor-view">
      <TransitionGroup name="table-card">
        <div
          v-for="table in filteredTables"
          :key="table.id"
          class="table-card"
          :class="[table.status, table.shape]"
          @click="selectTable(table)"
        >
          <div class="table-number">{{ table.table_number }}</div>
          <div class="table-capacity">
            <q-icon name="people" size="14px" />
            {{ table.capacity }}
          </div>
          <q-badge v-if="table.status === 'occupied'" color="primary" floating class="order-badge">
            <q-icon name="receipt" size="12px" />
          </q-badge>
          <div v-if="table.current_waiter_name" class="waiter-name">
            {{ table.current_waiter_name }}
          </div>
        </div>
      </TransitionGroup>
    </div>

    <!-- List View -->
    <div v-else class="list-view">
      <q-table
        :rows="filteredTables"
        :columns="tableColumns"
        row-key="id"
        :pagination="{ rowsPerPage: 20 }"
        flat
        bordered
      >
        <template v-slot:body-cell-status="props">
          <q-td :props="props">
            <q-badge :color="statusColor(props.row.status)">
              {{ props.row.status }}
            </q-badge>
          </q-td>
        </template>
        <template v-slot:body-cell-actions="props">
          <q-td :props="props">
            <q-btn flat round icon="more_vert" size="sm">
              <q-menu>
                <q-list>
                  <q-item clickable v-close-popup @click="selectTable(props.row)">
                    <q-item-section avatar><q-icon name="visibility" /></q-item-section>
                    <q-item-section>View Details</q-item-section>
                  </q-item>
                  <q-item
                    clickable
                    v-close-popup
                    @click="changeStatus(props.row, 'available')"
                    v-if="props.row.status !== 'available'"
                  >
                    <q-item-section avatar><q-icon name="check_circle" /></q-item-section>
                    <q-item-section>Mark Available</q-item-section>
                  </q-item>
                  <q-item clickable v-close-popup @click="generateSession(props.row)">
                    <q-item-section avatar><q-icon name="qr_code" /></q-item-section>
                    <q-item-section>Generate QR Code</q-item-section>
                  </q-item>
                </q-list>
              </q-menu>
            </q-btn>
          </q-td>
        </template>
      </q-table>
    </div>

    <!-- Table Details Dialog -->
    <q-dialog v-model="showDetailsDialog" position="right" full-height>
      <q-card class="details-dialog" v-if="selectedTable">
        <q-card-section class="dialog-header">
          <div class="dialog-title">
            <span class="table-number-large">{{ selectedTable.table_number }}</span>
            <q-badge :color="statusColor(selectedTable.status)">
              {{ selectedTable.status }}
            </q-badge>
          </div>
          <q-btn round flat icon="close" v-close-popup />
        </q-card-section>

        <q-card-section>
          <div class="info-grid">
            <div class="info-item">
              <q-icon name="people" />
              <span>{{ selectedTable.capacity }} seats</span>
            </div>
            <div class="info-item">
              <q-icon name="place" />
              <span>{{ selectedTable.location }} - {{ selectedTable.section }}</span>
            </div>
          </div>
        </q-card-section>

        <q-separator />

        <!-- Quick Actions -->
        <q-card-section>
          <p class="section-title">Quick Actions</p>
          <div class="action-buttons">
            <q-btn
              v-if="selectedTable.status === 'available'"
              color="primary"
              icon="add_shopping_cart"
              label="New Order"
              @click="startOrder(selectedTable)"
              no-caps
            />
            <q-btn
              v-if="selectedTable.status === 'occupied'"
              color="secondary"
              icon="receipt_long"
              label="View Order"
              @click="viewOrder(selectedTable)"
              no-caps
            />
            <q-btn
              v-if="selectedTable.status === 'occupied'"
              color="positive"
              icon="point_of_sale"
              label="Generate Bill"
              @click="generateBill(selectedTable)"
              no-caps
            />
            <q-btn
              color="info"
              icon="qr_code_2"
              label="Get QR Code"
              @click="generateSession(selectedTable)"
              no-caps
              outline
            />
          </div>
        </q-card-section>

        <q-separator />

        <!-- Status Change -->
        <q-card-section>
          <p class="section-title">Change Status</p>
          <div class="status-buttons">
            <q-btn
              v-for="status in ['available', 'occupied', 'reserved', 'cleaning', 'out_of_service']"
              :key="status"
              :color="statusColor(status)"
              :outline="selectedTable.status !== status"
              :label="status"
              @click="changeStatus(selectedTable, status)"
              size="sm"
              no-caps
            />
          </div>
        </q-card-section>

        <!-- Assign Waiter -->
        <q-separator />
        <q-card-section>
          <p class="section-title">Assigned Waiter</p>
          <q-select
            v-model="selectedTable.current_waiter_id"
            :options="waiters"
            option-value="id"
            option-label="full_name"
            emit-value
            map-options
            outlined
            dense
            placeholder="Select waiter"
            @update:model-value="assignWaiter"
          />
        </q-card-section>
      </q-card>
    </q-dialog>

    <!-- QR Code Dialog -->
    <q-dialog v-model="showQRDialog">
      <q-card class="qr-dialog">
        <q-card-section class="text-center">
          <h3>Table {{ selectedTable?.table_number }}</h3>
          <p>Scan to access menu</p>
        </q-card-section>
        <q-card-section class="text-center">
          <div v-if="generatedToken" class="qr-placeholder">
            <q-icon name="qr_code_2" size="150px" color="primary" />
            <p class="token-text">{{ generatedToken }}</p>
            <p class="url-text">{{ menuUrl }}</p>
          </div>
        </q-card-section>
        <q-card-actions align="center">
          <q-btn flat label="Copy Link" icon="content_copy" @click="copyMenuLink" />
          <q-btn flat label="Print" icon="print" @click="printQR" />
          <q-btn color="primary" label="Close" v-close-popup />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <!-- Add Table Dialog -->
    <q-dialog v-model="showAddDialog">
      <q-card style="min-width: 400px">
        <q-card-section>
          <div class="text-h6">Add New Table</div>
        </q-card-section>

        <q-card-section>
          <q-form @submit="addTable">
            <q-input
              v-model="newTable.table_number"
              label="Table Number"
              outlined
              dense
              class="q-mb-md"
              :rules="[(v) => !!v || 'Required']"
            />
            <q-input
              v-model.number="newTable.capacity"
              label="Capacity"
              type="number"
              outlined
              dense
              class="q-mb-md"
            />
            <q-select
              v-model="newTable.location"
              :options="['Indoor', 'Outdoor', 'Terrace', 'VIP Room']"
              label="Location"
              outlined
              dense
              class="q-mb-md"
            />
            <q-input v-model="newTable.section" label="Section" outlined dense class="q-mb-md" />
            <q-select
              v-model="newTable.shape"
              :options="['square', 'round', 'rectangle']"
              label="Shape"
              outlined
              dense
            />
          </q-form>
        </q-card-section>

        <q-card-actions align="right">
          <q-btn flat label="Cancel" v-close-popup />
          <q-btn color="primary" label="Add Table" @click="addTable" />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { supabase } from 'src/boot/supabase'
import { useQuasar, copyToClipboard } from 'quasar'
import { useRouter } from 'vue-router'

const $q = useQuasar()
const router = useRouter()

// State
const tables = ref([])
const waiters = ref([])
const loading = ref(true)
const viewMode = ref('floor')
const selectedSection = ref('All')
const showDetailsDialog = ref(false)
const showQRDialog = ref(false)
const showAddDialog = ref(false)
const selectedTable = ref(null)
const generatedToken = ref('')
const newTable = ref({
  table_number: '',
  capacity: 4,
  location: 'Indoor',
  section: 'Main Hall',
  shape: 'square',
})

// Table columns for list view
const tableColumns = [
  { name: 'table_number', label: 'Table', field: 'table_number', sortable: true },
  { name: 'capacity', label: 'Capacity', field: 'capacity', sortable: true },
  { name: 'location', label: 'Location', field: 'location' },
  { name: 'section', label: 'Section', field: 'section' },
  { name: 'status', label: 'Status', field: 'status' },
  { name: 'actions', label: 'Actions', field: 'actions' },
]

// Computed
const sections = computed(() => {
  const secs = [...new Set(tables.value.map((t) => t.section))]
  return ['All', ...secs]
})

const filteredTables = computed(() => {
  if (selectedSection.value === 'All') return tables.value
  return tables.value.filter((t) => t.section === selectedSection.value)
})

const occupiedCount = computed(() => tables.value.filter((t) => t.status === 'occupied').length)

const statusCounts = computed(() => ({
  available: tables.value.filter((t) => t.status === 'available').length,
  occupied: tables.value.filter((t) => t.status === 'occupied').length,
  reserved: tables.value.filter((t) => t.status === 'reserved').length,
  cleaning: tables.value.filter((t) => t.status === 'cleaning').length,
}))

const menuUrl = computed(() => {
  return `${window.location.origin}/menu?token=${generatedToken.value}`
})

// Methods
const fetchTables = async () => {
  loading.value = true
  try {
    const { data, error } = await supabase
      .from('restaurant_tables')
      .select('*, current_waiter:current_waiter_id(full_name)')
      .eq('is_active', true)
      .order('table_number')

    if (error) throw error
    tables.value = data.map((t) => ({
      ...t,
      current_waiter_name: t.current_waiter?.full_name,
    }))
  } catch (err) {
    console.error('Error fetching tables:', err)
    $q.notify({ type: 'negative', message: 'Failed to load tables' })
  } finally {
    loading.value = false
  }
}

const fetchWaiters = async () => {
  try {
    const { data, error } = await supabase
      .from('profiles')
      .select('id, full_name')
      .order('full_name')

    if (error) throw error
    waiters.value = data || []
  } catch (err) {
    console.error('Error fetching waiters:', err)
  }
}

const selectTable = (table) => {
  selectedTable.value = { ...table }
  showDetailsDialog.value = true
}

const changeStatus = async (table, newStatus) => {
  try {
    const { error } = await supabase
      .from('restaurant_tables')
      .update({ status: newStatus, updated_at: new Date().toISOString() })
      .eq('id', table.id)

    if (error) throw error

    table.status = newStatus
    $q.notify({ type: 'positive', message: `Table marked as ${newStatus}` })
  } catch (err) {
    console.error('Error updating status:', err)
    $q.notify({ type: 'negative', message: 'Failed to update table status' })
  }
}

const generateSession = async (table) => {
  selectedTable.value = table
  try {
    const { data, error } = await supabase.rpc('create_table_session', {
      p_table_id: table.id,
      p_device_name: 'Customer Device',
    })

    if (error) throw error

    if (data && data.length > 0) {
      generatedToken.value = data[0].access_token
      showQRDialog.value = true
    }
  } catch (err) {
    console.error('Error generating session:', err)
    $q.notify({ type: 'negative', message: 'Failed to generate QR code' })
  }
}

const copyMenuLink = () => {
  copyToClipboard(menuUrl.value)
  $q.notify({ type: 'positive', message: 'Link copied to clipboard' })
}

const printQR = () => {
  window.print()
}

const assignWaiter = async (waiterId) => {
  try {
    const { error } = await supabase
      .from('restaurant_tables')
      .update({ current_waiter_id: waiterId })
      .eq('id', selectedTable.value.id)

    if (error) throw error
    $q.notify({ type: 'positive', message: 'Waiter assigned' })
  } catch (err) {
    console.error('Error assigning waiter:', err)
    $q.notify({ type: 'negative', message: 'Failed to assign waiter' })
  }
}

const startOrder = (table) => {
  router.push({ path: '/operations/orders', query: { table_id: table.id } })
}

const viewOrder = (table) => {
  router.push({ path: '/operations/orders', query: { order_id: table.current_order_id } })
}

const generateBill = (table) => {
  router.push({ path: '/billing', query: { order_id: table.current_order_id } })
}

const addTable = async () => {
  try {
    const { error } = await supabase.from('restaurant_tables').insert([newTable.value])
    if (error) throw error
    $q.notify({ type: 'positive', message: 'Table added successfully' })
    showAddDialog.value = false
    fetchTables()
  } catch (err) {
    console.error('Error adding table:', err)
    console.log('Current Supabase Config:', import.meta.env.VITE_SUPABASE_URL)
    $q.notify({ type: 'negative', message: 'Failed to add table. See console for details.' })
  }
}

const statusColor = (status) => {
  const colors = {
    available: 'positive',
    occupied: 'negative',
    reserved: 'warning',
    cleaning: 'info',
    out_of_service: 'grey',
  }
  return colors[status] || 'grey'
}

// Real-time subscription
let subscription = null

const setupRealtime = () => {
  subscription = supabase
    .channel('tables-channel')
    .on('postgres_changes', { event: '*', schema: 'public', table: 'restaurant_tables' }, () => {
      fetchTables()
    })
    .subscribe()
}

// Lifecycle
onMounted(() => {
  fetchTables()
  fetchWaiters()
  setupRealtime()
})

onUnmounted(() => {
  if (subscription) supabase.removeChannel(subscription)
})
</script>

<style lang="scss" scoped>
.tables-page {
  padding: 24px;
}

.page-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 24px;
  flex-wrap: wrap;
  gap: 16px;

  .header-left {
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

  .header-right {
    display: flex;
    gap: 12px;
    align-items: center;
  }
}

.status-legend {
  display: flex;
  gap: 24px;
  margin-bottom: 20px;
  flex-wrap: wrap;

  .legend-item {
    display: flex;
    align-items: center;
    gap: 8px;
    font-size: 0.9rem;
    color: #666;
  }

  .legend-dot {
    width: 12px;
    height: 12px;
    border-radius: 50%;

    &.available {
      background: #21ba45;
    }
    &.occupied {
      background: #c10015;
    }
    &.reserved {
      background: #f2c037;
    }
    &.cleaning {
      background: #31ccec;
    }
  }
}

.section-filters {
  display: flex;
  gap: 8px;
  margin-bottom: 24px;
  flex-wrap: wrap;
}

.loading-container {
  display: flex;
  justify-content: center;
  padding: 60px;
}

.floor-view {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(120px, 1fr));
  gap: 16px;
}

.table-card {
  aspect-ratio: 1;
  background: white;
  border: 3px solid #e0e0e0;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  transition: all 0.3s ease;
  position: relative;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.08);

  &.square {
    border-radius: 12px;
  }

  &.round {
    border-radius: 50%;
  }

  &.rectangle {
    border-radius: 12px;
    aspect-ratio: 2/1;
  }

  &:hover {
    transform: scale(1.05);
    box-shadow: 0 8px 24px rgba(0, 0, 0, 0.15);
  }

  &.available {
    border-color: #21ba45;
    background: linear-gradient(135deg, #e8f5e9 0%, #c8e6c9 100%);
  }

  &.occupied {
    border-color: #c10015;
    background: linear-gradient(135deg, #ffebee 0%, #ffcdd2 100%);
  }

  &.reserved {
    border-color: #f2c037;
    background: linear-gradient(135deg, #fff8e1 0%, #ffecb3 100%);
  }

  &.cleaning {
    border-color: #31ccec;
    background: linear-gradient(135deg, #e1f5fe 0%, #b3e5fc 100%);
  }

  .table-number {
    font-size: 1.4rem;
    font-weight: 800;
    color: #1a1a2e;
  }

  .table-capacity {
    display: flex;
    align-items: center;
    gap: 4px;
    font-size: 0.8rem;
    color: #666;
    margin-top: 4px;
  }

  .order-badge {
    top: 8px;
    right: 8px;
  }

  .waiter-name {
    font-size: 0.7rem;
    color: #666;
    margin-top: 4px;
    max-width: 80%;
    text-overflow: ellipsis;
    white-space: nowrap;
    overflow: hidden;
  }
}

// Transition animations
.table-card-enter-active,
.table-card-leave-active {
  transition: all 0.3s ease;
}

.table-card-enter-from,
.table-card-leave-to {
  opacity: 0;
  transform: scale(0.8);
}

// Dialogs
.details-dialog {
  width: 400px;
  max-width: 100vw;

  .dialog-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%);
    color: white;
  }

  .dialog-title {
    display: flex;
    align-items: center;
    gap: 12px;
  }

  .table-number-large {
    font-size: 2rem;
    font-weight: 800;
  }

  .info-grid {
    display: flex;
    gap: 20px;
    flex-wrap: wrap;
  }

  .info-item {
    display: flex;
    align-items: center;
    gap: 8px;
    color: #666;
  }

  .section-title {
    font-weight: 600;
    margin-bottom: 12px;
    color: #1a1a2e;
  }

  .action-buttons {
    display: flex;
    flex-direction: column;
    gap: 8px;
  }

  .status-buttons {
    display: flex;
    flex-wrap: wrap;
    gap: 8px;
  }
}

.qr-dialog {
  min-width: 350px;
  text-align: center;

  h3 {
    margin: 0;
    font-weight: 700;
  }

  .qr-placeholder {
    padding: 20px;
    background: #f5f5f5;
    border-radius: 16px;
  }

  .token-text {
    font-family: monospace;
    font-size: 0.7rem;
    color: #666;
    word-break: break-all;
    margin: 12px 0 0;
  }

  .url-text {
    font-size: 0.8rem;
    color: #1976d2;
    margin: 8px 0 0;
  }
}
</style>
