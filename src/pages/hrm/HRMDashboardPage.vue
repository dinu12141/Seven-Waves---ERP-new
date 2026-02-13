<template>
  <q-page class="hrm-dashboard q-pa-lg">
    <div class="page-header q-mb-lg">
      <div class="row items-center q-gutter-md">
        <q-icon name="groups" size="42px" color="primary" />
        <div>
          <h4 class="q-ma-none text-weight-bold">HRM Dashboard</h4>
          <p class="q-ma-none text-grey-7">Human Resource Management overview</p>
        </div>
      </div>
    </div>

    <!-- Quick Stats -->
    <div class="row q-col-gutter-md q-mb-lg">
      <div class="col-12 col-sm-6 col-md-3">
        <q-card class="stat-card bg-blue-1">
          <q-card-section class="text-center">
            <q-icon name="badge" size="36px" color="blue" />
            <div class="text-h5 text-weight-bold q-mt-sm">--</div>
            <div class="text-caption text-grey-7">Total Employees</div>
          </q-card-section>
        </q-card>
      </div>
      <div class="col-12 col-sm-6 col-md-3">
        <q-card class="stat-card bg-green-1">
          <q-card-section class="text-center">
            <q-icon name="how_to_reg" size="36px" color="green" />
            <div class="text-h5 text-weight-bold q-mt-sm">--</div>
            <div class="text-caption text-grey-7">Present Today</div>
          </q-card-section>
        </q-card>
      </div>
      <div class="col-12 col-sm-6 col-md-3">
        <q-card class="stat-card bg-orange-1">
          <q-card-section class="text-center">
            <q-icon name="event_busy" size="36px" color="orange" />
            <div class="text-h5 text-weight-bold q-mt-sm">--</div>
            <div class="text-caption text-grey-7">On Leave</div>
          </q-card-section>
        </q-card>
      </div>
      <div class="col-12 col-sm-6 col-md-3">
        <q-card class="stat-card bg-red-1">
          <q-card-section class="text-center">
            <q-icon name="pending_actions" size="36px" color="red" />
            <div class="text-h5 text-weight-bold q-mt-sm">--</div>
            <div class="text-caption text-grey-7">Pending Requests</div>
          </q-card-section>
        </q-card>
      </div>
    </div>

    <!-- Quick Links -->
    <q-card class="text-center q-pa-xl">
      <q-icon name="construction" size="64px" color="warning" class="q-mb-md" />
      <h5 class="q-ma-none text-weight-bold">Coming Soon</h5>
      <p class="text-grey-7 q-mt-sm">
        The full HRM dashboard with employee analytics, attendance tracking, and leave management is
        under development.
      </p>
      <div class="row justify-center q-gutter-sm q-mt-md">
        <q-btn label="Employees" icon="people" color="primary" outline to="/hrm/employees" />
        <q-btn label="Attendance" icon="fact_check" color="primary" outline to="/hrm/attendance" />
        <q-btn label="Leaves" icon="event_busy" color="primary" outline to="/hrm/leaves" />
        <q-btn label="Salary" icon="payments" color="primary" outline to="/hrm/salary" />
      </div>
    </q-card>
  </q-page>
</template>

<script setup>
// HRM Dashboard - placeholder
</script>

<style scoped>
.hrm-dashboard {
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
