# Development Mock Order Refund Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make development mock WeChat and Alipay orders refundable from the admin while preserving real provider refund behavior.

**Architecture:** Mark mock payments in `out_trade_no`, then gate the mock refund branch with the `dev` profile, the existing feature flag, and that marker. Mock refunds complete locally and reuse the existing refund post-processing queue; all unmarked orders retain their provider-specific path.

**Tech Stack:** Java 8, Spring Boot, MyBatis-Plus, JUnit 4, Mockito, Maven, Playwright, MySQL, Redis

---

### Task 1: Lock the Routing Contract With Unit Tests

**Files:**
- Modify: `backend/crmeb-front/src/test/java/com/zbkj/front/service/impl/DevMockOrderPayServiceImplTest.java`
- Modify: `backend/crmeb-service/src/test/java/com/zbkj/service/service/impl/StoreOrderServiceImplTest.java`

- [ ] **Step 1: Assert that mock payment writes a transaction marker**

Add this assertion to `payMarksOrderPaidAndEnqueuesAfterPayTask` after capturing
the updated order:

```java
Assert.assertEquals(
        Constants.DEV_MOCK_ORDER_TRADE_NO_PREFIX + orderCaptor.getValue().getId(),
        orderCaptor.getValue().getOutTradeNo());
```

Import `com.zbkj.common.constants.Constants`.

- [ ] **Step 2: Add a mock refund routing test**

Create a paid WeChat order whose `outTradeNo` is
`Constants.DEV_MOCK_ORDER_TRADE_NO_PREFIX + order.getId()`. Configure a
`MockEnvironment` with the `dev` profile, set `devMockPayEnabled` to true with
`ReflectionTestUtils`, and use proxy dependencies to record provider and Redis
calls. Assert:

```java
Assert.assertTrue(service.refund(request));
Assert.assertEquals(Integer.valueOf(2), order.getRefundStatus());
Assert.assertFalse(providerCalled.get());
Assert.assertTrue(refundTaskQueued.get());
```

- [ ] **Step 3: Add real-provider isolation tests**

Add one test with an unmarked WeChat order under `dev`, and one marked order
under `prod`. In both cases assert:

```java
Assert.assertTrue(service.refund(request));
Assert.assertEquals(Integer.valueOf(3), order.getRefundStatus());
Assert.assertTrue(providerCalled.get());
Assert.assertFalse(refundTaskQueued.get());
```

- [ ] **Step 4: Run the focused tests and confirm they fail**

Run:

```bash
cd backend
JAVA_HOME=/Users/bytedance/.local/jdks/amazon-corretto-8.jdk/Contents/Home \
  mvn -pl crmeb-service,crmeb-front -am \
  -Dtest=StoreOrderServiceImplTest,DevMockOrderPayServiceImplTest \
  -Dsurefire.failIfNoSpecifiedTests=false test
```

Expected: failures because the marker constant and mock refund routing do not
exist yet.

### Task 2: Mark Mock Payments and Route Their Refunds

**Files:**
- Modify: `backend/crmeb-common/src/main/java/com/zbkj/common/constants/Constants.java`
- Modify: `backend/crmeb-front/src/main/java/com/zbkj/front/service/impl/DevMockOrderPayServiceImpl.java`
- Modify: `backend/crmeb-service/src/main/java/com/zbkj/service/service/impl/StoreOrderServiceImpl.java`
- Modify: `backend/crmeb-admin/src/main/resources/application-dev.yml`

- [ ] **Step 1: Add the shared marker constant**

Add beside the payment type constants:

```java
public static final String DEV_MOCK_ORDER_TRADE_NO_PREFIX = "devmock";
```

- [ ] **Step 2: Persist the marker during mock payment**

Import `Constants` and extend the mock payment update:

```java
StoreOrder updateOrder = new StoreOrder()
        .setId(storeOrder.getId())
        .setPayType(payType)
        .setIsChannel(PayConstants.PAY_TYPE_WE_CHAT.equals(payType)
                ? CHANNEL_WE_CHAT_H5 : CHANNEL_ALI_PAY)
        .setOutTradeNo(Constants.DEV_MOCK_ORDER_TRADE_NO_PREFIX + storeOrder.getId())
        .setUpdateTime(DateUtil.date());
```

- [ ] **Step 3: Add the environment-safe mock check**

Inject the feature flag and Spring environment into `StoreOrderServiceImpl`:

```java
@Value("${crmeb.payment.dev-mock-pay.enabled:false}")
private Boolean devMockPayEnabled;

@Autowired
private Environment environment;
```

Add imports for `Value`, `Environment`, and `Profiles`, then add:

```java
private boolean isDevMockPayment(StoreOrder storeOrder) {
    return Boolean.TRUE.equals(devMockPayEnabled)
            && environment.acceptsProfiles(Profiles.of("dev"))
            && StringUtils.startsWith(
                    storeOrder.getOutTradeNo(),
                    Constants.DEV_MOCK_ORDER_TRADE_NO_PREFIX);
}
```

- [ ] **Step 4: Skip providers only for marked mock orders**

At the start of the provider routing block, compute:

```java
boolean isDevMockPayment = isDevMockPayment(storeOrder);
```

