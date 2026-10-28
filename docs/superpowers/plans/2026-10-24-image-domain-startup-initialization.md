# Image Domain Startup Initialization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Initialize and cache the configured image domain whenever the uni-app application starts.

**Architecture:** Reuse the existing unauthenticated `getImageDomain()` API in `App.vue`. A focused startup helper validates the response before writing `imgHost`; failures remain non-blocking and preserve any cached value.

**Tech Stack:** Vue 3, uni-app, Pinia, existing request and cache utilities

---

### Task 1: Add Image Domain Startup Initialization

**Files:**
- Modify: `frontend/uni-app/App.vue:32-130`

- [x] **Step 1: Extend the existing API import**

Replace:

```js
import { loginConfigApi } from '@/api/api.js';
```

with:

```js
import { getImageDomain, loginConfigApi } from '@/api/api.js';
```

- [x] **Step 2: Add a non-blocking initialization helper**

Add this function next to `getLoginConfig()`:

```js
function initializeImageDomain() {
	return getImageDomain().then(res => {
		const imageDomain = typeof res.data === 'string' ? res.data.trim() : '';
		if (imageDomain) Cache.set('imgHost', imageDomain);
	}).catch(() => {});
}
```

The helper writes only non-empty string responses. Because the catch handler does not clear the cache or rethrow, a temporary API failure cannot block application startup or erase a previously valid domain.

- [x] **Step 3: Call the helper during application launch**

Immediately after `resolveApp()` in `onLaunch`, add:

```js
initializeImageDomain();
```

- [x] **Step 4: Check the focused diff**

Run:

```bash
git diff --check -- frontend/uni-app/App.vue
git diff -- frontend/uni-app/App.vue
```

Expected: no whitespace errors; the diff contains only the API import, helper, startup call, and the pre-existing neutral-branding edits.

### Task 2: Verify Build and Runtime Behavior

**Files:**
- Verify: `frontend/uni-app/App.vue`
- Verify: `frontend/uni-app/dist/build/h5`

- [x] **Step 1: Build H5**

Run:

```bash
npm run build:h5
```

from `frontend/uni-app`.

Expected: Vite completes the production build without errors.

- [x] **Step 2: Verify the configured endpoint and image asset**

Run:

```bash
curl -sS http://127.0.0.1:8081/api/front/image/domain
curl -sS -o /dev/null -w '%{http_code} %{content_type}\n' \
  http://127.0.0.1:8080/crmebimage/perset/staticImg/noAddress.png
```

Expected:

```text
{"code":200,"message":null,"data":"http://127.0.0.1:8080"}
200 image/png
```

- [x] **Step 3: Verify cold-start cache initialization**

Open the H5 application with a mobile viewport, clear the `imgHost` local-storage entry, reload, and inspect local storage after application launch.

Expected: `imgHost` equals `http://127.0.0.1:8080`, and the address empty-state image URL resolves under that host.

- [x] **Step 4: Report the result without committing unrelated work**

Summarize the modified file, build result, endpoint result, and runtime cache result. Do not stage or commit unrelated existing workspace changes.
