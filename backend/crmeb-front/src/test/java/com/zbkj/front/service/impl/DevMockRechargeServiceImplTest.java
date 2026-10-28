package com.zbkj.front.service.impl;

import com.zbkj.common.constants.Constants;
import com.zbkj.common.exception.CrmebException;
import com.zbkj.common.model.finance.UserRecharge;
import com.zbkj.common.model.user.User;
import com.zbkj.common.request.UserRechargeRequest;
import com.zbkj.common.vo.SystemGroupDataRechargeConfigVo;
import com.zbkj.front.response.DevMockRechargeResponse;
import com.zbkj.service.service.RechargePayService;
import com.zbkj.service.service.SystemConfigService;
import com.zbkj.service.service.SystemGroupDataService;
import com.zbkj.service.service.UserRechargeService;
import com.zbkj.service.service.UserService;
import org.junit.Assert;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.MockitoJUnitRunner;

import java.math.BigDecimal;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@RunWith(MockitoJUnitRunner.class)
public class DevMockRechargeServiceImplTest {

    private static final Integer USER_ID = 7;

    @InjectMocks
    private DevMockRechargeServiceImpl devMockRechargeService;

    @Mock
    private UserService userService;

    @Mock
    private SystemConfigService systemConfigService;

    @Mock
    private SystemGroupDataService systemGroupDataService;

    @Mock
    private UserRechargeService userRechargeService;

    @Mock
    private RechargePayService rechargePayService;

    @Test
    public void packageRechargeUsesServerAmountsAndReturnsUpdatedBalance() {
        UserRechargeRequest request = new UserRechargeRequest()
                .setPrice(new BigDecimal("1.00"))
                .setGroupDataId(62);
        SystemGroupDataRechargeConfigVo packageConfig = new SystemGroupDataRechargeConfigVo()
                .setId(62)
                .setPrice(new BigDecimal("30.00"))
                .setGiveMoney(new BigDecimal("3.00"));
        when(systemGroupDataService.getNormalInfo(
                eq(62), eq(SystemGroupDataRechargeConfigVo.class))).thenReturn(packageConfig);
        stubSuccessfulPayment(new BigDecimal("10.00"), new BigDecimal("43.00"));

        DevMockRechargeResponse response = devMockRechargeService.recharge(request);

        ArgumentCaptor<UserRecharge> orderCaptor = ArgumentCaptor.forClass(UserRecharge.class);
        verify(userRechargeService).save(orderCaptor.capture());
        UserRecharge order = orderCaptor.getValue();
        Assert.assertEquals(USER_ID, order.getUid());
        Assert.assertEquals(new BigDecimal("30.00"), order.getPrice());
        Assert.assertEquals(new BigDecimal("3.00"), order.getGivePrice());
        Assert.assertEquals("dev_mock", order.getRechargeType());
        Assert.assertEquals(Boolean.FALSE, order.getPaid());
        Assert.assertNotNull(order.getOrderId());
        verify(rechargePayService).paySuccess(order);
        Assert.assertEquals(Boolean.TRUE, response.getMock());
        Assert.assertEquals(order.getOrderId(), response.getOrderNo());
        Assert.assertEquals(new BigDecimal("30.00"), response.getRechargeAmount());
        Assert.assertEquals(new BigDecimal("3.00"), response.getGiveAmount());
        Assert.assertEquals(new BigDecimal("33.00"), response.getCreditedAmount());
        Assert.assertEquals(new BigDecimal("43.00"), response.getBalance());
    }

    @Test
    public void customRechargeUsesSubmittedAmountWithoutGift() {
        UserRechargeRequest request = new UserRechargeRequest()
                .setPrice(new BigDecimal("20.50"));
        when(systemConfigService.getValueByKeyException(
                Constants.CONFIG_KEY_RECHARGE_MIN_AMOUNT)).thenReturn("10");
        stubSuccessfulPayment(new BigDecimal("10.00"), new BigDecimal("30.50"));

        DevMockRechargeResponse response = devMockRechargeService.recharge(request);

        ArgumentCaptor<UserRecharge> orderCaptor = ArgumentCaptor.forClass(UserRecharge.class);
        verify(userRechargeService).save(orderCaptor.capture());
        Assert.assertEquals(new BigDecimal("20.50"), orderCaptor.getValue().getPrice());
        Assert.assertEquals(BigDecimal.ZERO, orderCaptor.getValue().getGivePrice());
        Assert.assertEquals(new BigDecimal("20.50"), response.getCreditedAmount());
        Assert.assertEquals(new BigDecimal("30.50"), response.getBalance());
        verify(systemGroupDataService, never()).getNormalInfo(any(), any());
    }

