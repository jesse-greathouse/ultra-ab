<script setup lang="ts">
import type { TestResultReportLine } from '../services/TestResultsService'
defineProps<{ line: TestResultReportLine }>()
</script>
<template>
  <div class="grid grid-cols-3 gap-2 px-2 py-1 border-b text-xs sm:text-sm">
    <div>{{ line.bucket }}</div>
    <div>{{ line.total_sessions }}</div>
    <div>{{ line.total_conversions }}</div>
  </div>
</template>
