package com.zbkj.front.service.impl;

import cn.hutool.core.date.DateUtil;
import com.zbkj.common.constants.Constants;
import com.zbkj.common.constants.PayConstants;
import com.zbkj.common.exception.CrmebException;
import com.zbkj.common.model.order.StoreOrder;
import com.zbkj.common.model.user.User;
import com.zbkj.front.request.DevMockPayRequest;
import com.zbkj.front.response.DevMockOrderPayResponse;
import com.zbkj.front.service.DevMockOrderPayService;
import com.zbkj.service.service.OrderPaySuccessQueueService;
import com.zbkj.service.service.StoreOrderService;
import com.zbkj.service.service.UserService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Service;
import org.springframework.transaction.support.TransactionTemplate;

/**
 * 本地开发模拟订单支付实现。
 *
 * <p>不调用微信/支付宝，直接按已支付处理订单，并复用真实支付成功后的后置任务，
 * 保证订单状态、库存、账单等业务逻辑与真实支付一致。</p>
 */
@Service
@Profile("dev")
@ConditionalOnProperty(
        prefix = "crmeb.payment.dev-mock-pay",
        name = "enabled",
        havingValue = "true",
        matchIfMissing = false)
public class DevMockOrderPayServiceImpl implements DevMockOrderPayService {

    private static final int CHANNEL_WE_CHAT_H5 = 2;
    private static final int CHANNEL_ALI_PAY = 6;

    @Autowired
    private StoreOrderService storeOrderService;

    @Autowired
    private UserService userService;

    @Autowired
    private OrderPaySuccessQueueService orderPaySuccessQueueService;

    @Autowired
    private TransactionTemplate transactionTemplate;

    @Override
    public DevMockOrderPayResponse pay(DevMockPayRequest request) {
        String payType = request.getPayType();
        if (!PayConstants.PAY_TYPE_WE_CHAT.equals(payType) && !PayConstants.PAY_TYPE_ALI_PAY.equals(payType)) {
            throw new CrmebException("不支持的模拟支付方式");
        }

        StoreOrder storeOrder = storeOrderService.getByOderId(request.getOrderNo());
        if (storeOrder == null) {
            throw new CrmebException("订单不存在");
        }
        if (Boolean.TRUE.equals(storeOrder.getIsDel())) {
            throw new CrmebException("订单已被删除");
        }
        User currentUser = userService.getInfoException();
        if (!storeOrder.getUid().equals(currentUser.getUid())) {
            throw new CrmebException("无权支付该订单");
        }
        if (Boolean.TRUE.equals(storeOrder.getPaid())) {
            return buildResponse(storeOrder.getOrderId(), payType);
        }

        StoreOrder updateOrder = new StoreOrder()
                .setId(storeOrder.getId())
                .setPayType(payType)
                .setIsChannel(PayConstants.PAY_TYPE_WE_CHAT.equals(payType) ? CHANNEL_WE_CHAT_H5 : CHANNEL_ALI_PAY)
                .setOutTradeNo(Constants.DEV_MOCK_ORDER_TRADE_NO_PREFIX + storeOrder.getId())
                .setUpdateTime(DateUtil.date());
        Boolean execute = transactionTemplate.execute(e -> {
            if (!storeOrderService.updateById(updateOrder)) {
                return Boolean.FALSE;
            }
            return storeOrderService.updatePaid(storeOrder.getOrderId());
        });
        if (!Boolean.TRUE.equals(execute)) {
            StoreOrder freshOrder = storeOrderService.getByOderId(request.getOrderNo());
            if (freshOrder == null || !Boolean.TRUE.equals(freshOrder.getPaid())) {
                throw new CrmebException("模拟支付失败，请重试");
            }
        }

        // 复用真实支付成功后的后置处理（订单日志、账单、积分、库存等）
        orderPaySuccessQueueService.enqueue(storeOrder.getOrderId());
        return buildResponse(storeOrder.getOrderId(), payType);
    }

    private DevMockOrderPayResponse buildResponse(String orderNo, String payType) {
        return new DevMockOrderPayResponse()
                .setMock(Boolean.TRUE)
                .setOrderNo(orderNo)
                .setPayType(payType)
                .setPaid(Boolean.TRUE);
    }
}
