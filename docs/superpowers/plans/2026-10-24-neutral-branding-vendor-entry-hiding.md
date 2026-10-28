# Neutral Branding And Vendor Entry Hiding Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace visible CRMEB/version/enterprise promotion with neutral mall wording and hide vendor-only navigation entries without deleting their routes, pages, APIs, or permissions.

**Architecture:** Keep business behavior intact and make all hiding presentation-only. A small pure utility recursively filters vendor menu components before either Pinia store consumes the menu API, while view components replace or suppress visible vendor branding.

**Tech Stack:** Vue 3, Pinia, Vite, Vitest, uni-app, Playwright

---

## File Map

- Create `frontend/admin/src/utils/menuVisibility.js`: single source of truth for vendor-only menu component paths and recursive filtering.
- Create `frontend/admin/tests/unit/utils/menuVisibility.spec.js`: proves nested filtering, data preservation, and non-mutation.
- Modify `frontend/admin/src/store/modules/user.js`: filter raw menu API data before sidebar/local-storage use.
- Modify `frontend/admin/src/store/modules/permission.js`: apply the same filter before permission route formatting.
- Modify `frontend/admin/src/views/login/index.vue`: replace branded carousel/logo/footer with a neutral login introduction.
- Modify `frontend/admin/src/utils/get-page-title.js`: force the neutral browser title.
- Modify `frontend/admin/src/views/dashboard/index.vue`: neutral welcome text.
- Modify `frontend/admin/src/components/copyright/index.vue`: neutral footer text without company/version data.
- Modify `frontend/admin/src/views/design/my_theme/index.vue`: remove only the external theme-market promotion.
- Modify `frontend/uni-app/pages/user/index.vue`: suppress the vendor copyright image and its display-only loading.
- Modify `frontend/uni-app/manifest.json`: neutral application name and description.
- Modify `frontend/uni-app/pages.json`: neutral H5 authorization page title.
- Modify `frontend/uni-app/components/pay-simulator/index.vue`: neutral fallback merchant name.

### Task 1: Add Tested Vendor Menu Filtering

**Files:**
- Create: `frontend/admin/src/utils/menuVisibility.js`
- Create: `frontend/admin/tests/unit/utils/menuVisibility.spec.js`
- Modify: `frontend/admin/src/store/modules/user.js`
- Modify: `frontend/admin/src/store/modules/permission.js`

- [ ] **Step 1: Write the failing utility tests**

```js
import { describe, expect, it } from 'vitest';
import { filterVendorMenus } from '@/utils/menuVisibility';

describe('filterVendorMenus', () => {
  it('removes vendor entries recursively while retaining business siblings', () => {
    const input = [
      {
        component: '/operation',
        childList: [
          { component: '/operation/setting', childList: [] },
          { component: '/operation/onePassConfig', childList: [] },
          { component: '/operation/systemSms/pay', childList: [] },
        ],
      },
      {
        component: '/appSetting',
        childList: [
          { component: '/appSetting/publicRoutine/download', childList: [] },
          { component: '/appSetting/publicRoutine/deliveryManagement', childList: [] },
        ],
      },
    ];

    const result = filterVendorMenus(input);

    expect(result[0].childList.map((item) => item.component)).toEqual(['/operation/setting']);
    expect(result[1].childList.map((item) => item.component)).toEqual([
      '/appSetting/publicRoutine/deliveryManagement',
    ]);
    expect(input[0].childList).toHaveLength(3);
  });

  it('supports menu trees already converted to children', () => {
    const result = filterVendorMenus([
      {
        component: '/operation',
        children: [
          { component: '/operation/onePassConfig', children: [] },
          { component: '/operation/logistics/freightSet', children: [] },
        ],
      },
    ]);

    expect(result[0].children.map((item) => item.component)).toEqual([
      '/operation/logistics/freightSet',
    ]);
  });
});
```

- [ ] **Step 2: Run the focused test and verify it fails**

Run:

```bash
cd frontend/admin
npm run test:unit -- tests/unit/utils/menuVisibility.spec.js
```

Expected: FAIL because `@/utils/menuVisibility` does not exist.

- [ ] **Step 3: Implement the recursive, non-mutating filter**

```js
const HIDDEN_VENDOR_COMPONENTS = new Set([
  '/operation/onePassConfig',
  '/operation/systemSms/pay',
  '/appSetting/publicRoutine/download',
]);

export function filterVendorMenus(items = []) {
  return items
    .filter((item) => !HIDDEN_VENDOR_COMPONENTS.has(item.component))
    .map((item) => {
      const next = { ...item };
      if (Array.isArray(item.childList)) {
        next.childList = filterVendorMenus(item.childList);
      }
      if (Array.isArray(item.children)) {
        next.children = filterVendorMenus(item.children);
      }
      return next;
    });
}
```

