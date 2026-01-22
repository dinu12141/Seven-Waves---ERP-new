<template>
  <div class="sap-input-wrapper" :class="{ 'sap-input-horizontal': horizontal }">
    <label v-if="label" class="sap-input-label" :class="{ required: required }">
      {{ label }}
    </label>
    <q-input
      v-bind="$attrs"
      :model-value="modelValue"
      @update:model-value="$emit('update:modelValue', $event)"
      dense
      outlined
      lazy-rules
      class="sap-input"
      :class="{ 'sap-input-error': error }"
      :error="error ? true : undefined"
      :error-message="error"
    >
      <template v-slot:prepend v-if="icon">
        <q-icon :name="icon" size="18px" />
      </template>
      <template v-slot:append v-if="clearable && modelValue">
        <q-icon
          name="close"
          size="16px"
          class="cursor-pointer sap-input-clear"
          @click="$emit('update:modelValue', '')"
        />
      </template>
      <template v-for="(_, slot) in $slots" :key="slot" v-slot:[slot]="scope">
        <slot :name="slot" v-bind="scope" />
      </template>
    </q-input>
    <div v-if="hint && !error" class="sap-input-hint">{{ hint }}</div>
  </div>
</template>

<script setup>
defineOptions({
  inheritAttrs: false,
})

defineProps({
  modelValue: {
    type: [String, Number],
    default: '',
  },
  label: {
    type: String,
    default: '',
  },
  icon: {
    type: String,
    default: '',
  },
  hint: {
    type: String,
    default: '',
  },
  error: {
    type: String,
    default: undefined,
  },
  required: {
    type: Boolean,
    default: false,
  },
  clearable: {
    type: Boolean,
    default: false,
  },
  horizontal: {
    type: Boolean,
    default: false,
  },
})

defineEmits(['update:modelValue'])
</script>

<style lang="scss" scoped>
.sap-input-wrapper {
  display: flex;
  flex-direction: column;
  gap: 4px;
  margin-bottom: 12px;

  &.sap-input-horizontal {
    flex-direction: row;
    align-items: center;
    gap: 12px;

    .sap-input-label {
      min-width: 120px;
      margin-bottom: 0;
    }

    .sap-input {
      flex: 1;
    }
  }
}

.sap-input-label {
  font-size: 12px;
  font-weight: 500;
  color: #555;

  &.required::after {
    content: ' *';
    color: $negative;
  }
}

.sap-input {
  :deep(.q-field__control) {
    height: 32px;
    min-height: 32px;
  }

  :deep(.q-field__control:before) {
    border-color: #e0e0e0;
  }

  :deep(.q-field__native) {
    font-size: 12px;
    padding: 4px 8px;
  }

  :deep(.q-field__marginal) {
    height: 32px;
  }

  &.sap-input-error {
    :deep(.q-field__control) {
      border-color: $negative;
    }
  }
}

.sap-input-hint {
  font-size: 10px;
  color: #888;
}

.sap-input-clear {
  color: #999;

  &:hover {
    color: $negative;
  }
}
</style>
