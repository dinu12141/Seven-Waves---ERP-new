<template>
  <q-page class="q-pa-md bg-grey-1">
    <q-card class="my-card q-ma-md shadow-3">
      <q-card-section class="bg-primary text-white">
        <div class="text-h6">Employee Registration Wizard</div>
        <div class="text-subtitle2">Register a new employee into the system</div>
      </q-card-section>

      <q-card-section>
        <q-stepper v-model="step" ref="stepper" color="primary" animated header-nav>
          <!-- STEP 1: BASIC INFORMATION -->
          <q-step :name="1" title="Basic Information" icon="person" :done="step > 1">
            <div class="row q-col-gutter-md">
              <div class="col-12 col-md-4">
                <q-input
                  v-model="form.basic.code"
                  label="User Code"
                  outlined
                  dense
                  readonly
                  hint="Auto-generated"
                >
                  <template v-slot:append>
                    <q-btn flat round icon="refresh" @click="generateCode" />
                  </template>
                </q-input>
              </div>
              <div class="col-12 col-md-4">
                <q-input
                  v-model="form.basic.firstName"
                  label="First Name"
                  outlined
                  dense
                  :rules="[(val) => !!val || 'Required']"
                />
              </div>
              <div class="col-12 col-md-4">
                <q-input
                  v-model="form.basic.lastName"
                  label="Last Name"
                  outlined
                  dense
                  :rules="[(val) => !!val || 'Required']"
                />
              </div>

              <div class="col-12 col-md-6">
                <q-input v-model="form.basic.initials" label="Name with Initials" outlined dense />
              </div>
              <div class="col-12 col-md-3">
                <q-select
                  v-model="form.basic.gender"
                  :options="['Male', 'Female', 'Other']"
                  label="Gender"
                  outlined
                  dense
                />
              </div>
              <div class="col-12 col-md-3">
                <q-input
                  v-model="form.basic.dob"
                  label="Date of Birth"
                  outlined
                  dense
                  type="date"
                  stack-label
                />
              </div>

              <div class="col-12 col-md-4">
                <q-input v-model="form.basic.nic" label="NIC Number" outlined dense />
              </div>
              <div class="col-12 col-md-4">
                <q-input v-model="form.basic.passport" label="Passport No" outlined dense />
              </div>
              <div class="col-12 col-md-4">
                <q-input v-model="form.basic.license" label="Driving License" outlined dense />
              </div>

              <div class="col-12 col-md-4">
                <q-select
                  v-model="form.basic.civilStatus"
                  :options="['Single', 'Married', 'Divorced']"
                  label="Civil Status"
                  outlined
                  dense
                />
              </div>
              <div class="col-12 col-md-4">
                <q-input v-model="form.basic.nationality" label="Nationality" outlined dense />
              </div>

              <div class="col-12">
                <q-separator class="q-my-sm" />
                <div class="text-subtitle2 q-mb-sm">Contact Details</div>
              </div>

              <div class="col-12 col-md-6">
                <q-input
                  v-model="form.basic.email"
                  label="Personal Email"
                  outlined
                  dense
                  type="email"
                />
              </div>
              <div class="col-12 col-md-6">
                <q-input v-model="form.basic.mobile" label="Mobile Phone" outlined dense />
              </div>
              <div class="col-12">
                <q-input
                  v-model="form.basic.address"
                  label="Permanent Address"
                  outlined
                  dense
                  type="textarea"
                  rows="3"
                />
              </div>
            </div>
          </q-step>

          <!-- STEP 2: STATUS & BANKING -->
          <q-step :name="2" title="Status & Banking" icon="account_balance" :done="step > 2">
            <div class="row q-col-gutter-md">
              <div class="col-12 col-md-4">
                <q-select
                  v-model="form.status.type"
                  :options="['Permanent', 'Contract', 'Probation', 'Intern', 'Part-Time']"
                  label="Employment Type"
                  outlined
                  dense
                />
              </div>

              <!-- Department & Designation -->
              <div class="col-12 col-md-4">
                <q-select
                  v-model="form.basic.departmentId"
                  :options="store.departments"
                  option-label="name"
                  option-value="id"
                  label="Department"
                  outlined
                  dense
                  emit-value
                  map-options
                />
              </div>
              <div class="col-12 col-md-4">
                <q-select
                  v-model="form.basic.designationId"
                  :options="filteredDesignations"
                  option-label="name"
                  option-value="id"
                  label="Designation (Job Role)"
                  outlined
                  dense
                  emit-value
                  map-options
                  @update:model-value="onDesignationSelect"
                />
              </div>

              <!-- System Access Hint -->
              <div class="col-12" v-if="selectedDesignationRole">
                <q-banner class="bg-blue-1 text-primary rounded-borders q-my-sm" dense>
                  <template v-slot:avatar>
                    <q-icon name="admin_panel_settings" color="primary" />
                  </template>
                  <strong>System Access:</strong> User will be created with Role
                  <q-badge color="primary">{{ selectedDesignationRole }}</q-badge>
                  and default credentials.
                </q-banner>
              </div>
              <div class="col-12 col-md-4">
                <q-input
                  v-model="form.status.joiningDate"
                  label="Date of Joining"
                  outlined
                  dense
                  type="date"
                  stack-label
                />
              </div>
              <div class="col-12 col-md-4">
                <q-input
                  v-model="form.status.confirmationDate"
                  label="Confirmation Date"
                  outlined
                  dense
                  type="date"
                  stack-label
                />
              </div>

              <div class="col-12 col-md-6" v-if="form.status.type === 'Permanent'">
                <q-input v-model="form.status.epfNumber" label="EPF Number" outlined dense />
              </div>
              <div class="col-12 col-md-6" v-if="form.status.type === 'Permanent'">
                <q-input v-model="form.status.etfNumber" label="ETF Number" outlined dense />
              </div>

              <div class="col-12">
                <q-toggle v-model="form.status.welfare" label="Activate Welfare Membership" />
              </div>

              <div class="col-12">
                <q-separator class="q-my-sm" />
                <div class="text-subtitle2 q-mb-sm">Banking Details</div>
              </div>

              <div class="col-12 col-md-4">
                <q-select
                  v-model="form.banking.method"
                  :options="['Bank', 'Cash', 'Cheque']"
                  label="Salary Mode"
                  outlined
                  dense
                />
              </div>

              <template v-if="form.banking.method === 'Bank'">
                <div class="col-12 col-md-4">
                  <q-input v-model="form.banking.bankName" label="Bank Name" outlined dense />
                </div>
                <div class="col-12 col-md-4">
                  <q-input v-model="form.banking.branch" label="Branch" outlined dense />
                </div>
                <div class="col-12 col-md-6">
                  <q-input
                    v-model="form.banking.accountNumber"
                    label="Account Number"
                    outlined
                    dense
                  />
                </div>
              </template>

              <div class="col-12">
                <q-separator class="q-my-sm" />
                <div class="text-subtitle2 q-mb-sm">KYC Documents</div>
                <div class="q-gutter-sm">
                  <q-checkbox v-model="form.status.kycDocs" val="NIC Copy" label="NIC Copy" />
                  <q-checkbox v-model="form.status.kycDocs" val="CV" label="CV" />
                  <q-checkbox
                    v-model="form.status.kycDocs"
                    val="Educational Certificates"
                    label="Educational Certificates"
                  />
                  <q-checkbox
                    v-model="form.status.kycDocs"
                    val="GS Certificate"
                    label="GS Certificate"
                  />
                  <q-checkbox
                    v-model="form.status.kycDocs"
                    val="Police Report"
                    label="Police Report"
                  />
                </div>
              </div>
            </div>
          </q-step>

          <!-- STEP 3: NETWORK REGISTRATION -->
          <q-step :name="3" title="Network Hierarchy" icon="hub" :done="step > 3">
            <div class="text-subtitle1 q-mb-md">Assign Employee to Sales Network</div>

            <div class="row q-col-gutter-md">
              <div class="col-12 col-md-6">
                <!-- Cascading Selects -->
                <q-select
                  v-model="selectedZone"
                  :options="zoneOptions"
                  option-label="name"
                  option-value="id"
                  label="Select Zone"
                  outlined
                  dense
                  @update:model-value="onZoneSelect"
                />
              </div>

              <div class="col-12 col-md-6" v-if="selectedZone">
                <q-select
                  v-model="selectedRegion"
                  :options="regionOptions"
                  option-label="name"
                  option-value="id"
                  label="Select Region"
                  outlined
                  dense
                  @update:model-value="onRegionSelect"
                />
              </div>

              <div class="col-12 col-md-6" v-if="selectedRegion">
                <q-select
                  v-model="selectedDistrict"
                  :options="districtOptions"
                  option-label="name"
                  option-value="id"
                  label="Select District"
                  outlined
                  dense
                  @update:model-value="onDistrictSelect"
                />
              </div>

              <div class="col-12 col-md-6" v-if="selectedDistrict">
                <q-select
                  v-model="selectedBranch"
                  :options="branchOptions"
                  option-label="name"
                  option-value="id"
                  label="Select Branch"
                  outlined
                  dense
                  @update:model-value="onBranchSelect"
                />
              </div>

              <div class="col-12 col-md-6" v-if="selectedBranch">
                <q-select
                  v-model="selectedTeam"
                  :options="teamOptions"
                  option-label="name"
                  option-value="id"
                  label="Select Team"
                  outlined
                  dense
                />
              </div>

              <div class="col-12">
                <div class="bg-blue-1 q-pa-sm rounded-borders" v-if="selectedTeam">
                  <strong>Selected Assignment:</strong> {{ selectedTeam.name }} (Team) <br />
                  <small>Manager: {{ selectedTeam.manager?.full_name || 'Unassigned' }}</small>
                </div>
              </div>

              <div class="col-12 col-md-6">
                <q-select
                  v-model="form.hierarchy.role"
                  :options="['Member', 'Leader', 'Assistant Leader']"
                  label="Role in Network"
                  outlined
                  dense
                />
              </div>
            </div>
          </q-step>

          <!-- STEP 4: PAYMENT REGISTRATION -->
          <q-step :name="4" title="Payment Setup" icon="payments">
            <div class="row q-col-gutter-md">
              <div class="col-12">
                <div class="text-subtitle2">Primary Salary Method</div>
                <q-option-group
                  v-model="form.payment.method"
                  :options="[
                    { label: 'Basic Salary', value: 'Basic' },
                    { label: 'Unit Based', value: 'Unit' },
                    { label: 'Day Based', value: 'Day' },
                    { label: 'Commission Only', value: 'Commission' },
                  ]"
                  color="primary"
                  inline
                />
              </div>

              <!-- Dynamic Fields based on Selection -->
              <div class="col-12 col-md-6" v-if="form.payment.method === 'Basic'">
                <q-input
                  v-model.number="form.payment.basicSalary"
                  label="Basic Salary Amount"
                  outlined
                  dense
                  type="number"
                  prefix="LKR"
                />
              </div>

              <div class="col-12 col-md-6" v-if="form.payment.method === 'Unit'">
                <q-input
                  v-model.number="form.payment.unitRate"
                  label="Rate Per Unit"
                  outlined
                  dense
                  type="number"
                  prefix="LKR"
                />
              </div>

              <div class="col-12 col-md-6" v-if="form.payment.method === 'Day'">
                <q-input
                  v-model.number="form.payment.dailyRate"
                  label="Daily Rate"
                  outlined
                  dense
                  type="number"
                  prefix="LKR"
                />
              </div>

              <div class="col-12 col-md-6">
                <q-select
                  v-model="form.payment.packageId"
                  :options="store.commissionPackages"
                  option-label="name"
                  option-value="id"
                  label="Commission Package"
                  outlined
                  dense
                  emit-value
                  map-options
                  clearable
                />
              </div>

              <!-- Allowances Table -->
              <div class="col-12">
                <q-separator class="q-my-sm" />
                <div class="row items-center justify-between">
                  <div class="text-subtitle2">Allowances</div>
                  <q-btn size="sm" color="secondary" label="Add Allowance" @click="addAllowance" />
                </div>

                <q-markup-table flat bordered class="q-mt-sm">
                  <thead>
                    <tr>
                      <th>Allowance Name</th>
                      <th>Amount</th>
                      <th>Action</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr v-for="(allowance, idx) in form.payment.allowances" :key="idx">
                      <td>
                        <q-input
                          v-model="allowance.name"
                          dense
                          borderless
                          placeholder="Name e.g Fuel"
                        />
                      </td>
                      <td>
                        <q-input v-model.number="allowance.amount" dense borderless type="number" />
                      </td>
                      <td>
                        <q-btn
                          flat
                          round
                          icon="delete"
                          color="negative"
                          @click="removeAllowance(idx)"
                          size="sm"
                        />
                      </td>
                    </tr>
                  </tbody>
                </q-markup-table>
              </div>
            </div>
          </q-step>

          <template v-slot:navigation>
            <q-stepper-navigation>
              <q-btn
                @click="handleNext"
                color="primary"
                :label="step === 4 ? 'Finish' : 'Continue'"
                :loading="store.loading"
              />
              <q-btn
                v-if="step > 1"
                flat
                color="primary"
                @click="$refs.stepper.previous()"
                label="Back"
                class="q-ml-sm"
              />
            </q-stepper-navigation>
          </template>
        </q-stepper>
      </q-card-section>
    </q-card>
  </q-page>
