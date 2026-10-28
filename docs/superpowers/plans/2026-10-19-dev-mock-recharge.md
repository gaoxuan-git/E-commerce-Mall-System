# Dev Mock Recharge Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在本地 `dev` 环境为 H5 提供不调用第三方支付、但真实写入充值订单、余额和账单的模拟充值能力。

**Architecture:** 在 `crmeb-front` 内新增由 `dev` Profile 与显式配置开关共同保护的 Controller 和 Service。Service 校验服务端套餐或自定义金额，创建 `rechargeType=dev_mock` 的充值订单，再复用 `RechargePayService.paySuccess()` 完成余额与账单更新；H5 仅在 Vite 开发构建中调用该接口，其他端和生产构建继续走原支付流程。

**Tech Stack:** Java 8、Spring Boot 2.2、Spring Profile、Spring Transaction、MyBatis-Plus、JUnit 4、Mockito、Vue 3、uni-app、Pinia、Vite

---

## 文件结构

- 创建 `backend/crmeb-front/src/main/java/com/zbkj/front/response/DevMockRechargeResponse.java`
  - 只定义模拟充值响应契约。
- 创建 `backend/crmeb-front/src/main/java/com/zbkj/front/service/DevMockRechargeService.java`
  - 只定义模拟充值服务入口。
- 创建 `backend/crmeb-front/src/main/java/com/zbkj/front/service/impl/DevMockRechargeServiceImpl.java`
  - 负责金额校验、订单创建、调用既有充值成功链路和读取最新余额。
- 创建 `backend/crmeb-front/src/main/java/com/zbkj/front/controller/DevMockRechargeController.java`
  - 负责 dev 专用 HTTP 路由及 Profile/配置双重隔离。
- 创建 `backend/crmeb-front/src/test/java/com/zbkj/front/service/impl/DevMockRechargeServiceImplTest.java`
  - 覆盖套餐、自定义金额、上下限、保存失败和支付处理失败。
- 创建 `backend/crmeb-front/src/test/java/com/zbkj/front/controller/DevMockRechargeControllerConditionTest.java`
  - 覆盖 Controller 的 Profile/配置注册条件。
- 修改 `backend/crmeb-front/src/main/resources/application-dev.yml`
  - 只在前台 dev 配置中启用模拟充值。
- 修改 `frontend/uni-app/api/user.js`
  - 增加模拟充值 API 封装。
- 修改 `frontend/uni-app/pages/users/user_payment/index.vue`
  - 增加 H5 开发模式的支付方式、提交状态和模拟充值分支。
- 修改 `功能验收测试报告.md`
  - 记录自动化测试、接口、数据库、刷新持久化和余额购买验收证据。

### Task 1: 定义模拟充值响应和服务契约

**Files:**
- Create: `backend/crmeb-front/src/main/java/com/zbkj/front/response/DevMockRechargeResponse.java`
- Create: `backend/crmeb-front/src/main/java/com/zbkj/front/service/DevMockRechargeService.java`

- [ ] **Step 1: 创建响应对象**

```java
@Data
@Accessors(chain = true)
public class DevMockRechargeResponse implements Serializable {
    private static final long serialVersionUID = 1L;
    private Boolean mock;
    private String orderNo;
    private BigDecimal rechargeAmount;
    private BigDecimal giveAmount;
    private BigDecimal creditedAmount;
    private BigDecimal balance;
}
```

- [ ] **Step 2: 创建服务接口**

```java
public interface DevMockRechargeService {
    DevMockRechargeResponse recharge(UserRechargeRequest request);
}
```

- [ ] **Step 3: 编译契约**

Run:

```bash
cd backend
./mvnw -pl crmeb-front -am -DskipTests compile
```

Expected: `BUILD SUCCESS`

### Task 2: 用测试定义金额、套餐和失败行为

**Files:**
- Create: `backend/crmeb-front/src/test/java/com/zbkj/front/service/impl/DevMockRechargeServiceImplTest.java`

- [ ] **Step 1: 编写固定套餐测试**

