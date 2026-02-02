<template>
  <q-page class="sap-page">
    <!-- Toolbar -->
    <SAPToolbar
      title="Payroll Management"
      icon="payments"
      :badge="payrollEntries.length"
      add-label="Run Payroll"
      :show-export="true"
      @add="openRunPayroll"
      @refresh="loadData"
      @export="exportData"
    />

    <!-- Stats Cards -->
    <div class="row q-col-gutter-md q-mb-md q-px-md">
      <div class="col-6 col-md-3">
        <q-card class="stat-card bg-primary text-white">
          <q-card-section>
            <div class="text-h5">{{ formatCurrency(stats.totalGross) }}</div>
            <div class="text-caption">Total Gross Pay</div>
          </q-card-section>
        </q-card>
      </div>
      <div class="col-6 col-md-3">
        <q-card class="stat-card bg-negative text-white">
          <q-card-section>
            <div class="text-h5">{{ formatCurrency(stats.totalDeductions) }}</div>
            <div class="text-caption">Total Deductions</div>
          </q-card-section>
        </q-card>
      </div>
      <div class="col-6 col-md-3">
        <q-card class="stat-card bg-positive text-white">
          <q-card-section>
            <div class="text-h5">{{ formatCurrency(stats.totalNet) }}</div>
            <div class="text-caption">Total Net Pay</div>
          </q-card-section>
        </q-card>
      </div>
      <div class="col-6 col-md-3">
        <q-card class="stat-card bg-info text-white">
          <q-card-section>
            <div class="text-h5">{{ stats.totalEmployees }}</div>
            <div class="text-caption">Employees Paid</div>
          </q-card-section>
        </q-card>
      </div>
    </div>

    <!-- Main Content -->
    <div class="sap-page-content">
      <div class="row q-col-gutter-md">
        <!-- Payroll Entries List -->
        <div class="col-12 col-md-5">
          <SAPCard title="Payroll Runs" icon="history" no-padding>
            <q-list separator>
              <q-item
                v-for="entry in payrollEntries"
                :key="entry.id"
                clickable
                :active="selectedEntry?.id === entry.id"
                @click="selectEntry(entry)"
              >
                <q-item-section avatar>
                  <q-avatar :color="getStatusColor(entry.status)" text-color="white">
                    <q-icon name="receipt_long" />
                  </q-avatar>
                </q-item-section>
                <q-item-section>
                  <q-item-label class="text-bold">{{ entry.doc_number }}</q-item-label>
                  <q-item-label caption>
                    {{ getMonthName(entry.payroll_month) }} {{ entry.payroll_year }}
                  </q-item-label>
                </q-item-section>
                <q-item-section side>
                  <q-badge :color="getStatusColor(entry.status)" :label="entry.status" />
                </q-item-section>
                <q-item-section side>
                  <div class="text-bold text-primary">
                    {{ formatCurrency(entry.total_net_pay) }}
                  </div>
                  <div class="text-caption">{{ entry.total_employees }} employees</div>
                </q-item-section>
              </q-item>

              <q-item v-if="payrollEntries.length === 0">
                <q-item-section class="text-grey text-center q-pa-lg">
                  <q-icon name="folder_open" size="48px" class="q-mb-sm" />
                  <div>No payroll runs yet</div>
                  <div class="text-caption">Click "Run Payroll" to create one</div>
                </q-item-section>
              </q-item>
            </q-list>
          </SAPCard>
        </div>

        <!-- Salary Slips -->
        <div class="col-12 col-md-7">
          <SAPCard
            :title="selectedEntry ? 'Salary Slips - ' + selectedEntry.doc_number : 'Salary Slips'"
            icon="description"
            no-padding
          >
            <template #header-right v-if="selectedEntry">
              <q-btn
                v-if="selectedEntry.status === 'Draft'"
                color="positive"
                label="Submit"
                icon="check"
                flat
                dense
                @click="submitPayroll"
              />
              <q-btn
                v-if="selectedEntry.status === 'Submitted'"
                color="primary"
                label="Approve"
                icon="verified"
                flat
                dense
                @click="approvePayroll"
              />
            </template>

            <SAPTable
              v-if="selectedEntry"
              :rows="salarySlips"
              :columns="slipColumns"
              :loading="loadingSlips"
              row-key="id"
              sticky-header
              height="calc(100vh - 450px)"
              @row-click="viewSlip"
            >
              <!-- Employee -->
              <template #body-cell-employee="props">
                <q-td :props="props">
                  <div class="text-bold">{{ props.row.employee?.full_name }}</div>
                  <div class="text-caption text-grey">
                    {{ props.row.employee?.employee_code }}
                  </div>
                </q-td>
              </template>

              <!-- Gross Pay -->
              <template #body-cell-gross_pay="props">
                <q-td :props="props" class="text-right text-positive">
                  {{ formatCurrency(props.value) }}
                </q-td>
              </template>

              <!-- Deductions -->
              <template #body-cell-total_deduction="props">
                <q-td :props="props" class="text-right text-negative">
                  ({{ formatCurrency(props.value) }})
                </q-td>
              </template>

              <!-- Net Pay -->
              <template #body-cell-net_pay="props">
                <q-td :props="props" class="text-right text-bold text-primary">
                  {{ formatCurrency(props.value) }}
                </q-td>
              </template>
            </SAPTable>

            <div v-else class="text-center q-pa-xl text-grey">
              <q-icon name="touch_app" size="64px" class="q-mb-md" />
              <div class="text-h6">Select a Payroll Run</div>
              <div class="text-caption">Click on a payroll entry to view salary slips</div>
            </div>
          </SAPCard>
        </div>
      </div>
    </div>

    <!-- Run Payroll Dialog -->
    <SAPDialog
      v-model="showRunDialog"
      title="Run Payroll"
      icon="play_arrow"
      width="500px"
      :loading="processing"
      confirm-label="Process Payroll"
      @confirm="processPayroll"
    >
      <q-banner class="bg-warning text-white q-mb-md" rounded>
        <template v-slot:avatar>
          <q-icon name="info" />
        </template>
        This will generate salary slips for all active employees with salary assignments.
      </q-banner>

      <div class="row q-col-gutter-md">
        <div class="col-6">
          <SAPSelect
            v-model="payrollForm.month"
            label="Month"
            :options="months"
            option-label="label"
            option-value="value"
            required
          />
        </div>
        <div class="col-6">
          <SAPInput
            v-model="payrollForm.year"
            label="Year"
            type="number"
            :min="2020"
            :max="2030"
            required
          />
        </div>
        <div class="col-12">
          <SAPSelect
            v-model="payrollForm.department_id"
            label="Department (Optional)"
            :options="departments"
            option-label="name"
            option-value="id"
            clearable
            hint="Leave empty to process all departments"
          />
        </div>
      </div>
    </SAPDialog>

    <!-- Salary Slip Details Dialog -->
    <SAPDialog
      v-model="showSlipDialog"
      :title="'Salary Slip - ' + selectedSlip?.doc_number"
      icon="receipt_long"
      width="700px"
      :show-confirm="false"
      cancel-label="Close"
    >
      <div v-if="selectedSlip" class="q-gutter-md">
        <!-- Header -->
        <div class="row q-col-gutter-md">
          <div class="col-6">
            <div class="text-caption text-grey">Employee</div>
            <div class="text-bold text-h6">{{ selectedSlip.employee?.full_name }}</div>
            <div class="text-caption">{{ selectedSlip.employee?.employee_code }}</div>
          </div>
          <div class="col-6 text-right">
            <div class="text-caption text-grey">Period</div>
            <div class="text-bold">
              {{ selectedSlip.start_date }} to {{ selectedSlip.end_date }}
            </div>
          </div>
        </div>

        <q-separator />

        <!-- Earnings -->
        <div>
          <div class="text-bold text-positive q-mb-sm">Earnings</div>
          <q-list dense bordered separator>
            <q-item v-for="item in slipEarnings" :key="item.id">
              <q-item-section>{{ item.salary_component?.name }}</q-item-section>
              <q-item-section side class="text-positive">
                {{ formatCurrency(item.amount) }}
              </q-item-section>
            </q-item>
            <q-item class="bg-green-1">
              <q-item-section class="text-bold">Total Earnings</q-item-section>
              <q-item-section side class="text-bold text-positive">
                {{ formatCurrency(selectedSlip.gross_pay) }}
              </q-item-section>
            </q-item>
          </q-list>
        </div>

        <!-- Deductions -->
        <div>
          <div class="text-bold text-negative q-mb-sm">Deductions</div>
          <q-list dense bordered separator>
            <q-item v-for="item in slipDeductions" :key="item.id">
              <q-item-section>{{ item.salary_component?.name }}</q-item-section>
              <q-item-section side class="text-negative">
                ({{ formatCurrency(item.amount) }})
              </q-item-section>
            </q-item>
            <q-item class="bg-red-1">
              <q-item-section class="text-bold">Total Deductions</q-item-section>
              <q-item-section side class="text-bold text-negative">
                ({{ formatCurrency(selectedSlip.total_deduction) }})
              </q-item-section>
            </q-item>
          </q-list>
        </div>

        <q-separator />

        <!-- Net Pay -->
        <div class="row items-center bg-primary text-white q-pa-md rounded-borders">
          <div class="col text-h6">Net Pay</div>
          <div class="col-auto text-h4 text-bold">
            {{ formatCurrency(selectedSlip.net_pay) }}
          </div>
        </div>
      </div>
    </SAPDialog>
  </q-page>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useQuasar } from 'quasar'
