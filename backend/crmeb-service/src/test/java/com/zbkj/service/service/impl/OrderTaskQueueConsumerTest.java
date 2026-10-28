package com.zbkj.service.service.impl;

import com.zbkj.common.constants.Constants;
import com.zbkj.common.constants.TaskConstants;
import com.zbkj.common.model.order.StoreOrder;
import com.zbkj.common.utils.RedisUtil;
import com.zbkj.service.service.OrderPayService;
import com.zbkj.service.service.StoreOrderService;
import com.zbkj.service.service.StoreOrderTaskService;
import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.junit.runners.Parameterized;
import org.springframework.test.util.ReflectionTestUtils;

import java.util.Arrays;
import java.util.Collection;

import static org.mockito.Mockito.*;

/** Exercises queue acknowledgement and retry isolation without touching live data. */
@RunWith(Parameterized.class)
public class OrderTaskQueueConsumerTest {
    @Parameterized.Parameters(name = "{0}")
    public static Collection<Object[]> consumers() {
        return Arrays.asList(new Object[][] {
                {"cancel", Constants.ORDER_TASK_REDIS_KEY_AFTER_CANCEL_BY_USER},
                {"refund", Constants.ORDER_TASK_REDIS_KEY_AFTER_REFUND_BY_USER},
                {"complete", Constants.ORDER_TASK_REDIS_KEY_AFTER_COMPLETE_BY_USER},
                {"receipt", TaskConstants.ORDER_TASK_REDIS_KEY_AFTER_TAKE_BY_USER},
                {"autoCancel", Constants.ORDER_AUTO_CANCEL_KEY},
                {"pay", TaskConstants.ORDER_TASK_PAY_SUCCESS_AFTER}
        });
    }

    private final String consumer;
    private final String key;
    private OrderTaskServiceImpl service;
    private RedisUtil redis;
    private StoreOrderService orders;
    private StoreOrderTaskService tasks;
    private OrderPayService payments;
    private StoreOrder first;
    private StoreOrder second;

    public OrderTaskQueueConsumerTest(String consumer, String key) {
        this.consumer = consumer;
        this.key = key;
    }

    @Before
    public void setUp() {
        service = new OrderTaskServiceImpl();
        redis = mock(RedisUtil.class);
        orders = mock(StoreOrderService.class);
        tasks = mock(StoreOrderTaskService.class);
        payments = mock(OrderPayService.class);
        ReflectionTestUtils.setField(service, "redisUtil", redis);
        ReflectionTestUtils.setField(service, "storeOrderService", orders);
        ReflectionTestUtils.setField(service, "storeOrderTaskService", tasks);
        ReflectionTestUtils.setField(service, "orderPayService", payments);
        first = new StoreOrder().setId(1001).setOrderId("queue-order-1001");
        second = new StoreOrder().setId(1002).setOrderId("queue-order-1002");
    }

    @Test
    public void emptyQueueDoesNotPopOrRunBusinessOperations() {
        when(redis.getListSize(key)).thenReturn(0L);
        consume();
        verify(redis).getListSize(key);
        verifyNoMoreInteractions(redis);
        verifyNoInteractions(orders, tasks, payments);
    }

    @Test
    public void successfulItemsAreConsumedWithoutRequeue() {
        arrangeTwoItems();
        outcome(first, true, false);
        outcome(second, true, false);
        consume();
        verifyRan(first);
        verifyRan(second);
        verifyNoRequeue();
    }

    @Test
    public void businessFailureRequeuesOnlyFailedItemAndContinuesBatch() {
        arrangeTwoItems();
        outcome(first, false, false);
        outcome(second, true, false);
        consume();
        verifyRan(first);
        verifyRan(second);
        verifySingleRequeue(payload(first));
    }

    @Test
    public void businessExceptionRequeuesOnlyFailedItemAndContinuesBatch() {
        arrangeTwoItems();
        outcome(first, false, true);
        outcome(second, true, false);
        consume();
        verifyRan(first);
        verifyRan(second);
        verifySingleRequeue(payload(first));
    }

