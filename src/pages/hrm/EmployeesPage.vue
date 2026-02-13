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
                  Manage system login credentials for this employee.
                  <span v-if="!employeeForm.user_id" class="text-weight-bold"
                    >No system user linked.</span
                  >
                </q-banner>
              </div>

              <!-- Manual User Access Management -->
              <div v-if="employeeForm.user_id" class="col-12 row q-col-gutter-md">
                <div class="col-12 col-md-6">
                  <q-input
                    v-model="systemAccessForm.email"
                    label="System Email"
                    outlined
                    dense
                    hint="Changing this will change the login email"
                  />
                </div>
                <div class="col-12 col-md-6">
                  <q-select
                    v-model="systemAccessForm.role"
                    :options="authStore.roleOptions"
                    label="System Role"
                    outlined
                    dense
                    emit-value
                    map-options
                  />
                </div>
                <div class="col-12 col-md-6">
                  <q-input
                    v-model="systemAccessForm.password"
                    label="New Password"
                    outlined
                    dense
                    placeholder="Leave empty to keep current"
                    hint="Enter a value only if you want to reset it"
                  >
                    <template v-slot:append>
                      <q-icon
                        name="refresh"
                        class="cursor-pointer"
                        @click="systemAccessForm.password = authStore.generateTempPassword()"
                      >
                        <q-tooltip>Generate Random</q-tooltip>
                      </q-icon>
                    </template>
                  </q-input>
                </div>
                <!-- Login Active Badge -->
                <div class="col-12 col-md-6 flex items-center">
                  <q-chip
                    icon="check_circle"
                    color="green"
                    text-color="white"
                    label="Login Active"
                    v-if="systemAccessForm.email"
                  />
                </div>

                <!-- Granular Permissions (For Existing Users) -->
                <div class="col-12">
                  <q-separator class="q-my-sm" />
                  <div class="text-subtitle2 q-mb-xs">User Permissions</div>
                  <div class="q-gutter-sm row">
                    <div v-for="mod in permissionModules" :key="mod" class="col-12 col-md-3">
                      <q-card flat bordered class="q-pa-sm bg-grey-1">
                        <div class="text-weight-bold text-caption text-uppercase q-mb-xs">
                          {{ mod }}
                        </div>
                        <div v-for="perm in getPermissionsByModule(mod)" :key="perm.id">
                          <q-checkbox
                            v-model="systemAccessForm.permissions"
                            :val="perm.id"
                            :label="perm.description || perm.action"
                            dense
                            size="sm"
                          />
                        </div>
                      </q-card>
                    </div>
                  </div>
                </div>

                <div class="col-12 q-mt-md">
                  <q-btn
                    color="primary"
                    label="Update Credentials & Permissions"
                    icon="save"
                    @click="updateSystemAccess"
                    :loading="updatingAccess"
                  />
                </div>
              </div>

              <div v-else class="col-12">
                <q-banner class="bg-warning text-white">
                  User account not created. Please create one via User Management or re-register.
                </q-banner>
              </div>
            </div>
          </q-tab-panel>
        </q-tab-panels>
      </q-form>

      <!-- Custom Footer for Dialog to include Delete -->
      <template v-slot:footer>
        <div class="row justify-between q-pa-md">
          <q-btn
            v-if="isEditing"
            color="negative"
            flat
            label="Delete Employee"
            icon="delete"
            @click="confirmDelete"
          />
          <div v-else></div>
          <!-- Spacer -->

          <div class="q-gutter-sm">
            <q-btn flat label="Cancel" v-close-popup />
            <q-btn
              color="primary"
              :label="isEditing ? 'Update' : 'Add'"
              @click="submitForm"
              :loading="saving"
            />
          </div>
        </div>
      </template>
    </SAPDialog>
  </q-page>
</template>

<script setup>
import { ref, computed, onMounted, reactive } from 'vue'
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
const updatingAccess = ref(false)
const employees = ref([])
const departments = ref([])
const designations = ref([])
const salaryStructures = ref([])
const availablePermissions = ref([])
const showEmployeeDialog = ref(false)
const showFilterDialog = ref(false)
const isEditing = ref(false)
const activeTab = ref('personal')
const employeeFormRef = ref(null)

const employeeForm = ref(getEmptyForm())
const systemAccessForm = reactive({
  email: '',
  role: '',
  password: '',
  permissions: [], // Array of Permission IDs
})

