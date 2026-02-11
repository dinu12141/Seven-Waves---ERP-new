<template>
  <q-page class="sap-page">
    <!-- Toolbar -->
    <SAPToolbar
      title="Employee Master Data"
      icon="people"
      :badge="employees.length"
      add-label="New Employee"
      :show-export="true"
      :show-filter="true"
      @add="openCreateDialog"
      @refresh="loadData"
      @export="exportData"
      @filter="showFilterDialog = true"
    />

    <!-- Main Content -->
    <div class="sap-page-content">
      <!-- Employee Grid -->
      <SAPCard title="Employees" icon="list" no-padding>
        <SAPTable
          :rows="filteredEmployees"
          :columns="columns"
          :loading="loading"
          :show-drill-down="true"
          row-key="id"
          sticky-header
          height="calc(100vh - 250px)"
          @row-click="viewEmployee"
          @drill-down="viewEmployee"
        >
          <!-- Employee Code -->
          <template #body-cell-employee_code="props">
            <q-td :props="props">
              <div class="row items-center no-wrap">
                <span class="text-bold text-primary">{{ props.value }}</span>
                <GoldenArrow @click="viewEmployee(props.row)" />
              </div>
            </q-td>
          </template>

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

          <!-- Employment Type -->
          <template #body-cell-employment_type="props">
            <q-td :props="props">
              <q-chip
                size="sm"
                :color="getTypeColor(props.value)"
                text-color="white"
                :label="props.value"
              />
            </q-td>
          </template>
        </SAPTable>
      </SAPCard>
    </div>

    <!-- Employee Master Data Dialog -->
    <SAPDialog
      v-model="showEmployeeDialog"
      :title="isEditing ? 'Employee - ' + employeeForm.employee_code : 'Employee - Create'"
      icon="person"
      width="1000px"
      :loading="saving"
      :confirm-label="isEditing ? 'Update' : 'Add'"
      @confirm="submitForm"
    >
      <q-form ref="employeeFormRef" @submit.prevent="submitForm">
        <!-- Header Section -->
        <div class="row q-col-gutter-md q-mb-md">
          <div class="col-12 col-md-4">
            <SAPInput
              v-model="employeeForm.employee_code"
              label="Employee No."
              required
              :readonly="true"
              hint="Auto-assigned"
            />
          </div>
          <div class="col-12 col-md-4">
            <SAPSelect
              v-model="employeeForm.status"
              label="Status"
              :options="['Active', 'Inactive', 'Left', 'Suspended']"
            />
          </div>
          <div class="col-12 col-md-4">
            <SAPSelect
              v-model="employeeForm.employment_type"
              label="Employment Type"
              :options="['Permanent', 'Contract', 'Probation', 'Intern', 'Part-Time']"
            />
          </div>
        </div>

        <!-- TABS -->
        <q-tabs
          v-model="activeTab"
          dense
          class="text-grey"
          active-color="primary"
          indicator-color="primary"
          align="justify"
          narrow-indicator
        >
          <q-tab name="personal" label="Personal Info" icon="person" />
          <q-tab name="employment" label="Employment" icon="work" />
          <q-tab name="salary" label="Salary" icon="payments" />
          <q-tab name="statutory" label="Statutory" icon="gavel" />
          <q-tab name="system" label="System Access" icon="admin_panel_settings" />
        </q-tabs>

        <q-separator />

        <q-tab-panels v-model="activeTab" animated class="q-mt-sm" style="min-height: 350px">
          <!-- Personal Info Tab -->
          <q-tab-panel name="personal">
            <div class="row q-col-gutter-md">
              <div class="col-12 col-md-6">
                <SAPInput
                  v-model="employeeForm.first_name"
                  label="First Name"
                  required
                  :rules="[(val) => !!val || 'First name is required']"
                />
                <SAPInput
                  v-model="employeeForm.last_name"
                  label="Last Name"
                  required
                  :rules="[(val) => !!val || 'Last name is required']"
                />
                <SAPInput v-model="employeeForm.nic_number" label="NIC Number" />
                <SAPInput v-model="employeeForm.date_of_birth" label="Date of Birth" type="date" />
              </div>
              <div class="col-12 col-md-6">
                <SAPSelect
                  v-model="employeeForm.gender"
                  label="Gender"
                  :options="['Male', 'Female', 'Other']"
                />
                <SAPSelect
                  v-model="employeeForm.marital_status"
                  label="Marital Status"
                  :options="['Single', 'Married', 'Divorced', 'Widowed']"
                />
                <SAPInput v-model="employeeForm.mobile_phone" label="Mobile Phone" />
                <SAPInput v-model="employeeForm.personal_email" label="Personal Email" />
              </div>
              <div class="col-12">
                <SAPInput
                  v-model="employeeForm.permanent_address"
                  label="Permanent Address"
                  type="textarea"
                  rows="2"
                />
              </div>
            </div>
          </q-tab-panel>

          <!-- Employment Tab -->
          <q-tab-panel name="employment">
            <div class="row q-col-gutter-md">
              <div class="col-12 col-md-6">
                <SAPSelect
                  v-model="employeeForm.department_id"
                  label="Department"
                  :options="departments"
                  option-label="name"
                  option-value="id"
                />
                <SAPSelect
                  v-model="employeeForm.designation_id"
                  label="Designation"
                  :options="designations"
                  option-label="name"
                  option-value="id"
                />
                <SAPInput
                  v-model="employeeForm.date_of_joining"
                  label="Date of Joining"
                  type="date"
                  required
                />
              </div>
              <div class="col-12 col-md-6">
                <SAPInput
                  v-model="employeeForm.date_of_confirmation"
                  label="Date of Confirmation"
                  type="date"
                />
                <SAPInput v-model="employeeForm.company_email" label="Company Email" />
                <SAPInput
                  v-model="employeeForm.notice_period_days"
                  label="Notice Period (Days)"
                  type="number"
                />
              </div>
            </div>
          </q-tab-panel>

          <!-- Salary Tab (Restricted Access) -->
          <q-tab-panel name="salary">
            <q-banner v-if="!canViewSalary" class="bg-warning text-white q-mb-md" rounded>
              <template v-slot:avatar>
                <q-icon name="lock" color="white" />
              </template>
              You do not have permission to view salary information.
            </q-banner>

            <div v-if="canViewSalary" class="row q-col-gutter-md">
              <div class="col-12 col-md-6">
                <SAPSelect
                  v-model="employeeForm.salary_mode"
                  label="Salary Mode"
                  :options="['Bank', 'Cash', 'Cheque']"
                />
                <SAPInput v-model="employeeForm.bank_name" label="Bank Name" />
                <SAPInput v-model="employeeForm.bank_branch" label="Bank Branch" />
                <SAPInput v-model="employeeForm.bank_account_no" label="Bank Account No." />
              </div>
              <div class="col-12 col-md-6">
                <SAPSelect
                  v-model="employeeForm.salary_structure_id"
                  label="Salary Structure"
                  :options="salaryStructures"
                  option-label="name"
                  option-value="id"
                />
                <SAPInput
                  v-model="employeeForm.base_amount"
                  label="Base Salary (LKR)"
                  type="number"
                />
              </div>
            </div>
          </q-tab-panel>

          <!-- Statutory Tab (EPF/ETF) -->
          <q-tab-panel name="statutory">
            <div class="row q-col-gutter-md">
              <div class="col-12 col-md-6">
                <SAPInput v-model="employeeForm.epf_number" label="EPF Number" />
                <SAPInput v-model="employeeForm.etf_number" label="ETF Number" />
              </div>
              <div class="col-12 col-md-6">
                <SAPInput
                  v-model="employeeForm.emergency_contact_name"
                  label="Emergency Contact Name"
                />
                <SAPInput
                  v-model="employeeForm.emergency_contact_phone"
                  label="Emergency Contact Phone"
                />
              </div>
            </div>
          </q-tab-panel>
          <!-- System Access Tab -->
          <q-tab-panel name="system">
            <div class="row q-col-gutter-md">
              <div class="col-12">
                <q-banner class="bg-blue-1 text-primary rounded-borders q-mb-md">
                  <template v-slot:avatar>
                    <q-icon name="info" color="primary" />
                  </template>
                  System login is automatically created based on Job Role.
                </q-banner>
              </div>
              <div class="col-12 col-md-6">
                <SAPInput
                  v-model="employeeForm.company_email"
                  label="System Username (Email)"
                  readonly
                  hint="Use this email to log in"
                />
              </div>
              <div class="col-12 col-md-6">
                <q-input
                  :model-value="'Employee123!'"
                  label="Default Password"
                  outlined
                  dense
                  readonly
                  type="text"
                  hint="Default password for new users"
                />
              </div>
              <div class="col-12 col-md-6">
                <q-input
                  :model-value="employeeForm.designation?.related_user_role || 'Sales Staff'"
                  label="Assigned System Role"
                  outlined
                  dense
                  readonly
                />
              </div>
              <div class="col-12 col-md-6">
                <q-chip
                  :model-value="true"
                  icon="check_circle"
                  color="green"
                  text-color="white"
                  label="Login Active"
                />
              </div>
            </div>
          </q-tab-panel>
        </q-tab-panels>
      </q-form>
    </SAPDialog>
  </q-page>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useQuasar } from 'quasar'
