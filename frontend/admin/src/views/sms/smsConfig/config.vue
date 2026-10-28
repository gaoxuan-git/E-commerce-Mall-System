<template>
  <div>
    <el-result v-if="isDev" icon="success" title="本地模拟服务运行中" />
    <iframe
      v-else-if="onePassUrl"
      ref="iframesRef"
      :src="onePassUrl"
      width="100%"
      :height="iframeHeight"
      style="border: none"
    ></iframe>
    <el-empty v-else description="服务未配置" />
  </div>
</template>

<script setup>
import { ref, onMounted, onBeforeUnmount, getCurrentInstance, nextTick } from 'vue';

defineOptions({ name: 'SmsConfig' });

const { proxy } = getCurrentInstance();

const iframeHeight = ref(0);
const isDev = import.meta.env.DEV;
const configuredUrl = import.meta.env.VITE_ONE_PASS_URL || '';
const onePassUrl = configuredUrl || 'https://api.crmeb.com/';

function handleResize() {
  iframeHeight.value = proxy.$selfUtil.getTableHeight(0);
}

if (!isDev) {
  window.addEventListener('resize', handleResize);
}

onMounted(() => {
  if (isDev) return;
  nextTick(() => {
    iframeHeight.value = proxy.$selfUtil.getTableHeight(0);
  });
});

onBeforeUnmount(() => {
  if (!isDev) {
    window.removeEventListener('resize', handleResize);
  }
});
</script>
