# Ecommerce Required Features Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 补齐注册、侧边账户导航、切换账号和下单进度，并验证 `功能.md` 的全部功能链路。

**Architecture:** 在现有 uni-app、Pinia 和 Spring Boot 模块边界内增量实现。注册由商城登录服务负责并复用用户创建能力；账户操作封装为移动端组件；下单进度只映射真实客户端阶段。

**Tech Stack:** Vue 3、uni-app、Pinia、Spring Boot 2.2.6、MyBatis-Plus、MySQL、Redis、JUnit 4、Vite

---

### Task 1: 注册请求模型和校验测试

**Files:**
- Create: `backend/crmeb-common/src/main/java/com/zbkj/common/request/RegisterRequest.java`
- Create: `backend/crmeb-common/src/test/java/com/zbkj/common/request/RegisterRequestTest.java`

- [ ] **Step 1: 写失败的请求校验测试**

测试使用 Bean Validation，覆盖合法请求、错误手机号、错误验证码和弱密码：

```java
public class RegisterRequestTest {
    private final Validator validator =
            Validation.buildDefaultValidatorFactory().getValidator();

    @Test
    public void acceptsValidRegistration() {
        RegisterRequest request = validRequest();
        Assert.assertTrue(validator.validate(request).isEmpty());
    }

    @Test
    public void rejectsInvalidPhoneCodeAndPassword() {
        RegisterRequest request = validRequest()
                .setPhone("123")
                .setCaptcha("12")
                .setPassword("123456");
        Assert.assertEquals(3, validator.validate(request).size());
    }
}
```

- [ ] **Step 2: 运行测试并确认失败**

Run:

```bash
cd backend
mvn -pl crmeb-common -Dtest=RegisterRequestTest test
```

Expected: `RegisterRequest` 不存在，测试编译失败。

- [ ] **Step 3: 实现请求模型**

模型字段：

```java
@JsonProperty("account")
@NotBlank
@Pattern(regexp = RegularConstants.PHONE_TWO)
private String phone;

@Pattern(regexp = RegularConstants.VALIDATE_CODE_NUM_SIX)
private String captcha;

@Pattern(regexp = RegularConstants.PASSWORD)
private String password;

@JsonProperty("spread_spid")
private Integer spreadPid = 0;
```

- [ ] **Step 4: 运行目标测试**

Run:

```bash
cd backend
mvn -pl crmeb-common -Dtest=RegisterRequestTest test
```

Expected: `RegisterRequestTest` 全部通过。

### Task 2: 商城注册接口和服务测试

**Files:**
- Modify: `backend/crmeb-front/src/main/java/com/zbkj/front/service/LoginService.java`
- Modify: `backend/crmeb-front/src/main/java/com/zbkj/front/service/impl/LoginServiceImpl.java`
- Modify: `backend/crmeb-front/src/main/java/com/zbkj/front/controller/LoginController.java`
- Modify: `backend/crmeb-front/src/main/java/com/zbkj/front/config/WebConfig.java`
- Create: `backend/crmeb-front/src/test/java/com/zbkj/front/service/impl/LoginServiceImplTest.java`

- [ ] **Step 1: 写失败的注册服务测试**

使用动态代理构造 `UserService`，使用测试 `RedisUtil` 和 `FrontTokenComponent`：

```java
@Test
public void registerCreatesUserSetsPasswordAndReturnsToken() {
    LoginServiceImpl service = createService(null, "123456");
    LoginResponse response = service.register(validRequest());
    Assert.assertEquals(Integer.valueOf(9), response.getUid());
    Assert.assertEquals("test-token", response.getToken());
    Assert.assertTrue(passwordUpdated.get());
}

@Test
public void registerRejectsExistingPhoneWithoutConsumingCode() {
    LoginServiceImpl service = createService(existingUser(), "123456");
    assertCrmebException("此手机号码已被注册", () -> service.register(validRequest()));
    Assert.assertFalse(codeDeleted.get());
}

@Test
public void registerRejectsWrongCodeWithoutCreatingUser() {
    LoginServiceImpl service = createService(null, "654321");
    assertCrmebException("验证码错误", () -> service.register(validRequest()));
    Assert.assertFalse(userCreated.get());
}
```

