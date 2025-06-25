<script setup lang="ts">
import type { TestResult } from '../services/TestResultsService'
defineProps<{ result: TestResult }>()
</script>
<template>
  <div class="grid grid-cols-6 gap-2 px-2 py-1 border-b text-xs sm:text-sm">
    <div>{{ result.id }}</div>
    <div>{{ result.sid }}</div>
    <div>{{ result.bucket }}</div>
    <div>{{ result.url }}</div>
    <div>{{ result.did_convert === 1 ? "Yes" : "No" }}</div>
    <div>{{ result.created_at ? new Date(result.created_at).toLocaleString() : "" }}</div>
  </div>
</template>
