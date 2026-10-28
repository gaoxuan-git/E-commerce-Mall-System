package com.zbkj.service.service.impl;

import com.alibaba.fastjson.JSONObject;
import com.zbkj.common.constants.WeChatConstants;
import com.zbkj.common.utils.RedisUtil;
import com.zbkj.service.service.WechatNewService;
import org.junit.Assert;
import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.MockitoJUnitRunner;
import org.springframework.mock.env.MockEnvironment;
import org.springframework.test.util.ReflectionTestUtils;

import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@RunWith(MockitoJUnitRunner.class)
public class WechatPublicServiceImplDevMockTest {

    @InjectMocks
    private WechatPublicServiceImpl service;

    @Mock
    private RedisUtil redisUtil;

    @Mock
    private WechatNewService wechatNewService;

    private MockEnvironment environment;

    @Before
    public void setUp() {
        environment = new MockEnvironment();
        environment.setActiveProfiles("dev");
        ReflectionTestUtils.setField(service, "environment", environment);
    }

    @Test
    public void devProfileReturnsEmptyLocalMenuWithoutWechatCredentials() {
        JSONObject result = (JSONObject) service.getCustomizeMenus();

        Assert.assertTrue(result.getJSONObject("menu").getJSONArray("button").isEmpty());
        verify(redisUtil).set(WeChatConstants.REDIS_PUBLIC_MENU_KEY, result);
        verify(wechatNewService, never()).getPublicCustomMenu();
    }

    @Test
    public void devProfilePersistsMenuLocallyWithoutWechatCall() {
        String data = "{\"button\":[{\"type\":\"click\",\"name\":\"本地菜单\",\"key\":\"DEV\"}]}";

        Assert.assertTrue(service.createMenus(data));

        JSONObject expected = new JSONObject();
        expected.put("menu", JSONObject.parseObject(data));
        verify(redisUtil).set(WeChatConstants.REDIS_PUBLIC_MENU_KEY, expected);
        verify(wechatNewService, never()).createPublicCustomMenu(data);
    }

    @Test
    public void devProfileDeletesLocalMenuWithoutWechatCall() {
        when(redisUtil.exists(WeChatConstants.REDIS_PUBLIC_MENU_KEY)).thenReturn(true);

        Assert.assertTrue(service.deleteMenus());

        verify(redisUtil).delete(WeChatConstants.REDIS_PUBLIC_MENU_KEY);
        verify(wechatNewService, never()).deletePublicCustomMenu();
    }

    @Test
    public void nonDevProfileKeepsRealWechatPath() {
        environment.setActiveProfiles("prod");
        JSONObject remote = new JSONObject();
        remote.put("menu", new JSONObject());
        when(wechatNewService.getPublicCustomMenu()).thenReturn(remote);

        Assert.assertSame(remote, service.getCustomizeMenus());

        verify(wechatNewService).getPublicCustomMenu();
        verify(redisUtil).set(WeChatConstants.REDIS_PUBLIC_MENU_KEY, remote);
    }
}
