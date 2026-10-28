# Development Fixed SMS Code Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Spring `dev` environment use fixed SMS verification code `123456` without calling OnePass, while every other environment keeps the existing random real-SMS behavior.

**Architecture:** Add a double gate inside `SmsServiceImpl`: the feature flag must be enabled and the active Spring Profile must include `dev`. The development branch writes the fixed code and existing cooldown key to Redis using the configured expiry; the production branch is left unchanged.

**Tech Stack:** Java 8, Spring Boot 2.2, Spring `Environment`, Redis, Maven, JUnit 4, Mockito

---

## File Map

| File | Responsibility |
|---|---|
| `backend/crmeb-service/pom.xml` | Provide Spring Boot test and Mockito dependencies for the new service test. |
| `backend/crmeb-service/src/test/java/com/zbkj/service/service/impl/SmsServiceImplDevFixedCodeTest.java` | Prove development fixed-code behavior and production isolation. |
| `backend/crmeb-service/src/main/java/com/zbkj/service/service/impl/SmsServiceImpl.java` | Route `dev` requests to Redis-only fixed-code delivery and preserve existing real SMS logic elsewhere. |
| `backend/crmeb-front/src/main/resources/application-dev.yml` | Enable fixed code `123456` only for the front API development profile. |
| `功能验收测试报告.md` | Record the fixed-code security boundary and final verification results. |

### Task 1: Add Failing Service Tests

**Files:**
- Modify: `backend/crmeb-service/pom.xml`
- Create: `backend/crmeb-service/src/test/java/com/zbkj/service/service/impl/SmsServiceImplDevFixedCodeTest.java`

- [ ] **Step 1: Add the test dependency**

Add this dependency after the existing JUnit dependency in `backend/crmeb-service/pom.xml`:

```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-test</artifactId>
    <scope>test</scope>
</dependency>
```

- [ ] **Step 2: Create the failing test class**

Create `backend/crmeb-service/src/test/java/com/zbkj/service/service/impl/SmsServiceImplDevFixedCodeTest.java`:

```java
package com.zbkj.service.service.impl;

import com.zbkj.common.constants.Constants;
import com.zbkj.common.constants.SmsConstants;
import com.zbkj.common.exception.CrmebException;
import com.zbkj.common.utils.RedisUtil;
import com.zbkj.service.service.OnePassService;
import com.zbkj.service.service.SystemConfigService;
import com.zbkj.service.service.UserService;
import org.junit.Assert;
import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.MockitoJUnitRunner;
import org.springframework.mock.env.MockEnvironment;
import org.springframework.test.util.ReflectionTestUtils;

import java.util.concurrent.TimeUnit;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@RunWith(MockitoJUnitRunner.class)
public class SmsServiceImplDevFixedCodeTest {

    private static final String PHONE = "13900009998";
    private static final String CODE_KEY = SmsConstants.SMS_VALIDATE_PHONE + PHONE;
    private static final String RATE_KEY = SmsConstants.SMS_VALIDATE_PHONE_NUM + PHONE;

    @InjectMocks
    private SmsServiceImpl smsService;

    @Mock
    private SystemConfigService systemConfigService;

    @Mock
    private RedisUtil redisUtil;

    @Mock
    private UserService userService;

    @Mock
    private OnePassService onePassService;

    private MockEnvironment environment;

    @Before
    public void setUp() {
        environment = new MockEnvironment();
        environment.setActiveProfiles("dev");
        ReflectionTestUtils.setField(smsService, "environment", environment);
        ReflectionTestUtils.setField(smsService, "devFixedCodeEnabled", true);
        ReflectionTestUtils.setField(smsService, "devFixedCode", "123456");
        when(userService.getValidateCodeRedisKey(PHONE)).thenReturn(CODE_KEY);
    }

    @Test
    public void devProfileStoresFixedCodeWithoutCallingOnePass() {
        when(redisUtil.exists(RATE_KEY)).thenReturn(false);
        when(systemConfigService.getValueByKey(Constants.CONFIG_KEY_SMS_CODE_EXPIRE))
                .thenReturn("3");

        Assert.assertTrue(smsService.sendCommonCode(PHONE));

        verify(redisUtil).set(CODE_KEY, "123456", 3L, TimeUnit.MINUTES);
        verify(redisUtil).set(RATE_KEY, 1, 60L);
        verify(onePassService, never()).checkAccount();
        verify(onePassService, never()).info();
    }

    @Test
    public void devProfileKeepsSixtySecondRateLimit() {
        when(redisUtil.exists(RATE_KEY)).thenReturn(true);

        assertCrmebException(
                "您的短信发送过于频繁，请稍后再试",
                () -> smsService.sendCommonCode(PHONE));

        verify(redisUtil, never()).set(
                eq(CODE_KEY), any(), anyLong(), any(TimeUnit.class));
        verify(onePassService, never()).checkAccount();
    }

    @Test
    public void disabledFlagUsesExistingOnePassPath() {
        ReflectionTestUtils.setField(smsService, "devFixedCodeEnabled", false);
        when(onePassService.checkAccount()).thenReturn(false);

        assertCrmebException(
                "发送短信请先登录一号通账号",
                () -> smsService.sendCommonCode(PHONE));

        verify(onePassService).checkAccount();
        verify(redisUtil, never()).set(
                eq(CODE_KEY), any(), anyLong(), any(TimeUnit.class));
    }

    @Test
    public void nonDevProfileIgnoresEnabledFlag() {
        environment.setActiveProfiles("prod");
        when(onePassService.checkAccount()).thenReturn(false);

        assertCrmebException(
                "发送短信请先登录一号通账号",
                () -> smsService.sendCommonCode(PHONE));

        verify(onePassService).checkAccount();
        verify(redisUtil, never()).set(
                eq(CODE_KEY), any(), anyLong(), any(TimeUnit.class));
    }

    @Test
    public void invalidFixedCodeIsRejectedWithoutRedisWrite() {
        ReflectionTestUtils.setField(smsService, "devFixedCode", "12345");
        when(redisUtil.exists(RATE_KEY)).thenReturn(false);

        assertCrmebException(
                "开发环境固定验证码必须为6位数字",
                () -> smsService.sendCommonCode(PHONE));

        verify(redisUtil, never()).set(
                eq(CODE_KEY), any(), anyLong(), any(TimeUnit.class));
        verify(onePassService, never()).checkAccount();
    }

    private void assertCrmebException(String expectedMessage, Runnable action) {
        try {
            action.run();
            Assert.fail("Expected CrmebException");
        } catch (CrmebException exception) {
            Assert.assertEquals(expectedMessage, exception.getMessage());
        }
    }
}
```

- [ ] **Step 3: Run the test and confirm it fails for the missing feature**

Run:

```bash
cd backend
mvn -pl crmeb-service -am clean \
  -Dtest=SmsServiceImplDevFixedCodeTest \
  -Dsurefire.failIfNoSpecifiedTests=false test
```

Expected: `SmsServiceImplDevFixedCodeTest` fails because fields such as `devFixedCodeEnabled` and the development branch do not exist yet. Do not accept a build that reports no matching tests.

- [ ] **Step 4: Commit the failing test**

```bash
git add backend/crmeb-service/pom.xml \
  backend/crmeb-service/src/test/java/com/zbkj/service/service/impl/SmsServiceImplDevFixedCodeTest.java
git commit -m "test: cover development fixed sms code"
```

### Task 2: Implement the Profile-Gated Fixed Code

**Files:**
- Modify: `backend/crmeb-service/src/main/java/com/zbkj/service/service/impl/SmsServiceImpl.java:1-75`
- Modify: `backend/crmeb-service/src/main/java/com/zbkj/service/service/impl/SmsServiceImpl.java:320-348`
- Modify: `backend/crmeb-front/src/main/resources/application-dev.yml:1-7`
- Test: `backend/crmeb-service/src/test/java/com/zbkj/service/service/impl/SmsServiceImplDevFixedCodeTest.java`

