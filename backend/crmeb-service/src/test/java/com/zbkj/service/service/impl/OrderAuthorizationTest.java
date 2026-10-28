package com.zbkj.service.service.impl;

import com.zbkj.common.exception.CrmebException;
import com.zbkj.common.model.order.StoreOrder;
import com.zbkj.common.model.user.User;
import com.zbkj.common.request.OrderRefundApplyRequest;
import com.zbkj.service.service.StoreOrderService;
import com.zbkj.service.service.UserService;
import org.junit.Assert;
import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.MockitoJUnitRunner;

import static org.mockito.Mockito.when;

@RunWith(MockitoJUnitRunner.class)
public class OrderAuthorizationTest {

    private static final String ORDER_NO = "order-other-user";

    @InjectMocks
    private OrderServiceImpl orderService;

    @Mock
    private StoreOrderService storeOrderService;

    @Mock
    private UserService userService;

    private StoreOrder order;

    @Before
    public void setUp() {
        order = new StoreOrder()
                .setId(10)
                .setUid(20)
                .setOrderId(ORDER_NO)
                .setIsDel(false)
                .setIsSystemDel(false)
                .setPaid(true)
                .setRefundStatus(0);
        when(userService.getInfoException()).thenReturn(new User().setUid(21));
    }

    @Test
    public void refundInfoRejectsOrderOwnedByAnotherUser() {
        when(storeOrderService.getByOderId(ORDER_NO)).thenReturn(order);
        assertUnauthorized(() -> orderService.applyRefundOrderInfo(ORDER_NO));
    }

    @Test
    public void refundApplyRejectsOrderOwnedByAnotherUser() {
        when(storeOrderService.getByEntityOne(org.mockito.ArgumentMatchers.any(StoreOrder.class)))
                .thenReturn(order);
        OrderRefundApplyRequest request = new OrderRefundApplyRequest()
                .setUni(ORDER_NO)
                .setText("not my order")
                .setReasonImage("")
                .setExplain("");
        assertUnauthorized(() -> orderService.refundApply(request));
    }

    private void assertUnauthorized(Runnable action) {
        try {
            action.run();
            Assert.fail("Expected ownership check to reject order access");
        } catch (CrmebException exception) {
            Assert.assertEquals("订单不存在", exception.getMessage());
        }
    }
}
