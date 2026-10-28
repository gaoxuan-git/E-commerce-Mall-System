<template>
	<view class="login-wrapper" :data-theme="theme" :style="colorStyle">
		<view class="auth-accent auth-accent--large"></view>
		<view class="auth-accent auth-accent--small"></view>

		<view class="auth-shell">
			<view class="auth-brand">
				<view class="auth-brand__mark">电</view>
				<text class="auth-brand__name">电商网购系统</text>
			</view>

			<view class="auth-hero">
				<text class="auth-hero__title">
					{{ formItem === 1 ? "回来看看，喜欢的都在" : "第一次见，欢迎加入" }}
				</text>
				<text class="auth-hero__desc">
					{{ formItem === 1 ? "订单、收藏和会员权益会在登录后同步" : "注册后即可管理订单、收藏与会员权益" }}
				</text>
			</view>

			<view class="auth-form">
				<view class="auth-switch">
					<view
						class="auth-switch__item"
						:class="{ active: formItem === 1 }"
						@click="switchAuthMode(1)"
					>
						登录
					</view>
					<view
						class="auth-switch__item"
						:class="{ active: formItem === 2 }"
						@click="switchAuthMode(2)"
					>
						注册
					</view>
				</view>

				<view v-if="formItem === 1" class="auth-method">
					<view
						class="auth-method__item"
						:class="{ active: current === 1 }"
						@click="current = 1"
					>
						验证码登录
					</view>
					<view
						class="auth-method__item"
						:class="{ active: current === 0 }"
						@click="current = 0"
					>
						密码登录
					</view>
				</view>

				<view v-if="formItem === 1 && current === 0" class="auth-fields">
					<view class="auth-field">
						<text class="iconfont icon-shouji auth-field__icon"></text>
						<input
							v-model="account"
							class="auth-field__input"
							type="number"
							maxlength="11"
							placeholder="输入手机号码"
						/>
					</view>
					<view class="auth-field">
						<text class="iconfont icon-mima auth-field__icon"></text>
						<input
							v-model="password"
							class="auth-field__input"
							type="password"
							maxlength="18"
							placeholder="填写登录密码"
						/>
					</view>
				</view>

				<view
					v-if="formItem === 1 && (current === 1 || appLoginStatus || appleLoginStatus)"
					class="auth-fields"
				>
					<view class="auth-field">
						<text class="iconfont icon-shouji auth-field__icon"></text>
						<input
							v-model="account"
							class="auth-field__input"
							type="number"
							maxlength="11"
							placeholder="输入手机号码"
						/>
					</view>
					<view class="auth-field">
						<text class="iconfont icon-yanzhengma auth-field__icon"></text>
						<input
							v-model="captcha"
							class="auth-field__input auth-field__input--code"
							type="number"
							maxlength="6"
							placeholder="填写验证码"
						/>
						<button
							class="auth-code main_color"
							:disabled="disabled"
							:class="{ disabled }"
							@click="code"
						>
							{{ text }}
						</button>
					</view>
					<view v-if="isShowCode" class="auth-field">
						<text class="iconfont icon-yanzhengma auth-field__icon"></text>
						<input
							v-model="codeVal"
							class="auth-field__input auth-field__input--code"
							type="number"
							maxlength="6"
							placeholder="填写图形验证码"
						/>
						<view class="auth-captcha" @click="again">
							<image class="code-img" :src="codeUrl" />
						</view>
					</view>
				</view>

				<view v-if="formItem === 2" class="auth-fields">
					<view class="auth-field">
						<text class="iconfont icon-shouji auth-field__icon"></text>
						<input
							v-model="account"
							class="auth-field__input"
							type="number"
							maxlength="11"
							placeholder="输入手机号码"
						/>
					</view>
					<view class="auth-field">
						<text class="iconfont icon-yanzhengma auth-field__icon"></text>
						<input
							v-model="captcha"
							class="auth-field__input auth-field__input--code"
							type="number"
							maxlength="6"
							placeholder="填写短信验证码"
						/>
						<button
							class="auth-code main_color"
							:disabled="disabled"
							:class="{ disabled }"
							@click="code"
						>
							{{ text }}
						</button>
					</view>
					<view class="auth-field">
						<text class="iconfont icon-mima auth-field__icon"></text>
						<input
							v-model="password"
							class="auth-field__input"
							type="password"
							maxlength="18"
							placeholder="设置6-18位登录密码"
						/>
					</view>
					<view class="auth-field">
						<text class="iconfont icon-mima auth-field__icon"></text>
						<input
							v-model="confirmPassword"
							class="auth-field__input"
							type="password"
							maxlength="18"
							placeholder="再次输入登录密码"
						/>
					</view>
				</view>

				<view class="protocol">
					<checkbox-group class="protocol__group" @change="isAgree = !isAgree">
						<!-- #ifndef MP -->
						<checkbox
							class="protocol__checkbox"
							role="checkbox"
							aria-label="我已阅读并同意用户协议和隐私政策"
							:aria-checked="isAgree"
							tabindex="0"
							@keydown.space.prevent="isAgree = !isAgree"
							@keydown.enter.prevent="isAgree = !isAgree"
							:checked="isAgree"
							color="#ffffff"
							backgroundColor="#ffffff"
							activeBackgroundColor="var(--view-theme, #ff542e)"
							activeBorderColor="var(--view-theme, #ff542e)"
							iconColor="#ffffff"
						/>
						<!-- #endif -->
						<!-- #ifdef MP -->
						<checkbox class="protocol__checkbox" :checked="isAgree" color="#ffffff" />
						<!-- #endif -->
						<text class="protocol__text">
							我已阅读并同意
							<text class="font_pro" @click.stop="userAgree('userinfo')">《用户协议》</text>
							和
							<text class="font_pro" @click.stop="userAgree('userprivacyinfo')">《隐私政策》</text>
						</text>
					</checkbox-group>
				</view>

				<view v-if="formItem === 1 && current === 1" class="auth-primary" @click="loginMobile">
					登录
				</view>
				<view v-if="formItem === 1 && current === 0" class="auth-primary" @click="submit">
					登录
				</view>
				<view v-if="formItem === 2" class="auth-primary" @click="register">
					注册并登录
				</view>

				<!-- #ifdef APP-PLUS -->
				<view v-if="formItem === 1 && !appLoginStatus && !appleLoginStatus" class="appLogin">
					<view class="hds">
						<span class="line"></span>
						<p>其他方式登录</p>
						<span class="line"></span>
					</view>
					<view class="btn-wrapper">
						<view class="btn wx" @click="wxLogin">
							<span class="iconfont icon-s-weixindenglu1"></span>
						</view>
						<view v-if="current === 1" class="btn mima" @click="current = 0">
							<span class="iconfont icon-s-mimadenglu1"></span>
						</view>
						<view v-if="current === 0" class="btn yanzheng" @click="current = 1">
							<span class="iconfont icon-s-yanzhengmadenglu1"></span>
						</view>
						<view v-if="appleShow" class="btn apple-btn" @click="appleLogin">
							<view class="iconfont icon-s-pingguo"></view>
						</view>
					</view>
				</view>
				<!-- #endif -->
			</view>
		</view>

		<Verify
			ref="verify"
			:captchaType="'blockPuzzle'"
			:imgSize="verifyImageSize"
			@success="handlerOnVerSuccess"
		/>
	</view>
