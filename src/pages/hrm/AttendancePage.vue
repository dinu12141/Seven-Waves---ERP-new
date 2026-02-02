<template>
  <q-page class="sap-page">
    <!-- Toolbar -->
    <SAPToolbar
      title="Attendance Management"
      icon="schedule"
      :badge="todayAttendance.length"
      add-label="Mark Attendance"
      :show-export="true"
      :show-filter="true"
      @add="openMarkAttendance"
      @refresh="loadData"
      @export="exportData"
      @filter="showFilterDialog = true"
    />

    <!-- Stats Cards -->
    <div class="row q-col-gutter-md q-mb-md q-px-md">
      <div class="col-6 col-md-3">
        <q-card class="stat-card bg-positive text-white">
          <q-card-section>
            <div class="text-h4">{{ stats.present }}</div>
            <div class="text-caption">Present Today</div>
          </q-card-section>
        </q-card>
      </div>
      <div class="col-6 col-md-3">
        <q-card class="stat-card bg-negative text-white">
          <q-card-section>
            <div class="text-h4">{{ stats.absent }}</div>
            <div class="text-caption">Absent Today</div>
          </q-card-section>
        </q-card>
      </div>
      <div class="col-6 col-md-3">
        <q-card class="stat-card bg-warning text-white">
          <q-card-section>
            <div class="text-h4">{{ stats.late }}</div>
            <div class="text-caption">Late Entry</div>
          </q-card-section>
        </q-card>
      </div>
      <div class="col-6 col-md-3">
        <q-card class="stat-card bg-info text-white">
          <q-card-section>
            <div class="text-h4">{{ stats.onLeave }}</div>
            <div class="text-caption">On Leave</div>
          </q-card-section>
        </q-card>
      </div>
      <div class="col-6 col-md-3" v-if="stats.unmarked > 0">
        <q-card class="stat-card bg-grey-4 text-grey-9">
          <q-card-section>
            <div class="text-h4">{{ stats.unmarked }}</div>
            <div class="text-caption">Not Marked</div>
          </q-card-section>
        </q-card>
      </div>
    </div>

    <!-- Main Content -->
    <div class="sap-page-content">
      <!-- Date Selector -->
      <div class="row q-mb-md q-px-md">
        <div class="col-auto">
          <q-input v-model="selectedDate" type="date" outlined dense @update:model-value="loadData">
            <template v-slot:prepend>
              <q-icon name="event" />
            </template>
          </q-input>
        </div>
        <div class="col-auto q-ml-md">
          <q-btn-group>
            <q-btn
              label="Today"
              @click="goToday"
              :flat="!isToday"
              :color="isToday ? 'primary' : ''"
            />
            <q-btn icon="chevron_left" @click="prevDay" flat />
            <q-btn icon="chevron_right" @click="nextDay" flat />
          </q-btn-group>
        </div>
      </div>

      <!-- Attendance Grid -->
      <SAPCard title="Attendance Records" icon="list" no-padding>
        <SAPTable
          :rows="todayAttendance"
          :columns="columns"
          :loading="loading"
          row-key="id"
          sticky-header
          height="calc(100vh - 400px)"
        >
          <!-- Status Badge -->
          <template #body-cell-status="props">
            <q-td :props="props">
              <q-badge
                :color="getStatusColor(props.value)"
                :label="props.value"
                class="text-capitalize"
              />
            </q-td>
          </template>

          <!-- Check-in Time -->
          <template #body-cell-check_in_time="props">
            <q-td :props="props">
              <span v-if="props.value">{{ formatTime(props.value) }}</span>
              <q-btn
                v-else
                size="sm"
                color="positive"
                label="Check In"
                flat
                dense
                @click="checkIn(props.row)"
              />
            </q-td>
          </template>

          <!-- Check-out Time -->
          <template #body-cell-check_out_time="props">
            <q-td :props="props">
              <span v-if="props.value">{{ formatTime(props.value) }}</span>
              <q-btn
                v-else-if="props.row.check_in_time"
                size="sm"
                color="negative"
                label="Check Out"
                flat
                dense
                @click="checkOut(props.row)"
              />
              <span v-else class="text-grey">-</span>
            </q-td>
          </template>

          <!-- Working Hours -->
          <template #body-cell-working_hours="props">
            <q-td :props="props" class="text-right">
              <span v-if="props.value" :class="props.value >= 8 ? 'text-positive' : 'text-warning'">
                {{ props.value?.toFixed(2) }} hrs
              </span>
              <span v-else class="text-grey">-</span>
            </q-td>
          </template>

          <!-- Overtime -->
          <template #body-cell-overtime_hours="props">
            <q-td :props="props" class="text-right">
              <q-badge
                v-if="props.value > 0"
                color="purple"
                :label="props.value?.toFixed(2) + ' OT'"
              />
              <span v-else class="text-grey">-</span>
            </q-td>
          </template>
        </SAPTable>
      </SAPCard>
    </div>

    <!-- Mark Attendance Dialog -->
    <SAPDialog
      v-model="showAttendanceDialog"
      title="Mark Attendance"
      icon="schedule"
      width="500px"
      :loading="saving"
      confirm-label="Save"
      @confirm="saveAttendance"
    >
      <div class="row q-col-gutter-md">
        <div class="col-12">
          <SAPSelect
            v-model="attendanceForm.employee_id"
            label="Employee"
            :options="employees"
            option-label="full_name"
            option-value="id"
            required
          />
        </div>
        <div class="col-12">
          <SAPInput v-model="attendanceForm.attendance_date" label="Date" type="date" required />
        </div>
        <div class="col-6">
          <SAPInput v-model="attendanceForm.check_in_time" label="Check In" type="time" />
        </div>
        <div class="col-6">
          <SAPInput v-model="attendanceForm.check_out_time" label="Check Out" type="time" />
        </div>
        <div class="col-12">
          <SAPSelect
            v-model="attendanceForm.status"
            label="Status"
            :options="['Present', 'Absent', 'Half Day', 'On Leave', 'Holiday', 'Weekend']"
          />
        </div>
        <div class="col-12">
          <SAPInput v-model="attendanceForm.remarks" label="Remarks" type="textarea" rows="2" />
        </div>
      </div>
    </SAPDialog>
  </q-page>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useQuasar } from 'quasar'
