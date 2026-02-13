<template>
  <q-page class="waiter-page q-pa-lg">
    <div class="page-header q-mb-lg">
      <div class="row items-center q-gutter-md">
        <q-icon name="room_service" size="42px" color="primary" />
        <div>
          <h4 class="q-ma-none text-weight-bold">Waiter Dashboard</h4>
          <p class="q-ma-none text-grey-7">Manage tables, take orders, and track service</p>
        </div>
      </div>
    </div>

    <!-- Quick Stats -->
    <div class="row q-col-gutter-md q-mb-lg">
      <div class="col-12 col-sm-6 col-md-3">
        <q-card class="stat-card bg-blue-1">
          <q-card-section class="text-center">
            <q-icon name="table_restaurant" size="36px" color="blue" />
            <div class="text-h5 text-weight-bold q-mt-sm">--</div>
            <div class="text-caption text-grey-7">Assigned Tables</div>
          </q-card-section>
        </q-card>
      </div>
      <div class="col-12 col-sm-6 col-md-3">
        <q-card class="stat-card bg-orange-1">
          <q-card-section class="text-center">
            <q-icon name="pending_actions" size="36px" color="orange" />
            <div class="text-h5 text-weight-bold q-mt-sm">--</div>
            <div class="text-caption text-grey-7">Active Orders</div>
          </q-card-section>
        </q-card>
      </div>
      <div class="col-12 col-sm-6 col-md-3">
        <q-card class="stat-card bg-green-1">
          <q-card-section class="text-center">
            <q-icon name="check_circle" size="36px" color="green" />
            <div class="text-h5 text-weight-bold q-mt-sm">--</div>
            <div class="text-caption text-grey-7">Completed Today</div>
          </q-card-section>
        </q-card>
      </div>
      <div class="col-12 col-sm-6 col-md-3">
        <q-card class="stat-card bg-purple-1">
          <q-card-section class="text-center">
            <q-icon name="restaurant" size="36px" color="purple" />
            <div class="text-h5 text-weight-bold q-mt-sm">--</div>
            <div class="text-caption text-grey-7">Ready to Serve</div>
          </q-card-section>
        </q-card>
      </div>
    </div>

    <!-- Coming Soon Notice -->
    <q-card class="text-center q-pa-xl">
      <q-icon name="construction" size="64px" color="warning" class="q-mb-md" />
      <h5 class="q-ma-none text-weight-bold">Coming Soon</h5>
      <p class="text-grey-7 q-mt-sm">
        The full waiter dashboard with table management, order taking, and kitchen status tracking
        is under development.
      </p>
      <div class="row justify-center q-gutter-sm q-mt-md">
        <q-btn
          label="View Tables"
          icon="table_restaurant"
          color="primary"
          outline
          to="/operations/tables"
        />
        <q-btn
          label="View Orders"
          icon="receipt_long"
          color="primary"
          outline
          to="/operations/orders"
        />
        <q-btn
          label="Kitchen Status"
          icon="soup_kitchen"
          color="primary"
          outline
          to="/operations/kitchen"
        />
      </div>
    </q-card>
  </q-page>
</template>

<script setup>
// Waiter Dashboard - placeholder
</script>

<style scoped>
.waiter-page {
  max-width: 1200px;
  margin: 0 auto;
}

.stat-card {
  border-radius: 12px;
  transition: transform 0.2s ease;
}

.stat-card:hover {
  transform: translateY(-2px);
}
</style>
