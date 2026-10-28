# H5 Auth Warm Member Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restyle the existing H5 login and registration page as the approved warm, lightweight membership experience without changing authentication APIs or behavior.

**Architecture:** Keep the existing Vue state and authentication methods intact while replacing only the page template and scoped SCSS. The page will use local text and icon-font assets so it remains complete when the remote login logo or image domain is unavailable.

**Tech Stack:** Vue 3, uni-app, SCSS, existing iconfont, Playwright

---

## File Map

- Modify `frontend/uni-app/pages/users/login/index.vue`: replace the old remote-logo layout, reorganize login/register states, remove display-only state, and apply the approved responsive styling.
- Verify with existing `tests/e2e/specs/h5-route-smoke.spec.mjs`: confirm the guest login route remains healthy.
- Verify with an inline Playwright script: inspect login, registration, and viewport overflow states without adding another permanent test file.

### Task 1: Replace The Authentication Page Structure

**Files:**
- Modify: `frontend/uni-app/pages/users/login/index.vue`

- [ ] **Step 1: Record the current failing visual contract**

Run:

```bash
grep -nE 'mobileLoginLogo|class="shading"|urlDomain.*phone_1|urlDomain.*code_2' \
  frontend/uni-app/pages/users/login/index.vue
```

Expected: the command finds the remote logo and remote field-icon dependencies that the approved design removes.

- [ ] **Step 2: Replace the top-level template with the approved C layout**

Use this structure while retaining the existing `Verify` and App-only third-party login behavior:

