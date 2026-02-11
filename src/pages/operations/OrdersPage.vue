<template>
  <q-page class="orders-page">
    <div class="page-header">
      <div class="header-left">
        <h1 class="page-title">Orders</h1>
        <p class="page-subtitle">{{ activeOrders.length }} active orders</p>
      </div>
      <div class="header-right">
        <q-btn-toggle
          v-model="statusFilter"
          toggle-color="primary"
          :options="statusOptions"
          rounded
          unelevated
        />
        <q-btn color="primary" icon="add" label="New Order" @click="showNewOrderDialog = true" />
      </div>
    </div>

    <!-- Loading State -->
    <div v-if="loading" class="loading-container">
      <q-spinner-dots size="50px" color="primary" />
    </div>

    <!-- Orders Grid -->
    <div v-else class="orders-grid">
      <TransitionGroup name="order-card">
        <q-card v-for="order in filteredOrders" :key="order.id" class="order-card">
          <!-- Order Header -->
          <q-card-section class="order-header" :class="statusClass(order.status)">
            <div class="order-info">
              <span class="order-number">{{ order.order_number }}</span>
              <q-badge :color="statusColor(order.status)">{{ order.status }}</q-badge>
            </div>
            <div class="table-info">
              <q-icon name="table_restaurant" />
              <span>{{ order.table_number || 'Takeaway' }}</span>
            </div>
          </q-card-section>

          <!-- Order Items -->
          <q-card-section>
            <div class="items-list">
              <div
                v-for="item in order.items"
                :key="item.id"
                class="order-item"
                :class="{ served: item.status === 'Served' }"
              >
                <div class="item-qty">{{ item.quantity }}x</div>
                <div class="item-details">
                  <span class="item-name">{{ item.item_name }}</span>
                  <span v-if="item.special_notes" class="item-notes">{{ item.special_notes }}</span>
                </div>
                <div class="item-status">
                  <q-badge :color="statusColor(item.status)" size="sm">
                    {{ item.status }}
                  </q-badge>
                </div>
                <div class="item-price">Rs. {{ item.line_total?.toFixed(2) }}</div>
              </div>
            </div>
          </q-card-section>

          <q-separator />

          <!-- Order Footer -->
          <q-card-section class="order-footer">
            <div class="order-meta">
              <span class="order-time">
                <q-icon name="schedule" size="14px" />
                {{ formatTime(order.ordered_at) }}
              </span>
              <span v-if="order.customer_name" class="customer-name">
                <q-icon name="person" size="14px" />
                {{ order.customer_name }}
              </span>
            </div>
            <div class="order-total">
              <span class="total-label">Total:</span>
              <span class="total-amount">Rs. {{ order.total_amount?.toFixed(2) }}</span>
            </div>
          </q-card-section>

          <!-- Actions -->
          <q-card-actions>
            <q-btn
              flat
              icon="visibility"
              label="View"
              @click="viewOrderDetails(order)"
              color="primary"
            />
            <q-btn
              v-if="order.status === 'Served'"
              flat
              icon="receipt_long"
              label="Bill"
              @click="generateBill(order)"
              color="positive"
            />
            <q-btn
              v-if="order.status !== 'Closed' && order.status !== 'Cancelled'"
              flat
              icon="edit"
              label="Edit"
              @click="editOrder(order)"
              color="secondary"
            />
          </q-card-actions>
        </q-card>
      </TransitionGroup>
    </div>

    <!-- Empty State -->
    <div v-if="!loading && !filteredOrders.length" class="empty-state">
      <q-icon name="receipt_long" size="80px" color="grey-4" />
      <h3>No Orders Found</h3>
      <p>
        {{
          statusFilter === 'all'
            ? 'Create a new order to get started'
            : 'No orders with this status'
        }}
      </p>
    </div>

    <!-- New Order Dialog -->
    <q-dialog v-model="showNewOrderDialog" full-width full-height>
      <q-card class="new-order-dialog">
        <q-card-section class="dialog-header bg-primary text-white">
          <div class="text-h6">New Order</div>
          <q-btn round flat icon="close" v-close-popup />
        </q-card-section>

        <div class="dialog-body">
          <!-- Left Panel: Menu Items -->
          <div class="menu-panel">
            <q-input
              v-model="menuSearch"
              placeholder="Search menu..."
              outlined
              dense
              class="menu-search"
            >
              <template v-slot:prepend>
                <q-icon name="search" />
              </template>
            </q-input>

            <div class="category-tabs">
              <q-chip
                v-for="cat in categories"
                :key="cat"
                :selected="selectedCategory === cat"
                @click="selectedCategory = cat"
                clickable
                color="primary"
                :outline="selectedCategory !== cat"
              >
                {{ cat }}
              </q-chip>
            </div>

            <div class="menu-grid">
              <div
                v-for="item in filteredMenuItems"
                :key="item.item_id"
                class="menu-item"
                @click="addToCart(item)"
              >
                <div class="item-image">
                  <q-icon name="restaurant_menu" size="32px" color="primary" />
                </div>
                <div class="item-info">
                  <span class="item-name">{{ item.item_name }}</span>
                  <span class="item-price">Rs. {{ item.selling_price?.toFixed(2) }}</span>
                </div>
              </div>
            </div>
          </div>

          <!-- Right Panel: Order Cart -->
          <div class="cart-panel">
            <div class="cart-header">
              <h3>Order Cart</h3>
              <q-select
                v-model="newOrder.table_id"
                :options="availableTables"
                option-value="id"
                option-label="table_number"
                emit-value
                map-options
                outlined
                dense
                label="Select Table"
                class="table-select"
              />
            </div>

            <div class="cart-items">
              <div v-if="!cart.length" class="empty-cart">
                <q-icon name="shopping_cart" size="48px" color="grey-4" />
                <p>Add items to cart</p>
              </div>

              <TransitionGroup name="cart-item">
                <div v-for="item in cart" :key="item.item_id" class="cart-item">
                  <div class="cart-item-info">
                    <span class="cart-item-name">{{ item.item_name }}</span>
                    <span class="cart-item-price">Rs. {{ item.selling_price?.toFixed(2) }}</span>
                  </div>
                  <div class="cart-item-qty">
                    <q-btn round flat icon="remove" size="sm" @click="decrementQty(item)" />
                    <span>{{ item.quantity }}</span>
                    <q-btn round flat icon="add" size="sm" @click="incrementQty(item)" />
                  </div>
                  <div class="cart-item-total">
                    Rs. {{ (item.selling_price * item.quantity).toFixed(2) }}
                  </div>
                  <q-btn
                    round
                    flat
                    icon="delete"
                    size="sm"
                    color="negative"
                    @click="removeFromCart(item)"
                  />
                </div>
              </TransitionGroup>
            </div>

            <!-- Special Instructions -->
            <q-input
              v-model="newOrder.special_instructions"
              label="Special Instructions"
              outlined
              dense
              type="textarea"
              rows="2"
              class="q-mt-md"
            />

            <!-- Cart Summary -->
            <div class="cart-summary">
              <div class="summary-row">
                <span>Subtotal</span>
                <span>Rs. {{ cartSubtotal.toFixed(2) }}</span>
              </div>
              <div class="summary-row total">
                <span>Total</span>
                <span>Rs. {{ cartSubtotal.toFixed(2) }}</span>
              </div>
            </div>

            <!-- Submit Button -->
            <q-btn
              color="primary"
              icon="send"
              label="Place Order"
              class="submit-btn"
              :disable="!cart.length || !newOrder.table_id"
              :loading="submitting"
              @click="submitOrder"
              no-caps
            />
          </div>
        </div>
      </q-card>
    </q-dialog>

    <!-- Order Details Dialog -->
    <q-dialog v-model="showDetailsDialog" position="right" full-height>
      <q-card class="details-dialog" v-if="selectedOrder">
        <q-card-section class="dialog-header bg-primary text-white">
          <div>
            <div class="text-h6">{{ selectedOrder.order_number }}</div>
            <div class="text-caption">{{ selectedOrder.table_number || 'Takeaway' }}</div>
          </div>
          <q-btn round flat icon="close" v-close-popup color="white" />
        </q-card-section>

        <q-card-section>
          <div class="status-timeline">
            <div
              v-for="status in orderStatuses"
              :key="status"
              class="status-step"
              :class="{ active: isStatusActive(status), current: selectedOrder.status === status }"
            >
              <div class="step-dot"></div>
              <span class="step-label">{{ status }}</span>
            </div>
          </div>
        </q-card-section>

        <q-separator />

        <q-card-section>
          <h4>Items</h4>
          <q-list>
            <q-item v-for="item in selectedOrder.items" :key="item.id">
              <q-item-section side>
                <q-badge color="primary">{{ item.quantity }}</q-badge>
              </q-item-section>
              <q-item-section>
                <q-item-label>{{ item.item_name }}</q-item-label>
                <q-item-label caption v-if="item.special_notes">{{
                  item.special_notes
                }}</q-item-label>
              </q-item-section>
              <q-item-section side>
                <q-badge :color="statusColor(item.status)">{{ item.status }}</q-badge>
              </q-item-section>
              <q-item-section side> Rs. {{ item.line_total?.toFixed(2) }} </q-item-section>
            </q-item>
          </q-list>
        </q-card-section>

        <q-separator />

        <q-card-section class="text-right">
          <div class="total-section">
            <span>Subtotal:</span>
            <span>Rs. {{ selectedOrder.subtotal?.toFixed(2) }}</span>
          </div>
          <div class="total-section">
            <span>Tax:</span>
            <span>Rs. {{ selectedOrder.tax_amount?.toFixed(2) }}</span>
          </div>
          <div class="total-section grand-total">
            <span>Total:</span>
            <span>Rs. {{ selectedOrder.total_amount?.toFixed(2) }}</span>
          </div>
        </q-card-section>

        <q-card-actions>
          <q-btn
            v-if="selectedOrder.status === 'Served'"
            color="positive"
            icon="receipt_long"
            label="Generate Bill"
            @click="generateBill(selectedOrder)"
            no-caps
            class="full-width"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { supabase } from 'src/boot/supabase'
