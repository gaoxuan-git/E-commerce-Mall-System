-- 本地环境统一：admin 8080 / front 8081 / 图片域名走 admin
USE `dexter_dianshang`;

UPDATE `eb_system_config` SET `value` = 'http://127.0.0.1:8080', `update_time` = NOW()
WHERE `name` IN ('localUploadUrl', 'site_url', 'api_url');

UPDATE `eb_system_config` SET `value` = 'http://127.0.0.1:8081', `update_time` = NOW()
WHERE `name` = 'front_api_url';