</template>
<script setup>
import { ref, watch } from 'vue';
import { onLoad } from '@dcloudio/uni-app';
import util from '@/utils/util.js';
import Cache from '@/utils/cache.js';
import { useAppStore } from "@/store/app.js";
import { useColor } from "@/composables/useColor.js";
import { useSendVerifyCode } from '@/composables/useSendVerifyCode.js';
import Verify from '../components/verifition/verify.vue';
import {
	loginH5,
	loginMobile as loginMobileApi,
	registerVerify,
	register as registerApi,
	getUserInfo as getUserInfoApi
} from "@/api/user.js";
import { appAuth, appleLogin as appleLoginRequest } from "@/api/public.js";
import { HTTP_REQUEST_URL } from "@/config/app.js";
import Routine from '@/libs/routine.js';
import { Debounce } from '@/utils/validate.js'
import {
	goToAgreement
} from "@/libs/order.js";

const app = getApp();
const BACK_URL = "login_back_url";
const appStore = useAppStore();
const { disabled, text, sendCode } = useSendVerifyCode();

const verify = ref(null);
const verifyViewportWidth = uni.getWindowInfo().windowWidth || 375;
const verifyImageWidth = Math.max(200, Math.floor(Math.min(310, verifyViewportWidth * 0.9 - 32)));
const verifyImageSize = {
	width: `${verifyImageWidth}px`,
	height: `${Math.round(verifyImageWidth / 2)}px`
};
const isAgree = ref(false);
const current = ref(1);
const account = ref("");
const password = ref("");
const confirmPassword = ref("");
const captcha = ref("");
const formItem = ref(1);
const type = ref("login");
const keyCode = ref("");
const codeUrl = ref("");
const codeVal = ref("");
const isShowCode = ref(false);
const platform = ref('');
const appLoginStatus = ref(false); // 微信登录强制绑定手机号码状态
const appUserInfo = ref(null); // 微信登录保存的用户信息
const appleLoginStatus = ref(false); // 苹果登录强制绑定手机号码状态
const appleUserInfo = ref(null);
const appleShow = ref(false); // 苹果登录版本必须要求ios13以上的
const theme = ref(app.globalData.theme);
const { colorStyle } = useColor();

