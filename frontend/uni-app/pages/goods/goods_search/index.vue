<template>
	<view :data-theme="theme">
		<searchBox :searchValue="searchValue" :focus="focus"
			@inputChange="setValue" @searchChange="searchBut"></searchBox>
		<view class='searchGood'>
			<view class='title'>热门搜索</view>
			<view class='list acea-row'>
				<block v-for="(item,index) in hotSearchList" :key="index">
					<view class='item' @tap='setHotSearchValue(item.title)'>{{item.title}}</view>
				</block>
			</view>
			<view class='line'></view>
			<goodList :bastList="bastList" v-if="bastList.length > 0"></goodList>
			<view class='loadingicon acea-row row-center-wrapper' v-if="bastList.length > 0">
				<text class='loading iconfont icon-jiazai' :hidden='loading==false'></text>{{loadTitle}}
			</view>
		</view>
		<view class='noCommodity'>
			<view class='pictrue'  v-if="bastList.length == 0 && isbastList">
				<image :src="urlDomain+'/crmebimage/perset/staticImg/noSearch.png'"></image>
			</view>
			<recommend ref="recommendIndex" v-if="bastList.length == 0"></recommend>
		</view>
	</view>
</template>

<script setup>
import { ref, getCurrentInstance } from "vue";
import { onLoad, onShow, onReachBottom } from "@dcloudio/uni-app";
import { getSearchKeyword, getProductslist } from "@/api/store.js";
import goodList from "@/components/goodList/index.vue";
import recommend from "@/components/recommend/index.vue";
import searchBox from "@/components/searchBox.vue";
import util from "@/utils/util.js";
import Cache from "@/utils/cache.js";

const { proxy } = getCurrentInstance();
const app = getApp();
const urlDomain = ref(Cache.get("imgHost"));
const searchValue = ref("");
const focus = ref(true);
const bastList = ref([]);
const hotSearchList = ref([]);
const first = ref(0);
const limit = ref(8);
const page = ref(1);
const loading = ref(false);
const loadend = ref(false);
const loadTitle = ref("加载更多");
const isbastList = ref(false);
const theme = ref(app.globalData.theme);
const recommendIndex = ref(null);

onLoad((e) => {
	searchValue.value = e.searchVal || "";
});

onShow(() => { getRoutineHotSearch(); });

onReachBottom(() => {
	if (bastList.value.length > 0) getProductList();
	else recommendIndex.value.get_host_product();
});

function getRoutineHotSearch() {
	getSearchKeyword().then(res => { hotSearchList.value = res.data; });
}

function getProductList() {
	if (loadend.value) return;
	if (loading.value) return;
	loading.value = true;
	loadTitle.value = "";
	getProductslist({ keyword: searchValue.value, page: page.value, limit: limit.value })
		.then(res => {
			let list = res.data.list;
			let isEnd = list.length < limit.value;
			bastList.value = util.SplitArray(list, bastList.value);
			loading.value = false;
			loadend.value = isEnd;
			loadTitle.value = isEnd ? "我也是有底线的~" : "加载更多";
			page.value++;
			isbastList.value = true;
		}).catch(() => { loading.value = false; loadTitle.value = "加载更多"; });
}

function setHotSearchValue(event) {
	searchValue.value = event;
	page.value = 1;
	loadend.value = false;
	bastList.value = [];
	getProductList();
}

function setValue(event) {
	searchValue.value = event.detail.value;
}

function searchBut(e) {
	focus.value = false;
	if (typeof e?.detail?.value === "string") searchValue.value = e.detail.value;
	if (searchValue.value.length > 0) {
		page.value = 1;
		loadend.value = false;
		bastList.value = [];
		uni.showLoading({ title: "正在搜索中" });
		getProductList();
		uni.hideLoading();
	} else {
		return util.Tips({ title: "请输入要搜索的商品", icon: "none", duration: 1000, mask: true });
	}
}
</script>

<style lang="scss">
	page {
		background-color: #fff !important;
	}

	.searchGood {
		padding-bottom: var(--mall-safe-bottom);
	}

	.searchGood .title {
		font-weight: 500;
		font-family: PingFang SC, PingFang SC;
		font-size: 28rpx;
		color: #333;
		margin: 50rpx 30rpx 25rpx 30rpx;
	}

	.searchGood .list {
		padding-left: 10rpx;
	}

	.searchGood .list .item {
		font-size: 26rpx;
		color: #454545;
		padding: 0 21rpx;
		height: 60rpx;
		border-radius: 30rpx;
		line-height: 60rpx;
		border: 1rpx solid #aaa;
		margin: 0 0 20rpx 20rpx;
	}

	.searchGood .line {
		border-bottom: 1rpx solid #eee;
		margin: 20rpx 30rpx 0 30rpx;
	}
</style>
