package com.zbkj.front.response;

import io.swagger.annotations.ApiModel;
import io.swagger.annotations.ApiModelProperty;
import lombok.Data;
import lombok.experimental.Accessors;

import java.io.Serializable;
import java.math.BigDecimal;

/**
 * 本地开发模拟充值响应。
 */
@Data
@Accessors(chain = true)
@ApiModel(value = "DevMockRechargeResponse", description = "本地开发模拟充值结果")
public class DevMockRechargeResponse implements Serializable {

    private static final long serialVersionUID = 1L;

    @ApiModelProperty(value = "是否为模拟充值")
    private Boolean mock;

    @ApiModelProperty(value = "充值订单号")
    private String orderNo;

    @ApiModelProperty(value = "充值金额")
    private BigDecimal rechargeAmount;

    @ApiModelProperty(value = "赠送金额")
    private BigDecimal giveAmount;

    @ApiModelProperty(value = "到账总额")
    private BigDecimal creditedAmount;

    @ApiModelProperty(value = "最新余额")
    private BigDecimal balance;
}
