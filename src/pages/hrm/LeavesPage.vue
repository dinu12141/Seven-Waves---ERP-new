<template>
  <q-page class="sap-page">
    <!-- Toolbar -->
    <SAPToolbar
      title="Leave Management"
      icon="event_busy"
      :badge="pendingLeaves.length"
      add-label="Apply Leave"
      :show-export="true"
      :show-filter="true"
      @add="openApplyLeave"
      @refresh="loadData"
    />

    <!-- Stats Cards -->
    <div class="row q-col-gutter-md q-mb-md q-px-md">
      <div class="col-6 col-md-3">
        <q-card class="stat-card bg-warning text-white">
          <q-card-section>
            <div class="text-h4">{{ pendingLeaves.length }}</div>
            <div class="text-caption">Pending Approval</div>
          </q-card-section>
        </q-card>
      </div>
      <div class="col-6 col-md-3">
        <q-card class="stat-card bg-positive text-white">
          <q-card-section>
            <div class="text-h4">{{ approvedThisMonth }}</div>
            <div class="text-caption">Approved This Month</div>
          </q-card-section>
        </q-card>
      </div>
      <div class="col-6 col-md-3">
        <q-card class="stat-card bg-negative text-white">
          <q-card-section>
            <div class="text-h4">{{ rejectedThisMonth }}</div>
            <div class="text-caption">Rejected This Month</div>
          </q-card-section>
        </q-card>
      </div>
      <div class="col-6 col-md-3">
        <q-card class="stat-card bg-info text-white">
          <q-card-section>
            <div class="text-h4">{{ onLeaveToday }}</div>
            <div class="text-caption">On Leave Today</div>
          </q-card-section>
        </q-card>
      </div>
    </div>

    <!-- Main Content -->
    <div class="sap-page-content">
      <!-- Tabs for different views -->
      <q-tabs v-model="activeView" class="q-mb-md" align="left" dense>
        <q-tab name="pending" label="Pending Approval" icon="pending" />
        <q-tab name="all" label="All Applications" icon="list" />
        <q-tab name="calendar" label="Leave Calendar" icon="calendar_month" />
      </q-tabs>

      <q-tab-panels v-model="activeView" animated>
        <!-- Pending Approvals -->
        <q-tab-panel name="pending" class="q-pa-none">
          <SAPCard title="Pending Leave Applications" icon="pending_actions" no-padding>
            <SAPTable
              :rows="pendingLeaves"
              :columns="columns"
              :loading="loading"
              row-key="id"
              sticky-header
              height="calc(100vh - 450px)"
            >
              <!-- Employee -->
              <template #body-cell-employee="props">
                <q-td :props="props">
                  <div class="row items-center no-wrap">
                    <q-avatar size="32px" color="primary" text-color="white" class="q-mr-sm">
                      {{ props.row.employee?.first_name?.charAt(0) }}
                    </q-avatar>
                    <div>
                      <div class="text-bold">{{ props.row.employee?.full_name }}</div>
                      <div class="text-caption text-grey">
                        {{ props.row.employee?.employee_code }}
                      </div>
                    </div>
                  </div>
                </q-td>
              </template>

              <!-- Leave Type -->
              <template #body-cell-leave_type="props">
                <q-td :props="props">
                  <q-chip
                    size="sm"
                    :color="getLeaveTypeColor(props.row.leave_type?.code)"
                    text-color="white"
                    :label="props.row.leave_type?.name"
                  />
                </q-td>
              </template>

              <!-- Status -->
              <template #body-cell-status="props">
                <q-td :props="props">
                  <q-badge :color="getStatusColor(props.value)" :label="props.value" />
                </q-td>
              </template>

              <!-- Actions -->
              <template #body-cell-actions="props">
                <q-td :props="props">
                  <q-btn
                    size="sm"
                    color="positive"
                    icon="check"
                    flat
                    round
                    @click="approveLeave(props.row)"
                  >
                    <q-tooltip>Approve</q-tooltip>
                  </q-btn>
                  <q-btn
                    size="sm"
                    color="negative"
                    icon="close"
                    flat
                    round
                    @click="rejectLeave(props.row)"
                  >
                    <q-tooltip>Reject</q-tooltip>
                  </q-btn>
                  <q-btn
                    size="sm"
                    color="info"
                    icon="visibility"
                    flat
                    round
                    @click="viewLeave(props.row)"
                  >
                    <q-tooltip>View Details</q-tooltip>
                  </q-btn>
                </q-td>
              </template>
            </SAPTable>
          </SAPCard>
        </q-tab-panel>

        <!-- All Applications -->
        <q-tab-panel name="all" class="q-pa-none">
          <SAPCard title="All Leave Applications" icon="list" no-padding>
            <SAPTable
              :rows="allLeaves"
              :columns="columns"
              :loading="loading"
              row-key="id"
              sticky-header
              height="calc(100vh - 450px)"
            >
              <template #body-cell-employee="props">
                <q-td :props="props">
                  <div class="text-bold">{{ props.row.employee?.full_name }}</div>
                </q-td>
              </template>

              <template #body-cell-leave_type="props">
                <q-td :props="props">
                  <q-chip
                    size="sm"
                    :color="getLeaveTypeColor(props.row.leave_type?.code)"
                    text-color="white"
                    :label="props.row.leave_type?.name"
                  />
                </q-td>
              </template>

              <template #body-cell-status="props">
                <q-td :props="props">
                  <q-badge :color="getStatusColor(props.value)" :label="props.value" />
                </q-td>
              </template>
            </SAPTable>
          </SAPCard>
        </q-tab-panel>

        <!-- Calendar View -->
        <q-tab-panel name="calendar" class="q-pa-none">
          <SAPCard title="Leave Calendar" icon="calendar_month">
            <div class="text-center q-pa-xl text-grey">
              <q-icon name="calendar_month" size="64px" class="q-mb-md" />
              <div class="text-h6">Calendar View Coming Soon</div>
              <div class="text-caption">Visual calendar with leave dates</div>
            </div>
          </SAPCard>
        </q-tab-panel>
      </q-tab-panels>
    </div>

    <!-- Apply Leave Dialog -->
    <SAPDialog
      v-model="showLeaveDialog"
      title="Apply for Leave"
      icon="event_busy"
      width="600px"
      :loading="saving"
      confirm-label="Submit"
      @confirm="submitLeave"
    >
      <div class="row q-col-gutter-md">
        <div class="col-12">
          <SAPSelect
            v-model="leaveForm.employee_id"
            label="Employee"
            :options="employees"
            option-label="full_name"
            option-value="id"
            required
          />
        </div>
        <div class="col-12">
          <SAPSelect
            v-model="leaveForm.leave_type_id"
            label="Leave Type"
            :options="leaveTypes"
            option-label="name"
            option-value="id"
            required
            @update:model-value="onLeaveTypeChange"
          />
        </div>
        <div class="col-6">
          <SAPInput v-model="leaveForm.from_date" label="From Date" type="date" required />
        </div>
        <div class="col-6">
          <SAPInput v-model="leaveForm.to_date" label="To Date" type="date" required />
        </div>
        <div class="col-12">
          <q-checkbox v-model="leaveForm.half_day" label="Half Day" />
        </div>
        <div class="col-12">
          <div class="text-bold q-mb-sm">
            Total Days:
            <span class="text-primary">{{ calculateDays }}</span>
          </div>
          <div v-if="selectedLeaveType" class="text-caption text-grey">
            Available Balance:
            <span :class="leaveBalance >= calculateDays ? 'text-positive' : 'text-negative'">
              {{ leaveBalance }} days
            </span>
          </div>
        </div>
        <div class="col-12">
          <SAPInput v-model="leaveForm.reason" label="Reason" type="textarea" rows="3" required />
        </div>
      </div>
    </SAPDialog>

    <!-- Leave Details Dialog -->
    <SAPDialog
      v-model="showDetailsDialog"
      :title="'Leave Application - ' + selectedLeave?.doc_number"
      icon="description"
      width="600px"
      :show-confirm="false"
      cancel-label="Close"
    >
      <div v-if="selectedLeave" class="q-gutter-md">
        <div class="row q-col-gutter-md">
          <div class="col-6">
            <div class="text-caption text-grey">Employee</div>
            <div class="text-bold">{{ selectedLeave.employee?.full_name }}</div>
          </div>
          <div class="col-6">
            <div class="text-caption text-grey">Status</div>
            <q-badge :color="getStatusColor(selectedLeave.status)" :label="selectedLeave.status" />
          </div>
          <div class="col-6">
            <div class="text-caption text-grey">Leave Type</div>
            <div>{{ selectedLeave.leave_type?.name }}</div>
          </div>
          <div class="col-6">
            <div class="text-caption text-grey">Total Days</div>
            <div class="text-bold text-primary">{{ selectedLeave.total_leave_days }}</div>
          </div>
          <div class="col-6">
            <div class="text-caption text-grey">From</div>
            <div>{{ selectedLeave.from_date }}</div>
          </div>
          <div class="col-6">
            <div class="text-caption text-grey">To</div>
            <div>{{ selectedLeave.to_date }}</div>
          </div>
          <div class="col-12">
            <div class="text-caption text-grey">Reason</div>
            <div>{{ selectedLeave.reason || '-' }}</div>
          </div>
        </div>

        <!-- Approval Timeline -->
        <q-timeline v-if="selectedLeave.status !== 'Draft'" color="primary" class="q-mt-md">
          <q-timeline-entry heading>Approval Workflow</q-timeline-entry>

          <q-timeline-entry
            :color="selectedLeave.hr_officer_approved_at ? 'positive' : 'grey'"
            :icon="selectedLeave.hr_officer_approved_at ? 'check_circle' : 'pending'"
          >
            <template v-slot:title>HR Officer Review</template>
            <template v-slot:subtitle>
              {{ selectedLeave.hr_officer_approved_at || 'Pending' }}
            </template>
          </q-timeline-entry>

          <q-timeline-entry
            :color="selectedLeave.hr_manager_approved_at ? 'positive' : 'grey'"
            :icon="selectedLeave.hr_manager_approved_at ? 'check_circle' : 'pending'"
          >
            <template v-slot:title>HR Manager Approval</template>
            <template v-slot:subtitle>
              {{ selectedLeave.hr_manager_approved_at || 'Pending' }}
            </template>
          </q-timeline-entry>
        </q-timeline>
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
const saving = ref(false)
const activeView = ref('pending')
const allLeaves = ref([])
const employees = ref([])
const leaveTypes = ref([])
const showLeaveDialog = ref(false)
const showDetailsDialog = ref(false)
const selectedLeave = ref(null)
const leaveBalance = ref(0)

