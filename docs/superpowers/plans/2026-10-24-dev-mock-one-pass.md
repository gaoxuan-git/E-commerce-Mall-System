# 开发环境一号通全量模拟 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 Spring `dev` 环境中完整模拟现有一号通能力，禁止访问真实一号通，并移除管理后台可见的一号通品牌与密钥配置提示。

**Architecture:** 所有指向 `sms.crmeb.net` 的请求统一经过 `OnePassUtil`。`dev` Profile 与 `crmeb.one-pass.dev-mock.enabled` 同时开启时，由独立的 `OnePassDevMockResponseFactory` 按 API 路径返回稳定契约；未知路径直接失败，绝不回退真实网络。业务服务继续解析原有响应结构，生产环境保持当前 HTTP、密钥和 Token 流程。

**Tech Stack:** Java 8、Spring Boot、Fastjson、JUnit 4、Mockito、Vue 3、Vite、Vitest、Playwright、MySQL

---

## 工作区约束

当前工作区包含退款验收及其他未提交改动，不得重置或覆盖。每次提交前只暂存本任务新增文件和明确修改的代码块，并执行：

```bash
git diff --cached --check
git diff --cached --name-status
```

共享脏文件包括：

- `backend/crmeb-admin/src/main/resources/application-dev.yml`
- `backend/crmeb-front/src/main/resources/application-dev.yml`
- `backend/crmeb-service/src/main/java/com/zbkj/service/service/impl/StoreOrderServiceImpl.java`
- `frontend/admin/src/views/sms/smsConfig/config.vue`

修改这些文件时必须保留现有内容，只追加本计划所述差异。

## 文件结构

### 新建

- `backend/crmeb-service/src/main/java/com/zbkj/service/support/OnePassDevMockResponseFactory.java`
  - 唯一职责：根据一号通 API 路径及表单参数生成开发模拟响应。
- `backend/crmeb-service/src/test/java/com/zbkj/service/support/OnePassDevMockResponseFactoryTest.java`
  - 覆盖所有模拟响应契约和未知接口拒绝行为。
- `backend/crmeb-service/src/test/java/com/zbkj/service/util/OnePassUtilDevMockTest.java`
  - 覆盖 `dev` 双重开关、密钥绕过及禁止真实 HTTP。
- `backend/crmeb-service/src/test/java/com/zbkj/service/service/impl/OnePassServiceImplDevMockTest.java`
  - 覆盖账号状态、面单、物流、商品采集和寄件解析。
- `backend/crmeb-service/src/test/java/com/zbkj/service/service/impl/StoreOrderServiceImplDevMockShipmentTest.java`
  - 覆盖模拟寄件运单号写入订单。
- `frontend/admin/tests/unit/views/SmsConfigDevMock.spec.js`
  - 覆盖开发构建显示本地服务状态且不渲染 iframe。
- `backend/sql/dev-one-pass-mock-labels.sql`
  - 仅用于当前开发数据库，把动态菜单和配置表单文案改为中性名称。
- `tests/e2e/specs/dev-one-pass-mock.spec.mjs`
  - 覆盖模板、寄件列表和订单寄件全链路。

### 修改

- `backend/crmeb-service/src/main/java/com/zbkj/service/util/OnePassUtil.java`
  - 增加开发模拟启用判断并接入响应工厂。
- `backend/crmeb-service/src/main/java/com/zbkj/service/service/impl/SmsServiceImpl.java`
  - 移除绕过 `OnePassUtil` 的两处短信直连。
- `backend/crmeb-service/src/main/java/com/zbkj/service/service/impl/OnePassServiceImpl.java`
  - 开发模拟视为账号可用，并调整模拟日志。
- `backend/crmeb-service/src/main/java/com/zbkj/service/service/impl/StoreOrderServiceImpl.java`
  - 商家寄件把返回运单号写入 `deliveryId` 和 `shipmentNum`。
- `backend/crmeb-admin/src/main/resources/application-dev.yml`
- `backend/crmeb-front/src/main/resources/application-dev.yml`
  - 开启开发模拟。
- `frontend/admin/src/views/sms/smsConfig/config.vue`
  - 开发构建显示本地模拟服务状态，不加载外部 iframe。
- `frontend/admin/src/router/modules/operation.js`
  - 开发构建使用“本地服务”菜单名。
- `frontend/admin/src/views/store/creatStore/index.vue`
  - 开发构建使用“本地模拟采集”说明。
- `frontend/admin/src/views/order/orderSend.vue`
  - 商家寄件选择快递公司时同步普通发货所需的快递编码和名称。

## Task 1：建立模拟响应工厂并锁定契约

**Files:**

- Create: `backend/crmeb-service/src/main/java/com/zbkj/service/support/OnePassDevMockResponseFactory.java`
- Create: `backend/crmeb-service/src/test/java/com/zbkj/service/support/OnePassDevMockResponseFactoryTest.java`

