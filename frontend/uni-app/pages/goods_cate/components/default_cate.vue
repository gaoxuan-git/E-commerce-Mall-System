<template>
	<view :data-theme="theme">
		<view class='productSort'>
			<skeleton :show="showSkeleton" :isNodes="isNodes" ref="skeleton" loading="chiaroscuro" selector="skeleton"
				bgcolor="#FFF"></skeleton>
			<view class="skeleton" :style="{visibility: showSkeleton ? 'hidden' : 'visible'}">
				<view class='header acea-row row-center-wrapper'>
					<view class='acea-row row-between-wrapper input'>
						<text class='iconfont icon-sousuo'></text>
						<input type='text' placeholder='点击搜索商品信息' @confirm="searchSubmitValue" confirm-type='search' name="search"
						 placeholder-class='placeholder' maxlength="20"></input>
					</view>
				</view>
			<view class='aside'>
				<scroll-view scroll-y="true" scroll-with-animation='true' style="height: 100%;">
						<view class='item acea-row row-center-wrapper' :class='index==navActive?"on":""' v-for="(item,index) in productList"
					 :key="index" @click='tap(index,"b"+index)'><text class="skeleton-rect">{{item.name}}</text></view>
					 </scroll-view>
					
				</view>
				<view class='conter'>
					<scroll-view scroll-y="true" :scroll-into-view="toView" style="height: 100%;" @scroll="scroll"
					 scroll-with-animation='true'>
						<block v-for="(item,index) in productList" :key="index">
							<view class='listw' :id="'b'+index">
								<view class='title acea-row row-center-wrapper'>
									<view class='line'></view>
									<view class='name'>{{item.name}}</view>
									<view class='line'></view>
								</view>
								<view class='list acea-row'>
									<block v-for="(itemn,indexn) in item.child" :key="indexn">
										<navigator :render-link="false" hover-class='none' :url='"/pages/goods/goods_list/index?cid="+itemn.id+"&title="+itemn.name' class='item acea-row row-column row-middle'>
											<view class='picture skeleton-rect' :style="{'background-color':itemn.extra?'none':'#f7f7f7'}">
												<image :src='itemn.extra'></image>
											</view>
											<view class='name line1'>{{itemn.name}}</view>
										</navigator>
									</block>
								</view>
							</view>
						</block>
						<view :style='"height:"+(height-300)+"rpx;"' v-if="number<15"></view>
					</scroll-view>
				</view>
			</view>
		</view>	
	</view>
</template>

<script setup>
	import { ref, watch, getCurrentInstance } from 'vue';
	import { onShow, onResize } from '@dcloudio/uni-app';
	import { getCategoryList } from '@/api/store.js';
	import util from '@/utils/util.js';
	import animationType from '@/utils/animationType.js'

	const { proxy } = getCurrentInstance();
	const props = defineProps({ footerHeight: { type: Number, default: 50 } });

	const showSkeleton = ref(true); //骨架屏显示隐藏
	const isNodes = ref(0); //控制什么时候开始抓取元素节点,只要数值改变就重新抓取
	const navlist = ref([]);
	const productList = ref([{name:'占位占位',child:[{extra:''},{extra:''}]},{name:'占位占位',child:[{extra:''},{extra:''}]},{name:'占位占位',child:[{extra:''},{extra:''}]},{name:'占位占位'}]);
	const navActive = ref(0);
	const number = ref("");
	const height = ref(0);
	const hightArr = ref([]);
	const toView = ref("");
	const theme = ref('theme1');

	// created
	uni.getStorage({
		key: 'theme',
		success: function(res) {
			theme.value = res.data;
		}
	});
	setTimeout(() => {
		isNodes.value++;
	}, 500);
	getAllCategory();

	onShow(() => {
		getAllCategory();
	});
	onResize(updateScrollHeight);
	watch(() => props.footerHeight, updateScrollHeight);

	function updateScrollHeight() {
		const info = uni.getWindowInfo();
		const scale = 750 / info.windowWidth;
		const bottom = info.safeAreaInsets?.bottom || 0;
		height.value = Math.max(0,
			(info.windowHeight - (info.statusBarHeight || 0) - props.footerHeight - bottom) * scale - 96);
	}

	function infoScroll() {
		let len = productList.value.length;
		let child = productList.value[len - 1] && productList.value[len - 1].child ? productList.value[len - 1].child : [];
		number.value = child ? child.length : 0;

		//设置商品列表高度
		updateScrollHeight();
		let len2 = len;
		let arr = [];
		for (let i = 0; i < len2; i++) {
			//获取元素所在位置
			let query = uni.createSelectorQuery().in(proxy);
			let idView = "#b" + i;
			query.select(idView).boundingClientRect();
			query.exec(function(res) {
				let top = res[0] ? res[0].top : 0;
				arr.push(top);
				hightArr.value = arr
			});
		}
	}
	function tap(index, id) {
		toView.value = id;
		navActive.value = index;
	}
	function getAllCategory() {
		getCategoryList().then(res => {
			productList.value = res.data;
			let pid = uni.getStorageSync('categoryId');
			if (pid) {
				let indexNow = productList.value.findIndex(item => item.id == pid)
				tap(indexNow, 'b' + indexNow)
			}
			setTimeout(function() {
				infoScroll();
			}, 500)
			setTimeout(() => {
				showSkeleton.value = false
			}, 1000)
		})
	}
	function scroll(e) {
		let scrollTop = e.detail.scrollTop + 10;
		let scrollArr = hightArr.value;
		for (let i = 0; i < scrollArr.length; i++) {
			if (scrollTop >= 0 && scrollTop < scrollArr[1] - scrollArr[0]) {
				navActive.value = 0
			} else if (scrollTop >= scrollArr[i] - scrollArr[0] && scrollTop < scrollArr[i + 1] - scrollArr[0]) {
				navActive.value = i
			} else if (scrollTop >= scrollArr[scrollArr.length - 1] - scrollArr[0]) {
				navActive.value = scrollArr.length - 1
			}
		}
	}
	function searchSubmitValue(e) {
		if (util.trim(e.detail.value).length > 0)
			uni.navigateTo({
				animationType: animationType.type,
				animationDuration: animationType.duration,
				url: '/pages/goods/goods_list/index?searchValue=' + e.detail.value
			})
		else
			return util.Tips({
				title: '请填写要搜索的产品信息'
			});
	}
