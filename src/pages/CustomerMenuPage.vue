<template>
  <div class="customer-menu" :class="{ 'dark-mode': darkMode }">
    <!-- Header -->
    <header class="menu-header">
      <div class="header-content">
        <div class="logo-section">
          <q-icon name="restaurant" size="32px" />
          <h1>Seven Waves</h1>
        </div>
        <div class="table-badge" v-if="tableInfo">
          <q-icon name="table_restaurant" />
          <span>{{ tableInfo.table_number }}</span>
        </div>
        <q-btn round flat :icon="darkMode ? 'light_mode' : 'dark_mode'" @click="toggleDarkMode" />
      </div>
    </header>

    <!-- Loading / Error States -->
    <div v-if="loading" class="loading-screen">
      <q-spinner-dots size="60px" color="primary" />
      <p>Loading menu...</p>
    </div>

    <div v-else-if="!tableInfo" class="error-screen">
      <q-icon name="error_outline" size="80px" color="negative" />
      <h2>Invalid Access</h2>
      <p>Please scan the QR code at your table</p>
    </div>

    <!-- Main Content -->
    <main v-else class="menu-content">
      <!-- Categories Navigation -->
      <nav class="category-nav">
        <div class="category-scroll">
          <button
            v-for="cat in categories"
            :key="cat"
            :class="{ active: selectedCategory === cat }"
            @click="selectedCategory = cat"
          >
            {{ cat }}
          </button>
        </div>
      </nav>

      <!-- Menu Items Grid -->
      <div class="items-grid">
        <TransitionGroup name="menu-item">
          <div
            v-for="item in filteredItems"
            :key="item.item_id"
            class="menu-item-card"
            @click="addToCart(item)"
          >
            <div class="item-image">
              <q-icon name="restaurant_menu" size="48px" color="primary" />
            </div>
            <div class="item-info">
              <h3>{{ item.item_name }}</h3>
              <p class="item-description">{{ item.description || 'Delicious dish' }}</p>
              <div class="item-footer">
                <span class="item-price">Rs. {{ item.selling_price?.toFixed(2) }}</span>
                <q-btn round color="primary" icon="add" size="sm" />
              </div>
            </div>
            <div v-if="getCartQty(item)" class="cart-qty-badge">
              {{ getCartQty(item) }}
            </div>
          </div>
        </TransitionGroup>
      </div>
    </main>

    <!-- Cart Floating Button -->
    <Transition name="cart-fab">
      <q-btn
        v-if="cart.length"
        fab
        color="primary"
        icon="shopping_cart"
        class="cart-fab"
        @click="showCart = true"
      >
        <q-badge color="red" floating>{{ cartItemCount }}</q-badge>
      </q-btn>
    </Transition>

    <!-- Cart Bottom Sheet -->
    <q-dialog v-model="showCart" position="bottom" full-width>
      <q-card class="cart-sheet">
        <q-card-section class="cart-header">
          <h2>Your Order</h2>
          <q-btn round flat icon="close" v-close-popup />
        </q-card-section>

        <q-card-section class="cart-items" v-if="cart.length">
          <TransitionGroup name="cart-item">
            <div v-for="item in cart" :key="item.item_id" class="cart-item">
              <div class="cart-item-info">
                <h4>{{ item.item_name }}</h4>
                <span class="cart-item-price">Rs. {{ item.selling_price?.toFixed(2) }}</span>
              </div>
              <div class="cart-item-controls">
                <q-btn round flat icon="remove" size="sm" @click="decrementQty(item)" />
                <span class="qty">{{ item.quantity }}</span>
                <q-btn round flat icon="add" size="sm" @click="incrementQty(item)" />
              </div>
              <div class="cart-item-total">
                Rs. {{ (item.selling_price * item.quantity).toFixed(2) }}
              </div>
            </div>
          </TransitionGroup>
        </q-card-section>

        <q-card-section v-else class="empty-cart">
          <q-icon name="shopping_cart" size="48px" color="grey-5" />
          <p>Your cart is empty</p>
        </q-card-section>

        <q-separator />

        <!-- Special Instructions -->
        <q-card-section v-if="cart.length">
          <q-input
            v-model="specialInstructions"
            label="Special instructions (allergies, preferences)"
            outlined
            dense
            type="textarea"
            rows="2"
          />
        </q-card-section>

        <!-- Cart Summary -->
        <q-card-section class="cart-summary" v-if="cart.length">
          <div class="summary-row">
            <span>Subtotal</span>
            <span>Rs. {{ cartTotal.toFixed(2) }}</span>
          </div>
          <div class="summary-row total">
            <span>Total</span>
            <span>Rs. {{ cartTotal.toFixed(2) }}</span>
          </div>
        </q-card-section>

        <q-card-actions v-if="cart.length">
          <q-btn
            color="primary"
            icon="send"
            label="Place Order"
            class="full-width submit-btn"
            :loading="submitting"
            @click="submitOrder"
            no-caps
          />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <!-- Order Status Modal -->
    <q-dialog v-model="showOrderStatus" persistent full-width full-height>
      <q-card class="order-status-card">
        <q-card-section class="status-header bg-primary text-white">
          <div class="status-title">
            <q-icon name="check_circle" size="48px" />
            <h2>Order Placed!</h2>
          </div>
          <p>Your order has been sent to the kitchen</p>
        </q-card-section>

        <q-card-section class="status-content">
          <div class="order-number">
            <span class="label">Order Number</span>
            <span class="number">{{ placedOrder?.order_number }}</span>
          </div>

          <div class="status-timeline">
            <div
              v-for="(step, index) in orderSteps"
              :key="index"
              class="timeline-step"
              :class="{ active: currentStepIndex >= index, current: currentStepIndex === index }"
            >
              <div class="step-icon">
                <q-icon :name="step.icon" size="24px" />
              </div>
              <div class="step-info">
                <span class="step-title">{{ step.title }}</span>
                <span class="step-desc">{{ step.description }}</span>
              </div>
            </div>
          </div>

          <div class="order-items-preview">
            <h4>Your Items</h4>
            <div v-for="item in placedOrderItems" :key="item.id" class="preview-item">
              <span class="qty">{{ item.quantity }}x</span>
              <span class="name">{{ item.item_name }}</span>
              <q-badge :color="statusColor(item.status)">{{ item.status }}</q-badge>
            </div>
          </div>
        </q-card-section>

        <q-card-actions>
          <q-btn
            flat
            color="primary"
            label="New Order"
            icon="add"
            @click="startNewOrder"
            class="full-width"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { supabase } from 'src/boot/supabase'
