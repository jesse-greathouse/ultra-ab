<script setup lang="ts">
import type { TestResult } from '../services/TestResultsService'
import TestResultLine from './TestResultLine.vue'
defineProps<{ results: TestResult[] }>()
</script>

<template>
  <div>
    <div class="grid grid-cols-6 gap-2 px-2 py-2 bg-slate-800 text-gray-100 font-semibold text-xs sm:text-sm border-b">
      <div>ID</div>
      <div>Session</div>
      <div>Bucket</div>
      <div>URL</div>
      <div>Converted?</div>
      <div>Date</div>
    </div>
    <TestResultLine v-for="result in results" :key="result.id" :result="result" />
  </div>
</template>