- [ ] **Step 1：先写失败的响应契约测试**

测试必须覆盖登录、账号信息、短信、模板、快递公司、面单模板、面单打印、
寄件、物流和商品采集。使用 Java 8 写法，不使用 `Map.of`。

```java
@RunWith(MockitoJUnitRunner.class)
public class OnePassDevMockResponseFactoryTest {

    private OnePassDevMockResponseFactory factory;

    @Before
    public void setUp() {
        factory = new OnePassDevMockResponseFactory();
    }

    @Test
    public void accountInfoEnablesEveryLocalCapability() {
        JSONObject response = factory.create(
                OnePassConstants.ONE_PASS_API_URL + OnePassConstants.USER_INFO_URI,
                null);

        JSONObject data = response.getJSONObject("data");
        Assert.assertEquals(Integer.valueOf(1), data.getJSONObject("sms").getInteger("open"));
        Assert.assertEquals(Integer.valueOf(9999), data.getJSONObject("sms").getInteger("num"));
        Assert.assertEquals(Integer.valueOf(1), data.getJSONObject("dump").getInteger("open"));
        Assert.assertEquals(Integer.valueOf(9999), data.getJSONObject("copy").getInteger("num"));
        Assert.assertEquals(Integer.valueOf(9999), data.getJSONObject("query").getInteger("num"));
    }

    @Test
    public void expressTemplateMatchesAdminContract() {
        JSONObject response = factory.create(
                OnePassConstants.ONE_PASS_API_URL
                        + OnePassConstants.ONE_PASS_API_EXPRESS_TEMP_URI
                        + "?com=yunda&is_shipment=1",
                null);

        JSONArray templates = response.getJSONObject("data").getJSONArray("data");
        Assert.assertFalse(templates.isEmpty());
        Assert.assertTrue(templates.getJSONObject(0).containsKey("temp_id"));
        Assert.assertTrue(templates.getJSONObject(0).containsKey("pic"));
    }

    @Test
    public void dynamicResponsesReuseRequestValues() {
        LinkedMultiValueMap<String, Object> params = new LinkedMultiValueMap<>();
        params.add("com", "yunda");
        params.add("num", "DEV123");

        JSONObject response = factory.create(
                OnePassConstants.ONE_PASS_API_URL
                        + OnePassConstants.ONE_PASS_API_EXPRESS_QUEARY_URI,
                params);

        Assert.assertEquals("yunda", response.getJSONObject("data").getString("com"));
        Assert.assertEquals("DEV123", response.getJSONObject("data").getString("num"));
        Assert.assertFalse(response.getJSONObject("data").getJSONArray("content").isEmpty());
    }

    @Test
    public void unknownEndpointFailsClosed() {
        try {
            factory.create(OnePassConstants.ONE_PASS_API_URL + "v2/unknown", null);
            Assert.fail("Expected CrmebException");
        } catch (CrmebException exception) {
            Assert.assertTrue(exception.getMessage().contains("开发模拟未实现该接口"));
        }
    }
}
```

- [ ] **Step 2：运行测试并确认失败**

```bash
cd backend
./mvnw -pl crmeb-service -am \
  -Dtest=OnePassDevMockResponseFactoryTest \
  -Dsurefire.failIfNoSpecifiedTests=false test
```

Expected: `FAIL`，原因是 `OnePassDevMockResponseFactory` 尚不存在。

- [ ] **Step 3：实现响应工厂**

工厂公开一个入口：

```java
public JSONObject create(String url, MultiValueMap<String, Object> params)
```

端点提取必须去掉 query string，并只接受 `OnePassConstants` 中当前业务实际
使用的路径。基础结构：

