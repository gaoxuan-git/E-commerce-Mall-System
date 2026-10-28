import { test, expect } from '@playwright/test';
import { h5Routes } from '../fixtures/routes.mjs';
import { installDiagnostics, assertPageHealthy } from '../helpers/diagnostics.mjs';
import { readRuntimeFixtures, resolveRoute } from '../helpers/fixtures.mjs';

test.describe('@smoke H5 route coverage', () => {
  test('route manifest matches the 65 executable H5 entries', async () => {
    expect(h5Routes).toHaveLength(65);
    expect(new Set(h5Routes.map((route) => route.path.split('?')[0])).size).toBe(65);
  });

  test('app update page uses neutral visible branding', async ({ page }, testInfo) => {
    const diagnostics = installDiagnostics(page);
    await page.goto(
      new URL('/pages/users/app_update/app_update', testInfo.project.use.baseURL).toString(),
      { waitUntil: 'domcontentloaded' },
    );

    await expect(page.getByText('商城系统', { exact: true })).toBeVisible();
    await expect(page.getByText('crmeb', { exact: true })).toHaveCount(0);
    await expect(page.locator('[src*="crmeb_java"]')).toHaveCount(0);
    await page.getByText('检查新版本', { exact: true }).click();
    await expect(page.getByText('请在 App 内检查更新', { exact: true })).toBeVisible();
    await assertPageHealthy(page, diagnostics);
  });

  for (const route of h5Routes) {
    test(`${route.kind}: ${route.name}`, async ({ page, browser }, testInfo) => {
      const fixtures = readRuntimeFixtures();
      const targetPath = resolveRoute(route.path, fixtures);
      let currentPage = page;
      let guestContext;
      if (!route.auth) {
        guestContext = await browser.newContext({
          viewport: testInfo.project.use.viewport,
          storageState: { cookies: [], origins: [] },
        });
        currentPage = await guestContext.newPage();
      }

      const diagnostics = installDiagnostics(currentPage);
      await currentPage.goto(new URL(targetPath, testInfo.project.use.baseURL).toString(), {
        waitUntil: 'domcontentloaded',
      });
      await assertPageHealthy(currentPage, diagnostics);

      if (route.auth) {
        expect(currentPage.url(), `${route.name} unexpectedly redirected to login`).not.toContain(
          '/pages/users/login/index',
        );
      }

      if (['home', 'categories', 'product-detail', 'cart', 'orders', 'user-center', 'login'].includes(route.name)) {
        await currentPage.screenshot({
          path: testInfo.outputPath(`${route.name}.png`),
          fullPage: true,
        });
      }
      await guestContext?.close();
    });
  }
});
