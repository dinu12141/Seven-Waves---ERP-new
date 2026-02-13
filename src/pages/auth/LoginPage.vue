<template>
  <q-page class="login-page">
    <div class="login-container">
      <!-- Logo Section -->
      <div class="logo-section">
        <div class="logo-icon">
          <q-icon name="waves" size="64px" />
        </div>
        <h1 class="brand-name">Seven Waves</h1>
        <p class="brand-tagline">Enterprise Resource Planning</p>
      </div>

      <!-- Login Card -->
      <q-card class="login-card">
        <q-card-section class="card-header">
          <h2 class="login-title">Welcome Back</h2>
          <p class="login-subtitle">Sign in to continue to your dashboard</p>
        </q-card-section>

        <q-card-section>
          <q-form @submit.prevent="handleLogin" class="login-form">
            <!-- Job Role Selector (User Request) -->

            <!-- Email Input -->
            <q-input
              v-model="email"
              type="email"
              label="Email Address"
              outlined
              :rules="[
                (val) => !!val || 'Email is required',
                (val) => /.+@.+\..+/.test(val) || 'Enter a valid email',
              ]"
              class="input-field"
            >
              <template v-slot:prepend>
                <q-icon name="mail" color="grey-7" />
              </template>
            </q-input>

            <!-- Password Input -->
            <q-input
              v-model="password"
              :type="showPassword ? 'text' : 'password'"
              label="Password"
              outlined
              :rules="[(val) => !!val || 'Password is required']"
              class="input-field"
            >
              <template v-slot:prepend>
                <q-icon name="lock" color="grey-7" />
              </template>
              <template v-slot:append>
                <q-icon
                  :name="showPassword ? 'visibility_off' : 'visibility'"
                  class="cursor-pointer"
                  @click="showPassword = !showPassword"
                />
              </template>
            </q-input>

            <!-- Error Message -->
            <q-banner
              v-if="authStore.error"
              class="bg-negative text-white q-mb-md"
              rounded
              style="white-space: pre-wrap"
            >
              <template v-slot:avatar>
                <q-icon name="error" color="white" />
              </template>
              {{ authStore.error }}
            </q-banner>

            <!-- Login Button -->
            <q-btn
              type="submit"
              label="Sign In"
              color="primary"
              class="login-btn full-width"
              :loading="authStore.loading"
              unelevated
              size="lg"
            />
          </q-form>
        </q-card-section>
      </q-card>

      <!-- Footer -->
      <p class="footer-text">© 2026 Seven Waves Enterprise. All rights reserved.</p>
    </div>
  </q-page>
</template>

<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from 'src/stores/authStore'

const router = useRouter()
const authStore = useAuthStore()

const email = ref('')
const password = ref('')
const showPassword = ref(false)

async function handleLogin() {
  const result = await authStore.login(email.value, password.value)

  if (result.success) {
    if (result.redirectTo) {
      router.push(result.redirectTo)
    } else {
      router.push('/dashboard')
    }
  }
}
</script>

<style lang="scss" scoped>
.login-page {
  min-height: 100vh;
  background: linear-gradient(135deg, #1a1a2e 0%, #16213e 50%, #0f3460 100%);
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 20px;
}

.login-container {
  width: 100%;
  max-width: 420px;
  text-align: center;
}

.logo-section {
  margin-bottom: 30px;

  .logo-icon {
    width: 100px;
    height: 100px;
    margin: 0 auto 15px;
    border-radius: 50%;
    background: linear-gradient(135deg, $primary, $accent);
    display: flex;
    align-items: center;
    justify-content: center;
    color: white;
    box-shadow: 0 8px 30px rgba(230, 74, 46, 0.4);
  }

  .brand-name {
    font-size: 2rem;
    font-weight: 700;
    color: #ffffff;
    margin: 0;
    letter-spacing: 1px;
  }

  .brand-tagline {
    font-size: 0.9rem;
    color: rgba(255, 255, 255, 0.7);
    margin: 5px 0 0;
  }
}

.login-card {
  background: rgba(255, 255, 255, 0.95);
  border-radius: 16px;
  box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
  backdrop-filter: blur(10px);
  overflow: hidden;
}

.card-header {
  background: linear-gradient(135deg, $primary 0%, $accent 100%);
  padding: 25px;
  text-align: center;

  .login-title {
    font-size: 1.5rem;
    font-weight: 600;
    color: #ffffff;
    margin: 0;
  }

  .login-subtitle {
    font-size: 0.9rem;
    color: rgba(255, 255, 255, 0.85);
    margin: 8px 0 0;
  }
}

.login-form {
  padding: 20px;
}

.input-field {
  margin-bottom: 16px;

  :deep(.q-field__control) {
    border-radius: 10px;
  }
}

.error-banner {
  border-radius: 10px;
}

.login-btn {
  margin-top: 10px;
  border-radius: 10px;
  font-weight: 600;
  letter-spacing: 0.5px;
  height: 50px;

  &:hover {
    transform: translateY(-2px);
    box-shadow: 0 8px 25px rgba(230, 74, 46, 0.4);
  }

  transition: all 0.3s ease;
}

.footer-text {
  margin-top: 30px;
  font-size: 0.8rem;
  color: rgba(255, 255, 255, 0.5);
}
</style>