- [ ] **Step 2: 运行测试并确认失败**

Run:

```bash
cd backend
mvn -pl crmeb-front -am -Dtest=LoginServiceImplTest -Dsurefire.failIfNoSpecifiedTests=false test
```

Expected: `register` 方法不存在，测试编译失败。

- [ ] **Step 3: 实现事务注册**

`LoginServiceImpl.register` 必须按以下顺序执行：

```java
if (ObjectUtil.isNotNull(userService.getByPhone(request.getPhone()))) {
    throw new CrmebException("此手机号码已被注册");
}
checkValidateCode(request.getPhone(), request.getCaptcha());
User user = transactionTemplate.execute(status -> {
    User created = userService.registerPhone(request.getPhone(), spreadPid);
    if (!userService.updateUserPassword(created.getUid(), request.getPassword())) {
        status.setRollbackOnly();
        throw new CrmebException("注册失败");
    }
    return created;
});
return buildLoginResponse(user);
```

抽取 `buildLoginResponse(User)`，供验证码登录和注册共用。

- [ ] **Step 4: 暴露匿名注册接口**

控制器增加：

```java
@PostMapping("/register")
public CommonResult<LoginResponse> register(
        @RequestBody @Validated RegisterRequest request) {
    return CommonResult.success(loginService.register(request));
}
```

确认 `WebConfig` 将 `/api/front/register` 保持为匿名接口。

- [ ] **Step 5: 运行后端目标测试**

Run:

```bash
cd backend
mvn -pl crmeb-common,crmeb-front -am \
  -Dtest=RegisterRequestTest,LoginServiceImplTest \
  -Dsurefire.failIfNoSpecifiedTests=false test
```

Expected: 两个测试类全部通过。

### Task 3: 登录页独立注册

**Files:**
- Modify: `frontend/uni-app/pages/users/login/index.vue`
- Modify: `frontend/uni-app/api/user.js`

- [ ] **Step 1: 对齐注册 API 契约**

保持：

```js
export function register(data) {
  return request.post("register", data, { noAuth: true });
}
```

注册成功响应按 `LoginResponse` 处理，不按纯字符串处理。

- [ ] **Step 2: 增加注册模式 UI**

模板使用 `formItem` 分支：

```vue
<view class="whiteBg">
  <template v-if="formItem === 1">
    <!-- 现有两种登录 -->
  </template>
  <template v-else>
    <!-- 手机号、验证码、密码、协议、注册并登录 -->
  </template>
</view>
```

登录模式底部显示“注册账号”；注册模式显示“返回登录”。

- [ ] **Step 3: 注册成功后建立登录态**

```js
registerApi(payload).then(({ data }) => {
  appStore.LOGIN({ token: data.token });
  getUserInfo(data);
});
```

切换模式时清空验证码和密码，防止不同用途表单互相污染。

- [ ] **Step 4: 静态检查登录页**

Run:

```bash
cd frontend/uni-app
npx vite build
```

Expected: 无模板或脚本编译错误。

### Task 4: 侧边账户导航和切换账号

**Files:**
- Create: `frontend/uni-app/components/accountDrawer/index.vue`
- Modify: `frontend/uni-app/pages/user/index.vue`
- Modify: `frontend/uni-app/pages/infos/user_info/index.vue`

- [ ] **Step 1: 创建账户抽屉组件**

组件接口：

```vue
<account-drawer
  :visible="accountDrawerVisible"
  @close="accountDrawerVisible = false"
/>
```

组件读取 Pinia `isLogin` 和 `userInfo`：

