import { test, expect } from '@playwright/test';
import { readRuntimeFixtures } from '../helpers/fixtures.mjs';

test('@core refund reason picker opens without event errors and enforces the advertised remark limit', async ({ page }) => {
  const f = readRuntimeFixtures();
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  await page.route('**/api/front/order/apply/refund/refund-form-test', route => route.fulfill({
    json: { code: 200, data: {
      totalNum: 1, payPrice: '10.00',
      orderInfoList: [{ image: f.productImage, storeName: '退款表单测试商品', price: '10.00', cartNum: 1 }],
    } },
  }));
  await page.route('**/api/front/order/refund/reason', route => route.fulfill({
    json: { code: 200, data: ['收货地址填错了', '与描述不符'] },
  }));
  let submitted;
  await page.route(/\/api\/front\/order\/refund$/, route => {
    submitted = route.request().postDataJSON();
    return route.fulfill({ json: { code: 400, message: '表单测试拒绝，无退款写入' } });
  });
  await page.goto('/pages/goods/goods_return/index?orderId=refund-form-test');
  await page.locator('.reason').click();
  await expect(page.locator('uni-picker-view')).toBeVisible();
  await page.getByText(/^(取消|Cancel)$/).click();
  await expect(page.locator('uni-picker-view')).toHaveCount(0);
  await page.locator('.reason').click();
  await page.getByText(/^(完成|Done)$/).click();
  await expect(page.locator('.reason')).toHaveText('收货地址填错了');
  const remark = page.locator('textarea');
  await expect(remark).toHaveAttribute('maxlength', '100');
  await remark.fill('测'.repeat(110));
  await expect(remark).toHaveValue('测'.repeat(100));
  await page.getByText('申请退款', { exact: true }).click();
  await expect.poll(() => submitted).toEqual({
    text: '收货地址填错了', refund_reason_wap_explain: '测'.repeat(100),
    refund_reason_wap_img: '', uni: 'refund-form-test',
  });
  await expect(page.getByText('表单测试拒绝，无退款写入', { exact: true })).toBeVisible();
  expect(errors).toEqual([]);
});
