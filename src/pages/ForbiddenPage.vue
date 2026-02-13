<template>
  <div class="fullscreen bg-white text-center q-pa-md flex flex-center">
    <div>
      <div class="forbidden-icon q-mb-lg">
        <q-icon name="lock" size="80px" color="negative" />
      </div>
      <div class="text-h3 text-weight-bold text-negative q-mb-sm">403</div>
      <div class="text-h5 text-grey-8 q-mb-md">Access Denied</div>
      <p class="text-body1 text-grey-6" style="max-width: 400px; margin: 0 auto">
        You don't have permission to access this page. Contact your administrator if you believe
        this is an error.
      </p>

      <!-- Debug Info -->
      <div
        class="q-mt-md q-pa-sm bg-grey-2 rounded-borders text-caption text-left"
        style="max-width: 500px; margin: 20px auto; overflow-wrap: break-word"
      >
        <div><strong>User:</strong> {{ authStore.user?.email || 'Not logged in' }}</div>
        <div>
          <strong>Role:</strong> {{ authStore.profile?.role || 'None' }} ({{
            authStore.roleDisplayName
          }})
        </div>
        <div><strong>Is Admin:</strong> {{ authStore.isAdmin }}</div>
        <div><strong>Permissions:</strong> {{ authStore.permissions.length }}</div>
        <div v-if="authStore.error" class="text-negative">
          <strong>Error:</strong> {{ authStore.error }}
        </div>
      </div>

      <div class="q-mt-lg q-gutter-sm">
        <q-btn
          color="primary"
          label="Go to Dashboard"
          icon="dashboard"
          @click="$router.push('/dashboard')"
          unelevated
        />
        <q-btn outline color="grey-7" label="Go Back" icon="arrow_back" @click="$router.back()" />
        <q-btn outline color="negative" label="Logout" icon="logout" @click="handleLogout" />
      </div>
    </div>
  </div>
</template>

<style scoped>
.forbidden-icon {
  background: rgba(255, 0, 0, 0.06);
  border-radius: 50%;
  width: 140px;
  height: 140px;
  display: flex;
  align-items: center;
  justify-content: center;
  margin: 0 auto;
}
</style>

<script setup>
import { useAuthStore } from 'src/stores/authStore'
import { useRouter } from 'vue-router'

const authStore = useAuthStore()
const router = useRouter()

async function handleLogout() {
  await authStore.logout()
  router.push('/login')
}
</script>