import { useQuasar } from 'quasar'
import { useRouter, useRoute } from 'vue-router'

const $q = useQuasar()
const router = useRouter()
const route = useRoute()

// State
const orders = ref([])
const menuItems = ref([])
const availableTables = ref([])
const loading = ref(true)
const submitting = ref(false)
const statusFilter = ref('all')
const menuSearch = ref('')
const selectedCategory = ref('All')
const showNewOrderDialog = ref(false)
const showDetailsDialog = ref(false)
const selectedOrder = ref(null)
const cart = ref([])
const newOrder = ref({
  table_id: null,
  special_instructions: '',
})

// Status options
const statusOptions = [
  { label: 'All', value: 'all' },
  { label: 'Active', value: 'active' },
  { label: 'Preparing', value: 'Preparing' },
  { label: 'Served', value: 'Served' },
  { label: 'Closed', value: 'Closed' },
]

const orderStatuses = ['Ordered', 'Preparing', 'Partially Served', 'Served', 'Billed', 'Closed']

// Computed
const activeOrders = computed(() =>
  orders.value.filter((o) => !['Closed', 'Cancelled'].includes(o.status)),
)

const filteredOrders = computed(() => {
  if (statusFilter.value === 'all') return orders.value
  if (statusFilter.value === 'active') return activeOrders.value
  return orders.value.filter((o) => o.status === statusFilter.value)
})