```java
@Component
public class OnePassDevMockResponseFactory {

    private static final String PRODUCT_IMAGE =
            "crmebimage/public/open-data/abo-curated-v2/8101-main.jpg";
    private final AtomicLong sequence = new AtomicLong(1000000000L);

    public JSONObject create(String url, MultiValueMap<String, Object> params) {
        String endpoint = endpoint(url);
        if (OnePassConstants.USER_LOGIN_URI.equals(endpoint)) return login();
        if (OnePassConstants.USER_INFO_URI.equals(endpoint)) return accountInfo();
        if (OnePassConstants.ONE_PASS_TEMP_LIST_URI.equals(endpoint)) return smsTemplates();
        if (OnePassConstants.ONE_PASS_APPLYS_LIST_URI.equals(endpoint)) return smsTemplates();
        if (OnePassConstants.ONE_PASS_API_EXPRESS_URI.equals(endpoint)) return expressCompanies();
        if (OnePassConstants.ONE_PASS_API_EXPRESS_TEMP_URI.equals(endpoint)) return expressTemplates();
        if (OnePassConstants.ONE_PASS_API_EXPRESS_DUMP_RECORD_URI.equals(endpoint)) return dumpRecords();
        if (OnePassConstants.ONE_PASS_API_EXPRESS_DUMP_URI.equals(endpoint)) return expressLabel(params);
        if (OnePassConstants.ONE_PASS_API_EXPRESS_QUEARY_URI.equals(endpoint)) return logistics(params);
        if (OnePassConstants.ONE_PASS_API_SHIPMENT_GET_KUAIDI_COMS_URI.equals(endpoint)) return shipmentCompanies();
        if (OnePassConstants.ONE_PASS_API_SHIPMENT_CREATE_ORDER_URI.equals(endpoint)) return shipmentOrder(params);
        if (OnePassConstants.ONE_PASS_API_COPY_GOODS_URI.equals(endpoint)) return product();
        if (isSimpleSuccessEndpoint(endpoint)) return ok(new JSONObject());
        throw new CrmebException("开发模拟未实现该接口: " + endpoint);
    }

    private String endpoint(String url) {
        int apiIndex = url.indexOf("/api/");
        if (apiIndex < 0) throw new CrmebException("开发模拟不接受非一号通地址");
        String endpoint = url.substring(apiIndex + 5);
        int queryIndex = endpoint.indexOf('?');
        return queryIndex >= 0 ? endpoint.substring(0, queryIndex) : endpoint;
    }

    private JSONObject ok(Object data) {
        JSONObject response = new JSONObject();
        response.put("status", 200);
        response.put("msg", "ok");
        response.put("data", data);
        return response;
    }

    private String first(MultiValueMap<String, Object> params, String key, String fallback) {
        if (params == null || params.getFirst(key) == null) return fallback;
        return String.valueOf(params.getFirst(key));
    }
}
```

固定数据要求：

```json
{
  "account": "local-dev-mock",
  "sms": { "open": 1, "num": 9999, "sign": "本地测试" },
  "dump": { "open": 1, "num": 9999 },
  "copy": { "open": 1, "num": 9999 },
  "query": { "open": 1, "num": 9999 }
}
```

快递列表至少包含 `yunda`、`yuantong` 和 `shunfeng`。寄件公司项必须符合
`orderSend.vue` 的契约：

```json
{
  "id": "yunda",
  "label": "韵达快递",
  "value": "yunda",
  "types": ["标准快递"],
  "list": [
    {
      "temp_id": "DEV-YUNDA-001",
      "title": "本地测试面单",
      "pic": "data:image/svg+xml;base64,..."
    }
  ]
}
```

商品响应必须包含：

```json
{
  "store_name": "开发模拟采集商品",
  "store_info": "仅用于本地功能测试",
  "image": "crmebimage/public/open-data/abo-curated-v2/8101-main.jpg",
  "slider_image": "crmebimage/public/open-data/abo-curated-v2/8101-main.jpg",
  "cost": 10.00,
  "price": 19.90,
  "ot_price": 29.90,
  "unit_name": "件",
  "description": "<p>开发模拟商品，不对应真实外部商品。</p>",
  "items": [
    {
      "value": "规格",
      "detail": ["标准版"]
    }
  ],
  "info": {
    "value": [
      {
        "value1": "标准版",
        "pic": "crmebimage/public/open-data/abo-curated-v2/8101-main.jpg",
        "detail": {
          "规格": "标准版"
        }
      }
    ]
  }
}
```

面单 `label` 使用工厂内生成的 Base64 SVG，文字固定为
`DEV MOCK LABEL` 和 `NOT FOR SHIPPING`，不得引用外部图片。

- [ ] **Step 4：运行工厂测试**

```bash
cd backend
./mvnw -pl crmeb-service -am \
  -Dtest=OnePassDevMockResponseFactoryTest \
  -Dsurefire.failIfNoSpecifiedTests=false test
```

Expected: `PASS`。

- [ ] **Step 5：提交工厂和测试**

```bash
git add backend/crmeb-service/src/main/java/com/zbkj/service/support/OnePassDevMockResponseFactory.java
git add backend/crmeb-service/src/test/java/com/zbkj/service/support/OnePassDevMockResponseFactoryTest.java
git commit -m "feat: add development one-pass response factory"
```

## Task 2：把 OnePassUtil 变成强制隔离边界

**Files:**

- Modify: `backend/crmeb-service/src/main/java/com/zbkj/service/util/OnePassUtil.java`
- Create: `backend/crmeb-service/src/test/java/com/zbkj/service/util/OnePassUtilDevMockTest.java`
- Modify: `backend/crmeb-admin/src/main/resources/application-dev.yml`
- Modify: `backend/crmeb-front/src/main/resources/application-dev.yml`

- [ ] **Step 1：写失败的隔离测试**

