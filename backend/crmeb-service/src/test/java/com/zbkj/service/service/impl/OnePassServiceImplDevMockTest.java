package com.zbkj.service.service.impl;

import com.alibaba.fastjson.JSONArray;
import com.alibaba.fastjson.JSONObject;
import com.zbkj.common.constants.Constants;
import com.zbkj.common.constants.OnePassConstants;
import com.zbkj.common.request.onepass.OnePassShipmentCreateOrderRequest;
import com.zbkj.common.vo.MyRecord;
import com.zbkj.common.vo.OnePassLoginVo;
import com.zbkj.common.vo.OnePassLogisticsQueryVo;
import com.zbkj.service.service.SystemConfigService;
import com.zbkj.service.support.OnePassDevMockResponseFactory;
import com.zbkj.service.util.OnePassUtil;
import org.junit.Assert;
import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.MockitoJUnitRunner;
import org.springframework.util.MultiValueMap;

import java.util.HashMap;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.contains;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;

@RunWith(MockitoJUnitRunner.class)
public class OnePassServiceImplDevMockTest {

    @InjectMocks
    private OnePassServiceImpl service;

    @Mock
    private OnePassUtil onePassUtil;

    @Mock
    private SystemConfigService systemConfigService;

    private OnePassDevMockResponseFactory responseFactory;
    private HashMap<String, String> headers;

    @Before
    public void setUp() {
        responseFactory = new OnePassDevMockResponseFactory();
        headers = new HashMap<>();
    }

    @Test
    public void devMockAccountIsAlwaysAvailable() {
        when(onePassUtil.isDevMockEnabled()).thenReturn(true);

        Assert.assertTrue(service.checkAccount());
    }

    @Test
    public void logisticsKeepsRequestedIdentity() {
        stubSimpleToken();
        when(onePassUtil.postFrom(
                contains(OnePassConstants.ONE_PASS_API_EXPRESS_QUEARY_URI),
                any(),
                eq(headers))).thenAnswer(invocation -> responseFactory.create(
                        invocation.getArgument(0),
                        invocation.getArgument(1)));

        OnePassLogisticsQueryVo result = service.exprQuery("DEV123", "yunda", "");

        Assert.assertNotNull(result);
        Assert.assertEquals("DEV123", result.getNum());
        Assert.assertEquals("yunda", result.getCom());
        Assert.assertFalse(result.getContent().isEmpty());
    }

    @Test
    public void expressDumpMapsLocalTrackingAndLabel() {
        stubSimpleToken();
        when(onePassUtil.postFrom(
                contains(OnePassConstants.ONE_PASS_API_EXPRESS_DUMP_URI),
                any(),
                eq(headers))).thenAnswer(invocation -> responseFactory.create(
                        invocation.getArgument(0),
                        invocation.getArgument(1)));

        MyRecord input = new MyRecord();
        input.set("order_id", "ORDER-DEV-1");
        MyRecord result = service.expressDump(input);

        Assert.assertTrue(result.getStr("kuaidinum").startsWith("DEV"));
        Assert.assertTrue(result.getStr("label").startsWith("data:image/svg+xml;base64,"));
    }

    @Test
    public void productImportReturnsLocalProductContract() {
        stubSimpleToken();
        when(onePassUtil.postFrom(
                contains(OnePassConstants.ONE_PASS_API_COPY_GOODS_URI),
                any(),
                eq(headers))).thenAnswer(invocation -> responseFactory.create(
                        invocation.getArgument(0),
                        invocation.getArgument(1)));

        JSONObject product = service.copyGoods("https://example.invalid/product/1");

        Assert.assertEquals("开发模拟采集商品", product.getString("store_name"));
        Assert.assertFalse(product.getJSONArray("items").isEmpty());
    }

    @Test
    public void shipmentReturnsLocalTaskAndTrackingData() {
        OnePassLoginVo loginVo = new OnePassLoginVo();
        loginVo.setAccessKey("local-dev-mock");
        when(onePassUtil.getLoginVo()).thenReturn(loginVo);
        when(onePassUtil.getToken(loginVo)).thenReturn("Bearer-dev-mock-token");
        when(onePassUtil.getCommonHeader("Bearer-dev-mock-token")).thenReturn(headers);
        when(systemConfigService.getValueByKey(Constants.CONFIG_KEY_API_URL))
                .thenReturn("http://127.0.0.1:8080");
        when(onePassUtil.postFrom(
                contains(OnePassConstants.ONE_PASS_API_SHIPMENT_CREATE_ORDER_URI),
                any(),
                eq(headers))).thenAnswer(invocation -> responseFactory.create(
                        invocation.getArgument(0),
                        invocation.getArgument(1)));

        OnePassShipmentCreateOrderRequest request = new OnePassShipmentCreateOrderRequest();
        request.setKuaidicom("yunda");
        request.setSendRealName("本地测试寄件人");
        JSONObject result = service.shipmentCreateOrder(request);

        Assert.assertTrue(result.getString("order_id").startsWith("DEV-ORDER-"));
        Assert.assertTrue(result.getString("task_id").startsWith("DEV-TASK-"));
        Assert.assertTrue(result.getString("kuaidinum").startsWith("DEV"));
    }

    @Test
    public void shipmentCompaniesKeepTopLevelProviderContract() {
        OnePassLoginVo loginVo = new OnePassLoginVo();
        when(onePassUtil.getLoginVo()).thenReturn(loginVo);
        when(onePassUtil.getToken(loginVo)).thenReturn("Bearer-dev-mock-token");
        when(onePassUtil.getCommonHeader("Bearer-dev-mock-token")).thenReturn(headers);
        when(onePassUtil.getData(anyString(), eq(headers))).thenAnswer(invocation ->
                responseFactory.create(invocation.getArgument(0), null));

        JSONObject response = service.shipmentComs();
        JSONArray companies = response.getJSONArray("data");

        Assert.assertFalse(companies.isEmpty());
        Assert.assertEquals("yunda", companies.getJSONObject(0).getString("value"));
    }

    private void stubSimpleToken() {
        when(onePassUtil.getToken()).thenReturn("Bearer-dev-mock-token");
        when(onePassUtil.getCommonHeader("Bearer-dev-mock-token")).thenReturn(headers);
    }
}
