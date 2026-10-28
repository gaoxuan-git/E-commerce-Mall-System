import { defineConfig } from '@playwright/test';
import dotenv from 'dotenv';

dotenv.config();

const h5BaseURL = process.env.H5_BASE_URL || 'http://127.0.0.1:5273';
const adminBaseURL = process.env.ADMIN_BASE_URL || 'http://127.0.0.1:9527';

export default defineConfig({
  testDir: './specs',
  fullyParallel: false,
  forbidOnly: true,
  retries: 0,
  workers: 1,
  timeout: 45_000,
  expect: {
    timeout: 10_000,
  },
  globalSetup: './global-setup.mjs',
  globalTeardown: './global-teardown.mjs',
  outputDir: './artifacts/test-results',
  reporter: [
    ['line'],
    ['json', { outputFile: './artifacts/results.json' }],
    ['html', { outputFolder: './artifacts/html-report', open: 'never' }],
  ],
  use: {
    browserName: 'chromium',
    channel: 'chrome',
    actionTimeout: 10_000,
    navigationTimeout: 20_000,
    screenshot: 'only-on-failure',
    trace: 'retain-on-failure',
    video: 'off',
  },
  projects: [
    {
      name: 'h5-mobile',
      testMatch: /h5-.*\.spec\.mjs|security-boundaries\.spec\.mjs/,
      use: {
        baseURL: h5BaseURL,
        viewport: { width: 390, height: 844 },
        storageState: './auth/h5.json',
      },
    },
    {
      name: 'admin-desktop',
      testMatch: /admin-.*\.spec\.mjs|cross-system-lifecycle\.spec\.mjs|dev-one-pass-mock\.spec\.mjs/,
      use: {
        baseURL: adminBaseURL,
        viewport: { width: 1440, height: 900 },
        storageState: './auth/admin.json',
      },
    },
  ],
});
