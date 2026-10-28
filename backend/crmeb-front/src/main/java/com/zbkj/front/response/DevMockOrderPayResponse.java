package com.zbkj.front.response;

import io.swagger.annotations.ApiModel;
import io.swagger.annotations.ApiModelProperty;
import lombok.Data;
import lombok.EqualsAndHashCode;
import lombok.experimental.Accessors;

import java.io.Serializable;

/**
 * 本地开发模拟支付响应。
 */
@Data
@EqualsAndHashCode(callSuper = false)
@Accessors(chain = true)
@ApiModel(value = "DevMockOrderPayResponse对象", description = "本地开发模拟支付响应")
public class DevMockOrderPayResponse implements Serializable {

    private static final long serialVersionUID = 1L;

    @ApiModelProperty(value = "是否模拟支付")
    private Boolean mock;

    @ApiModelProperty(value = "订单编号")
    private String orderNo;

    @ApiModelProperty(value = "支付方式")
    private String payType;

    @ApiModelProperty(value = "是否已支付")
    private Boolean paid;
}