</script>

<style scoped lang="scss">
	.productSort .header {
		width: 100%;
		height: calc(96rpx + var(--mall-safe-top));
		padding-top: var(--mall-safe-top);
		background-color: #fff;
		position: fixed;
		left: 0;
		right: 0;
		top: var(--mall-window-top);
		z-index: 9;
		border-bottom: 1rpx solid #f5f5f5;
	}
	
	.productSort .header .input {
		width: calc(100% - 48rpx);
		flex-wrap: nowrap;
		height: 60rpx;
		background-color: #f5f5f5;
		border-radius: 50rpx;
		box-sizing: border-box;
		padding: 0 25rpx;
	}
	
	.productSort .header .input .iconfont {
		font-size: 26rpx;
		color: #555;
	}
	
	.productSort .header .input .placeholder {
		color: #999;
	}
	
	.productSort .header .input input {
		font-size: 26rpx;
		height: 100%;
		flex: 1;
		min-width: 0;
		width: 0;
		margin-left: 14rpx;
	}
	
	.productSort .aside {
		position: fixed;
		width: 180rpx;
		left: 0;
		top: calc(var(--mall-custom-top) + 96rpx);
		bottom: calc(var(--mall-category-footer) + var(--mall-safe-bottom));
		background-color: #f7f7f7;
		overflow: hidden;
	}
	
	.productSort .aside .item {
		height: 100rpx;
		width: 100%;
		font-size: 26rpx;
		color: #424242;
		position: relative;
	}
	.productSort .aside .item.on {
		background-color: #fff;
		width: 100%;
		text-align: center;
		@include main_color(theme);
		font-weight: bold;
	}
	.productSort .aside .item.on ::before{
		content: '';
		width: 4rpx;
		height: 100rpx;
		position: absolute;
		left: 0;
		top: 0;
		@include main_bg_color(theme);
	}
	
	.productSort .conter {
		position: fixed;
		top: calc(var(--mall-custom-top) + 96rpx);
		bottom: calc(var(--mall-category-footer) + var(--mall-safe-bottom));
		left: 180rpx;
		right: 0;
		padding: 0 14rpx;
		background-color: #fff;
	}
	
	.productSort .conter .listw {
		padding-top: 20rpx;
	}
	
	.productSort .conter .listw .title {
		height: 90rpx;
	}
	
	.productSort .conter .listw .title .line {
		width: 100rpx;
		height: 2rpx;
		background-color: #f0f0f0;
	}
	
	.productSort .conter .listw .title .name {
		font-size: 28rpx;
		color: #333;
		margin: 0 30rpx;
		font-weight: bold;
	}
	
	.productSort .conter .list {
		flex-wrap: wrap;
	}
	
	.productSort .conter .list .item {
		width: 177rpx;
		margin-top: 26rpx;
	}
	
	.productSort .conter .list .item .picture {
		width: 120rpx;
		height: 120rpx;
		border-radius: 50%;
	}
	
	.productSort .conter .list .item .picture image {
		width: 100%;
		height: 100%;
		border-radius: 50%;
		div{
			background-color: #f7f7f7;
		}
	}
	
	.productSort .conter .list .item .name {
		font-size: 24rpx;
		color: #333;
		height: 56rpx;
		line-height: 56rpx;
		width: 120rpx;
		text-align: center;
	}
</style>