测试构造客户端伪造的 `price=1` 和一个有效 `groupDataId`，Mock 服务端套餐为
`price=30`、`giveMoney=3`。捕获保存的 `UserRecharge` 并断言：

```java
Assert.assertEquals(new BigDecimal("30.00"), order.getPrice());
Assert.assertEquals(new BigDecimal("3.00"), order.getGivePrice());
Assert.assertEquals("dev_mock", order.getRechargeType());
Assert.assertFalse(order.getPaid());
Assert.assertEquals(new BigDecimal("33.00"), response.getCreditedAmount());
Assert.assertEquals(new BigDecimal("43.00"), response.getBalance());
Assert.assertTrue(response.getMock());
```

- [ ] **Step 2: 编写自定义金额测试**

Mock 最低充值额为 `10`，提交 `20.50` 且不传套餐，断言赠送金额为零、到账
`20.50`，并且订单使用当前登录用户 ID。

- [ ] **Step 3: 编写拒绝场景测试**

分别验证下列请求抛出 `CrmebException`，且不保存订单：

```text
price = null                         -> 请输入充值金额
price = 0                            -> 充值金额必须大于0
price = 9.99, minimum = 10           -> 充值金额不能低于10
price = 50000.01                     -> 充值金额最大值为50000
groupDataId = 999, package missing   -> 您选择的充值方式已下架
```

- [ ] **Step 4: 编写持久化失败测试**

当 `userRechargeService.save(order)` 返回 `false` 时断言错误为
`生成模拟充值订单失败`，并验证 `rechargePayService.paySuccess()` 从未调用。

- [ ] **Step 5: 编写充值成功处理失败测试**

当订单保存成功但 `rechargePayService.paySuccess(order)` 返回 `false` 时断言错误为
`模拟充值失败，请重试`；实现方法上的事务注解保证运行时抛出异常后回滚订单。

- [ ] **Step 6: 运行测试确认先失败**

Run:

```bash
cd backend
./mvnw -pl crmeb-front -am \
  -Dtest=DevMockRechargeServiceImplTest \
  -Dsurefire.failIfNoSpecifiedTests=false test
```

Expected: FAIL because `DevMockRechargeServiceImpl` does not exist.

### Task 3: 实现模拟充值服务

**Files:**
- Create: `backend/crmeb-front/src/main/java/com/zbkj/front/service/impl/DevMockRechargeServiceImpl.java`
- Test: `backend/crmeb-front/src/test/java/com/zbkj/front/service/impl/DevMockRechargeServiceImplTest.java`

- [ ] **Step 1: 声明环境和配置条件**

```java
@Service
@Profile("dev")
@ConditionalOnProperty(
        prefix = "crmeb.payment.dev-mock-recharge",
        name = "enabled",
        havingValue = "true",
        matchIfMissing = false)
public class DevMockRechargeServiceImpl implements DevMockRechargeService {
    private static final BigDecimal MAX_RECHARGE_AMOUNT = new BigDecimal("50000");
    private static final String RECHARGE_TYPE = "dev_mock";
}
```

- [ ] **Step 2: 从可信来源解析金额**

当 `groupDataId > 0` 时调用：

```java
systemGroupDataService.getNormalInfo(
        request.getGroupDataId(),
        SystemGroupDataRechargeConfigVo.class);
```

套餐不存在时抛出 `您选择的充值方式已下架`。存在时只使用返回的 `price` 和
`giveMoney`，赠送为空按零处理。

当未选择套餐时，校验 `request.price` 非空、大于零、不低于
`store_user_min_recharge` 且不超过 `50000`，赠送金额固定为零。

- [ ] **Step 3: 创建未支付模拟订单**

```java
User currentUser = userService.getInfoException();
UserRecharge order = new UserRecharge()
        .setUid(currentUser.getUid())
        .setOrderId(CrmebUtil.getOrderNo("recharge"))
        .setPrice(rechargeAmount)
        .setGivePrice(giveAmount)
        .setRechargeType(RECHARGE_TYPE)
        .setPaid(false)
        .setOutTradeNo("");
```

保存失败时抛出 `生成模拟充值订单失败`。

