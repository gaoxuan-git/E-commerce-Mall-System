import { test, expect } from '@playwright/test';
import { apiRequest, expectBusinessOk } from '../helpers/api.mjs';
import { createBuyNowOrder, expectBusinessFailure, sqlQuote } from '../helpers/core.mjs';
import { queryRows, queryScalar } from '../helpers/database.mjs';
import { readRuntimeFixtures } from '../helpers/fixtures.mjs';

async function cartList(fixtures) {
  return expectBusinessOk(fixtures.frontApi, '/api/front/cart/list', {
    token: fixtures.h5Token,
    query: { isValid: true, page: 1, limit: 100 },
  });
}

async function deleteCart(fixtures, id) {
  return apiRequest(fixtures.frontApi, '/api/front/cart/delete', {
    method: 'POST',
    token: fixtures.h5Token,
    query: { ids: id },
    allowHttpError: true,
  });
}

test.describe.serial('@core cart and order creation', () => {
  test('cart add, merge, quantity validation, pre-order, and delete are consistent', async () => {
    const fixtures = readRuntimeFixtures();
    const existing = (await cartList(fixtures)).list.filter(
      (item) => Number(item.productId) === fixtures.secondProductId,
    );
    for (const item of existing) await deleteCart(fixtures, item.id);

    let cartId;
    try {
      const add = () =>
        expectBusinessOk(fixtures.frontApi, '/api/front/cart/save', {
          method: 'POST',
          token: fixtures.h5Token,
          body: {
            productId: fixtures.secondProductId,
            productAttrUnique: fixtures.secondProductAttrUnique,
            cartNum: 1,
          },
        });
      cartId = Number((await add()).cartId);
      expect(Number((await add()).cartId)).toBe(cartId);

      let item = (await cartList(fixtures)).list.find((entry) => Number(entry.id) === cartId);
      expect(item.cartNum).toBe(2);

      await expectBusinessOk(fixtures.frontApi, '/api/front/cart/num', {
        method: 'POST',
        token: fixtures.h5Token,
        query: { id: cartId, number: 3 },
      });
      item = (await cartList(fixtures)).list.find((entry) => Number(entry.id) === cartId);
      expect(item.cartNum).toBe(3);

      const invalidQuantity = await apiRequest(fixtures.frontApi, '/api/front/cart/num', {
        method: 'POST',
        token: fixtures.h5Token,
        query: { id: cartId, number: 0 },
        allowHttpError: true,
      });
      expectBusinessFailure(invalidQuantity, /数量/);
      expect(Number(queryScalar(`SELECT cart_num FROM eb_store_cart WHERE id = ${cartId}`))).toBe(3);

      const pre = await expectBusinessOk(fixtures.frontApi, '/api/front/order/pre/order', {
        method: 'POST',
        token: fixtures.h5Token,
        body: {
          preOrderType: 'shoppingCart',
          orderDetails: [{ shoppingCartId: cartId }],
        },
      });
      const loaded = await expectBusinessOk(
        fixtures.frontApi,
        `/api/front/order/load/pre/${pre.preOrderNo}`,
        { token: fixtures.h5Token },
      );
      expect(loaded.orderInfoVo.orderProNum).toBe(3);
      expect(Number(loaded.orderInfoVo.payFee)).toBeCloseTo(fixtures.secondProductPrice * 3, 2);

      const deleted = await deleteCart(fixtures, cartId);
      expect([0, 200]).toContain(deleted.payload?.code);
      expect((await cartList(fixtures)).list.some((entry) => Number(entry.id) === cartId)).toBeFalsy();
      cartId = null;
    } finally {
      if (cartId) await deleteCart(fixtures, cartId);
    }
  });

  test('buy-now amount, persisted order, and duplicate create behavior are correct', async () => {
    const fixtures = readRuntimeFixtures();
    const mark = `${fixtures.runId}-create-${Date.now()}`;
    const order = await createBuyNowOrder(fixtures, { productNum: 2, mark });

    const total = fixtures.productPrice * 2;
    expect(order.loaded.orderInfoVo.orderProNum).toBe(2);
    expect(Number(order.loaded.orderInfoVo.proTotalFee)).toBeCloseTo(total, 2);
    expect(Number(order.loaded.orderInfoVo.payFee)).toBeCloseTo(total, 2);

    const rows = queryRows(
      `SELECT order_id, uid, total_num, total_price, pay_price, paid, status, mark FROM eb_store_order WHERE order_id = ${sqlQuote(order.orderNo)}`,
    );
    expect(rows).toHaveLength(1);
    expect(rows[0]).toEqual([order.orderNo, String(fixtures.primaryUserId), '2', total.toFixed(2), total.toFixed(2), '0', '0', mark]);

    const duplicate = await apiRequest(fixtures.frontApi, '/api/front/order/create', {
      method: 'POST',
      token: fixtures.h5Token,
      body: order.createBody,
      allowHttpError: true,
    });
    expectBusinessFailure(duplicate, /预下单订单不存在/);
    expect(
      Number(
        queryScalar(
          `SELECT COUNT(*) FROM eb_store_order WHERE uid = ${fixtures.primaryUserId} AND mark = ${sqlQuote(mark)}`,
        ),
      ),
    ).toBe(1);
  });

  test('address flow preserves pre-order context after password login', async ({ browser }) => {
    const context = await browser.newContext({
      viewport: { width: 390, height: 844 },
      storageState: { cookies: [], origins: [] },
    });
    const page = await context.newPage();
    const consoleErrors = [];
    const pageErrors = [];
    const preOrderNo = String(Date.now());
    const h5Base = process.env.H5_BASE_URL || 'http://127.0.0.1:5273';

    page.on('console', (message) => {
      if (message.type() === 'error') consoleErrors.push(message.text());
    });
    page.on('pageerror', (error) => pageErrors.push(error.message));

    try {
      await page.goto(
        new URL(`/pages/users/user_address/index?preOrderNo=${preOrderNo}`, h5Base).toString(),
        { waitUntil: 'networkidle' },
      );
      await page.waitForURL(/\/pages\/users\/login\/index/);
      await page.getByText('密码登录', { exact: true }).click();
      await page.locator('input[type="number"]').fill(process.env.E2E_USER_ACCOUNT);
      await page.locator('input[type="password"]').fill(process.env.E2E_USER_PASSWORD);
      await page.locator('uni-checkbox').click();
      await page.getByText('登录', { exact: true }).last().click();
      await page.waitForURL(
        (url) =>
          url.pathname === '/pages/users/user_address/index' &&
          url.searchParams.get('preOrderNo') === preOrderNo,
      );
      await expect(page.getByText('立即保存', { exact: true })).toBeVisible();

      expect(consoleErrors).toEqual([]);
      expect(pageErrors).toEqual([]);
    } finally {
      await context.close();
    }
  });
});
