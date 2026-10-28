package com.zbkj.service.service.impl;

import com.zbkj.common.exception.CrmebException;
import com.zbkj.common.model.order.StoreOrder;
import com.zbkj.common.model.user.User;
import com.zbkj.common.request.OrderPayRequest;
import com.zbkj.service.service.StoreOrderService;
import com.zbkj.service.service.UserService;
import org.junit.Assert;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.MockitoJUnitRunner;

import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@RunWith(MockitoJUnitRunner.class)
public class OrderPayAuthorizationTest {

    @InjectMocks
    private OrderPayServiceImpl orderPayService;

    @Mock
    private StoreOrderService storeOrderService;

    @Mock
    private UserService userService;

    @Test
    public void paymentRejectsOrderOwnedByAnotherUser() {
        StoreOrder order = new StoreOrder()
                .setId(10)
                .setUid(20)
                .setOrderId("order-other-user")
                .setIsDel(false)
                .setPaid(false);
        when(storeOrderService.getByOderId(order.getOrderId())).thenReturn(order);
        when(userService.getInfoException()).thenReturn(new User().setUid(21));

        try {
            orderPayService.payment(new OrderPayRequest()
                    .setOrderNo(order.getOrderId())
                    .setPayType("yue")
                    .setPayChannel("yue"), "127.0.0.1");
            Assert.fail("Expected ownership check to reject payment");
        } catch (CrmebException exception) {
            Assert.assertEquals("无权支付该订单", exception.getMessage());
        }

        verify(userService, never()).getById(order.getUid());
    }
}