</template>

<script setup>
import { ref, reactive, onMounted, computed } from 'vue'
import { useRouter } from 'vue-router'
import { useQuasar } from 'quasar'
import { useEmployeeStore } from 'stores/employeeStore' // Adjust path if needed

const $q = useQuasar()
const router = useRouter()
const store = useEmployeeStore()

const step = ref(1)
const stepper = ref(null)

// Form State
const form = reactive({
  basic: {
    code: '',
    firstName: '',
    lastName: '',
    initials: '',
    gender: 'Male',
    dob: '',
    nic: '',
    passport: '',
    license: '',
    civilStatus: 'Single',
    nationality: 'Sri Lankan',
    email: '',
    mobile: '',
    address: '',
    education: [],
    departmentId: null,
    designationId: null,
  },
  status: {
    type: 'Permanent',
    joiningDate: '',
    confirmationDate: '',
    epfNumber: '',
    etfNumber: '',
    welfare: false,
    kycDocs: [],
  },
  banking: {
    method: 'Bank',
    bankName: '',
    branch: '',
    accountNumber: '',
  },
  hierarchy: {
    nodeId: null, // Selected final node (Team/Branch etc)
    role: 'Member',
  },
  payment: {
    method: 'Basic', // Basic, Unit, Day, Commission
    basicSalary: 0,
    unitRate: 0,
    dailyRate: 0,
    packageId: null,
    allowances: [],
  },
})

