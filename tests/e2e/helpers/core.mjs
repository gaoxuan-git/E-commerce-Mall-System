import { expect } from '@playwright/test';
import { apiRequest } from './api.mjs';
import { queryScalar } from './database.mjs';

export function isBusinessOk(payload) {
  return [0, 200].includes(payload?.code);
}

export function expectBusinessFailure(result, messagePattern) {
  expect(result.response.ok, 'business failures should still use a valid HTTP response').toBeTruthy();
  expect(isBusinessOk(result.payload), `unexpected success: ${JSON.stringify(result.payload)}`).toBeFalsy();
  if (messagePattern) {
    expect(String(result.payload?.message || '')).toMatch(messagePattern);
  }
}

export function sqlQuote(value) {
  return `'${String(value).replaceAll('\\', '\\\\').replaceAll("'", "''")}'`;
}

export async function waitForScalar(sql, predicate, options = {}) {
  const timeout = options.timeout || 10_000;
  const interval = options.interval || 200;
  const startedAt = Date.now();
  let value;
  do {
    value = queryScalar(sql);
    if (predicate(value)) return value;
    await new Promise((resolve) => setTimeout(resolve, interval));
  } while (Date.now() - startedAt < timeout);
  throw new Error(`Database condition was not met in ${timeout}ms. Last value: ${value}`);
}

export async function createBuyNowOrder(fixtures, options = {}) {
  const token = options.token || fixtures.h5Token;
  const productId = options.productId || fixtures.productId;
  const attrValueId = options.attrValueId || fixtures.productAttrValueId;
  const addressId = options.addressId || fixtures.addressId;
  const productNum = options.productNum || 1;
  const mark = options.mark || `${fixtures.runId}-order-${Date.now()}`;

  const pre = await apiRequest(fixtures.frontApi, '/api/front/order/pre/order', {
    method: 'POST',
    token,
    body: {
      preOrderType: 'buyNow',
      orderDetails: [{ productId, attrValueId, productNum }],
    },
  });
  expect(pre.response.ok).toBeTruthy();
  expect(isBusinessOk(pre.payload), JSON.stringify(pre.payload)).toBeTruthy();
  const preOrderNo = pre.payload.data?.preOrderNo;
  expect(preOrderNo).toBeTruthy();

  const loaded = await apiRequest(fixtures.frontApi, `/api/front/order/load/pre/${preOrderNo}`, { token });
  expect(loaded.response.ok).toBeTruthy();
  expect(isBusinessOk(loaded.payload), JSON.stringify(loaded.payload)).toBeTruthy();

  const createBody = {
    preOrderNo,
    shippingType: 1,
    addressId,
    couponId: 0,
    useIntegral: false,
    mark,
    storeId: 0,
    realName: '',
    phone: '',
  };
  const created = await apiRequest(fixtures.frontApi, '/api/front/order/create', {
    method: 'POST',
    token,
    body: createBody,
  });
  expect(created.response.ok).toBeTruthy();
  expect(isBusinessOk(created.payload), JSON.stringify(created.payload)).toBeTruthy();
  const orderNo = created.payload.data?.orderNo;
  expect(orderNo).toBeTruthy();

  return {
    preOrderNo,
    orderNo,
    mark,
    loaded: loaded.payload.data,
    createBody,
  };
}
