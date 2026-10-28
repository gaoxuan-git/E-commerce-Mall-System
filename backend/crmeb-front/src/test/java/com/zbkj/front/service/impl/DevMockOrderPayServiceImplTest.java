package com.zbkj.front.service.impl;

import com.zbkj.common.constants.Constants;
import com.zbkj.common.exception.CrmebException;
import com.zbkj.common.model.order.StoreOrder;
import com.zbkj.common.model.user.User;
import com.zbkj.front.request.DevMockPayRequest;
import com.zbkj.front.response.DevMockOrderPayResponse;
import com.zbkj.service.service.OrderPaySuccessQueueService;
import com.zbkj.service.service.StoreOrderService;
import com.zbkj.service.service.UserService;
import org.junit.Assert;
import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.MockitoJUnitRunner;
import org.springframework.transaction.support.TransactionCallback;
import org.springframework.transaction.support.TransactionTemplate;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@RunWith(MockitoJUnitRunner.class)
public class DevMockOrderPayServiceImplTest {

    private static final Integer USER_ID = 7;
    private static final String ORDER_NO = "order202610210001";

    @InjectMocks
    private DevMockOrderPayServiceImpl devMockOrderPayService;

    @Mock
    private StoreOrderService storeOrderService;

    @Mock
    private UserService userService;

    @Mock
    private OrderPaySuccessQueueService orderPaySuccessQueueService;

    @Mock
    private TransactionTemplate transactionTemplate;

    @Before
    @SuppressWarnings("unchecked")
    public void setUp() {
        when(transactionTemplate.execute(any())).thenAnswer(invocation -> {
            TransactionCallback<Boolean> callback = invocation.getArgument(0);
            return callback.doInTransaction(null);
        });
    }

    @Test
    public void payMarksOrderPaidAndEnqueuesAfterPayTask() {
        when(storeOrderService.getByOderId(ORDER_NO)).thenReturn(order(false));
        when(userService.getInfoException()).thenReturn(user());
        when(storeOrderService.updateById(any())).thenReturn(true);
        when(storeOrderService.updatePaid(ORDER_NO)).thenReturn(true);

        DevMockOrderPayResponse response = devMockOrderPayService.pay(request("weixin"));

        ArgumentCaptor<StoreOrder> orderCaptor = ArgumentCaptor.forClass(StoreOrder.class);
        verify(storeOrderService).updateById(orderCaptor.capture());
        Assert.assertEquals("weixin", orderCaptor.getValue().getPayType());
        Assert.assertEquals(Integer.valueOf(2), orderCaptor.getValue().getIsChannel());
        Assert.assertEquals(
                Constants.DEV_MOCK_ORDER_TRADE_NO_PREFIX + orderCaptor.getValue().getId(),
                orderCaptor.getValue().getOutTradeNo());
        verify(storeOrderService).updatePaid(ORDER_NO);
        verify(orderPaySuccessQueueService).enqueue(ORDER_NO);
        Assert.assertEquals(Boolean.TRUE, response.getMock());
        Assert.assertEquals(Boolean.TRUE, response.getPaid());
        Assert.assertEquals(ORDER_NO, response.getOrderNo());
        Assert.assertEquals("weixin", response.getPayType());
    }

    @Test
    public void alreadyPaidOrderIsIdempotent() {
        when(storeOrderService.getByOderId(ORDER_NO)).thenReturn(order(true));
        when(userService.getInfoException()).thenReturn(user());

        DevMockOrderPayResponse response = devMockOrderPayService.pay(request("alipay"));

        Assert.assertEquals(Boolean.TRUE, response.getPaid());
        verify(storeOrderService, never()).updateById(any());
        verify(storeOrderService, never()).updatePaid(anyString());
        verify(orderPaySuccessQueueService, never()).enqueue(anyString());
    }

    @Test
    public void unsupportedPayTypeIsRejected() {
        assertCrmebException("不支持的模拟支付方式",
                () -> devMockOrderPayService.pay(request("yue")));

        verify(storeOrderService, never()).getByOderId(anyString());
    }

    @Test
    public void orderOfOtherUserIsRejected() {
        when(userService.getInfoException()).thenReturn(user());

        StoreOrder otherOrder = order(false).setUid(USER_ID + 1);
        when(storeOrderService.getByOderId(ORDER_NO)).thenReturn(otherOrder);

        assertCrmebException("无权支付该订单",
                () -> devMockOrderPayService.pay(request("weixin")));

        verify(storeOrderService, never()).updatePaid(anyString());
    }

    @Test
    public void missingOrderIsRejected() {
        when(storeOrderService.getByOderId(ORDER_NO)).thenReturn(null);

        assertCrmebException("订单不存在",
                () -> devMockOrderPayService.pay(request("weixin")));
    }

    @Test
    public void updatePaidFailureIsRejected() {
        when(storeOrderService.getByOderId(ORDER_NO)).thenReturn(order(false));
        when(userService.getInfoException()).thenReturn(user());
        when(storeOrderService.updateById(any())).thenReturn(true);
        when(storeOrderService.updatePaid(ORDER_NO)).thenReturn(false);

        assertCrmebException("模拟支付失败，请重试",
                () -> devMockOrderPayService.pay(request("alipay")));

        verify(orderPaySuccessQueueService, never()).enqueue(eq(ORDER_NO));
    }

    private DevMockPayRequest request(String payType) {
        return new DevMockPayRequest().setOrderNo(ORDER_NO).setPayType(payType);
    }

    private StoreOrder order(boolean paid) {
        return new StoreOrder()
                .setId(1)
                .setUid(USER_ID)
                .setOrderId(ORDER_NO)
                .setPaid(paid)
                .setIsDel(false);
    }

    private User user() {
        return new User().setUid(USER_ID);
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