const leaveForm = ref({
  employee_id: null,
  leave_type_id: null,
  from_date: new Date().toISOString().split('T')[0],
  to_date: new Date().toISOString().split('T')[0],
  half_day: false,
  reason: '',
})

// Computed
const pendingLeaves = computed(() =>
  allLeaves.value.filter((l) => ['Pending HR Officer', 'Pending HR Manager'].includes(l.status)),
)

const approvedThisMonth = computed(() => {
  const now = new Date()
  return allLeaves.value.filter((l) => {
    const date = new Date(l.created_at)
    return (
      l.status === 'Approved' &&
      date.getMonth() === now.getMonth() &&
      date.getFullYear() === now.getFullYear()
    )
  }).length
})

const rejectedThisMonth = computed(() => {
  const now = new Date()
  return allLeaves.value.filter((l) => {
    const date = new Date(l.created_at)
    return (
      l.status === 'Rejected' &&
      date.getMonth() === now.getMonth() &&
      date.getFullYear() === now.getFullYear()
    )
  }).length
})

const onLeaveToday = computed(() => {
  const today = new Date().toISOString().split('T')[0]
  return allLeaves.value.filter(
    (l) => l.status === 'Approved' && l.from_date <= today && l.to_date >= today,
  ).length
})

const selectedLeaveType = computed(() =>
  leaveTypes.value.find((t) => t.id === leaveForm.value.leave_type_id),
)

