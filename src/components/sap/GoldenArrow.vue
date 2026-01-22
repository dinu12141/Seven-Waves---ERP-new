<template>
  <q-icon
    name="arrow_forward"
    class="golden-arrow cursor-pointer q-ml-xs"
    color="orange-8"
    size="xs"
    @click.stop="$emit('click')"
  >
    <q-tooltip>View Record Details</q-tooltip>
  </q-icon>
</template>

<style scoped>
.golden-arrow {
  transition: transform 0.2s ease;
  transform: rotate(-45deg); /* Angled up-right like SAP */
}
.golden-arrow:hover {
  transform: rotate(-45deg) scale(1.2);
}
</style>
