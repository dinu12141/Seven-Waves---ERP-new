<template>
  <q-page class="sap-page">
    <div class="row items-center q-mb-md">
      <q-btn flat round icon="arrow_back" color="primary" @click="$router.back()" />
      <div class="text-h6 q-ml-sm">New Employee Registration</div>
    </div>

    <!-- MAIN CARD -->
    <SAPCard no-padding class="registration-card">
      <q-stepper v-model="step" ref="stepper" color="primary" animated header-nav>
        <!-- Step 1: Basic Info -->
        <q-step :name="1" title="Basic Information" icon="person" :done="step > 1">
          <q-form @submit="nextStep" class="q-pa-md">
            <div class="row q-col-gutter-md">
              <div class="col-12 text-subtitle2 text-grey-7">Personal Details</div>

              <!-- Employee Code (Auto/Manual) -->
              <div class="col-12 col-md-4">
                <SAPInput
                  v-model="form.basic.code"
                  label="Employee Code"
                  hint="Leave empty for auto-generation"
                  :loading="generatingCode"
                >
                  <template v-slot:append>
                    <q-btn icon="autorenew" flat round dense @click="generateCode">
                      <q-tooltip>Generate Next Code</q-tooltip>
                    </q-btn>
                  </template>
                </SAPInput>
              </div>

              <!-- Name -->
              <div class="col-12 col-md-4">
                <SAPInput
                  v-model="form.basic.firstName"
                  label="First Name *"
                  :rules="[(val) => !!val || 'Required']"
                />
              </div>
              <div class="col-12 col-md-4">
                <SAPInput
                  v-model="form.basic.lastName"
                  label="Last Name *"
                  :rules="[(val) => !!val || 'Required']"
                />
              </div>

              <!-- Contact -->
              <div class="col-12 col-md-6">
                <SAPInput v-model="form.basic.mobile" label="Mobile Number" mask="###-#######" />
              </div>
              <div class="col-12 col-md-6">
                <SAPInput v-model="form.basic.email" label="Personal Email" type="email" />
              </div>

              <!-- Identifiers -->
              <div class="col-12 col-md-4">
                <SAPInput v-model="form.basic.nic" label="NIC Number" />
              </div>
              <div class="col-12 col-md-4">
                <SAPSelect
                  v-model="form.basic.gender"
                  label="Gender"
                  :options="['Male', 'Female', 'Other']"
                />
              </div>
              <div class="col-12 col-md-4">
                <SAPInput v-model="form.basic.dob" label="Date of Birth" type="date" />
              </div>

              <div class="col-12">
                <SAPInput
                  v-model="form.basic.address"
                  label="Permanent Address"
                  type="textarea"
                  rows="2"
                />
              </div>

              <div class="col-12 text-subtitle2 text-grey-7 q-mt-md">Job Details</div>

              <!-- Department/Designation -->
              <div class="col-12 col-md-6">
                <SAPSelect
                  v-model="form.basic.departmentId"
                  label="Department *"
                  :options="store.departments"
                  option-label="name"
                  option-value="id"
                  :rules="[(val) => !!val || 'Required']"
                />
              </div>
              <div class="col-12 col-md-6">
                <SAPSelect
                  v-model="form.basic.designationId"
                  label="Designation *"
                  :options="filteredDesignations"
                  option-label="name"
                  option-value="id"
                  :disable="!form.basic.departmentId"
                  :rules="[(val) => !!val || 'Required']"
                  @update:model-value="onDesignationSelect"
                />
              </div>

              <!-- Dates -->
              <div class="col-12 col-md-4">
                <SAPInput
                  v-model="form.basic.joinDate"
                  label="Date of Joining *"
                  type="date"
                  :rules="[(val) => !!val || 'Required']"
                />
              </div>
              <div class="col-12 col-md-4">
                <SAPSelect
                  v-model="form.basic.type"
                  label="Employment Type"
                  :options="['Permanent', 'Contract', 'Probation', 'Intern', 'Part-Time']"
                />
              </div>
              <div class="col-12 col-md-4">
                <SAPInput v-model="form.basic.status" label="Status" readonly />
              </div>
            </div>

            <q-stepper-navigation>
              <q-btn @click="nextStep" color="primary" label="Continue to Compensation" />
            </q-stepper-navigation>
          </q-form>
        </q-step>

        <!-- Step 2: Pay & Statutory -->
        <q-step :name="2" title="Pay & Statutory" icon="payments" :done="step > 2">
          <q-form @submit="nextStep" class="q-pa-md">
            <div class="row q-col-gutter-md">
              <!-- Salary Structure Selection -->
              <div class="col-12 text-subtitle2 text-grey-7">Compensation Structure</div>
              <div class="col-12 col-md-6">
                <SAPSelect
                  v-model="form.payment.salaryStructureId"
                  label="Salary Structure"
                  :options="store.salaryStructures"
                  option-label="name"
                  option-value="id"
                  hint="Select base structure (Grade/Scale)"
                />
              </div>
              <div class="col-12 col-md-6">
                <SAPInput
                  v-model="form.payment.baseAmount"
                  label="Base Salary Amount (LKR)"
                  type="number"
                  prefix="LKR"
                  hint="Override base amount if needed"
                />
              </div>

              <div class="col-12 text-subtitle2 text-grey-7 q-mt-md">Payment Method</div>
              <div class="col-12 col-md-4">
                <SAPSelect
                  v-model="form.payment.mode"
                  label="Payment Mode"
                  :options="['Bank', 'Cash', 'Cheque']"
                />
              </div>

              <template v-if="form.payment.mode === 'Bank'">
                <div class="col-12 col-md-4">
                  <SAPInput v-model="form.payment.bankName" label="Bank Name" />
                </div>
                <div class="col-12 col-md-4">
                  <SAPInput v-model="form.payment.accountNo" label="Account Number" />
                </div>
              </template>

              <div class="col-12 text-subtitle2 text-grey-7 q-mt-md">Statutory Requirements</div>
              <div class="col-12 col-md-6">
                <SAPInput v-model="form.payment.epfNo" label="EPF Number" />
              </div>
              <div class="col-12 col-md-6">
                <SAPInput v-model="form.payment.etfNo" label="ETF Number" />
              </div>
            </div>

            <q-stepper-navigation>
              <q-btn @click="nextStep" color="primary" label="Continue to Hierarchy" />
              <q-btn flat @click="step = 1" color="primary" label="Back" class="q-ml-sm" />
            </q-stepper-navigation>
          </q-form>
        </q-step>

        <!-- Step 3: Network/Hierarchy (Optional) -->
        <q-step :name="3" title="Sales Hierarchy" icon="lan" :done="step > 3">
          <div class="q-pa-md">
            <div class="text-subtitle1 q-mb-sm">Sales/Reporting Hierarchy</div>
            <p class="text-caption text-grey">
              Assign reporting lines for sales commissions and approvals.
            </p>

            <div class="row q-col-gutter-md">
              <div class="col-12 col-md-6">
                <SAPSelect
                  v-model="form.hierarchy.supervisorId"
                  label="Direct Supervisor"
                  :options="store.employees"
                  option-label="full_name"
                  option-value="id"
                  hint="Common reporting line"
                />
              </div>
              <div class="col-12 col-md-6">
                <SAPSelect
                  v-model="form.hierarchy.parentAgentId"
                  label="Upline Agent (Network)"
                  :options="store.getAgentsOnly"
                  option-label="full_name"
                  option-value="id"
                  hint="For MLM/Network Sales Structure"
                  clearable
                />
              </div>
              <!-- Hierarchy Preview -->
              <div class="col-12">
                <q-card flat bordered v-if="form.hierarchy.parentAgentId">
                  <q-card-section>
                    <div class="text-caption">Hierarchy Preview</div>
                    <div class="flex items-center q-mt-sm">
                      <q-chip color="primary" text-color="white" icon="person">
                        {{ getAgentName(form.hierarchy.parentAgentId) }}
                      </q-chip>
                      <q-icon name="arrow_forward" size="sm" class="q-mx-sm" />
                      <q-chip outline color="primary" icon="badge"> New Employee </q-chip>
                    </div>
                  </q-card-section>
                </q-card>
              </div>
            </div>
          </div>
          <q-stepper-navigation>
            <q-btn @click="nextStep" color="primary" label="Continue to System Access" />
            <q-btn flat @click="step = 2" color="primary" label="Back" class="q-ml-sm" />
          </q-stepper-navigation>
        </q-step>

        <!-- Step 4: System Access -->
        <q-step :name="4" title="System Access" icon="admin_panel_settings" :done="step > 4">
          <q-form @submit="submitForm" class="q-pa-md">
            <div class="row q-col-gutter-md">
              <div class="col-12">
                <q-toggle
                  v-model="form.system.enabled"
                  label="Enable System Access (User Login)"
                  color="green"
                  size="lg"
                />
              </div>

              <template v-if="form.system.enabled">
                <div class="col-12 col-md-6">
                  <SAPInput
                    v-model="form.system.email"
                    label="Login Email"
                    hint="Defaults to personal email or generated"
                    :rules="[(val) => !!val || 'Email is required for login']"
                  />
                </div>
                <!-- Role Selection -->
                <div class="col-12 col-md-6">
                  <q-select
                    v-model="form.system.role"
                    :options="authStore.roleOptions"
                    label="System Role *"
                    outlined
                    dense
                    emit-value
                    map-options
                    :rules="[(val) => !!val || 'Role is required']"
                  >
                    <template v-slot:option="scope">
                      <q-item v-bind="scope.itemProps">
                        <q-item-section>
                          <q-item-label>{{ scope.opt.label }}</q-item-label>
                          <q-item-label caption>Code: {{ scope.opt.value }}</q-item-label>
                        </q-item-section>
                      </q-item>
                    </template>
                  </q-select>
                </div>

                <div class="col-12 col-md-6">
                  <SAPInput
                    v-model="form.system.password"
                    label="Password"
                    type="password"
                    hint="Leave empty to auto-generate"
                  />
                </div>

                <!-- Granular Permissions -->
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
                            v-model="form.system.permissions"
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
              </template>
            </div>

            <q-stepper-navigation>
              <q-btn
                type="submit"
                color="positive"
                label="Create Employee"
                icon="check"
                :loading="submitting"
              />
              <q-btn flat @click="step = 3" color="primary" label="Back" class="q-ml-sm" />
            </q-stepper-navigation>
          </q-form>
        </q-step>
      </q-stepper>
    </SAPCard>

    <!-- Credential Dialog -->
    <q-dialog v-model="showCredentialsDialog">
      <SAPCard title="User Created" style="min-width: 400px">
        <div class="text-center q-pa-md">
          <q-icon name="check_circle" color="positive" size="64px" />
          <div class="text-h6 q-mt-sm">Employee Registered!</div>
          <p>System access has been granted.</p>

          <q-list bordered separator class="rounded-borders text-left q-mt-md">
            <q-item>
              <q-item-section>
                <q-item-label caption>Email</q-item-label>
                <q-item-label>{{ createdCredentials.email }}</q-item-label>
              </q-item-section>
              <q-item-section side>
                <q-btn
                  flat
                  round
                  icon="content_copy"
                  size="sm"
                  @click="copyToClipboard(createdCredentials.email)"
                />
              </q-item-section>
            </q-item>
            <q-item>
              <q-item-section>
                <q-item-label caption>Password</q-item-label>
                <q-item-label class="text-weight-bold">{{
                  createdCredentials.password
                }}</q-item-label>
              </q-item-section>
              <q-item-section side>
                <q-btn
                  flat
                  round
                  icon="content_copy"
                  size="sm"
                  @click="copyToClipboard(createdCredentials.password)"
                />
              </q-item-section>
            </q-item>
            <q-item>
              <q-item-section>
                <q-item-label caption>Role</q-item-label>
                <q-item-label>{{
                  authStore.roleOptions.find((r) => r.value === createdCredentials.role)?.label ||
                  createdCredentials.role
                }}</q-item-label>
              </q-item-section>
            </q-item>
          </q-list>

          <q-banner dense class="bg-blue-1 text-primary q-mt-md text-left">
            Permissions assigned: {{ form.system.permissions.length }}
          </q-banner>
        </div>
        <q-card-actions align="right">
          <q-btn flat label="Close" color="primary" v-close-popup @click="finish" />
        </q-card-actions>
      </SAPCard>
    </q-dialog>
  </q-page>