```vue
<template>
  <view class="login-wrapper" :data-theme="theme" :style="colorStyle">
    <view class="auth-accent auth-accent--large"></view>
    <view class="auth-accent auth-accent--small"></view>

    <view class="auth-shell">
      <view class="auth-brand">
        <view class="auth-brand__mark">商</view>
        <text class="auth-brand__name">商城系统</text>
      </view>

      <view class="auth-hero">
        <text class="auth-hero__title">
          {{ formItem === 1 ? "回来看看，喜欢的都在" : "第一次见，欢迎加入" }}
        </text>
        <text class="auth-hero__desc">
          {{
            formItem === 1
              ? "订单、收藏和会员权益会在登录后同步"
              : "注册后即可管理订单、收藏与会员权益"
          }}
        </text>
      </view>

      <view class="auth-form">
        <view class="auth-switch" role="tablist">
          <view
            class="auth-switch__item"
            :class="{ active: formItem === 1 }"
            @click="switchAuthMode(1)"
          >
            登录
          </view>
          <view
            class="auth-switch__item"
            :class="{ active: formItem === 2 }"
            @click="switchAuthMode(2)"
          >
            注册
          </view>
        </view>

        <view v-if="formItem === 1" class="auth-method">
          <view
            class="auth-method__item"
            :class="{ active: current === 1 }"
            @click="current = 1"
          >
            验证码登录
          </view>
          <view
            class="auth-method__item"
            :class="{ active: current === 0 }"
            @click="current = 0"
          >
            密码登录
          </view>
        </view>

        <view v-if="formItem === 1 && current === 0" class="auth-fields">
          <view class="auth-field">
            <text class="iconfont icon-shouji auth-field__icon"></text>
            <input
              v-model="account"
              class="auth-field__input"
              type="number"
              maxlength="11"
              placeholder="输入手机号码"
            />
          </view>
          <view class="auth-field">
            <text class="iconfont icon-mima auth-field__icon"></text>
            <input
              v-model="password"
              class="auth-field__input"
              type="password"
              maxlength="18"
              placeholder="填写登录密码"
            />
          </view>
        </view>

        <view
          v-if="formItem === 1 && (current === 1 || appLoginStatus || appleLoginStatus)"
          class="auth-fields"
        >
          <view class="auth-field">
            <text class="iconfont icon-shouji auth-field__icon"></text>
            <input
              v-model="account"
              class="auth-field__input"
              type="number"
              maxlength="11"
              placeholder="输入手机号码"
            />
          </view>
          <view class="auth-field">
            <text class="iconfont icon-yanzhengma auth-field__icon"></text>
            <input
              v-model="captcha"
              class="auth-field__input auth-field__input--code"
              type="number"
              maxlength="6"
              placeholder="填写验证码"
            />
            <button
              class="auth-code main_color"
              :disabled="disabled"
              :class="{ disabled }"
              @click="code"
            >
              {{ text }}
            </button>
          </view>
          <view v-if="isShowCode" class="auth-field">
            <text class="iconfont icon-yanzhengma auth-field__icon"></text>
            <input
              v-model="codeVal"
              class="auth-field__input auth-field__input--code"
              type="number"
              maxlength="6"
              placeholder="填写图形验证码"
            />
            <view class="auth-captcha" @click="again">
              <image class="code-img" :src="codeUrl" />
            </view>
          </view>
        </view>

        <view v-if="formItem === 2" class="auth-fields">
          <view class="auth-field">
            <text class="iconfont icon-shouji auth-field__icon"></text>
            <input
              v-model="account"
              class="auth-field__input"
              type="number"
              maxlength="11"
              placeholder="输入手机号码"
            />
          </view>
          <view class="auth-field">
            <text class="iconfont icon-yanzhengma auth-field__icon"></text>
            <input
              v-model="captcha"
              class="auth-field__input auth-field__input--code"
              type="number"
              maxlength="6"
              placeholder="填写短信验证码"
            />
            <button
              class="auth-code main_color"
              :disabled="disabled"
              :class="{ disabled }"
              @click="code"
            >
              {{ text }}
            </button>
          </view>
          <view class="auth-field">
            <text class="iconfont icon-mima auth-field__icon"></text>
            <input
              v-model="password"
              class="auth-field__input"
              type="password"
              maxlength="18"
              placeholder="设置6-18位登录密码"
            />
          </view>
          <view class="auth-field">
            <text class="iconfont icon-mima auth-field__icon"></text>
            <input
              v-model="confirmPassword"
              class="auth-field__input"
              type="password"
              maxlength="18"
              placeholder="再次输入登录密码"
            />
          </view>
        </view>

        <view class="protocol">
          <checkbox-group class="protocol__group" @change="isAgree = !isAgree">
            <checkbox
              class="protocol__checkbox"
              :checked="isAgree"
              color="#ffffff"
              backgroundColor="#ffffff"
              activeBackgroundColor="var(--view-theme, #ff542e)"
              activeBorderColor="var(--view-theme, #ff542e)"
              iconColor="#ffffff"
            />
            <text class="protocol__text">
              我已阅读并同意
              <text class="font_pro" @click.stop="userAgree('userinfo')">《用户协议》</text>
              和
              <text class="font_pro" @click.stop="userAgree('userprivacyinfo')">《隐私政策》</text>
            </text>
          </checkbox-group>
        </view>

        <view
          v-if="formItem === 1 && current === 1"
          class="auth-primary"
          @click="loginMobile"
        >
          登录
        </view>
        <view
          v-if="formItem === 1 && current === 0"
          class="auth-primary"
          @click="submit"
        >
          登录
        </view>
        <view v-if="formItem === 2" class="auth-primary" @click="register">
          注册并登录
        </view>

        <!-- #ifdef APP-PLUS -->
        <view
          v-if="formItem === 1 && !appLoginStatus && !appleLoginStatus"
          class="appLogin"
        >
          <view class="hds">
            <span class="line"></span>
            <p>其他方式登录</p>
            <span class="line"></span>
          </view>
          <view class="btn-wrapper">
            <view class="btn wx" @click="wxLogin">
              <span class="iconfont icon-s-weixindenglu1"></span>
            </view>
            <view v-if="current === 1" class="btn mima" @click="current = 0">
              <span class="iconfont icon-s-mimadenglu1"></span>
            </view>
            <view v-if="current === 0" class="btn yanzheng" @click="current = 1">
              <span class="iconfont icon-s-yanzhengmadenglu1"></span>
            </view>
            <view v-if="appleShow" class="btn apple-btn" @click="appleLogin">
              <view class="iconfont icon-s-pingguo"></view>
            </view>
          </view>
        </view>
        <!-- #endif -->
      </view>
    </view>

    <Verify
      ref="verify"
      :captchaType="'blockPuzzle'"
      :imgSize="{ width: '330px', height: '155px' }"
      @success="handlerOnVerSuccess"
    />
  </view>
</template>
```

- [ ] **Step 3: Remove template-only state**

Delete these declarations because the new page no longer renders a remote logo or the unused navigation list:

```js
const navList = ref(["快速登录", "账号登录"]);
const mobileLoginLogo = ref(app.globalData.mobileLoginLogo);
```

