import { test, expect } from '@playwright/test';
import { apiRequest, expectBusinessOk } from '../helpers/api.mjs';
import { expectBusinessFailure } from '../helpers/core.mjs';
import { queryRows, queryScalar } from '../helpers/database.mjs';
import { readRuntimeFixtures } from '../helpers/fixtures.mjs';

for (const message of ['您的帮砍次数已达上限', '您已经砍过该商品']) {
  test(`@core rejected bargain help preserves displayed history and price: ${message}`, async ({ page }) => {
    const f = readRuntimeFixtures();
    const rows = queryRows(`SELECT u.id,u.bargain_id,u.uid FROM eb_store_bargain_user u
      JOIN eb_store_bargain b ON b.id=u.bargain_id
      WHERE u.uid=${f.primaryUserId} AND u.is_del=0 AND b.stop_time>${Date.now()}
      AND EXISTS (SELECT 1 FROM eb_store_bargain_user_help h WHERE h.bargain_user_id=u.id)
      ORDER BY u.id LIMIT 1`);
    expect(rows).toHaveLength(1);
    const [userId, bargainId, starterUid] = rows[0].map(Number);
    const info = await expectBusinessOk(f.frontApi, '/api/front/bargain/user', {
      token: f.secondH5Token, query: { bargainId, bargainUserId: userId },
    });
    await page.addInitScript(({ token, uid }) => {
      localStorage.setItem('LOGIN_STATUS_TOKEN', token);
      localStorage.setItem('UID', String(uid));
      localStorage.setItem('EXPIRES_TIME', String(Math.floor(Date.now() / 1000) + 3600));
    }, { token: f.secondH5Token, uid: f.secondUserId });
    // Expose the help action independently of whether this reused test user has helped before.
    await page.route(/\/api\/front\/bargain\/user(?:\?|$)/, route =>
      route.fulfill({ json: { code: 200, data: { ...info, bargainStatus: 5 } } }));
    let attempts = 0;
    await page.route(/\/api\/front\/bargain\/help(?:\?|$)/, route => {
      attempts++;
      return route.fulfill({ json: { code: 400, message } });
    });
    await page.goto(`/pages/activity/goods_bargain_details/index?id=${bargainId}&startBargainUid=${starterUid}&storeBargainId=${userId}`);
    const history = page.locator('.bargainGang .list');
    await expect(history).toBeVisible();
    const previousHistory = await history.innerText();
    const previousPrice = await page.locator('.bargainGang .money').allTextContents();
    const progress = page.locator('.content > .money');
    const previousProgress = await progress.innerText();
    await page.getByText('帮好友砍一刀', { exact: true }).click();
    await expect.poll(() => attempts).toBe(1);
    await expect(page.getByText(message, { exact: true })).toBeVisible();
    await expect.poll(() => history.innerText()).toBe(previousHistory);
    await expect.poll(() => progress.innerText()).toBe(previousProgress);
    expect(await page.locator('.bargainGang .money').allTextContents()).toEqual(previousPrice);
    await expect(page.getByText('暂无助力记录', { exact: true })).toHaveCount(0);
  });
}

test('@core real bargain self-help, concurrent friend help, duplicate and activity mismatch preserve prices and records', async () => {
  const f = readRuntimeFixtures();
  expect(new URL(f.frontApi).hostname).toBe('127.0.0.1');
  // Each run uses an unstarted local demo activity; never reset participation history.
  const candidates = queryRows(`SELECT b.id FROM eb_store_bargain b
    WHERE b.id >= 8100 AND b.status=1 AND b.is_del=0 AND b.stock>0 AND b.quota>0
    AND b.start_time < ${Date.now()} AND b.stop_time > ${Date.now()}
    AND NOT EXISTS (SELECT 1 FROM eb_store_bargain_user u
      WHERE u.bargain_id=b.id AND u.uid IN (${f.primaryUserId},${f.secondUserId}))
    AND NOT EXISTS (SELECT 1 FROM eb_store_bargain_user_help h
      WHERE h.bargain_id=b.id AND h.uid=${f.secondUserId})
    ORDER BY b.id LIMIT 1`);
  expect(candidates.length, 'An unused demo activity is required').toBe(1);
  const bargainId = Number(candidates[0][0]);
  const started = await expectBusinessOk(f.frontApi, '/api/front/bargain/start', {
    method: 'POST', token: f.h5Token, body: { bargainId },
  });
  const bargainUserId = Number(started.storeBargainUserId);
  const body = { bargainId, bargainUserId, bargainUserUid: f.primaryUserId };
  const snapshot = () => ({
    activity: queryRows(`SELECT price,status,is_del FROM eb_store_bargain_user WHERE id=${bargainUserId}`),
    helps: queryRows(`SELECT uid,price FROM eb_store_bargain_user_help WHERE bargain_user_id=${bargainUserId} ORDER BY id`),
    share: queryScalar(`SELECT share FROM eb_store_bargain WHERE id=${bargainId}`),
  });
  const help = (token, data = body) => apiRequest(f.frontApi, '/api/front/bargain/help', {
    method: 'POST', token, body: data,
  });
  const beforeSelf = snapshot();
  // Client-supplied starter UID must not affect the stored share count.
  const self = await help(f.h5Token, { ...body, bargainUserUid: f.secondUserId });
  expect(self.payload?.code).toBe(200);
  expect(Number(self.payload.data.bargainPrice)).toBeGreaterThan(0);
  expect(snapshot().share).toBe(beforeSelf.share);
  const afterSelf = snapshot();
  expectBusinessFailure(await help(f.h5Token), /已经砍过/);
  expect(snapshot()).toEqual(afterSelf);

  const parallel = await Promise.all([help(f.secondH5Token), help(f.secondH5Token)]);
  expect(parallel.filter(result => result.payload?.code === 200)).toHaveLength(1);
  expect(parallel.filter(result => result.payload?.code !== 200)).toHaveLength(1);
  const afterFriend = snapshot();
  expect(afterFriend.helps).toHaveLength(2);
  expect(Number(afterFriend.share)).toBe(Number(afterSelf.share) + 1);
  const total = afterFriend.helps.reduce((sum, row) => sum + Math.round(Number(row[1]) * 100), 0);
  expect(Math.round(Number(afterFriend.activity[0][0]) * 100)).toBe(total);
  expectBusinessFailure(await help(f.secondH5Token), /已经砍过/);
  expect(snapshot()).toEqual(afterFriend);

  const otherId = Number(queryScalar(`SELECT id FROM eb_store_bargain WHERE id >= 8100 AND id != ${bargainId} AND status=1 AND is_del=0 LIMIT 1`));
  expectBusinessFailure(await help(f.secondH5Token, { ...body, bargainId: otherId }), /不匹配/);
  expectBusinessFailure(await apiRequest(f.frontApi, '/api/front/bargain/user', {
    token: f.secondH5Token, query: { bargainId: otherId, bargainUserId },
  }), /不匹配/);
  expect(snapshot()).toEqual(afterFriend);
  const info = await expectBusinessOk(f.frontApi, '/api/front/bargain/user', {
    token: f.secondH5Token, query: { bargainId, bargainUserId },
  });
  expect(Number(info.alreadyPrice)).toBe(Number(afterFriend.activity[0][0]));
  expect(info.userHelpList).toHaveLength(2);
});