import { supabase } from 'src/boot/supabase'
import { SAPTable, SAPCard, SAPToolbar, SAPDialog, SAPInput, SAPSelect } from 'src/components/sap'

const $q = useQuasar()

// State
const loading = ref(false)
const saving = ref(false)
const selectedDate = ref(new Date().toISOString().split('T')[0])
const todayAttendance = ref([])
const employees = ref([])
const showAttendanceDialog = ref(false)
const showFilterDialog = ref(false)

const attendanceForm = ref({
  employee_id: null,
  attendance_date: new Date().toISOString().split('T')[0],
  check_in_time: null,
  check_out_time: null,
  status: 'Present',
  remarks: '',
})

// Stats
const stats = computed(() => {
  const data = todayAttendance.value
  return {
    present: data.filter((a) => a.status === 'Present').length,
    absent: data.filter((a) => a.status === 'Absent').length,
    late: data.filter((a) => a.late_entry_minutes > 15).length,
    onLeave: data.filter((a) => a.status === 'On Leave').length,
    unmarked: data.filter((a) => !a.status).length,
  }
})

const isToday = computed(() => selectedDate.value === new Date().toISOString().split('T')[0])

// Columns
const columns = [
  {
    name: 'employee_code',
    label: 'Emp. No.',
    field: (row) => row.employee?.employee_code,
    sortable: true,
    align: 'left',
  },
  {
    name: 'employee_name',
    label: 'Employee Name',
    field: (row) => row.employee?.full_name,
    sortable: true,
    align: 'left',
  },
  {
    name: 'shift',
    label: 'Shift',
    field: (row) => row.shift_type?.name || 'General',
    align: 'center',
  },
  { name: 'check_in_time', label: 'Check In', field: 'check_in_time', align: 'center' },
  { name: 'check_out_time', label: 'Check Out', field: 'check_out_time', align: 'center' },
  { name: 'working_hours', label: 'Working Hrs', field: 'working_hours', align: 'right' },
  { name: 'overtime_hours', label: 'OT', field: 'overtime_hours', align: 'right' },
  { name: 'status', label: 'Status', field: 'status', align: 'center' },
]

// Methods
function getStatusColor(status) {
  const colors = {
    Present: 'positive',
    Absent: 'negative',
    'Half Day': 'warning',
    'On Leave': 'info',
    Holiday: 'purple',
    Weekend: 'grey',
  }
  return colors[status] || 'grey'
}

function formatTime(timestamp) {
  if (!timestamp) return '-'
  const date = new Date(timestamp)
  return date.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit', hour12: true })
}