const categories = computed(() => {
  const cats = [...new Set(menuItems.value.map((i) => i.category_name))]
  return ['All', ...cats]
})

const filteredMenuItems = computed(() => {
  let items = menuItems.value

  if (selectedCategory.value !== 'All') {
    items = items.filter((i) => i.category_name === selectedCategory.value)
  }

  if (menuSearch.value) {
    const search = menuSearch.value.toLowerCase()
    items = items.filter((i) => i.item_name.toLowerCase().includes(search))
  }

  return items
})

const cartSubtotal = computed(() =>
  cart.value.reduce((sum, item) => sum + item.selling_price * item.quantity, 0),
)

// Methods
const fetchOrders = async () => {
  loading.value = true
  try {
    const { data, error } = await supabase
      .from('order_headers')
      .select(
        `
        *,
        table:table_id(table_number),
        items:order_items(*)
      `,
      )
      .order('ordered_at', { ascending: false })
      .limit(50)

    if (error) throw error

    orders.value = data.map((o) => ({
      ...o,
      table_number: o.table?.table_number,
    }))
  } catch (err) {
    console.error('Error fetching orders:', err)
    $q.notify({ type: 'negative', message: 'Failed to load orders' })
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

const fetchTables = async () => {
  try {
    const { data, error } = await supabase
      .from('restaurant_tables')
      .select('id, table_number')
      .eq('is_active', true)
      .order('table_number')

    if (error) throw error
    availableTables.value = data || []
  } catch (err) {
    console.error('Error fetching tables:', err)
  }
}

const addToCart = (item) => {
  const existing = cart.value.find((c) => c.item_id === item.item_id)
  if (existing) {
    existing.quantity++
  } else {
    cart.value.push({ ...item, quantity: 1 })
  }
}

const incrementQty = (item) => item.quantity++
const decrementQty = (item) => {
  if (item.quantity > 1) {
    item.quantity--
  } else {
    removeFromCart(item)
  }
}

const removeFromCart = (item) => {
  cart.value = cart.value.filter((c) => c.item_id !== item.item_id)
}

const submitOrder = async () => {
  if (!cart.value.length || !newOrder.value.table_id) return

  submitting.value = true
  try {
    // Get table session
    const { data: sessions } = await supabase
      .from('table_sessions')
      .select('id')
      .eq('table_id', newOrder.value.table_id)
      .eq('is_active', true)
      .limit(1)

    let sessionId = sessions?.[0]?.id

    // Create session if doesn't exist
    if (!sessionId) {
      const { data: newSession } = await supabase.rpc('create_table_session', {
        p_table_id: newOrder.value.table_id,
        p_device_name: 'Staff Order',
      })
      sessionId = newSession?.[0]?.session_id
    }

    // Create order using RPC
    const { error } = await supabase.rpc('create_table_order', {
      p_table_session_id: sessionId,
      p_items: cart.value.map((item) => ({
        item_id: item.item_id,
        quantity: item.quantity,
        special_notes: item.special_notes || '',
      })),
      p_special_instructions: newOrder.value.special_instructions,
    })

    if (error) throw error

    $q.notify({ type: 'positive', message: 'Order created successfully!' })
    showNewOrderDialog.value = false
    cart.value = []
    newOrder.value = { table_id: null, special_instructions: '' }
    fetchOrders()
  } catch (err) {
    console.error('Error creating order:', err)
    $q.notify({ type: 'negative', message: 'Failed to create order: ' + err.message })
  } finally {
    submitting.value = false
  }
}

const viewOrderDetails = (order) => {
  selectedOrder.value = order
  showDetailsDialog.value = true
}

const editOrder = () => {
  // TODO: Implement edit functionality
  $q.notify({ type: 'info', message: 'Edit functionality coming soon' })
}

const generateBill = (order) => {
  router.push({ path: '/billing', query: { order_id: order.id } })
}

const formatTime = (dateStr) => {
  if (!dateStr) return ''
  const date = new Date(dateStr)
  return date.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' })
}

const statusColor = (status) => {
  const colors = {
    Ordered: 'orange',
    Preparing: 'blue',
    'Partially Served': 'cyan',
    Ready: 'teal',
    Served: 'green',
    Billed: 'purple',
    Closed: 'grey',
    Cancelled: 'red',
  }
  return colors[status] || 'grey'
}

const statusClass = () => {
  return ''
}

const isStatusActive = (status) => {
  const statusOrder = orderStatuses
  const currentIndex = statusOrder.indexOf(selectedOrder.value?.status)
  const targetIndex = statusOrder.indexOf(status)
  return targetIndex <= currentIndex
}

// Real-time subscription
let subscription = null

const setupRealtime = () => {
  subscription = supabase
    .channel('orders-channel')
    .on('postgres_changes', { event: '*', schema: 'public', table: 'order_headers' }, () => {
      fetchOrders()
    })
    .on('postgres_changes', { event: '*', schema: 'public', table: 'order_items' }, () => {
      fetchOrders()
    })
    .subscribe()
}

// Handle route params
const handleRouteParams = () => {
  if (route.query.table_id) {
    newOrder.value.table_id = route.query.table_id
    showNewOrderDialog.value = true
  }
}

// Lifecycle
onMounted(() => {
  fetchOrders()
  fetchMenu()
  fetchTables()
  setupRealtime()
  handleRouteParams()
})

onUnmounted(() => {
  if (subscription) supabase.removeChannel(subscription)
})
</script>

<style lang="scss" scoped>
.orders-page {
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

.loading-container {
  display: flex;
  justify-content: center;
  padding: 60px;
}

.empty-state {
  text-align: center;
  padding: 60px;
  color: #666;

  h3 {
    margin: 16px 0 8px;
  }
}

.orders-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(340px, 1fr));
  gap: 20px;
}

.order-card {
  border-radius: 16px;
  overflow: hidden;
  transition: all 0.3s ease;

  &:hover {
    transform: translateY(-4px);
    box-shadow: 0 12px 40px rgba(0, 0, 0, 0.15);
  }

  .order-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 16px;
    background: linear-gradient(135deg, #f5f5f5 0%, #e0e0e0 100%);

    &.ordered {
      background: linear-gradient(135deg, #fff3e0 0%, #ffe0b2 100%);
    }
    &.preparing {
      background: linear-gradient(135deg, #e3f2fd 0%, #bbdefb 100%);
    }
    &.served {
      background: linear-gradient(135deg, #e8f5e9 0%, #c8e6c9 100%);
    }

    .order-info {
      display: flex;
      align-items: center;
      gap: 12px;

      .order-number {
        font-weight: 700;
        color: #1a1a2e;
      }
    }

    .table-info {
      display: flex;
      align-items: center;
      gap: 4px;
      color: #666;
    }
  }

  .items-list {
    max-height: 200px;
    overflow-y: auto;
  }

  .order-item {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 8px 0;
    border-bottom: 1px solid #f0f0f0;

    &:last-child {
      border-bottom: none;
    }

    &.served {
      opacity: 0.6;
    }

    .item-qty {
      background: #e0e0e0;
      padding: 4px 8px;
      border-radius: 4px;
      font-weight: 600;
      font-size: 0.85rem;
    }

    .item-details {
      flex: 1;

      .item-name {
        display: block;
        font-weight: 500;
      }

      .item-notes {
        display: block;
        font-size: 0.75rem;
        color: #666;
        font-style: italic;
      }
    }

    .item-price {
      font-weight: 600;
      color: #1a1a2e;
    }
  }

  .order-footer {
    display: flex;
    justify-content: space-between;
    align-items: center;

    .order-meta {
      display: flex;
      flex-direction: column;
      gap: 4px;
      font-size: 0.85rem;
      color: #666;

      span {
        display: flex;
        align-items: center;
        gap: 4px;
      }
    }

    .order-total {
      text-align: right;

      .total-label {
        font-size: 0.85rem;
        color: #666;
      }

      .total-amount {
        display: block;
        font-size: 1.2rem;
        font-weight: 700;
        color: #1a1a2e;
      }
    }
  }
}

// New Order Dialog
.new-order-dialog {
  width: 100%;
  max-width: 1200px;
  height: 90vh;
  display: flex;
  flex-direction: column;

  .dialog-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
  }

  .dialog-body {
    display: flex;
    flex: 1;
    overflow: hidden;
  }

  .menu-panel {
    flex: 2;
    padding: 20px;
    overflow-y: auto;
    border-right: 1px solid #e0e0e0;

    .menu-search {
      margin-bottom: 16px;
    }

    .category-tabs {
      display: flex;
      flex-wrap: wrap;
      gap: 8px;
      margin-bottom: 20px;
    }

    .menu-grid {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(150px, 1fr));
      gap: 12px;
    }

    .menu-item {
      background: white;
      border: 2px solid #e0e0e0;
      border-radius: 12px;
      padding: 16px;
      cursor: pointer;
      transition: all 0.2s;
      text-align: center;

      &:hover {
        border-color: var(--q-primary);
        transform: scale(1.02);
      }

      .item-image {
        width: 60px;
        height: 60px;
        margin: 0 auto 12px;
        display: flex;
        align-items: center;
        justify-content: center;
        background: #f5f5f5;
        border-radius: 50%;
      }

      .item-info {
        .item-name {
          display: block;
          font-weight: 600;
          font-size: 0.9rem;
          margin-bottom: 4px;
        }

        .item-price {
          color: var(--q-primary);
          font-weight: 700;
        }
      }
    }
  }

  .cart-panel {
    flex: 1;
    padding: 20px;
    display: flex;
    flex-direction: column;
    background: #fafafa;

    .cart-header {
      margin-bottom: 16px;

      h3 {
        margin: 0 0 12px;
        font-weight: 700;
      }
    }

    .cart-items {
      flex: 1;
      overflow-y: auto;
    }

    .empty-cart {
      text-align: center;
      padding: 40px;
      color: #999;
    }

    .cart-item {
      display: flex;
      align-items: center;
      gap: 12px;
      padding: 12px;
      background: white;
      border-radius: 8px;
      margin-bottom: 8px;

      .cart-item-info {
        flex: 1;

        .cart-item-name {
          display: block;
          font-weight: 600;
        }

        .cart-item-price {
          font-size: 0.85rem;
          color: #666;
        }
      }

      .cart-item-qty {
        display: flex;
        align-items: center;
        gap: 8px;

        span {
          font-weight: 700;
          min-width: 24px;
          text-align: center;
        }
      }

      .cart-item-total {
        font-weight: 700;
        color: var(--q-primary);
      }
    }

    .cart-summary {
      background: white;
      padding: 16px;
      border-radius: 8px;
      margin-top: 16px;

      .summary-row {
        display: flex;
        justify-content: space-between;
        margin-bottom: 8px;

        &.total {
          font-size: 1.2rem;
          font-weight: 700;
          padding-top: 8px;
          border-top: 2px solid #e0e0e0;
        }
      }
    }

    .submit-btn {
      margin-top: 16px;
      width: 100%;
      padding: 12px;
      font-size: 1rem;
    }
  }
}

// Details Dialog
.details-dialog {
  width: 450px;
  max-width: 100vw;

  .dialog-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
  }

  .status-timeline {
    display: flex;
    justify-content: space-between;
    position: relative;

    &::before {
      content: '';
      position: absolute;
      top: 8px;
      left: 0;
      right: 0;
      height: 2px;
      background: #e0e0e0;
    }

    .status-step {
      position: relative;
      text-align: center;

      .step-dot {
        width: 16px;
        height: 16px;
        border-radius: 50%;
        background: #e0e0e0;
        margin: 0 auto 8px;
        position: relative;
        z-index: 1;
      }

      .step-label {
        font-size: 0.7rem;
        color: #999;
      }

      &.active {
        .step-dot {
          background: var(--q-primary);
        }
        .step-label {
          color: var(--q-primary);
        }
      }

      &.current {
        .step-dot {
          box-shadow: 0 0 0 4px rgba(var(--q-primary-rgb), 0.3);
        }
        .step-label {
          font-weight: 700;
        }
      }
    }
  }

  h4 {
    margin: 0 0 12px;
    font-weight: 600;
  }

  .total-section {
    display: flex;
    justify-content: space-between;
    margin-bottom: 8px;

    &.grand-total {
      font-size: 1.3rem;
      font-weight: 700;
      padding-top: 12px;
      border-top: 2px solid #e0e0e0;
      color: var(--q-primary);
    }
  }
}

// Transitions
.order-card-enter-active,
.order-card-leave-active {
  transition: all 0.3s ease;
}

.order-card-enter-from,
.order-card-leave-to {
  opacity: 0;
  transform: scale(0.9);
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