const calculateDays = computed(() => {
  if (leaveForm.value.half_day) return 0.5
  if (!leaveForm.value.from_date || !leaveForm.value.to_date) return 0
  const from = new Date(leaveForm.value.from_date)
  const to = new Date(leaveForm.value.to_date)
  return Math.max(1, Math.ceil((to - from) / (1000 * 60 * 60 * 24)) + 1)
})

// Columns
const columns = [
  { name: 'doc_number', label: 'Doc No.', field: 'doc_number', sortable: true, align: 'left' },
  { name: 'employee', label: 'Employee', field: 'employee', align: 'left' },
  { name: 'leave_type', label: 'Leave Type', field: 'leave_type', align: 'center' },
  { name: 'from_date', label: 'From', field: 'from_date', sortable: true, align: 'center' },
  { name: 'to_date', label: 'To', field: 'to_date', align: 'center' },
  {
    name: 'total_leave_days',
    label: 'Days',
    field: 'total_leave_days',
    sortable: true,
    align: 'right',
  },
  { name: 'status', label: 'Status', field: 'status', align: 'center' },
  { name: 'actions', label: 'Actions', field: 'actions', align: 'center' },
]

// Methods
function getStatusColor(status) {
  const colors = {
    Draft: 'grey',
    'Pending HR Officer': 'warning',
    'Pending HR Manager': 'orange',
    Approved: 'positive',
    Rejected: 'negative',
    Cancelled: 'grey',
  }
  return colors[status] || 'grey'
}

function getLeaveTypeColor(code) {
  const colors = {
    CL: 'primary',
    ML: 'negative',
    AL: 'positive',
    MAT: 'pink',
    PAT: 'blue',
    LWP: 'grey',
  }
  return colors[code] || 'secondary'
}

