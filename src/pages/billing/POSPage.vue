<template>
  <q-page class="pos-page">
    <div class="pos-layout">
      <!-- Left Panel: Orders List -->
      <div class="orders-panel">
        <div class="panel-header">
          <h2>Pending Bills</h2>
          <q-input
            v-model="searchOrder"
            placeholder="Search..."
            dense
            outlined
            class="search-input"
          >
            <template v-slot:prepend><q-icon name="search" /></template>
          </q-input>
        </div>

        <div class="orders-list">
          <div
            v-for="order in filteredOrders"
            :key="order.id"
            class="order-tile"
            :class="{ active: selectedOrder?.id === order.id }"
            @click="selectOrder(order)"
          >
            <div class="tile-header">
              <span class="table-number">{{ order.table_number || 'TK' }}</span>
              <q-badge :color="statusColor(order.status)">{{ order.status }}</q-badge>
            </div>
            <div class="tile-body">
              <span class="order-number">{{ order.order_number }}</span>
              <span class="order-time">{{ formatTime(order.ordered_at) }}</span>
            </div>
            <div class="tile-footer">
              <span class="item-count">{{ order.items?.length || 0 }} items</span>
              <span class="order-total">Rs. {{ order.total_amount?.toFixed(2) }}</span>
            </div>
          </div>

          <div v-if="!filteredOrders.length" class="empty-state">
            <q-icon name="receipt" size="48px" color="grey-4" />
            <p>No pending orders</p>
          </div>
        </div>
      </div>

      <!-- Right Panel: Bill Details -->
      <div class="bill-panel">
        <div v-if="!selectedOrder" class="no-selection">
          <q-icon name="point_of_sale" size="80px" color="grey-4" />
          <h3>Select an Order</h3>
          <p>Choose an order from the left to generate a bill</p>
        </div>

        <div v-else class="bill-content">
          <!-- Bill Header -->
          <div class="bill-header">
            <div class="header-info">
              <h2>{{ selectedOrder.order_number }}</h2>
              <div class="table-info">
                <q-icon name="table_restaurant" />
                <span>{{ selectedOrder.table_number || 'Takeaway' }}</span>
              </div>
            </div>
            <div class="header-meta">
              <span v-if="selectedOrder.customer_name">
                <q-icon name="person" size="16px" />
                {{ selectedOrder.customer_name }}
              </span>
              <span>
                <q-icon name="schedule" size="16px" />
                {{ formatDateTime(selectedOrder.ordered_at) }}
              </span>
            </div>
          </div>

          <!-- Bill Items -->
          <div class="bill-items">
            <q-table
              :rows="selectedOrder.items"
              :columns="itemColumns"
              row-key="id"
              flat
              hide-pagination
              :pagination="{ rowsPerPage: 0 }"
            >
              <template v-slot:body-cell-quantity="props">
                <q-td :props="props" class="qty-cell">
                  {{ props.row.quantity }}
                </q-td>
              </template>
              <template v-slot:body-cell-line_total="props">
                <q-td :props="props" class="amount-cell">
                  Rs. {{ props.row.line_total?.toFixed(2) }}
                </q-td>
              </template>
            </q-table>
          </div>

          <!-- Bill Summary -->
          <div class="bill-summary">
            <div class="summary-row">
              <span>Subtotal</span>
              <span>Rs. {{ selectedOrder.subtotal?.toFixed(2) }}</span>
            </div>
            <div class="summary-row" v-if="discount > 0">
              <span>Discount ({{ discountPercent }}%)</span>
              <span class="discount-amount">-Rs. {{ discount.toFixed(2) }}</span>
            </div>
            <div class="summary-row" v-if="serviceCharge > 0">
              <span>Service Charge</span>
              <span>Rs. {{ serviceCharge.toFixed(2) }}</span>
            </div>
            <div class="summary-row">
              <span>Tax</span>
              <span>Rs. {{ taxAmount.toFixed(2) }}</span>
            </div>
            <q-separator class="q-my-sm" />
            <div class="summary-row total">
              <span>Grand Total</span>
              <span>Rs. {{ grandTotal.toFixed(2) }}</span>
            </div>
          </div>

          <!-- Payment Section -->
          <div class="payment-section">
            <div class="payment-options">
              <q-btn-toggle
                v-model="paymentMethod"
                toggle-color="primary"
                :options="[
                  { label: 'Cash', value: 'cash', icon: 'payments' },
                  { label: 'Card', value: 'card', icon: 'credit_card' },
                  { label: 'UPI', value: 'upi', icon: 'qr_code' },
                ]"
                rounded
                unelevated
              />
            </div>

            <div class="cash-calc" v-if="paymentMethod === 'cash'">
              <q-input
                v-model.number="receivedAmount"
                label="Amount Received"
                type="number"
                outlined
                dense
                prefix="Rs."
                class="received-input"
              />
              <div class="change-display" v-if="receivedAmount >= grandTotal">
                <span class="change-label">Change</span>
                <span class="change-amount"
                  >Rs. {{ (receivedAmount - grandTotal).toFixed(2) }}</span
                >
              </div>
            </div>

            <!-- Discount Input -->
            <div class="discount-input">
              <q-input
                v-model.number="discountPercent"
                label="Discount %"
                type="number"
                outlined
                dense
                :max="100"
                :min="0"
                class="discount-field"
              />
            </div>
          </div>

          <!-- Action Buttons -->
          <div class="bill-actions">
            <q-btn
              color="primary"
              icon="receipt_long"
              label="Generate Bill"
              @click="generateBill"
              :loading="processing"
              :disable="paymentMethod === 'cash' && receivedAmount < grandTotal"
              no-caps
              class="bill-btn"
            />
            <q-btn flat icon="print" label="Print Preview" @click="printBill" no-caps />
            <q-btn flat icon="cancel" label="Void" color="negative" @click="voidOrder" no-caps />
          </div>
        </div>
      </div>
    </div>

    <!-- Print Preview Dialog -->
    <q-dialog v-model="showPrintPreview" full-width>
      <q-card class="print-preview-card">
        <q-card-section class="print-header">
          <div class="text-h6">Print Preview</div>
          <q-btn round flat icon="close" v-close-popup />
        </q-card-section>
        <q-card-section class="print-content" ref="printArea">
          <div class="receipt" v-if="selectedOrder">
            <div class="receipt-header">
              <h1>Seven Waves</h1>
              <p>Restaurant & Cafe</p>
              <p class="address">123 Main Street, City</p>
              <p class="phone">Tel: 012-345-6789</p>
            </div>
            <div class="receipt-divider">--------------------------------</div>
            <div class="receipt-info">
              <p><strong>Bill No:</strong> {{ selectedOrder.order_number }}</p>
              <p><strong>Table:</strong> {{ selectedOrder.table_number || 'Takeaway' }}</p>
              <p><strong>Date:</strong> {{ formatDateTime(new Date()) }}</p>
            </div>
            <div class="receipt-divider">--------------------------------</div>
            <div class="receipt-items">
              <div class="receipt-item" v-for="item in selectedOrder.items" :key="item.id">
                <span class="item-name">{{ item.quantity }}x {{ item.item_name }}</span>
                <span class="item-price">{{ item.line_total?.toFixed(2) }}</span>
              </div>
            </div>
            <div class="receipt-divider">--------------------------------</div>
            <div class="receipt-totals">
              <div class="total-row">
                <span>Subtotal</span>
                <span>{{ selectedOrder.subtotal?.toFixed(2) }}</span>
              </div>
              <div class="total-row" v-if="discount > 0">
                <span>Discount</span>
                <span>-{{ discount.toFixed(2) }}</span>
              </div>
              <div class="total-row">
                <span>Tax</span>
                <span>{{ taxAmount.toFixed(2) }}</span>
              </div>
              <div class="total-row grand">
                <span>TOTAL</span>
                <span>Rs. {{ grandTotal.toFixed(2) }}</span>
              </div>
            </div>
            <div class="receipt-divider">--------------------------------</div>
            <div class="receipt-footer">
              <p>Thank you for dining with us!</p>
              <p>Visit Again</p>
            </div>
          </div>
        </q-card-section>
        <q-card-actions align="right">
          <q-btn flat label="Close" v-close-popup />
          <q-btn color="primary" icon="print" label="Print" @click="doPrint" />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { supabase } from 'src/boot/supabase'