Delete the unused function:

```js
function navTap(index) {
  current.value = index;
}
```

Keep `current` initialized to `1`:

```js
const current = ref(1);
```

- [ ] **Step 4: Scan the updated component**

Run:

```bash
grep -nE 'mobileLoginLogo|class="shading"|urlDomain.*phone_1|urlDomain.*code_2|navList|navTap' \
  frontend/uni-app/pages/users/login/index.vue
```

Expected: no output.

### Task 2: Apply The Warm Membership Styling

**Files:**
- Modify: `frontend/uni-app/pages/users/login/index.vue`

- [ ] **Step 1: Replace the old scoped style**

Replace the current `<style lang="scss" scoped>` content with styles that implement these exact layout constraints:

```scss
page {
  min-height: 100%;
  background: #fff8f4;
}

.login-wrapper {
  position: relative;
  min-height: 100vh;
  padding:
    calc(env(safe-area-inset-top) + 34rpx)
    40rpx
    calc(env(safe-area-inset-bottom) + 48rpx);
  overflow: hidden;
  box-sizing: border-box;
  background: #fff8f4;
  color: #2e2927;
  letter-spacing: 0;
}

.auth-shell {
  position: relative;
  z-index: 2;
  width: 100%;
  max-width: 670rpx;
  margin: 0 auto;
}

.auth-accent {
  position: absolute;
  pointer-events: none;
  background: #ffd7c9;

  &--large {
    top: -90rpx;
    right: -104rpx;
    width: 330rpx;
    height: 270rpx;
    border-radius: 56rpx;
    transform: rotate(24deg);
  }

  &--small {
    top: 210rpx;
    right: 72rpx;
    width: 112rpx;
    height: 112rpx;
    border-radius: 28rpx;
    background: var(--view-theme, #ff542e);
    transform: rotate(12deg);
    box-shadow: 0 24rpx 54rpx rgba(255, 84, 46, 0.2);
  }
}

.auth-brand {
  display: flex;
  align-items: center;
  gap: 18rpx;
  height: 64rpx;

  &__mark {
    width: 56rpx;
    height: 56rpx;
    border-radius: 14rpx;
    color: #fff;
    background: #2e2927;
    font-size: 24rpx;
    line-height: 56rpx;
    font-weight: 600;
    text-align: center;
  }

  &__name {
    font-size: 28rpx;
    line-height: 40rpx;
    font-weight: 600;
  }
}

.auth-hero {
  min-height: 300rpx;
  padding-top: 72rpx;

  &__title {
    display: block;
    width: 430rpx;
    font-size: 58rpx;
    line-height: 76rpx;
    font-weight: 700;
  }

  &__desc {
    display: block;
    width: 430rpx;
    margin-top: 18rpx;
    color: #8c746c;
    font-size: 24rpx;
    line-height: 38rpx;
  }
}

.auth-form {
  position: relative;
  padding-top: 18rpx;
}

.auth-switch {
  display: flex;
  width: 320rpx;
  height: 76rpx;
  border-bottom: 1rpx solid #eddcd5;

  &__item {
    position: relative;
    width: 160rpx;
    color: #9a847d;
    font-size: 28rpx;
    line-height: 76rpx;
    text-align: center;

    &.active {
      color: #2e2927;
      font-weight: 600;

      &::after {
        content: "";
        position: absolute;
        left: 36rpx;
        right: 36rpx;
        bottom: -1rpx;
        height: 4rpx;
        background: var(--view-theme, #ff542e);
      }
    }
  }
}

.auth-method {
  display: flex;
  gap: 34rpx;
  height: 70rpx;
  align-items: center;

  &__item {
    color: #a18f88;
    font-size: 24rpx;
    line-height: 34rpx;

    &.active {
      color: var(--view-theme, #ff542e);
      font-weight: 600;
    }
  }
}

.auth-fields {
  display: flex;
  flex-direction: column;
  gap: 20rpx;
}

.auth-field {
  display: flex;
  align-items: center;
  width: 100%;
  height: 96rpx;
  padding: 0 28rpx;
  border: 1rpx solid #f0dfd8;
  border-radius: 16rpx;
  box-sizing: border-box;
  background: rgba(255, 255, 255, 0.78);

  &:focus-within {
    border-color: var(--view-theme, #ff542e);
    box-shadow: 0 0 0 4rpx rgba(255, 84, 46, 0.08);
  }

  &__icon {
    flex: 0 0 38rpx;
    color: #8c746c;
    font-size: 30rpx;
    text-align: center;
  }

  &__input {
    flex: 1;
    min-width: 0;
    height: 92rpx;
    margin-left: 18rpx;
    color: #2e2927;
    font-size: 28rpx;
    line-height: 92rpx;
  }
}

.auth-code {
  flex: 0 0 auto;
  min-width: 160rpx;
  height: 64rpx;
  margin: 0;
  padding: 0 12rpx;
  border: 0;
  color: var(--view-theme, #ff542e);
  background: transparent;
  font-size: 24rpx;
  line-height: 64rpx;

  &::after {
    border: 0;
  }

  &.disabled {
    color: #bcaea8;
  }
}

.auth-captcha {
  flex: 0 0 166rpx;
  height: 64rpx;
  overflow: hidden;
  border-radius: 8rpx;
}

.code-img {
  width: 100%;
  height: 100%;
}

.protocol {
  margin-top: 28rpx;

  &__group {
    display: flex;
    align-items: flex-start;
  }

  &__checkbox {
    flex: 0 0 auto;
    transform: scale(0.82);
    transform-origin: left top;
  }

  &__text {
    flex: 1;
    margin-left: 4rpx;
    color: #9a8982;
    font-size: 22rpx;
    line-height: 36rpx;
  }

  .font_pro {
    color: var(--view-theme, #ff542e);
  }

  ::v-deep .uni-checkbox-input.uni-checkbox-input-checked,
  ::v-deep checkbox .wx-checkbox-input.wx-checkbox-input-checked {
    border: 0 !important;
    color: #fff !important;
    background: var(--view-theme, #ff542e) !important;
  }
}

.auth-primary {
  width: 100%;
  height: 96rpx;
  margin-top: 34rpx;
  border-radius: 48rpx;
  color: #fff;
  background: #2e2927;
  font-size: 30rpx;
  line-height: 96rpx;
  font-weight: 600;
  text-align: center;
  box-shadow: 0 24rpx 44rpx rgba(46, 41, 39, 0.16);

  &:active {
    opacity: 0.88;
    transform: translateY(1rpx);
  }
}

.appLogin {
  margin-top: 54rpx;

  .hds {
    display: flex;
    align-items: center;
    justify-content: center;
    color: #aa9c96;
    font-size: 22rpx;

    .line {
      width: 68rpx;
      height: 1rpx;
      background: #e5d7d1;
    }

    p {
      margin: 0 20rpx;
    }
  }

  .btn-wrapper {
    display: flex;
    align-items: center;
    justify-content: center;
    margin-top: 30rpx;
  }

  .btn {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 72rpx;
    height: 72rpx;
    margin: 0 14rpx;
    border-radius: 50%;

    &.wx {
      background: #61c64f;
    }

    &.mima {
      background: #2e2927;
    }

    &.yanzheng {
      background: var(--view-theme, #ff542e);
    }

    &.apple-btn {
      background: #000;
    }
  }

  .iconfont {
    color: #fff;
    font-size: 40rpx;
  }
}

.main_color {
  color: var(--view-theme, #ff542e);
}

@media screen and (max-width: 360px) {
  .auth-hero__title,
  .auth-hero__desc {
    width: 400rpx;
  }

  .auth-hero__title {
    font-size: 52rpx;
    line-height: 68rpx;
  }
}
```

