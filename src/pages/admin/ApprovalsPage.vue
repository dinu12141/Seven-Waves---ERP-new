<template>
  <q-page class="q-pa-md">
    <!-- Header -->
    <div class="row items-center q-mb-lg">
      <div class="col">
        <div class="text-h4 text-weight-bold">Pending Approvals</div>
        <div class="text-subtitle1 text-grey-7">Review and approve pending documents</div>
      </div>
      <div class="col-auto">
        <q-btn
          flat
          round
          icon="refresh"
          color="primary"
          @click="fetchPendingApprovals"
          :loading="loading"
        >
          <q-tooltip>Refresh</q-tooltip>
        </q-btn>
      </div>
    </div>

    <!-- Stats Cards -->
    <div class="row q-col-gutter-md q-mb-lg">
      <div class="col-12 col-sm-6 col-md-3">
        <q-card class="bg-orange-1">
          <q-card-section>
            <div class="text-h6 text-orange-9">Purchase Orders</div>
            <div class="text-h3 text-weight-bold text-orange">{{ stats.purchaseOrders }}</div>
            <div class="text-caption text-grey-7">Pending approval</div>
          </q-card-section>
        </q-card>
      </div>
      <div class="col-12 col-sm-6 col-md-3">
        <q-card class="bg-blue-1">
          <q-card-section>
            <div class="text-h6 text-blue-9">Goods Receipt</div>
            <div class="text-h3 text-weight-bold text-blue">{{ stats.grn }}</div>
            <div class="text-caption text-grey-7">Pending approval</div>
          </q-card-section>
        </q-card>
      </div>
      <div class="col-12 col-sm-6 col-md-3">
        <q-card class="bg-green-1">
          <q-card-section>
            <div class="text-h6 text-green-9">Leave Requests</div>
            <div class="text-h3 text-weight-bold text-green">{{ stats.leaves }}</div>
            <div class="text-caption text-grey-7">Pending approval</div>
          </q-card-section>
        </q-card>
      </div>
      <div class="col-12 col-sm-6 col-md-3">
        <q-card class="bg-purple-1">
          <q-card-section>
            <div class="text-h6 text-purple-9">Total Pending</div>
            <div class="text-h3 text-weight-bold text-purple">{{ stats.total }}</div>
            <div class="text-caption text-grey-7">All documents</div>
          </q-card-section>
        </q-card>
      </div>
    </div>

    <!-- Filter Tabs -->
    <q-tabs
      v-model="activeTab"
      class="text-grey"
      active-color="primary"
      indicator-color="primary"
      align="left"
      narrow-indicator
    >
      <q-tab name="all" label="All" />
      <q-tab name="purchase_order" label="Purchase Orders" />
      <q-tab name="grn" label="GRN" />
      <q-tab name="leave_application" label="Leave Requests" />
    </q-tabs>

    <q-separator class="q-mb-md" />

    <!-- Approvals Table -->
    <q-table
      :rows="filteredApprovals"
      :columns="columns"
      row-key="id"
      :loading="loading"
      flat
      bordered
      :rows-per-page-options="[10, 20, 50]"
    >
      <template v-slot:body-cell-doc_type="props">
        <q-td :props="props">
          <q-chip :color="getDocTypeColor(props.row.doc_type)" text-color="white" size="sm">
            {{ formatDocType(props.row.doc_type) }}
          </q-chip>
        </q-td>
      </template>

      <template v-slot:body-cell-amount="props">
        <q-td :props="props">
          <span v-if="props.row.doc_type === 'leave_application'">
            {{ props.row.amount }} days
          </span>
          <span v-else>
            {{ formatCurrency(props.row.amount) }}
          </span>
        </q-td>
      </template>

      <template v-slot:body-cell-requested_at="props">
        <q-td :props="props">
          {{ formatDate(props.row.requested_at) }}
        </q-td>
      </template>

      <template v-slot:body-cell-actions="props">
        <q-td :props="props">
          <q-btn
            flat
            round
            dense
            icon="check_circle"
            color="positive"
            @click="approveDocument(props.row)"
            :loading="approving === props.row.id"
          >
            <q-tooltip>Approve</q-tooltip>
          </q-btn>
          <q-btn
            flat
            round
            dense
            icon="cancel"
            color="negative"
            @click="rejectDocument(props.row)"
            :loading="approving === props.row.id"
          >
            <q-tooltip>Reject</q-tooltip>
          </q-btn>
          <q-btn flat round dense icon="visibility" color="info" @click="viewDocument(props.row)">
            <q-tooltip>View Details</q-tooltip>
          </q-btn>
        </q-td>
      </template>

      <template v-slot:no-data>
        <div class="full-width row flex-center q-pa-xl text-grey-6">
          <q-icon name="check_circle" size="3em" class="q-mr-md" />
          <span class="text-h6">No pending approvals</span>
        </div>
      </template>
    </q-table>

    <!-- Rejection Dialog -->
    <q-dialog v-model="showRejectDialog" persistent>
      <q-card style="min-width: 400px">
        <q-card-section class="row items-center">
          <div class="text-h6">Reject Document</div>
          <q-space />
          <q-btn icon="close" flat round dense v-close-popup />
        </q-card-section>

        <q-card-section>
          <q-input
            v-model="rejectReason"
            type="textarea"
            label="Reason for rejection"
            outlined
            rows="3"
            :rules="[(val) => !!val || 'Please provide a reason']"
          />
        </q-card-section>

        <q-card-actions align="right">
          <q-btn flat label="Cancel" v-close-popup />
          <q-btn color="negative" label="Reject" @click="confirmReject" :loading="approving" />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useQuasar } from 'quasar'