import { useQuasar } from 'quasar'
import { useRoute } from 'vue-router'

const $q = useQuasar()
const route = useRoute()

// State
const orders = ref([])
const selectedOrder = ref(null)
const searchOrder = ref('')
const paymentMethod = ref('cash')
const receivedAmount = ref(0)
const discountPercent = ref(0)
const processing = ref(false)
const showPrintPreview = ref(false)
const printArea = ref(null)

// Item columns
const itemColumns = [
  { name: 'item_name', label: 'Item', field: 'item_name', align: 'left' },
  { name: 'quantity', label: 'Qty', field: 'quantity', align: 'center' },
  {
    name: 'unit_price',
    label: 'Price',
    field: 'unit_price',
    align: 'right',
    format: (v) => `Rs. ${v?.toFixed(2)}`,
  },
  { name: 'line_total', label: 'Amount', field: 'line_total', align: 'right' },
]

// Computed
const filteredOrders = computed(() => {
  let result = orders.value.filter((o) =>
    ['Served', 'Partially Served', 'Billed'].includes(o.status),
  )

  if (searchOrder.value) {
    const search = searchOrder.value.toLowerCase()
    result = result.filter(
      (o) =>
        o.order_number.toLowerCase().includes(search) ||
        o.table_number?.toLowerCase().includes(search),
    )
  }

  return result
})

