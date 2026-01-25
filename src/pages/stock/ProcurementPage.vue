<template>
  <q-page class="sap-page">
    <SAPToolbar
      title="Procurement Dashboard"
      icon="shopping_basket"
      :show-add="false"
      :show-export="true"
      @refresh="loadData"
    />

    <div class="sap-page-content">
      <!-- Top Cards -->
      <div class="row q-col-gutter-sd q-mb-md">
        <div class="col-12 col-md-3">
          <q-card class="dashboard-card bg-orange-1">
            <q-card-section>
              <div class="text-subtitle2 text-orange-9">Low Stock Items</div>
              <div class="text-h4 text-orange-10 q-mt-sm text-bold">
                {{ stockStore.alerts.length }}
              </div>
            </q-card-section>
          </q-card>
        </div>
        <div class="col-12 col-md-3">
          <q-card class="dashboard-card bg-blue-1">
            <q-card-section>
              <div class="text-subtitle2 text-blue-9">Pending Requests</div>
              <div class="text-h4 text-blue-10 q-mt-sm text-bold">
                {{ stockStore.purchaseRequests.length }}
              </div>
            </q-card-section>
          </q-card>
        </div>
      </div>

      <div class="row q-col-gutter-md">
        <!-- Low Stock Alerts Panel -->
        <div class="col-12 col-lg-6">
          <SAPCard
            title="Low Stock Alerts (Re-order Recommendation)"
            icon="warning"
            class="full-height"
          >
            <SAPTable
              :rows="stockStore.alerts"
              :columns="alertColumns"
              :loading="stockStore.loading"
              dense
              flat
            >
              <template #body-cell-actions="props">
                <q-td :props="props" class="text-center">
                  <q-btn
                    size="sm"
                    color="primary"
                    label="Raise PR"
                    dense
                    unelevated
                    @click="openPRDialog(props.row)"
                  />
                </q-td>
              </template>
              <template #body-cell-available="props">
                <q-td :props="props" class="text-right text-bold text-negative">
                  {{ formatNumber(props.row.available_stock) }}
                </q-td>
              </template>
            </SAPTable>
          </SAPCard>
        </div>

        <!-- Purchase Requests Panel -->
        <div class="col-12 col-lg-6">
          <SAPCard title="Purchase Requests (PR)" icon="assignment" class="full-height">
            <SAPTable
              :rows="stockStore.purchaseRequests"
              :columns="prColumns"
              :loading="stockStore.loading"
              dense
              flat
            >
              <template #body-cell-actions="props">
                <q-td :props="props" class="text-center">
                  <q-btn
                    v-if="props.row.status === 'Open'"
                    size="sm"
                    color="positive"
                    label="Convert to PO"
                    dense
                    unelevated
                    @click="convertToPO(props.row)"
                  />
                  <q-chip v-else size="sm">{{ props.row.status }}</q-chip>
                </q-td>
              </template>
            </SAPTable>
          </SAPCard>
        </div>
      </div>
    </div>

    <!-- Create PR Dialog -->
    <SAPDialog
      v-model="showPRDialog"
      title="Create Purchase Request"
      icon="add_shopping_cart"
      width="600px"
      confirm-label="Create Request"
      @confirm="submitPR"
    >
      <div v-if="selectedAlertItem">
        <div class="text-subtitle1 q-mb-md">
          Item: {{ selectedAlertItem.item_code }} - {{ selectedAlertItem.item_name }}
        </div>

        <SAPInput
          v-model="prFormData.required_quantity"
          label="Required Quantity"
          type="number"
          autofocus
        />
        <SAPInput v-model="prFormData.required_date" label="Required Date" type="date" />
        <SAPSelect
          v-model="prFormData.preferred_vendor_id"
          label="Preferred Vendor"
          :options="stockStore.suppliers"
          option-label="name"
          option-value="id"
        />
        <SAPInput v-model="prFormData.remarks" label="Remarks" type="textarea" />
      </div>
    </SAPDialog>
  </q-page>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useStockStore } from 'src/stores/stockStore'
