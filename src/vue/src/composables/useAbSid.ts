import { ref, onMounted } from 'vue'

export function useAbSid() {
  const sid = ref<string | undefined>(undefined)
  function getCookie(name: string): string | undefined {
    if (typeof document === "undefined") return undefined
    const match = document.cookie.match(new RegExp("(^| )" + name + "=([^;]+)"))
    return match ? decodeURIComponent(match[2]) : undefined
  }
  onMounted(() => {
    sid.value = getCookie("ab_sid")
  })
  return sid
}
