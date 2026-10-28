package com.zbkj.service.support;

import com.alibaba.fastjson.JSONArray;
import com.alibaba.fastjson.JSONObject;
import com.zbkj.common.constants.OnePassConstants;
import com.zbkj.common.exception.CrmebException;
import org.junit.Assert;
import org.junit.Before;
import org.junit.Test;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.util.MultiValueMap;

public class OnePassDevMockResponseFactoryTest {

    private OnePassDevMockResponseFactory factory;

    @Before
    public void setUp() {
        factory = new OnePassDevMockResponseFactory();
    }

    @Test
    public void loginReturnsStableLocalToken() {
        JSONObject data = create(OnePassConstants.USER_LOGIN_URI, null).getJSONObject("data");

        Assert.assertEquals("dev-mock-token", data.getString("access_token"));
        Assert.assertTrue(data.getLongValue("expires_in") > 0L);
    }

    @Test
    public void accountInfoEnablesEveryLocalCapability() {
        JSONObject data = create(OnePassConstants.USER_INFO_URI, null).getJSONObject("data");

        Assert.assertEquals("local-dev-mock", data.getString("account"));
        Assert.assertEquals(Integer.valueOf(1), data.getJSONObject("sms").getInteger("open"));
        Assert.assertEquals(Integer.valueOf(9999), data.getJSONObject("sms").getInteger("num"));
        Assert.assertEquals(Integer.valueOf(1), data.getJSONObject("dump").getInteger("open"));
        Assert.assertEquals(Integer.valueOf(9999), data.getJSONObject("copy").getInteger("num"));
        Assert.assertEquals(Integer.valueOf(9999), data.getJSONObject("query").getInteger("num"));
    }

    @Test
    public void smsEndpointsReturnUsableTemplateContracts() {
        JSONObject templates = create(OnePassConstants.ONE_PASS_TEMP_LIST_URI, null)
                .getJSONObject("data");
        JSONArray templateRows = templates.getJSONArray("data");
        Assert.assertEquals(Integer.valueOf(templateRows.size()), templates.getInteger("count"));
        Assert.assertTrue(templateRows.getJSONObject(0).containsKey("temp_id"));
        Assert.assertTrue(templateRows.getJSONObject(0).containsKey("temp_type"));

        JSONObject applications = create(OnePassConstants.ONE_PASS_APPLYS_LIST_URI, null)
                .getJSONObject("data");
        Assert.assertFalse(applications.getJSONArray("data").isEmpty());

        assertSuccess(OnePassConstants.ONE_PASS_API_SEND_URI);
        assertSuccess(OnePassConstants.ONE_PASS_TEMP_APPLY_URI);
        assertSuccess(OnePassConstants.ONE_PASS_SMS_MODIFY_URI);
        assertSuccess(OnePassConstants.ONE_PASS_SMS_OPEN_URI);
    }

    @Test
    public void expressEndpointsMatchAdminContracts() {
        JSONObject companies = create(OnePassConstants.ONE_PASS_API_EXPRESS_URI, null)
                .getJSONObject("data");
        JSONArray companyRows = companies.getJSONArray("data");
        Assert.assertTrue(companyRows.size() >= 3);
        Assert.assertTrue(contains(companyRows, "code", "yunda"));
        Assert.assertTrue(contains(companyRows, "code", "yuantong"));
        Assert.assertTrue(contains(companyRows, "code", "shunfeng"));

        JSONObject templates = factory.create(
                OnePassConstants.ONE_PASS_API_URL
                        + OnePassConstants.ONE_PASS_API_EXPRESS_TEMP_URI
                        + "?com=yunda&is_shipment=1",
                null).getJSONObject("data");
        JSONArray templateRows = templates.getJSONArray("data");
        Assert.assertFalse(templateRows.isEmpty());
        Assert.assertEquals("DEV-YUNDA-001", templateRows.getJSONObject(0).getString("temp_id"));
        Assert.assertTrue(templateRows.getJSONObject(0).getString("pic").startsWith("data:image/svg+xml;base64,"));

        JSONObject records = create(OnePassConstants.ONE_PASS_API_EXPRESS_DUMP_RECORD_URI, null)
                .getJSONObject("data");
        Assert.assertNotNull(records.getJSONArray("data"));
    }

