import { test, expect } from '@playwright/test';

test.use({ storageState: { cookies: [], origins: [] } });

test('@core login agreement can be found, toggled by keyboard, and stays in sync with its visible checkbox', async ({ page }) => {
  await page.goto('/pages/users/login/index');
  const checkbox = page.getByRole('checkbox', { name: '我已阅读并同意用户协议和隐私政策' });
  await expect(checkbox).toBeVisible();
  await expect(checkbox).not.toBeChecked();
  await checkbox.focus();
  await page.keyboard.press('Space');
  await expect(checkbox).toBeChecked();
  await expect(page.locator('.protocol .uni-checkbox-input svg')).toHaveCount(1);
  await page.keyboard.press('Enter');
  await expect(checkbox).not.toBeChecked();
  await expect(page.locator('.protocol .uni-checkbox-input svg')).toHaveCount(0);
});
