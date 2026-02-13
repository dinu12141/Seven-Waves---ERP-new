<template>
  <q-layout view="hHh lpR fFf" class="fullscreen bg-grey-2">
    <!-- Header -->
    <q-header elevated class="bg-primary text-white">
      <q-toolbar>
        <q-btn flat round dense icon="arrow_back" @click="$router.push('/dashboard')" />
        <q-toolbar-title> POS Terminal </q-toolbar-title>
        <q-space />
        <div class="text-subtitle1 q-mr-md">{{ formattedDate }}</div>
        <q-btn flat round dense icon="wifi" />
        <q-btn flat round dense icon="power_settings_new" />
      </q-toolbar>
    </q-header>

    <q-page-container class="row full-height">
      <!-- LEFT PANE: Product Catalog -->
      <div class="col-8 q-pa-md column full-height">
        <!-- Search & Filter -->
        <div class="row q-mb-md q-gutter-sm">
          <q-input
            v-model="posStore.searchQuery"
            outlined
            dense
            placeholder="Search items..."
            class="col-grow bg-white"
            clearable
          >
            <template v-slot:prepend>
              <q-icon name="search" />
            </template>
          </q-input>

          <q-select
            v-model="posStore.activeCategory"
            :options="categoryOptions"
            outlined
            dense
            emit-value
            map-options
            class="col-3 bg-white"
            label="Category"
          />
        </div>

        <!-- Category Tabs (Optional Visual Filter) -->
        <q-tabs
          v-model="posStore.activeCategory"
          dense
          class="text-grey"
          active-color="primary"
          indicator-color="primary"
          align="left"
          narrow-indicator
        >
          <q-tab name="All" label="All Items" />
          <q-tab
            v-for="cat in posStore.categories.filter((c) => c.id !== 'all')"
            :key="cat.id"
            :name="cat.name"
            :label="cat.name"
          />
        </q-tabs>

        <q-separator class="q-my-sm" />

        <!-- Product Grid -->
        <q-scroll-area class="col full-height q-pr-sm">
          <div v-if="posStore.loading" class="row justify-center q-pa-lg">
            <q-spinner size="3em" color="primary" />
          </div>

          <div v-else class="row q-col-gutter-md">
            <div
              v-for="product in posStore.filteredProducts"
              :key="product.id"
              class="col-xs-6 col-sm-4 col-md-3"
            >
              <q-card
                class="cursor-pointer hover-effect column full-height"
                @click="posStore.addToCart(product)"
                v-ripple
              >
                <q-img
                  :src="product.image_url || 'https://placehold.co/150'"
                  :ratio="1"
                  class="col-grow"
                >
                  <div class="absolute-bottom text-subtitle2 text-center q-pa-xs">
                    {{ product.item_name }}
                  </div>
                </q-img>

                <q-card-section class="q-pa-sm text-center bg-grey-1">
                  <div class="text-bold text-primary">
                    {{ formatCurrency(product.selling_price) }}
                  </div>
                  <div class="text-caption text-grey">
                    Stock: {{ product.stock_level || 'N/A' }}
                  </div>
                </q-card-section>
              </q-card>
            </div>
          </div>
        </q-scroll-area>
      </div>

      <!-- RIGHT PANE: Cart & Checkout -->
      <div class="col-4 bg-white shadow-2 column full-height">
        <!-- Cart Header -->
        <div class="q-pa-md bg-grey-1 border-bottom row items-center justify-between">
          <div class="text-h6">Current Order</div>
          <q-btn flat round dense icon="delete_outline" color="negative" @click="confirmClearCart">
            <q-tooltip>Clear Cart</q-tooltip>
          </q-btn>
        </div>

        <!-- Cart Items -->
        <q-scroll-area class="col q-px-md">
          <q-list separator>
            <transition-group name="list">
              <q-item v-for="item in posStore.cart" :key="item.id" class="q-py-md">
                <q-item-section>
                  <q-item-label class="text-weight-bold">{{ item.name }}</q-item-label>
                  <q-item-label caption
                    >{{ formatCurrency(item.price) }} x {{ item.quantity }}</q-item-label
                  >
                </q-item-section>

                <q-item-section side>
                  <div class="row items-center no-wrap">
                    <q-btn
                      round
                      dense
                      flat
                      icon="remove_circle_outline"
                      color="grey"
                      @click="posStore.removeFromCart(item.id)"
                    />
                    <div class="q-mx-sm text-subtitle1">{{ item.quantity }}</div>
                    <q-btn
                      round
                      dense
                      flat
                      icon="add_circle_outline"
                      color="primary"
                      @click="posStore.addToCart(item)"
                    />
                  </div>
                  <div class="text-subtitle2 text-right q-mt-xs">
                    {{ formatCurrency(item.line_total) }}
                  </div>
                </q-item-section>
              </q-item>
            </transition-group>
          </q-list>

          <div
            v-if="posStore.cart.length === 0"
            class="column items-center justify-center q-pa-xl text-grey-5"
          >
            <q-icon name="shopping_cart" size="4em" />
            <div class="q-mt-md">Cart is empty</div>
          </div>
        </q-scroll-area>

        <!-- Cart Summary & Actions -->
        <div class="q-pa-md bg-grey-1 border-top">
          <div class="row justify-between q-mb-xs text-grey-8">
            <div>Subtotal</div>
            <div>{{ formatCurrency(posStore.cartTotal) }}</div>
          </div>
          <div class="row justify-between q-mb-xs text-grey-8">
            <div>Tax (0%)</div>
            <div>$0.00</div>
          </div>
          <q-separator class="q-my-sm" />
          <div class="row justify-between text-h5 text-bold text-primary q-mb-lg">
            <div>Total</div>
            <div>{{ formatCurrency(posStore.cartTotal) }}</div>
          </div>

          <div class="row q-gutter-md">
            <q-btn
              outline
              color="orange"
              label="Hold"
              class="col"
              icon="pause"
              :disable="posStore.cart.length === 0"
            />
            <q-btn
              unelevated
              color="positive"
              label="Checkout"
              class="col-7"
              size="lg"
              icon="payment"
              :disable="posStore.cart.length === 0"
              @click="openCheckout"
            />
          </div>
        </div>
      </div>
    </q-page-container>

    <!-- Payment Dialog -->
    <q-dialog v-model="posStore.showPaymentDialog" persistent>
      <q-card style="width: 500px; max-width: 80vw">
        <q-card-section class="row items-center q-pb-none">
          <div class="text-h6">Payment</div>
          <q-space />
          <q-btn icon="close" flat round dense v-close-popup />
        </q-card-section>

        <q-separator class="q-my-md" />

        <q-card-section>
          <div class="text-center q-mb-lg">
            <div class="text-caption text-uppercase text-grey">Total Amount</div>
            <div class="text-h3 text-primary text-bold">
              {{ formatCurrency(posStore.cartTotal) }}
            </div>
          </div>

          <div class="q-gutter-md">
            <q-select
              v-model="paymentMethod"
              :options="['Cash', 'Card', 'Online Transfer']"
              label="Payment Method"
              outlined
              dense
            />

            <div v-if="paymentMethod === 'Cash'">
              <q-input
                v-model.number="amountTendered"
                label="Amount Tendered"
                outlined
                type="number"
                prefix="$"
                autofocus
                :rules="[(val) => val >= posStore.cartTotal || 'Insufficient amount']"
              />

              <div class="row justify-between q-mt-md q-pa-md bg-grey-2 rounded-borders">
                <div class="text-subtitle1">Change Due:</div>
                <div class="text-h6 text-positive">
                  {{ formatCurrency(Math.max(0, amountTendered - posStore.cartTotal)) }}
                </div>
              </div>
            </div>
          </div>
        </q-card-section>

        <q-card-actions align="right" class="q-pa-md">
          <q-btn flat label="Cancel" v-close-popup color="grey" />
          <q-btn
            unelevated
            label="Finalize Bill"
            color="primary"
            :loading="posStore.checkoutLoading"
            @click="processPayment"
            :disable="paymentMethod === 'Cash' && amountTendered < posStore.cartTotal"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </q-layout>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { usePosStore } from 'src/stores/posStore'
