package com.zbkj.service.service.impl;

import com.baomidou.mybatisplus.core.conditions.Wrapper;
import com.zbkj.common.constants.SmsConstants;
import com.zbkj.common.exception.CrmebException;
import com.zbkj.common.model.user.User;
import com.zbkj.common.request.PasswordRequest;
import com.zbkj.common.utils.CrmebUtil;
import com.zbkj.common.utils.RedisUtil;
import com.zbkj.service.dao.UserDao;
import org.junit.Assert;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.Spy;
import org.mockito.junit.MockitoJUnitRunner;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@RunWith(MockitoJUnitRunner.class)
public class UserPasswordResetTest {
    private static final String PHONE = "13900000001";
    private static final String CODE_KEY = SmsConstants.SMS_VALIDATE_PHONE + PHONE;
    @Spy @InjectMocks private UserServiceImpl service;
    @Mock private UserDao userDao;
    @Mock private RedisUtil redisUtil;

    @Test
    public void missingUserReturnsBusinessFailureWithoutChangingPassword() {
        when(redisUtil.get(CODE_KEY)).thenReturn("123456");
        assertRejected("用户不存在");
        verify(redisUtil, never()).delete(CODE_KEY);
        verify(service, never()).update(any(User.class), any(Wrapper.class));
    }

    @Test
    public void successfulResetStoresPasswordAndConsumesCode() {
        User user = existingUser();
        when(redisUtil.get(CODE_KEY)).thenReturn("123456");
        when(userDao.selectOne(any(Wrapper.class))).thenReturn(user);
        doReturn(true).when(service).update(any(User.class), any(Wrapper.class));
        Assert.assertTrue(service.password(request()));
        Assert.assertEquals(CrmebUtil.encryptPassword("Pass_123", PHONE), user.getPwd());
        verify(redisUtil).delete(CODE_KEY);
    }

    @Test
    public void failedSaveDoesNotConsumeCode() {
        when(redisUtil.get(CODE_KEY)).thenReturn("123456");
        when(userDao.selectOne(any(Wrapper.class))).thenReturn(existingUser());
        doReturn(false).when(service).update(any(User.class), any(Wrapper.class));
        Assert.assertFalse(service.password(request()));
        verify(redisUtil, never()).delete(CODE_KEY);
    }

    @Test
    public void wrongCodeDoesNotAccessUserOrSave() {
        when(redisUtil.get(CODE_KEY)).thenReturn("654321");
        assertRejected("验证码错误");
        verifyNoInteractions(userDao);
        verify(redisUtil, never()).delete(CODE_KEY);
    }

    @Test
    public void expiredCodeDoesNotAccessUserOrSave() {
        assertRejected("验证码已过期");
        verifyNoInteractions(userDao);
        verify(redisUtil, never()).delete(CODE_KEY);
    }

    private void assertRejected(String message) {
        try {
            service.password(request());
            Assert.fail("Expected business failure");
        } catch (CrmebException e) {
            Assert.assertEquals(message, e.getMessage());
        }
    }

    private User existingUser() {
        return new User().setUid(7).setAccount(PHONE).setPhone(PHONE).setIsLogoff(false);
    }

    private PasswordRequest request() {
        return new PasswordRequest().setPhone(PHONE).setPassword("Pass_123").setValidateCode("123456");
    }
}