watch(formItem, (nval) => {
	if (nval == 1) {
		type.value = 'login'
	} else {
		type.value = 'register'
	}
});

onLoad((options = {}) => {
	if (options.mode === 'register') formItem.value = 2;
	uni.getSystemInfo({
		success: function(res) {
			if (res.platform.toLowerCase() == 'ios' && res.system.split(' ')[1] >= '13') {
				appleShow.value = true
			}
		}
	});
});

//滑块验证成功后
function handlerOnVerSuccess(data) {
	verify.value.hide();
	codeSend();
}

//发送验证码
function codeSend() {
	if (!account.value) return util.Tips({ title: '请填写手机号码' });
	if (!isAgree.value) return util.Tips({ title: '请勾选用户隐私协议' });
	if (!/^1(3|4|5|7|8|9|6)\d{9}$/i.test(account.value)) return util.Tips({ title: '请输入正确的手机号码' });
	registerVerify(account.value)
		.then(res => {
			util.Tips({ title: res.message });
			sendCode();
		})
		.catch(err => {
			return util.Tips({ title: err });
		});
}

function userAgree(t) {
	goToAgreement(t)
}

function switchAuthMode(mode) {
	if (formItem.value === mode) return;
	formItem.value = mode;
	captcha.value = '';
	password.value = '';
	confirmPassword.value = '';
}

// 苹果登录
function appleLogin() {
	account.value = ''
	captcha.value = ''
	if (!isAgree.value) return util.Tips({ title: '请勾选用户隐私协议' });
	uni.showLoading({ title: '登录中' })
	uni.login({
		provider: 'apple',
		timeout: 10000,
		success(loginRes) {
			uni.getUserInfo({
				provider: 'apple',
				success: function(infoRes) {
					appleUserInfo.value = infoRes.userInfo
					appleLoginApi()
				},
				fail() {
					uni.hideLoading()
					uni.showToast({ title: '获取用户信息失败', icon: 'none', duration: 2000 })
				},
				complete() {
					uni.hideLoading()
				}
			});
		},
		fail(error) {
			uni.hideLoading()
		}
	})
}

// 苹果登录Api
function appleLoginApi() {
	appleLoginRequest({
		openId: appleUserInfo.value.openId,
		email: appleUserInfo.value.email == undefined ? '' : appleUserInfo.value.email,
		identityToken: appleUserInfo.value.identityToken || ''
	}).then((res) => {
		appStore.LOGIN({ 'token': res.data.token });
		getUserInfo(res.data);
	}).catch(error => {
		uni.hideLoading();
		uni.showModal({
			title: '提示',
			content: `错误信息${error}`,
			success: function(res) {
				if (res.confirm) {
				} else if (res.cancel) {
				}
			}
		});
	})
}

// App微信登录
const wxLogin = Debounce(function() {
	account.value = ''
	captcha.value = ''
	if (!isAgree.value) return util.Tips({ title: '请勾选用户隐私协议' });
	uni.showLoading({ title: '登录中' })
	uni.login({
		provider: 'weixin',
		success: function(loginRes) {
			// 获取用户信息
			uni.getUserInfo({
				provider: 'weixin',
				success: function(infoRes) {
					uni.hideLoading();
					appUserInfo.value = infoRes.userInfo
					appUserInfo.value.type = platform.value === 'ios' ? 'iosWx' : 'androidWx'
					wxLoginGo(appUserInfo.value)
				},
				fail() {
					uni.hideLoading();
					uni.showToast({ title: '获取用户信息失败', icon: 'none', duration: 2000 })
				},
				complete() {
					uni.hideLoading()
				}
			});
		},
		fail() {
			uni.hideLoading()
			uni.showToast({ title: '登录失败', icon: 'none', duration: 2000 })
		}
	});
})