import { supabase } from 'src/boot/supabase'

const $q = useQuasar()

// State
const loading = ref(false)
const approving = ref(null)
const approvals = ref([])
const activeTab = ref('all')
const showRejectDialog = ref(false)
const rejectReason = ref('')
const selectedDocument = ref(null)

// Table columns
const columns = [
  {
    name: 'doc_type',
    label: 'Type',
    field: 'doc_type',
    align: 'left',
    sortable: true,
  },
  {
    name: 'doc_number',
    label: 'Document #',
    field: 'doc_number',
    align: 'left',
    sortable: true,
  },
  {
    name: 'description',
    label: 'Description',
    field: 'description',
    align: 'left',
  },
  {
    name: 'amount',
    label: 'Amount',
    field: 'amount',
    align: 'right',
    sortable: true,
  },
  {
    name: 'requested_by',
    label: 'Requested By',
    field: 'requested_by',
    align: 'left',
  },
  {
    name: 'requested_at',
    label: 'Date',
    field: 'requested_at',
    align: 'left',
    sortable: true,
  },
  {
    name: 'actions',
    label: 'Actions',
    field: 'actions',
    align: 'center',
  },
]

// Computed
const filteredApprovals = computed(() => {
  if (activeTab.value === 'all') return approvals.value
  return approvals.value.filter((a) => a.doc_type === activeTab.value)
})

const stats = computed(() => {
  const po = approvals.value.filter((a) => a.doc_type === 'purchase_order').length
  const grn = approvals.value.filter((a) => a.doc_type === 'grn').length
  const leaves = approvals.value.filter((a) => a.doc_type === 'leave_application').length
  return {
    purchaseOrders: po,
    grn: grn,
    leaves: leaves,
    total: po + grn + leaves,
  }
})

// Methods
async function fetchPendingApprovals() {
  loading.value = true
  try {
    const { data, error } = await supabase.from('pending_approvals').select('*')

    if (error) throw error
    approvals.value = data || []
  } catch (err) {
    console.error('Error fetching approvals:', err)
    $q.notify({
      type: 'negative',
      message: 'Failed to load pending approvals',
    })
  } finally {
    loading.value = false
  }
}

async function approveDocument(doc) {
  approving.value = doc.id
  try {
    const { error } = await supabase.rpc('approve_document', {
      p_doc_type: doc.doc_type,
      p_doc_id: doc.id,
      p_action: 'approve',
    })

    if (error) throw error

    $q.notify({
      type: 'positive',
      message: `${formatDocType(doc.doc_type)} ${doc.doc_number} approved successfully`,
    })

    // Refresh list
    await fetchPendingApprovals()
  } catch (err) {
    console.error('Error approving document:', err)
    $q.notify({
      type: 'negative',
      message: err.message || 'Failed to approve document',
    })
  } finally {
    approving.value = null
  }
}

function rejectDocument(doc) {
  selectedDocument.value = doc
  rejectReason.value = ''
  showRejectDialog.value = true
}

async function confirmReject() {
  if (!rejectReason.value) return

  approving.value = selectedDocument.value.id
  try {
    const { error } = await supabase.rpc('approve_document', {
      p_doc_type: selectedDocument.value.doc_type,
      p_doc_id: selectedDocument.value.id,
      p_action: 'reject',
    })

    if (error) throw error

    showRejectDialog.value = false
    $q.notify({
      type: 'warning',
      message: `${formatDocType(selectedDocument.value.doc_type)} ${selectedDocument.value.doc_number} rejected`,
    })

    await fetchPendingApprovals()
  } catch (err) {
    console.error('Error rejecting document:', err)
    $q.notify({
      type: 'negative',
      message: err.message || 'Failed to reject document',
    })
  } finally {
    approving.value = null
  }
}

function viewDocument(doc) {
  // Navigate to the appropriate page based on document type
  const routes = {
    purchase_order: '/stock/po',
    grn: '/stock/grn',
    leave_application: '/hrm/leaves',
  }
  // Could add query params or use a modal here
  $q.notify({
    type: 'info',
    message: `View ${doc.doc_number} - Navigate to ${routes[doc.doc_type]}`,
  })
}

function formatDocType(type) {
  const labels = {
    purchase_order: 'Purchase Order',
    grn: 'Goods Receipt',
    leave_application: 'Leave Request',
  }
  return labels[type] || type
}

function getDocTypeColor(type) {
  const colors = {
    purchase_order: 'orange',
    grn: 'blue',
    leave_application: 'green',
  }
  return colors[type] || 'grey'
}

function formatCurrency(amount) {
  if (!amount) return 'LKR 0.00'
  return new Intl.NumberFormat('en-LK', {
    style: 'currency',
    currency: 'LKR',
  }).format(amount)
}

function formatDate(dateStr) {
  if (!dateStr) return '-'
  return new Date(dateStr).toLocaleDateString('en-GB', {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  })
}

// Lifecycle
onMounted(() => {
  fetchPendingApprovals()
})
</script>

<style scoped>
.q-card {
  border-radius: 12px;
}
</style>