import { supabase } from 'src/boot/supabase'
import { useAuthStore } from 'src/stores/authStore'
import { SAPTable, SAPCard, SAPToolbar, SAPDialog, SAPInput, SAPSelect } from 'src/components/sap'

const $q = useQuasar()
const authStore = useAuthStore()

// State
const loading = ref(false)
const loadingSlips = ref(false)
const processing = ref(false)
const payrollEntries = ref([])
const salarySlips = ref([])
const slipDetails = ref([])
const departments = ref([])
const selectedEntry = ref(null)
const selectedSlip = ref(null)
const showRunDialog = ref(false)
const showSlipDialog = ref(false)

const currentDate = new Date()
const payrollForm = ref({
  month: currentDate.getMonth() + 1,
  year: currentDate.getFullYear(),
  department_id: null,
})

const months = [
  { value: 1, label: 'January' },
  { value: 2, label: 'February' },
  { value: 3, label: 'March' },
  { value: 4, label: 'April' },
  { value: 5, label: 'May' },
  { value: 6, label: 'June' },
  { value: 7, label: 'July' },
  { value: 8, label: 'August' },
  { value: 9, label: 'September' },
  { value: 10, label: 'October' },
  { value: 11, label: 'November' },
  { value: 12, label: 'December' },
]

// Computed
const stats = computed(() => {
  if (!selectedEntry.value) {
    // Calculate from all approved payrolls
    const approved = payrollEntries.value.filter((e) => e.status === 'Approved')
    return {
      totalGross: approved.reduce((s, e) => s + (e.total_gross_pay || 0), 0),
      totalDeductions: approved.reduce((s, e) => s + (e.total_deductions || 0), 0),
      totalNet: approved.reduce((s, e) => s + (e.total_net_pay || 0), 0),
      totalEmployees: approved.reduce((s, e) => s + (e.total_employees || 0), 0),
    }
  }
  return {
    totalGross: selectedEntry.value.total_gross_pay || 0,
    totalDeductions: selectedEntry.value.total_deductions || 0,
    totalNet: selectedEntry.value.total_net_pay || 0,
    totalEmployees: selectedEntry.value.total_employees || 0,
  }
})

