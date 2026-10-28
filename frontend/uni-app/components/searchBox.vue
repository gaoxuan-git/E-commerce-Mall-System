<template>
	<view class="mobile-search-header" :style="headerStyle">
		<view class="search-contain">
			<view class="search-back" @click="toBack" v-if="toBackShow" aria-label="返回">
				<text class="iconfont icon-fanhui2"></text>
			</view>
			<view class="search-box">
				<text class="iconfont icon-sousuo2"></text>
				<input :value="searchValue" :focus="focus" @input="inputValue" @confirm="inputSearch"
					type="text" confirm-type="search" name="search" placeholder="点击搜索商品"
					placeholder-class="placeholder" maxlength="20"></input>
			</view>
			<view class="search-submit" @tap="submitSearch">搜索</view>
		</view>
	</view>
</template>

<script setup>
	import { ref } from 'vue';

	const props = defineProps({
		//是否展示返回按钮
		toBackShow: {
			type: Boolean,
			default: true
		},
		searchValue:{
			type: String,
			default: ''
		},
		focus: {
			type: Boolean,
			default: false
		}
	});

	const emit = defineEmits(['searchChange', 'inputChange']);
	const headerStyle = ref({});

	// 小程序预留右侧胶囊；App / H5 不调用小程序专用 API。
	// #ifdef MP
	const menu = uni.getMenuButtonBoundingClientRect?.();
	if (menu && menu.width > 0) {
		const info = uni.getWindowInfo();
		headerStyle.value = {
			paddingTop: Math.max(info.statusBarHeight || 0, menu.top - (44 - menu.height) / 2) + 'px',
			paddingRight: Math.max(12, info.windowWidth - menu.left + 8) + 'px'
		}
	}
	// #endif

	function inputSearch(e){
		emit('searchChange', e)
	}
	function inputValue(e) {
		emit('inputChange', e)
	}
	function submitSearch() {
		emit('searchChange', { detail: { value: props.searchValue } })
	}
	function toBack(){
		if (getCurrentPages().length > 1) uni.navigateBack();
		else uni.switchTab({ url: '/pages/index/index' });
	}
</script>

<style scoped lang="scss">
	.mobile-search-header {
		position: sticky;
		top: var(--mall-window-top);
		z-index: 99;
		padding: calc(var(--mall-safe-top) + 12rpx) 24rpx 12rpx;
		background: #fff;
		border-bottom: 1rpx solid #f0f0f0;
	}
	.search-contain{
		display: flex;
		align-items: center;
		flex-wrap: nowrap;
		gap: 16rpx;
		min-height: 44px;
	}
	.search-box {
		display: flex;
		align-items: center;
		flex: 1;
		min-width: 0;
		background-color: #f7f7f7;
		border-radius: 33rpx;
		padding: 0 24rpx;
		box-sizing: border-box;
		height: 66rpx;
		min-height: 36px;
	}
	.search-back,
	.search-submit {
		display: flex;
		align-items: center;
		justify-content: center;
		flex-shrink: 0;
		min-width: 44px;
		min-height: 44px;
		color: #282828;
		font-size: 28rpx;
	}
	.search-back .iconfont {
		font-size: 36rpx;
	}
	.search-box input {
		flex: 1;
		min-width: 0;
		width: 0;
		height: 100%;
		margin-left: 12rpx;
		font-size: 26rpx;
	}

	.search-box .placeholder {
		color: #bbb;
	}

	.search-box .iconfont {
		color: #000;
		font-size: 35rpx;
		flex-shrink: 0;
	}
</style>
