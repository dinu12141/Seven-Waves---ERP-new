<template>
  <q-page class="q-pa-md bg-grey-1">
    <!-- Page Header -->
    <div class="row items-center q-mb-lg">
      <div>
        <div class="text-h5 text-weight-bold">User Management</div>
        <div class="text-subtitle2 text-grey-7">Manage system users and permissions</div>
      </div>
      <q-space />
      <q-btn
        color="primary"
        icon="person_add"
        label="Create User"
        unelevated
        @click="showCreateDialog = true"
      />
    </div>

    <!-- Users Table -->
    <q-card flat bordered>
      <q-card-section class="q-pa-none">
        <q-table
          :rows="authStore.allUsers"
          :columns="columns"
          row-key="id"
          :loading="authStore.loading"
          :filter="searchFilter"
          :pagination="{ rowsPerPage: 15 }"
          flat
          bordered
        >
          <!-- Search -->
          <template v-slot:top-right>
            <q-input
              v-model="searchFilter"
              placeholder="Search users..."
              dense
              outlined
              class="q-mr-md"
              style="min-width: 250px"
            >
              <template v-slot:prepend>
                <q-icon name="search" />
              </template>
            </q-input>
          </template>

          <!-- Role Badge -->
          <template v-slot:body-cell-role="props">
            <q-td :props="props">
              <q-badge
                :color="getRoleBadgeColor(props.row.role)"
                :label="authStore.roleDisplayNames[props.row.role] || props.row.role"
              />
            </q-td>
          </template>

          <!-- Status -->
          <template v-slot:body-cell-status="props">
            <q-td :props="props">
              <q-badge
                :color="props.row.is_active !== false ? 'positive' : 'grey'"
                :label="props.row.is_active !== false ? 'Active' : 'Disabled'"
              />
            </q-td>
          </template>

          <!-- Created date -->
          <template v-slot:body-cell-created_at="props">
            <q-td :props="props">
              {{ formatDate(props.row.created_at) }}
            </q-td>
          </template>

          <!-- Actions -->
          <template v-slot:body-cell-actions="props">
            <q-td :props="props" class="q-gutter-xs">
              <q-btn
                flat
                round
                dense
                icon="security"
                color="orange"
                @click="openPermissionsDialog(props.row)"
              >
                <q-tooltip>Edit Permissions</q-tooltip>
              </q-btn>
              <q-btn
                flat
                round
                dense
                icon="edit"
                color="primary"
                @click="openEditDialog(props.row)"
              >
                <q-tooltip>Edit User</q-tooltip>
              </q-btn>
            </q-td>
          </template>
        </q-table>
      </q-card-section>
    </q-card>

    <!-- CREATE USER DIALOG -->
    <q-dialog
      v-model="showCreateDialog"
      persistent
      maximized
      transition-show="slide-up"
      transition-hide="slide-down"
    >
      <q-card class="create-user-card">
        <q-card-section class="bg-primary text-white row items-center">
          <q-icon name="person_add" size="24px" class="q-mr-sm" />
          <div class="text-h6">Create New User</div>
          <q-space />
          <q-btn flat round dense icon="close" @click="closeCreateDialog" />
        </q-card-section>

        <q-card-section class="q-pa-lg" style="max-height: calc(100vh - 120px); overflow-y: auto">
          <q-stepper v-model="createStep" ref="createStepper" color="primary" animated header-nav>
            <!-- Step 1: Basic Info -->
            <q-step :name="1" title="User Details" icon="person" :done="createStep > 1">
              <div class="row q-col-gutter-md">
                <div class="col-12 col-md-6">
                  <q-input
                    v-model="createForm.fullName"
                    label="Full Name *"
                    outlined
                    dense
                    :rules="[(val) => !!val || 'Full name is required']"
                  />
                </div>
                <div class="col-12 col-md-6">
                  <q-input
                    v-model="createForm.email"
                    label="Email Address *"
                    outlined
                    dense
                    type="email"
                    :rules="[
                      (val) => !!val || 'Email is required',
                      (val) => /.+@.+\..+/.test(val) || 'Enter a valid email',
                    ]"
                  />
                </div>

                <div class="col-12 col-md-6">
                  <q-select
                    v-model="createForm.roleCode"
                    :options="authStore.roleOptions"
                    label="System Role *"
                    outlined
                    dense
                    emit-value
                    map-options
                    :rules="[(val) => !!val || 'Role is required']"
                  />
                </div>

                <div class="col-12 col-md-6">
                  <q-input
                    v-model="createForm.password"
                    label="Temporary Password"
                    outlined
                    dense
                    readonly
                  >
                    <template v-slot:append>
                      <q-btn flat round dense icon="refresh" @click="regeneratePassword">
                        <q-tooltip>Generate New Password</q-tooltip>
                      </q-btn>
                      <q-btn flat round dense icon="content_copy" @click="copyPassword">
                        <q-tooltip>Copy Password</q-tooltip>
                      </q-btn>
                    </template>
                  </q-input>
                </div>

                <div class="col-12">
                  <q-banner class="bg-amber-1 text-brown-8 rounded-borders" dense>
                    <template v-slot:avatar>
                      <q-icon name="info" color="amber-8" />
                    </template>
                    Save this temporary password — it will only be shown once. The user should
                    change it on first login.
                  </q-banner>
                </div>
              </div>
            </q-step>

            <!-- Step 2: Permissions -->
            <q-step :name="2" title="Permissions" icon="security" :done="createStep > 2">
              <div class="q-mb-md">
                <q-banner class="bg-blue-1 rounded-borders" dense>
                  <template v-slot:avatar>
                    <q-icon name="info" color="primary" />
                  </template>
                  <span class="text-weight-medium">Role-based defaults</span> are shown in
                  <q-badge color="green" label="green" class="q-mx-xs" />. Custom overrides appear
                  in <q-badge color="orange" label="orange" class="q-mx-xs" />. Uncheck a green
                  permission to explicitly deny it.
                </q-banner>
              </div>
              <PermissionSelector
                v-model="createForm.permissions"
                :role-code="createForm.roleCode"
              />
            </q-step>

            <!-- Step 3: Review -->
            <q-step :name="3" title="Review" icon="check_circle">
              <q-card flat bordered class="q-mb-md">
                <q-card-section>
                  <div class="text-subtitle1 text-weight-bold q-mb-sm">User Summary</div>
                  <q-list dense>
                    <q-item>
                      <q-item-section avatar><q-icon name="person" /></q-item-section>
                      <q-item-section>
                        <q-item-label>{{ createForm.fullName }}</q-item-label>
                        <q-item-label caption>Full Name</q-item-label>
                      </q-item-section>
                    </q-item>
                    <q-item>
                      <q-item-section avatar><q-icon name="email" /></q-item-section>
                      <q-item-section>
                        <q-item-label>{{ createForm.email }}</q-item-label>
                        <q-item-label caption>Email</q-item-label>
                      </q-item-section>
                    </q-item>
                    <q-item>
                      <q-item-section avatar><q-icon name="badge" /></q-item-section>
                      <q-item-section>
                        <q-item-label>
                          <q-badge
                            :color="getRoleBadgeColor(createForm.roleCode)"
                            :label="
                              authStore.roleDisplayNames[createForm.roleCode] || createForm.roleCode
                            "
                          />
                        </q-item-label>
                        <q-item-label caption>Role</q-item-label>
                      </q-item-section>
                    </q-item>
                    <q-item>
                      <q-item-section avatar><q-icon name="security" /></q-item-section>
                      <q-item-section>
                        <q-item-label
                          >{{
                            createForm.permissions.filter((p) => p.grant_type === 'allow').length
                          }}
                          custom allows,
                          {{
                            createForm.permissions.filter((p) => p.grant_type === 'deny').length
                          }}
                          denies</q-item-label
                        >
                        <q-item-label caption>Permission Overrides</q-item-label>
                      </q-item-section>
                    </q-item>
                  </q-list>
                </q-card-section>
              </q-card>

              <q-card flat bordered class="bg-green-1">
                <q-card-section>
                  <div class="row items-center">
                    <q-icon name="vpn_key" size="24px" color="green" class="q-mr-sm" />
                    <div>
                      <div class="text-weight-bold">Temporary Password</div>
                      <div
                        class="text-h6 text-weight-bold text-green-8"
                        style="font-family: monospace"
                      >
                        {{ createForm.password }}
                      </div>
                    </div>
                    <q-space />
                    <q-btn
                      flat
                      icon="content_copy"
                      color="green"
                      @click="copyPassword"
                      label="Copy"
                    />
                  </div>
                </q-card-section>
              </q-card>
            </q-step>

            <template v-slot:navigation>
              <q-stepper-navigation>
                <q-btn
                  @click="handleCreateStep"
                  color="primary"
                  :label="createStep === 3 ? 'Create User' : 'Continue'"
                  :loading="authStore.loading"
                  unelevated
                />
                <q-btn
                  v-if="createStep > 1"
                  flat
                  color="primary"
                  @click="createStep--"
                  label="Back"
                  class="q-ml-sm"
                />
              </q-stepper-navigation>
            </template>
          </q-stepper>
        </q-card-section>
      </q-card>
    </q-dialog>

    <!-- EDIT PERMISSIONS DIALOG -->
    <q-dialog
      v-model="showPermDialog"
      persistent
      maximized
      transition-show="slide-up"
      transition-hide="slide-down"
    >
      <q-card>
        <q-card-section class="bg-orange text-white row items-center">
          <q-icon name="security" size="24px" class="q-mr-sm" />
          <div class="text-h6">Edit Permissions — {{ editingUser?.full_name }}</div>
          <q-space />
          <q-btn flat round dense icon="close" @click="showPermDialog = false" />
        </q-card-section>

        <q-card-section class="q-pa-lg" style="max-height: calc(100vh - 120px); overflow-y: auto">
          <div class="q-mb-md">
            <q-banner class="bg-blue-1 rounded-borders" dense>
              <template v-slot:avatar>
                <q-icon name="info" color="primary" />
              </template>
              Current role:
              <q-badge
                color="primary"
                :label="authStore.roleDisplayNames[editingUser?.role] || editingUser?.role"
                class="q-mx-xs"
              />
              — role defaults in <q-badge color="green" label="green" class="q-mx-xs" />, overrides
              in <q-badge color="orange" label="orange" class="q-mx-xs" />.
            </q-banner>
          </div>

          <PermissionSelector v-model="editPermissions" :role-code="editingUser?.role" />
        </q-card-section>

        <q-card-actions align="right" class="q-pa-md">
          <q-btn flat label="Cancel" @click="showPermDialog = false" />
          <q-btn
            color="primary"
            label="Save Permissions"
            unelevated
            :loading="authStore.loading"
            @click="savePermissions"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <!-- EDIT USER DIALOG -->
    <q-dialog v-model="showEditDialog">
      <q-card style="min-width: 400px">
        <q-card-section class="bg-primary text-white">
          <div class="text-h6">Edit User</div>
        </q-card-section>

        <q-card-section>
          <q-input v-model="editForm.full_name" label="Full Name" outlined dense class="q-mb-md" />
          <q-select
            v-model="editForm.role"
            :options="authStore.roleOptions"
            label="System Role"
            outlined
            dense
            emit-value
            map-options
          />
        </q-card-section>

        <q-card-actions align="right">
          <q-btn flat label="Cancel" @click="showEditDialog = false" />
          <q-btn
            color="primary"
            label="Save"
            unelevated
            :loading="authStore.loading"
            @click="saveUserEdit"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <!-- SUCCESS DIALOG -->
    <q-dialog v-model="showSuccessDialog">
      <q-card style="min-width: 400px">
        <q-card-section class="bg-positive text-white text-center">
          <q-icon name="check_circle" size="48px" />
          <div class="text-h6 q-mt-sm">User Created Successfully!</div>
        </q-card-section>

        <q-card-section class="text-center">
          <p class="text-body1">Share these credentials with the user:</p>
          <q-card flat bordered class="q-pa-md bg-grey-1">
            <div class="q-mb-sm"><strong>Email:</strong> {{ createdUserEmail }}</div>
            <div>
              <strong>Password:</strong>
              <span class="text-h6 text-weight-bold" style="font-family: monospace">{{
                createdUserPassword
              }}</span>
            </div>
          </q-card>
          <q-btn
            flat
            color="primary"
            icon="content_copy"
            label="Copy Credentials"
            @click="copyCreatedCredentials"
            class="q-mt-sm"
          />
        </q-card-section>

        <q-card-actions align="center">
          <q-btn color="primary" label="Done" unelevated @click="showSuccessDialog = false" />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup>