```java
@RunWith(MockitoJUnitRunner.class)
public class OnePassUtilDevMockTest {

    @InjectMocks
    private OnePassUtil onePassUtil;

    @Mock private SystemConfigService systemConfigService;
    @Mock private RestTemplateUtil restTemplateUtil;
    @Mock private RedisUtil redisUtil;
    @Mock private OnePassDevMockResponseFactory responseFactory;

    private MockEnvironment environment;

    @Before
    public void setUp() {
        environment = new MockEnvironment();
        environment.setActiveProfiles("dev");
        ReflectionTestUtils.setField(onePassUtil, "environment", environment);
        ReflectionTestUtils.setField(onePassUtil, "devMockEnabled", true);
    }

    @Test
    public void devMockUsesLocalCredentialsWithoutConfigOrRedis() {
        OnePassLoginVo login = onePassUtil.getLoginVo();

        Assert.assertEquals("local-dev-mock", login.getAccessKey());
        Assert.assertEquals("Bearer-dev-mock-token", onePassUtil.getToken(login));
        verify(systemConfigService, never()).getValueByKey(anyString());
        verify(redisUtil, never()).get(anyString());
    }

    @Test
    public void devMockDelegatesRequestsWithoutHttp() {
        String url = OnePassConstants.ONE_PASS_API_URL + OnePassConstants.USER_INFO_URI;
        JSONObject expected = new JSONObject();
        when(responseFactory.create(eq(url), isNull())).thenReturn(expected);

        Assert.assertSame(expected, onePassUtil.postFrom(url, null, null));
        verify(restTemplateUtil, never()).postFromUrlencoded(anyString(), any(), any());
    }

    @Test
    public void nonDevCannotUseMockFlag() {
        environment.setActiveProfiles("prod");
        when(systemConfigService.getValueByKey(OnePassConstants.ONE_PASS_ACCESS_KEY))
                .thenReturn("");

        try {
            onePassUtil.getLoginVo();
            Assert.fail("Expected CrmebException");
        } catch (CrmebException exception) {
            Assert.assertTrue(exception.getMessage().contains("accessKey"));
        }
    }
}
```

- [ ] **Step 2：运行测试确认失败**

```bash
cd backend
./mvnw -pl crmeb-service -am \
  -Dtest=OnePassUtilDevMockTest \
  -Dsurefire.failIfNoSpecifiedTests=false test
```

Expected: `FAIL`，因为配置字段和模拟分支尚不存在。

- [ ] **Step 3：实现双重开关和三个请求出口**

在 `OnePassUtil` 注入：

```java
@Autowired
private Environment environment;

@Autowired
private OnePassDevMockResponseFactory devMockResponseFactory;

@Value("${crmeb.one-pass.dev-mock.enabled:false}")
private boolean devMockEnabled;

public boolean isDevMockEnabled() {
    return devMockEnabled && environment.acceptsProfiles(Profiles.of("dev"));
}
```

开发登录和 Token：

```java
if (isDevMockEnabled()) {
    OnePassLoginVo loginVo = new OnePassLoginVo();
    loginVo.setAccessKey("local-dev-mock");
    loginVo.setSecretKey("local-dev-mock-secret");
    return loginVo;
}
```

`getToken()` 和 `getToken(OnePassLoginVo)` 在模拟模式直接返回
`Bearer-dev-mock-token`，不读写 Redis。

三个请求方法都先执行：

```java
if (isDevMockEnabled()) {
    logger.info("[DEV MOCK] One-pass request: {}", url);
    return devMockResponseFactory.create(url, param);
}
```

其中 `getData(String, Map)` 没有表单参数，传 `null`。模拟关闭时保留现有
`RestTemplateUtil` 和 `checkResult` 行为。

- [ ] **Step 4：在两个 dev 配置中开启模拟**

在既有 `crmeb` 节点下追加，不覆盖支付和短信配置：

```yaml
one-pass:
  dev-mock:
    enabled: true
```

- [ ] **Step 5：运行隔离测试和工厂测试**

```bash
cd backend
./mvnw -pl crmeb-service -am \
  -Dtest=OnePassUtilDevMockTest,OnePassDevMockResponseFactoryTest \
  -Dsurefire.failIfNoSpecifiedTests=false test
```

Expected: 全部 `PASS`，Mockito 验证真实 HTTP 和 Redis Token 均未调用。

- [ ] **Step 6：提交隔离边界**

共享 YAML 使用精确分块暂存，提交前确认没有带入支付配置改动：

```bash
git add backend/crmeb-service/src/main/java/com/zbkj/service/util/OnePassUtil.java
git add backend/crmeb-service/src/test/java/com/zbkj/service/util/OnePassUtilDevMockTest.java
git add -p backend/crmeb-admin/src/main/resources/application-dev.yml
git add -p backend/crmeb-front/src/main/resources/application-dev.yml
git commit -m "feat: isolate one-pass behind dev mock mode"
```

## Task 3：收口短信直连并验证业务解析

**Files:**

- Modify: `backend/crmeb-service/src/main/java/com/zbkj/service/service/impl/SmsServiceImpl.java`
- Modify: `backend/crmeb-service/src/main/java/com/zbkj/service/service/impl/OnePassServiceImpl.java`
- Create: `backend/crmeb-service/src/test/java/com/zbkj/service/service/impl/OnePassServiceImplDevMockTest.java`