function wxLoginGo(info) {
	appAuth(info).then(res => {
		if (res.data.type === 'register') {
			uni.navigateTo({
				url: '/pages/users/app_login/index?authKey=' + res.data.key
			})
		}
		if (res.data.type === 'login') {
			appStore.LOGIN({ 'token': res.data.token });
			getUserInfo(res.data);
		}
	}).catch(res => {
		util.Tips({ title: res });
	});
}

function again() {
	codeUrl.value =
		HTTP_REQUEST_URL +
		"/sms_captcha?" +
		"key=" +
		keyCode.value +
		Date.parse(new Date());
}

//手机号验证码登录
const loginMobile = Debounce(function() {
	if (!account.value) return util.Tips({ title: '请填写手机号码' });
	if (!/^1(3|4|5|7|8|9|6)\d{9}$/i.test(account.value)) return util.Tips({ title: '请输入正确的手机号码' });
	if (!captcha.value) return util.Tips({ title: '请填写验证码' });
	if (!/^[\w\d]+$/i.test(captcha.value)) return util.Tips({ title: '请输入正确的验证码' });
	if (!isAgree.value) return util.Tips({ title: '请勾选用户隐私协议' });
	uni.showLoading({ title: '登录中' })
	loginMobileApi({
			phone: account.value,
			captcha: captcha.value,
			spread_spid: Cache.get("spread")
		})
		.then(res => {
			let data = res.data;
			appStore.LOGIN({ 'token': res.data.token });
			uni.hideLoading();
			getUserInfo(data);
		})
		.catch(res => {
			uni.hideLoading();
			util.Tips({ title: res });
		});
})

const register = Debounce(function() {
	if (!account.value) return util.Tips({ title: '请填写手机号码' });
	if (!/^1(3|4|5|7|8|9|6)\d{9}$/i.test(account.value)) return util.Tips({ title: '请输入正确的手机号码' });
	if (!isAgree.value) return util.Tips({ title: '请勾选用户隐私协议' });
	if (!captcha.value) return util.Tips({ title: '请填写验证码' });
	if (!/^\d{6}$/.test(captcha.value)) return util.Tips({ title: '验证码必须为6位数字' });
	if (!password.value) return util.Tips({ title: '请填写密码' });
	if (!/^[A-Za-z]\w{5,17}$/.test(password.value)) {
		return util.Tips({ title: '密码须以字母开头，长度为6-18位' });
	}
	if (password.value !== confirmPassword.value) return util.Tips({ title: '两次输入的密码不一致' });
	uni.showLoading({ title: '注册中' });
	registerApi({
			account: account.value,
			captcha: captcha.value,
			password: password.value,
			spread_spid: Cache.get("spread")
		})
		.then(res => {
			const data = res.data;
			appStore.LOGIN({ token: data.token });
			uni.hideLoading();
			getUserInfo(data);
		})
		.catch(res => {
			uni.hideLoading();
			util.Tips({ title: res });
		});
})

async function code() {
	if (!account.value) return util.Tips({ title: '请填写手机号码' });
	if (!isAgree.value) return util.Tips({ title: '请勾选用户隐私协议' });
	if (!/^1(3|4|5|7|8|9|6)\d{9}$/i.test(account.value)) return util.Tips({ title: '请输入正确的手机号码' });
	if (formItem.value == 2) type.value = "register";
	verify.value.show();
}

//账号密码登录
const submit = Debounce(function() {
	if (!account.value) return util.Tips({ title: '请填写账号' });
	if (!/^[\w\d]{5,16}$/i.test(account.value)) return util.Tips({ title: '请输入正确的账号' });
	if (!password.value) return util.Tips({ title: '请填写密码' });
	if (!isAgree.value) return util.Tips({ title: '请勾选用户隐私协议' });
	uni.showLoading({ title: '登录中' })
	loginH5({
			account: account.value,
			password: password.value,
			spread_spid: Cache.get("spread")
		}).then(({ data }) => {
			appStore.LOGIN({ 'token': data.token });
			uni.hideLoading();
			getUserInfo(data);
		})
		.catch(e => {
			uni.hideLoading();
			util.Tips({ title: e });
		});
})