- [ ] **Step 2: Validate stylesheet and Vue syntax**

Run:

```bash
cd frontend/uni-app
npm run build:h5
```

Expected: `DONE Build complete.`

- [ ] **Step 3: Commit the focused UI change**

Run:

```bash
git add frontend/uni-app/pages/users/login/index.vue
git commit -m "feat: refresh h5 login and registration"
```

Expected: one commit containing only the login component.

### Task 3: Verify Authentication States And Responsive Layout

**Files:**
- Verify: `frontend/uni-app/pages/users/login/index.vue`
- Existing test: `tests/e2e/specs/h5-route-smoke.spec.mjs`

- [ ] **Step 1: Run the existing guest route smoke test**

Run:

```bash
cd tests/e2e
E2E_USER_ACCOUNT=13000000000 \
E2E_USER_PASSWORD='crmeb@123456' \
E2E_SECOND_USER_ACCOUNT=13000000000 \
E2E_SECOND_USER_PASSWORD='crmeb@123456' \
npx playwright test --project=h5-mobile --grep 'guest: login'
```

Expected: `1 passed`.

- [ ] **Step 2: Inspect default login and registration states**

Run from `tests/e2e`:

```bash
node --input-type=module <<'NODE'
import { chromium, devices } from 'playwright';

const browser = await chromium.launch({ channel: 'chrome', headless: true });
const context = await browser.newContext({
  ...devices['iPhone 13'],
  viewport: { width: 390, height: 844 },
});
const page = await context.newPage();

await page.goto('http://127.0.0.1:5273/pages/users/login/index', {
  waitUntil: 'networkidle',
});

const defaultState = await page.evaluate(() => ({
  brand: document.querySelector('.auth-brand__name')?.textContent?.trim(),
  activeMethod: document.querySelector('.auth-method__item.active')?.textContent?.trim(),
  fieldCount: document.querySelectorAll('.auth-fields .auth-field').length,
  oldLogoCount: document.querySelectorAll('.shading image').length,
  scrollWidth: document.documentElement.scrollWidth,
  innerWidth: window.innerWidth,
}));

await page.screenshot({ path: '/tmp/h5-auth-login-c.png', fullPage: true });
await page.locator('.auth-switch__item').nth(1).click();

const registerState = await page.evaluate(() => ({
  title: document.querySelector('.auth-hero__title')?.textContent?.trim(),
  fieldCount: document.querySelectorAll('.auth-fields .auth-field').length,
  primaryText: document.querySelector('.auth-primary')?.textContent?.trim(),
  scrollWidth: document.documentElement.scrollWidth,
  innerWidth: window.innerWidth,
}));

await page.screenshot({ path: '/tmp/h5-auth-register-c.png', fullPage: true });

if (defaultState.brand !== '商城系统') throw new Error(JSON.stringify(defaultState));
if (defaultState.activeMethod !== '验证码登录') throw new Error(JSON.stringify(defaultState));
if (defaultState.fieldCount < 2 || defaultState.oldLogoCount !== 0) {
  throw new Error(JSON.stringify(defaultState));
}
if (defaultState.scrollWidth > defaultState.innerWidth) throw new Error(JSON.stringify(defaultState));
if (registerState.fieldCount !== 4 || registerState.primaryText !== '注册并登录') {
  throw new Error(JSON.stringify(registerState));
}
if (registerState.scrollWidth > registerState.innerWidth) throw new Error(JSON.stringify(registerState));

console.log(JSON.stringify({ defaultState, registerState }, null, 2));
await context.close();
await browser.close();
NODE
```