- [ ] **Step 1：写失败的服务解析测试**

```java
@RunWith(MockitoJUnitRunner.class)
public class OnePassServiceImplDevMockTest {

    @InjectMocks private OnePassServiceImpl service;
    @Mock private OnePassUtil onePassUtil;

    @Test
    public void devMockAccountIsAlwaysAvailable() {
        when(onePassUtil.isDevMockEnabled()).thenReturn(true);
        Assert.assertTrue(service.checkAccount());
    }

    @Test
    public void logisticsKeepsRequestedIdentity() {
        when(onePassUtil.getToken()).thenReturn("Bearer-dev-mock-token");
        when(onePassUtil.postFrom(
                contains(OnePassConstants.ONE_PASS_API_EXPRESS_QUEARY_URI),
                any(), any())).thenAnswer(invocation -> {
            JSONObject data = new JSONObject();
            data.put("com", "yunda");
            data.put("num", "DEV123");
            data.put("ischeck", "1");
            data.put("status", "3");
            data.put("content", new JSONArray());
            JSONObject response = new JSONObject();
            response.put("data", data);
            return response;
        });

        OnePassLogisticsQueryVo result = service.exprQuery("DEV123", "yunda", "");
        Assert.assertEquals("DEV123", result.getNum());
        Assert.assertEquals("yunda", result.getCom());
    }
}
```

同时给 `SmsServiceImplDevFixedCodeTest` 增加一条通知短信测试，验证
`OnePassUtil.postFrom` 被调用且 `RestTemplateUtil` 不再存在于服务依赖中。

- [ ] **Step 2：运行测试确认失败**

```bash
cd backend
./mvnw -pl crmeb-service -am \
  -Dtest=OnePassServiceImplDevMockTest,SmsServiceImplDevFixedCodeTest \
  -Dsurefire.failIfNoSpecifiedTests=false test
```

Expected: `FAIL`，`checkAccount()` 仍读取数据库密钥，短信仍直接调用
`RestTemplateUtil`。

- [ ] **Step 3：修改账号校验**

`OnePassServiceImpl.checkAccount()` 开头增加：

```java
if (onePassUtil.isDevMockEnabled()) {
    return Boolean.TRUE;
}
```

开发模拟日志改用 `[DEV MOCK]`，不打印完整寄件参数或手机号。生产日志保持
原行为。

- [ ] **Step 4：移除 SmsServiceImpl 的一号通直连**

将三处路径全部改为：

```java
onePassUtil.postFrom(
        OnePassConstants.ONE_PASS_API_URL + OnePassConstants.ONE_PASS_API_SEND_URI,
        param,
        header);
```

`SmsServiceImpl.postFrom(...)` 直接委托 `onePassUtil.postFrom(...)`。删除仅为
直连存在的 `RestTemplateUtil` 字段、导入和重复 `checkResult(String)`。

异常处理仍返回现有 `false`，但模拟日志只记录：

```java
logger.info("[DEV MOCK] SMS accepted for local delivery");
```

不得输出 Header、Token、验证码或完整手机号。

- [ ] **Step 5：静态检查所有一号通 URL 都已收口**

```bash
grep -RIn "OnePassConstants.ONE_PASS_API_URL" \
  backend/crmeb-service/src/main/java \
  --include='*.java'
```

Expected: 业务类可以构造 URL，但实际请求只能调用 `OnePassUtil`；输出中不得再
出现 `restTemplateUtil.*OnePassConstants.ONE_PASS_API_URL`。

- [ ] **Step 6：运行服务测试**

```bash
cd backend
./mvnw -pl crmeb-service -am \
  -Dtest=OnePassServiceImplDevMockTest,SmsServiceImplDevFixedCodeTest,OnePassUtilDevMockTest,OnePassDevMockResponseFactoryTest \
  -Dsurefire.failIfNoSpecifiedTests=false test
```

Expected: 全部 `PASS`。

- [ ] **Step 7：提交服务收口**

```bash
git add backend/crmeb-service/src/main/java/com/zbkj/service/service/impl/SmsServiceImpl.java
git add backend/crmeb-service/src/main/java/com/zbkj/service/service/impl/OnePassServiceImpl.java
git add backend/crmeb-service/src/test/java/com/zbkj/service/service/impl/OnePassServiceImplDevMockTest.java
git add backend/crmeb-service/src/test/java/com/zbkj/service/service/impl/SmsServiceImplDevFixedCodeTest.java
git commit -m "fix: route one-pass services through dev mock boundary"
```

## Task 4：修正商家寄件订单契约

**Files:**

- Modify: `backend/crmeb-service/src/main/java/com/zbkj/service/service/impl/StoreOrderServiceImpl.java`
- Create: `backend/crmeb-service/src/test/java/com/zbkj/service/service/impl/StoreOrderServiceImplDevMockShipmentTest.java`
- Modify: `frontend/admin/src/views/order/orderSend.vue`