// Hierarchy Selections
const selectedZone = ref(null)
const selectedRegion = ref(null)
const selectedDistrict = ref(null)
const selectedBranch = ref(null)
const selectedTeam = ref(null)

const zoneOptions = computed(() => store.salesHierarchy.filter((h) => h.type === 'Zone'))
const regionOptions = ref([])
const districtOptions = ref([])
const branchOptions = ref([])
const teamOptions = ref([])

const filteredDesignations = computed(() => {
  if (!form.basic.departmentId) return store.designations
  return store.designations.filter((d) => d.department_id === form.basic.departmentId)
})

const selectedDesignationRole = ref('')
const onDesignationSelect = (id) => {
  const desg = store.designations.find((d) => d.id === id)
  if (desg) selectedDesignationRole.value = desg.related_user_role || 'Default Staff'
}

// Lifecycle
onMounted(async () => {
  await store.fetchConfigurationData()
  await generateCode()
})

const generateCode = async () => {
  form.basic.code = await store.generateUserCode()
}

// Hierarchy Logic
const onZoneSelect = (val) => {
  selectedRegion.value = null
  if (val) regionOptions.value = store.getChildren(val.id)
  else regionOptions.value = []
  resetHierarchyFrom('Region')
}

const onRegionSelect = (val) => {
  selectedDistrict.value = null
  if (val) districtOptions.value = store.getChildren(val.id)
  else districtOptions.value = []
  resetHierarchyFrom('District')
}