import { useRoute } from 'vue-router'
import { useQuasar } from 'quasar'

const route = useRoute()
const $q = useQuasar()

// State
const loading = ref(true)
const submitting = ref(false)
const tableInfo = ref(null)
const sessionId = ref(null)
const menuItems = ref([])
const cart = ref([])
const selectedCategory = ref('All')
const showCart = ref(false)
const showOrderStatus = ref(false)
const specialInstructions = ref('')
const placedOrder = ref(null)
const placedOrderItems = ref([])
const darkMode = ref(false)

// Order tracking steps
const orderSteps = [
  { title: 'Order Received', description: 'Your order has been placed', icon: 'receipt_long' },
  { title: 'Preparing', description: 'Kitchen is working on your order', icon: 'restaurant' },
  { title: 'Ready', description: 'Your order is ready', icon: 'check_circle' },
  { title: 'Served', description: 'Enjoy your meal!', icon: 'room_service' },
]

// Computed
const categories = computed(() => {
  const cats = [...new Set(menuItems.value.map((i) => i.category_name))]
  return ['All', ...cats]
})

const filteredItems = computed(() => {
  if (selectedCategory.value === 'All') return menuItems.value
  return menuItems.value.filter((i) => i.category_name === selectedCategory.value)
})

const cartItemCount = computed(() => cart.value.reduce((sum, item) => sum + item.quantity, 0))

const cartTotal = computed(() =>
  cart.value.reduce((sum, item) => sum + item.selling_price * item.quantity, 0),
)

const currentStepIndex = computed(() => {
  if (!placedOrder.value) return 0
  const statusMap = { Ordered: 0, Preparing: 1, Ready: 2, Served: 3, 'Partially Served': 2 }
  return statusMap[placedOrder.value.status] || 0
})

