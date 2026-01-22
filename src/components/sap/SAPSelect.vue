<template>
  <q-select
    v-bind="$attrs"
    :model-value="modelValue"
    @update:model-value="$emit('update:modelValue', $event)"
    :options="filteredOptions"
    :option-label="optionLabel"
    :option-value="optionValue"
    dense
    outlined
    emit-value
    map-options
    :use-input="searchable"
    :input-debounce="200"
    class="sap-select"
    :class="{ 'sap-select-error': error }"
    :error="error ? true : undefined"
    :error-message="error"
    @filter="onFilter"
  >
    <template v-slot:prepend v-if="icon">
      <q-icon :name="icon" size="18px" />
    </template>

    <template v-slot:no-option>
      <q-item>
        <q-item-section class="text-grey text-body2"> No options available </q-item-section>
      </q-item>
    </template>

    <template v-slot:option="scope">
      <q-item v-bind="scope.itemProps" class="sap-select-option">
        <q-item-section avatar v-if="showOptionIcon">
          <q-icon :name="scope.opt.icon || 'circle'" size="16px" />
        </q-item-section>
        <q-item-section>
          <q-item-label class="sap-option-label">
            {{ getOptionLabel(scope.opt) }}
          </q-item-label>
          <q-item-label caption v-if="getOptionDescription(scope.opt)">
            {{ getOptionDescription(scope.opt) }}
          </q-item-label>
        </q-item-section>
      </q-item>
    </template>

    <template v-for="(_, slot) in $slots" :key="slot" v-slot:[slot]="scope">
      <slot :name="slot" v-bind="scope" />
    </template>
  </q-select>
</template>

<script setup>
import { ref, watch } from 'vue'

defineOptions({
  inheritAttrs: false,
})

const props = defineProps({
  modelValue: {
    type: [String, Number, Object, Array],
    default: null,
  },
  options: {
    type: Array,
    default: () => [],
  },
  optionLabel: {
    type: [String, Function],
    default: 'label',
  },
  optionValue: {
    type: [String, Function],
    default: 'value',
  },
  optionDescription: {
    type: String,
    default: '',
  },
  icon: {
    type: String,
    default: '',
  },
  error: {
    type: String,
    default: undefined,
  },
  searchable: {
    type: Boolean,
    default: false,
  },
  showOptionIcon: {
    type: Boolean,
    default: false,
  },
})

defineEmits(['update:modelValue'])

const filteredOptions = ref(props.options)

watch(
  () => props.options,
  (newVal) => {
    filteredOptions.value = newVal
  },
)

function getOptionLabel(opt) {
  if (typeof props.optionLabel === 'function') {
    return props.optionLabel(opt)
  }
  return typeof opt === 'object' ? opt[props.optionLabel] : opt
}

function getOptionDescription(opt) {
  if (!props.optionDescription || typeof opt !== 'object') return ''
  return opt[props.optionDescription]
}

function onFilter(val, update) {
  if (!props.searchable) {
    update()
    return
  }

  update(() => {
    if (val === '') {
      filteredOptions.value = props.options
    } else {
      const needle = val.toLowerCase()
      filteredOptions.value = props.options.filter((opt) => {
        const label = getOptionLabel(opt)
        return String(label).toLowerCase().includes(needle)
      })
    }
  })
}
</script>

<style lang="scss" scoped>
.sap-select {
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

  &.sap-select-error {
    :deep(.q-field__control) {
      border-color: $negative;
    }
  }
}

.sap-select-option {
  padding: 6px 12px;
  min-height: 32px;
}

.sap-option-label {
  font-size: 12px;
}
</style>
