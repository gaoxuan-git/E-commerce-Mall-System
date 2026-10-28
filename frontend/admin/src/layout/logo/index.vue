<template>
  <div
    class="layout-logo"
    v-if="themeConfig.layout !== 'columns' && !themeConfig.isCollapse"
    @click="onThemeConfigChange"
  >
    <span class="layout-logo-title">电商网购系统管理后台</span>
  </div>
  <div class="layout-logo-size" v-else @click="onThemeConfigChange">
    <span class="layout-logo-size-title">电商</span>
  </div>
</template>

<script setup>
import { computed } from 'vue';
import { useRouter } from 'vue-router';
import { useThemeConfigStore } from '@/store/modules/themeConfig';

defineOptions({ name: 'layoutLogo' });

const router = useRouter();
const themeConfigStore = useThemeConfigStore();

// 获取布局配置信息
const themeConfig = computed(() => themeConfigStore.themeConfig);
// logo 点击实现菜单展开/收起
function onThemeConfigChange() {
  // if (
  //   themeConfigStore.themeConfig.layout == 'columns' &&
  //   !this.$store.state.user.childMenuList.length &&
  //   themeConfigStore.themeConfig.isCollapse
  // )
  //   return;
  // if (themeConfigStore.themeConfig.layout === 'transverse' || themeConfigStore.themeConfig.layout === 'classic') return false;
  // themeConfigStore.themeConfig.isCollapse = !themeConfigStore.themeConfig.isCollapse;
  router.push(`/dashboard`);
}
</script>

<style scoped lang="scss">
.layout-logo {
  display: flex;
  align-items: center;
  justify-content: center;
  color: var(--prev-color-primary);
  font-size: 16px;
  cursor: pointer;
  animation: logoAnimation 0.3s ease-in-out;
  height: 64px;
  line-height: 64px;
  width: 206px;
  &:hover {
    span {
      opacity: 0.9;
    }
  }
  &-title {
    font-size: 16px;
    line-height: 24px;
    font-weight: 600;
    letter-spacing: 0;
    color: #303133;
  }
}
.layout-logo-size {
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  margin: auto;
  height: 50px;
  width: 100%;
  &-title {
    font-size: 14px;
    line-height: 20px;
    font-weight: 600;
    letter-spacing: 0;
    color: #303133;
    animation: logoAnimation 0.3s ease-in-out;
  }
}
</style>