// Methods
const validateToken = async () => {
  const token = route.query.token
  if (!token) {
    loading.value = false
    return
  }

  try {
    const { data, error } = await supabase.rpc('validate_table_token', {
      p_access_token: token,
    })

    if (error) throw error

    if (data && data.length > 0) {
      tableInfo.value = data[0]
      sessionId.value = data[0].session_id
      await fetchMenu()
    }
  } catch (err) {
    console.error('Error validating token:', err)
  } finally {
    loading.value = false
  }
}

const fetchMenu = async () => {
  try {
    const { data, error } = await supabase.rpc('get_customer_menu')
    if (error) throw error
    menuItems.value = data || []
  } catch (err) {
    console.error('Error fetching menu:', err)
  }
}

const addToCart = (item) => {
  const existing = cart.value.find((c) => c.item_id === item.item_id)
  if (existing) {
    existing.quantity++
  } else {
    cart.value.push({ ...item, quantity: 1 })
  }

  // Haptic feedback
  if (navigator.vibrate) navigator.vibrate(50)
}

const getCartQty = (item) => {
  const cartItem = cart.value.find((c) => c.item_id === item.item_id)
  return cartItem?.quantity || 0
}

const incrementQty = (item) => item.quantity++
const decrementQty = (item) => {
  if (item.quantity > 1) {
    item.quantity--
  } else {
    cart.value = cart.value.filter((c) => c.item_id !== item.item_id)
  }
}

const submitOrder = async () => {
  if (!cart.value.length) return

  submitting.value = true
  try {
    const { data, error } = await supabase.rpc('create_table_order', {
      p_table_session_id: sessionId.value,
      p_items: cart.value.map((item) => ({
        item_id: item.item_id,
        quantity: item.quantity,
        special_notes: '',
      })),
      p_special_instructions: specialInstructions.value,
    })

    if (error) throw error

    if (data && data.length > 0) {
      placedOrder.value = data[0]
      placedOrderItems.value = cart.value.map((item) => ({
        ...item,
        status: 'Ordered',
      }))

      showCart.value = false
      showOrderStatus.value = true
      cart.value = []
      specialInstructions.value = ''

      // Start polling for status updates
      startStatusPolling()
    }
  } catch (err) {
    console.error('Error submitting order:', err)
    $q.notify({ type: 'negative', message: 'Failed to place order. Please try again.' })
  } finally {
    submitting.value = false
  }
}

const startNewOrder = () => {
  showOrderStatus.value = false
  placedOrder.value = null
  placedOrderItems.value = []
}

const statusColor = (status) => {
  const colors = { Ordered: 'orange', Preparing: 'blue', Ready: 'green', Served: 'grey' }
  return colors[status] || 'grey'
}

const toggleDarkMode = () => {
  darkMode.value = !darkMode.value
  localStorage.setItem('customerMenuDarkMode', darkMode.value)
}

// Status polling
let statusInterval = null

const startStatusPolling = () => {
  if (statusInterval) clearInterval(statusInterval)

  statusInterval = setInterval(async () => {
    if (!placedOrder.value?.order_id) return

    try {
      const { data, error } = await supabase.rpc('get_order_status', {
        p_order_id: placedOrder.value.order_id,
      })

      if (error) throw error

      if (data && data.length > 0) {
        placedOrder.value = { ...placedOrder.value, status: data[0].order_status }
        placedOrderItems.value = data[0].items || []

        // Stop polling if order is served
        if (data[0].order_status === 'Served') {
          clearInterval(statusInterval)
        }
      }
    } catch (err) {
      console.error('Error polling status:', err)
    }
  }, 5000)
}

// Lifecycle
onMounted(() => {
  validateToken()
  darkMode.value = localStorage.getItem('customerMenuDarkMode') === 'true'
})

onUnmounted(() => {
  if (statusInterval) clearInterval(statusInterval)
})
</script>