import { date, useQuasar } from 'quasar'

const $q = useQuasar()
const posStore = usePosStore()

// Local State
const paymentMethod = ref('Cash')
const amountTendered = ref(0)
const formattedDate = computed(() => date.formatDate(Date.now(), 'ddd, MMM D, HH:mm'))

// Computed
const categoryOptions = computed(() =>
  posStore.categories.map((c) => ({ label: c.name, value: c.name })),
)

// Methods
function formatCurrency(value) {
  return new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(value)
}

function confirmClearCart() {
  $q.dialog({
    title: 'Confirm',
    message: 'Are you sure you want to clear the cart?',
    cancel: true,
    persistent: true,
  }).onOk(() => {
    posStore.clearCart()
  })
}

function openCheckout() {
  amountTendered.value = 0
  paymentMethod.value = 'Cash' // Reset default
  posStore.showPaymentDialog = true
}

async function processPayment() {
  const result = await posStore.processCheckout({
    method: paymentMethod.value.toLowerCase(),
    tendered: amountTendered.value,
  })

  if (result.success) {
    posStore.showPaymentDialog = false
    $q.notify({
      type: 'positive',
      message: `Transaction successful! Invoice #${result.invoiceId.split('-')[0]}`,
      position: 'top',
    })
  } else {
    $q.notify({
      type: 'negative',
      message: 'Transaction failed: ' + result.error,
    })
  }
}

// Lifecycle
onMounted(async () => {
  await posStore.fetchCategories()
  await posStore.fetchProducts()
})
</script>

<style lang="scss" scoped>
.hover-effect {
  transition:
    transform 0.2s,
    box-shadow 0.2s;
  &:hover {
    transform: translateY(-2px);
    box-shadow: 0 4px 8px rgba(0, 0, 0, 0.15);
  }
}
.border-bottom {
  border-bottom: 1px solid #e0e0e0;
}
.border-top {
  border-top: 1px solid #e0e0e0;
}

/* List Transitions */
.list-enter-active,
.list-leave-active {
  transition: all 0.3s ease;
}
.list-enter-from,
.list-leave-to {
  opacity: 0;
  transform: translateX(30px);
}
</style>
