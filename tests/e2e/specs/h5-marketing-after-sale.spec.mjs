import { test, expect } from '@playwright/test';
import { apiRequest, expectBusinessOk } from '../helpers/api.mjs';
import { createBuyNowOrder, expectBusinessFailure } from '../helpers/core.mjs';
import { readRuntimeFixtures } from '../helpers/fixtures.mjs';
import { assertPageHealthy, installDiagnostics } from '../helpers/diagnostics.mjs';

test.describe.serial('@core marketing and after-sale boundaries', () => {
  test('bargain help records render, expand and collapse without undefined index warnings', async ({ page }) => {
    const fixtures = readRuntimeFixtures();
    const diagnostics = installDiagnostics(page);
    const warnings = [];
    page.on('console', message => {
      if (message.type() === 'warning' && /Property "index".*not defined/.test(message.text())) {
        warnings.push(message.text());
      }
    });
    const helpList = Array.from({ length: 5 }, (_, index) => ({
      nickname: `助力测试好友${index + 1}`,
      avatar: `${fixtures.adminApi}/crmebimage/perset/staticImg/avatar.png`,
      addTimeStr: '2026-10-24 20:00:36',
      price: (index + 1).toFixed(2),
    }));
    // Isolate the display boundary from activity expiry and random bargain amounts.
    await page.route('**/api/front/bargain/detail/*', async route => {
      const response = await route.fetch();
      const payload = await response.json();
      payload.data.stopTime = Date.now() + 3_600_000;
      payload.data.quota = 10;
      await route.fulfill({ response, json: payload });
    });
    await page.route('**/api/front/bargain/user?*', route => route.fulfill({
      json: {
        code: 200,
        data: {
          bargainStatus: 3,
          storeBargainUserId: 0,
          alreadyPrice: 15,
          surplusPrice: 20,
          bargainPercent: 43,
          userHelpList: helpList,
        },
      },
    }));
    await page.goto(`/pages/activity/goods_bargain_details/index?id=${fixtures.bargainId}`);
    const rows = page.locator('.bargainGang .list .item');
    await expect(rows).toHaveCount(3);
    await expect(rows.first()).toContainText('助力测试好友1');
    await expect(rows.first()).toContainText('2026-10-24 20:00:36');
    await expect(rows.first()).toContainText('1.00');
    await page.locator('.bargainGang .open').click();
    await expect(rows).toHaveCount(5);
    await expect(rows.last()).toContainText('助力测试好友5');
    await page.locator('.bargainGang .open').click();
    await expect(rows).toHaveCount(3);
    await assertPageHealthy(page, diagnostics);
    expect(warnings).toEqual([]);
  });

  test('seckill detail navigation and SKU image preview survive reactive updates', async ({ page }) => {
    const fixtures = readRuntimeFixtures();
    const diagnostics = installDiagnostics(page);
    const templateWarnings = [];
    page.on('console', message => {
      if (message.type() === 'warning' && /missing template or render function/.test(message.text())) {
        templateWarnings.push(message.text());
      }
    });
    await page.goto(`/pages/activity/goods_seckill_details/index?id=${fixtures.seckillId}`);
    await expect(page.locator('.product-con .introduce .infor')).not.toBeEmpty();
    await expect(page.locator('.navbar')).toBeVisible();
    await page.locator('.navbar .header .item').filter({ hasText: '详情' }).click();
    await expect(page.locator('#past2 .title')).toBeInViewport();
    await page.locator('.navbar .header .item').filter({ hasText: '商品' }).click();
    await expect(page.locator('#past0 .introduce')).toBeInViewport();
    await page.locator('.attribute .p-24').first().click();
    await expect(page.locator('.product-window')).toHaveClass(/on/);
    await page.locator('.product-window.on .textpic .pictrue').click();
    await expect(page.locator('.previewImg')).toBeVisible();
    await expect(page.locator('.previewImg .sku_name')).not.toBeEmpty();
    await expect(page.locator('.previewImg .sku_price')).toContainText('￥');
    await page.locator('.previewImg .mask').click({ position: { x: 10, y: 10 } });
    await expect(page.locator('.previewImg')).toHaveCount(0);
    await assertPageHealthy(page, diagnostics, { settleMs: 1500 });
    expect(templateWarnings).toEqual([]);
  });

  test('combination SKU image preview opens and closes without template or event errors', async ({ page }) => {
    const fixtures = readRuntimeFixtures();
    const diagnostics = installDiagnostics(page);
    const templateWarnings = [];
    page.on('console', message => {
      if (message.type() === 'warning' && /missing template or render function/.test(message.text())) {
        templateWarnings.push(message.text());
      }
    });
    await page.goto(`/pages/activity/goods_combination_details/index?id=${fixtures.combinationId}`);
    await expect(page.locator('.product-con .introduce')).not.toBeEmpty();
    await page.locator('.attribute').first().click();
    await expect(page.locator('.product-window')).toHaveClass(/on/);
    await page.locator('.product-window.on .textpic .pictrue').click();
    await expect(page.locator('.previewImg')).toBeVisible();
    await expect(page.locator('.previewImg .sku_name')).not.toBeEmpty();
    await expect(page.locator('.previewImg .sku_price')).toContainText('￥');
    await page.locator('.previewImg .mask').click({ position: { x: 10, y: 10 } });
    await expect(page.locator('.previewImg')).toHaveCount(0);
    await expect(page.locator('.product-window')).toHaveClass(/on/);
    await assertPageHealthy(page, diagnostics, { settleMs: 1500 });
    expect(templateWarnings).toEqual([]);
  });

  test('sign-in and configured activity APIs return stable domain objects', async () => {
    const fixtures = readRuntimeFixtures();
    const signConfig = await expectBusinessOk(fixtures.frontApi, '/api/front/user/sign/config', {
      token: fixtures.h5Token,
    });
    expect(signConfig).toBeInstanceOf(Array);
    const signState = await expectBusinessOk(fixtures.frontApi, '/api/front/user/sign/get', {
      token: fixtures.h5Token,
    });
    expect(typeof signState.today).toBe('boolean');
    const signUser = await expectBusinessOk(fixtures.frontApi, '/api/front/user/sign/user', {
      method: 'POST',
      token: fixtures.h5Token,
    });
    expect(signUser).toEqual(expect.any(Object));

    const seckill = await expectBusinessOk(
      fixtures.frontApi,
      `/api/front/seckill/detail/${fixtures.seckillId}`,
      { token: fixtures.h5Token },
    );
    expect(Number(seckill.storeSeckill.id)).toBe(fixtures.seckillId);
    const combination = await expectBusinessOk(
      fixtures.frontApi,
      `/api/front/combination/detail/${fixtures.combinationId}`,
      { token: fixtures.h5Token },
    );
    expect(Number(combination.storeCombination.id)).toBe(fixtures.combinationId);
    const bargain = await expectBusinessOk(
      fixtures.frontApi,
      `/api/front/bargain/detail/${fixtures.bargainId}`,
      { token: fixtures.h5Token },
    );
    expect(Number(bargain.id)).toBe(fixtures.bargainId);
  });

  test('refund APIs reject nonexistent and unpaid orders without state changes', async () => {
    const fixtures = readRuntimeFixtures();
    const reasons = await expectBusinessOk(fixtures.frontApi, '/api/front/order/refund/reason', {
      token: fixtures.h5Token,
    });
    expect(reasons).toBeInstanceOf(Array);

    const nonexistent = await apiRequest(fixtures.frontApi, '/api/front/order/refund', {
      method: 'POST',
      token: fixtures.h5Token,
      body: {
        id: 0,
        uni: `missing-${Date.now()}`,
        text: 'E2E invalid order',
        refund_reason_wap_img: '',
        refund_reason_wap_explain: '',
      },
      allowHttpError: true,
    });
    expectBusinessFailure(nonexistent, /支付订单不存在/);

    const unpaid = await createBuyNowOrder(fixtures, {
      mark: `${fixtures.runId}-refund-boundary-${Date.now()}`,
    });
    const unpaidRefund = await apiRequest(fixtures.frontApi, '/api/front/order/refund', {
      method: 'POST',
      token: fixtures.h5Token,
      body: {
        id: 0,
        uni: unpaid.orderNo,
        text: 'E2E unpaid order',
        refund_reason_wap_img: '',
        refund_reason_wap_explain: '',
      },
      allowHttpError: true,
    });
    expectBusinessFailure(unpaidRefund, /支付订单不存在/);
  });
});
