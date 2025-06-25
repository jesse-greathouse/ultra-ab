import { ref, watch } from 'vue'
import type { Ref } from 'vue'
import { TestResultsService, type TestResult } from '../services/TestResultsService'

export function useTestResults(sid: Ref<string | undefined>, refreshTrigger?: any) {
  const results = ref<TestResult[]>([])
  const loading = ref(false)
  const error = ref<string | null>(null)

  watch(
    () => [sid.value, refreshTrigger && refreshTrigger.value],
    async () => {
      if (!sid.value) {
        results.value = []
        loading.value = false
        error.value = null
        return
      }
      loading.value = true
      error.value = null
      try {
        results.value = await TestResultsService.fetchBySid(sid.value)
      } catch (e: any) {
        error.value = e.message
      } finally {
        loading.value = false
      }
    },
    { immediate: true }
  )

  return { results, loading, error }
}
