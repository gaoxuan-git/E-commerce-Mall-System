package com.zbkj.front.service.impl;

import com.zbkj.common.constants.SmsConstants;
import com.zbkj.common.exception.CrmebException;
import com.zbkj.common.model.user.User;
import com.zbkj.common.request.RegisterRequest;
import com.zbkj.common.response.LoginResponse;
import com.zbkj.common.token.FrontTokenComponent;
import com.zbkj.common.utils.RedisUtil;
import com.zbkj.service.service.UserService;
import org.junit.Assert;
import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.MockitoJUnitRunner;
import org.springframework.transaction.support.TransactionCallback;
import org.springframework.transaction.support.TransactionTemplate;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@RunWith(MockitoJUnitRunner.class)
public class LoginServiceImplTest {

    private static final String PHONE = "13900000001";
    private static final String CODE_KEY = SmsConstants.SMS_VALIDATE_PHONE + PHONE;

    @InjectMocks
    private LoginServiceImpl loginService;

    @Mock
    private UserService userService;

    @Mock
    private TransactionTemplate transactionTemplate;

    @Mock
    private RedisUtil redisUtil;

    @Mock
    private FrontTokenComponent tokenComponent;

    @Before
    public void runTransactionsImmediately() {
        when(transactionTemplate.execute(any())).thenAnswer(invocation -> {
            TransactionCallback<?> callback = invocation.getArgument(0);
            return callback.doInTransaction(null);
        });
    }

    @Test
    public void registersUserSetsPasswordAndReturnsToken() {
        RegisterRequest request = validRequest();
        User user = user();
        when(userService.getByPhone(PHONE)).thenReturn(null);
        when(redisUtil.get(CODE_KEY)).thenReturn("123456");
        when(userService.registerPhone(PHONE, 0)).thenReturn(user);
        when(userService.updateUserPassword(7, "Pass_123")).thenReturn(true);
        when(tokenComponent.createToken(user)).thenReturn("front-token");

        LoginResponse response = loginService.register(request);

        Assert.assertEquals("front-token", response.getToken());
        Assert.assertEquals(Integer.valueOf(7), response.getUid());
        Assert.assertEquals(PHONE, response.getPhone());
        verify(userService).registerPhone(PHONE, 0);
        verify(userService).updateUserPassword(7, "Pass_123");
        verify(redisUtil).delete(CODE_KEY);
    }

    @Test
    public void duplicatePhoneDoesNotConsumeVerificationCode() {
        when(userService.getByPhone(PHONE)).thenReturn(user());

        assertCrmebException("手机号已注册", () -> loginService.register(validRequest()));

        verify(redisUtil, never()).get(CODE_KEY);
        verify(redisUtil, never()).delete(CODE_KEY);
        verify(userService, never()).registerPhone(any(), any());
    }

    @Test
    public void wrongVerificationCodeDoesNotCreateUser() {
        when(userService.getByPhone(PHONE)).thenReturn(null);
        when(redisUtil.get(CODE_KEY)).thenReturn("654321");

        assertCrmebException("验证码错误", () -> loginService.register(validRequest()));

        verify(redisUtil, never()).delete(CODE_KEY);
        verify(userService, never()).registerPhone(any(), any());
    }

    private RegisterRequest validRequest() {
        return new RegisterRequest()
                .setPhone(PHONE)
                .setCaptcha("123456")
                .setPassword("Pass_123")
                .setSpreadPid(0);
    }

    private User user() {
        User user = new User();
        user.setUid(7);
        user.setPhone(PHONE);
        user.setNickname("新用户");
        return user;
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