import { SAPToolbar, SAPCard, SAPTable, SAPDialog, SAPInput, SAPSelect } from 'src/components/sap'
import { date, useQuasar } from 'quasar'

const stockStore = useStockStore()
const $q = useQuasar()

// State
const showPRDialog = ref(false)
const selectedAlertItem = ref(null)
const prFormData = ref({
  required_quantity: 0,
  required_date: date.formatDate(Date.now(), 'YYYY-MM-DD'),
  preferred_vendor_id: null,
  remarks: '',
})

// Columns
const alertColumns = [
  { name: 'item_code', label: 'Item No.', field: 'item_code', align: 'left', sortable: true },
  { name: 'available', label: 'Avail.', field: 'available_stock', align: 'right', sortable: true },
  { name: 'min_stock', label: 'Min.', field: 'min_stock', align: 'right' },
  { name: 'reorder', label: 'Suggest Qty', field: 'reorder_qty', align: 'right' },
  { name: 'actions', label: 'Action', align: 'center' },
]

const prColumns = [
  { name: 'doc_number', label: 'No.', field: 'doc_number', align: 'left' },
  { name: 'req_date', label: 'Req. Date', field: 'required_date', align: 'left' },
  {
    name: 'requester',
    label: 'Requester',
    field: (row) => row.requester?.full_name,
    align: 'left',
  },
  { name: 'status', label: 'Status', field: 'status', align: 'center' },
  { name: 'actions', label: 'Action', align: 'center' },
]

// Lifecycle
onMounted(() => {
  loadData()
})

function loadData() {
  stockStore.checkStockAlerts()
  stockStore.fetchPurchaseRequests()
  stockStore.fetchSuppliers()
}

function formatNumber(val) {
  return val ? parseFloat(val).toFixed(2) : '0.00'
}

function openPRDialog(alertItem) {
  selectedAlertItem.value = alertItem
  prFormData.value = {
    required_quantity: alertItem.reorder_qty,
    required_date: date.formatDate(Date.now(), 'YYYY-MM-DD'),
    preferred_vendor_id: alertItem.preferred_vendor_id,
    remarks: 'Generated from Low Stock Alert',
  }
  showPRDialog.value = true
}

async function submitPR() {
  if (!prFormData.value.required_quantity || prFormData.value.required_quantity <= 0) {
    $q.notify({ type: 'negative', message: 'Invalid Quantity' })
    return
  }

  const prHeader = {
    requester_id: null, // Should bind to auth user link in store if mapped
    required_date: prFormData.value.required_date,
    remarks: prFormData.value.remarks,
    status: 'Open',
  }

  const line = {
    item_id: selectedAlertItem.value.item_id,
    required_quantity: prFormData.value.required_quantity,
    preferred_vendor_id: prFormData.value.preferred_vendor_id,
    // Assume Base UoM for simplicity or fetch item first
    uom_id: null, // Ideally fetch from item master
  }

  const result = await stockStore.createPurchaseRequest(prHeader, [line])

  if (result.success) {
    $q.notify({ type: 'positive', message: 'Purchase Request Created' })
    showPRDialog.value = false
  } else {
    $q.notify({ type: 'negative', message: result.error })
  }
}

// Stub for conversion logic - to be expanded to open PO dialog pre-filled
// Stub for conversion logic - to be expanded to open PO dialog pre-filled
function convertToPO(prRow) {
  // Logic: Navigate to PO Page with PR ID as query param to pre-fill?
  // Or open a dialog here. For MVP, we can alert.
  console.log('Converting PR:', prRow)
  $q.dialog({
    title: 'Convert to PO',
    message: 'This feature will pre-fill a Purchase Order from this PR.',
  })
}
</script>

<style lang="scss" scoped>
.dashboard-card {
  height: 100%;
}
</style>
