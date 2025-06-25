import { ref, watch } from 'vue'
import { TestResultsService, type TestResultReport } from '../services/TestResultsService'

export function useTestResultReport(refreshCount: any = 0) {
  const report = ref<TestResultReport>([])
  const loading = ref(true)
  const error = ref<string | null>(null)

  watch(
    () => (refreshCount && refreshCount.value !== undefined ? refreshCount.value : refreshCount),
    async () => {
      loading.value = true
      error.value = null
      try {
        report.value = await TestResultsService.getReport()
      } catch (e: any) {
        error.value = e.message
      } finally {
        loading.value = false
      }
    },
    { immediate: true }
  )

  return { report, loading, error }
}