    @Test
    public void nullCustomAmountIsRejected() {
        assertCrmebException("请输入充值金额",
                () -> devMockRechargeService.recharge(new UserRechargeRequest()));

        verify(userRechargeService, never()).save(any());
    }

    @Test
    public void zeroCustomAmountIsRejected() {
        UserRechargeRequest request = new UserRechargeRequest().setPrice(BigDecimal.ZERO);

        assertCrmebException("充值金额必须大于0",
                () -> devMockRechargeService.recharge(request));

        verify(userRechargeService, never()).save(any());
    }

    @Test
    public void customAmountBelowMinimumIsRejected() {
        UserRechargeRequest request = new UserRechargeRequest()
                .setPrice(new BigDecimal("9.99"));
        when(systemConfigService.getValueByKeyException(
                Constants.CONFIG_KEY_RECHARGE_MIN_AMOUNT)).thenReturn("10");

        assertCrmebException("充值金额不能低于10",
                () -> devMockRechargeService.recharge(request));

        verify(userRechargeService, never()).save(any());
    }

    @Test
    public void customAmountAboveMaximumIsRejected() {
        UserRechargeRequest request = new UserRechargeRequest()
                .setPrice(new BigDecimal("50000.01"));
        when(systemConfigService.getValueByKeyException(
                Constants.CONFIG_KEY_RECHARGE_MIN_AMOUNT)).thenReturn("10");

        assertCrmebException("充值金额最大值为50000",
                () -> devMockRechargeService.recharge(request));

        verify(userRechargeService, never()).save(any());
    }

    @Test
    public void missingPackageIsRejected() {
        UserRechargeRequest request = new UserRechargeRequest()
                .setPrice(new BigDecimal("30.00"))
                .setGroupDataId(999);
        when(systemGroupDataService.getNormalInfo(
                eq(999), eq(SystemGroupDataRechargeConfigVo.class))).thenReturn(null);

        assertCrmebException("您选择的充值方式已下架",
                () -> devMockRechargeService.recharge(request));

        verify(userRechargeService, never()).save(any());
    }

    @Test
    public void orderSaveFailureDoesNotRunPaymentSuccess() {
        UserRechargeRequest request = new UserRechargeRequest()
                .setPrice(new BigDecimal("20.00"));
        when(systemConfigService.getValueByKeyException(
                Constants.CONFIG_KEY_RECHARGE_MIN_AMOUNT)).thenReturn("10");
        when(userService.getInfoException()).thenReturn(user(new BigDecimal("10.00")));
        when(userRechargeService.save(any())).thenReturn(false);

        assertCrmebException("生成模拟充值订单失败",
                () -> devMockRechargeService.recharge(request));

        verify(rechargePayService, never()).paySuccess(any());
    }

    @Test
    public void paymentSuccessFailureIsRejected() {
        UserRechargeRequest request = new UserRechargeRequest()
                .setPrice(new BigDecimal("20.00"));
        when(systemConfigService.getValueByKeyException(
                Constants.CONFIG_KEY_RECHARGE_MIN_AMOUNT)).thenReturn("10");
        when(userService.getInfoException()).thenReturn(user(new BigDecimal("10.00")));
        when(userRechargeService.save(any())).thenReturn(true);
        when(rechargePayService.paySuccess(any())).thenReturn(false);

        assertCrmebException("模拟充值失败，请重试",
                () -> devMockRechargeService.recharge(request));

        verify(userService, never()).getById(any());
    }

    private void stubSuccessfulPayment(BigDecimal originalBalance, BigDecimal updatedBalance) {
        when(userService.getInfoException()).thenReturn(user(originalBalance));
        when(userRechargeService.save(any())).thenReturn(true);
        when(rechargePayService.paySuccess(any())).thenReturn(true);
        when(userService.getById(USER_ID)).thenReturn(user(updatedBalance));
    }

    private User user(BigDecimal balance) {
        return new User()
                .setUid(USER_ID)
                .setNowMoney(balance)
                .setStatus(true);
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
