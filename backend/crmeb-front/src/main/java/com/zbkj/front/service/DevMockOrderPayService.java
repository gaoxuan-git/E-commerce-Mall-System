package com.zbkj.front.service;

import com.zbkj.front.request.DevMockPayRequest;
import com.zbkj.front.response.DevMockOrderPayResponse;

/**
 * 本地开发模拟订单支付服务。
 */
public interface DevMockOrderPayService {

    /**
     * 不调用第三方支付，直接按已支付处理订单
     *
     * @param request 模拟支付参数
     * @return 模拟支付结果
     */
    DevMockOrderPayResponse pay(DevMockPayRequest request);
}