// Computed
const filteredEmployees = computed(() => employees.value)
const canViewSalary = computed(
  () =>
    ['admin', 'Z_ALL', 'hr_manager', 'director'].includes(authStore.userRole) || authStore.isAdmin,
)

// Permission Helpers
const permissionModules = computed(() => {
  return [...new Set(availablePermissions.value.map((p) => p.module))]
})

function getPermissionsByModule(mod) {
  return availablePermissions.value.filter((p) => p.module === mod)
}

// Columns
const columns = [
  {
    name: 'employee_code',
    label: 'Emp. No.',
    field: 'employee_code',
    sortable: true,
    align: 'left',
  },
  {
    name: 'full_name',
    label: 'Full Name',
    field: (row) => `${row.first_name || ''} ${row.last_name || ''}`,
    sortable: true,
    align: 'left',
  },
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
    user_id: null,
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
      .select('*, department:departments(*), designation:designations(*)')
      .order('employee_code')

    if (empError) {
      console.error('Employee query error:', empError)
      throw empError
    }
    employees.value = empData || []

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

    // Load Permissions for UI
    const { data: permData, error: permError } = await supabase
      .from('permissions')
      .select('*')
      .order('module')

    if (permError) console.error('Permissions query error', permError)
    availablePermissions.value = permData || []

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

  // Reset System Access Form
  systemAccessForm.email = ''
  systemAccessForm.role = ''
  systemAccessForm.password = ''
  systemAccessForm.permissions = []

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

  // Load System User Profile (if user_id exists)
  if (row.user_id) {
    const { data: profileData, error: profileError } = await supabase
      .from('profiles')
      .select('email, role')
      .eq('id', row.user_id)
      .single()

    if (profileError) {
      console.warn('Error fetching system profile:', profileError)
    }

    if (profileData) {
      systemAccessForm.email = profileData.email
      systemAccessForm.role = profileData.role
    }

    // Fetch user permissions
    const { data: userPerms } = await supabase
      .from('user_permissions')
      .select('permission_id')
      .eq('user_id', row.user_id)

    if (userPerms) {
      systemAccessForm.permissions = userPerms.map((p) => p.permission_id)
    }
  }

  showEmployeeDialog.value = true
}

// Function to delete employee
async function confirmDelete() {
  $q.dialog({
    title: 'Confirm Delete',
    message:
      'Are you sure you want to delete this employee? This will also delete their system user account. This action cannot be undone.',
    cancel: true,
    persistent: true,
  }).onOk(async () => {
    try {
      saving.value = true
      const result = await authStore.adminDeleteEmployee(employeeForm.value.id)
      if (result.success) {
        $q.notify({ type: 'positive', message: 'Employee deleted successfully' })
        showEmployeeDialog.value = false
        await loadData()
      } else {
        throw new Error(result.error)
      }
    } catch (err) {
      $q.notify({ type: 'negative', message: 'Failed to delete: ' + err.message })
    } finally {
      saving.value = false
    }
  })
}

// Function to update system credentials
async function updateSystemAccess() {
  if (!employeeForm.value.user_id) return

  try {
    updatingAccess.value = true
    // admin_update_user(p_user_id, p_email, p_password, p_full_name, p_role, p_permissions)
    const passwordToSend = systemAccessForm.password ? systemAccessForm.password : null

    const { data, error } = await supabase.rpc('admin_update_user', {
      p_user_id: employeeForm.value.user_id,
      p_email: systemAccessForm.email,
      p_password: passwordToSend,
      p_full_name: `${employeeForm.value.first_name} ${employeeForm.value.last_name}`,
      p_role: systemAccessForm.role,
      p_permissions: systemAccessForm.permissions,
    })

    if (error) throw error

    if (data && data.success === false) throw new Error(data.error)

    $q.notify({ type: 'positive', message: 'Credentials & Permissions updated successfully' })
    systemAccessForm.password = '' // Clear password field
    // Reload data to reflect email changes if any
    await loadData()
  } catch (err) {
    $q.notify({ type: 'negative', message: 'Failed to update credentials: ' + err.message })
  } finally {
    updatingAccess.value = false
  }
}

async function submitForm() {
  // If not editing, use registration page
  if (!isEditing.value) {
    openCreateDialog()
    return
  }

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
    delete payload.designation // Fix: remove entire object
    delete payload.department // Fix: remove entire object

    let employeeId = payload.id

    // Update core employee data
    const result = await supabase.from('employees').update(payload).eq('id', payload.id)
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
      message: 'Employee updated',
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
