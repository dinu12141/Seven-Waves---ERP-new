<template>
  <q-page class="page-placeholder">
    <div class="page-header">
      <h1 class="page-title">{{ title }}</h1>
      <p class="page-subtitle">{{ subtitle }}</p>
    </div>
    <q-card class="coming-soon-card">
      <q-card-section class="text-center">
        <q-icon :name="icon" size="80px" color="grey-4" />
        <h3>Coming Soon</h3>
        <p>This module is under development</p>
      </q-card-section>
    </q-card>
  </q-page>
</template>

<script setup>
defineProps({
  title: { type: String, default: 'Page Title' },
  subtitle: { type: String, default: '' },
  icon: { type: String, default: 'construction' },
})
</script>

<style lang="scss" scoped>
.page-placeholder {
  padding: 24px;
}

.page-header {
  margin-bottom: 30px;

  .page-title {
    font-size: 1.8rem;
    font-weight: 700;
    color: #1a1a2e;
    margin: 0;
  }

  .page-subtitle {
    color: #666;
    margin: 5px 0 0;
  }
}

.coming-soon-card {
  max-width: 400px;
  margin: 50px auto;
  border-radius: 16px;

  h3 {
    margin: 20px 0 10px;
    color: #1a1a2e;
  }

  p {
    color: #666;
    margin: 0;
  }
}
</style>