import { ref, reactive, onMounted } from 'vue'
import { useQuasar, copyToClipboard } from 'quasar'
import { useAuthStore } from 'src/stores/authStore'
import PermissionSelector from 'src/components/PermissionSelector.vue'

const $q = useQuasar()
const authStore = useAuthStore()

const searchFilter = ref('')
const showCreateDialog = ref(false)
const showPermDialog = ref(false)
const showEditDialog = ref(false)
const showSuccessDialog = ref(false)
const createStep = ref(1)

// Created user credentials (for success dialog)
const createdUserEmail = ref('')
const createdUserPassword = ref('')

// Table columns
const columns = [
  { name: 'full_name', label: 'Full Name', field: 'full_name', sortable: true, align: 'left' },
  { name: 'email', label: 'Email', field: 'email', sortable: true, align: 'left' },
  { name: 'role', label: 'Role', field: 'role', sortable: true, align: 'left' },
  { name: 'status', label: 'Status', field: 'is_active', align: 'center' },
  { name: 'created_at', label: 'Created', field: 'created_at', sortable: true, align: 'left' },
  { name: 'actions', label: 'Actions', field: 'actions', align: 'center' },
]

// Create form
const createForm = reactive({
  fullName: '',
  email: '',
  roleCode: 'Z_SALES_STAFF',
  password: '',
  permissions: [],
})