import { supabase } from 'src/boot/supabase'
import { useAuthStore } from 'src/stores/authStore'
import {
  SAPTable,
  SAPCard,
  SAPToolbar,
  SAPDialog,
  SAPInput,
  SAPSelect,
  GoldenArrow,
} from 'src/components/sap'

const $q = useQuasar()
const router = useRouter()
const authStore = useAuthStore()

// State
const loading = ref(false)
const saving = ref(false)
const employees = ref([])
const departments = ref([])
const designations = ref([])
const salaryStructures = ref([])
const showEmployeeDialog = ref(false)
const showFilterDialog = ref(false)
const isEditing = ref(false)
const activeTab = ref('personal')
const employeeFormRef = ref(null)

const employeeForm = ref(getEmptyForm())

// Computed
const filteredEmployees = computed(() => employees.value)
const canViewSalary = computed(() =>
  ['admin', 'hr_manager', 'director'].includes(authStore.userRole),
)

// Columns
const columns = [
  {
    name: 'employee_code',
    label: 'Emp. No.',
    field: 'employee_code',
    sortable: true,
    align: 'left',
  },
  { name: 'full_name', label: 'Full Name', field: 'full_name', sortable: true, align: 'left' },
  {
    name: 'department',
    label: 'Department',
    field: (row) => row.department?.name || '-',
    sortable: true,
    align: 'left',
  },
  {
    name: 'designation',
    label: 'Designation',
    field: (row) => row.designation?.name || '-',
    sortable: true,
    align: 'left',
  },
  { name: 'employment_type', label: 'Type', field: 'employment_type', align: 'center' },
  { name: 'mobile_phone', label: 'Mobile', field: 'mobile_phone', align: 'left' },
  {
    name: 'date_of_joining',
    label: 'Joined',
    field: 'date_of_joining',
    sortable: true,
    align: 'center',
  },
  { name: 'status', label: 'Status', field: 'status', align: 'center' },
]

