package com.zbkj.service.service.impl;

import com.baomidou.mybatisplus.core.conditions.Wrapper;
import com.baomidou.mybatisplus.core.conditions.update.UpdateWrapper;
import com.zbkj.common.constants.Constants;
import com.zbkj.common.exception.CrmebException;
import com.zbkj.common.model.order.StoreOrder;
import com.zbkj.common.utils.RedisUtil;
import com.zbkj.service.delete.OrderUtils;
import com.zbkj.service.service.StoreOrderService;
import org.junit.Assert;
import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.ArgumentCaptor;
import org.mockito.junit.MockitoJUnitRunner;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@RunWith(MockitoJUnitRunner.class)
public class OrderCancelStateTest {
    @InjectMocks
    private OrderServiceImpl orderService;
    @Mock
    private OrderUtils orderUtils;
    @Mock
    private StoreOrderService storeOrderService;
    @Mock
    private RedisUtil redisUtil;

    private StoreOrder order;

    @Before
    public void setUp() {
        order = new StoreOrder().setId(10).setUid(20).setPaid(false)
                .setStatus(0).setRefundStatus(0).setIsDel(false).setIsSystemDel(false);
        when(orderUtils.getInfoById(10)).thenReturn(order);
    }

    @Test
    public void paidOrderCannotBeCancelled() {
        order.setPaid(true);
        assertRejected("已支付订单无法取消!");
    }

    @Test
    public void userDeletedOrderCannotBeCancelledAgain() {
        order.setIsDel(true);
        assertRejected("订单已取消或删除!");
    }

    @Test
    public void systemDeletedOrderCannotBeCancelledAgain() {
        order.setIsSystemDel(true);
        assertRejected("订单已取消或删除!");
    }

    @Test
    public void nonPendingStateCannotBeCancelled() {
        order.setStatus(1);
        assertRejected("订单状态错误!");
    }

    @Test
    public void refundStateCannotBeCancelled() {
        order.setRefundStatus(1);
        assertRejected("订单状态错误!");
    }

    @Test
    public void failedPersistenceDoesNotQueueInventoryReturn() {
        when(storeOrderService.update(isNull(), any(Wrapper.class))).thenReturn(false);
        Assert.assertFalse(orderService.cancel(10));
        verifyNoInteractions(redisUtil);
    }

    @Test
    public void successfulCancellationRequiresPendingStateInDatabase() {
        when(storeOrderService.update(isNull(), any(Wrapper.class))).thenReturn(true);
        Assert.assertTrue(orderService.cancel(10));
        verify(redisUtil).lPush(Constants.ORDER_TASK_REDIS_KEY_AFTER_CANCEL_BY_USER, 10);
        ArgumentCaptor<UpdateWrapper> captor = ArgumentCaptor.forClass(UpdateWrapper.class);
        verify(storeOrderService).update(isNull(), captor.capture());
        String predicate = captor.getValue().getSqlSegment();
        for (String field : new String[]{"id", "uid", "paid", "is_del", "is_system_del", "status", "refund_status"}) {
            Assert.assertTrue("Missing conditional update field: " + field, predicate.contains(field + " ="));
        }
        Assert.assertTrue(captor.getValue().getSqlSet().contains("is_system_del="));
        verifyNoMoreInteractions(redisUtil);
    }

    @Test
    public void staleRetryAfterSuccessfulCancellationDoesNotQueueAgain() {
        // 两次读取均为旧的未支付快照，数据库条件更新仅让第一次成功。
        when(storeOrderService.update(isNull(), any(Wrapper.class))).thenReturn(true, false);
        Assert.assertTrue(orderService.cancel(10));
        Assert.assertFalse(orderService.cancel(10));
        verify(redisUtil, times(1)).lPush(Constants.ORDER_TASK_REDIS_KEY_AFTER_CANCEL_BY_USER, 10);
        verifyNoMoreInteractions(redisUtil);
    }

    private void assertRejected(String message) {
        try {
            orderService.cancel(10);
            Assert.fail("Expected invalid cancellation to be rejected");
        } catch (CrmebException exception) {
            Assert.assertEquals(message, exception.getMessage());
        }
        verifyNoInteractions(storeOrderService, redisUtil);
    }
}