- [ ] **Step 1：写失败的订单寄件测试**

```java
@RunWith(MockitoJUnitRunner.class)
public class StoreOrderServiceImplDevMockShipmentTest {

    @Spy @InjectMocks private StoreOrderServiceImpl service;
    @Mock private OnePassService onePassService;

    @Test
    public void shipmentResponsePopulatesTrackingFields() {
        StoreOrder order = new StoreOrder();
        order.setOrderId("ORDER-DEV-1");
        order.setRealName("测试收件人");
        order.setUserPhone("13900000000");
        order.setUserAddress("测试地址");

        OnePassShipmentCreateOrderRequest shipment = new OnePassShipmentCreateOrderRequest();
        shipment.setKuaidicom("yunda");
        shipment.setSendRealName("测试寄件人");
        StoreOrderSendRequest request = new StoreOrderSendRequest();
        request.setShipment(shipment);

        JSONObject result = new JSONObject();
        result.put("order_id", "DEV-ORDER-1");
        result.put("task_id", "DEV-TASK-1");
        result.put("kuaidinum", "DEV1000000001");
        when(onePassService.shipmentCreateOrder(shipment)).thenReturn(result);

        service.expressForOnePassShipment(request, order);

        Assert.assertEquals("DEV1000000001", order.getDeliveryId());
        Assert.assertEquals("DEV1000000001", order.getShipmentNum());
        Assert.assertEquals("DEV-TASK-1", order.getShipmentTaskId());
    }
}
```

在测试调用前固定数据库更新结果，避免纯单测访问 mapper：

```java
doReturn(true).when(service).updateById(order);
```

- [ ] **Step 2：运行测试确认失败**

```bash
cd backend
./mvnw -pl crmeb-service -am \
  -Dtest=StoreOrderServiceImplDevMockShipmentTest \
  -Dsurefire.failIfNoSpecifiedTests=false test
```

Expected: `FAIL`，`deliveryId` 和 `shipmentNum` 尚未写入。

- [ ] **Step 3：补齐后端运单字段**

在 `expressForOnePassShipment` 解析 `kuaidinum` 后设置：

```java
storeOrder.setDeliveryId(kuaidinum);
storeOrder.setShipmentNum(kuaidinum);
```

保留现有 `shipmentPic`、任务号和订单号写入。外层 `express(...)` 已负责把订单
状态设置为 `1`、写状态日志并发送通知，不新增伪造回调。

- [ ] **Step 4：同步商家寄件的快递编码**

`orderSend.vue` 的 `onChangeShipmentExpress` 找到选中项后同步：

```js
formItem.expressCode = expressItem.value;
formItem.expressName = expressItem.label;
```

这样后端 `expressService.getByCode(request.getExpressCode())` 能取到快递公司。

- [ ] **Step 5：运行后端测试和管理端构建**

```bash
cd backend
./mvnw -pl crmeb-service -am \
  -Dtest=StoreOrderServiceImplDevMockShipmentTest,OnePassServiceImplDevMockTest \
  -Dsurefire.failIfNoSpecifiedTests=false test
```

```bash
cd frontend/admin
npm run build
```

Expected: 测试 `PASS`，Vite 构建成功。

- [ ] **Step 6：提交寄件契约修复**

`StoreOrderServiceImpl.java` 使用分块暂存，只提交上述两个 setter：

```bash
git add -p backend/crmeb-service/src/main/java/com/zbkj/service/service/impl/StoreOrderServiceImpl.java
git add backend/crmeb-service/src/test/java/com/zbkj/service/service/impl/StoreOrderServiceImplDevMockShipmentTest.java
git add frontend/admin/src/views/order/orderSend.vue
git commit -m "fix: complete dev shipment tracking contract"
```

## Task 5：开发后台去除一号通品牌

**Files:**

- Modify: `frontend/admin/src/views/sms/smsConfig/config.vue`
- Modify: `frontend/admin/src/router/modules/operation.js`
- Modify: `frontend/admin/src/views/store/creatStore/index.vue`
- Create: `frontend/admin/tests/unit/views/SmsConfigDevMock.spec.js`
- Create: `backend/sql/dev-one-pass-mock-labels.sql`

- [ ] **Step 1：写失败的短信配置页测试**

```js
import { mount } from '@vue/test-utils';
import SmsConfig from '@/views/sms/smsConfig/config.vue';

describe('SmsConfig development mode', () => {
  it('shows the local service state without rendering an external iframe', () => {
    const wrapper = mount(SmsConfig, {
      global: {
        mocks: {
          $selfUtil: { getTableHeight: () => 720 },
        },
        stubs: {
          'el-result': {
            props: ['title'],
            template: '<div data-test="local-service">{{ title }}</div>',
          },
          'el-empty': true,
        },
      },
    });

    expect(wrapper.get('[data-test="local-service"]').text()).toBe('本地模拟服务运行中');
    expect(wrapper.find('iframe').exists()).toBe(false);
    expect(wrapper.text()).not.toContain('一号通');
  });
});
```

