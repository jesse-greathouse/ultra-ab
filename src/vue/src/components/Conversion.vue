<script setup lang="ts">
defineProps<{
  label?: string
  disabled?: boolean
}>()
const emit = defineEmits(['convert'])
</script>
<template>
  <div class="flex flex-col items-center my-8">
    <button @click="$emit('convert')" :disabled="disabled"
      class="bg-blue-700 hover:bg-blue-800 text-white text-3xl px-16 py-8 rounded-2xl shadow-2xl font-extrabold mb-2 transition-colors"
      :class="{ 'opacity-50 cursor-not-allowed': disabled }">
      Convert
    </button>
    <span class="text-lg font-medium text-sky-600">{{ label }}</span>
  </div>
</template>
