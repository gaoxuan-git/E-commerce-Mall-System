import { expect } from '@playwright/test';

export const SOURCE_HEADER = 'df07addc462f7f8f';

export function apiHeaders(token, extra = {}) {
  return {
    'Content-Type': 'application/json',
    'X-Source': SOURCE_HEADER,
    ...(token ? { Authorization: `Bearer ${token}` } : {}),
    ...extra,
  };
}

export async function apiRequest(baseURL, path, options = {}) {
  const url = new URL(path, baseURL);
  for (const [name, value] of Object.entries(options.query || {})) {
    if (value === undefined || value === null) continue;
    const values = Array.isArray(value) ? value : [value];
    for (const item of values) url.searchParams.append(name, String(item));
  }

  let body;
  const headers = { ...options.headers };
  if (options.body !== undefined) {
    if (options.bodyEncoding === 'form') {
      body = new URLSearchParams(options.body).toString();
      headers['Content-Type'] = 'application/x-www-form-urlencoded';
    } else {
      body = JSON.stringify(options.body);
    }
  }

  const response = await fetch(url, {
    method: options.method || 'GET',
    headers: apiHeaders(options.token, headers),
    body,
    signal: AbortSignal.timeout(options.timeout || 15_000),
  });

  const text = await response.text();
  let payload;
  try {
    payload = text ? JSON.parse(text) : null;
  } catch {
    throw new Error(`${options.method || 'GET'} ${path} returned non-JSON HTTP ${response.status}`);
  }

  if (!options.allowHttpError && !response.ok) {
    throw new Error(`${options.method || 'GET'} ${path} returned HTTP ${response.status}: ${text.slice(0, 300)}`);
  }
  return { response, payload };
}

export async function expectBusinessOk(baseURL, path, options = {}) {
  const { response, payload } = await apiRequest(baseURL, path, options);
  expect(response.ok, `${path} HTTP status`).toBeTruthy();
  expect([0, 200], `${path} business code: ${JSON.stringify(payload)}`).toContain(payload?.code);
  return payload.data;
}

export async function loginAdmin(baseURL, account, password) {
  return expectBusinessOk(baseURL, '/api/admin/login', {
    method: 'POST',
    body: { account, pwd: password },
  });
}

export async function loginFront(baseURL, account, password) {
  return expectBusinessOk(baseURL, '/api/front/login', {
    method: 'POST',
    body: { account, password, spread_spid: 0 },
  });
}
