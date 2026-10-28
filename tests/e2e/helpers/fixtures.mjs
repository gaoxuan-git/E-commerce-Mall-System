import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const rootDir = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const fixturePath = path.join(rootDir, 'runtime', 'fixtures.json');

export function readRuntimeFixtures() {
  if (!fs.existsSync(fixturePath)) {
    throw new Error(`Runtime fixture file is missing: ${fixturePath}. Run Playwright through its configured global setup.`);
  }
  return JSON.parse(fs.readFileSync(fixturePath, 'utf8'));
}

export function resolveRoute(route, fixtures) {
  return route.replace(/\{([a-zA-Z0-9_]+)\}/g, (_, key) => {
    const value = fixtures[key];
    if (value === undefined || value === null || value === '') {
      throw new Error(`Route fixture "${key}" is unavailable for ${route}`);
    }
    return encodeURIComponent(String(value));
  });
}

export function firstList(payload) {
  const candidates = [
    payload,
    payload?.list,
    payload?.content,
    payload?.page?.list,
    payload?.page?.content,
    payload?.records,
  ];
  return candidates.find(Array.isArray) || [];
}