Import `filterVendorMenus` in both stores. In `user.js`, filter immediately after `menuListApi()` and before `replaceChildListWithChildren()`. In `permission.js`, filter immediately after `menuListApi()` and before `formatRoutes()`.

```js
import { filterVendorMenus } from '@/utils/menuVisibility';

let accessRoutes = filterVendorMenus(await roleApi.menuListApi());
accessRoutes = replaceChildListWithChildren(accessRoutes);
```

```js
import { filterVendorMenus } from '@/utils/menuVisibility';

let menusAll = filterVendorMenus(await roleApi.menuListApi());
menusAll = formatRoutes(menusAll);
```

- [ ] **Step 4: Run unit tests**

Run:

```bash
cd frontend/admin
npm run test:unit -- tests/unit/utils/menuVisibility.spec.js
```

Expected: 2 tests PASS.

- [ ] **Step 5: Commit the menu filtering unit**

```bash
git add frontend/admin/src/utils/menuVisibility.js \
  frontend/admin/tests/unit/utils/menuVisibility.spec.js \
  frontend/admin/src/store/modules/user.js \
  frontend/admin/src/store/modules/permission.js
git commit -m "fix: hide vendor-only admin menu entries"
```

### Task 2: Neutralize Admin Branding

**Files:**
- Modify: `frontend/admin/src/views/login/index.vue`
- Modify: `frontend/admin/src/utils/get-page-title.js`
- Modify: `frontend/admin/src/views/dashboard/index.vue`
- Modify: `frontend/admin/src/components/copyright/index.vue`
- Modify: `frontend/admin/src/views/design/my_theme/index.vue`

- [ ] **Step 1: Replace the login carousel and image logo**

Replace the desktop swiper block with:

```vue
<div v-if="fullWidth > 768" class="login-intro">
  <div class="login-intro__eyebrow">MALL OPERATIONS</div>
  <div class="login-intro__title">商城管理后台</div>
  <div class="login-intro__desc">商品、订单与用户运营</div>
</div>
```

Replace the logo image with:

```vue
<div class="page-account-top-title">商城管理后台</div>
```

Remove the login footer block, Swiper imports, `swiperModules`, `swiperList`, `loginLogo`, `companyName`, `version`, and their assignments. Keep `getLoginPicApi()` only for `backgroundImage` and write `商城管理后台` to `singleAdminSiteName`.

Style `.login-intro` as a fixed `286px` desktop panel using the existing page background, stable dimensions, white text, and no promotional claims. Adjust border radii without changing the 670px desktop container or 384px mobile form.

```scss
.login-intro {
  width: 286px;
  height: 400px;
  flex: 0 0 286px;
  padding: 56px 32px;
  box-sizing: border-box;
  color: #fff;
  background: rgba(12, 31, 103, 0.72);
  border-radius: 6px 0 0 6px;

  &__eyebrow {
    margin-top: 96px;
    font-size: 12px;
    line-height: 20px;
  }

  &__title {
    margin-top: 12px;
    font-size: 28px;
    line-height: 40px;
    font-weight: 600;
  }

  &__desc {
    margin-top: 12px;
    font-size: 14px;
    line-height: 22px;
  }
}

.page-account-top-title {
  font-size: 24px;
  line-height: 34px;
  font-weight: 600;
  color: #303133;
}
```

- [ ] **Step 2: Replace remaining visible admin defaults**

Use these exact strings:

```js
const title = '商城管理后台';
```

```vue
<div class="welcome-desc">欢迎使用商城管理后台，祝您工作愉快！</div>
```

Render `商城管理后台` in the copyright component without requesting company/version data:

```vue
<template>
  <div class="ivu-global-footer i-copyright">
    <div class="footers acea-row">
      <div class="title">商城管理后台</div>
    </div>
  </div>
</template>

<script setup>
defineOptions({ name: 'i-copyright' });
</script>
```

- [ ] **Step 3: Remove only the external theme-market promotion**

Delete the external market `<img>` from the action bar, its `themeMarketImage` import, the `toTheme()` function, and now-unused `.theme-in` styles. Keep new theme, import, export, edit, use, and delete behavior unchanged.

- [ ] **Step 4: Build and scan the admin source**

Run:

```bash
cd frontend/admin
npm run build
grep -RniE 'JAVA[[:space:]]*开源版|CRMEB-JAVA-KY|欢迎使用 CRMEB|crmeb.com/theme' src \
  --exclude-dir=styles
```

Expected: build succeeds; grep returns no rendered branding or theme-market link. Source license comments may still match generic CRMEB searches and are intentionally retained.

- [ ] **Step 5: Commit admin presentation changes**