- [ ] **Step 4: 复用充值成功处理并返回数据库最新余额**

```java
if (!Boolean.TRUE.equals(rechargePayService.paySuccess(order))) {
    throw new CrmebException("模拟充值失败，请重试");
}
User updatedUser = userService.getById(currentUser.getUid());
BigDecimal creditedAmount = rechargeAmount.add(giveAmount);
return new DevMockRechargeResponse()
        .setMock(true)
        .setOrderNo(order.getOrderId())
        .setRechargeAmount(rechargeAmount)
        .setGiveAmount(giveAmount)
        .setCreditedAmount(creditedAmount)
        .setBalance(updatedUser.getNowMoney());
```

`recharge()` 使用
`@Transactional(rollbackFor = {RuntimeException.class, Error.class, CrmebException.class})`，
使订单保存与 `paySuccess()` 内的订单、余额、账单更新处于同一事务。

- [ ] **Step 5: 运行服务测试**

Run:

```bash
cd backend
./mvnw -pl crmeb-front -am \
  -Dtest=DevMockRechargeServiceImplTest \
  -Dsurefire.failIfNoSpecifiedTests=false test
```

Expected: all `DevMockRechargeServiceImplTest` tests PASS.

### Task 4: 增加 dev 条件接口

**Files:**
- Create: `backend/crmeb-front/src/main/java/com/zbkj/front/controller/DevMockRechargeController.java`
- Create: `backend/crmeb-front/src/test/java/com/zbkj/front/controller/DevMockRechargeControllerConditionTest.java`

- [ ] **Step 1: 编写 Bean 注册条件测试**

使用 `AnnotationConfigApplicationContext` 注册一个 Mock
`DevMockRechargeService`，分别断言：

```text
activeProfiles=dev,  enabled=true  -> Controller bean count = 1
activeProfiles=dev,  enabled=false -> Controller bean count = 0
activeProfiles=prod, enabled=true  -> Controller bean count = 0
```

- [ ] **Step 2: 运行测试确认先失败**

Run:

```bash
cd backend
./mvnw -pl crmeb-front -am \
  -Dtest=DevMockRechargeControllerConditionTest \
  -Dsurefire.failIfNoSpecifiedTests=false test
```

Expected: FAIL because `DevMockRechargeController` does not exist.

- [ ] **Step 3: 创建 Controller**

```java
@RestController
@RequestMapping("api/front/recharge/dev")
@Profile("dev")
@ConditionalOnProperty(
        prefix = "crmeb.payment.dev-mock-recharge",
        name = "enabled",
        havingValue = "true",
        matchIfMissing = false)
public class DevMockRechargeController {
    @Autowired
    private DevMockRechargeService devMockRechargeService;

    @PostMapping("/mock")
    public CommonResult<DevMockRechargeResponse> recharge(
            @RequestBody @Validated UserRechargeRequest request) {
        return CommonResult.success(devMockRechargeService.recharge(request));
    }
}
```

该路径属于 `/api/front/**` 且不在 `WebConfig` 排除列表中，因此沿用现有前台
Token 鉴权。

- [ ] **Step 4: 运行 Controller 条件测试**

Run:

```bash
cd backend
./mvnw -pl crmeb-front -am \
  -Dtest=DevMockRechargeControllerConditionTest \
  -Dsurefire.failIfNoSpecifiedTests=false test
```

Expected: all condition tests PASS.

### Task 5: 仅在前台 dev Profile 开启接口

**Files:**
- Modify: `backend/crmeb-front/src/main/resources/application-dev.yml`

- [ ] **Step 1: 增加显式开关**

在既有 `crmeb:` 节点下增加：

```yaml
  payment:
    dev-mock-recharge:
      enabled: true
```

- [ ] **Step 2: 确认其他 Profile 未开启**

Run:

```bash
rg -n "dev-mock-recharge" \
  backend/crmeb-front/src/main/resources/application-*.yml \
  backend/crmeb-admin/src/main/resources/application-*.yml
```

Expected: only `backend/crmeb-front/src/main/resources/application-dev.yml`.

