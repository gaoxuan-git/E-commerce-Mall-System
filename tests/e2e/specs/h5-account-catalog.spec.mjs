import { test, expect } from '@playwright/test';
import { apiRequest, expectBusinessOk } from '../helpers/api.mjs';
import { readRuntimeFixtures } from '../helpers/fixtures.mjs';

test.describe.serial('@core account and catalog contracts', () => {
  test('loading the profile preserves the user ID established by login', async ({ page }) => {
    const fixtures = readRuntimeFixtures();
    const profileResponse = page.waitForResponse(response =>
      new URL(response.url()).pathname === '/api/front/user' && response.ok());
    await page.goto('/pages/user/index');
    await profileResponse;
    await expect(page.getByText('领券中心', { exact: true })).toBeVisible();
    await expect.poll(() => page.evaluate(() => String(uni.getStorageSync('UID')))).toBe(String(fixtures.primaryUserId));
    await page.goto('/pages/activity/goods_bargain/index');
    await expect.poll(() => page.evaluate(() => String(uni.getStorageSync('UID')))).toBe(String(fixtures.primaryUserId));
  });

  for (const cachedProfile of [false, true]) {
    test(`expired login redirects and clears account state without unhandled errors (cached profile: ${cachedProfile})`, async ({ page }) => {
      const errors = [];
      page.on('pageerror', error => errors.push(error.message));
      await page.addInitScript(({ cachedProfile }) => {
        localStorage.setItem('LOGIN_STATUS_TOKEN', 'expired-e2e-token');
        localStorage.setItem('EXPIRES_TIME', String(Math.floor(Date.now() / 1000) + 3600));
        localStorage.setItem('UID', '1');
        if (cachedProfile) localStorage.setItem('USER_INFO', JSON.stringify({ uid: 1, nickname: '过期用户' }));
        else localStorage.removeItem('USER_INFO');
      }, { cachedProfile });
      await page.goto('/pages/user/index');
      await expect(page).toHaveURL(/\/pages\/users\/login\/index/);
      await expect.poll(() => page.evaluate(() => ({
        token: localStorage.getItem('LOGIN_STATUS_TOKEN'),
        expires: localStorage.getItem('EXPIRES_TIME'),
        uid: localStorage.getItem('UID'),
        profile: localStorage.getItem('USER_INFO'),
      }))).toEqual({ token: null, expires: null, uid: null, profile: null });
      await expect(page.locator('input').first()).toBeVisible();
      await page.waitForTimeout(1000);
      expect(errors).toEqual([]);
    });
  }

  test('user-center coupon entry opens the coupon center', async ({ page }) => {
    await page.goto('/pages/user/index');
    await page.getByText('领券中心', { exact: true }).click();
    await expect(page).toHaveURL(/\/pages\/users\/user_get_coupon\/index/);
    await expect(page.getByText('通用券', { exact: true })).toBeVisible();
    await expect(page.getByText('商品券', { exact: true })).toBeVisible();
  });

  test('public catalog, search, SKU, images, and comments are consistent', async () => {
    const fixtures = readRuntimeFixtures();
    const categories = await expectBusinessOk(fixtures.frontApi, '/api/front/category');
    const flatten = (items) => items.flatMap((item) => [item, ...flatten(item.child || [])]);
    expect(flatten(categories).some((item) => Number(item.id) === fixtures.categoryId)).toBeTruthy();

    const products = await expectBusinessOk(fixtures.frontApi, '/api/front/products', {
      query: { keyword: fixtures.productName, page: 1, limit: 10 },
    });
    const product = products.list.find((item) => Number(item.id) === fixtures.productId);
    expect(product).toBeTruthy();
    expect(product.storeName).toBe(fixtures.productName);
    expect(new URL(product.image).hostname).toBe('127.0.0.1');

    const detail = await expectBusinessOk(
      fixtures.frontApi,
      `/api/front/product/detail/${fixtures.productId}`,
      { token: fixtures.h5Token },
    );
    expect(detail.productInfo.id).toBe(fixtures.productId);
    expect(detail.productInfo.storeName).toBe(product.storeName);
    expect(detail.productValue['图示款'].id).toBe(fixtures.productAttrValueId);
    expect(detail.productValue['图示款'].unique).toBe(fixtures.productAttrUnique);
    expect(detail.productValue['图示款'].image).toBe(new URL(fixtures.productImage, fixtures.adminApi).toString());
    expect(Number(detail.productValue['图示款'].price)).toBe(fixtures.productPrice);

    const replies = await expectBusinessOk(fixtures.frontApi, `/api/front/reply/list/${fixtures.productId}`, {
      query: { type: 0, page: 1, limit: 10 },
    });
    expect(replies.list).toBeInstanceOf(Array);
    const replyCounts = await expectBusinessOk(
      fixtures.frontApi,
      `/api/front/reply/config/${fixtures.productId}`,
    );
    expect(replyCounts).toEqual(expect.any(Object));
  });

  test('authenticated profile and collection state round-trip correctly', async () => {
    const fixtures = readRuntimeFixtures();
    const profile = await expectBusinessOk(fixtures.frontApi, '/api/front/user', {
      token: fixtures.h5Token,
    });
    expect(profile.nickname).toBeTruthy();
    expect(Number(profile.nowMoney)).toBeGreaterThanOrEqual(0);

    const getDetail = () =>
      expectBusinessOk(fixtures.frontApi, `/api/front/product/detail/${fixtures.secondProductId}`, {
        token: fixtures.h5Token,
      });
    const initial = await getDetail();

    try {
      if (initial.userCollect) {
        await expectBusinessOk(fixtures.frontApi, `/api/front/collect/cancel/${fixtures.secondProductId}`, {
          method: 'POST',
          token: fixtures.h5Token,
        });
      }
      await expectBusinessOk(fixtures.frontApi, '/api/front/collect/add', {
        method: 'POST',
        token: fixtures.h5Token,
        body: { id: fixtures.secondProductId, category: 'product' },
      });
      expect((await getDetail()).userCollect).toBeTruthy();

      await expectBusinessOk(fixtures.frontApi, `/api/front/collect/cancel/${fixtures.secondProductId}`, {
        method: 'POST',
        token: fixtures.h5Token,
      });
      expect((await getDetail()).userCollect).toBeFalsy();
    } finally {
      const current = await apiRequest(
        fixtures.frontApi,
        `/api/front/product/detail/${fixtures.secondProductId}`,
        { token: fixtures.h5Token, allowHttpError: true },
      );
      if (initial.userCollect && !current.payload?.data?.userCollect) {
        await apiRequest(fixtures.frontApi, '/api/front/collect/add', {
          method: 'POST',
          token: fixtures.h5Token,
          body: { id: fixtures.secondProductId, category: 'product' },
          allowHttpError: true,
        });
      }
    }
  });
});