const discount = computed(() => {
  if (!selectedOrder.value) return 0
  return (selectedOrder.value.subtotal || 0) * (discountPercent.value / 100)
})

const serviceCharge = computed(() => {
  if (!selectedOrder.value) return 0
  return selectedOrder.value.service_charge || 0
})

const taxAmount = computed(() => {
  if (!selectedOrder.value) return 0
  const taxableAmount = (selectedOrder.value.subtotal || 0) - discount.value + serviceCharge.value
  return taxableAmount * 0.05 // 5% tax
})

const grandTotal = computed(() => {
  if (!selectedOrder.value) return 0
  return (
    (selectedOrder.value.subtotal || 0) - discount.value + serviceCharge.value + taxAmount.value
  )
})

// Methods
const fetchOrders = async () => {
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
      .in('status', ['Served', 'Partially Served', 'Billed'])
      .order('ordered_at', { ascending: false })

    if (error) throw error

    orders.value = data.map((o) => ({
      ...o,
      table_number: o.table?.table_number,
    }))

    // Auto-select order from route query
    if (route.query.order_id) {
      const order = orders.value.find((o) => o.id === route.query.order_id)
      if (order) selectOrder(order)
    }
  } catch (err) {
    console.error('Error fetching orders:', err)
    $q.notify({ type: 'negative', message: 'Failed to load orders' })
  }
}

const selectOrder = (order) => {
  selectedOrder.value = order
  receivedAmount.value = 0
  discountPercent.value = order.discount_percent || 0
}

const generateBill = async () => {
  if (!selectedOrder.value) return

  processing.value = true
  try {
    const { error } = await supabase
      .from('order_headers')
      .update({
        status: 'Billed',
        billed_at: new Date().toISOString(),
        discount_amount: discount.value,
        tax_amount: taxAmount.value,
        total_amount: grandTotal.value,
      })
      .eq('id', selectedOrder.value.id)

    if (error) throw error

    // Update table status
    if (selectedOrder.value.table_id) {
      await supabase
        .from('restaurant_tables')
        .update({
          status: 'cleaning',
          current_order_id: null,
          updated_at: new Date().toISOString(),
        })
        .eq('id', selectedOrder.value.table_id)
    }

    $q.notify({ type: 'positive', message: 'Bill generated successfully!' })

    // Show print preview
    showPrintPreview.value = true

    // Refresh orders
    fetchOrders()
    selectedOrder.value = null
  } catch (err) {
    console.error('Error generating bill:', err)
    $q.notify({ type: 'negative', message: 'Failed to generate bill' })
  } finally {
    processing.value = false
  }
}

