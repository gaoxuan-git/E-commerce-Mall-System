import { chromium } from 'playwright';
import http from 'node:http';
import { readFile, stat, mkdir, writeFile } from 'node:fs/promises';
import { resolve, extname } from 'node:path';
import assert from 'node:assert/strict';

const root = resolve('frontend/uni-app/dist/build/h5');
const server = http.createServer(async (req, res) => {
	try {
		let path = resolve(root, '.' + new URL(req.url, 'http://localhost').pathname);
		try { if (!(await stat(path)).isFile()) path = root + '/index.html'; } catch { path = root + '/index.html'; }
		res.setHeader('Content-Type', ({ '.html': 'text/html', '.js': 'application/javascript', '.css': 'text/css', '.png': 'image/png', '.svg': 'image/svg+xml' })[extname(path)] || 'application/octet-stream');
		res.end(await readFile(path));
	} catch { res.writeHead(500).end(); }
});
await new Promise(resolve => server.listen(5283, '0.0.0.0', resolve));
const browser = await chromium.launch({ channel: 'chrome', headless: true });
const page = await browser.newPage({ viewport: { width: 390, height: 844 } });
const requests = [];
const errors = [];
page.on('request', req => { if (/connection\/info/.test(req.url())) requests.push({ url: req.url(), authorization: req.headers().authorization || null }); });
page.on('pageerror', error => errors.push(error.message));
page.on('console', message => { if (message.type() === 'error') console.log('browser console', message.text()); });
const artifacts = resolve('APK安装包/连接验证');
await mkdir(artifacts, { recursive: true });
try {
	await page.goto('http://127.0.0.1:5283/pages/server_connection/index?edit=1');
	await page.locator('input').first().fill('256.1.1.1');
	await page.getByText('检测连接', { exact: true }).click();
	await page.getByText('IP 地址格式错误', { exact: true }).waitFor();
	await page.locator('input').first().fill('127.0.0.1');
	await page.getByText('检测连接', { exact: true }).click();
	await page.getByText('两个服务均已连通，可以保存。', { exact: true }).waitFor();
	await page.screenshot({ path: artifacts + '/H5-检测成功.png', fullPage: true });
	await page.getByText('保存并连接', { exact: true }).click();
	await page.waitForURL(/pages\/(?:guide|index)\/index/);
	await page.goto('http://127.0.0.1:5283/pages/server_connection/index?edit=1');
	assert.equal(await page.locator('input').first().inputValue(), '127.0.0.1');
	// Wrong image service preserves the saved config and cannot enable save.
	await page.locator('input').nth(2).fill('8081');
	await page.getByText('检测连接', { exact: true }).click();
	await page.getByText('服务不匹配，请检查端口并更新后端', { exact: true }).first().waitFor();
	await page.reload();
	assert.equal(await page.locator('input').nth(2).inputValue(), '8080');
	await page.locator('input').first().fill('10.178.79.201');
	await page.getByText('检测连接', { exact: true }).click();
	await page.getByText('两个服务均已连通，可以保存。', { exact: true }).waitFor();
	await page.getByText('保存并连接', { exact: true }).click();
	await page.waitForURL(/pages\/(?:guide|index)\/index/);
	await page.goto('http://127.0.0.1:5283/pages/server_connection/index?edit=1');
	assert.equal(await page.locator('input').first().inputValue(), '10.178.79.201');
	assert.ok(requests.every(req => req.authorization === null));
	assert.deepEqual(errors, []);
	await writeFile(artifacts + '/H5验证.json', JSON.stringify({ passed: true, checks: ['非法IP', '双服务检测', '保存重载', '错误端口保留原配置', '切换LAN IP无需构建', '匿名检测'], requests, errors }, null, 2));
	console.log('H5 connection UI checks passed', requests.length);
} catch (error) {
	console.log('UI failure', await page.locator('.message').allTextContents(), requests, errors);
	await page.screenshot({ path: artifacts + '/H5-调试.png', fullPage: true });
	throw error;
} finally { await browser.close(); server.close(); }
