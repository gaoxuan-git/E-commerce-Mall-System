package com.zbkj.service.service.impl;

import com.alibaba.fastjson.JSONObject;
import com.zbkj.common.model.order.StoreOrder;
import com.zbkj.common.request.StoreOrderSendRequest;
import com.zbkj.common.request.onepass.OnePassShipmentCreateOrderRequest;
import com.zbkj.service.service.OnePassService;
import org.junit.Assert;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.Spy;
import org.mockito.junit.MockitoJUnitRunner;

import static org.mockito.Mockito.doReturn;
import static org.mockito.Mockito.when;

@RunWith(MockitoJUnitRunner.class)
public class StoreOrderServiceImplDevMockShipmentTest {

    @Spy
    @InjectMocks
    private StoreOrderServiceImpl service;

    @Mock
    private OnePassService onePassService;

    @Test
    public void shipmentResponsePopulatesTrackingFields() {
        StoreOrder order = new StoreOrder();
        order.setOrderId("ORDER-DEV-1");
        order.setRealName("测试收件人");
        order.setUserPhone("13900000000");
        order.setUserAddress("测试地址");

        OnePassShipmentCreateOrderRequest shipment = new OnePassShipmentCreateOrderRequest();
        shipment.setKuaidicom("yunda");
        shipment.setSendRealName("测试寄件人");
        StoreOrderSendRequest request = new StoreOrderSendRequest();
        request.setShipment(shipment);

        JSONObject result = new JSONObject();
        result.put("order_id", "DEV-ORDER-1");
        result.put("task_id", "DEV-TASK-1");
        result.put("kuaidinum", "DEV1000000001");
        when(onePassService.shipmentCreateOrder(shipment)).thenReturn(result);
        doReturn(true).when(service).updateById(order);

        service.expressForOnePassShipment(request, order);

        Assert.assertEquals("DEV1000000001", order.getDeliveryId());
        Assert.assertEquals("DEV1000000001", order.getShipmentNum());
        Assert.assertEquals("DEV-TASK-1", order.getShipmentTaskId());
        Assert.assertEquals("DEV-ORDER-1", order.getShipmentOrderId());
    }
}