const printBill = () => {
  showPrintPreview.value = true
}

const doPrint = () => {
  window.print()
}

const voidOrder = () => {
  $q.dialog({
    title: 'Void Order',
    message: 'Are you sure you want to void this order? This cannot be undone.',
    cancel: true,
    persistent: true,
  }).onOk(async () => {
    try {
      const { error } = await supabase
        .from('order_headers')
        .update({ status: 'Cancelled' })
        .eq('id', selectedOrder.value.id)

      if (error) throw error

      $q.notify({ type: 'positive', message: 'Order voided' })
      selectedOrder.value = null
      fetchOrders()
    } catch (err) {
      console.error('Error voiding order:', err)
      $q.notify({ type: 'negative', message: 'Failed to void order' })
    }
  })
}

const formatTime = (dateStr) => {
  if (!dateStr) return ''
  return new Date(dateStr).toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' })
}

const formatDateTime = (dateStr) => {
  if (!dateStr) return ''
  const date = new Date(dateStr)
  return date.toLocaleDateString('en-US', {
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  })
}

const statusColor = (status) => {
  const colors = { Served: 'green', 'Partially Served': 'cyan', Billed: 'purple' }
  return colors[status] || 'grey'
}

// Real-time subscription
let subscription = null

const setupRealtime = () => {
  subscription = supabase
    .channel('billing-channel')
    .on('postgres_changes', { event: '*', schema: 'public', table: 'order_headers' }, () => {
      fetchOrders()
    })
    .subscribe()
}

// Lifecycle
onMounted(() => {
  fetchOrders()
  setupRealtime()
})

onUnmounted(() => {
  if (subscription) supabase.removeChannel(subscription)
})
</script>

<style lang="scss" scoped>
.pos-page {
  height: calc(100vh - 50px);
  overflow: hidden;
}

.pos-layout {
  display: flex;
  height: 100%;
}

.orders-panel {
  width: 350px;
  background: #f5f5f5;
  border-right: 1px solid #e0e0e0;
  display: flex;
  flex-direction: column;

  .panel-header {
    padding: 20px;
    background: white;
    border-bottom: 1px solid #e0e0e0;

    h2 {
      margin: 0 0 12px;
      font-weight: 700;
    }

    .search-input {
      width: 100%;
    }
  }

  .orders-list {
    flex: 1;
    overflow-y: auto;
    padding: 12px;
  }

  .order-tile {
    background: white;
    border-radius: 12px;
    padding: 16px;
    margin-bottom: 12px;
    cursor: pointer;
    transition: all 0.3s;
    border: 2px solid transparent;

    &:hover {
      transform: translateY(-2px);
      box-shadow: 0 4px 16px rgba(0, 0, 0, 0.1);
    }

    &.active {
      border-color: var(--q-primary);
      background: linear-gradient(135deg, #fff 0%, #e3f2fd 100%);
    }

    .tile-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 8px;

      .table-number {
        font-size: 1.2rem;
        font-weight: 800;
        color: #1a1a2e;
      }
    }

    .tile-body {
      .order-number {
        display: block;
        font-size: 0.85rem;
        color: #666;
      }

      .order-time {
        font-size: 0.8rem;
        color: #999;
      }
    }

    .tile-footer {
      display: flex;
      justify-content: space-between;
      margin-top: 12px;
      padding-top: 12px;
      border-top: 1px solid #f0f0f0;

      .item-count {
        font-size: 0.85rem;
        color: #666;
      }

      .order-total {
        font-weight: 700;
        color: var(--q-primary);
      }
    }
  }

  .empty-state {
    text-align: center;
    padding: 40px;
    color: #999;
  }
}