const onDistrictSelect = (val) => {
  selectedBranch.value = null
  if (val) branchOptions.value = store.getChildren(val.id)
  else branchOptions.value = []
  resetHierarchyFrom('Branch')
}

const onBranchSelect = (val) => {
  selectedTeam.value = null
  if (val) teamOptions.value = store.getChildren(val.id)
  else teamOptions.value = []
}

const resetHierarchyFrom = (level) => {
  if (level === 'Region') {
    selectedDistrict.value = null
    selectedBranch.value = null
    selectedTeam.value = null
  }
  if (level === 'District') {
    selectedBranch.value = null
    selectedTeam.value = null
  }
  if (level === 'Branch') {
    selectedTeam.value = null
  }
}

// Allowance Logic
const addAllowance = () => {
  form.payment.allowances.push({ name: '', amount: 0 })
}
const removeAllowance = (idx) => {
  form.payment.allowances.splice(idx, 1)
}

// Navigation
const handleNext = async () => {
  if (step.value === 4) {
    await submitForm()
  } else {
    stepper.value.next()
  }
}

const submitForm = async () => {
  // Assign final hierarchy selection
  // Prefer Team -> Branch -> District -> Region -> Zone (deepest selected)
  if (selectedTeam.value) form.hierarchy.nodeId = selectedTeam.value.id
  else if (selectedBranch.value) form.hierarchy.nodeId = selectedBranch.value.id
  else if (selectedDistrict.value) form.hierarchy.nodeId = selectedDistrict.value.id

  const res = await store.registerEmployee(form)
  if (res.success) {
    $q.notify({ type: 'positive', message: 'Employee Registered Successfully!' })
    router.push('/hrm/employees') // Redirect to list
  } else {
    $q.notify({ type: 'negative', message: 'Error: ' + res.error })
  }
}
</script>