<style lang="scss" scoped>
.customer-menu {
  min-height: 100vh;
  background: #fafafa;
  padding-bottom: 80px;

  &.dark-mode {
    background: #1a1a2e;

    .menu-header {
      background: linear-gradient(135deg, #16213e 0%, #0f3460 100%);
    }

    .menu-item-card {
      background: #16213e;
      color: white;

      h3 {
        color: white;
      }

      .item-description {
        color: rgba(255, 255, 255, 0.7);
      }
    }

    .category-nav button {
      background: #16213e;
      color: white;

      &.active {
        background: #e94560;
      }
    }
  }
}

.menu-header {
  background: linear-gradient(135deg, #e94560 0%, #0f3460 100%);
  padding: 16px 20px;
  position: sticky;
  top: 0;
  z-index: 100;
  box-shadow: 0 4px 20px rgba(0, 0, 0, 0.2);

  .header-content {
    display: flex;
    justify-content: space-between;
    align-items: center;
    max-width: 800px;
    margin: 0 auto;
  }

  .logo-section {
    display: flex;
    align-items: center;
    gap: 8px;
    color: white;

    h1 {
      margin: 0;
      font-size: 1.3rem;
      font-weight: 700;
    }
  }

  .table-badge {
    background: rgba(255, 255, 255, 0.2);
    padding: 8px 16px;
    border-radius: 20px;
    display: flex;
    align-items: center;
    gap: 8px;
    color: white;
    font-weight: 600;
  }
}

.loading-screen,
.error-screen {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  height: 60vh;
  text-align: center;
  padding: 20px;

  h2 {
    margin: 16px 0 8px;
  }

  p {
    color: #666;
  }
}

.menu-content {
  max-width: 800px;
  margin: 0 auto;
  padding: 20px;
}

.category-nav {
  margin-bottom: 20px;
  overflow-x: auto;

  .category-scroll {
    display: flex;
    gap: 8px;
    padding-bottom: 8px;
  }

  button {
    flex-shrink: 0;
    padding: 10px 20px;
    border: none;
    border-radius: 25px;
    background: white;
    color: #666;
    font-size: 0.9rem;
    font-weight: 500;
    cursor: pointer;
    transition: all 0.3s;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.08);

    &.active {
      background: #e94560;
      color: white;
    }
  }
}

.items-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(160px, 1fr));
  gap: 16px;
}

