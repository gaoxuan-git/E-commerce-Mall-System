import { test, expect } from '@playwright/test';
import { expectBusinessOk } from '../helpers/api.mjs';
import { createBuyNowOrder, sqlQuote, waitForScalar } from '../helpers/core.mjs';
import { queryRows, queryScalar } from '../helpers/database.mjs';
import { readRuntimeFixtures } from '../helpers/fixtures.mjs';

test.describe.serial('@core cross-system order lifecycle', () => {
  test('front create/pay, admin fulfill, and front receive/review remain consistent', async () => {
    const fixtures = readRuntimeFixtures();
    const order = await createBuyNowOrder(fixtures, {
      mark: `${fixtures.runId}-lifecycle-${Date.now()}`,
    });
    await expectBusinessOk(fixtures.frontApi, '/api/front/pay/dev/mock', {
      method: 'POST',
      token: fixtures.h5Token,
      body: { orderNo: order.orderNo, payType: 'weixin' },
    });
    await waitForScalar(
      `SELECT paid FROM eb_store_order WHERE order_id = ${sqlQuote(order.orderNo)}`,
      (value) => value === '1',
    );

    const adminList = await expectBusinessOk(fixtures.adminApi, '/api/admin/store/order/list', {
      token: fixtures.adminToken,
      query: { type: 2, status: 'notShipped', orderNo: order.orderNo, page: 1, limit: 10 },
    });
    expect(adminList.list).toHaveLength(1);
    expect(adminList.list[0].orderId).toBe(order.orderNo);

    await expectBusinessOk(fixtures.adminApi, '/api/admin/store/order/send', {
      method: 'POST',
      token: fixtures.adminToken,
      body: {
        orderNo: order.orderNo,
        deliveryType: 'fictitious',
        expressRecordType: '1',
      },
    });
    let frontDetail = await expectBusinessOk(
      fixtures.frontApi,
      `/api/front/order/detail/${order.orderNo}`,
      { token: fixtures.h5Token },
    );
    expect(frontDetail).toMatchObject({ paid: true, status: 1, deliveryType: 'fictitious' });

    await expectBusinessOk(fixtures.frontApi, '/api/front/order/take', {
      method: 'POST',
      token: fixtures.h5Token,
      query: { id: frontDetail.id },
    });
    frontDetail = await expectBusinessOk(fixtures.frontApi, `/api/front/order/detail/${order.orderNo}`, {
      token: fixtures.h5Token,
    });
    expect(frontDetail.status).toBe(2);

    const replyProduct = await expectBusinessOk(fixtures.frontApi, '/api/front/order/product', {
      method: 'POST',
      token: fixtures.h5Token,
      body: { orderId: frontDetail.id, uni: String(fixtures.productAttrValueId) },
    });
    expect(replyProduct.productId).toBe(fixtures.productId);

    const comment = `${fixtures.runId} lifecycle review`;
    await expectBusinessOk(fixtures.frontApi, '/api/front/order/comment', {
      method: 'POST',
      token: fixtures.h5Token,
      body: {
        orderNo: order.orderNo,
        productId: fixtures.productId,
        unique: String(fixtures.productAttrValueId),
        productScore: 5,
        serviceScore: 5,
        comment,
        pics: '',
        sku: replyProduct.sku,
      },
    });
    expect(
      Number(
        queryScalar(
          `SELECT COUNT(*) FROM eb_store_product_reply WHERE oid = ${frontDetail.id} AND comment = ${sqlQuote(comment)}`,
        ),
      ),
    ).toBe(1);
    expect(
      queryRows(
        `SELECT paid, status, refund_status FROM eb_store_order WHERE order_id = ${sqlQuote(order.orderNo)}`,
      )[0],
    ).toEqual(['1', '3', '0']);

    const adminDetail = await expectBusinessOk(fixtures.adminApi, '/api/admin/store/order/info', {
      token: fixtures.adminToken,
      query: { orderNo: order.orderNo },
    });
    expect(adminDetail.orderId).toBe(order.orderNo);
    expect(adminDetail.status).toBe(3);
  });
});
