<template>
  <q-page class="kitchen-display-page">
    <!-- Header -->
    <div class="kitchen-header">
      <div class="header-left">
        <q-icon name="restaurant" size="36px" color="white" />
        <div class="header-text">
          <h1>Kitchen Display</h1>
          <p>{{ currentTime }} | {{ pendingCount }} Orders Pending</p>
        </div>
      </div>
      <div class="header-right">
        <q-btn-toggle
          v-model="selectedStation"
          toggle-color="white"
          text-color="white"
          :options="stationOptions"
          rounded
          unelevated
          class="station-toggle"
        />
        <q-btn round flat icon="refresh" color="white" @click="refreshOrders" :loading="loading" />
        <q-btn round flat icon="fullscreen" color="white" @click="toggleFullscreen" />
      </div>
    </div>

    <!-- Loading State -->
    <div v-if="loading && !orders.length" class="loading-container">
      <q-spinner-dots size="60px" color="primary" />
      <p>Loading orders...</p>
    </div>

    <!-- Empty State -->
    <div v-else-if="!filteredOrders.length" class="empty-state">
      <q-icon name="check_circle" size="100px" color="positive" />
      <h2>All Caught Up!</h2>
      <p>No pending orders at the moment</p>
    </div>

    <!-- Orders Grid -->
    <div v-else class="orders-grid">
      <TransitionGroup name="order-card">
        <div
          v-for="order in filteredOrders"
          :key="order.id"
          class="order-card"
          :class="[order.status.toLowerCase().replace(' ', '-'), priorityClass(order)]"
        >
          <!-- Card Header -->
          <div class="card-header">
            <div class="table-info">
              <q-badge :color="statusColor(order.status)" floating>{{ order.status }}</q-badge>
              <span class="table-number">{{ order.table_number || 'TK' }}</span>
              <span class="kot-number">{{ order.kot_number }}</span>
            </div>
            <div class="time-info">
              <q-icon name="schedule" size="16px" />
              <span :class="{ urgent: order.elapsed_minutes > 15 }">
                {{ order.elapsed_minutes }}m
              </span>
            </div>
          </div>

          <!-- Item Details -->
          <div class="item-details">
            <div class="quantity-badge">{{ order.quantity }}</div>
            <div class="item-name">{{ order.item_name }}</div>
          </div>

          <!-- Special Notes -->
          <div v-if="order.special_notes" class="special-notes">
            <q-icon name="info" size="16px" />
            {{ order.special_notes }}
          </div>

          <!-- Priority Badge -->
          <q-badge
            v-if="order.priority !== 'Normal'"
            :color="priorityColor(order.priority)"
            class="priority-badge"
          >
            {{ order.priority }}
          </q-badge>

          <!-- Action Buttons -->
          <div class="card-actions">
            <q-btn
              v-if="order.status === 'Pending'"
              color="warning"
              label="Start"
              icon="play_arrow"
              @click="updateStatus(order, 'In Progress')"
              :loading="order.updating"
              no-caps
            />
            <q-btn
              v-else-if="order.status === 'In Progress'"
              color="positive"
              label="Ready"
              icon="check"
              @click="updateStatus(order, 'Ready')"
              :loading="order.updating"
              no-caps
            />
            <q-btn
              v-else-if="order.status === 'Ready'"
              color="info"
              label="Served"
              icon="room_service"
              @click="updateStatus(order, 'Served')"
              :loading="order.updating"
              no-caps
            />
          </div>
        </div>
      </TransitionGroup>
    </div>

    <!-- Audio notification -->
    <audio ref="notificationAudio" src="/notification.mp3" preload="auto"></audio>
  </q-page>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { supabase } from 'src/boot/supabase'
import { useQuasar } from 'quasar'

const $q = useQuasar()

// State
const orders = ref([])
const loading = ref(true)
const selectedStation = ref('all')
const currentTime = ref('')
const notificationAudio = ref(null)

