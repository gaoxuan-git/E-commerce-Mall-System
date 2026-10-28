package com.zbkj.front.service.impl;

import com.zbkj.common.constants.Constants;
import com.zbkj.common.exception.CrmebException;
import com.zbkj.common.model.finance.UserRecharge;
import com.zbkj.common.model.user.User;
import com.zbkj.common.request.UserRechargeRequest;
import com.zbkj.common.utils.CrmebUtil;
import com.zbkj.common.vo.SystemGroupDataRechargeConfigVo;
import com.zbkj.front.response.DevMockRechargeResponse;
import com.zbkj.front.service.DevMockRechargeService;
import com.zbkj.service.service.RechargePayService;
import com.zbkj.service.service.SystemConfigService;
import com.zbkj.service.service.SystemGroupDataService;
import com.zbkj.service.service.UserRechargeService;
import com.zbkj.service.service.UserService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;

/**
 * 本地开发模拟充值实现。
 */
@Service
@Profile("dev")
@ConditionalOnProperty(
        prefix = "crmeb.payment.dev-mock-recharge",
        name = "enabled",
        havingValue = "true",
        matchIfMissing = false)
public class DevMockRechargeServiceImpl implements DevMockRechargeService {

    private static final BigDecimal MAX_RECHARGE_AMOUNT = new BigDecimal("50000");
    private static final String RECHARGE_TYPE = "dev_mock";

    @Autowired
    private UserService userService;

    @Autowired
    private SystemConfigService systemConfigService;

    @Autowired
    private SystemGroupDataService systemGroupDataService;

    @Autowired
    private UserRechargeService userRechargeService;

    @Autowired
    private RechargePayService rechargePayService;

    @Override
    @Transactional(rollbackFor = {RuntimeException.class, Error.class, CrmebException.class})
    public DevMockRechargeResponse recharge(UserRechargeRequest request) {
        BigDecimal rechargeAmount;
        BigDecimal giveAmount = BigDecimal.ZERO;

        Integer groupDataId = request.getGroupDataId();
        if (groupDataId != null && groupDataId > 0) {
            SystemGroupDataRechargeConfigVo packageConfig = systemGroupDataService.getNormalInfo(
                    groupDataId, SystemGroupDataRechargeConfigVo.class);
            if (packageConfig == null) {
                throw new CrmebException("您选择的充值方式已下架");
            }
            rechargeAmount = packageConfig.getPrice();
            if (packageConfig.getGiveMoney() != null) {
                giveAmount = packageConfig.getGiveMoney();
            }
        } else {
            rechargeAmount = validateCustomAmount(request.getPrice());
        }

        User currentUser = userService.getInfoException();
        UserRecharge order = new UserRecharge()
                .setUid(currentUser.getUid())
                .setOrderId(CrmebUtil.getOrderNo("recharge"))
                .setPrice(rechargeAmount)
                .setGivePrice(giveAmount)
                .setRechargeType(RECHARGE_TYPE)
                .setPaid(false)
                .setOutTradeNo("");

        if (!userRechargeService.save(order)) {
            throw new CrmebException("生成模拟充值订单失败");
        }
        if (!Boolean.TRUE.equals(rechargePayService.paySuccess(order))) {
            throw new CrmebException("模拟充值失败，请重试");
        }

        User updatedUser = userService.getById(currentUser.getUid());
        BigDecimal creditedAmount = rechargeAmount.add(giveAmount);
        return new DevMockRechargeResponse()
                .setMock(true)
                .setOrderNo(order.getOrderId())
                .setRechargeAmount(rechargeAmount)
                .setGiveAmount(giveAmount)
                .setCreditedAmount(creditedAmount)
                .setBalance(updatedUser.getNowMoney());
    }

    private BigDecimal validateCustomAmount(BigDecimal amount) {
        if (amount == null) {
            throw new CrmebException("请输入充值金额");
        }
        if (amount.compareTo(BigDecimal.ZERO) <= 0) {
            throw new CrmebException("充值金额必须大于0");
        }

        String minimumAmountValue = systemConfigService.getValueByKeyException(
                Constants.CONFIG_KEY_RECHARGE_MIN_AMOUNT);
        BigDecimal minimumAmount = new BigDecimal(minimumAmountValue);
        if (amount.compareTo(minimumAmount) < 0) {
            throw new CrmebException("充值金额不能低于" + minimumAmountValue);
        }
        if (amount.compareTo(MAX_RECHARGE_AMOUNT) > 0) {
            throw new CrmebException("充值金额最大值为50000");
        }
        return amount;
    }
}