Expected:

- `brand` equals `商城系统`.
- `activeMethod` equals `验证码登录`.
- the login state has at least two fields.
- the registration state has four fields.
- neither state has horizontal overflow.

- [ ] **Step 3: Check three mobile widths**

Run from `tests/e2e`:

```bash
node --input-type=module <<'NODE'
import { chromium } from 'playwright';

const browser = await chromium.launch({ channel: 'chrome', headless: true });
const sizes = [
  { width: 375, height: 812 },
  { width: 390, height: 844 },
  { width: 430, height: 932 },
];
const results = [];

for (const viewport of sizes) {
  const context = await browser.newContext({ viewport });
  const page = await context.newPage();
  await page.goto('http://127.0.0.1:5273/pages/users/login/index', {
    waitUntil: 'networkidle',
  });
  const result = await page.evaluate(() => ({
    innerWidth: window.innerWidth,
    scrollWidth: document.documentElement.scrollWidth,
    primaryVisible: Boolean(document.querySelector('.auth-primary')),
  }));
  if (result.scrollWidth > result.innerWidth || !result.primaryVisible) {
    throw new Error(JSON.stringify({ viewport, result }));
  }
  results.push({ viewport, result });
  await context.close();
}

console.log(JSON.stringify(results, null, 2));
await browser.close();
NODE
```

Expected: all three viewports report `scrollWidth <= innerWidth` and `primaryVisible: true`.

- [ ] **Step 4: Inspect final screenshots**

Open:

```text
/tmp/h5-auth-login-c.png
/tmp/h5-auth-register-c.png
```

Expected:

- no overlap between geometric decoration and the heading;
- registration fields remain evenly spaced;
- agreement text remains readable;
- the main button remains visible after natural vertical scrolling;
- no old remote logo is rendered.
