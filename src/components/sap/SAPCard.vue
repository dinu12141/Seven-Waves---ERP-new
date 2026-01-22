<template>
  <q-card class="sap-card" :flat="flat" :bordered="bordered">
    <q-card-section class="sap-card-header" v-if="title || $slots.header">
      <slot name="header">
        <div class="sap-card-title">
          <q-icon :name="icon" size="20px" class="q-mr-sm" v-if="icon" />
          <span>{{ title }}</span>
        </div>
        <q-space />
        <slot name="header-right" />
      </slot>
    </q-card-section>

    <q-separator v-if="title || $slots.header" />

    <q-card-section class="sap-card-body" :class="{ 'no-padding': noPadding }">
      <slot />
    </q-card-section>

    <q-separator v-if="$slots.footer" />

    <q-card-section class="sap-card-footer" v-if="$slots.footer">
      <slot name="footer" />
    </q-card-section>
  </q-card>
</template>

<script setup>
defineProps({
  title: {
    type: String,
    default: '',
  },
  icon: {
    type: String,
    default: '',
  },
  flat: {
    type: Boolean,
    default: false,
  },
  bordered: {
    type: Boolean,
    default: true,
  },
  noPadding: {
    type: Boolean,
    default: false,
  },
})
</script>

<style lang="scss" scoped>
.sap-card {
  background: #fff;
  border-radius: 4px;

  &.q-card--bordered {
    border-color: #e0e0e0;
  }
}

.sap-card-header {
  display: flex;
  align-items: center;
  padding: 12px 16px;
  background: #fafafa;
}

.sap-card-title {
  display: flex;
  align-items: center;
  font-size: 14px;
  font-weight: 600;
  color: #333;
}

.sap-card-body {
  padding: 16px;

  &.no-padding {
    padding: 0;
  }
}

.sap-card-footer {
  display: flex;
  align-items: center;
  justify-content: flex-end;
  gap: 8px;
  padding: 12px 16px;
  background: #fafafa;
}
</style>
