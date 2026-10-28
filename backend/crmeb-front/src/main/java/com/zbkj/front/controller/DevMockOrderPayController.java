package com.zbkj.front.controller;

import com.zbkj.common.result.CommonResult;
import com.zbkj.front.request.DevMockPayRequest;
import com.zbkj.front.response.DevMockOrderPayResponse;
import com.zbkj.front.service.DevMockOrderPayService;
import io.swagger.annotations.Api;
import io.swagger.annotations.ApiOperation;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Profile;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * 本地开发模拟订单支付接口。
 */
@RestController("DevMockOrderPayController")
@RequestMapping("api/front/pay/dev")
@Profile("dev")
@ConditionalOnProperty(
        prefix = "crmeb.payment.dev-mock-pay",
        name = "enabled",
        havingValue = "true",
        matchIfMissing = false)
@Api(tags = "订单 -- 本地开发模拟支付")
public class DevMockOrderPayController {

    @Autowired
    private DevMockOrderPayService devMockOrderPayService;

    @PostMapping("/mock")
    @ApiOperation(value = "本地开发模拟订单支付")
    public CommonResult<DevMockOrderPayResponse> pay(
            @RequestBody @Validated DevMockPayRequest request) {
        return CommonResult.success(devMockOrderPayService.pay(request));
    }
}