const slipEarnings = computed(() => slipDetails.value.filter((d) => d.component_type === 'Earning'))

const slipDeductions = computed(() =>
  slipDetails.value.filter((d) => d.component_type === 'Deduction'),
)

// Columns
const slipColumns = [
  { name: 'employee', label: 'Employee', field: 'employee', align: 'left' },
  { name: 'payment_days', label: 'Days', field: 'payment_days', align: 'right' },
  { name: 'gross_pay', label: 'Gross Pay', field: 'gross_pay', align: 'right' },
  { name: 'total_deduction', label: 'Deductions', field: 'total_deduction', align: 'right' },
  { name: 'net_pay', label: 'Net Pay', field: 'net_pay', align: 'right' },
]

// Methods
function formatCurrency(value) {
  if (!value) return 'LKR 0.00'
  return 'LKR ' + parseFloat(value).toLocaleString('en-US', { minimumFractionDigits: 2 })
}

function getStatusColor(status) {
  const colors = {
    Draft: 'grey',
    Submitted: 'warning',
    Approved: 'positive',
    Cancelled: 'negative',
  }
  return colors[status] || 'grey'
}

function getMonthName(month) {
  return months.find((m) => m.value === month)?.label || month
}

async function loadData() {
  loading.value = true
  try {
    // Load payroll entries
    const { data: entries, error: entriesError } = await supabase
      .from('payroll_entries')
      .select('*')
      .order('payroll_year', { ascending: false })
      .order('payroll_month', { ascending: false })

    if (entriesError) throw entriesError
    payrollEntries.value = entries || []

    // Load departments
    const { data: deptData } = await supabase
      .from('departments')
      .select('*')
      .eq('is_active', true)
      .order('name')
    departments.value = deptData || []
  } catch (err) {
    console.error('Error loading payroll:', err)
    $q.notify({ type: 'negative', message: 'Failed to load payroll data' })
  } finally {
    loading.value = false
  }
}