// Edit form
const editForm = reactive({
  id: null,
  full_name: '',
  role: '',
})

// Permission editing
const editingUser = ref(null)
const editPermissions = ref([])

// Lifecycle
onMounted(async () => {
  await authStore.fetchAllUsers()
  regeneratePassword()
})

// Helpers
function getRoleBadgeColor(role) {
  const colors = {
    Z_ALL: 'deep-purple',
    Z_STOCK_MGR: 'teal',
    Z_INV_CLERK: 'cyan',
    Z_PROD_STAFF: 'orange',
    Z_SALES_STAFF: 'blue',
    Z_HR_MANAGER: 'pink',
    Z_HR_OFFICER: 'pink-4',
    Z_FINANCE: 'green',
    Z_KITCHEN: 'amber-8',
    Z_WAITER: 'light-blue',
    Z_CASHIER: 'indigo',
    admin: 'deep-purple',
    manager: 'teal',
  }
  return colors[role] || 'grey'
}

function formatDate(dateStr) {
  if (!dateStr) return '—'
  return new Date(dateStr).toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
  })
}

function regeneratePassword() {
  createForm.password = authStore.generateTempPassword()
}

function copyPassword() {
  copyToClipboard(createForm.password)
    .then(() => $q.notify({ type: 'positive', message: 'Password copied to clipboard' }))
    .catch(() => $q.notify({ type: 'negative', message: 'Failed to copy' }))
}