- [ ] **Step 2：运行测试确认失败**

```bash
cd frontend/admin
npm run test:unit -- tests/unit/views/SmsConfigDevMock.spec.js
```

Expected: `FAIL`，当前页面没有本地服务状态。

- [ ] **Step 3：实现开发页面和中性文案**

`smsConfig/config.vue`：

```vue
<el-result
  v-if="isDev"
  icon="success"
  title="本地模拟服务运行中"
/>
<iframe
  v-else-if="onePassUrl"
  ...
/>
<el-empty v-else description="服务未配置" />
```

```js
const isDev = import.meta.env.DEV;
const configuredUrl = import.meta.env.VITE_ONE_PASS_URL || '';
const onePassUrl = configuredUrl || 'https://api.crmeb.com/';
```

`operation.js`：

```js
title: import.meta.env.DEV ? '本地服务' : '一号通配置',
```

`creatStore/index.vue`：

```vue
<div class="tips-bottom" v-if="isDev">
  商品采集设置：设置 > 系统设置 > 第三方接口设置 > 本地模拟采集
</div>
<div class="tips-bottom" v-else>
  商品采集设置：设置 > 系统设置 > 第三方接口设置 >
  采集商品配置（如配置一号通采集，请先登录一号通账号，无一号通，请选择99Api设置）
</div>
```

```js
const isDev = import.meta.env.DEV;
```

- [ ] **Step 4：添加本地数据库文案脚本**

`backend/sql/dev-one-pass-mock-labels.sql` 内容：

```sql
START TRANSACTION;

UPDATE eb_system_menu
SET name = '本地服务'
WHERE component = '/operation/onePassConfig'
  AND name = '一号通配置';

UPDATE eb_category
SET name = '本地模拟服务',
    url = '本地模拟服务'
WHERE id = 836
  AND type = 6;

UPDATE eb_system_form_temp
SET name = '本地模拟服务',
    info = '本地模拟服务'
WHERE id = 173;

UPDATE eb_system_form_temp
SET content = REPLACE(content, '"label":"一号通"', '"label":"本地模拟"')
WHERE id IN (175, 176);

COMMIT;
```

该脚本只用于本地开发数据库，不加入生产升级 SQL。

- [ ] **Step 5：运行前端测试、构建和源码扫描**

```bash
cd frontend/admin
npm run test:unit -- tests/unit/views/SmsConfigDevMock.spec.js
npm run build
```

```bash
grep -RIn "一号通" frontend/admin/src \
  --include='*.vue' --include='*.js' \
  --exclude='iconfont.js' --exclude='iconfont.json'
```

Expected: 测试和构建通过；剩余命中只能是生产分支文案、API 注释或代码标识，
开发页面不得显示该品牌。

- [ ] **Step 6：提交开发界面**

```bash
git add frontend/admin/src/views/sms/smsConfig/config.vue
git add frontend/admin/src/router/modules/operation.js
git add frontend/admin/src/views/store/creatStore/index.vue
git add frontend/admin/tests/unit/views/SmsConfigDevMock.spec.js
git add backend/sql/dev-one-pass-mock-labels.sql
git commit -m "feat: present local services in development admin"
```

## Task 6：增加一号通开发模拟 E2E

**Files:**

- Create: `tests/e2e/specs/dev-one-pass-mock.spec.mjs`

- [ ] **Step 1：写 API 与订单寄件端到端测试**

