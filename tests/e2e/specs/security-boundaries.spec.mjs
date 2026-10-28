import { test, expect } from '@playwright/test';
import { apiRequest, expectBusinessOk } from '../helpers/api.mjs';
import { createBuyNowOrder, expectBusinessFailure, sqlQuote } from '../helpers/core.mjs';
import { queryRows, queryScalar } from '../helpers/database.mjs';
import { readRuntimeFixtures } from '../helpers/fixtures.mjs';

test.describe.serial('@core authorization and failure boundaries', () => {
  test('anonymous users cannot access profile, cart, orders, or admin data', async () => {
    const fixtures = readRuntimeFixtures();
    for (const [baseURL, path] of [
      [fixtures.frontApi, '/api/front/user'],
      [fixtures.frontApi, '/api/front/cart/list?isValid=true&page=1&limit=10'],
      [fixtures.frontApi, '/api/front/order/list?type=0&page=1&limit=10'],
      [fixtures.adminApi, '/api/admin/store/order/list?type=2&status=all&page=1&limit=10'],
    ]) {
      const result = await apiRequest(baseURL, path, { allowHttpError: true });
      expect([0, 200], `${path} unexpectedly succeeded`).not.toContain(result.payload?.code);
    }
  });

  test('cart IDs cannot be modified or deleted by another user', async () => {
    const fixtures = readRuntimeFixtures();
    const row = queryRows(
      `SELECT id, cart_num FROM eb_store_cart WHERE uid = ${fixtures.secondUserId} AND status = 1 ORDER BY id LIMIT 1`,
    )[0];
    expect(row).toBeTruthy();
    const [cartId, originalQuantity] = row;

    const update = await apiRequest(fixtures.frontApi, '/api/front/cart/num', {
      method: 'POST',
      token: fixtures.h5Token,
      query: { id: cartId, number: Number(originalQuantity) + 1 },
      allowHttpError: true,
    });
    expectBusinessFailure(update, /购物车不存在|无权/);
    expect(queryScalar(`SELECT cart_num FROM eb_store_cart WHERE id = ${Number(cartId)}`)).toBe(originalQuantity);

    const deletion = await apiRequest(fixtures.frontApi, '/api/front/cart/delete', {
      method: 'POST',
      token: fixtures.h5Token,
      query: { ids: cartId },
      allowHttpError: true,
    });
    expectBusinessFailure(deletion, /购物车不存在|无权/);
    expect(Number(queryScalar(`SELECT COUNT(*) FROM eb_store_cart WHERE id = ${Number(cartId)}`))).toBe(1);
  });

  test('order payment, detail, and refund operations enforce ownership', async () => {
    const fixtures = readRuntimeFixtures();
    const order = await createBuyNowOrder(fixtures, {
      mark: `${fixtures.runId}-security-${Date.now()}`,
    });
    const before = queryRows(
      `SELECT paid, refund_status FROM eb_store_order WHERE order_id = ${sqlQuote(order.orderNo)}`,
    )[0];

    const detail = await apiRequest(fixtures.frontApi, `/api/front/order/detail/${order.orderNo}`, {
      token: fixtures.secondH5Token,
      allowHttpError: true,
    });
    expectBusinessFailure(detail, /订单不存在|无权/);

    const payment = await apiRequest(fixtures.frontApi, '/api/front/pay/payment', {
      method: 'POST',
      token: fixtures.secondH5Token,
      body: { orderNo: order.orderNo, payType: 'yue', payChannel: 'yue', scene: 0 },
      allowHttpError: true,
    });
    expectBusinessFailure(payment, /订单不存在|无权支付/);
    expect(
      queryRows(
        `SELECT paid, refund_status FROM eb_store_order WHERE order_id = ${sqlQuote(order.orderNo)}`,
      )[0],
    ).toEqual(before);

    const refundInfo = await apiRequest(
      fixtures.frontApi,
      `/api/front/order/apply/refund/${order.orderNo}`,
      { token: fixtures.secondH5Token, allowHttpError: true },
    );
    expectBusinessFailure(refundInfo, /订单不存在|无权/);

    await expectBusinessOk(fixtures.frontApi, '/api/front/pay/dev/mock', {
      method: 'POST',
      token: fixtures.h5Token,
      body: { orderNo: order.orderNo, payType: 'weixin' },
    });
    const refund = await apiRequest(fixtures.frontApi, '/api/front/order/refund', {
      method: 'POST',
      token: fixtures.secondH5Token,
      body: {
        id: Number(
          queryScalar(`SELECT id FROM eb_store_order WHERE order_id = ${sqlQuote(order.orderNo)}`),
        ),
        uni: order.orderNo,
        text: 'cross-user refund attempt',
        refund_reason_wap_img: '',
        refund_reason_wap_explain: '',
      },
      allowHttpError: true,
    });
    expectBusinessFailure(refund, /支付订单不存在|订单不存在|无权/);
    expect(
      queryScalar(`SELECT refund_status FROM eb_store_order WHERE order_id = ${sqlQuote(order.orderNo)}`),
    ).toBe('0');
  });

  test('mock payment rejects unsupported types and missing orders', async () => {
    const fixtures = readRuntimeFixtures();
    const unsupported = await apiRequest(fixtures.frontApi, '/api/front/pay/dev/mock', {
      method: 'POST',
      token: fixtures.h5Token,
      body: { orderNo: `missing-${Date.now()}`, payType: 'yue' },
      allowHttpError: true,
    });
    expectBusinessFailure(unsupported, /不支持的模拟支付方式/);

    const missing = await apiRequest(fixtures.frontApi, '/api/front/pay/dev/mock', {
      method: 'POST',
      token: fixtures.h5Token,
      body: { orderNo: `missing-${Date.now()}`, payType: 'weixin' },
      allowHttpError: true,
    });
    expectBusinessFailure(missing, /订单不存在/);
  });
});