```bash
git add frontend/admin/src/views/login/index.vue \
  frontend/admin/src/utils/get-page-title.js \
  frontend/admin/src/views/dashboard/index.vue \
  frontend/admin/src/components/copyright/index.vue \
  frontend/admin/src/views/design/my_theme/index.vue
git commit -m "fix: neutralize visible admin branding"
```

### Task 3: Neutralize H5 Branding

**Files:**
- Modify: `frontend/uni-app/pages/user/index.vue`
- Modify: `frontend/uni-app/manifest.json`
- Modify: `frontend/uni-app/pages.json`
- Modify: `frontend/uni-app/components/pay-simulator/index.vue`

- [ ] **Step 1: Suppress the personal-center vendor image**

Remove the `<image class="support">` element, `copyRightPicSrc` import, `copyRightPic` state, and the `loginConfigApi()` call that only loads `companyImage`. Retain the rest of `onLoad()` unchanged.

Apply this focused diff:

```diff
-    <image :src="copyRightPic" alt="" class="support"></image>
     <pageFooter :style="colorStyle"></pageFooter>

-import { getThemeInfo, loginConfigApi } from "@/api/api.js";
+import { getThemeInfo } from "@/api/api.js";

-import copyRightPicSrc from "@/static/images/support.png";

-const copyRightPic = ref(copyRightPicSrc);

 onLoad((option) => {
   uni.hideTabBar();
   applyTheme(uni.getStorageSync("previewThemeId") || "").catch(() => {});
-  loginConfigApi()
-    .then((res) => {
-      const companyImage = (res.data || {}).companyImage;
-      if (companyImage) copyRightPic.value = companyImage;
-    })
-    .catch(() => {});
   // #ifdef MP
```

- [ ] **Step 2: Replace visible H5 defaults**

Apply these exact values:

```json
"name": "商城系统",
"description": "商城系统"
```

```json
"navigationBarTitleText": "商城系统"
```

```vue
<view class="merchant">{{ merchant || '商城系统' }}</view>
```

- [ ] **Step 3: Build and scan H5**

Run:

```bash
cd frontend/uni-app
npm run build:h5
grep -RniE 'JAVA[[:space:]]*开源版|CRMEB-JAVA-KY|CRMEB 商城|众邦科技版权所有' \
  pages components manifest.json pages.json \
  --exclude-dir=node_modules
```

Expected: build succeeds; grep returns no rendered matches. Comments mentioning the upstream license are allowed.

- [ ] **Step 4: Commit H5 presentation changes**

```bash
git add frontend/uni-app/pages/user/index.vue \
  frontend/uni-app/manifest.json \
  frontend/uni-app/pages.json \
  frontend/uni-app/components/pay-simulator/index.vue
git commit -m "fix: neutralize visible h5 branding"
```

### Task 4: Browser Regression And Route Preservation

**Files:**
- Verify only; no planned source changes.

- [ ] **Step 1: Start or confirm all local services**

Confirm MySQL `3306`, Redis `6379`, admin API `8080`, front API `8081`, admin UI `9527`, and H5 `5273`.

- [ ] **Step 2: Verify the admin login page**

Open `http://127.0.0.1:9527/login`.

Expected:

- “商城管理后台” is visible.
- The old carousel image, CRMEB logo, company text, and version are absent.
- Username/password inputs and login button work.

- [ ] **Step 3: Verify dashboard and navigation**

Log in with the configured local administrator.

Expected:

- Browser title and welcome message use “商城管理后台”.
- 一号通配置, 短信购买, and 小程序下载 are absent from navigation/search.
- Theme management remains available, but no CRMEB theme-market button is visible.

- [ ] **Step 4: Verify hidden routes remain functional**

Navigate directly to:

```text
/operation/onePassConfig
/operation/systemSms/pay
/appSetting/publicRoutine/download
```

Expected: routes still resolve to their existing components or existing authorization/configuration state; no 404 caused by this change.

- [ ] **Step 5: Verify H5 personal center**

Open `http://127.0.0.1:5273/pages/user/index` at a mobile viewport.

Expected: personal center renders normally and the CRMEB/众邦 copyright image is absent.

- [ ] **Step 6: Run focused and existing regression tests**

Run:

```bash
cd frontend/admin
npm run test:unit

cd ../../tests/e2e
E2E_USER_ACCOUNT=13000000000 \
E2E_USER_PASSWORD='crmeb@123456' \
E2E_SECOND_USER_ACCOUNT=13000000000 \
E2E_SECOND_USER_PASSWORD='crmeb@123456' \
npx playwright test --project=admin-desktop --grep @smoke
```

Expected: admin unit tests and admin smoke tests pass. Report any unrelated pre-existing failure separately rather than weakening assertions.