```js
import { test, expect } from '@playwright/test';
import { expectBusinessOk } from '../helpers/api.mjs';
import { createBuyNowOrder, sqlQuote, waitForScalar } from '../helpers/core.mjs';
import { queryRows } from '../helpers/database.mjs';
import { readRuntimeFixtures } from '../helpers/fixtures.mjs';

test.describe.serial('@one-pass-dev-mock local third-party simulation', () => {
  test('templates and shipment companies work without credentials', async () => {
    const fixtures = readRuntimeFixtures();

    const templates = await expectBusinessOk(
      fixtures.adminApi,
      '/api/admin/express/template',
      {
        token: fixtures.adminToken,
        query: { com: 'yunda' },
      },
    );
    expect(templates.data.data[0]).toMatchObject({ temp_id: 'DEV-YUNDA-001' });

    const shipmentCompanies = await expectBusinessOk(
      fixtures.adminApi,
      '/api/admin/pass/shipment/express',
      { token: fixtures.adminToken },
    );
    expect(shipmentCompanies.data.some((item) => item.value === 'yunda')).toBe(true);
  });

  test('merchant shipment immediately records local tracking data', async () => {
    const fixtures = readRuntimeFixtures();
    const order = await createBuyNowOrder(fixtures, {
      mark: `${fixtures.runId}-dev-shipment-${Date.now()}`,
    });

    await expectBusinessOk(fixtures.frontApi, '/api/front/pay/dev/mock', {
      method: 'POST',
      token: fixtures.h5Token,
      body: { orderNo: order.orderNo, payType: 'weixin' },
    });

    await expectBusinessOk(fixtures.adminApi, '/api/admin/store/order/send', {
      method: 'POST',
      token: fixtures.adminToken,
      body: {
        orderNo: order.orderNo,
        deliveryType: 'express',
        expressRecordType: '3',
        expressCode: 'yunda',
        shipment: {
          kuaidicom: 'yunda',
          sendRealName: '本地测试寄件人',
          sendPhone: '13900000000',
          sendAddress: '本地测试地址',
          serviceType: '标准快递',
          tempid: 'DEV-YUNDA-001',
          dayType: '0',
        },
      },
    });

    await waitForScalar(
      `SELECT status FROM eb_store_order WHERE order_id = ${sqlQuote(order.orderNo)}`,
      (value) => value === '1',
    );
    expect(
      queryRows(
        `SELECT status, delivery_code, delivery_id, shipment_num
           FROM eb_store_order
          WHERE order_id = ${sqlQuote(order.orderNo)}`,
      )[0],
    ).toEqual(['1', 'yunda', expect.stringMatching(/^DEV/), expect.stringMatching(/^DEV/)]);
  });
});
```

- [ ] **Step 2：先在旧服务上运行并确认失败**

```bash
cd tests/e2e
npx playwright test specs/dev-one-pass-mock.spec.mjs
```

Expected: 模板接口返回 `accessKey` 错误，证明测试能复现原问题。

- [ ] **Step 3：执行本地菜单文案 SQL 并重建服务**

```bash
mysql -uroot -p123456 dexter_dianshang < backend/sql/dev-one-pass-mock-labels.sql
```

按项目现有方式重新构建并启动 8080、8081 服务；保持 Redis DB 10 和当前
测试数据库，不重置用户已有数据。

- [ ] **Step 4：运行 E2E**

```bash
cd tests/e2e
npx playwright test specs/dev-one-pass-mock.spec.mjs
```

Expected: 两个测试全部 `PASS`。

- [ ] **Step 5：提交 E2E**

```bash
git add tests/e2e/specs/dev-one-pass-mock.spec.mjs
git commit -m "test: cover development one-pass simulation"
```

## Task 7：全量验证与运行时审计

**Files:**

- Modify only if a test reveals a defect in files already listed above.

- [ ] **Step 1：运行后端受影响单测**

```bash
cd backend
./mvnw -pl crmeb-service -am \
  -Dtest=OnePassDevMockResponseFactoryTest,OnePassUtilDevMockTest,OnePassServiceImplDevMockTest,StoreOrderServiceImplDevMockShipmentTest,SmsServiceImplDevFixedCodeTest,StoreOrderServiceImplTest \
  -Dsurefire.failIfNoSpecifiedTests=false test
```

Expected: 全部 `PASS`。

- [ ] **Step 2：运行管理端测试和构建**

```bash
cd frontend/admin
npm run test:unit
npm run build
```

Expected: Vitest 全部通过，Vite 构建成功。

- [ ] **Step 3：运行核心 E2E 回归**

```bash
cd tests/e2e
npx playwright test --grep "@one-pass-dev-mock|@core"
```

Expected: 新增模拟测试及既有核心流程全部通过。

- [ ] **Step 4：验证当前报错接口**

从 Playwright 管理员登录态读取 Token 后请求：

```bash
ADMIN_TOKEN=$(node -e "const s=JSON.parse(require('fs').readFileSync('tests/e2e/auth/admin.json','utf8')); process.stdout.write(s.cookies.find(c=>c.name==='Authorization').value)")
curl -sS \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -H "X-Source: df07addc462f7f8f" \
  "http://127.0.0.1:8080/api/admin/express/template?com=yunda"
```

Expected: 业务码 `200`，响应包含 `DEV-YUNDA-001`，不包含 `accessKey`。

- [ ] **Step 5：审计外部调用和错误日志**

```bash
grep -RIn "sms.crmeb.net" backend/crmeb_admin_log backend/crmeb_front_log \
  --include='*.log'
```

只检查本次重启后的时间窗口。Expected: 没有新的外部请求记录。

```bash
tail -n 5000 backend/crmeb_admin_log/log_error.log | \
  grep -E "请配置一号通|accessKey|secretKey"
```

Expected: 没有本次验证产生的新错误。

- [ ] **Step 6：检查最终差异**

```bash
git diff --check
git status --short
```

确认没有生成物、日志、数据库导出或用户其他改动被暂存。报告：

- 后端测试通过数。
- 管理端测试通过数。
- E2E 通过数。
- 当前模板接口响应结果。
- 本次验证时间窗口内 `sms.crmeb.net` 新请求数为 0。
