<template>
  <div class="sap-toolbar">
    <div class="sap-toolbar-left">
      <slot name="left">
        <q-btn
          v-if="showBack"
          flat
          dense
          icon="arrow_back"
          class="sap-toolbar-btn"
          @click="$emit('back')"
        >
          <q-tooltip>Go Back</q-tooltip>
        </q-btn>
        <div class="sap-toolbar-title" v-if="title">
          <q-icon :name="icon" size="22px" class="q-mr-sm" v-if="icon" />
          <span>{{ title }}</span>
          <q-badge v-if="badge" :color="badgeColor" class="q-ml-sm">
            {{ badge }}
          </q-badge>
        </div>
      </slot>
    </div>

    <div class="sap-toolbar-center">
      <slot name="center" />
    </div>

    <div class="sap-toolbar-right">
      <slot name="right" />
      <template v-if="showActions">
        <q-btn
          v-if="showAdd"
          dense
          color="primary"
          icon="add"
          :label="addLabel"
          class="sap-toolbar-btn-primary"
          @click="$emit('add')"
        />
        <q-btn
          v-if="showRefresh"
          flat
          dense
          icon="refresh"
          class="sap-toolbar-btn"
          @click="$emit('refresh')"
        >
          <q-tooltip>Refresh</q-tooltip>
        </q-btn>
        <q-btn
          v-if="showExport"
          flat
          dense
          icon="download"
          class="sap-toolbar-btn"
          @click="$emit('export')"
        >
          <q-tooltip>Export</q-tooltip>
        </q-btn>
        <q-btn
          v-if="showFilter"
          flat
          dense
          icon="filter_list"
          class="sap-toolbar-btn"
          @click="$emit('filter')"
        >
          <q-tooltip>Filter</q-tooltip>
        </q-btn>
      </template>
    </div>
  </div>
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
  badge: {
    type: [String, Number],
    default: '',
  },
  badgeColor: {
    type: String,
    default: 'primary',
  },
  showBack: {
    type: Boolean,
    default: false,
  },
  showActions: {
    type: Boolean,
    default: true,
  },
  showAdd: {
    type: Boolean,
    default: true,
  },
  addLabel: {
    type: String,
    default: 'Add New',
  },
  showRefresh: {
    type: Boolean,
    default: true,
  },
  showExport: {
    type: Boolean,
    default: false,
  },
  showFilter: {
    type: Boolean,
    default: false,
  },
})

defineEmits(['back', 'add', 'refresh', 'export', 'filter'])
</script>

<style lang="scss" scoped>
.sap-toolbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 12px 16px;
  background: #fff;
  border-bottom: 1px solid #e0e0e0;
  gap: 16px;
}

.sap-toolbar-left,
.sap-toolbar-right {
  display: flex;
  align-items: center;
  gap: 8px;
}

.sap-toolbar-center {
  flex: 1;
  display: flex;
  justify-content: center;
}

.sap-toolbar-title {
  display: flex;
  align-items: center;
  font-size: 16px;
  font-weight: 600;
  color: #333;
}

.sap-toolbar-btn {
  color: #666;

  &:hover {
    color: $primary;
  }
}

.sap-toolbar-btn-primary {
  font-size: 12px;
  padding: 6px 16px;
}
</style>
