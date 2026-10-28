import { test, expect } from '@playwright/test';
import { spawnSync } from 'node:child_process';
import { apiRequest } from '../helpers/api.mjs';
import { expectBusinessFailure, sqlQuote } from '../helpers/core.mjs';
import { queryScalar } from '../helpers/database.mjs';
import { readRuntimeFixtures } from '../helpers/fixtures.mjs';

test('@core registration rejects invalid input, expired codes, and existing accounts without creating users', async () => {
  const fixtures = readRuntimeFixtures();
  let account = '13999990001';
  const hasCode = () => {
    const result = spawnSync('redis-cli', [
      '-n', process.env.REDIS_DB || '10', '--raw', 'EXISTS', `sms:validate:code:${account}`,
    ], { encoding: 'utf8' });
    expect(result.status, result.stderr).toBe(0);
    return result.stdout.trim() !== '0';
  };
  while (Number(queryScalar(`SELECT COUNT(*) FROM eb_user WHERE phone = ${sqlQuote(account)}`)) || hasCode()) {
    account = String(Number(account) + 1);
  }
  const userCount = Number(queryScalar('SELECT COUNT(*) FROM eb_user'));
  const valid = { account, captcha: '123456', password: 'Test_123', spread_spid: 0 };
  const cases = [
    { body: { ...valid, account: '123' }, message: /手机号码格式错误/ },
    { body: { ...valid, captcha: '12' }, message: /验证码必须为6位数字/ },
    { body: { ...valid, password: '123456' }, message: /密码必须以字母开头/ },
    { body: valid, message: /验证码已过期/ },
    {
      body: { ...valid, account: queryScalar(`SELECT phone FROM eb_user WHERE uid = ${fixtures.primaryUserId}`) },
      message: /手机号已注册/,
    },
  ];
  for (const item of cases) {
    const result = await apiRequest(fixtures.frontApi, '/api/front/register', {
      method: 'POST', body: item.body,
    });
    expectBusinessFailure(result, item.message);
    expect(result.payload?.data?.token).toBeFalsy();
    expect(Number(queryScalar('SELECT COUNT(*) FROM eb_user'))).toBe(userCount);
    expect(Number(queryScalar(`SELECT COUNT(*) FROM eb_user WHERE phone = ${sqlQuote(account)}`))).toBe(0);
  }
});
