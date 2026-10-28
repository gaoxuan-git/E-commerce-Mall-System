import { test, expect } from '@playwright/test';
import { installDiagnostics, assertPageHealthy } from '../helpers/diagnostics.mjs';
import { readRuntimeFixtures } from '../helpers/fixtures.mjs';

test.describe.serial('@smoke admin menu coverage', () => {
  test('menu API exposes concrete component pages', async () => {
    const routes = readRuntimeFixtures().adminRoutes || [];
    expect(routes.length, 'admin menu route count').toBeGreaterThan(20);
    expect(new Set(routes.map((route) => route.path)).size, 'admin menu paths must be unique').toBe(routes.length);
  });

  test('every reachable menu page renders without browser or network errors', async ({ page }, testInfo) => {
    test.setTimeout(10 * 60_000);
    const routes = readRuntimeFixtures().adminRoutes || [];
    const failures = [];

    for (const route of routes) {
      await test.step(`${route.name}: ${route.path}`, async () => {
        const currentPage = await page.context().newPage();
        const diagnostics = installDiagnostics(currentPage);
        try {
          await currentPage.goto(route.path, { waitUntil: 'domcontentloaded' });
          await expect(currentPage).not.toHaveURL(/\/login(?:\?|$)/);
          await assertPageHealthy(currentPage, diagnostics, {
            settleMs: 1_200,
            allowRequestFailures: [
              /GET http:\/\/127\.0\.0\.1:9527\/(?:node_modules|src)\/.*net::ERR_ABORTED/,
            ],
          });
          await expect(
            currentPage.locator('.app-main, main, #app').first(),
            `${route.path} main content`,
          ).toBeVisible();
        } catch (error) {
          failures.push(`${route.path}: ${error.message}`);
          if (!currentPage.isClosed()) {
            await currentPage.screenshot({
              path: testInfo.outputPath(`failed-${route.path.replaceAll('/', '_') || 'root'}.png`),
              fullPage: true,
            });
          }
        }
        if (['/dashboard', '/store/index', '/order/index', '/user/index'].includes(route.path)) {
          await currentPage.screenshot({
            path: testInfo.outputPath(`${route.path.replaceAll('/', '_') || 'root'}.png`),
            fullPage: true,
          });
        }
        await currentPage.close();
      });
    }
    expect(failures, failures.join('\n')).toEqual([]);
  });
});