- [ ] **Step 3: 运行前台模块测试**

Run:

```bash
cd backend
./mvnw -pl crmeb-front -am test
```

Expected: `BUILD SUCCESS`.

### Task 6: 接入 H5 开发模式页面

**Files:**
- Modify: `frontend/uni-app/api/user.js`
- Modify: `frontend/uni-app/pages/users/user_payment/index.vue`

- [ ] **Step 1: 添加 API 封装**

```javascript
export function devMockRecharge(data) {
  return request.post("recharge/dev/mock", data);
}
```

- [ ] **Step 2: 建立仅 H5 开发构建启用的状态**

```javascript
const isDevMockRecharge = ref(false);
// #ifdef H5
isDevMockRecharge.value = import.meta.env.DEV;
// #endif
const submitting = ref(false);
```

开发 H5 将支付数组替换为唯一选项：

```javascript
{
    name: "本地模拟支付",
    icon: "icon-yuezhifu",
    value: "dev_mock",
    title: "仅本地开发环境",
    payStatus: 1
}
```

并设置 `payType.value = "dev_mock"`。`onLoad` 中开发 H5 不调用真实
`getOrderPayConfig()`。

- [ ] **Step 3: 增加提交状态和按钮文案**

```html
<button class="but" formType="submit" :disabled="submitting">
  {{ active ? "立即转入" : (isDevMockRecharge ? (submitting ? "模拟充值中..." : "模拟充值") : "立即充值") }}
</button>
```

处理函数开头在 `submitting` 为真时直接返回，阻止重复提交。

- [ ] **Step 4: 增加模拟充值分支**

在金额校验通过后、真实支付 `switch` 前调用：

```javascript
if (isDevMockRecharge.value) {
    submitting.value = true;
    uni.showLoading({ title: "模拟充值中" });
    devMockRecharge({
        price: payMoney,
        rechar_id: rechar_id.value
    }).then(res => {
        appStore.changInfo({
            amount1: "nowMoney",
            amount2: res.data.balance
        });
        return util.Tips({
            title: "模拟充值成功",
            icon: "success"
        }, {
            tab: 5,
            url: "/pages/users/user_money/index"
        });
    }).catch(err => {
        return util.Tips({ title: err.msg || err });
    }).finally(() => {
        submitting.value = false;
        uni.hideLoading();
    });
    return;
}
```

该分支不调用 `rechargeWechat`、`alipayFull` 或 `uni.requestPayment`。

- [ ] **Step 5: 构建 H5 开发与生产版本**

Run:

```bash
cd frontend/uni-app
npm run build:h5
```

Expected: build completes without Vue or Vite errors.

运行中的 `npm run dev:h5` 由 Vite 热更新加载代码；若未运行，则启动并保留进程：

```bash
npm run dev:h5 -- --host 127.0.0.1
```

### Task 7: 自动化回归与静态隔离检查

**Files:**
- Test: `backend/crmeb-front/src/test/java/com/zbkj/front/service/impl/DevMockRechargeServiceImplTest.java`
- Test: `backend/crmeb-front/src/test/java/com/zbkj/front/controller/DevMockRechargeControllerConditionTest.java`

- [ ] **Step 1: 运行全部相关后端测试**

Run:

```bash
cd backend
./mvnw -pl crmeb-front -am test
```

Expected: all common, service, and front tests PASS.

- [ ] **Step 2: 检查真实支付代码未被修改**

Run:

```bash
git diff -- \
  backend/crmeb-service/src/main/java/com/zbkj/service/service/impl/WeChatPayServiceImpl.java \
  backend/crmeb-service/src/main/java/com/zbkj/service/service/impl/AliPayServiceImpl.java \
  backend/crmeb-front/src/main/java/com/zbkj/front/service/impl/UserCenterServiceImpl.java
```

Expected: no diff produced by this feature.

- [ ] **Step 3: 检查配置和密钥边界**

Run:

```bash
rg -n "dev-mock-recharge|pay_weixin_appid|private.?key|secret" \
  backend/crmeb-front/src/main/resources/application-*.yml
```