async function loadData() {
  loading.value = true
  try {
    // Load all active employees
    const { data: empData, error: empError } = await supabase
      .from('employees')
      .select('id, employee_code, full_name, img_url:avatar_url')
      .eq('status', 'Active')
      .order('employee_code')

    if (empError) throw empError
    employees.value = empData || []

    // Load attendance for selected date
    const { data: attData, error: attError } = await supabase
      .from('attendance')
      .select('*, shift_type:shift_types(*)')
      .eq('attendance_date', selectedDate.value)

    if (attError) throw attError

    // Merge Data
    const attendanceMap = new Map((attData || []).map((a) => [a.employee_id, a]))

    todayAttendance.value = employees.value.map((emp) => {
      const att = attendanceMap.get(emp.id)
      return {
        id: att?.id || `temp-${emp.id}`, // Use attendance ID or temp ID
        employee_id: emp.id,
        employee: emp,
        status: att?.status || null, // null means Not Marked
        check_in_time: att?.check_in_time,
        check_out_time: att?.check_out_time,
        shift_type: att?.shift_type,
        working_hours: att?.working_hours,
        overtime_hours: att?.overtime_hours,
        late_entry_minutes: att?.late_entry_minutes || 0,
      }
    })
  } catch (err) {
    console.error('Error loading attendance:', err)
    $q.notify({ type: 'negative', message: 'Failed to load attendance' })
  } finally {
    loading.value = false
  }
}

function goToday() {
  selectedDate.value = new Date().toISOString().split('T')[0]
  loadData()
}

function prevDay() {
  const date = new Date(selectedDate.value)
  date.setDate(date.getDate() - 1)
  selectedDate.value = date.toISOString().split('T')[0]
  loadData()
}

function nextDay() {
  const date = new Date(selectedDate.value)
  date.setDate(date.getDate() + 1)
  selectedDate.value = date.toISOString().split('T')[0]
  loadData()
}

function openMarkAttendance() {
  attendanceForm.value = {
    employee_id: null,
    attendance_date: selectedDate.value,
    check_in_time: null,
    check_out_time: null,
    status: 'Present',
    remarks: '',
  }
  showAttendanceDialog.value = true
}

async function checkIn(row) {
  const now = new Date()
  const timeStr = now.toTimeString().slice(0, 5)

  try {
    const { error } = await supabase.rpc('record_attendance', {
      p_employee_id: row.employee_id,
      p_attendance_date: selectedDate.value,
      p_check_in: timeStr,
      p_source: 'Manual',
    })

    if (error) throw error
    $q.notify({ type: 'positive', message: 'Checked in successfully' })
    await loadData()
  } catch (err) {
    console.error('Check-in error:', err)
    $q.notify({ type: 'negative', message: err.message || 'Check-in failed' })
  }
}

async function checkOut(row) {
  try {
    const { error } = await supabase
      .from('attendance')
      .update({
        check_out_time: new Date().toISOString(),
        working_hours: calculateWorkingHours(row.check_in_time, new Date()),
      })
      .eq('id', row.id)

    if (error) throw error
    $q.notify({ type: 'positive', message: 'Checked out successfully' })
    await loadData()
  } catch (err) {
    console.error('Check-out error:', err)
    $q.notify({ type: 'negative', message: err.message || 'Check-out failed' })
  }
}

function calculateWorkingHours(checkIn, checkOut) {
  if (!checkIn || !checkOut) return 0
  const start = new Date(checkIn)
  const end = new Date(checkOut)
  return (end - start) / (1000 * 60 * 60)
}

async function saveAttendance() {
  if (!attendanceForm.value.employee_id) {
    $q.notify({ type: 'warning', message: 'Please select an employee' })
    return
  }

  saving.value = true
  try {
    const { error } = await supabase.rpc('record_attendance', {
      p_employee_id: attendanceForm.value.employee_id,
      p_attendance_date: attendanceForm.value.attendance_date,
      p_check_in: attendanceForm.value.check_in_time,
      p_check_out: attendanceForm.value.check_out_time,
      p_source: 'Manual',
    })

    if (error) throw error

    $q.notify({ type: 'positive', message: 'Attendance saved' })
    showAttendanceDialog.value = false
    await loadData()
  } catch (err) {
    console.error('Error saving attendance:', err)
    $q.notify({ type: 'negative', message: err.message || 'Failed to save attendance' })
  } finally {
    saving.value = false
  }
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

  .text-h4 {
    font-weight: 700;
  }
}
</style>
