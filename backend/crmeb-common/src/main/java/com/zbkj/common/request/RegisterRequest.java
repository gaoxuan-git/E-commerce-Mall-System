package com.zbkj.common.request;

import com.fasterxml.jackson.annotation.JsonProperty;
import com.zbkj.common.constants.RegularConstants;
import io.swagger.annotations.ApiModel;
import io.swagger.annotations.ApiModelProperty;
import lombok.Data;
import lombok.EqualsAndHashCode;
import lombok.experimental.Accessors;

import javax.validation.constraints.NotBlank;
import javax.validation.constraints.Pattern;
import java.io.Serializable;

@Data
@EqualsAndHashCode(callSuper = false)
@Accessors(chain = true)
@ApiModel(value = "RegisterRequest对象", description = "移动端手机号注册请求对象")
public class RegisterRequest implements Serializable {

    private static final long serialVersionUID = 1L;

    @ApiModelProperty(value = "手机号", required = true)
    @NotBlank(message = "手机号不能为空")
    @Pattern(regexp = RegularConstants.PHONE_TWO, message = "手机号码格式错误")
    @JsonProperty("account")
    private String phone;

    @ApiModelProperty(value = "短信验证码", required = true)
    @NotBlank(message = "验证码不能为空")
    @Pattern(regexp = RegularConstants.VALIDATE_CODE_NUM_SIX, message = "验证码必须为6位数字")
    private String captcha;

    @ApiModelProperty(value = "登录密码", required = true)
    @NotBlank(message = "密码不能为空")
    @Pattern(
            regexp = RegularConstants.PASSWORD,
            message = "密码必须以字母开头，长度为6~18位，只能包含字母、数字和下划线"
    )
    private String password;

    @ApiModelProperty(value = "推广人id")
    @JsonProperty("spread_spid")
    private Integer spreadPid = 0;
}
