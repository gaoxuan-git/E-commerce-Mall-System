package com.zbkj.service.util;

import com.alibaba.fastjson.JSONObject;
import com.zbkj.common.constants.OnePassConstants;
import com.zbkj.common.exception.CrmebException;
import com.zbkj.common.utils.RedisUtil;
import com.zbkj.common.utils.RestTemplateUtil;
import com.zbkj.common.vo.OnePassLoginVo;
import com.zbkj.service.service.SystemConfigService;
import com.zbkj.service.support.OnePassDevMockResponseFactory;
import org.junit.Assert;
import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.MockitoJUnitRunner;
import org.springframework.mock.env.MockEnvironment;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.util.MultiValueMap;

import java.util.HashMap;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.ArgumentMatchers.isNull;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@RunWith(MockitoJUnitRunner.class)
public class OnePassUtilDevMockTest {

    @InjectMocks
    private OnePassUtil onePassUtil;

    @Mock
    private SystemConfigService systemConfigService;

    @Mock
    private RestTemplateUtil restTemplateUtil;

    @Mock
    private RedisUtil redisUtil;

    @Mock
    private OnePassDevMockResponseFactory devMockResponseFactory;

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
        Assert.assertEquals("local-dev-mock-secret", login.getSecretKey());
        Assert.assertEquals("Bearer-dev-mock-token", onePassUtil.getToken(login));
        Assert.assertEquals("Bearer-dev-mock-token", onePassUtil.getToken());
        verify(systemConfigService, never()).getValueByKey(anyString());
        verify(redisUtil, never()).exists(anyString());
        verify(redisUtil, never()).get(anyString());
    }

    @Test
    public void devMockDelegatesAllRequestTypesWithoutHttp() {
        String postUrl = OnePassConstants.ONE_PASS_API_URL + OnePassConstants.USER_INFO_URI;
        String getUrl = OnePassConstants.ONE_PASS_API_URL + OnePassConstants.ONE_PASS_API_EXPRESS_URI;
        String dataUrl = OnePassConstants.ONE_PASS_API_URL
                + OnePassConstants.ONE_PASS_API_EXPRESS_TEMP_URI
                + "?com=yunda";
        MultiValueMap<String, Object> params = new LinkedMultiValueMap<>();
        params.add("page", 1);

        JSONObject postResponse = new JSONObject();
        JSONObject getResponse = new JSONObject();
        JSONObject dataResponse = new JSONObject();
        when(devMockResponseFactory.create(eq(postUrl), isNull())).thenReturn(postResponse);
        when(devMockResponseFactory.create(eq(getUrl), eq(params))).thenReturn(getResponse);
        when(devMockResponseFactory.create(eq(dataUrl), isNull())).thenReturn(dataResponse);

        Assert.assertSame(postResponse, onePassUtil.postFrom(postUrl, null, null));
        Assert.assertSame(getResponse, onePassUtil.getFrom(getUrl, params, new HashMap<>()));
        Assert.assertSame(dataResponse, onePassUtil.getData(dataUrl, new HashMap<>()));
        verify(restTemplateUtil, never()).postFromUrlencoded(anyString(), any(), any());
        verify(restTemplateUtil, never()).getDataForm(anyString(), any(), any());
        verify(restTemplateUtil, never()).getData(anyString(), any());
    }

    @Test
    public void mockFlagWithoutDevProfileCannotBypassCredentials() {
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

    @Test
    public void devProfileWithoutMockFlagCannotBypassCredentials() {
        ReflectionTestUtils.setField(onePassUtil, "devMockEnabled", false);
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
