package com.zbkj.service.service.impl;

import com.zbkj.common.constants.Constants;
import com.zbkj.common.model.order.StoreOrder;
import com.zbkj.common.model.order.StoreOrderInfo;
import com.zbkj.common.model.product.StoreProduct;
import com.zbkj.common.model.product.StoreProductAttrValue;
import com.zbkj.service.service.*;
import org.junit.Assert;
import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.MockitoJUnitRunner;
import org.springframework.transaction.support.TransactionCallback;
import org.springframework.transaction.support.TransactionTemplate;

import java.util.Collections;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@RunWith(MockitoJUnitRunner.class)
public class OrderCancelInventoryTest {
    @InjectMocks
    private StoreOrderTaskServiceImpl taskService;
    @Mock
    private TransactionTemplate transactionTemplate;
    @Mock
    private StoreOrderStatusService storeOrderStatusService;
    @Mock
    private StoreOrderInfoService storeOrderInfoService;
    @Mock
    private StoreProductService storeProductService;
    @Mock
    private StoreProductAttrValueService attrValueService;

    private StoreOrder order;

    @Before
    public void setUp() {
        order = new StoreOrder().setId(10).setOrderId("cancel-stock-test")
                .setType(0).setSeckillId(0).setBargainId(0).setCombinationId(0).setCouponId(0);
        StoreOrderInfo info = new StoreOrderInfo();
        info.setProductId(30);
        info.setAttrValueId(40);
        info.setPayNum(2);
        when(storeOrderInfoService.getListByOrderNo(order.getOrderId())).thenReturn(Collections.singletonList(info));
        when(storeProductService.getById(30)).thenReturn(new StoreProduct().setId(30).setVersion(5));
        when(transactionTemplate.execute(any())).thenAnswer(invocation ->
                ((TransactionCallback<?>) invocation.getArgument(0)).doInTransaction(null));
    }

    @Test
    public void failedProductStockUpdateKeepsTaskRetryable() {
        when(storeProductService.operationStock(30, 2, "add", 5)).thenReturn(false);
        Assert.assertFalse(taskService.cancelByUser(order));
        verifyNoInteractions(attrValueService);
    }

    @Test
    public void failedSkuStockUpdateKeepsTaskRetryable() {
        when(storeProductService.operationStock(30, 2, "add", 5)).thenReturn(true);
        when(attrValueService.getById(40)).thenReturn(new StoreProductAttrValue().setId(40).setVersion(6));
        when(attrValueService.operationStock(40, 2, "add", Constants.PRODUCT_TYPE_NORMAL, 6)).thenReturn(false);
        Assert.assertFalse(taskService.cancelByUser(order));
    }

    @Test
    public void successfulProductAndSkuRestorationCompletesTask() {
        when(storeProductService.operationStock(30, 2, "add", 5)).thenReturn(true);
        when(attrValueService.getById(40)).thenReturn(new StoreProductAttrValue().setId(40).setVersion(6));
        when(attrValueService.operationStock(40, 2, "add", Constants.PRODUCT_TYPE_NORMAL, 6)).thenReturn(true);
        Assert.assertTrue(taskService.cancelByUser(order));
        verify(storeProductService).operationStock(30, 2, "add", 5);
        verify(attrValueService).operationStock(40, 2, "add", Constants.PRODUCT_TYPE_NORMAL, 6);
    }
}