Expected: 模拟充值开关只在 dev；本功能不新增支付密钥或伪密钥。

- [ ] **Step 4: 检查补丁格式**

Run:

```bash
git diff --check
```

Expected: no whitespace errors in files changed by this feature.

### Task 8: 真实接口、数据库和浏览器验收

**Files:**
- Modify: `功能验收测试报告.md`

- [ ] **Step 1: 构建并重启前台 API**

Run:

```bash
cd backend
./mvnw -pl crmeb-front -am -DskipTests package
```

停止现有 8081 进程后，以 `dev` Profile 启动最新
`backend/crmeb-front/target/Crmeb-front.jar`，确认 `/api/front/**` 可访问。

- [ ] **Step 2: 准备专用测试用户并记录充值前余额**

使用本地测试账号登录，记录：

```sql
SELECT uid, phone, now_money
FROM eb_user
WHERE uid = <authenticated_test_uid>;
```

不得使用生产数据或生产 Token。

- [ ] **Step 3: 调用套餐模拟充值**

从 `GET /api/front/recharge/index` 取得有效套餐 ID，再调用：

```http
POST /api/front/recharge/dev/mock
Authorization: Bearer <local_test_token>
Content-Type: application/json

{"price":1,"rechar_id":<valid_package_id>}
```

Expected: `mock=true`，返回金额采用服务端套餐而非客户端的 `1`，余额增加
`rechargeAmount + giveAmount`。

- [ ] **Step 4: 核对订单、账单和余额**

```sql
SELECT id, uid, order_id, price, give_price, recharge_type, paid, pay_time
FROM eb_user_recharge
WHERE order_id = '<response_order_no>';

SELECT uid, link_id, pm, category, type, number, balance
FROM eb_user_bill
WHERE link_id = '<response_order_no>';

SELECT uid, now_money
FROM eb_user
WHERE uid = <authenticated_test_uid>;
```

Expected:

```text
eb_user_recharge.recharge_type = dev_mock
eb_user_recharge.paid = 1
eb_user_bill.pm = 1
eb_user_bill.type = pay_recharge
eb_user.now_money = response.balance
```

- [ ] **Step 5: 浏览器验证 H5**

在 `http://127.0.0.1:5173` 登录测试账号并进入充值页，验证：

```text
支付方式只显示“本地模拟支付”
按钮显示“模拟充值”
连续点击不会重复提交
成功提示为“模拟充值成功”
网络面板只出现 /api/front/recharge/dev/mock
没有微信、支付宝或 requestPayment 请求
刷新余额页后余额保持
```

- [ ] **Step 6: 验证余额购买**

选择价格不超过测试余额的普通商品，提交订单并选择余额支付。核对订单支付成功，
且 `eb_user.now_money` 按订单实付金额减少。

- [ ] **Step 7: 验证生产隔离**

以非 `dev` Profile 或将
`crmeb.payment.dev-mock-recharge.enabled=false` 启动前台 API，调用同一路径。

Expected: HTTP 404；不得回退到微信或支付宝充值。

- [ ] **Step 8: 更新验收报告**

在 `功能验收测试报告.md` 写入执行日期、命令结果、测试用户 UID、订单号、充值前后
余额、赠送金额、账单关联、余额购买订单号和生产隔离结果。Token、密码、支付密钥不
写入报告。

## 提交说明

本工作区当前未配置 Git identity，因此执行过程中不自动配置身份或创建提交。完成后
保留按功能聚合的差异；若仓库后续配置身份，可按以下顺序提交：

```bash
git add backend/crmeb-front/src/main/java/com/zbkj/front \
  backend/crmeb-front/src/test/java/com/zbkj/front \
  backend/crmeb-front/src/main/resources/application-dev.yml
git commit -m "feat: add dev mock recharge endpoint"

git add frontend/uni-app/api/user.js \
  frontend/uni-app/pages/users/user_payment/index.vue
git commit -m "feat: use mock recharge in dev h5"

git add docs/superpowers/plans/2026-10-19-dev-mock-recharge.md \
  功能验收测试报告.md
git commit -m "docs: record mock recharge verification"
```
