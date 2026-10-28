import { test, expect } from '@playwright/test';
import { spawnSync } from 'node:child_process';
import { apiRequest, expectBusinessOk, loginFront } from '../helpers/api.mjs';
import { expectBusinessFailure, sqlQuote } from '../helpers/core.mjs';
import { queryRows, queryScalar } from '../helpers/database.mjs';
import { readRuntimeFixtures } from '../helpers/fixtures.mjs';

function redisValue(command, key) {
  const result = spawnSync('redis-cli', [
    '-n', process.env.REDIS_DB || '10', '--raw', command, key,
  ], { encoding: 'utf8' });
  expect(result.status, result.stderr).toBe(0);
  return result.stdout.trim();
}

function unusedAccount() {
  let account = '13998880001';
  while (Number(queryScalar(`SELECT COUNT(*) FROM eb_user WHERE phone = ${sqlQuote(account)}`))
    || redisValue('EXISTS', `sms:validate:code:${account}`) !== '0'
    || redisValue('EXISTS', `sms:validate:phone:${account}`) !== '0') {
    account = String(Number(account) + 1);
  }
  return account;
}

test('@core synthetic registration, code rate limit, password reset and password login form a real API lifecycle', async () => {
  test.setTimeout(100_000);
  const fixtures = readRuntimeFixtures();
  expect(new URL(fixtures.frontApi).hostname).toBe('127.0.0.1');
  const account = unusedAccount();
  const codeKey = `sms:validate:code:${account}`;
  const rateKey = `sms:validate:phone:${account}`;
  const sendCode = () => apiRequest(fixtures.frontApi, '/api/front/sendCode', {
    method: 'POST', query: { phone: account },
  });
  const send = await sendCode();
  expect(send.payload?.code).toBe(200);
  expect(String(JSON.parse(redisValue('GET', codeKey)))).toBe('123456');
  expectBusinessFailure(await sendCode(), /发送过于频繁/);

  const registered = await expectBusinessOk(fixtures.frontApi, '/api/front/register', {
    method: 'POST', body: { account, captcha: '123456', password: 'Auth_123', spread_spid: 0 },
  });
  expect(registered.uid).toBeGreaterThan(0);
  expect(registered.token).toBeTruthy();
  expect(redisValue('EXISTS', codeKey)).toBe('0');
  expect(queryRows(`SELECT account,phone FROM eb_user WHERE uid = ${Number(registered.uid)}`))
    .toEqual([[account, account]]);
  await expectBusinessOk(fixtures.frontApi, '/api/front/user', { token: registered.token });
  expect((await loginFront(fixtures.frontApi, account, 'Auth_123')).uid).toBe(registered.uid);

  // 保留真实 60 秒限流，不清除 Redis，也不改动既有账号。
  await expect.poll(() => redisValue('EXISTS', rateKey), {
    timeout: 65_000, intervals: [1_000],
  }).toBe('0');
  expect((await sendCode()).payload?.code).toBe(200);
  const reset = (body) => apiRequest(fixtures.frontApi, '/api/front/register/reset', {
    method: 'POST', token: registered.token, body,
  });
  const before = queryScalar(`SELECT pwd FROM eb_user WHERE uid = ${Number(registered.uid)}`);
  for (const [body, message] of [
    [{ account, captcha: '123456' }, /密码不能为空/],
    [{ account, password: 'Auth_456' }, /验证码不能为空/],
    [{ account, captcha: '654321', password: 'Auth_456' }, /验证码错误/],
  ]) {
    expectBusinessFailure(await reset(body), message);
    expect(queryScalar(`SELECT pwd FROM eb_user WHERE uid = ${Number(registered.uid)}`)).toBe(before);
    expect(redisValue('EXISTS', codeKey)).toBe('1');
  }
  const changed = await reset({ account, captcha: '123456', password: 'Auth_456' });
  expect(changed.payload?.code).toBe(200);
  expect(changed.payload?.data).toBe(true);
  expect(redisValue('EXISTS', codeKey)).toBe('0');
  expectBusinessFailure(await reset({ account, captcha: '123456', password: 'Auth_789' }), /验证码已过期/);
  expectBusinessFailure(await apiRequest(fixtures.frontApi, '/api/front/login', {
    method: 'POST', body: { account, password: 'Auth_123', spread_spid: 0 },
  }), /密码错误/);
  const login = await loginFront(fixtures.frontApi, account, 'Auth_456');
  expect(login.uid).toBe(registered.uid);
  await expectBusinessOk(fixtures.frontApi, '/api/front/logout', { token: login.token });
});

test('@core reset of an unregistered synthetic phone returns a business error and retains its code', async () => {
  const fixtures = readRuntimeFixtures();
  const account = unusedAccount();
  await expectBusinessOk(fixtures.frontApi, '/api/front/sendCode', {
    method: 'POST', query: { phone: account },
  });
  expectBusinessFailure(await apiRequest(fixtures.frontApi, '/api/front/register/reset', {
    method: 'POST', token: fixtures.h5Token,
    body: { account, captcha: '123456', password: 'Auth_123' },
  }), /用户不存在/);
  expect(Number(queryScalar(`SELECT COUNT(*) FROM eb_user WHERE phone = ${sqlQuote(account)}`))).toBe(0);
  expect(redisValue('EXISTS', `sms:validate:code:${account}`)).toBe('1');
});