    @Test
    public void malformedItemIsRetainedWithoutBlockingFollowingValidItem() {
        when(redis.getListSize(key)).thenReturn(2L);
        when(redis.getRightPop(key, 10L)).thenReturn("invalid-order-reference", payload(second));
        lookup(second);
        outcome(second, true, false);
        consume();
        verifyRan(second);
        verifySingleRequeue("invalid-order-reference");
    }

    @Test
    public void concurrentEmptyPopDoesNotCreateRetryAndNextItemStillRuns() {
        when(redis.getListSize(key)).thenReturn(2L);
        when(redis.getRightPop(key, 10L)).thenReturn(null, payload(second));
        lookup(second);
        outcome(second, true, false);
        consume();
        verifyRan(second);
        verifyNoRequeue();
    }

    private Object payload(StoreOrder order) {
        return consumer.equals("autoCancel") || consumer.equals("pay")
                ? order.getOrderId() : order.getId();
    }

    private void arrangeTwoItems() {
        when(redis.getListSize(key)).thenReturn(2L);
        when(redis.getRightPop(key, 10L)).thenReturn(payload(first), payload(second));
        lookup(first);
        lookup(second);
    }

    private void lookup(StoreOrder order) {
        if (consumer.equals("autoCancel") || consumer.equals("pay")) {
            when(orders.getByOderId(order.getOrderId())).thenReturn(order);
        } else if (!consumer.equals("receipt")) {
            when(orders.getById(order.getId())).thenReturn(order);
        }
    }

    private void outcome(StoreOrder order, boolean result, boolean throwsException) {
        switch (consumer) {
            case "cancel":
                if (throwsException) when(tasks.cancelByUser(order)).thenThrow(new IllegalStateException("retry"));
                else when(tasks.cancelByUser(order)).thenReturn(result);
                break;
            case "refund":
                if (throwsException) when(tasks.refundOrder(order)).thenThrow(new IllegalStateException("retry"));
                else when(tasks.refundOrder(order)).thenReturn(result);
                break;
            case "complete":
                if (throwsException) when(tasks.complete(order)).thenThrow(new IllegalStateException("retry"));
                else when(tasks.complete(order)).thenReturn(result);
                break;
            case "receipt":
                if (throwsException) when(tasks.orderReceiving(order.getId())).thenThrow(new IllegalStateException("retry"));
                else when(tasks.orderReceiving(order.getId())).thenReturn(result);
                break;
            case "autoCancel":
                if (throwsException) when(tasks.autoCancel(order)).thenThrow(new IllegalStateException("retry"));
                else when(tasks.autoCancel(order)).thenReturn(result);
                break;
            case "pay":
                if (throwsException) when(payments.paySuccess(order)).thenThrow(new IllegalStateException("retry"));
                else when(payments.paySuccess(order)).thenReturn(result);
                break;
            default: throw new AssertionError(consumer);
        }
    }

    private void consume() {
        switch (consumer) {
            case "cancel": service.cancelByUser(); break;
            case "refund": service.refundApply(); break;
            case "complete": service.complete(); break;
            case "receipt": service.orderReceiving(); break;
            case "autoCancel": service.autoCancel(); break;
            case "pay": service.orderPaySuccessAfter(); break;
            default: throw new AssertionError(consumer);
        }
    }

    private void verifyRan(StoreOrder order) {
        switch (consumer) {
            case "cancel": verify(tasks).cancelByUser(order); break;
            case "refund": verify(tasks).refundOrder(order); break;
            case "complete": verify(tasks).complete(order); break;
            case "receipt": verify(tasks).orderReceiving(order.getId()); break;
            case "autoCancel": verify(tasks).autoCancel(order); break;
            case "pay": verify(payments).paySuccess(order); break;
            default: throw new AssertionError(consumer);
        }
    }

    private void verifyNoRequeue() {
        verify(redis).getListSize(key);
        verify(redis, times(2)).getRightPop(key, 10L);
        verifyNoMoreInteractions(redis);
    }

    private void verifySingleRequeue(Object failed) {
        verify(redis).getListSize(key);
        verify(redis, times(2)).getRightPop(key, 10L);
        verify(redis).lPush(key, failed);
        verifyNoMoreInteractions(redis);
    }
}
