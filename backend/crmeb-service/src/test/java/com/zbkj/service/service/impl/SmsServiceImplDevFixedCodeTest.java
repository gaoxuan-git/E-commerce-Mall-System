package com.zbkj.service.service.impl;

import com.alibaba.fastjson.JSONObject;
import com.zbkj.common.constants.Constants;
import com.zbkj.common.constants.OnePassConstants;
import com.zbkj.common.constants.SmsConstants;
import com.zbkj.common.exception.CrmebException;
import com.zbkj.common.utils.RedisUtil;
import com.zbkj.common.vo.OnePassLoginVo;
import com.zbkj.service.service.OnePassService;
import com.zbkj.service.service.SystemConfigService;
import com.zbkj.service.service.UserService;
import com.zbkj.service.util.OnePassUtil;
import org.junit.Assert;
import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.MockitoJUnitRunner;
import org.springframework.mock.env.MockEnvironment;
import org.springframework.test.util.ReflectionTestUtils;

import java.util.HashMap;
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

    @Mock
    private OnePassUtil onePassUtil;

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
        when(redisUtil.set(CODE_KEY, "123456", 3L, TimeUnit.MINUTES))
                .thenReturn(true);
        when(redisUtil.set(RATE_KEY, 1, 60L)).thenReturn(true);

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

    @Test
    public void codeRedisWriteFailureReturnsErrorWithoutRateLimit() {
        when(redisUtil.exists(RATE_KEY)).thenReturn(false);
        when(systemConfigService.getValueByKey(Constants.CONFIG_KEY_SMS_CODE_EXPIRE))
                .thenReturn("3");
        when(redisUtil.set(CODE_KEY, "123456", 3L, TimeUnit.MINUTES))
                .thenReturn(false);

        assertCrmebException(
                "验证码保存失败，请稍后重试",
                () -> smsService.sendCommonCode(PHONE));

        verify(redisUtil, never()).set(RATE_KEY, 1, 60L);
        verify(onePassService, never()).checkAccount();
    }

    @Test
    public void rateLimitRedisWriteFailureDeletesStoredCode() {
        when(redisUtil.exists(RATE_KEY)).thenReturn(false);
        when(systemConfigService.getValueByKey(Constants.CONFIG_KEY_SMS_CODE_EXPIRE))
                .thenReturn("3");
        when(redisUtil.set(CODE_KEY, "123456", 3L, TimeUnit.MINUTES))
                .thenReturn(true);
        when(redisUtil.set(RATE_KEY, 1, 60L)).thenReturn(false);

        assertCrmebException(
                "验证码保存失败，请稍后重试",
                () -> smsService.sendCommonCode(PHONE));

        verify(redisUtil).delete(CODE_KEY);
        verify(onePassService, never()).checkAccount();
    }

    @Test
    public void notificationSmsUsesOnePassBoundary() {
        OnePassLoginVo loginVo = new OnePassLoginVo();
        loginVo.setAccessKey("local-dev-mock");
        loginVo.setSecretKey("local-dev-mock-secret");
        HashMap<String, String> headers = new HashMap<>();
        headers.put("Authorization", "Bearer-dev-mock-token");

        when(onePassUtil.getLoginVo()).thenReturn(loginVo);
        when(onePassUtil.getToken()).thenReturn("Bearer-dev-mock-token");
        when(onePassUtil.getCommonHeader("Bearer-dev-mock-token")).thenReturn(headers);
        when(onePassUtil.postFrom(
                eq(OnePassConstants.ONE_PASS_API_URL + OnePassConstants.ONE_PASS_API_SEND_URI),
                any(),
                eq(headers))).thenReturn(new JSONObject());

        Assert.assertTrue(smsService.sendOrderDeliverNotice(
                PHONE,
                "本地用户",
                "本地商品",
                "ORDER-DEV-1",
                100002));

        verify(onePassUtil).postFrom(
                eq(OnePassConstants.ONE_PASS_API_URL + OnePassConstants.ONE_PASS_API_SEND_URI),
                any(),
                eq(headers));
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
