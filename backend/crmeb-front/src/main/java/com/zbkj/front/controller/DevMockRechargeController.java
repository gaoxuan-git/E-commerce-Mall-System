package com.zbkj.front.controller;

import com.zbkj.common.request.UserRechargeRequest;
import com.zbkj.common.result.CommonResult;
import com.zbkj.front.response.DevMockRechargeResponse;
import com.zbkj.front.service.DevMockRechargeService;
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
 * 本地开发模拟充值接口。
 */
@RestController("DevMockRechargeController")
@RequestMapping("api/front/recharge/dev")
@Profile("dev")
@ConditionalOnProperty(
        prefix = "crmeb.payment.dev-mock-recharge",
        name = "enabled",
        havingValue = "true",
        matchIfMissing = false)
@Api(tags = "用户 -- 本地开发模拟充值")
public class DevMockRechargeController {

    @Autowired
    private DevMockRechargeService devMockRechargeService;

    @PostMapping("/mock")
    @ApiOperation(value = "本地开发模拟充值")
    public CommonResult<DevMockRechargeResponse> recharge(
            @RequestBody @Validated UserRechargeRequest request) {
        return CommonResult.success(devMockRechargeService.recharge(request));
    }
}