// Methods
function getEmptyForm() {
  return {
    employee_code: '',
    first_name: '',
    last_name: '',
    date_of_birth: null,
    gender: 'Male',
    marital_status: 'Single',
    nic_number: '',
    personal_email: '',
    company_email: '',
    mobile_phone: '',
    emergency_contact_name: '',
    emergency_contact_phone: '',
    permanent_address: '',
    department_id: null,
    designation_id: null,
    employment_type: 'Permanent',
    date_of_joining: new Date().toISOString().split('T')[0],
    date_of_confirmation: null,
    notice_period_days: 30,
    salary_mode: 'Bank',
    bank_name: '',
    bank_branch: '',
    bank_account_no: '',
    epf_number: '',
    etf_number: '',
    status: 'Active',
    salary_structure_id: null,
    base_amount: 0,
  }
}

function getStatusColor(status) {
  const colors = {
    Active: 'positive',
    Inactive: 'grey',
    Left: 'negative',
    Suspended: 'warning',
  }
  return colors[status] || 'grey'
}

function getTypeColor(type) {
  const colors = {
    Permanent: 'primary',
    Contract: 'accent',
    Probation: 'warning',
    Intern: 'info',
    'Part-Time': 'secondary',
  }
  return colors[type] || 'grey'
}

async function loadData() {
  loading.value = true
  try {
    // Load Employees
    const { data: empData, error: empError } = await supabase
      .from('employees')
      .select('*, department:departments!department_id(*), designation:designations(*)')
      .order('employee_code')

    if (empError) {
      console.error('Employee query error:', empError)
      throw empError
    }
    employees.value = empData || []

    // Load Salary Assignments for all employees (optimization: could be done per employee on view, but for list size it's ok to fetch active ones)
    // Actually, to keep it simple and secure, let's fetch it on demand in viewEmployee

    // Load Departments
    const { data: deptData, error: deptError } = await supabase
      .from('departments')
      .select('*')
      .eq('is_active', true)
      .order('name')

    if (deptError) console.error('Department query error:', deptError)
    departments.value = deptData || []

    // Load Designations
    const { data: desigData, error: desigError } = await supabase
      .from('designations')
      .select('*')
      .eq('is_active', true)
      .order('name')

    if (desigError) console.error('Designation query error:', desigError)
    designations.value = desigData || []

    // Load Salary Structures (if permitted)
    if (canViewSalary.value) {
      const { data: ssData, error: ssError } = await supabase
        .from('salary_structures')
        .select('*')
        .eq('is_active', true)
        .order('name')

      if (ssError) console.error('Salary structure query error:', ssError)
      salaryStructures.value = ssData || []
    }
  } catch (err) {
    console.error('Error loading employees:', err)
    $q.notify({ type: 'negative', message: err.message || 'Failed to load employees' })
  } finally {
    loading.value = false
  }
}

