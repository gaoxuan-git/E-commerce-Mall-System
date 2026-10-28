<template>
	<view class="lottie-bg">
		<view v-if="invalidParams" class="invalid-params">授权参数无效，请返回重试</view>
		<view v-else id="lottie">
			<image :src="urlDomain+'/crmebimage/perset/staticImg/live-logo.gif'" rel="preload" />
		</view>
	</view>
</template>

<script setup>
	import { ref, getCurrentInstance } from 'vue'
	import { onLoad } from '@dcloudio/uni-app'
	// #ifdef H5
	import wechat from "@/libs/wechat.js";
	// #endif
	import {
		getUserInfo
	} from "@/api/user.js";

	const { proxy } = getCurrentInstance();

	const urlDomain = ref(proxy.$Cache.get("imgHost"))
	const invalidParams = ref(false)

	onLoad((option) => {
		// #ifdef H5
		const {
			code,
			state,
			back_url
		} = option;
		if (!code || !state || !back_url) {
			invalidParams.value = true;
			return;
		}
		wechat.auth(code, state)
			.then(() => {
				getUserInfo().then(res => {
					location.href = decodeURIComponent(
						decodeURIComponent(back_url)
					);
				}).catch(res => {
				});
			})
			.catch((err) => {
			});
		// #endif
		// #ifndef H5
		uni.switchTab({
			url: '/pages/index/index'
		});
		// #endif
	})
</script>

<style scoped lang="scss">
	.lottie-bg {
		position: fixed;
		left: 0;
		top: 0;
		background-color: #fff;
		width: 100%;
		height: 100%;
		z-index: 999;

		display: flex;
		align-items: center;
		justify-content: center;
	}

	#lottie {
		display: block;
		width: 100%;
		height: 100%;
		display: flex;
		align-items: center;
		justify-content: center;
		overflow: hidden;
		transform: translate3d(0, 0, 0);
		margin: auto;

		image {
			width: 200rpx;
			height: 200rpx;
		}
	}

	.invalid-params {
		padding: 0 40rpx;
		font-size: 30rpx;
		color: #666;
		text-align: center;
	}
</style>
