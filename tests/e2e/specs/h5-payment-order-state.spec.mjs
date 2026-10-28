import { test, expect } from '@playwright/test';
import { apiRequest, expectBusinessOk } from '../helpers/api.mjs';
import {
  createBuyNowOrder,
  expectBusinessFailure,
  sqlQuote,
  waitForScalar,
} from '../helpers/core.mjs';
import { queryRows, queryScalar } from '../helpers/database.mjs';
import { readRuntimeFixtures } from '../helpers/fixtures.mjs';

test.describe.serial('@core payment and order state', () => {
  test('mock recharge and balance payment update money, order, bill, and logs atomically', async () => {
    const fixtures = readRuntimeFixtures();
    const initialBalance = Number(
      queryScalar(`SELECT now_money FROM eb_user WHERE uid = ${fixtures.primaryUserId}`),
    );
    const rechargeAmount = Number((fixtures.productPrice + 1).toFixed(2));

    const invalid = await apiRequest(fixtures.frontApi, '/api/front/recharge/dev/mock', {
      method: 'POST',
      token: fixtures.h5Token,
      body: { price: 0, rechar_id: 0, payType: 'weixin', from: 'weixinh5' },
      allowHttpError: true,
    });
    expectBusinessFailure(invalid, /必须大于0|不能低于/);
    expect(Number(queryScalar(`SELECT now_money FROM eb_user WHERE uid = ${fixtures.primaryUserId}`))).toBe(
      initialBalance,
    );

    const recharge = await expectBusinessOk(fixtures.frontApi, '/api/front/recharge/dev/mock', {
      method: 'POST',
      token: fixtures.h5Token,
      body: { price: rechargeAmount, rechar_id: 0, payType: 'weixin', from: 'weixinh5' },
    });
    expect(recharge.mock).toBeTruthy();
    expect(Number(recharge.creditedAmount)).toBe(rechargeAmount);
    expect(Number(recharge.balance)).toBeCloseTo(initialBalance + rechargeAmount, 2);
    expect(
      queryRows(
        `SELECT uid, price, give_price, recharge_type, paid FROM eb_user_recharge WHERE order_id = ${sqlQuote(recharge.orderNo)}`,
      )[0],
    ).toEqual([String(fixtures.primaryUserId), rechargeAmount.toFixed(2), '0.00', 'dev_mock', '1']);
    expect(
      Number(
        queryScalar(
          `SELECT COUNT(*) FROM eb_user_bill WHERE uid = ${fixtures.primaryUserId} AND link_id = ${sqlQuote(recharge.orderNo)} AND type = 'pay_recharge'`,
        ),
      ),
    ).toBe(1);

    const order = await createBuyNowOrder(fixtures, {
      mark: `${fixtures.runId}-balance-${Date.now()}`,
    });
    const paid = await expectBusinessOk(fixtures.frontApi, '/api/front/pay/payment', {
      method: 'POST',
      token: fixtures.h5Token,
      body: { orderNo: order.orderNo, payType: 'yue', payChannel: 'yue', scene: 0 },
    });
    expect(paid).toMatchObject({ status: true, payType: 'yue', orderNo: order.orderNo });

    await waitForScalar(
      `SELECT paid FROM eb_store_order WHERE order_id = ${sqlQuote(order.orderNo)}`,
      (value) => value === '1',
    );
    const orderRow = queryRows(
      `SELECT id, paid, status, pay_type, is_channel, pay_price FROM eb_store_order WHERE order_id = ${sqlQuote(order.orderNo)}`,
    )[0];
    expect(orderRow.slice(1)).toEqual(['1', '0', 'yue', '3', fixtures.productPrice.toFixed(2)]);
    expect(Number(queryScalar(`SELECT now_money FROM eb_user WHERE uid = ${fixtures.primaryUserId}`))).toBeCloseTo(
      initialBalance + rechargeAmount - fixtures.productPrice,
      2,
    );
    await waitForScalar(
      `SELECT COUNT(*) FROM eb_store_order_status WHERE oid = ${Number(orderRow[0])} AND change_type = 'pay_success'`,
      (value) => value === '1',
    );

    const duplicate = await apiRequest(fixtures.frontApi, '/api/front/pay/payment', {
      method: 'POST',
      token: fixtures.h5Token,
      body: { orderNo: order.orderNo, payType: 'yue', payChannel: 'yue', scene: 0 },
      allowHttpError: true,
    });
    expectBusinessFailure(duplicate, /订单已支付/);
  });

  test('mock WeChat and Alipay are idempotent and reject another user', async () => {
    const fixtures = readRuntimeFixtures();
    const wechatOrder = await createBuyNowOrder(fixtures, {
      mark: `${fixtures.runId}-weixin-${Date.now()}`,
    });
    const payBody = { orderNo: wechatOrder.orderNo, payType: 'weixin' };
    const first = await expectBusinessOk(fixtures.frontApi, '/api/front/pay/dev/mock', {
      method: 'POST',
      token: fixtures.h5Token,
      body: payBody,
    });
    expect(first).toMatchObject({ mock: true, paid: true, payType: 'weixin' });
    const second = await expectBusinessOk(fixtures.frontApi, '/api/front/pay/dev/mock', {
      method: 'POST',
      token: fixtures.h5Token,
      body: payBody,
    });
    expect(second).toMatchObject({ mock: true, paid: true, orderNo: wechatOrder.orderNo });

    const row = queryRows(
      `SELECT id, paid, pay_type, is_channel, out_trade_no, pay_price
       FROM eb_store_order
       WHERE order_id = ${sqlQuote(wechatOrder.orderNo)}`,
    )[0];
    expect(row.slice(1, 4)).toEqual(['1', 'weixin', '2']);
    expect(row[4]).toBe(`devmock${row[0]}`);
    await waitForScalar(
      `SELECT COUNT(*) FROM eb_store_order_status WHERE oid = ${Number(row[0])} AND change_type = 'pay_success'`,
      (value) => value === '1',
    );

    const crossUser = await apiRequest(fixtures.frontApi, '/api/front/pay/dev/mock', {
      method: 'POST',
      token: fixtures.secondH5Token,
      body: payBody,
      allowHttpError: true,
    });
    expectBusinessFailure(crossUser, /无权支付/);

    await expectBusinessOk(fixtures.adminApi, '/api/admin/store/order/refund', {
      token: fixtures.adminToken,
      query: { orderNo: wechatOrder.orderNo, amount: row[5] },
    });
    expect(
      queryRows(
        `SELECT refund_status, refund_price
         FROM eb_store_order
         WHERE order_id = ${sqlQuote(wechatOrder.orderNo)}`,
      )[0],
    ).toEqual(['2', row[5]]);

    const duplicateRefund = await apiRequest(fixtures.adminApi, '/api/admin/store/order/refund', {
      token: fixtures.adminToken,
      query: { orderNo: wechatOrder.orderNo, amount: row[5] },
      allowHttpError: true,
    });
    expectBusinessFailure(duplicateRefund, /已退款|请勿重复操作/);

    const alipayOrder = await createBuyNowOrder(fixtures, {
      productId: fixtures.secondProductId,
      attrValueId: fixtures.secondProductAttrValueId,
      mark: `${fixtures.runId}-alipay-${Date.now()}`,
    });
    await expectBusinessOk(fixtures.frontApi, '/api/front/pay/dev/mock', {
      method: 'POST',
      token: fixtures.h5Token,
      body: { orderNo: alipayOrder.orderNo, payType: 'alipay' },
    });
    const alipayRow = queryRows(
      `SELECT id, paid, pay_type, is_channel, out_trade_no, pay_price
       FROM eb_store_order
       WHERE order_id = ${sqlQuote(alipayOrder.orderNo)}`,
    )[0];
    expect(alipayRow.slice(1, 4)).toEqual(['1', 'alipay', '6']);
    expect(alipayRow[4]).toBe(`devmock${alipayRow[0]}`);
    await waitForScalar(
      `SELECT COUNT(*) FROM eb_store_order_status WHERE oid = ${Number(alipayRow[0])} AND change_type = 'pay_success'`,
      (value) => value === '1',
    );

    await expectBusinessOk(fixtures.adminApi, '/api/admin/store/order/refund', {
      token: fixtures.adminToken,
      query: { orderNo: alipayOrder.orderNo, amount: alipayRow[5] },
    });
    expect(
      queryRows(
        `SELECT refund_status, refund_price
         FROM eb_store_order
         WHERE order_id = ${sqlQuote(alipayOrder.orderNo)}`,
      )[0],
    ).toEqual(['2', alipayRow[5]]);
  });
});
