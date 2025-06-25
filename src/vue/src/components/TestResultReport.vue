<script setup lang="ts">
import type { TestResultReport } from '../services/TestResultsService'
import TestResultReportLine from './TestResultReportLine.vue'
defineProps<{ report: TestResultReport }>()
</script>

<template>
  <div>
    <div class="grid grid-cols-3 gap-2 px-2 py-2 bg-slate-800 font-semibold text-xs sm:text-sm border-b">
      <div>Bucket</div>
      <div>Total Sessions</div>
      <div>Total Conversions</div>
    </div>
    <TestResultReportLine v-for="line in report" :key="line.bucket" :line="line" />
  </div>
</template>