</template>

<script setup>
import { ref, reactive, computed, onMounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import { useQuasar, copyToClipboard as qCopy } from 'quasar'
import { useEmployeeStore } from 'stores/employeeStore'
import { useAuthStore } from 'stores/authStore'
import { SAPCard, SAPInput, SAPSelect } from 'src/components/sap'
import { supabase } from 'src/boot/supabase' // Import supabase for permission fetching

const router = useRouter()
const $q = useQuasar()
const store = useEmployeeStore()
const authStore = useAuthStore()

const step = ref(1)
const stepper = ref(null)
const submitting = ref(false)
const generatingCode = ref(false)
const showCredentialsDialog = ref(false)
const createdCredentials = reactive({ email: '', password: '', role: '' })
const availablePermissions = ref([]) // Load from DB

const form = reactive({
  basic: {
    code: '',
    firstName: '',
    lastName: '',
    mobile: '',
    email: '',
    nic: '',
    gender: 'Male',
    dob: null,
    address: '',
    departmentId: null,
    designationId: null,
    joinDate: new Date().toISOString().split('T')[0],
    type: 'Permanent',
    status: 'Active',
  },
  payment: {
    mode: 'Bank',
    bankName: '',
    accountNo: '',
    epfNo: '',
    etfNo: '',
    salaryStructureId: null,
    baseAmount: 0, // Optional override
  },
  hierarchy: {
    supervisorId: null,
    parentAgentId: null, // For MLM upline
  },
  system: {
    enabled: false,
    email: '',
    password: '',
    role: 'Z_SALES_STAFF',
    permissions: [], // Permission IDs
  },
})

// --- Computed ---
const filteredDesignations = computed(() => {
  if (!form.basic.departmentId) return store.designations
  return store.designations.filter((d) => d.department_id === form.basic.departmentId)
})

const selectedDesignationRole = ref('Z_SALES_STAFF')

// Permission Helpers
const permissionModules = computed(() => {
  return [...new Set(availablePermissions.value.map((p) => p.module))]
})

function getPermissionsByModule(mod) {
  return availablePermissions.value.filter((p) => p.module === mod)
}

// --- Methods ---
async function generateCode() {
  generatingCode.value = true
  // Trigger store action to get next code
  const nextCode = await store.generateNextEmployeeCode()
  form.basic.code = nextCode
  generatingCode.value = false
}

const onDesignationSelect = (id) => {
  // Auto-select role based on designation metadata if available
  const desg = store.designations.find((d) => d.id === id)
  if (desg) {
    // Mapping logic: e.g. "Manager" -> Z_STOCK_MGR
    // This relies on mapping or an extra column in designations table.
    // For now, simple heuristics or default to Sales Staff
    if (desg.name.toLowerCase().includes('manager')) selectedDesignationRole.value = 'Z_STOCK_MGR'
    else if (desg.name.toLowerCase().includes('kitchen'))
      selectedDesignationRole.value = 'Z_PROD_STAFF'
    else if (
      desg.name.toLowerCase().includes('waiter') ||
      desg.name.toLowerCase().includes('cashier')
    )
      selectedDesignationRole.value = 'Z_SALES_STAFF'
    else selectedDesignationRole.value = 'Z_SALES_STAFF'

    form.system.role = selectedDesignationRole.value
  }
}

// Watchers
watch(
  () => form.basic.email,
  (val) => {
    if (form.system.enabled && !form.system.email) {
      form.system.email = val
    }
  },
)

watch(
  () => form.basic.code,
  () => {
    if (form.system.enabled && !form.system.email && !form.basic.email) {
      // form.system.email = `${val.toLowerCase()}@sevenwaves.com`
    }
  },
)

function nextStep() {
  stepper.value.next()
}

function getAgentName(id) {
  const agent = store.employees.find((e) => e.id === id)
  return agent ? agent.full_name : 'Unknown'
}

async function loadPermissions() {
  const { data } = await supabase.from('permissions').select('*').order('module, resource')
  availablePermissions.value = data || []
}

async function submitForm() {
  submitting.value = true
  try {
    // 1. Create Employee Record first
    const res = await store.registerEmployee(form)
    if (!res.success) {
      $q.notify({ type: 'negative', message: 'Error creating employee: ' + res.error })
      return
    }

    const employeeId = res.data?.id

    // 2. Create System User via admin RPC if enabled
    if (form.system.enabled) {
      const loginEmail = form.system.email || `${form.basic.code.toLowerCase()}@sevenwaves.com`
      const userPassword = form.system.password || authStore.generateTempPassword()
      const roleCode = form.system.role || 'Z_SALES_STAFF'
      const perms = form.system.permissions

      const userResult = await authStore.adminCreateUser({
        email: loginEmail,
        password: userPassword,
        fullName: `${form.basic.firstName || ''} ${form.basic.lastName || ''}`.trim() || 'New User',
        roleCode: roleCode,
        permissions: perms,
        employeeId: employeeId,
      })

      if (userResult.success) {
        createdCredentials.email = loginEmail
        createdCredentials.password = userPassword
        createdCredentials.role = roleCode
        showCredentialsDialog.value = true
      } else {
        $q.notify({
          type: 'warning',
          message: 'Employee created but system user failed: ' + userResult.error,
          timeout: 0,
          actions: [
            {
              label: 'Dismiss',
              color: 'white',
              handler: () => {
                /* ... */
              },
            },
          ],
        })
        finish() // Still finish as employee is created
      }
    } else {
      $q.notify({ type: 'positive', message: 'Employee registered successfully' })
      finish()
    }
  } catch (err) {
    console.error(err)
    $q.notify({ type: 'negative', message: 'Failed to register employee' })
  } finally {
    submitting.value = false
  }
}

function copyToClipboard(text) {
  qCopy(text)
    .then(() => {
      $q.notify({ type: 'positive', message: 'Copied to clipboard', timeout: 1000 })
    })
    .catch(() => {
      $q.notify({ type: 'negative', message: 'Failed to copy' })
    })
}

function finish() {
  router.push('/hrm/employees')
}

onMounted(async () => {
  await store.fetchConfig() // Departments, Desig
  await store.fetchEmployees() // For hierarchy
  await loadPermissions()
  if (!form.basic.code) generateCode()
})
</script>

<style scoped>
.registration-card {
  min-height: 600px;
}
</style>