- 未登录按钮跳转 `/pages/users/login/index?mode=register` 或登录页。
- 已登录入口跳转个人资料。
- 切换账号和退出登录调用统一 `leaveCurrentAccount(target)`。

- [ ] **Step 2: 增加个人中心菜单图标**

个人中心顶部使用稳定尺寸图标按钮：

```vue
<view class="account-menu-button" @tap="accountDrawerVisible = true">
  <text class="iconfont icon-gengduo2"></text>
</view>
```

按钮避开状态栏和小程序胶囊区域。

- [ ] **Step 3: 增加个人详情切换账号**

在退出登录按钮前增加：

```vue
<view class="switchAccount" @click="switchAccount">切换账号</view>
```

`switchAccount` 服务端退出后本地 `LOGOUT`，再 `reLaunch` 到登录页。服务端退出失败时也清除本地状态。

- [ ] **Step 4: 验证本地状态清理**

检查 `LOGIN_STATUS`、`UID`、`USER_INFO`、`EXPIRES_TIME`、微信授权缓存均由 `appStore.LOGOUT()` 清除。

### Task 5: 下单过程进度和重复提交保护

**Files:**
- Modify: `frontend/uni-app/pages/order/order_confirm/index.vue`

- [ ] **Step 1: 增加进度状态**

```js
const submitting = ref(false);
const submitProgress = ref(0);
const submitStage = ref('');
```

实现：

```js
function updateSubmitProgress(progress, stage) {
  submitProgress.value = progress;
  submitStage.value = stage;
}

function resetSubmitProgress() {
  submitting.value = false;
  submitProgress.value = 0;
  submitStage.value = '';
}
```

- [ ] **Step 2: 增加进度层**

进度层包含阶段文字、百分比和固定宽度进度轨道；`submitting` 为真时显示并阻止重复操作。

- [ ] **Step 3: 绑定真实阶段**

`SubOrder` 开始校验设为 20%；校验通过调用 API 前设为 55%；返回订单号设为 85%；导航前设为 100%。

创建失败时调用 `resetSubmitProgress()` 并保留原错误提示。

- [ ] **Step 4: 验证重复提交**

`SubOrder` 和 `onCreate` 开头均检查 `submitting`，单次用户操作只能发出一个 `order/create` 请求。

### Task 6: 构建、接口和浏览器端到端验收

**Files:**
- Modify: `功能实现对照说明.md`
- Create: `功能验收测试报告.md`

- [ ] **Step 1: 后端完整测试**

Run:

```bash
cd backend
mvn test
```

Expected: 所有模块测试通过。

- [ ] **Step 2: 前端构建**

Run:

```bash
cd frontend/uni-app
npm run build:h5
npm run build:app
```

Run:

```bash
cd frontend/admin
npm run build
```

Expected: 三个构建退出码均为 0。

- [ ] **Step 3: API 集成测试**

使用唯一测试手机号和 Redis 测试验证码验证：

- 注册成功并返回令牌。
- 重复注册失败。
- 密码登录成功。
- 商品分类、列表、详情成功。
- 加入购物车、列表、修改数量、删除成功。
- 多商品预下单、创建订单、订单列表和删除规则成功。
- 个人信息、修改密码、退出成功。
- 管理端商品和订单接口可访问。

- [ ] **Step 4: 浏览器端到端测试**

在本地 H5 依次验证：

- 引导页到首页。
- 分类到商品详情。
- 数量与加入购物车。
- 购物车删除、多选下单和进度。
- 订单列表和删除。
- 登录页注册。
- 个人详情、修改密码、切换账号。
- 侧边导航登录和退出。

每个关键视口检查控制台错误和布局遮挡。

- [ ] **Step 5: 文档收口**

`功能实现对照说明.md` 将 9 项均更新为“已实现”，并引用新增文件和测试证据。

`功能验收测试报告.md` 记录命令、结果、未执行的外部真实支付边界和残余风险。
