<template>
  <q-dialog
    :model-value="modelValue"
    @update:model-value="$emit('update:modelValue', $event)"
    :persistent="persistent"
    :maximized="maximized"
  >
    <q-card class="sap-dialog" :style="{ width: width, minWidth: minWidth }">
      <!-- Header -->
      <q-card-section class="sap-dialog-header">
        <div class="sap-dialog-title">
          <q-icon :name="icon" size="22px" class="q-mr-sm" v-if="icon" />
          <span>{{ title }}</span>
        </div>
        <q-space />
        <q-btn
          v-if="showClose"
          flat
          dense
          round
          icon="close"
          size="sm"
          @click="$emit('update:modelValue', false)"
        />
      </q-card-section>

      <q-separator />

      <!-- Body -->
      <q-card-section class="sap-dialog-body">
        <slot />
      </q-card-section>

      <!-- Footer -->
      <q-separator v-if="$slots.footer || showDefaultFooter" />

      <q-card-section class="sap-dialog-footer" v-if="$slots.footer || showDefaultFooter">
        <slot name="footer">
          <q-btn
            flat
            dense
            :label="cancelLabel"
            class="sap-dialog-btn"
            @click="$emit('update:modelValue', false)"
          />
          <q-btn
            dense
            color="primary"
            :label="confirmLabel"
            :loading="loading"
            class="sap-dialog-btn"
            @click="$emit('confirm')"
          />
        </slot>
      </q-card-section>
    </q-card>
  </q-dialog>
</template>

<script setup>
defineProps({
  modelValue: {
    type: Boolean,
    default: false,
  },
  title: {
    type: String,
    default: '',
  },
  icon: {
    type: String,
    default: '',
  },
  width: {
    type: String,
    default: '600px',
  },
  minWidth: {
    type: String,
    default: '400px',
  },
  persistent: {
    type: Boolean,
    default: false,
  },
  maximized: {
    type: Boolean,
    default: false,
  },
  showClose: {
    type: Boolean,
    default: true,
  },
  showDefaultFooter: {
    type: Boolean,
    default: true,
  },
  confirmLabel: {
    type: String,
    default: 'Save',
  },
  cancelLabel: {
    type: String,
    default: 'Cancel',
  },
  loading: {
    type: Boolean,
    default: false,
  },
})

defineEmits(['update:modelValue', 'confirm'])
</script>

<style lang="scss" scoped>
.sap-dialog {
  max-width: 90vw;
  max-height: 90vh;
  display: flex;
  flex-direction: column;
}

.sap-dialog-header {
  display: flex;
  align-items: center;
  padding: 12px 16px;
  background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%);
  color: #fff;
}

.sap-dialog-title {
  display: flex;
  align-items: center;
  font-size: 15px;
  font-weight: 600;
}

.sap-dialog-body {
  flex: 1;
  overflow-y: auto;
  padding: 20px;
  max-height: 60vh;
}

.sap-dialog-footer {
  display: flex;
  align-items: center;
  justify-content: flex-end;
  gap: 8px;
  padding: 12px 16px;
  background: #fafafa;
}

.sap-dialog-btn {
  font-size: 12px;
  padding: 6px 20px;
}
</style>