.bill-panel {
  flex: 1;
  display: flex;
  flex-direction: column;
  overflow: hidden;

  .no-selection {
    flex: 1;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    color: #999;

    h3 {
      margin: 16px 0 8px;
    }
  }

  .bill-content {
    flex: 1;
    display: flex;
    flex-direction: column;
    overflow: hidden;
  }

  .bill-header {
    background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%);
    color: white;
    padding: 24px;

    .header-info {
      display: flex;
      align-items: center;
      gap: 20px;

      h2 {
        margin: 0;
        font-weight: 700;
      }

      .table-info {
        display: flex;
        align-items: center;
        gap: 8px;
        background: rgba(255, 255, 255, 0.1);
        padding: 8px 16px;
        border-radius: 20px;
      }
    }

    .header-meta {
      margin-top: 12px;
      display: flex;
      gap: 20px;
      font-size: 0.9rem;
      opacity: 0.8;

      span {
        display: flex;
        align-items: center;
        gap: 6px;
      }
    }
  }

  .bill-items {
    flex: 1;
    overflow-y: auto;
    padding: 20px;

    .qty-cell {
      text-align: center;
      font-weight: 600;
    }

    .amount-cell {
      text-align: right;
      font-weight: 600;
    }
  }

  .bill-summary {
    background: #fafafa;
    padding: 20px;
    border-top: 1px solid #e0e0e0;

    .summary-row {
      display: flex;
      justify-content: space-between;
      margin-bottom: 8px;
      font-size: 0.95rem;

      .discount-amount {
        color: #21ba45;
      }

      &.total {
        font-size: 1.4rem;
        font-weight: 800;
        color: #1a1a2e;

        span:last-child {
          color: var(--q-primary);
        }
      }
    }
  }

  .payment-section {
    padding: 20px;
    background: white;
    border-top: 1px solid #e0e0e0;

    .payment-options {
      margin-bottom: 16px;
    }

    .cash-calc {
      display: flex;
      gap: 16px;
      align-items: center;

      .received-input {
        width: 200px;
      }

      .change-display {
        background: linear-gradient(135deg, #e8f5e9 0%, #c8e6c9 100%);
        padding: 12px 20px;
        border-radius: 12px;

        .change-label {
          display: block;
          font-size: 0.8rem;
          color: #666;
        }

        .change-amount {
          font-size: 1.5rem;
          font-weight: 800;
          color: #21ba45;
        }
      }
    }

    .discount-input {
      margin-top: 16px;

      .discount-field {
        width: 150px;
      }
    }
  }

  .bill-actions {
    display: flex;
    gap: 12px;
    padding: 20px;
    background: #fafafa;
    border-top: 1px solid #e0e0e0;

    .bill-btn {
      flex: 1;
      padding: 14px;
      font-size: 1rem;
    }
  }
}

// Print Preview
.print-preview-card {
  max-width: 400px;

  .print-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
  }

  .print-content {
    max-height: 500px;
    overflow-y: auto;
  }

  .receipt {
    font-family: 'Courier New', monospace;
    font-size: 12px;
    line-height: 1.4;
    text-align: center;

    .receipt-header {
      h1 {
        margin: 0;
        font-size: 18px;
      }

      .address,
      .phone {
        font-size: 10px;
        margin: 2px 0;
      }
    }

    .receipt-divider {
      color: #999;
      margin: 8px 0;
    }

    .receipt-info {
      text-align: left;

      p {
        margin: 2px 0;
      }
    }

    .receipt-items {
      text-align: left;

      .receipt-item {
        display: flex;
        justify-content: space-between;
        margin: 4px 0;
      }
    }

    .receipt-totals {
      .total-row {
        display: flex;
        justify-content: space-between;
        margin: 4px 0;

        &.grand {
          font-weight: bold;
          font-size: 14px;
          margin-top: 8px;
        }
      }
    }

    .receipt-footer {
      margin-top: 12px;

      p {
        margin: 4px 0;
      }
    }
  }
}

@media print {
  .pos-page {
    display: none;
  }

  .print-preview-card {
    box-shadow: none;

    .print-header,
    .q-card__actions {
      display: none;
    }
  }
}
</style>
