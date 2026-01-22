<template>
  <q-page class="sap-page">
    <!-- Toolbar -->
    <SAPToolbar
      title="Suppliers"
      icon="local_shipping"
      :badge="stockStore.suppliers.length"
      add-label="New Supplier"
      @add="openCreateDialog"
      @refresh="loadData"
    />

    <!-- Main Content -->
    <div class="sap-page-content">
      <SAPCard title="Supplier List" icon="list" no-padding>
        <SAPTable
          :rows="stockStore.suppliers"
          :columns="columns"
          :loading="stockStore.loading"
          row-key="id"
          @row-click="editSupplier"
        >
          <template #body-cell-code="props">
            <q-td :props="props">
              <div class="row items-center no-wrap">
                <span class="supplier-code q-mr-xs">{{ props.value }}</span>
                <GoldenArrow @click="editSupplier(props.row)" />
              </div>
            </q-td>
          </template>

          <!-- Status Column -->
          <template #body-cell-is_active="props">
            <q-td :props="props" class="text-center">
              <q-badge
                :color="props.value ? 'positive' : 'grey'"
                :label="props.value ? 'Active' : 'Inactive'"
              />
            </q-td>
          </template>

          <!-- Actions -->
          <template #body-cell-actions="props">
            <q-td :props="props" class="actions-cell">
              <q-btn
                flat
                dense
                round
                size="sm"
                icon="edit"
                color="primary"
                @click.stop="editSupplier(props.row)"
              />
              <q-btn
                flat
                dense
                round
                size="sm"
                icon="receipt_long"
                color="info"
                @click.stop="viewPurchaseHistory(props.row)"
              >
                <q-tooltip>Purchase History</q-tooltip>
              </q-btn>
            </q-td>
          </template>
        </SAPTable>
      </SAPCard>
    </div>

    <!-- Create/Edit Dialog -->
    <SAPDialog
      v-model="showDialog"
      :title="isEditing ? 'Edit Supplier' : 'New Supplier'"
      icon="local_shipping"
      width="700px"
      :loading="saving"
      @confirm="submitForm"
    >
      <q-form ref="formRef" @submit.prevent>
        <div class="row q-col-gutter-md">
          <div class="col-12 col-md-4">
            <SAPInput
              v-model="form.code"
              label="Supplier Code"
              required
              placeholder="e.g., SUP001"
              :rules="requiredRules"
            />
          </div>
          <div class="col-12 col-md-8">
            <SAPInput v-model="form.name" label="Supplier Name" required :rules="requiredRules" />
          </div>
          <div class="col-12 col-md-6">
            <SAPInput v-model="form.contact_person" label="Contact Person" />
          </div>
          <div class="col-12 col-md-6">
            <SAPInput v-model="form.phone" label="Phone" />
          </div>
          <div class="col-12 col-md-6">
            <SAPInput v-model="form.email" label="Email" type="email" />
          </div>
          <div class="col-12 col-md-6">
            <SAPInput v-model="form.city" label="City" />
          </div>
          <div class="col-12">
            <SAPInput v-model="form.address" label="Address" type="textarea" rows="2" />
          </div>
          <div class="col-12 col-md-6">
            <SAPInput v-model="form.tax_id" label="Tax ID" />
          </div>
          <div class="col-12 col-md-6">
            <SAPInput
              v-model.number="form.payment_terms"
              label="Payment Terms (Days)"
              type="number"
            />
          </div>
          <div class="col-12">
            <SAPInput v-model="form.notes" label="Notes" type="textarea" rows="2" />
          </div>
          <div class="col-12">
            <q-checkbox v-model="form.is_active" label="Active" dense />
          </div>
        </div>
      </q-form>
    </SAPDialog>
  </q-page>
</template>

<script setup>
import { ref, onMounted, onUnmounted } from 'vue'
import { useQuasar } from 'quasar'
import { useStockStore } from 'src/stores/stockStore'
import { SAPTable, SAPCard, SAPToolbar, SAPDialog, SAPInput, GoldenArrow } from 'src/components/sap'

const $q = useQuasar()
const stockStore = useStockStore()

const showDialog = ref(false)
const isEditing = ref(false)
const saving = ref(false)
const formRef = ref(null)
const form = ref(getEmptyForm())

const requiredRules = [(val) => !!val || 'Field is required']

const columns = [
  { name: 'code', label: 'Code', field: 'code', sortable: true, align: 'left' },
  { name: 'name', label: 'Name', field: 'name', sortable: true, align: 'left' },
  { name: 'contact_person', label: 'Contact', field: 'contact_person', align: 'left' },
  { name: 'phone', label: 'Phone', field: 'phone', align: 'left' },
  { name: 'city', label: 'City', field: 'city', align: 'left' },
  {
    name: 'payment_terms',
    label: 'Terms',
    field: (row) => (row.payment_terms ? `${row.payment_terms} days` : '—'),
    align: 'center',
  },
  { name: 'is_active', label: 'Status', field: 'is_active', align: 'center' },
  { name: 'actions', label: 'Actions', field: 'actions', align: 'center' },
]

function getEmptyForm() {
  return {
    code: '',
    name: '',
    contact_person: '',
    phone: '',
    email: '',
    address: '',
    city: '',
    tax_id: '',
    payment_terms: 30,
    notes: '',
    is_active: true,
  }
}

async function loadData() {
  await stockStore.fetchSuppliers()
}

function openCreateDialog() {
  isEditing.value = false
  form.value = getEmptyForm()
  showDialog.value = true
}

function editSupplier(supplier) {
  isEditing.value = true
  form.value = { ...supplier }
  showDialog.value = true
}

async function saveSupplier() {
  saving.value = true
  try {
    let result
    if (isEditing.value) {
      result = await stockStore.updateSupplier(form.value.id, form.value)
    } else {
      result = await stockStore.createSupplier(form.value)
    }

    if (result.success) {
      $q.notify({
        type: 'positive',
        message: isEditing.value ? 'Supplier updated' : 'Supplier created',
      })
      showDialog.value = false
    } else {
      $q.notify({ type: 'negative', message: result.error })
    }
  } finally {
    saving.value = false
  }
}

async function submitForm() {
  const success = await formRef.value.validate()
  if (success) {
    await saveSupplier()
  }
}

function viewPurchaseHistory(supplier) {
  $q.notify({ type: 'info', message: `Purchase history for ${supplier.name} coming soon` })
}

// Keyboard Shortcuts
function handleKeydown(e) {
  // Ctrl + A: Add Record
  if (e.ctrlKey && e.key === 'a') {
    e.preventDefault()
    openCreateDialog()
  }
  // Esc: Close Dialogs
  if (e.key === 'Escape') {
    showDialog.value = false
  }
}

onMounted(async () => {
  window.addEventListener('keydown', handleKeydown)
  await loadData()
})

onUnmounted(() => {
  window.removeEventListener('keydown', handleKeydown)
})
</script>

<style lang="scss" scoped>
.sap-page {
  background: #f5f7fa;
  min-height: 100vh;
}

.sap-page-content {
  padding: 16px;
}

.supplier-code {
  font-family: 'Consolas', monospace;
  font-weight: 600;
  color: $primary;
}

.actions-cell {
  width: 100px;
}
</style>
