<script setup lang="ts">
import { ref, onMounted } from 'vue'
import Conversion from './components/Conversion.vue'
import TestResultList from './components/TestResultList.vue'
import TestResultReport from './components/TestResultReport.vue'
import { useAbSid } from './composables/useAbSid'
import { useTestResults } from './composables/useTestResults'
import { useTestResultReport } from './composables/useTestResultReport'
import { TestResultsService } from './services/TestResultsService'

const sid = useAbSid()
const converted = ref(false)
const refreshCount = ref(0)
const testResult = ref<{ id: number } | null>(null)

const { report, loading: reportLoading, error: reportError } = useTestResultReport(refreshCount)
const { results, loading, error } = useTestResults(sid, refreshCount)

onMounted(async () => {
  if (!sid.value) return
  // Only call once per mount and sid
  try {
    const res = await TestResultsService.create({
      sid: sid.value,
      bucket: "B",
      url: window.location.pathname,
      did_convert: 0,
    })
    testResult.value = res
  } catch (e: any) {
    if (import.meta.env.DEV) {
      // eslint-disable-next-line no-console
      console.warn("Failed to record test result:", e)
    }
  }
})

const handleConvert = async () => {
  if (!sid.value) {
    alert("No session ID found.")
    return
  }
  if (!testResult.value || !testResult.value.id) {
    alert("No test result record found to update.")
    return
  }
  try {
    const updated = await TestResultsService.updateById(testResult.value.id, {
      sid: sid.value,
      bucket: "B",
      url: window.location.pathname,
      did_convert: 1,
    })
    testResult.value = updated
    converted.value = true
    refreshCount.value++
  } catch (e) {
    alert("Failed to record conversion.")
    console.error(e)
  }
}
</script>

<template>
  <div class="flex justify-center items-center gap-8 my-8">
    <a href="https://vite.dev" target="_blank">
      <img src="./assets/vite.svg" class="logo" alt="Vite logo" />
    </a>
    <a href="https://vuejs.org/" target="_blank">
      <img src="./assets/vue.svg" class="logo vue" alt="Vue logo" />
    </a>
  </div>

  <Conversion :label="converted ? 'Conversion recorded!' : 'Buy Me'" :disabled="converted" @convert="handleConvert" />

  <div class="w-full max-w-2xl bg-slate-900">
    <h3 class="text-lg font-bold mb-2 mt-8 text-gray-400">Test Result Report</h3>
    <div v-if="reportLoading" class="text-gray-500">Loading summary…</div>
    <div v-else-if="reportError" class="text-red-500">Error: {{ reportError }}</div>
    <TestResultReport v-else :report="report" />
  </div>

  <div class="w-full max-w-2xl mt-8 bg-slate-900 border-t border-gray-300 pt-8">
    <h2 class="text-xl font-semibold mb-4 text-gray-400">Test Result Records</h2>
    <div v-if="loading" class="text-gray-500">Loading test results…</div>
    <div v-else-if="error" class="text-red-500">Error: {{ error }}</div>
    <TestResultList v-else :results="results" />
  </div>
</template>

<style scoped>
.logo {
  height: 6em;
  padding: 1.5em;
  will-change: filter;
  transition: filter 300ms;
}

.logo:hover {
  filter: drop-shadow(0 0 2em #646cffaa);
}

.logo.vue:hover {
  filter: drop-shadow(0 0 2em #42b883aa);
}
</style>
