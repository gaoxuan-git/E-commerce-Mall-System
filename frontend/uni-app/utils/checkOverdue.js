import { HTTP_REQUEST_URL, HEADER, TOKENNAME } from '@/config/app';
import { LOGIN_STATUS } from '@/config/cache';
import { useAppStore } from "../store/app.js";
import { serverConnection } from '@/config/serverConnection.js';
export async function checkOverdue(data) {
	try { await serverConnection.ensureReady(); } catch (_) { return; }
	const generation = serverConnection.getGeneration();
	const appStore = useAppStore();
	const token = appStore.token || getCacheToken();
	let Url = HTTP_REQUEST_URL,header = { ...HEADER };
	if (token) header[TOKENNAME] = `Bearer ${token}`;
	if (!token) return;
	uni.request({
		url: Url + '/api/front/user',
		method: 'GET',
		header: header,
		success:(res) =>{
			if (generation !== serverConnection.getGeneration()) return;
			if(res.data && [410000, 410001, 410002, 401, 402].indexOf(res.data.code) !== -1){
				useAppStore().LOGOUT();
			}
		}
	})
}

function getCacheToken() {
	try {
		return uni.getStorageSync(LOGIN_STATUS) || '';
	} catch (e) {
		return '';
	}
}