async function selectEntry(entry) {
  selectedEntry.value = entry
  loadingSlips.value = true

  try {
    const { data, error } = await supabase
      .from('salary_slips')
      .select('*, employee:employees(*)')
      .eq('payroll_entry_id', entry.id)
      .order('doc_number')

    if (error) throw error
    salarySlips.value = data || []
  } catch (err) {
    console.error('Error loading slips:', err)
    $q.notify({ type: 'negative', message: 'Failed to load salary slips' })
  } finally {
    loadingSlips.value = false
  }
}

async function viewSlip(row) {
  selectedSlip.value = row

  try {
    const { data, error } = await supabase
      .from('salary_slip_details')
      .select('*, salary_component:salary_components(*)')
      .eq('salary_slip_id', row.id)
      .order('idx')

    if (error) throw error
    slipDetails.value = data || []
    showSlipDialog.value = true
  } catch (err) {
    console.error('Error loading slip details:', err)
  }
}

function openRunPayroll() {
  payrollForm.value = {
    month: currentDate.getMonth() + 1,
    year: currentDate.getFullYear(),
    department_id: null,
  }
  showRunDialog.value = true
}

async function processPayroll() {
  processing.value = true
  try {
    const { data, error } = await supabase.rpc('process_payroll_entry', {
      p_payroll_month: payrollForm.value.month,
      p_payroll_year: payrollForm.value.year,
      p_department_id: payrollForm.value.department_id,
      p_user_id: authStore.user?.id,
    })

    if (error) throw error
    if (!data.success) throw new Error(data.error)

    $q.notify({
      type: 'positive',
      message: `Payroll processed for ${data.total_employees} employees`,
    })
    showRunDialog.value = false
    await loadData()

    // Select the new entry
    const newEntry = payrollEntries.value.find((e) => e.id === data.payroll_entry_id)
    if (newEntry) selectEntry(newEntry)
  } catch (err) {
    console.error('Payroll processing error:', err)
    $q.notify({ type: 'negative', message: err.message || 'Failed to process payroll' })
  } finally {
    processing.value = false
  }
}

async function submitPayroll() {
  if (!selectedEntry.value) return

  try {
    const { error } = await supabase
      .from('payroll_entries')
      .update({ status: 'Submitted', submitted_at: new Date().toISOString() })
      .eq('id', selectedEntry.value.id)

    if (error) throw error

    $q.notify({ type: 'positive', message: 'Payroll submitted for approval' })
    await loadData()
    selectedEntry.value.status = 'Submitted'
  } catch (err) {
    console.error('Submit error:', err)
    $q.notify({ type: 'negative', message: 'Failed to submit payroll' })
  }
}

async function approvePayroll() {
  if (!selectedEntry.value) return

  $q.dialog({
    title: 'Approve Payroll',
    message: `Approve payroll for ${getMonthName(selectedEntry.value.payroll_month)} ${selectedEntry.value.payroll_year}?\n\nTotal Net Pay: ${formatCurrency(selectedEntry.value.total_net_pay)}`,
    cancel: true,
    persistent: true,
  }).onOk(async () => {
    try {
      const { error } = await supabase
        .from('payroll_entries')
        .update({
          status: 'Approved',
          approved_at: new Date().toISOString(),
          approved_by: authStore.user?.id,
        })
        .eq('id', selectedEntry.value.id)

      if (error) throw error

      // Also update all salary slips
      await supabase
        .from('salary_slips')
        .update({ status: 'Submitted' })
        .eq('payroll_entry_id', selectedEntry.value.id)

      $q.notify({ type: 'positive', message: 'Payroll approved!' })
      await loadData()
      selectedEntry.value.status = 'Approved'
    } catch (err) {
      console.error('Approve error:', err)
      $q.notify({ type: 'negative', message: 'Failed to approve payroll' })
    }
  })
}

function exportData() {
  $q.notify({ type: 'info', message: 'Export functionality coming soon' })
}

// Lifecycle
onMounted(() => {
  loadData()
})
</script>

<style lang="scss" scoped>
.sap-page {
  background-color: #f5f5f5;
}

.stat-card {
  border-radius: 12px;

  .text-h5 {
    font-weight: 700;
  }
}
</style>
