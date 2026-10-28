package com.zbkj.front.service;

import com.zbkj.common.request.UserRechargeRequest;
import com.zbkj.front.response.DevMockRechargeResponse;

/**
 * 本地开发模拟充值服务。
 */
public interface DevMockRechargeService {

    /**
     * 创建模拟充值订单并完成余额入账。
     *
     * @param request 充值参数
     * @return 模拟充值结果
     */
    DevMockRechargeResponse recharge(UserRechargeRequest request);
}