function copyCreatedCredentials() {
  const text = `Email: ${createdUserEmail.value}\nPassword: ${createdUserPassword.value}`
  copyToClipboard(text)
    .then(() => $q.notify({ type: 'positive', message: 'Credentials copied to clipboard' }))
    .catch(() => $q.notify({ type: 'negative', message: 'Failed to copy' }))
}

// Create User Flow
async function handleCreateStep() {
  if (createStep.value < 3) {
    createStep.value++
    return
  }

  // Step 3 — Submit
  const result = await authStore.adminCreateUser({
    email: createForm.email,
    password: createForm.password,
    fullName: createForm.fullName,
    roleCode: createForm.roleCode,
    permissions: createForm.permissions,
  })

  if (result.success) {
    createdUserEmail.value = createForm.email
    createdUserPassword.value = createForm.password

    showCreateDialog.value = false
    showSuccessDialog.value = true

    // Reset form
    createForm.fullName = ''
    createForm.email = ''
    createForm.roleCode = 'Z_SALES_STAFF'
    createForm.permissions = []
    createStep.value = 1
    regeneratePassword()

    // Refresh users list
    await authStore.fetchAllUsers()
  } else {
    $q.notify({ type: 'negative', message: 'Error: ' + result.error })
  }
}

function closeCreateDialog() {
  showCreateDialog.value = false
  createStep.value = 1
}

// Edit Permissions
async function openPermissionsDialog(user) {
  editingUser.value = user

  // Load existing user-level overrides
  const result = await authStore.fetchUserPermissions(user.id)
  editPermissions.value = result.data || []
  showPermDialog.value = true
}

async function savePermissions() {
  const result = await authStore.updateUserPermissions(editingUser.value.id, editPermissions.value)

  if (result.success) {
    $q.notify({ type: 'positive', message: 'Permissions updated successfully' })
    showPermDialog.value = false
  } else {
    $q.notify({ type: 'negative', message: 'Error: ' + result.error })
  }
}

// Edit User
function openEditDialog(user) {
  editForm.id = user.id
  editForm.full_name = user.full_name
  editForm.role = user.role
  showEditDialog.value = true
}

async function saveUserEdit() {
  const result = await authStore.updateUserProfile(editForm.id, {
    full_name: editForm.full_name,
    role: editForm.role,
  })

  if (result.success) {
    $q.notify({ type: 'positive', message: 'User updated successfully' })
    showEditDialog.value = false
    await authStore.fetchAllUsers()
  } else {
    $q.notify({ type: 'negative', message: 'Error: ' + result.error })
  }
}
</script>

<style scoped>
.create-user-card {
  max-width: 900px;
  margin: 0 auto;
}
</style>
