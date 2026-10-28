import { test, expect } from '@playwright/test';
import { assertPageHealthy, installDiagnostics } from '../helpers/diagnostics.mjs';

test.describe('@core splash advertisement flow', () => {
  test.use({ storageState: { cookies: [], origins: [] } });

  test('fresh visitor can skip the countdown and revisiting within the interval opens home', async ({ page }) => {
    const diagnostics = installDiagnostics(page);
    await page.goto('/pages/guide/index');
    const skip = page.locator('.jump-over');
    await expect(skip).toBeVisible();
    await expect(page.locator('.swiper-item-img img').first()).toBeVisible();
    const initial = Number((await skip.innerText()).replace(/\D/g, ''));
    expect(initial).toBeGreaterThan(0);
    await expect.poll(async () => Number((await skip.innerText()).replace(/\D/g, ''))).toBeLessThan(initial);
    await skip.click();
    await expect(page).toHaveURL(/\/pages\/index\/index/);
    await assertPageHealthy(page, diagnostics);
    // A second tab shares the interval state without cancelling the first tab's
    // delayed DIY component requests.
    const revisit = await page.context().newPage();
    const revisitDiagnostics = installDiagnostics(revisit);
    await revisit.goto('/pages/guide/index');
    await expect(revisit).toHaveURL(/\/pages\/index\/index/);
    await assertPageHealthy(revisit, revisitDiagnostics);
  });

  test('fresh visitor reaches home automatically when the configured countdown finishes', async ({ page }) => {
    const diagnostics = installDiagnostics(page);
    await page.goto('/pages/guide/index');
    await expect(page.locator('.jump-over')).toBeVisible();
    await expect(page).toHaveURL(/\/pages\/index\/index/, { timeout: 25_000 });
    await assertPageHealthy(page, diagnostics);
  });
});