- [ ] **Step 1: Add imports and injected configuration**

Add these imports to `SmsServiceImpl.java`:

```java
import com.zbkj.common.constants.RegularConstants;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.env.Environment;
import org.springframework.core.env.Profiles;
```

Add these fields after `onePassService`:

```java
@Autowired
private Environment environment;

@Value("${crmeb.sms.dev-fixed-code.enabled:false}")
private boolean devFixedCodeEnabled;

@Value("${crmeb.sms.dev-fixed-code.value:}")
private String devFixedCode;
```

- [ ] **Step 2: Route only `dev` requests to the fixed-code branch**

Replace `sendCommonCode` with:

```java
@Override
public Boolean sendCommonCode(String phone) {
    ValidateFormUtil.isPhone(phone, "手机号码错误");
    if (isDevFixedCodeEnabled()) {
        validateCodeSendFrequency(phone);
        return sendDevFixedCode(phone);
    }

    Boolean checkAccount = onePassService.checkAccount();
    if (!checkAccount) {
        throw new CrmebException("发送短信请先登录一号通账号");
    }
    JSONObject info = onePassService.info();
    JSONObject smsObject = info.getJSONObject("sms");
    Integer open = smsObject.getInteger("open");
    if (!open.equals(1)) {
        throw new CrmebException("发送短信请先开通一号通账号服务");
    }
    if (smsObject.getInteger("num") <= 0) {
        throw new CrmebException("一号通账号服务余量不足");
    }
    validateCodeSendFrequency(phone);
    return sendSms(phone, SmsConstants.SMS_CONFIG_TYPE_VERIFICATION_CODE, null);
}
```

- [ ] **Step 3: Add the private development helpers**

Add these methods immediately after `sendCommonCode`:

```java
private boolean isDevFixedCodeEnabled() {
    return devFixedCodeEnabled
            && environment.acceptsProfiles(Profiles.of("dev"));
}

private void validateCodeSendFrequency(String phone) {
    if (redisUtil.exists(SmsConstants.SMS_VALIDATE_PHONE_NUM + phone)) {
        throw new CrmebException("您的短信发送过于频繁，请稍后再试");
    }
}

private Boolean sendDevFixedCode(String phone) {
    if (StrUtil.isBlank(devFixedCode)
            || !devFixedCode.matches(RegularConstants.VALIDATE_CODE_NUM_SIX)) {
        throw new CrmebException("开发环境固定验证码必须为6位数字");
    }

    String codeExpireStr =
            systemConfigService.getValueByKey(Constants.CONFIG_KEY_SMS_CODE_EXPIRE);
    if (StrUtil.isBlank(codeExpireStr) || Integer.parseInt(codeExpireStr) == 0) {
        codeExpireStr = String.valueOf(Constants.NUM_FIVE);
    }

    redisUtil.set(
            userService.getValidateCodeRedisKey(phone),
            devFixedCode,
            Long.valueOf(codeExpireStr),
            TimeUnit.MINUTES);
    redisUtil.set(SmsConstants.SMS_VALIDATE_PHONE_NUM + phone, 1, 60L);
    return Boolean.TRUE;
}
```

- [ ] **Step 4: Enable the feature in front API development config**

Extend the existing `crmeb` block in `backend/crmeb-front/src/main/resources/application-dev.yml`:

```yaml
crmeb:
  version: CRMEB-JAVA-KY-v3.1
  imagePath: /Users/bytedance/Downloads/安卓app/crmeb_java/backend/
  asyncConfig: false
  jwt-secret:
  sms:
    dev-fixed-code:
      enabled: true
      value: ${CRMEB_DEV_SMS_CODE:123456}
```

Do not add this enable flag to `application-prod.yml`, `application-beta.yml`, `application-trip.yml`, or the admin module.

- [ ] **Step 5: Run the focused test**

Run:

```bash
cd backend
mvn -pl crmeb-service -am clean \
  -Dtest=SmsServiceImplDevFixedCodeTest \
  -Dsurefire.failIfNoSpecifiedTests=false test
```

Expected:

```text
Tests run: 5, Failures: 0, Errors: 0, Skipped: 0
BUILD SUCCESS
```

- [ ] **Step 6: Commit the implementation**

```bash
git add backend/crmeb-service/src/main/java/com/zbkj/service/service/impl/SmsServiceImpl.java \
  backend/crmeb-front/src/main/resources/application-dev.yml
git commit -m "feat: add dev fixed sms verification code"
```

### Task 3: Run Backend Regression Tests

**Files:**
- Verify: `backend/pom.xml`
- Verify: all tests under `backend/*/src/test`

- [ ] **Step 1: Run the full backend test suite**

Run:

```bash
cd backend
mvn clean test
```

Expected:

```text
BUILD SUCCESS
Failures: 0
Errors: 0
```

Confirm the output includes `Running com.zbkj.service.service.impl.SmsServiceImplDevFixedCodeTest` and five executed tests.

- [ ] **Step 2: Package both API applications**

Run:

```bash
cd backend
mvn -DskipTests package
```

Expected: all four Maven modules report `SUCCESS`, with fresh:

```text
crmeb-front/target/Crmeb-front.jar
crmeb-admin/target/Crmeb-admin.jar
```

### Task 4: Verify the Real Development Runtime

**Files:**
- Runtime: `backend/crmeb-front/target/Crmeb-front.jar`
- Runtime config: `backend/crmeb-front/src/main/resources/application-dev.yml`
- Data: Redis DB 10

- [ ] **Step 1: Restart only the front API with the new JAR**

Run:

```bash
FRONT_PID="$(lsof -ti tcp:8081)"
if [ -n "$FRONT_PID" ]; then kill "$FRONT_PID"; fi
cd backend
nohup java -jar crmeb-front/target/Crmeb-front.jar \
  --spring.profiles.active=dev \
  > /tmp/crmeb-front-fixed-sms.log 2>&1 &
```

Expected: `lsof -nP -iTCP:8081 -sTCP:LISTEN` shows the new Java process and `/tmp/crmeb-front-fixed-sms.log` reports successful startup.

- [ ] **Step 2: Clear only the dedicated test keys**

Run:

```bash
TEST_PHONE=13900009998
redis-cli -n 10 del \
  "sms:validate:code:${TEST_PHONE}" \
  "sms:validate:phone:${TEST_PHONE}"
```

Expected: Redis deletes zero, one, or two dedicated test keys; no unrelated data is touched.

- [ ] **Step 3: Request the development verification code**

Run:

```bash
curl -sS -X POST \
  "http://127.0.0.1:8081/api/front/sendCode?phone=${TEST_PHONE}" \
  | jq '{code, message}'
```

Expected:

```json
{"code":200,"message":"发送成功"}
```

- [ ] **Step 4: Verify Redis value and TTL without printing the code**

Run:

```bash
test "$(redis-cli -n 10 get "sms:validate:code:${TEST_PHONE}")" = "123456"
TTL="$(redis-cli -n 10 ttl "sms:validate:code:${TEST_PHONE}")"
test "$TTL" -gt 0
test "$TTL" -le 180
test "$(redis-cli -n 10 ttl "sms:validate:phone:${TEST_PHONE}")" -gt 0
```

Expected: all four shell assertions exit with status `0`; no code is printed.

- [ ] **Step 5: Verify the 60-second rate limit**

Run:

```bash
curl -sS -X POST \
  "http://127.0.0.1:8081/api/front/sendCode?phone=${TEST_PHONE}" \
  | jq '{code, message}'
```

Expected: the response message is `您的短信发送过于频繁，请稍后再试`.

- [ ] **Step 6: Consume `123456` through the real phone-login flow**

Run:

```bash
LOGIN_RESPONSE="$(
  curl -sS -X POST \
    "http://127.0.0.1:8081/api/front/login/mobile" \
    -H 'Content-Type: application/json' \
    --data "{\"phone\":\"${TEST_PHONE}\",\"captcha\":\"123456\",\"spread_spid\":0}"
)"
test "$(printf '%s' "$LOGIN_RESPONSE" | jq -r '.code')" = "200"
test "$(printf '%s' "$LOGIN_RESPONSE" | jq -r '.data.token | length > 20')" = "true"
test "$(redis-cli -n 10 exists "sms:validate:code:${TEST_PHONE}")" = "0"
```

Expected: all assertions exit with status `0`. Do not print or persist the returned Token.

- [ ] **Step 7: Confirm no external SMS call occurred**

Run:

```bash
if rg -n "发送短信请先登录一号通账号|一号通账号服务余量不足|ONE_PASS_API_SEND" \
  /tmp/crmeb-front-fixed-sms.log; then
  exit 1
fi
```

Expected: no matches and exit status `0`.

### Task 5: Record Evidence and Final Audit

**Files:**
- Modify: `功能验收测试报告.md`
- Verify: `docs/superpowers/specs/2026-10-18-dev-fixed-sms-code-design.md`

- [ ] **Step 1: Add the fixed-code verification section**

Append this section before the final conclusion in `功能验收测试报告.md`:

```markdown
## 开发环境固定短信验证码

- 仅 Spring `dev` Profile 且显式开关开启时使用固定验证码 `123456`。
- 固定码写入 Redis DB 10，沿用当前 3 分钟有效期和 60 秒发送间隔。
- 接口响应和服务日志不返回验证码。
- 开发分支不调用一号通或其他第三方短信服务。
- `prod`、`beta`、`trip` 和管理 API 未开启固定码。
- 定向单元测试 5/5 通过，后端全量测试通过。
- 真实接口已验证发送、限流、验证码登录及成功消费后删除。
```

- [ ] **Step 2: Audit production isolation**

Run:

```bash
rg -n "dev-fixed-code|123456" \
  backend/crmeb-front/src/main/resources/application-prod.yml \
  backend/crmeb-front/src/main/resources/application-beta.yml \
  backend/crmeb-front/src/main/resources/application-trip.yml \
  backend/crmeb-admin/src/main/resources \
  || true
```

Expected: no enable flag or fixed code appears outside `application-dev.yml`.

- [ ] **Step 3: Audit secrets and accidental response exposure**

Run:

```bash
rg -n "devFixedCode|dev-fixed-code" \
  backend/crmeb-service/src/main/java \
  backend/crmeb-front/src/main/java
```

Expected: matches occur only in `SmsServiceImpl` configuration and internal helper logic. No Controller response includes the fixed code.

- [ ] **Step 4: Review the final scoped diff**

Run:

```bash
git diff --ignore-space-at-eol -- \
  backend/crmeb-service/pom.xml \
  backend/crmeb-service/src/test/java/com/zbkj/service/service/impl/SmsServiceImplDevFixedCodeTest.java \
  backend/crmeb-service/src/main/java/com/zbkj/service/service/impl/SmsServiceImpl.java \
  backend/crmeb-front/src/main/resources/application-dev.yml \
  功能验收测试报告.md
```

Expected: only the test dependency, five tests, profile-gated implementation, development config, and report evidence are present.

- [ ] **Step 5: Commit the evidence**

```bash
git add 功能验收测试报告.md
git commit -m "docs: record dev fixed sms verification"
```

## Completion Criteria

- Development SMS requests succeed without OnePass and store `123456`.
- Redis TTL follows `sms_code_expire`; resend cooldown remains 60 seconds.
- Fixed code is consumed by the existing login flow and deleted afterward.
- Fixed code cannot activate outside Spring `dev`.
- API responses and logs do not expose the verification code.
- Focused tests, full backend tests, packaging, and runtime integration checks pass.
- No unrelated worktree changes are reverted or included in commits.
