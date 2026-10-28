import { test, expect } from '@playwright/test';
import { spawnSync } from 'node:child_process';
import { apiRequest } from '../helpers/api.mjs';
import { createBuyNowOrder, expectBusinessFailure, isBusinessOk, sqlQuote } from '../helpers/core.mjs';
import { queryRows, queryScalar } from '../helpers/database.mjs';
import { readRuntimeFixtures } from '../helpers/fixtures.mjs';

function queuedCancellationCount(orderId) {
  const result = spawnSync('redis-cli', [
    '-n', process.env.REDIS_DB || '10', '--raw',
    'LRANGE', 'alterOrderCancelByUser', '0', '-1',
  ], { encoding: 'utf8' });
  expect(result.status, result.stderr).toBe(0);
  return result.stdout.trim().split('\n').filter((value) => value === String(orderId)).length;
}

test.describe('@core cancellation state boundaries', () => {
  test('concurrent unpaid cancellation persists once and queues one inventory return', async () => {
    const fixtures = readRuntimeFixtures();
    const order = await createBuyNowOrder(fixtures, {
      mark: `${fixtures.runId}-cancel-${Date.now()}`,
    });
    const orderId = Number(queryScalar(
      `SELECT id FROM eb_store_order WHERE order_id = ${sqlQuote(order.orderNo)}`,
    ));
    expect(queuedCancellationCount(orderId)).toBe(0);
    const cancel = () => apiRequest(fixtures.frontApi, '/api/front/order/cancel', {
      method: 'POST', token: fixtures.h5Token, query: { id: orderId },
    });
    const results = await Promise.all([cancel(), cancel()]);
    expect(results.filter((result) => isBusinessOk(result.payload))).toHaveLength(1);
    expect(queryRows(
      `SELECT paid,is_del,is_system_del FROM eb_store_order WHERE id = ${orderId}`,
    )[0]).toEqual(['0', '1', '1']);
    expect(queuedCancellationCount(orderId)).toBe(1);
    expectBusinessFailure(await cancel(), /取消|删除/);
    expect(queuedCancellationCount(orderId)).toBe(1);
  });

  test('paid cancellation, unpaid deletion, and cross-user cancellation leave orders intact', async () => {
    const fixtures = readRuntimeFixtures();
    const paidId = Number(queryScalar(
      `SELECT id FROM eb_store_order WHERE uid = ${fixtures.primaryUserId}
       AND paid = 1 AND is_del = 0 AND is_system_del = 0 ORDER BY id DESC LIMIT 1`,
    ));
    expect(paidId).toBeGreaterThan(0);
    const queueBefore = queuedCancellationCount(paidId);
    const paidCancel = await apiRequest(fixtures.frontApi, '/api/front/order/cancel', {
      method: 'POST', token: fixtures.h5Token, query: { id: paidId },
    });
    expectBusinessFailure(paidCancel, /已支付订单无法取消/);
    expect(queryRows(
      `SELECT paid,is_del,is_system_del FROM eb_store_order WHERE id = ${paidId}`,
    )[0]).toEqual(['1', '0', '0']);
    expect(queuedCancellationCount(paidId)).toBe(queueBefore);

    const unpaidId = Number(queryScalar(
      `SELECT id FROM eb_store_order WHERE uid = ${fixtures.primaryUserId}
       AND paid = 0 AND is_del = 0 AND is_system_del = 0 ORDER BY id DESC LIMIT 1`,
    ));
    expect(unpaidId).toBeGreaterThan(0);
    const unpaidDelete = await apiRequest(fixtures.frontApi, '/api/front/order/del', {
      method: 'POST', token: fixtures.h5Token, query: { id: unpaidId },
    });
    expectBusinessFailure(unpaidDelete, /未支付订单无法删除/);
    const crossUserCancel = await apiRequest(fixtures.frontApi, '/api/front/order/cancel', {
      method: 'POST', token: fixtures.secondH5Token, query: { id: unpaidId },
    });
    expectBusinessFailure(crossUserCancel, /没有找到相关订单信息/);
    expect(queryRows(
      `SELECT paid,is_del,is_system_del FROM eb_store_order WHERE id = ${unpaidId}`,
    )[0]).toEqual(['0', '0', '0']);
  });
});
