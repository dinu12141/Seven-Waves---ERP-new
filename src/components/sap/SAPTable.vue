<template>
  <q-table
    v-model:selected="selected"
    :rows="rows"
    :columns="columns"
    :row-key="rowKey"
    :loading="loading"
    :filter="filter"
    :pagination="pagination"
    :selection="selection"
    :dense="true"
    :flat="true"
    :bordered="true"
    class="sap-table"
    @row-click="handleRowClick"
    @update:pagination="$emit('update:pagination', $event)"
  >
    <!-- Header Slot -->
    <template v-slot:top v-if="$slots.top || showSearch || title">
      <div class="sap-table-header">
        <div class="sap-table-title" v-if="title">
          <q-icon :name="icon" size="20px" class="q-mr-sm" v-if="icon" />
          {{ title }}
          <q-badge color="primary" class="q-ml-sm" v-if="showCount">
            {{ rows.length }}
          </q-badge>
        </div>
        <q-space />
        <slot name="top-right">
          <q-input
            v-if="showSearch"
            v-model="filter"
            dense
            outlined
            placeholder="Search..."
            class="sap-search-input"
          >
            <template v-slot:prepend>
              <q-icon name="search" size="18px" />
            </template>
          </q-input>
        </slot>
      </div>
    </template>

    <!-- Golden Arrow / Drill-Down Column -->
    <template v-slot:body-cell-actions="props" v-if="showDrillDown">
      <q-td :props="props" class="sap-actions-cell">
        <q-btn
          flat
          dense
          round
          size="sm"
          color="primary"
          icon="arrow_forward_ios"
          class="sap-drill-arrow"
          @click.stop="$emit('drill-down', props.row)"
        >
          <q-tooltip>View Details</q-tooltip>
        </q-btn>
      </q-td>
    </template>

    <!-- Status Column -->
    <template v-slot:body-cell-status="props">
      <q-td :props="props">
        <q-badge
          :color="getStatusColor(props.value)"
          :label="props.value"
          class="sap-status-badge"
        />
      </q-td>
    </template>

    <!-- Currency Column -->
    <template v-slot:body-cell-currency="props">
      <q-td :props="props" class="text-right">
        {{ formatCurrency(props.value) }}
      </q-td>
    </template>

    <!-- Quantity Column -->
    <template v-slot:body-cell-quantity="props">
      <q-td :props="props" class="text-right">
        <span :class="props.value < 0 ? 'text-negative' : ''">
          {{ formatNumber(props.value) }}
        </span>
      </q-td>
    </template>

    <!-- Boolean Column -->
    <template v-slot:body-cell-boolean="props">
      <q-td :props="props" class="text-center">
        <q-icon
          :name="props.value ? 'check_circle' : 'cancel'"
          :color="props.value ? 'positive' : 'grey'"
          size="18px"
        />
      </q-td>
    </template>

    <!-- No Data Slot -->
    <template v-slot:no-data>
      <div class="sap-no-data">
        <q-icon name="inbox" size="48px" color="grey-5" />
        <div class="q-mt-sm text-grey-6">{{ noDataLabel }}</div>
      </div>
    </template>

    <!-- Loading Slot -->
    <template v-slot:loading>
      <q-inner-loading showing color="primary">
        <q-spinner-dots size="40px" color="primary" />
      </q-inner-loading>
    </template>

    <!-- Pass through remaining slots -->
    <template v-for="(_, slot) in $slots" :key="slot" v-slot:[slot]="scope">
      <slot :name="slot" v-bind="scope" />
    </template>
  </q-table>
</template>

<script setup>
import { ref } from 'vue'

const props = defineProps({
  rows: {
    type: Array,
    default: () => [],
  },
  columns: {
    type: Array,
    required: true,
  },
  rowKey: {
    type: String,
    default: 'id',
  },
  loading: {
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
  showSearch: {
    type: Boolean,
    default: true,
  },
  showCount: {
    type: Boolean,
    default: true,
  },
  showDrillDown: {
    type: Boolean,
    default: false,
  },
  selection: {
    type: String,
    default: 'none',
  },
  noDataLabel: {
    type: String,
    default: 'No records found',
  },
  paginationConfig: {
    type: Object,
    default: () => ({ rowsPerPage: 15 }),
  },
})

const emit = defineEmits(['row-click', 'drill-down', 'update:pagination'])

const filter = ref('')
const selected = ref([])
const pagination = ref(props.paginationConfig)

function handleRowClick(evt, row) {
  emit('row-click', row)
}

function getStatusColor(status) {
  const colors = {
    draft: 'grey',
    pending: 'warning',
    approved: 'info',
    completed: 'positive',
    cancelled: 'negative',
    active: 'positive',
    inactive: 'grey',
  }
  return colors[status?.toLowerCase()] || 'primary'
}

function formatCurrency(value) {
  if (value == null) return '—'
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'LKR',
    minimumFractionDigits: 2,
  }).format(value)
}

function formatNumber(value) {
  if (value == null) return '—'
  return new Intl.NumberFormat('en-US', {
    minimumFractionDigits: 0,
    maximumFractionDigits: 3,
  }).format(value)
}
</script>

<style lang="scss" scoped>
.sap-table {
  font-size: 12px;

  :deep(.q-table__top) {
    padding: 8px 12px;
    background: #fafafa;
    border-bottom: 1px solid #e0e0e0;
  }

  :deep(thead tr th) {
    font-size: 11px;
    font-weight: 600;
    text-transform: uppercase;
    color: #333;
    background: #f5f5f5;
    padding: 8px 12px;
    white-space: nowrap;
    border-bottom: 2px solid #ddd;
  }

  :deep(tbody tr td) {
    font-size: 12px;
    padding: 6px 12px;
    border-bottom: 1px solid #eee;
  }

  :deep(tbody tr:hover) {
    background: rgba($primary, 0.04);
  }

  :deep(tbody tr.selected) {
    background: rgba($primary, 0.1);
  }

  :deep(.q-table__bottom) {
    font-size: 11px;
    padding: 6px 12px;
    background: #fafafa;
  }
}

.sap-table-header {
  display: flex;
  align-items: center;
  width: 100%;
  gap: 12px;
}

.sap-table-title {
  display: flex;
  align-items: center;
  font-size: 14px;
  font-weight: 600;
  color: #333;
}

.sap-search-input {
  width: 220px;

  :deep(.q-field__control) {
    height: 32px;
  }

  :deep(.q-field__native) {
    font-size: 12px;
  }
}

.sap-actions-cell {
  width: 40px;
  padding: 4px !important;
}

.sap-drill-arrow {
  transition: transform 0.2s ease;

  &:hover {
    transform: translateX(2px);
    color: $primary;
  }
}

.sap-status-badge {
  font-size: 10px;
  font-weight: 500;
  padding: 2px 8px;
  text-transform: capitalize;
}

.sap-no-data {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 32px;
}
</style>
