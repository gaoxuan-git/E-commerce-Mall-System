import { expect } from '@playwright/test';

export function installDiagnostics(page) {
  const state = {
    consoleErrors: [],
    pageErrors: [],
    requestFailures: [],
    badResponses: [],
    externalRequests: [],
  };

  page.on('console', (message) => {
    if (message.type() === 'error') state.consoleErrors.push(message.text());
  });
  page.on('pageerror', (error) => state.pageErrors.push(error.message));
  page.on('requestfailed', (request) => {
    state.requestFailures.push(`${request.method()} ${request.url()} ${request.failure()?.errorText || ''}`.trim());
  });
  page.on('request', (request) => {
    const url = new URL(request.url());
    if (['http:', 'https:'].includes(url.protocol) && !['127.0.0.1', 'localhost'].includes(url.hostname)) {
      state.externalRequests.push(`${request.method()} ${request.url()}`);
    }
  });
  page.on('response', (response) => {
    if (response.status() >= 500) {
      state.badResponses.push(`${response.status()} ${response.request().method()} ${response.url()}`);
    }
  });
  return state;
}

function withoutAllowed(values, allowedPatterns = []) {
  return values.filter((value) => !allowedPatterns.some((pattern) => pattern.test(value)));
}

export async function assertPageHealthy(page, diagnostics, options = {}) {
  await page.waitForLoadState('domcontentloaded');
  await page.waitForTimeout(options.settleMs || 800);
  await page
    .waitForFunction(
      () => {
        const root = document.querySelector('#app') || document.body;
        const text = (root?.innerText || '').replace(/\s+/g, ' ').trim();
        return text.length > 0 || Boolean(root?.querySelector('img, canvas, video, iframe'));
      },
      null,
      { timeout: options.contentTimeout || 10_000 },
    )
    .catch(() => {});

  const pageShape = await page.evaluate(() => {
    const body = document.body;
    const root = document.querySelector('#app') || body;
    const visibleImages = [...document.images].filter((image) => {
      const style = getComputedStyle(image);
      const rect = image.getBoundingClientRect();
      return style.display !== 'none' && style.visibility !== 'hidden' && rect.width > 0 && rect.height > 0;
    });
    return {
      text: (root?.innerText || '').replace(/\s+/g, ' ').trim(),
      childCount: root?.childElementCount || 0,
      badImages: visibleImages
        .filter((image) => image.complete && image.naturalWidth === 0)
        .map((image) => image.currentSrc || image.src),
      bodyScrollWidth: body?.scrollWidth || 0,
      viewportWidth: window.innerWidth,
    };
  });

  expect(pageShape.childCount, 'root element must render content').toBeGreaterThan(0);
  expect(
    pageShape.text.length > 0 || (await page.locator('img, canvas, video, iframe').count()) > 0,
    'page must not be visually blank',
  ).toBeTruthy();
  expect(pageShape.badImages, `broken images: ${pageShape.badImages.join(', ')}`).toEqual([]);
  expect(pageShape.bodyScrollWidth, 'page must not have horizontal document overflow').toBeLessThanOrEqual(
    pageShape.viewportWidth + 1,
  );

  const consoleErrors = withoutAllowed(diagnostics.consoleErrors, options.allowConsole || []);
  const pageErrors = withoutAllowed(diagnostics.pageErrors, options.allowPageErrors || []);
  const requestFailures = withoutAllowed(diagnostics.requestFailures, options.allowRequestFailures || []);
  const badResponses = withoutAllowed(diagnostics.badResponses, options.allowResponses || []);
  const externalRequests = withoutAllowed(diagnostics.externalRequests, options.allowExternalRequests || []);

  expect(consoleErrors, `console errors: ${consoleErrors.join('\n')}`).toEqual([]);
  expect(pageErrors, `page errors: ${pageErrors.join('\n')}`).toEqual([]);
  expect(requestFailures, `failed requests: ${requestFailures.join('\n')}`).toEqual([]);
  expect(badResponses, `HTTP 5xx responses: ${badResponses.join('\n')}`).toEqual([]);
  expect(externalRequests, `unexpected external requests: ${externalRequests.join('\n')}`).toEqual([]);
}
