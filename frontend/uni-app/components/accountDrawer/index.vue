<template>
	<tui-drawer :visible="visible" mode="left" :z-index="1001" :mask-z-index="1000" @close="emit('close')">
		<view class="account-drawer">
			<view class="drawer-head">
				<view class="drawer-title">账户</view>
				<view class="close-button iconfont icon-guanbi" title="关闭" @click="emit('close')"></view>
			</view>

			<view v-if="isLogin" class="account-summary">
				<image class="avatar" :src="avatar" mode="aspectFill"></image>
				<view class="account-copy">
					<view class="account-name line1">{{ displayName }}</view>
					<view class="account-phone">{{ maskedPhone }}</view>
				</view>
			</view>
			<view v-else class="guest-summary">
				<view class="guest-icon iconfont icon-yonghu"></view>
				<view>
					<view class="account-name">访客</view>
					<view class="account-phone">登录后查看订单与资产</view>
				</view>
			</view>

			<view class="drawer-actions">
				<!-- #ifdef APP-PLUS || H5 -->
				<view class="drawer-action" @click="openConnection">
					<text class="iconfont icon-shezhi"></text>
					<text>服务器连接设置</text>
					<text class="iconfont icon-xiangyou action-arrow"></text>
				</view>
				<!-- #endif -->
				<template v-if="isLogin">
					<view class="drawer-action" @click="emit('profile')">
						<text class="iconfont icon-yonghu-xianxing"></text>
						<text>个人资料</text>
						<text class="iconfont icon-xiangyou action-arrow"></text>
					</view>
					<view class="drawer-action" @click="emit('switch-account')">
						<text class="iconfont icon-zhanghao"></text>
						<text>切换账号</text>
						<text class="iconfont icon-xiangyou action-arrow"></text>
					</view>
					<view class="drawer-action drawer-action--danger" @click="emit('logout')">
						<text class="iconfont icon-tuichu"></text>
						<text>退出登录</text>
					</view>
				</template>
				<template v-else>
					<button class="primary-action" @click="emit('login', 'login')">登录</button>
					<button class="secondary-action" @click="emit('login', 'register')">注册新账号</button>
				</template>
			</view>
		</view>
	</tui-drawer>
</template>

<script setup>
import { computed } from 'vue';
import tuiDrawer from '@/components/tuiDrawer/tui-drawer.vue';

const props = defineProps({
	visible: {
		type: Boolean,
		default: false
	},
	isLogin: {
		type: Boolean,
		default: false
	},
	userInfo: {
		type: Object,
		default: () => ({})
	}
});

const emit = defineEmits(['close', 'login', 'profile', 'switch-account', 'logout']);
function openConnection() {
	emit('close');
	uni.navigateTo({ url: '/pages/server_connection/index?edit=1' });
}
const avatar = computed(() => props.userInfo?.avatar || '/static/images/f.png');
const displayName = computed(() => props.userInfo?.nickname || props.userInfo?.phone || '商城用户');
const maskedPhone = computed(() => {
	const phone = props.userInfo?.phone || '';
	return /^1\d{10}$/.test(phone) ? phone.replace(/^(\d{3})\d{4}(\d{4})$/, '$1****$2') : '已登录';
});
</script>

<style lang="scss" scoped>
.account-drawer {
	width: 560rpx;
	max-width: 85vw;
	min-height: 100%;
	padding-top: var(--mall-safe-top);
	padding-right: 32rpx;
	padding-bottom: calc(40rpx + env(safe-area-inset-bottom));
	padding-left: 32rpx;
	background: #fff;
	box-sizing: border-box;
	max-height: 100vh;
	overflow-y: auto;
}

.drawer-head {
	display: flex;
	align-items: center;
	justify-content: space-between;
	height: 96rpx;
	border-bottom: 1rpx solid #ededed;
}

.drawer-title {
	color: #222;
	font-size: 34rpx;
	font-weight: 600;
}

.close-button {
	display: flex;
	align-items: center;
	justify-content: center;
	width: 64rpx;
	height: 64rpx;
	color: #555;
	font-size: 28rpx;
}

.account-summary,
.guest-summary {
	display: flex;
	align-items: center;
	min-height: 176rpx;
	border-bottom: 1rpx solid #ededed;
}

.avatar,
.guest-icon {
	flex: none;
	width: 92rpx;
	height: 92rpx;
	margin-right: 24rpx;
	border-radius: 50%;
}

.guest-icon {
	display: flex;
	align-items: center;
	justify-content: center;
	background: #f1f2f4;
	color: #666;
	font-size: 44rpx;
}

.account-copy {
	min-width: 0;
}

.account-name {
	max-width: 340rpx;
	color: #222;
	font-size: 30rpx;
	font-weight: 600;
}

.account-phone {
	margin-top: 10rpx;
	color: #8a8a8a;
	font-size: 24rpx;
}

.drawer-actions {
	padding-top: 24rpx;
}

.drawer-action {
	display: grid;
	grid-template-columns: 52rpx 1fr 32rpx;
	align-items: center;
	min-height: 92rpx;
	border-bottom: 1rpx solid #f0f0f0;
	color: #333;
	font-size: 28rpx;
}

.drawer-action .iconfont {
	font-size: 32rpx;
}

.drawer-action .action-arrow {
	color: #aaa;
	font-size: 26rpx;
}

.drawer-action--danger {
	grid-template-columns: 52rpx 1fr;
	margin-top: 20rpx;
	border-bottom: 0;
	color: #d74343;
}

.primary-action,
.secondary-action {
	width: 100%;
	height: 84rpx;
	margin: 16rpx 0 0;
	border-radius: 8rpx;
	font-size: 28rpx;
	line-height: 84rpx;
}

.primary-action {
	background: var(--view-theme, #e93323);
	color: #fff;
}

.secondary-action {
	border: 1rpx solid #d9d9d9;
	background: #fff;
	color: #333;
}

button::after {
	border: 0;
}
</style>
