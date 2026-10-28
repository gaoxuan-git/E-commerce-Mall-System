// 单设备服务器配置。探测独立于业务请求，不携带登录凭据。
export const CONNECTION_KEY = 'CRMEB_SERVER_CONNECTION_V1';
export const DEFAULT_API = 'http://127.0.0.1:8081';

export function normalizeConnection(input) {
	if (!input || (input.version !== undefined && input.version !== 1)) throw new Error('服务器配置版本无效');
	let host = String(input.host || '').trim().toLowerCase();
	let scheme = input.scheme || 'http';
	let apiPort = input.apiPort === undefined ? 8081 : input.apiPort;
	if (/^https?:\/\//i.test(host)) {
		const match = /^(https?):\/\/([^/:?#@]+)(?::(\d+))?\/?$/.exec(host);
		if (!match) throw new Error('请填写 IP、域名或不含路径的服务器地址');
		scheme = match[1];
		host = match[2];
		if (match[3]) apiPort = match[3];
	}
	if (!['http', 'https'].includes(scheme)) throw new Error('协议仅支持 HTTP / HTTPS');
	if (/^[\d.]+$/.test(host)) {
		if (!/^(\d{1,3}\.){3}\d{1,3}$/.test(host) || host.split('.').some(n => +n > 255)) throw new Error('IP 地址格式错误');
		host = host.split('.').map(n => String(+n)).join('.');
	} else if (!host || host.length > 253 || !host.split('.').every(n => /^[a-z\d](?:[a-z\d-]{0,61}[a-z\d])?$/.test(n))) {
		throw new Error('域名格式错误，请勿填写路径或账号密码');
	}
	const port = (value, label) => {
		if (!/^\d+$/.test(String(value)) || +value < 1 || +value > 65535) throw new Error(`${label}必须为 1–65535 的整数`);
		return +value;
	};
	return { version: 1, scheme, host, apiPort: port(apiPort, '商城端口'), imagePort: port(input.imagePort === undefined ? 8080 : input.imagePort, '图片端口') };
}

export function origins(config) {
	return { api: `${config.scheme}://${config.host}:${config.apiPort}`, image: `${config.scheme}://${config.host}:${config.imagePort}` };
}

export function createConnectionManager(storage, native = false) {
	let config = null;
	try { const saved = storage.getStorageSync(CONNECTION_KEY); if (saved) config = normalizeConnection(saved); } catch (_) {}
	let ready = !native && !config;
	let bootstrap;
	let generation = 0;
	const proofs = new WeakMap();
	const api = () => config ? origins(config).api : (native ? '' : DEFAULT_API);
	const image = () => config ? origins(config).image : '';
	const probeService = (origin, path, service, progress, key) => new Promise((resolve, reject) => {
		let settled = false;
		let task;
		const finish = (error, data) => {
			if (settled) return;
			settled = true;
			clearTimeout(timer);
			if (progress) progress(key, error ? error.message : '连接正常');
			error ? reject(error) : resolve(data);
		};
		const timer = setTimeout(() => { finish(new Error('连接超时，请检查 IP、端口和同一局域网')); if (task) task.abort(); }, 6000);
		try {
			task = storage.request({
				url: origin + path, method: 'GET', timeout: 5500,
				header: { Accept: 'application/json' }, withCredentials: false,
				success: res => {
					const body = res.data;
					const data = body && body.data;
					if (res.statusCode !== 200 || !body || body.code !== 200 || !data || data.service !== service || data.protocolVersion !== 1) {
						return finish(new Error('服务不匹配，请检查端口并更新后端'));
					}
					if (service === 'crmeb-admin' && (data.imageRoot !== '/crmebimage' || !data.imageDirectoryReadable)) return finish(new Error('图片目录不可读，请检查后端图片配置'));
					finish(null, data);
				},
				fail: () => finish(new Error('无法连接，请检查 IP、端口和网络'))
			});
		} catch (error) { console.error('服务器检测初始化失败', error); finish(new Error('无法发起连接检测')); }
	});
	async function probe(input, progress) {
		const candidate = normalizeConnection(input);
		const urls = origins(candidate);
		const results = await Promise.allSettled([
			probeService(urls.api, '/api/front/connection/info', 'crmeb-front', progress, 'api'),
			probeService(urls.image, '/api/public/connection/info', 'crmeb-admin', progress, 'image')
		]);
		const failed = results.find(r => r.status === 'rejected');
		if (failed) throw failed.reason;
		const proof = {};
		proofs.set(proof, { fingerprint: JSON.stringify(candidate), expires: Date.now() + 60000 });
		return proof;
	}
	function save(input, proof) {
		const candidate = normalizeConnection(input);
		const validated = proofs.get(proof);
		if (!validated || validated.fingerprint !== JSON.stringify(candidate) || validated.expires < Date.now()) throw new Error('配置已变化或检测已过期，请重新检测');
		const changed = api() !== origins(candidate).api;
		// 先持久化；失败时保留旧地址与账号。
		storage.setStorageSync(CONNECTION_KEY, candidate);
		config = candidate;
		ready = false;
		bootstrap = null;
		generation++;
		proofs.delete(proof);
		// 同接口保留账号，换接口清除全部服务缓存；连接配置本身不受影响。
		const keys = changed ? storage.getStorageInfoSync().keys : ['imgHost', 'mobileLoginLogo', 'viewColor', 'themeInfo'];
		keys.forEach(key => { if (key !== CONNECTION_KEY) storage.removeStorageSync(key); });
		storage.setStorageSync('imgHost', image());
		return { changed, config: { ...config } };
	}
	function ensureReady() {
		if (ready) return Promise.resolve(true);
		if (!bootstrap) {
			bootstrap = (config ? probe(config).then(() => { ready = true; return true; }) : Promise.reject(new Error('请先配置服务器')))
				.catch(error => { bootstrap = null; throw error; });
		}
		return bootstrap;
	}
	function clearBusinessStorage() {
		storage.getStorageInfoSync().keys.forEach(key => { if (key !== CONNECTION_KEY) storage.removeStorageSync(key); });
	}
	function rewrite(value) {
		if (!config) return value;
		if (Array.isArray(value)) return value.map(rewrite);
		if (value && typeof value === 'object') return Object.fromEntries(Object.entries(value).map(([key, item]) => [key, rewrite(item)]));
		if (typeof value !== 'string') return value;
		return value.replace(/(?:https?:\/\/[^\s"'<>]+)?\/crmebimage\/[^\s"'<>]*/g, resource => {
			if (resource.startsWith('/')) return image() + resource;
			const match = /^(https?:\/\/([^/:]+)(?::\d+)?)(\/crmebimage\/.*)$/.exec(resource);
			if (!match) return resource;
			const host = match[2].toLowerCase();
			const local = host === config.host || host === 'localhost' || host === '127.0.0.1' || /^10\./.test(host) || /^192\.168\./.test(host) || /^172\.(1[6-9]|2\d|3[01])\./.test(host);
			return local ? image() + match[3] : resource;
		});
	}
	return { api, image, probe, save, ensureReady, rewrite, clearBusinessStorage, getConfig: () => config && { ...config }, getGeneration: () => generation };
}

let native = false;
// #ifdef APP-PLUS
native = true;
// #endif
// 显式引用各 API，确保 H5 编译器按需导入 request 而非只生成 storage 子集。
export const serverConnection = createConnectionManager({
	getStorageSync: key => uni.getStorageSync(key),
	setStorageSync: (key, value) => uni.setStorageSync(key, value),
	removeStorageSync: key => uni.removeStorageSync(key),
	getStorageInfoSync: () => uni.getStorageInfoSync(),
	request: options => uni.request(options)
}, native);
