import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

// Load the pure module as ESM without changing the uni-app package type.
globalThis.uni = { getStorageSync: () => '' };
const source = await readFile(new URL('../frontend/uni-app/config/serverConnection.js', import.meta.url), 'utf8');
const { createConnectionManager, normalizeConnection, origins, CONNECTION_KEY } = await import('data:text/javascript;base64,' + Buffer.from(source).toString('base64'));
const candidate = { host: '192.168.1.8', apiPort: 8081, imagePort: 8080 };
function mock(saved, responder) {
	const data = new Map(saved ? [[CONNECTION_KEY, saved]] : []);
	const calls = [];
	return {
		data, calls,
		getStorageSync: key => data.get(key),
		setStorageSync: (key, value) => data.set(key, value),
		removeStorageSync: key => data.delete(key),
		getStorageInfoSync: () => ({ keys: [...data.keys()] }),
		request(options) {
			calls.push(options);
			queueMicrotask(() => {
				if (responder) return responder(options);
				options.success({ statusCode: 200, data: { code: 200, data: {
					service: options.url.includes('/api/front/') ? 'crmeb-front' : 'crmeb-admin',
					protocolVersion: 1, imageRoot: '/crmebimage', imageDirectoryReadable: true
				} } });
			});
			return { abort() {} };
		}
	};
}
test('validates IP, origin, credentials, protocol, and port bounds', () => {
	assert.equal(origins(normalizeConnection(candidate)).api, 'http://192.168.1.8:8081');
	assert.equal(normalizeConnection({ ...candidate, host: 'https://demo.local:9001/' }).apiPort, 9001);
	for (const host of ['', '256.1.1.1', '1.2.3', 'https://a:b@demo.local', 'http://demo.local/path', 'javascript:alert(1)', 'a-.local']) {
		assert.throws(() => normalizeConnection({ ...candidate, host }));
	}
	for (const apiPort of ['', 0, 65536, 1.5, '8081x']) assert.throws(() => normalizeConnection({ ...candidate, apiPort }));
	assert.throws(() => normalizeConnection({ ...candidate, version: 2 }));
});
test('native without configuration fails closed; H5 keeps default', async () => {
	const storage = mock({ ...candidate, version: 2 });
	const manager = createConnectionManager(storage, true);
	assert.equal(manager.api(), '');
	await assert.rejects(manager.ensureReady());
	assert.equal(storage.calls.length, 0);
	assert.equal(createConnectionManager(mock(), false).api(), 'http://127.0.0.1:8081');
});
test('probe is anonymous and bootstrap is shared', async () => {
	const storage = mock(candidate);
	storage.data.set('token', 'OLD');
	const manager = createConnectionManager(storage, true);
	await Promise.all([manager.ensureReady(), manager.ensureReady()]);
	assert.equal(storage.calls.length, 2);
	for (const options of storage.calls) {
		assert.deepEqual(options.header, { Accept: 'application/json' });
		assert.equal(options.withCredentials, false);
		assert.ok(options.timeout <= 6000);
	}
});
test('unmatched services, versions, unreadable images, and failed requests reject', async () => {
	for (const metadata of [{ service: 'wrong', protocolVersion: 1 }, { service: 'crmeb-front', protocolVersion: 2 }, { service: 'crmeb-admin', protocolVersion: 1, imageRoot: '/crmebimage', imageDirectoryReadable: false }]) {
		const storage = mock(candidate, options => options.success({ statusCode: 200, data: { code: 200, data: metadata } }));
		await assert.rejects(createConnectionManager(storage, true).probe(candidate));
		assert.deepEqual(storage.data.get(CONNECTION_KEY), candidate);
	}
	await assert.rejects(createConnectionManager(mock(null, options => options.fail({ errMsg: 'timeout' })), true).probe(candidate));
});
test('proof binds candidate; failed save leaves old connection and token', async () => {
	const storage = mock(candidate);
	storage.data.set('token', 'OLD');
	const manager = createConnectionManager(storage, true);
	const proof = await manager.probe(candidate);
	assert.throws(() => manager.save({ ...candidate, host: '192.168.1.9' }, proof));
	storage.setStorageSync = () => { throw new Error('disk full'); };
	assert.throws(() => manager.save(candidate, proof));
	assert.equal(manager.api(), 'http://192.168.1.8:8081');
	assert.equal(storage.data.get('token'), 'OLD');
});
test('same API preserves login; different API isolates caches; clear retains configuration', async () => {
	const storage = mock(candidate);
	storage.data.set('token', 'OLD');
	storage.data.set('USER_INFO', 'old-user');
	const manager = createConnectionManager(storage, true);
	const same = { ...candidate, imagePort: 8090 };
	manager.save(same, await manager.probe(same));
	assert.equal(storage.data.get('token'), 'OLD');
	const other = { ...same, host: '10.0.2.2' };
	manager.save(other, await manager.probe(other));
	assert.equal(storage.data.has('token'), false);
	assert.equal(storage.data.has('USER_INFO'), false);
	assert.equal(manager.api(), 'http://10.0.2.2:8081');
	manager.clearBusinessStorage();
	assert.ok(storage.data.has(CONNECTION_KEY));
	assert.equal(createConnectionManager(storage, true).api(), manager.api());
});
test('nested media and HTML local URLs follow image origin; CDN, payment, OAuth are unchanged', () => {
	const manager = createConnectionManager(mock(candidate), true);
	const external = 'https://cdn.example.com/crmebimage/a.png';
	const value = manager.rewrite({
		images: ['/crmebimage/a.png', 'http://127.0.0.1:8080/crmebimage/b.png', 'http://10.1.2.3:8080/crmebimage/c.png', external],
		html: '<img src="http://192.168.3.4:8080/crmebimage/a.png">',
		pay: 'https://pay.example.com/pay', oauth: 'https://open.weixin.qq.com/connect/oauth2'
	});
	assert.equal(value.images[0], 'http://192.168.1.8:8080/crmebimage/a.png');
	assert.equal(value.images[3], external);
	assert.ok(value.html.includes('http://192.168.1.8:8080/crmebimage/a.png'));
	assert.equal(value.pay, 'https://pay.example.com/pay');
});
test('hung probes are bounded and aborted without saving candidate', async () => {
	const storage = mock(candidate);
	let aborted = 0;
	storage.request = () => ({ abort() { aborted++; } });
	const start = Date.now();
	await assert.rejects(createConnectionManager(storage, true).probe(candidate), /连接超时/);
	assert.ok(Date.now() - start < 8000);
	assert.equal(aborted, 2);
	assert.deepEqual(storage.data.get(CONNECTION_KEY), candidate);
});
