<template>
	<view class="connection-page">
		<view class="topline"><text>电商网购系统</text><text class="badge">设备连接</text></view>
		<view class="title">连接你的服务器</view>
		<view class="description">手机与电脑连接同一局域网。电脑 IP 变化后，在这里修改即可。</view>
		<view class="form">
			<text class="label">服务器 IP / 域名</text>
			<input class="host" v-model="form.host" placeholder="例如 192.168.1.100" :maxlength="260" :disabled="busy" />
			<view class="protocol">
				<view v-for="scheme in ['http', 'https']" :key="scheme" :class="{ selected: form.scheme === scheme }" @click="!busy && (form.scheme = scheme)">{{ scheme.toUpperCase() }}</view>
			</view>
			<view class="ports">
				<view><text class="label">商城端口</text><input v-model="form.apiPort" type="number" :disabled="busy" /></view>
				<view><text class="label">图片端口</text><input v-model="form.imagePort" type="number" :disabled="busy" /></view>
			</view>
		</view>
		<view class="preview">
			<view class="preview-title">即将连接</view>
			<view class="service"><text>商城接口</text><text :class="{ healthy: status.api === '连接正常' }">{{ status.api }}</text></view>
			<view class="address">{{ preview.api }}</view>
			<view class="service"><text>图片服务</text><text :class="{ healthy: status.image === '连接正常' }">{{ status.image }}</text></view>
			<view class="address">{{ preview.image }}</view>
		</view>
		<view v-if="message" class="message">{{ message }}</view>
		<button class="test-button" :disabled="busy" @click="detect">{{ busy ? '正在检测连接…' : '检测连接' }}</button>
		<button class="save-button" :disabled="busy || !proof" @click="connect">保存并连接</button>
		<view class="note">设置仅保存在这台手机。切换商城地址后需重新登录，图片端口调整保留登录。</view>
		<view v-if="saved" class="restore" @click="restore">载入已保存的配置</view>
	</view>
</template>

<script setup>
import { reactive, ref, shallowRef, computed, watch } from 'vue';
import { onLoad } from '@dcloudio/uni-app';
import { serverConnection, normalizeConnection, origins } from '@/config/serverConnection.js';
import { refreshConnectionUrls } from '@/config/app.js';

const saved = serverConnection.getConfig();
const form = reactive(saved || { host: '', scheme: 'http', apiPort: 8081, imagePort: 8080 });
const status = reactive({ api: '待检测', image: '待检测' });
const busy = ref(false);
const proof = shallowRef(null);
const message = ref('');
const preview = computed(() => {
	try { return origins(normalizeConnection(form)); } catch (_) { return { api: '填写地址后显示', image: '填写地址后显示' }; }
});
watch(form, () => { proof.value = null; status.api = status.image = '待检测'; message.value = ''; });
function restore() { if (!busy.value && saved) Object.assign(form, saved); }
async function detect() {
	proof.value = null;
	message.value = '';
	try {
		normalizeConnection(form);
		busy.value = true;
		status.api = status.image = '检测中';
		proof.value = await serverConnection.probe({ ...form }, (key, result) => { status[key] = result; });
		message.value = '两个服务均已连通，可以保存。';
	} catch (error) { message.value = error.message; }
	finally { busy.value = false; }
}
function connect() {
	try {
		serverConnection.save({ ...form }, proof.value);
		refreshConnectionUrls();
		// #ifdef APP-PLUS
		plus.runtime.restart();
		// #endif
		// #ifdef H5
		const url = new URL(location.href);
		url.pathname = '/pages/guide/index';
		url.search = '';
		url.hash = '';
		location.replace(url.href);
		// #endif
	} catch (error) { message.value = error.message; }
}
onLoad(async options => {
	if (options.edit === '1' || !saved) return;
	// #ifdef APP-PLUS
	busy.value = true;
	status.api = status.image = '检测中';
	try {
		await serverConnection.ensureReady();
		uni.reLaunch({ url: '/pages/guide/index' });
	} catch (error) { message.value = error.message; status.api = status.image = '请重新检测'; }
	finally { busy.value = false; }
	// #endif
});
</script>

<style scoped>
.connection-page { min-height: 100vh; box-sizing: border-box; padding: calc(44rpx + var(--mall-safe-top)) 44rpx calc(48rpx + var(--mall-safe-bottom)); background: #f5f6f8; color: #1e2633; }
.topline { display: flex; justify-content: space-between; align-items: center; font-size: 25rpx; font-weight: 600; }
.badge { color: #637086; font-size: 22rpx; font-weight: 400; }
.title { margin-top: 64rpx; font-size: 46rpx; font-weight: 700; letter-spacing: -1rpx; }
.description { margin: 20rpx 0 40rpx; color: #6b7482; font-size: 27rpx; line-height: 1.7; }
.form { padding: 32rpx; border-radius: 20rpx; background: white; }
.label { display: block; font-size: 25rpx; color: #626c7b; margin-bottom: 16rpx; }
input { height: 86rpx; border-bottom: 2rpx solid #e4e7ec; font-size: 34rpx; color: #1e2633; }
.host { font-size: 32rpx; }
.protocol { display: flex; gap: 16rpx; margin: 28rpx 0; }
.protocol view { padding: 14rpx 26rpx; border: 1rpx solid #dce1e8; border-radius: 8rpx; color: #6b7482; font-size: 23rpx; }
.protocol .selected { color: #254f89; background: #edf3fc; border-color: #9fb8db; }
.ports { display: flex; gap: 32rpx; }
.ports > view { flex: 1; min-width: 0; }
.preview { margin-top: 32rpx; padding: 0 4rpx; }
.preview-title { color: #8a93a2; font-size: 22rpx; margin-bottom: 22rpx; }
.service { display: flex; justify-content: space-between; gap: 14rpx; font-size: 25rpx; }
.service > text:last-child { color: #8a6c36; font-size: 22rpx; text-align: right; max-width: 70%; }
.service > text.healthy { color: #25815c; }
.address { margin: 10rpx 0 26rpx; font-size: 24rpx; color: #647084; word-break: break-all; }
.message { margin: 20rpx 0; color: #6b7482; font-size: 25rpx; line-height: 1.5; }
button { font-size: 29rpx; height: 90rpx; line-height: 90rpx; border-radius: 12rpx; margin-top: 18rpx; }
button::after { border: 0; }
.test-button { color: #254f89; background: #e7eef8; }
.save-button { color: white; background: #254f89; }
.save-button[disabled] { background: #ccd4df; color: white; }
.note { margin-top: 24rpx; color: #8a93a2; font-size: 23rpx; line-height: 1.7; }
.restore { padding-top: 28rpx; color: #254f89; font-size: 25rpx; text-align: center; }
</style>