    @Test
    public void expressLabelUsesLocalSvgOnly() {
        LinkedMultiValueMap<String, Object> params = new LinkedMultiValueMap<>();
        params.add("order_id", "ORDER-DEV-1");

        JSONObject data = create(OnePassConstants.ONE_PASS_API_EXPRESS_DUMP_URI, params)
                .getJSONObject("data");

        Assert.assertTrue(data.getString("label").startsWith("data:image/svg+xml;base64,"));
        Assert.assertTrue(data.getString("kuaidinum").startsWith("DEV"));
    }

    @Test
    public void logisticsReusesRequestedIdentity() {
        LinkedMultiValueMap<String, Object> params = new LinkedMultiValueMap<>();
        params.add("com", "yunda");
        params.add("num", "DEV123");

        JSONObject data = create(OnePassConstants.ONE_PASS_API_EXPRESS_QUEARY_URI, params)
                .getJSONObject("data");

        Assert.assertEquals("yunda", data.getString("com"));
        Assert.assertEquals("DEV123", data.getString("num"));
        Assert.assertFalse(data.getJSONArray("content").isEmpty());
    }

    @Test
    public void shipmentEndpointsMatchOrderFormContract() {
        JSONArray companies = create(
                OnePassConstants.ONE_PASS_API_SHIPMENT_GET_KUAIDI_COMS_URI,
                null).getJSONArray("data");
        JSONObject yunda = find(companies, "value", "yunda");
        Assert.assertNotNull(yunda);
        Assert.assertFalse(yunda.getJSONArray("types").isEmpty());
        Assert.assertEquals(
                "DEV-YUNDA-001",
                yunda.getJSONArray("list").getJSONObject(0).getString("temp_id"));

        LinkedMultiValueMap<String, Object> params = new LinkedMultiValueMap<>();
        params.add("kuaidicom", "yunda");
        params.add("tempid", "DEV-YUNDA-001");
        JSONObject shipment = create(
                OnePassConstants.ONE_PASS_API_SHIPMENT_CREATE_ORDER_URI,
                params).getJSONObject("data");
        Assert.assertTrue(shipment.getString("order_id").startsWith("DEV-ORDER-"));
        Assert.assertTrue(shipment.getString("task_id").startsWith("DEV-TASK-"));
        Assert.assertTrue(shipment.getString("kuaidinum").startsWith("DEV"));

        assertSuccess(OnePassConstants.ONE_PASS_API_SHIPMENT_CANCEL_ORDER_URI);
    }

    @Test
    public void productResponseSupportsLocalImport() {
        JSONObject product = create(OnePassConstants.ONE_PASS_API_COPY_GOODS_URI, null)
                .getJSONObject("data");

        Assert.assertEquals("开发模拟采集商品", product.getString("store_name"));
        Assert.assertFalse(product.getJSONArray("items").isEmpty());
        Assert.assertFalse(product.getJSONObject("info").getJSONArray("value").isEmpty());
    }

    @Test
    public void unknownEndpointFailsClosed() {
        try {
            create("v2/unknown", null);
            Assert.fail("Expected CrmebException");
        } catch (CrmebException exception) {
            Assert.assertTrue(exception.getMessage().contains("开发模拟未实现该接口"));
        }
    }

    @Test
    public void nonOnePassAddressIsRejected() {
        try {
            factory.create("https://example.com/api/v2/user/info", null);
            Assert.fail("Expected CrmebException");
        } catch (CrmebException exception) {
            Assert.assertTrue(exception.getMessage().contains("非一号通地址"));
        }
    }

    private JSONObject create(String endpoint, MultiValueMap<String, Object> params) {
        return factory.create(OnePassConstants.ONE_PASS_API_URL + endpoint, params);
    }

    private void assertSuccess(String endpoint) {
        JSONObject response = create(endpoint, null);
        Assert.assertEquals(Integer.valueOf(200), response.getInteger("status"));
    }

    private boolean contains(JSONArray values, String key, String expected) {
        return find(values, key, expected) != null;
    }

    private JSONObject find(JSONArray values, String key, String expected) {
        for (int i = 0; i < values.size(); i++) {
            JSONObject value = values.getJSONObject(i);
            if (expected.equals(value.getString(key))) {
                return value;
            }
        }
        return null;
    }
}
