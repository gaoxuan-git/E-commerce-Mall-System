import { test, expect } from '@playwright/test';
import { expectBusinessOk } from '../helpers/api.mjs';
import { createBuyNowOrder, sqlQuote, waitForScalar } from '../helpers/core.mjs';
import { queryRows } from '../helpers/database.mjs';
import { readRuntimeFixtures } from '../helpers/fixtures.mjs';

test.describe.serial('@one-pass-dev-mock local third-party simulation', () => {
  test('templates and shipment companies work without credentials', async () => {
    const fixtures = readRuntimeFixtures();

    const templates = await expectBusinessOk(
      fixtures.adminApi,
      '/api/admin/express/template',
      {
        token: fixtures.adminToken,
        query: { com: 'yunda' },
      },
    );
    expect(templates.data.data[0]).toMatchObject({
      temp_id: 'DEV-YUNDA-001',
      title: '本地测试面单',
    });

    const shipmentCompanies = await expectBusinessOk(
      fixtures.adminApi,
      '/api/admin/pass/shipment/express',
      { token: fixtures.adminToken },
    );
    expect(shipmentCompanies.data.some((item) => item.value === 'yunda')).toBe(true);
  });

  test('merchant shipment immediately records local tracking data', async () => {
    const fixtures = readRuntimeFixtures();
    const order = await createBuyNowOrder(fixtures, {
      mark: `${fixtures.runId}-dev-shipment-${Date.now()}`,
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

    await expectBusinessOk(fixtures.adminApi, '/api/admin/store/order/send', {
      method: 'POST',
      token: fixtures.adminToken,
      body: {
        orderNo: order.orderNo,
        deliveryType: 'express',
        expressRecordType: '3',
        expressCode: 'yunda',
        expressName: '韵达快递',
        shipment: {
          kuaidicom: 'yunda',
          sendRealName: '本地测试寄件人',
          sendPhone: '13900000000',
          sendAddress: '本地测试地址',
          serviceType: '标准快递',
          tempid: 'DEV-YUNDA-001',
          dayType: '0',
        },
      },
    });

    await waitForScalar(
      `SELECT status FROM eb_store_order WHERE order_id = ${sqlQuote(order.orderNo)}`,
      (value) => value === '1',
    );
    const orderRow = queryRows(
      `SELECT status, delivery_code, delivery_id, shipment_num
         FROM eb_store_order
        WHERE order_id = ${sqlQuote(order.orderNo)}`,
    )[0];

    expect(orderRow[0]).toBe('1');
    expect(orderRow[1]).toBe('yunda');
    expect(orderRow[2]).toMatch(/^DEV/);
    expect(orderRow[3]).toBe(orderRow[2]);
  });
});
