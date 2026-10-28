// +----------------------------------------------------------------------
// | CRMEB [ CRMEB赋能开发者，助力企业发展 ]
// +----------------------------------------------------------------------
// | Copyright (c) 2016~2026 https://www.crmeb.com All rights reserved.
// +----------------------------------------------------------------------
// | Licensed CRMEB并不是自由软件，未经许可不能去掉CRMEB相关版权
// +----------------------------------------------------------------------
// | Author: CRMEB Team <admin@crmeb.com>
// +----------------------------------------------------------------------

// 本地开发：商城 API = crmeb-front；管理端 = 8080
import { serverConnection } from './serverConnection.js';
export let HTTP_REQUEST_URL = serverConnection.api();

export let HTTP_H5_URL = serverConnection.api();

export function refreshConnectionUrls() {
	HTTP_REQUEST_URL = serverConnection.api();
	HTTP_H5_URL = serverConnection.api();
}

export const HEADER = {
	'content-type': 'application/json',
	'X-Source': 'df07addc462f7f8f'
};
export const HEADERPARAMS = {
	'content-type': 'application/x-www-form-urlencoded'
};
// 回话密钥名称 请勿修改此配置
export const TOKENNAME = 'Authorization';
// 缓存时间 0 永久
export const EXPIRE = 0;
// 用户 token 本地有效期（秒），与后端 JWT_FRONT_EXPIRE_MINUTES=7天保持一致
export const TOKEN_EXPIRE_SECONDS = 60 * 60 * 24 * 7;
//分页最多显示条数
export const LIMIT = 10;

export default {
	get HTTP_REQUEST_URL() { return HTTP_REQUEST_URL; },
	get HTTP_H5_URL() { return HTTP_H5_URL; },
	HEADER,
	HEADERPARAMS,
	TOKENNAME,
	EXPIRE,
	TOKEN_EXPIRE_SECONDS,
	LIMIT
};