// Station options
const stationOptions = [
  { label: 'All', value: 'all' },
  { label: 'Hot', value: 'Hot' },
  { label: 'Cold', value: 'Cold' },
  { label: 'Grill', value: 'Grill' },
  { label: 'Bar', value: 'Bar' },
]

// Computed
const filteredOrders = computed(() => {
  if (selectedStation.value === 'all') return orders.value
  return orders.value.filter((o) => o.kitchen_station === selectedStation.value)
})

const pendingCount = computed(() => orders.value.filter((o) => o.status === 'Pending').length)

// Methods
const fetchOrders = async () => {
  loading.value = true
  try {
    const { data, error } = await supabase.rpc('get_kitchen_orders')
    if (error) throw error
    orders.value = data || []
  } catch (err) {
    console.error('Error fetching orders:', err)
    $q.notify({ type: 'negative', message: 'Failed to load orders' })
  } finally {
    loading.value = false
  }
}

const updateStatus = async (order, newStatus) => {
  order.updating = true
  try {
    const { error } = await supabase.rpc('update_kot_status', {
      p_kot_id: order.kot_id,
      p_new_status: newStatus,
    })
    if (error) throw error

    // Update local state
    order.status = newStatus
    $q.notify({ type: 'positive', message: `Order marked as ${newStatus}` })

    // Remove from list if served
    if (newStatus === 'Served') {
      orders.value = orders.value.filter((o) => o.kot_id !== order.kot_id)
    }
  } catch (err) {
    console.error('Error updating status:', err)
    $q.notify({ type: 'negative', message: 'Failed to update order' })
  } finally {
    order.updating = false
  }
}

const refreshOrders = () => fetchOrders()

const toggleFullscreen = () => {
  if (!document.fullscreenElement) {
    document.documentElement.requestFullscreen()
  } else {
    document.exitFullscreen()
  }
}

const statusColor = (status) => {
  const colors = {
    Pending: 'orange',
    'In Progress': 'blue',
    Ready: 'green',
    Served: 'grey',
  }
  return colors[status] || 'grey'
}

const priorityColor = (priority) => {
  const colors = { Rush: 'red', High: 'orange', Normal: 'grey', Low: 'blue' }
  return colors[priority] || 'grey'
}

const priorityClass = (order) => {
  if (order.priority === 'Rush') return 'rush-order'
  if (order.elapsed_minutes > 15) return 'delayed-order'
  return ''
}

// Update clock
const updateClock = () => {
  const now = new Date()
  currentTime.value = now.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' })
}

// Real-time subscription
let subscription = null

const setupRealtime = () => {
  subscription = supabase
    .channel('kitchen-orders-channel')
    .on(
      'postgres_changes',
      {
        event: 'INSERT',
        schema: 'public',
        table: 'kitchen_orders',
      },
      (payload) => {
        console.log('New order:', payload)
        // Play notification sound
        if (notificationAudio.value) {
          notificationAudio.value.play().catch(() => {})
        }
        // Refresh orders
        fetchOrders()

        // Show notification
        $q.notify({
          type: 'info',
          message: `New Order: ${payload.new.item_name}`,
          caption: `Table ${payload.new.table_number}`,
          icon: 'notifications_active',
          timeout: 5000,
        })
      },
    )
    .on(
      'postgres_changes',
      {
        event: 'UPDATE',
        schema: 'public',
        table: 'kitchen_orders',
      },
      () => {
        fetchOrders()
      },
    )
    .subscribe()
}

// Lifecycle
let clockInterval = null

onMounted(() => {
  updateClock()
  clockInterval = setInterval(updateClock, 1000)
  fetchOrders()
  setupRealtime()
})

onUnmounted(() => {
  if (clockInterval) clearInterval(clockInterval)
  if (subscription) supabase.removeChannel(subscription)
})
</script>

<style lang="scss" scoped>
.kitchen-display-page {
  background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%);
  min-height: 100vh;
  padding: 0;
}