Guard both positive-amount provider calls with `!isDevMockPayment`. Set status
with:

```java
boolean isBalancePayment = Constants.PAY_TYPE_YUE.equals(storeOrder.getPayType());
boolean isImmediateRefund = isBalancePayment || isDevMockPayment;
storeOrder.setRefundStatus(isImmediateRefund ? 2 : 3);
```

Inside the existing transaction, enqueue a marked mock refund and reject queue
failure:

```java
if (isDevMockPayment
        && !redisUtil.lPush(
                Constants.ORDER_TASK_REDIS_KEY_AFTER_REFUND_BY_USER,
                storeOrder.getId())) {
    throw new CrmebException("退款后续任务提交失败，请稍后重试");
}
```

Exclude mock orders from the two existing zero-value external-payment branches
to avoid duplicate queue entries.

- [ ] **Step 5: Enable the existing feature flag for the admin dev profile**

Add to `backend/crmeb-admin/src/main/resources/application-dev.yml`:

```yaml
crmeb:
  payment:
    dev-mock-pay:
      enabled: true
```

- [ ] **Step 6: Run the focused unit tests**

Run the Maven command from Task 1.

Expected: all `StoreOrderServiceImplTest` and
`DevMockOrderPayServiceImplTest` tests pass.

### Task 3: Add End-to-End Refund Coverage

**Files:**
- Modify: `tests/e2e/specs/h5-payment-order-state.spec.mjs`

- [ ] **Step 1: Verify the marker after mock payment**

Expand the WeChat query and assertion:

```javascript
const row = queryRows(
  `SELECT id, paid, pay_type, is_channel, out_trade_no
   FROM eb_store_order
   WHERE order_id = ${sqlQuote(wechatOrder.orderNo)}`,
)[0];
expect(row.slice(1, 4)).toEqual(['1', 'weixin', '2']);
expect(row[4]).toBe(`devmock${row[0]}`);
```

- [ ] **Step 2: Refund WeChat and Alipay through the admin API**

For each mock-paid order, read the persisted payment amount and call:

```javascript
const refundAmount = queryScalar(
  `SELECT pay_price
   FROM eb_store_order
   WHERE order_id = ${sqlQuote(order.orderNo)}`,
);
await expectBusinessOk(fixtures.adminApi, '/api/admin/store/order/refund', {
  token: fixtures.adminToken,
  query: { orderNo: order.orderNo, amount: refundAmount },
});
expect(
  queryRows(
    `SELECT refund_status, refund_price
     FROM eb_store_order
     WHERE order_id = ${sqlQuote(order.orderNo)}`,
  )[0],
).toEqual(['2', String(Number(refundAmount).toFixed(2))]);
```

- [ ] **Step 3: Verify duplicate refund rejection**

Call the same refund endpoint again with `allowHttpError: true`, then assert:

```javascript
expectBusinessFailure(duplicate, /已退款|请勿重复操作/);
```

- [ ] **Step 4: Run the focused Playwright spec**

Run:

```bash
cd tests/e2e
npx playwright test specs/h5-payment-order-state.spec.mjs --project=h5-mobile
```

Expected: all payment and refund state tests pass with no external payment
provider calls.

### Task 4: Repair and Verify the Current Failing Order

**Files:**
- Data repair only: local `dexter_dianshang.eb_store_order`

- [ ] **Step 1: Build the affected backend modules**

Run:

```bash
cd backend
JAVA_HOME=/Users/bytedance/.local/jdks/amazon-corretto-8.jdk/Contents/Home \
  mvn -pl crmeb-admin,crmeb-front -am -DskipTests package
```

Expected: Maven reports `BUILD SUCCESS`.

- [ ] **Step 2: Restart admin and front services with the dev profile**

Stop only the existing processes bound to ports `8080` and `8081`, then start:

```bash
cd backend
/Users/bytedance/.local/jdks/amazon-corretto-8.jdk/Contents/Home/bin/java \
  -jar crmeb-admin/target/Crmeb-admin.jar --spring.profiles.active=dev
/Users/bytedance/.local/jdks/amazon-corretto-8.jdk/Contents/Home/bin/java \
  -jar crmeb-front/target/Crmeb-front.jar --spring.profiles.active=dev
```

Expected: both ports listen and health endpoints return successful JSON.

- [ ] **Step 3: Mark the confirmed legacy mock order**

Run:

```sql
UPDATE eb_store_order
SET out_trade_no = CONCAT('devmock', id)
WHERE order_id = 'order68555179277398143945396'
  AND paid = 1
  AND pay_type = 'weixin'
  AND out_trade_no IS NULL;
```

Expected: exactly one row is updated.

- [ ] **Step 4: Retry the refund through the admin API**

Use the local admin token and call:

```text
GET /api/admin/store/order/refund
    ?orderNo=order68555179277398143945396
    &amount=286.23
```

Expected: business success, `refund_status = 2`, `refund_price = 286.23`, and
no new `微信申请退款失败` log entry.

- [ ] **Step 5: Run final regression checks**

Run the focused unit tests again, run `git diff --check`, and inspect the final
diff. Do not commit the implementation files because they contain pre-existing
uncommitted acceptance work; report the exact changed files and test results.
