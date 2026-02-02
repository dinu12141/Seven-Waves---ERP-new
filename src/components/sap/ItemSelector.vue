<template>
  <SAPSelect
    v-bind="$attrs"
    :model-value="modelValue"
    @update:model-value="onUpdate"
    :options="options"
    option-label="item_name"
    option-value="item_code"
    :searchable="true"
    :loading="loading"
    @filter="filterItems"
    class="item-selector"
  >
    <template v-slot:option="scope">
      <q-item v-bind="scope.itemProps" class="sap-select-option">
        <q-item-section>
          <q-item-label class="text-weight-bold">{{ scope.opt.item_code }}</q-item-label>
          <q-item-label caption lines="1">{{ scope.opt.item_name }}</q-item-label>
        </q-item-section>
        <q-item-section side v-if="scope.opt.warehouse_stock">
          <q-badge color="positive" outline>
            {{ getStock(scope.opt) }}
          </q-badge>
        </q-item-section>
      </q-item>
    </template>

    <template v-for="(_, slot) in $slots" :key="slot" v-slot:[slot]="scope">
      <slot :name="slot" v-bind="scope" />
    </template>

    <template v-slot:selected-item="scope">
      <span
        v-if="scope.opt"
        class="row items-center cursor-pointer"
        @click.stop="openItem(scope.opt)"
      >
        <span class="text-primary text-weight-bold q-mr-xs">{{ scope.opt.item_code }}</span>
        <span class="text-grey-8">- {{ scope.opt.item_name }}</span>
        <q-icon name="open_in_new" size="xs" color="primary" class="q-ml-sm" />
      </span>
    </template>
  </SAPSelect>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useStockStore } from 'src/stores/stockStore'
import SAPSelect from './SAPSelect.vue'

defineProps({
  modelValue: {
    type: String,
    default: null,
  },
  params: {
    type: Object,
    default: () => ({}),
  },
})

const emit = defineEmits(['update:modelValue', 'item-selected'])

const stockStore = useStockStore()
const router = useRouter()
const options = ref([])
const loading = ref(false)

onMounted(async () => {
  if (stockStore.items.length === 0) {
    loading.value = true
    await stockStore.fetchItems()
    loading.value = false
  }
  options.value = stockStore.activeItems
})

function filterItems(val, update) {
  if (val === '') {
    update(() => {
      options.value = stockStore.activeItems
    })
    return
  }

  update(() => {
    const needle = val.toLowerCase()
    options.value = stockStore.activeItems.filter(
      (v) =>
        v.item_code.toLowerCase().includes(needle) || v.item_name.toLowerCase().includes(needle),
    )
  })
}

function onUpdate(val) {
  emit('update:modelValue', val)
  const item = stockStore.items.find((i) => i.item_code === val)
  if (item) {
    emit('item-selected', item)
  }
}

function getStock(item) {
  if (!item.warehouse_stock) return 0
  return item.warehouse_stock.reduce((sum, s) => sum + (s.quantity_on_hand || 0), 0)
}

function openItem(item) {
  // Deep linking to Item Master
  // Assuming route is /stock/items?code=ITEMCODE or similar
  // For now, we'll emit an event or navigate if possible
  // Ideally this opens the item dialog in the Items Page or navigates there
  router.push({ path: '/stock/items', query: { code: item.item_code } })
}
</script>

<style scoped>
.item-selector {
  width: 100%;
}
</style>