async function loadData() {
  loading.value = true
  try {
    // Load all leave applications
    const { data: leaveData, error: leaveError } = await supabase
      .from('leave_applications')
      .select('*, employee:employees(*), leave_type:leave_types(*)')
      .order('created_at', { ascending: false })

    if (leaveError) throw leaveError
    allLeaves.value = leaveData || []

    // Load employees
    const { data: empData } = await supabase
      .from('employees')
      .select('id, employee_code, full_name')
      .eq('status', 'Active')
      .order('full_name')
    employees.value = empData || []

    // Load leave types
    const { data: ltData } = await supabase
      .from('leave_types')
      .select('*')
      .eq('is_active', true)
      .order('name')
    leaveTypes.value = ltData || []
  } catch (err) {
    console.error('Error loading leaves:', err)
    $q.notify({ type: 'negative', message: 'Failed to load leave data' })
  } finally {
    loading.value = false
  }
}

function openApplyLeave() {
  leaveForm.value = {
    employee_id: null,
    leave_type_id: null,
    from_date: new Date().toISOString().split('T')[0],
    to_date: new Date().toISOString().split('T')[0],
    half_day: false,
    reason: '',
  }
  leaveBalance.value = 0
  showLeaveDialog.value = true
}

async function onLeaveTypeChange() {
  if (!leaveForm.value.employee_id || !leaveForm.value.leave_type_id) return

  // Get leave balance
  const { data } = await supabase
    .from('leave_allocations')
    .select('*')
    .eq('employee_id', leaveForm.value.employee_id)
    .eq('leave_type_id', leaveForm.value.leave_type_id)
    .single()

  if (data) {
    leaveBalance.value =
      data.new_leaves_allocated + (data.carry_forwarded_leaves || 0) - (data.leaves_taken || 0)
  } else {
    leaveBalance.value = 0
  }
}

function viewLeave(row) {
  selectedLeave.value = row
  showDetailsDialog.value = true
}

async function submitLeave() {
  if (!leaveForm.value.employee_id || !leaveForm.value.leave_type_id) {
    $q.notify({ type: 'warning', message: 'Please fill all required fields' })
    return
  }

  saving.value = true
  try {
    const { data, error } = await supabase.rpc('apply_leave', {
      p_employee_id: leaveForm.value.employee_id,
      p_leave_type_id: leaveForm.value.leave_type_id,
      p_from_date: leaveForm.value.from_date,
      p_to_date: leaveForm.value.to_date,
      p_reason: leaveForm.value.reason,
      p_half_day: leaveForm.value.half_day,
    })

    if (error) throw error
    if (!data.success) throw new Error(data.error)

    $q.notify({ type: 'positive', message: 'Leave application submitted' })
    showLeaveDialog.value = false
    await loadData()
  } catch (err) {
    console.error('Error submitting leave:', err)
    $q.notify({ type: 'negative', message: err.message || 'Failed to submit leave' })
  } finally {
    saving.value = false
  }
}

async function approveLeave(row) {
  $q.dialog({
    title: 'Approve Leave',
    message: `Approve ${row.total_leave_days} day(s) of ${row.leave_type?.name} for ${row.employee?.full_name}?`,
    cancel: true,
    persistent: true,
  }).onOk(async () => {
    try {
      const { data, error } = await supabase.rpc('approve_leave', {
        p_leave_id: row.id,
        p_approver_id: authStore.user?.id,
        p_action: 'approve',
      })

      if (error) throw error
      if (!data.success) throw new Error(data.error)

      $q.notify({ type: 'positive', message: 'Leave approved' })
      await loadData()
    } catch (err) {
      console.error('Approval error:', err)
      $q.notify({ type: 'negative', message: err.message || 'Approval failed' })
    }
  })
}

async function rejectLeave(row) {
  $q.dialog({
    title: 'Reject Leave',
    message: 'Please provide a reason for rejection:',
    prompt: {
      model: '',
      type: 'textarea',
    },
    cancel: true,
    persistent: true,
  }).onOk(async (reason) => {
    try {
      const { data, error } = await supabase.rpc('approve_leave', {
        p_leave_id: row.id,
        p_approver_id: authStore.user?.id,
        p_action: 'reject',
        p_rejection_reason: reason,
      })

      if (error) throw error
      if (!data.success) throw new Error(data.error)

      $q.notify({ type: 'info', message: 'Leave rejected' })
      await loadData()
    } catch (err) {
      console.error('Rejection error:', err)
      $q.notify({ type: 'negative', message: err.message || 'Rejection failed' })
    }
  })
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

  .text-h4 {
    font-weight: 700;
  }
}
</style>
