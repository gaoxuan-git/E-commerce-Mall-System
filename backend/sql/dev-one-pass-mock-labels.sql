START TRANSACTION;

UPDATE eb_system_menu
SET name = '本地服务'
WHERE component = '/operation/onePassConfig'
  AND name = '一号通配置';

UPDATE eb_category
SET name = '本地模拟服务',
    url = '本地模拟服务'
WHERE id = 836
  AND type = 6;

UPDATE eb_system_form_temp
SET name = '本地模拟服务',
    info = '本地模拟服务'
WHERE id = 173;

UPDATE eb_system_form_temp
SET content = REPLACE(content, '"label":"一号通"', '"label":"本地模拟"')
WHERE id IN (175, 176);

COMMIT;