.kitchen-header {
  background: linear-gradient(90deg, #e94560 0%, #0f3460 100%);
  padding: 16px 24px;
  display: flex;
  justify-content: space-between;
  align-items: center;
  position: sticky;
  top: 0;
  z-index: 100;
  box-shadow: 0 4px 20px rgba(0, 0, 0, 0.3);

  .header-left {
    display: flex;
    align-items: center;
    gap: 16px;
  }

  .header-text {
    h1 {
      color: white;
      font-size: 1.5rem;
      font-weight: 700;
      margin: 0;
    }

    p {
      color: rgba(255, 255, 255, 0.8);
      margin: 0;
      font-size: 0.9rem;
    }
  }

  .header-right {
    display: flex;
    align-items: center;
    gap: 12px;
  }

  .station-toggle {
    background: rgba(255, 255, 255, 0.1);
    border-radius: 25px;
  }
}

.loading-container,
.empty-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  height: 60vh;
  color: white;

  p {
    margin-top: 16px;
    color: rgba(255, 255, 255, 0.7);
  }

  h2 {
    color: white;
    margin: 16px 0 8px;
  }
}

.orders-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
  gap: 20px;
  padding: 24px;
}

.order-card {
  background: white;
  border-radius: 16px;
  padding: 20px;
  box-shadow: 0 8px 32px rgba(0, 0, 0, 0.2);
  position: relative;
  transition: all 0.3s ease;
  border-left: 5px solid #ccc;

  &:hover {
    transform: translateY(-4px);
    box-shadow: 0 12px 40px rgba(0, 0, 0, 0.3);
  }

  &.pending {
    border-left-color: #ff9800;
  }

  &.in-progress {
    border-left-color: #2196f3;
    animation: pulse 2s infinite;
  }

  &.ready {
    border-left-color: #4caf50;
  }

  &.rush-order {
    border-left-color: #f44336;
    animation: shake 0.5s infinite;
  }

  &.delayed-order {
    background: linear-gradient(135deg, #fff 0%, #ffebee 100%);
  }
}

@keyframes pulse {
  0%,
  100% {
    box-shadow: 0 8px 32px rgba(33, 150, 243, 0.3);
  }
  50% {
    box-shadow: 0 8px 32px rgba(33, 150, 243, 0.6);
  }
}

@keyframes shake {
  0%,
  100% {
    transform: translateX(0);
  }
  25% {
    transform: translateX(-2px);
  }
  75% {
    transform: translateX(2px);
  }
}

.card-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  margin-bottom: 16px;

  .table-info {
    display: flex;
    flex-direction: column;
    gap: 4px;
    position: relative;

    .table-number {
      font-size: 1.8rem;
      font-weight: 800;
      color: #1a1a2e;
    }

    .kot-number {
      font-size: 0.75rem;
      color: #666;
    }
  }

  .time-info {
    display: flex;
    align-items: center;
    gap: 4px;
    font-size: 0.9rem;
    color: #666;

    .urgent {
      color: #f44336;
      font-weight: 700;
    }
  }
}

.item-details {
  display: flex;
  align-items: center;
  gap: 12px;
  margin-bottom: 12px;

  .quantity-badge {
    width: 40px;
    height: 40px;
    background: linear-gradient(135deg, #e94560 0%, #0f3460 100%);
    color: white;
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    font-weight: 700;
    font-size: 1.2rem;
  }

  .item-name {
    font-size: 1.1rem;
    font-weight: 600;
    color: #1a1a2e;
  }
}

.special-notes {
  background: #fff3cd;
  border: 1px solid #ffc107;
  border-radius: 8px;
  padding: 8px 12px;
  font-size: 0.85rem;
  color: #856404;
  display: flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 12px;
}

.priority-badge {
  position: absolute;
  top: 12px;
  right: 12px;
}

.card-actions {
  margin-top: 16px;

  .q-btn {
    width: 100%;
    border-radius: 10px;
    font-weight: 600;
  }
}

// Transition animations
.order-card-enter-active,
.order-card-leave-active {
  transition: all 0.5s ease;
}

.order-card-enter-from {
  opacity: 0;
  transform: translateY(-30px);
}

.order-card-leave-to {
  opacity: 0;
  transform: scale(0.8);
}
</style>
