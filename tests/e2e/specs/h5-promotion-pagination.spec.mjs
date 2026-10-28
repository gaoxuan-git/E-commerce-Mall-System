import { test, expect } from '@playwright/test';
import { readRuntimeFixtures } from '../helpers/fixtures.mjs';

for (const scenario of [
  { page: 'commission_rank', endpoint: 'brokerage_rank', limit: 20, selector: '.CommissionRank .list > .item', tab: '月排行' },
  { page: 'promoter_rank', endpoint: 'rank', limit: 10, selector: '.PromoterRank .list > .item', tab: '月榜' },
]) {
  test(`@core ${scenario.page} loads the second page once and resets pagination when changing period`, async ({ page }) => {
    await page.setViewportSize({ width: 390, height: 400 });
    const fixtures = readRuntimeFixtures();
    const calls = [];
    await page.route(new RegExp(`/api/front/${scenario.endpoint}(?:\\?|$)`), async (route) => {
      const url = new URL(route.request().url());
      const number = Number(url.searchParams.get('page'));
      const period = url.searchParams.get('type');
      calls.push({ number, period });
      const length = number === 1 ? scenario.limit : 2;
      const rows = Array.from({ length }, (_, index) => ({
        uid: (number - 1) * scenario.limit + index + 1,
        nickname: `${period}-rank-${(number - 1) * scenario.limit + index + 1}`,
        avatar: fixtures.productImage,
        spreadCount: 100 - index,
        brokeragePrice: '10.00',
      }));
      await route.fulfill({ json: { code: 200, data: rows } });
    });
    await page.goto(`/pages/promoter/${scenario.page}/index`);
    await expect(page.getByText('week-rank-1', { exact: true })).toBeVisible();
    await page.evaluate(() => window.scrollTo({ top: document.documentElement.scrollHeight, behavior: 'instant' }));
    await expect.poll(() => calls.filter((c) => c.period === 'week').map((c) => c.number)).toEqual([1, 2]);
    await expect(page.locator(scenario.selector)).toHaveCount(
      scenario.limit + 2 - (scenario.page === 'promoter_rank' ? 3 : 0),
    );
    // uni-h5 在触底回调后锁定 350ms；下一次触底需等待框架解除锁定。
    await page.waitForTimeout(400);
    await page.getByText(scenario.tab, { exact: true }).scrollIntoViewIfNeeded();
    await page.evaluate(() => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))));
    await page.getByText(scenario.tab, { exact: true }).click();
    await expect(page.getByText('month-rank-1', { exact: true })).toBeVisible();
    await expect(page.getByText('week-rank-1', { exact: true })).toHaveCount(0);
    await page.evaluate(() => window.scrollTo({ top: document.documentElement.scrollHeight, behavior: 'instant' }));
    await expect.poll(() => calls.filter((c) => c.period === 'month').map((c) => c.number)).toEqual([1, 2]);
  });

  test(`@core ${scenario.page} accepts null results and ignores a stale response after changing period`, async ({ page }) => {
    const fixtures = readRuntimeFixtures();
    let releaseWeek;
    const weekGate = new Promise((resolve) => { releaseWeek = resolve; });
    let weekStarted = false;
    await page.route(new RegExp(`/api/front/${scenario.endpoint}(?:\\?|$)`), async (route) => {
      const period = new URL(route.request().url()).searchParams.get('type');
      if (period === 'week') {
        weekStarted = true;
        await weekGate;
        await route.fulfill({ json: { code: 200, data: [{
          uid: 1, nickname: 'stale-week-result', avatar: fixtures.productImage,
          spreadCount: 5, brokeragePrice: '10.00',
        }] } });
      } else {
        await route.fulfill({ json: { code: 200, data: null } });
      }
    });
    await page.goto(`/pages/promoter/${scenario.page}/index`);
    await expect.poll(() => weekStarted).toBe(true);
    await page.getByText(scenario.tab, { exact: true }).click();
    await expect(page.getByText('暂无排行～', { exact: true })).toBeVisible();
    const responsePromise = page.waitForResponse((response) => {
      const url = new URL(response.url());
      return url.pathname === `/api/front/${scenario.endpoint}` && url.searchParams.get('type') === 'week';
    });
    releaseWeek();
    const response = await responsePromise;
    await response.finished();
    await page.evaluate(() => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))));
    await expect(page.getByText('stale-week-result', { exact: true })).toHaveCount(0);
    await expect(page.getByText('暂无排行～', { exact: true })).toBeVisible();
  });
}