async function openCreateDialog() {
  await router.push('/hrm/register')
}

async function viewEmployee(row) {
  employeeForm.value = { ...getEmptyForm(), ...row }
  isEditing.value = true

  // Load Salary Assignment
  if (canViewSalary.value) {
    const { data, error } = await supabase
      .from('employee_salary_assignments')
      .select('*')
      .eq('employee_id', row.id)
      .eq('is_active', true)
      .order('created_at', { ascending: false }) // Get latest
      .limit(1)
      .single()

    if (data) {
      employeeForm.value.salary_structure_id = data.salary_structure_id
      employeeForm.value.base_amount = data.base_amount
    } else if (error && error.code !== 'PGRST116') {
      console.error('Error fetching salary assignment:', error)
    }
  }

  showEmployeeDialog.value = true
}

async function submitForm() {
  if (!employeeForm.value.first_name || !employeeForm.value.last_name) {
    $q.notify({ type: 'warning', message: 'Please fill required fields' })
    return
  }

  saving.value = true
  try {
    const payload = { ...employeeForm.value }
    // Remove computed/joined fields
    delete payload.department
    delete payload.designation
    delete payload.full_name
    delete payload.salary_structure_id
    delete payload.base_amount

    let employeeId = payload.id
    let result

    if (isEditing.value) {
      result = await supabase.from('employees').update(payload).eq('id', payload.id)
    } else {
      delete payload.id
      payload.created_by = authStore.user?.id // Set created_by
      result = await supabase.from('employees').insert(payload).select().single()
      if (result.data) employeeId = result.data.id
    }

    if (result.error) throw result.error

    // Handle Salary Assignment
    if (canViewSalary.value && employeeForm.value.salary_structure_id) {
      const salaryPayload = {
        employee_id: employeeId,
        salary_structure_id: employeeForm.value.salary_structure_id,
        base_amount: employeeForm.value.base_amount || 0,
        from_date: employeeForm.value.date_of_joining || new Date().toISOString().split('T')[0],
        is_active: true,
      }

      // Check for existing active assignment
      const { data: existing } = await supabase
        .from('employee_salary_assignments')
        .select('id')
        .eq('employee_id', employeeId)
        .eq('is_active', true)
        .single()

      if (existing) {
        await supabase
          .from('employee_salary_assignments')
          .update({
            salary_structure_id: salaryPayload.salary_structure_id,
            base_amount: salaryPayload.base_amount,
          })
          .eq('id', existing.id)
      } else {
        await supabase.from('employee_salary_assignments').insert(salaryPayload)
      }
    }

    $q.notify({
      type: 'positive',
      message: isEditing.value ? 'Employee updated' : 'Employee created',
    })
    showEmployeeDialog.value = false
    await loadData()
  } catch (err) {
    console.error('Error saving employee:', err)
    $q.notify({ type: 'negative', message: err.message || 'Failed to save employee' })
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
</style>