.menu-item-card {
  background: white;
  border-radius: 16px;
  padding: 16px;
  cursor: pointer;
  transition: all 0.3s;
  position: relative;
  box-shadow: 0 4px 16px rgba(0, 0, 0, 0.08);

  &:hover {
    transform: translateY(-4px);
    box-shadow: 0 8px 24px rgba(0, 0, 0, 0.12);
  }

  &:active {
    transform: scale(0.98);
  }

  .item-image {
    width: 80px;
    height: 80px;
    margin: 0 auto 12px;
    background: linear-gradient(135deg, #ffe0e6 0%, #e0e0ff 100%);
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .item-info {
    text-align: center;

    h3 {
      margin: 0 0 4px;
      font-size: 0.95rem;
      font-weight: 600;
      color: #1a1a2e;
    }

    .item-description {
      font-size: 0.75rem;
      color: #888;
      margin: 0 0 12px;
      display: -webkit-box;
      -webkit-line-clamp: 2;
      line-clamp: 2;
      -webkit-box-orient: vertical;
      overflow: hidden;
    }

    .item-footer {
      display: flex;
      justify-content: space-between;
      align-items: center;

      .item-price {
        font-size: 1rem;
        font-weight: 700;
        color: #e94560;
      }
    }
  }

  .cart-qty-badge {
    position: absolute;
    top: -8px;
    right: -8px;
    background: #e94560;
    color: white;
    width: 28px;
    height: 28px;
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    font-weight: 700;
    font-size: 0.85rem;
    box-shadow: 0 4px 12px rgba(233, 69, 96, 0.4);
  }
}

.cart-fab {
  position: fixed;
  bottom: 24px;
  right: 24px;
  z-index: 50;
  box-shadow: 0 8px 24px rgba(0, 0, 0, 0.3);
}

// Cart Bottom Sheet
.cart-sheet {
  border-radius: 24px 24px 0 0;
  max-height: 80vh;
  overflow-y: auto;

  .cart-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    position: sticky;
    top: 0;
    background: white;
    z-index: 1;

    h2 {
      margin: 0;
      font-weight: 700;
    }
  }

  .cart-items {
    max-height: 300px;
    overflow-y: auto;
  }

  .cart-item {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 12px 0;
    border-bottom: 1px solid #f0f0f0;

    .cart-item-info {
      flex: 1;

      h4 {
        margin: 0;
        font-size: 0.95rem;
      }

      .cart-item-price {
        font-size: 0.8rem;
        color: #666;
      }
    }

    .cart-item-controls {
      display: flex;
      align-items: center;
      gap: 4px;
      background: #f5f5f5;
      border-radius: 20px;
      padding: 4px;

      .qty {
        min-width: 24px;
        text-align: center;
        font-weight: 600;
      }
    }

    .cart-item-total {
      font-weight: 700;
      color: #e94560;
    }
  }

  .empty-cart {
    text-align: center;
    padding: 40px;
    color: #999;
  }

  .cart-summary {
    background: #fafafa;
    border-radius: 12px;

    .summary-row {
      display: flex;
      justify-content: space-between;
      margin-bottom: 8px;

      &.total {
        font-size: 1.3rem;
        font-weight: 700;
        padding-top: 8px;
        border-top: 2px solid #e0e0e0;
        color: #1a1a2e;
      }
    }
  }

  .submit-btn {
    padding: 14px;
    font-size: 1rem;
    border-radius: 12px;
  }
}

// Order Status Modal
.order-status-card {
  border-radius: 24px;
  max-width: 500px;
  margin: auto;

  .status-header {
    text-align: center;
    padding: 30px;

    .status-title {
      display: flex;
      flex-direction: column;
      align-items: center;
      gap: 12px;

      h2 {
        margin: 0;
      }
    }

    p {
      margin: 8px 0 0;
      opacity: 0.9;
    }
  }

  .status-content {
    padding: 24px;
  }

  .order-number {
    text-align: center;
    margin-bottom: 30px;

    .label {
      display: block;
      font-size: 0.85rem;
      color: #666;
      margin-bottom: 4px;
    }

    .number {
      font-size: 1.5rem;
      font-weight: 800;
      color: #1a1a2e;
    }
  }

  .status-timeline {
    display: flex;
    flex-direction: column;
    gap: 20px;
    margin-bottom: 30px;

    .timeline-step {
      display: flex;
      align-items: center;
      gap: 16px;
      opacity: 0.4;
      transition: all 0.3s;

      &.active {
        opacity: 1;
      }

      &.current {
        .step-icon {
          animation: pulse 2s infinite;
        }
      }

      .step-icon {
        width: 48px;
        height: 48px;
        border-radius: 50%;
        background: #e0e0e0;
        display: flex;
        align-items: center;
        justify-content: center;
        color: white;
      }

      &.active .step-icon {
        background: linear-gradient(135deg, #e94560 0%, #0f3460 100%);
      }

      .step-info {
        .step-title {
          display: block;
          font-weight: 600;
        }

        .step-desc {
          font-size: 0.85rem;
          color: #666;
        }
      }
    }
  }

  .order-items-preview {
    background: #fafafa;
    border-radius: 12px;
    padding: 16px;

    h4 {
      margin: 0 0 12px;
    }

    .preview-item {
      display: flex;
      align-items: center;
      gap: 12px;
      padding: 8px 0;

      .qty {
        background: #e0e0e0;
        padding: 4px 8px;
        border-radius: 4px;
        font-weight: 600;
        font-size: 0.8rem;
      }

      .name {
        flex: 1;
      }
    }
  }
}

@keyframes pulse {
  0%,
  100% {
    box-shadow: 0 0 0 0 rgba(233, 69, 96, 0.4);
  }
  50% {
    box-shadow: 0 0 0 12px rgba(233, 69, 96, 0);
  }
}

// Transitions
.menu-item-enter-active,
.menu-item-leave-active {
  transition: all 0.3s ease;
}

.menu-item-enter-from,
.menu-item-leave-to {
  opacity: 0;
  transform: scale(0.9);
}

.cart-fab-enter-active,
.cart-fab-leave-active {
  transition: all 0.3s ease;
}

.cart-fab-enter-from,
.cart-fab-leave-to {
  opacity: 0;
  transform: scale(0.5);
}

.cart-item-enter-active,
.cart-item-leave-active {
  transition: all 0.2s ease;
}

.cart-item-enter-from,
.cart-item-leave-to {
  opacity: 0;
  transform: translateX(20px);
}
</style>