function getUserInfo(data) {
	appStore.SETUID(data.uid);
	getUserInfoApi().then(res => {
		appStore.UPDATE_USERINFO(res.data);
		let backUrl = Cache.get(BACK_URL) || "/pages/index/index";
		if (backUrl.indexOf('/pages/users/login/index') !== -1) {
			backUrl = '/pages/index/index';
		}
		uni.reLaunch({ url: backUrl });
	})
}
</script>
<style lang="scss" scoped>
	page {
		min-height: 100%;
		background: #fff8f4;
	}

	.login-wrapper {
		position: relative;
		min-height: 100vh;
		padding:
			calc(env(safe-area-inset-top) + 34rpx)
			40rpx
			calc(env(safe-area-inset-bottom) + 48rpx);
		overflow: hidden;
		box-sizing: border-box;
		background: #fff8f4;
		color: #2e2927;
		font-family: "PingFang SC", "HarmonyOS Sans SC", sans-serif;
		letter-spacing: 0;
	}

	.auth-shell {
		position: relative;
		z-index: 2;
		width: 100%;
		max-width: 670rpx;
		margin: 0 auto;
	}

	.auth-accent {
		position: absolute;
		pointer-events: none;
		background: #ffd7c9;

		&--large {
			top: -90rpx;
			right: -104rpx;
			width: 330rpx;
			height: 270rpx;
			border-radius: 56rpx;
			transform: rotate(24deg);
		}

		&--small {
			top: 210rpx;
			right: 72rpx;
			width: 112rpx;
			height: 112rpx;
			border-radius: 28rpx;
			background: var(--view-theme, #ff542e);
			box-shadow: 0 24rpx 54rpx rgba(255, 84, 46, 0.2);
			transform: rotate(12deg);
		}
	}

	.auth-brand {
		display: flex;
		align-items: center;
		gap: 18rpx;
		height: 64rpx;
		animation: auth-rise 0.45s ease-out both;

		&__mark {
			width: 56rpx;
			height: 56rpx;
			border-radius: 14rpx;
			color: #fff;
			background: #2e2927;
			font-size: 24rpx;
			line-height: 56rpx;
			font-weight: 600;
			text-align: center;
		}

		&__name {
			font-size: 28rpx;
			line-height: 40rpx;
			font-weight: 600;
		}
	}

	.auth-hero {
		min-height: 300rpx;
		padding-top: 72rpx;
		animation: auth-rise 0.5s 0.06s ease-out both;

		&__title {
			display: block;
			width: 430rpx;
			font-size: 58rpx;
			line-height: 76rpx;
			font-weight: 700;
			letter-spacing: 0;
		}

		&__desc {
			display: block;
			width: 430rpx;
			margin-top: 18rpx;
			color: #8c746c;
			font-size: 24rpx;
			line-height: 38rpx;
			letter-spacing: 0;
		}
	}

	.auth-form {
		position: relative;
		padding-top: 18rpx;
		animation: auth-rise 0.55s 0.12s ease-out both;
	}

	.auth-switch {
		display: flex;
		width: 320rpx;
		height: 76rpx;
		border-bottom: 1rpx solid #eddcd5;

		&__item {
			position: relative;
			width: 160rpx;
			color: #9a847d;
			font-size: 28rpx;
			line-height: 76rpx;
			text-align: center;

			&.active {
				color: #2e2927;
				font-weight: 600;

				&::after {
					content: "";
					position: absolute;
					right: 36rpx;
					bottom: -1rpx;
					left: 36rpx;
					height: 4rpx;
					background: var(--view-theme, #ff542e);
				}
			}
		}
	}

	.auth-method {
		display: flex;
		align-items: center;
		gap: 34rpx;
		height: 70rpx;

		&__item {
			color: #a18f88;
			font-size: 24rpx;
			line-height: 34rpx;

			&.active {
				color: var(--view-theme, #ff542e);
				font-weight: 600;
			}
		}
	}

	.auth-fields {
		display: flex;
		flex-direction: column;
		gap: 20rpx;
	}

	.auth-field {
		display: flex;
		align-items: center;
		width: 100%;
		height: 96rpx;
		padding: 0 28rpx;
		border: 1rpx solid #f0dfd8;
		border-radius: 16rpx;
		box-sizing: border-box;
		background: rgba(255, 255, 255, 0.78);
		transition: border-color 0.2s ease, box-shadow 0.2s ease;

		&:focus-within {
			border-color: var(--view-theme, #ff542e);
			box-shadow: 0 0 0 4rpx rgba(255, 84, 46, 0.08);
		}

		&__icon {
			flex: 0 0 38rpx;
			color: #8c746c;
			font-size: 30rpx;
			text-align: center;
		}

		&__input {
			flex: 1;
			min-width: 0;
			height: 92rpx;
			margin-left: 18rpx;
			color: #2e2927;
			font-size: 28rpx;
			line-height: 92rpx;

			&--code {
				padding-right: 8rpx;
			}
		}
	}

	::v-deep .uni-input-placeholder {
		color: #b3a39d;
	}

	.auth-code {
		flex: 0 0 auto;
		min-width: 160rpx;
		height: 64rpx;
		margin: 0;
		padding: 0 12rpx;
		border: 0;
		color: var(--view-theme, #ff542e);
		background: transparent;
		font-size: 24rpx;
		line-height: 64rpx;

		&::after {
			border: 0;
		}

		&.disabled {
			color: #bcaea8;
		}
	}

	.auth-captcha {
		flex: 0 0 166rpx;
		height: 64rpx;
		overflow: hidden;
		border-radius: 8rpx;
	}

	.code-img {
		width: 100%;
		height: 100%;
	}

	.protocol {
		margin-top: 28rpx;

		&__group {
			display: flex;
			align-items: flex-start;
		}

		&__checkbox {
			flex: 0 0 auto;
			transform: scale(0.82);
			transform-origin: left top;
		}

		&__text {
			flex: 1;
			margin-left: 4rpx;
			color: #9a8982;
			font-size: 22rpx;
			line-height: 36rpx;
		}

		.font_pro {
			color: var(--view-theme, #ff542e);
		}

		::v-deep .uni-checkbox-input.uni-checkbox-input-checked,
		::v-deep checkbox .wx-checkbox-input.wx-checkbox-input-checked {
			border: 0 !important;
			color: #fff !important;
			background: var(--view-theme, #ff542e) !important;
		}
	}

	.auth-primary {
		width: 100%;
		height: 96rpx;
		margin-top: 34rpx;
		border-radius: 48rpx;
		color: #fff;
		background: #2e2927;
		box-shadow: 0 24rpx 44rpx rgba(46, 41, 39, 0.16);
		font-size: 30rpx;
		line-height: 96rpx;
		font-weight: 600;
		text-align: center;
		transition: opacity 0.15s ease, transform 0.15s ease;

		&:active {
			opacity: 0.88;
			transform: translateY(1rpx);
		}
	}

	.appLogin {
		margin-top: 54rpx;

		.hds {
			display: flex;
			align-items: center;
			justify-content: center;
			color: #aa9c96;
			font-size: 22rpx;

			.line {
				width: 68rpx;
				height: 1rpx;
				background: #e5d7d1;
			}

			p {
				margin: 0 20rpx;
			}
		}

		.btn-wrapper {
			display: flex;
			align-items: center;
			justify-content: center;
			margin-top: 30rpx;
		}

		.btn {
			display: flex;
			align-items: center;
			justify-content: center;
			width: 72rpx;
			height: 72rpx;
			margin: 0 14rpx;
			border-radius: 50%;

			&.wx {
				background: #61c64f;
			}

			&.mima {
				background: #2e2927;
			}

			&.yanzheng {
				background: var(--view-theme, #ff542e);
			}

			&.apple-btn {
				background: #000;
			}
		}

		.iconfont {
			color: #fff;
			font-size: 40rpx;
		}
	}

	.main_color {
		color: var(--view-theme, #ff542e);
	}

	@keyframes auth-rise {
		from {
			opacity: 0;
			transform: translateY(18rpx);
		}

		to {
			opacity: 1;
			transform: translateY(0);
		}
	}

	@media screen and (max-width: 360px) {
		.auth-hero__title,
		.auth-hero__desc {
			width: 400rpx;
		}

		.auth-hero__title {
			font-size: 52rpx;
			line-height: 68rpx;
		}
	}

	@media (prefers-reduced-motion: reduce) {
		.auth-brand,
		.auth-hero,
		.auth-form {
			animation: none;
		}
	}
</style>
