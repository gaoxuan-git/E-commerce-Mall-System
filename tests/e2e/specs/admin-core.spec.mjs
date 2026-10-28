import { test, expect } from '@playwright/test';
import { apiRequest, expectBusinessOk } from '../helpers/api.mjs';
import { createBuyNowOrder, sqlQuote } from '../helpers/core.mjs';
import { queryScalar } from '../helpers/database.mjs';
import { readRuntimeFixtures } from '../helpers/fixtures.mjs';

test.describe.serial('@core admin business APIs', () => {
  test('admin product, user, and order views agree with front-created data', async () => {
    const fixtures = readRuntimeFixtures();
    const products = await expectBusinessOk(fixtures.adminApi, '/api/admin/store/product/list', {
      token: fixtures.adminToken,
      query: { type: 1, keywords: fixtures.productName, page: 1, limit: 10 },
    });
    expect(products.list.some((item) => Number(item.id) === fixtures.productId)).toBeTruthy();

    const users = await expectBusinessOk(fixtures.adminApi, '/api/admin/user/list', {
      token: fixtures.adminToken,
      query: {
        searchType: 'uid',
        content: fixtures.primaryUserId,
        accessType: 0,
        page: 1,
        limit: 10,
      },
    });
    expect(users.list.some((item) => Number(item.uid) === fixtures.primaryUserId)).toBeTruthy();

    const order = await createBuyNowOrder(fixtures, {
      mark: `${fixtures.runId}-admin-order-${Date.now()}`,
    });
    const list = await expectBusinessOk(fixtures.adminApi, '/api/admin/store/order/list', {
      token: fixtures.adminToken,
      query: { type: 2, status: 'all', orderNo: order.orderNo, page: 1, limit: 10 },
    });
    expect(list.list).toHaveLength(1);
    expect(list.list[0].orderId).toBe(order.orderNo);
    expect(Number(list.list[0].uid)).toBe(fixtures.primaryUserId);

    const remark = `${fixtures.runId}-verified`;
    await expectBusinessOk(fixtures.adminApi, '/api/admin/store/order/mark', {
      method: 'POST',
      token: fixtures.adminToken,
      query: { orderNo: order.orderNo, mark: remark },
    });
    const detail = await expectBusinessOk(fixtures.adminApi, '/api/admin/store/order/info', {
      token: fixtures.adminToken,
      query: { orderNo: order.orderNo },
    });
    expect(detail.orderId).toBe(order.orderNo);
    expect(detail.remark).toBe(remark);
  });

  test('article create, read, update, search, and delete form an isolated CRUD loop', async () => {
    const fixtures = readRuntimeFixtures();
    const title = `${fixtures.runId} article ${Date.now()}`;
    const updatedTitle = `${title} updated`;
    const article = {
      cid: '601',
      title,
      author: 'E2E',
      imageInput: 'crmebimage/public/open-data/abo-curated-v2/8101-main.jpg',
      synopsis: 'E2E isolated article',
      shareTitle: title,
      shareSynopsis: 'E2E isolated article',
      isHot: false,
      isBanner: false,
      content: '<p>E2E isolated article body</p>',
    };
    let articleId;

    try {
      await expectBusinessOk(fixtures.adminApi, '/api/admin/article/save', {
        method: 'POST',
        token: fixtures.adminToken,
        body: article,
      });
      articleId = Number(
        queryScalar(`SELECT id FROM eb_article WHERE title = ${sqlQuote(title)} ORDER BY id DESC LIMIT 1`),
      );
      expect(articleId).toBeGreaterThan(0);

      const detail = await expectBusinessOk(fixtures.adminApi, '/api/admin/article/info', {
        token: fixtures.adminToken,
        query: { id: articleId },
      });
      expect(detail.title).toBe(title);

      await expectBusinessOk(fixtures.adminApi, '/api/admin/article/update', {
        method: 'POST',
        token: fixtures.adminToken,
        query: { id: articleId },
        body: { ...article, title: updatedTitle, shareTitle: updatedTitle },
      });
      const list = await expectBusinessOk(fixtures.adminApi, '/api/admin/article/list', {
        token: fixtures.adminToken,
        query: { keywords: updatedTitle, page: 1, limit: 10 },
      });
      expect(list.list.some((item) => Number(item.id) === articleId && item.title === updatedTitle)).toBeTruthy();

      await expectBusinessOk(fixtures.adminApi, '/api/admin/article/delete', {
        token: fixtures.adminToken,
        query: { id: articleId },
      });
      expect(Number(queryScalar(`SELECT COUNT(*) FROM eb_article WHERE id = ${articleId}`))).toBe(0);
      articleId = null;
    } finally {
      if (articleId) {
        await apiRequest(fixtures.adminApi, '/api/admin/article/delete', {
          token: fixtures.adminToken,
          query: { id: articleId },
          allowHttpError: true,
        });
      }
    }
  });
});
