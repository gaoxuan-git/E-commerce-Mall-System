<template>
	<view v-if="show" class="pay-simulator">
		<view class="pay-simulator__header">
			<view class="close" @click="onClose">
				<text class="iconfont icon-guanbi"></text>
			</view>
			<view class="title">收银台</view>
			<view class="placeholder"></view>
		</view>

		<view class="pay-simulator__content">
			<view class="merchant">{{ merchant || '电商网购系统' }}</view>
			<view class="amount">
				<text class="symbol">￥</text>
				<text class="number">{{ formatAmount }}</text>
			</view>
			<view class="method-card">
				<view class="method-icon" :class="payType === 'alipay' ? 'alipay' : 'weixin'">
					<text class="iconfont" :class="payIcon"></text>
				</view>
				<view class="method-info">
					<view class="method-name">{{ payName }}</view>
					<view class="method-tip">模拟支付，不会产生真实扣款</view>
				</view>
				<view class="method-check">
					<text class="iconfont icon-xuanzhong1"></text>
				</view>
			</view>
			<view class="notice">演示环境：点击确认后直接完成支付，不调用微信/支付宝接口</view>
		</view>

		<view class="pay-simulator__footer">
			<button class="confirm-btn" :class="payType === 'alipay' ? 'alipay' : 'weixin'"
				:loading="loading" :disabled="loading" @click="onConfirm">
				确认支付 ￥{{ formatAmount }}
			</button>
			<view class="cancel" @click="onClose">取消支付</view>
		</view>
	</view>
</template>

<script setup>
import { computed } from 'vue';

const props = defineProps({
	show: { type: Boolean, default: false },
	amount: { type: [String, Number], default: '0.00' },
	payType: { type: String, default: 'weixin' },
	payName: { type: String, default: '微信支付' },
	payIcon: { type: String, default: 'icon-weixin2' },
	merchant: { type: String, default: '' },
	loading: { type: Boolean, default: false }
});

const emit = defineEmits(['confirm', 'close']);

const formatAmount = computed(() => {
	const value = Number(props.amount);
	if (Number.isNaN(value)) return '0.00';
	return value.toFixed(2);
});

function onConfirm() {
	if (props.loading) return;
	emit('confirm');
}

function onClose() {
	if (props.loading) return;
	emit('close');
}
</script>

<style scoped lang="scss">
.pay-simulator {
	position: fixed;
	left: 0;
	right: 0;
	top: 0;
	bottom: 0;
	z-index: 9999;
	background-color: #f5f6f8;
	display: flex;
	flex-direction: column;
}

.pay-simulator__header {
	height: 96rpx;
	display: flex;
	align-items: center;
	justify-content: space-between;
	padding: 0 30rpx;
	background-color: #fff;
	border-bottom: 1rpx solid #eee;

	.title {
		font-size: 34rpx;
		font-weight: bold;
		color: #282828;
	}

	.close,
	.placeholder {
		width: 60rpx;
		height: 60rpx;
		line-height: 60rpx;
	}

	.close .iconfont {
		font-size: 38rpx;
		color: #8a8a8a;
	}
}

.pay-simulator__content {
	flex: 1;
	padding: 70rpx 40rpx 0;

	.merchant {
		text-align: center;
		font-size: 28rpx;
		color: #666;
	}

	.amount {
		margin-top: 24rpx;
		text-align: center;
		color: #282828;

		.symbol {
			font-size: 40rpx;
			font-weight: bold;
		}

		.number {
			font-size: 88rpx;
			font-weight: bold;
			margin-left: 6rpx;
		}
	}

	.method-card {
		margin-top: 70rpx;
		background-color: #fff;
		border-radius: 20rpx;
		padding: 30rpx;
		display: flex;
		align-items: center;

		.method-icon {
			width: 76rpx;
			height: 76rpx;
			border-radius: 50%;
			display: flex;
			align-items: center;
			justify-content: center;

			.iconfont {
				font-size: 44rpx;
				color: #fff;
			}

			&.weixin {
				background-color: #41b035;
			}

			&.alipay {
				background-color: #00aaea;
			}
		}

		.method-info {
			flex: 1;
			margin-left: 24rpx;

			.method-name {
				font-size: 32rpx;
				color: #282828;
				font-weight: bold;
			}

			.method-tip {
				margin-top: 8rpx;
				font-size: 24rpx;
				color: #999;
			}
		}

		.method-check .iconfont {
			font-size: 40rpx;
			color: #07c160;
		}
	}

	.notice {
		margin-top: 30rpx;
		text-align: center;
		font-size: 24rpx;
		color: #b0b0b0;
		line-height: 36rpx;
	}
}

.pay-simulator__footer {
	padding: 0 40rpx 80rpx;
	display: flex;
	flex-direction: column;
	align-items: center;

	.confirm-btn {
		width: 100%;
		height: 92rpx;
		line-height: 92rpx;
		border-radius: 46rpx;
		font-size: 32rpx;
		font-weight: bold;
		color: #fff;

		&.weixin {
			background-color: #07c160;
		}

		&.alipay {
			background-color: #1677ff;
		}

		&[disabled] {
			opacity: 0.7;
		}
	}

	.cancel {
		margin-top: 30rpx;
		font-size: 28rpx;
		color: #888;
	}
}
</style>
