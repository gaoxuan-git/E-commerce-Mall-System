-- CRMEB local development demo data with a curated ABO product catalog.
-- Idempotent: only DEMO-SEED-V1 users/orders and explicitly owned products are replaced.
-- Target database: dexter_dianshang

SET NAMES utf8mb4;
SET @demo_tag = '[DEMO-SEED-V1]';
SET @seed_now = NOW();
SET @old_foreign_key_checks = @@FOREIGN_KEY_CHECKS;
SET FOREIGN_KEY_CHECKS = 0;

START TRANSACTION;

-- This leaf category is exclusively used by the curated catalog. Its original
-- "腰凳" label and icon did not match the available ABO products.
UPDATE eb_category
SET name = '母婴出行',
    extra = 'crmebimage/public/open-data/abo-curated-v2/8114-main.jpg',
    update_time = @seed_now
WHERE id = 285
  AND pid = 280;

-- Collect every product owned by the old and current demo imports. Business products
-- without one of these markers are not touched.
DROP TEMPORARY TABLE IF EXISTS tmp_owned_products;
CREATE TEMPORARY TABLE tmp_owned_products (
    id INT PRIMARY KEY
) ENGINE = MEMORY;
INSERT INTO tmp_owned_products (id)
SELECT id
FROM eb_store_product
WHERE soure_link = 'demo-seed-v1'
   OR soure_link LIKE 'abo-open-data-v1:%'
   OR soure_link LIKE 'abo-curated-v2:%';

DROP TEMPORARY TABLE IF EXISTS tmp_owned_seckill;
CREATE TEMPORARY TABLE tmp_owned_seckill (id INT PRIMARY KEY) ENGINE = MEMORY;
INSERT INTO tmp_owned_seckill (id)
SELECT s.id
FROM eb_store_seckill s
JOIN tmp_owned_products p ON p.id = s.product_id;

DROP TEMPORARY TABLE IF EXISTS tmp_owned_bargain;
CREATE TEMPORARY TABLE tmp_owned_bargain (id INT PRIMARY KEY) ENGINE = MEMORY;
INSERT INTO tmp_owned_bargain (id)
SELECT b.id
FROM eb_store_bargain b
JOIN tmp_owned_products p ON p.id = b.product_id;

DROP TEMPORARY TABLE IF EXISTS tmp_owned_combination;
CREATE TEMPORARY TABLE tmp_owned_combination (id INT PRIMARY KEY) ENGINE = MEMORY;
INSERT INTO tmp_owned_combination (id)
SELECT c.id
FROM eb_store_combination c
JOIN tmp_owned_products p ON p.id = c.product_id;

-- Remove a previous run in dependency order.
DELETE r FROM eb_store_product_reply r
LEFT JOIN tmp_owned_products p ON p.id = r.product_id
WHERE p.id IS NOT NULL OR r.id BETWEEN 580000 AND 581000;
DELETE pink FROM eb_store_pink pink
JOIN tmp_owned_combination c ON c.id = pink.cid;
DELETE os FROM eb_store_order_status os
    JOIN eb_store_order o ON o.id = os.oid
WHERE o.remark = @demo_tag;
DELETE oi FROM eb_store_order_info oi
    JOIN eb_store_order o ON o.id = oi.order_id
WHERE o.remark = @demo_tag;
DELETE FROM eb_store_order WHERE remark = @demo_tag;
DELETE c FROM eb_store_cart c
LEFT JOIN tmp_owned_products p ON p.id = c.product_id
WHERE c.uid BETWEEN 8101 AND 8200 OR p.id IS NOT NULL;
DELETE r FROM eb_store_product_relation r
LEFT JOIN tmp_owned_products p ON p.id = r.product_id
WHERE r.uid BETWEEN 8101 AND 8200 OR p.id IS NOT NULL;
DELETE FROM eb_store_coupon_user
WHERE coupon_id BETWEEN 8101 AND 8200 OR uid BETWEEN 8101 AND 8200;
DELETE FROM eb_user_bill WHERE uid BETWEEN 8101 AND 8200;
DELETE FROM eb_user_address WHERE uid BETWEEN 8101 AND 8200;
DELETE FROM eb_user_visit_record
WHERE uid BETWEEN 8101 AND 8200 OR id BETWEEN -999999 AND -800000;
DELETE d FROM eb_product_day_record d
LEFT JOIN tmp_owned_products p ON p.id = d.product_id
WHERE p.id IS NOT NULL OR d.id BETWEEN -999999 AND -800000;
DELETE FROM eb_shopping_product_day_record WHERE id BETWEEN -999999 AND -800000;
DELETE FROM eb_trading_day_record WHERE id BETWEEN -999999 AND -800000;

DELETE d FROM eb_store_product_description d
JOIN tmp_owned_products p ON p.id = d.product_id
WHERE d.type = 0;
DELETE d FROM eb_store_product_description d
JOIN tmp_owned_seckill s ON s.id = d.product_id
WHERE d.type = 1;
DELETE d FROM eb_store_product_description d
JOIN tmp_owned_bargain b ON b.id = d.product_id
WHERE d.type = 2;
DELETE d FROM eb_store_product_description d
JOIN tmp_owned_combination c ON c.id = d.product_id
WHERE d.type = 3;

DELETE r FROM eb_store_product_attr_result r
JOIN tmp_owned_products p ON p.id = r.product_id
WHERE r.type = 0;
DELETE r FROM eb_store_product_attr_result r
JOIN tmp_owned_seckill s ON s.id = r.product_id
WHERE r.type = 1;
DELETE r FROM eb_store_product_attr_result r
JOIN tmp_owned_bargain b ON b.id = r.product_id
WHERE r.type = 2;
DELETE r FROM eb_store_product_attr_result r
JOIN tmp_owned_combination c ON c.id = r.product_id
WHERE r.type = 3;

DELETE o FROM eb_store_product_attr_option o
JOIN eb_store_product_attr a ON a.id = o.attr_id
JOIN tmp_owned_products p ON p.id = a.product_id
WHERE a.type = 0;
DELETE o FROM eb_store_product_attr_option o
JOIN eb_store_product_attr a ON a.id = o.attr_id
JOIN tmp_owned_seckill s ON s.id = a.product_id
WHERE a.type = 1;
DELETE o FROM eb_store_product_attr_option o
JOIN eb_store_product_attr a ON a.id = o.attr_id
JOIN tmp_owned_bargain b ON b.id = a.product_id
WHERE a.type = 2;
DELETE o FROM eb_store_product_attr_option o
JOIN eb_store_product_attr a ON a.id = o.attr_id
JOIN tmp_owned_combination c ON c.id = a.product_id
WHERE a.type = 3;

DELETE v FROM eb_store_product_attr_value v
JOIN tmp_owned_products p ON p.id = v.product_id
WHERE v.type = 0;
DELETE v FROM eb_store_product_attr_value v
JOIN tmp_owned_seckill s ON s.id = v.product_id
WHERE v.type = 1;
DELETE v FROM eb_store_product_attr_value v
JOIN tmp_owned_bargain b ON b.id = v.product_id
WHERE v.type = 2;
DELETE v FROM eb_store_product_attr_value v
JOIN tmp_owned_combination c ON c.id = v.product_id
WHERE v.type = 3;

DELETE a FROM eb_store_product_attr a
JOIN tmp_owned_products p ON p.id = a.product_id
WHERE a.type = 0;
DELETE a FROM eb_store_product_attr a
JOIN tmp_owned_seckill s ON s.id = a.product_id
WHERE a.type = 1;
DELETE a FROM eb_store_product_attr a
JOIN tmp_owned_bargain b ON b.id = a.product_id
WHERE a.type = 2;
DELETE a FROM eb_store_product_attr a
JOIN tmp_owned_combination c ON c.id = a.product_id
WHERE a.type = 3;

DELETE s FROM eb_store_seckill s JOIN tmp_owned_seckill owned ON owned.id = s.id;
DELETE c FROM eb_store_combination c JOIN tmp_owned_combination owned ON owned.id = c.id;
DELETE b FROM eb_store_bargain b JOIN tmp_owned_bargain owned ON owned.id = b.id;
DELETE FROM eb_store_coupon WHERE id BETWEEN 8101 AND 8200;
DELETE FROM eb_article WHERE id BETWEEN 8101 AND 8200;
DELETE p FROM eb_store_product p JOIN tmp_owned_products owned ON owned.id = p.id;
DELETE FROM eb_user
WHERE uid BETWEEN 8101 AND 8200 AND mark = @demo_tag;

DROP TEMPORARY TABLE IF EXISTS tmp_demo_numbers;
CREATE TEMPORARY TABLE tmp_demo_numbers (n INT PRIMARY KEY) ENGINE = MEMORY;
INSERT INTO tmp_demo_numbers (n)
SELECT a.n * 100 + b.n * 10 + c.n + 1
FROM (
    SELECT 0 n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3
    UNION ALL SELECT 4 UNION ALL SELECT 5
) AS a
CROSS JOIN (
    SELECT 0 n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
    UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9
) AS b
CROSS JOIN (
    SELECT 0 n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
    UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9
) AS c
WHERE a.n * 100 + b.n * 10 + c.n + 1 <= 600;

-- BEGIN GENERATED ABO CURATED V2 PRODUCTS
-- Generated by backend/sql/tools/build_abo_demo_catalog.py v2.0.0.
-- Source of truth: backend/sql/data/abo-curated-v2.json.
DROP TEMPORARY TABLE IF EXISTS tmp_demo_products;
CREATE TEMPORARY TABLE tmp_demo_products (
    id INT PRIMARY KEY,
    item_id VARCHAR(32) NOT NULL,
    main_image_id VARCHAR(64) NOT NULL,
    store_name VARCHAR(128) NOT NULL,
    store_info VARCHAR(256) NOT NULL,
    keyword VARCHAR(256) NOT NULL,
    cate_id VARCHAR(64) NOT NULL,
    image VARCHAR(256) NOT NULL,
    price DECIMAL(8, 2) NOT NULL,
    ot_price DECIMAL(8, 2) NOT NULL,
    cost DECIMAL(8, 2) NOT NULL,
    stock INT NOT NULL,
    sales INT NOT NULL,
    sort_num INT NOT NULL,
    unit_name VARCHAR(32) NOT NULL,
    weight DECIMAL(8, 2) NOT NULL,
    source_marker VARCHAR(255) NOT NULL
) ENGINE = MEMORY;

INSERT INTO tmp_demo_products VALUES
(8101, 'B0842CPXX5', '81Y+y5ld2jL', 'AmazonBasics 3.5升空气炸锅', '热风烹饪设备，容量与功率按源商品标题整理。', '炸锅 AmazonBasics 3.5升空气炸锅 AmazonBasics', '275', 'crmebimage/public/open-data/abo-curated-v2/8101-main.jpg', 499.00, 623.75, 274.45, 120, 36, 360, '台', 4.20, 'abo-curated-v2:B0842CPXX5:81Y+y5ld2jL'),
(8102, 'B0842CVYNS', '81I2tY2MSeL', 'AmazonBasics 5.5升触控空气炸锅', '热风烹饪设备，容量与功率按源商品标题整理。', '炸锅 AmazonBasics 5.5升触控空气炸锅 AmazonBasics', '275', 'crmebimage/public/open-data/abo-curated-v2/8102-main.jpg', 538.92, 673.65, 296.41, 137, 59, 326, '台', 4.30, 'abo-curated-v2:B0842CVYNS:81I2tY2MSeL'),
(8103, 'B07W197T5J', '71H8btY1jlL', 'Amazon Basics 手动空气炸锅', '热风烹饪设备，容量与功率按源商品标题整理。', '炸锅 Amazon Basics 手动空气炸锅 Amazon Basics', '275', 'crmebimage/public/open-data/abo-curated-v2/8103-main.jpg', 578.84, 723.55, 318.36, 154, 82, 292, '台', 4.40, 'abo-curated-v2:B07W197T5J:71H8btY1jlL'),
(8104, 'B07DR85F7F', '61HO4QZsrnL', 'Luby 不锈钢热风空气炸锅', '热风烹饪设备，容量与功率按源商品标题整理。', '炸锅 Luby 不锈钢热风空气炸锅 Luby', '275', 'crmebimage/public/open-data/abo-curated-v2/8104-main.jpg', 618.76, 773.45, 340.32, 171, 105, 258, '台', 4.50, 'abo-curated-v2:B07DR85F7F:61HO4QZsrnL'),
(8105, 'B07DCCJ1FX', '81Vk2qN10RL', 'Stone & Beam 带盖不粘奶锅', '锅具材质与套装内容按源商品记录整理。', '锅具 Stone & Beam 带盖不粘奶锅 Stone & Beam', '276', 'crmebimage/public/open-data/abo-curated-v2/8105-main.jpg', 329.00, 411.25, 180.95, 188, 128, 359, '套', 3.40, 'abo-curated-v2:B07DCCJ1FX:81Vk2qN10RL'),
(8106, 'B07BLCDMJJ', '81Mw1ky7NgL', 'Stone & Beam 12夸脱不锈钢汤锅', '锅具材质与套装内容按源商品记录整理。', '锅具 Stone & Beam 12夸脱不锈钢汤锅 Stone & Beam', '276', 'crmebimage/public/open-data/abo-curated-v2/8106-main.jpg', 355.32, 444.15, 195.43, 205, 151, 325, '套', 3.50, 'abo-curated-v2:B07BLCDMJJ:81Mw1ky7NgL'),
(8107, 'B07BG61THW', '8116H-pbopL', 'Stone & Beam 不粘煎锅两件套', '锅具材质与套装内容按源商品记录整理。', '锅具 Stone & Beam 不粘煎锅两件套 Stone & Beam', '276', 'crmebimage/public/open-data/abo-curated-v2/8107-main.jpg', 381.64, 477.05, 209.90, 222, 174, 291, '套', 3.60, 'abo-curated-v2:B07BG61THW:8116H-pbopL'),
(8108, 'B073Q9GT4N', '81w6X1n93-L', 'AmazonBasics 铸铁锅具五件套', '锅具材质与套装内容按源商品记录整理。', '锅具 AmazonBasics 铸铁锅具五件套 AmazonBasics', '276', 'crmebimage/public/open-data/abo-curated-v2/8108-main.jpg', 407.96, 509.95, 224.38, 239, 197, 257, '套', 3.70, 'abo-curated-v2:B073Q9GT4N:81w6X1n93-L'),
(8109, 'B07PVPKTWR', '71TG2fgzfML', 'AmazonBasics 多速手持搅拌棒套装', '搅拌设备类型与容量按源商品标题整理。', '破壁机 AmazonBasics 多速手持搅拌棒套装 AmazonBasics', '277', 'crmebimage/public/open-data/abo-curated-v2/8109-main.jpg', 299.00, 373.75, 164.45, 256, 220, 358, '台', 2.20, 'abo-curated-v2:B07PVPKTWR:71TG2fgzfML'),
(8110, 'B07DRNNZKJ', '81v7T-5gdzL', 'AmazonBasics 1.5升台式搅拌机', '搅拌设备类型与容量按源商品标题整理。', '破壁机 AmazonBasics 1.5升台式搅拌机 AmazonBasics', '277', 'crmebimage/public/open-data/abo-curated-v2/8110-main.jpg', 322.92, 403.65, 177.61, 273, 53, 324, '台', 2.30, 'abo-curated-v2:B07DRNNZKJ:81v7T-5gdzL'),
(8111, 'B07FLLCKJJ', '71xtTNSJ54L', 'AmazonBasics 600毫升随行果汁机', '搅拌设备类型与容量按源商品标题整理。', '破壁机 AmazonBasics 600毫升随行果汁机 AmazonBasics', '277', 'crmebimage/public/open-data/abo-curated-v2/8111-main.jpg', 346.84, 433.55, 190.76, 290, 76, 290, '台', 2.40, 'abo-curated-v2:B07FLLCKJJ:71xtTNSJ54L'),
(8112, 'B06XZQSP1C', '81Psy088UcL', 'Solimo 动物图案新生儿睡袋提篮套装', '婴儿睡袋提篮套装，适合新生儿外出携带。', '母婴出行 Solimo 动物图案新生儿睡袋提篮套装 Amazon Brand - Solimo', '285', 'crmebimage/public/open-data/abo-curated-v2/8112-main.jpg', 199.00, 248.75, 109.45, 307, 99, 357, '套', 1.10, 'abo-curated-v2:B06XZQSP1C:81Psy088UcL'),
(8113, 'B06Y12PVZ7', '81zYgwtud-L', 'Solimo 水果图案新生儿睡袋提篮套装', '婴儿睡袋提篮套装，适合新生儿外出携带。', '母婴出行 Solimo 水果图案新生儿睡袋提篮套装 Amazon Brand - Solimo', '285', 'crmebimage/public/open-data/abo-curated-v2/8113-main.jpg', 214.92, 268.65, 118.21, 324, 122, 323, '套', 1.20, 'abo-curated-v2:B06Y12PVZ7:81zYgwtud-L'),
(8114, 'B07DBMLN18', '71owDZxAMfL', 'EONO 大容量母婴双肩包', '母婴双肩包，适合外出收纳和携带。', '母婴出行 EONO 大容量母婴双肩包 EONO', '285', 'crmebimage/public/open-data/abo-curated-v2/8114-main.jpg', 230.84, 288.55, 126.96, 341, 145, 289, '套', 1.30, 'abo-curated-v2:B07DBMLN18:71owDZxAMfL'),
(8115, 'B07RJFDGKH', '61Hu60INfML', 'Mama Bear 温和型婴儿配方奶粉12盎司', '配方类型与包装净含量按源商品标题整理。', '奶粉 Mama Bear 温和型婴儿配方奶粉12盎司 Mama Bear', '286', 'crmebimage/public/open-data/abo-curated-v2/8115-main.jpg', 239.00, 298.75, 131.45, 358, 168, 356, '罐', 0.80, 'abo-curated-v2:B07RJFDGKH:61Hu60INfML'),
(8116, 'B07RD73SZM', '61wgHBhRgdL', 'Mama Bear 优护型婴儿配方奶粉23.2盎司', '配方类型与包装净含量按源商品标题整理。', '奶粉 Mama Bear 优护型婴儿配方奶粉23.2盎司 Mama Bear', '286', 'crmebimage/public/open-data/abo-curated-v2/8116-main.jpg', 258.12, 322.65, 141.97, 375, 191, 322, '罐', 0.90, 'abo-curated-v2:B07RD73SZM:61wgHBhRgdL'),
(8117, 'B0847T8PLR', '71UkRHrBGZL', 'Mama Bear 舒适型婴儿配方奶粉22.5盎司', '配方类型与包装净含量按源商品标题整理。', '奶粉 Mama Bear 舒适型婴儿配方奶粉22.5盎司 Mama Bear', '286', 'crmebimage/public/open-data/abo-curated-v2/8117-main.jpg', 277.24, 346.55, 152.48, 132, 214, 288, '罐', 1.00, 'abo-curated-v2:B0847T8PLR:71UkRHrBGZL'),
(8118, 'B07HJW2JYF', '810817TlqlL', 'AmazonBasics 大颗粒木质积木20件套', '玩具类型、材质或件数按源商品标题整理。', '玩具 AmazonBasics 大颗粒木质积木20件套 AmazonBasics', '287', 'crmebimage/public/open-data/abo-curated-v2/8118-main.jpg', 119.00, 148.75, 65.45, 149, 47, 355, '套', 1.30, 'abo-curated-v2:B07HJW2JYF:810817TlqlL'),
(8119, 'B07ZDPST4B', '816z3Gi-iDL', 'AmazonBasics 迷你罐装彩泥11件套', '玩具类型、材质或件数按源商品标题整理。', '玩具 AmazonBasics 迷你罐装彩泥11件套 AmazonBasics', '287', 'crmebimage/public/open-data/abo-curated-v2/8119-main.jpg', 129.00, 161.25, 70.95, 166, 70, 321, '套', 1.40, 'abo-curated-v2:B07ZDPST4B:816z3Gi-iDL'),
(8120, 'B07THDGF2K', '71wIbvoL9dL', 'AmazonBasics 精细动作创意插板', '玩具类型、材质或件数按源商品标题整理。', '玩具 AmazonBasics 精细动作创意插板 AmazonBasics', '287', 'crmebimage/public/open-data/abo-curated-v2/8120-main.jpg', 139.00, 173.75, 76.45, 183, 93, 287, '套', 1.50, 'abo-curated-v2:B07THDGF2K:71wIbvoL9dL'),
(8121, 'B07THDN2ZS', '61UwC0SF6rL', 'AmazonBasics 橡胶木创意积木4件套', '玩具类型、材质或件数按源商品标题整理。', '玩具 AmazonBasics 橡胶木创意积木4件套 AmazonBasics', '287', 'crmebimage/public/open-data/abo-curated-v2/8121-main.jpg', 149.00, 186.25, 81.95, 200, 116, 253, '套', 1.60, 'abo-curated-v2:B07THDN2ZS:61UwC0SF6rL'),
(8122, 'B07W7243ZM', '71bUd4HxoCL', 'Mama Bear 宽口奶瓶奶嘴6件套', '奶瓶配件类型与包装数量按源商品标题整理。', '奶瓶 Mama Bear 宽口奶瓶奶嘴6件套 Mama Bear', '806', 'crmebimage/public/open-data/abo-curated-v2/8122-main.jpg', 89.00, 111.25, 48.95, 217, 139, 354, '套', 0.50, 'abo-curated-v2:B07W7243ZM:71bUd4HxoCL'),
(8123, 'B07SPWYZ3V', '810iaQVJB3L', 'Mama Bear 9盎司宽口奶瓶3只装', '奶瓶配件类型与包装数量按源商品标题整理。', '奶瓶 Mama Bear 9盎司宽口奶瓶3只装 Mama Bear', '806', 'crmebimage/public/open-data/abo-curated-v2/8123-main.jpg', 99.00, 123.75, 54.45, 234, 162, 320, '套', 0.60, 'abo-curated-v2:B07SPWYZ3V:810iaQVJB3L'),
(8124, 'B07FP1P97K', '81cn+7x6PXL', 'Mama Bear 奶瓶刷3件套', '奶瓶配件类型与包装数量按源商品标题整理。', '奶瓶 Mama Bear 奶瓶刷3件套 Mama Bear', '806', 'crmebimage/public/open-data/abo-curated-v2/8124-main.jpg', 109.00, 136.25, 59.95, 251, 185, 286, '套', 0.70, 'abo-curated-v2:B07FP1P97K:81cn+7x6PXL'),
(8125, 'B07CTS3Q7Y', '81lwga3GVEL', 'AmazonBasics 户外信封式睡袋', '露营用品类型按源商品标题与主图整理。', '露营装备 AmazonBasics 户外信封式睡袋 AmazonBasics', '288', 'crmebimage/public/open-data/abo-curated-v2/8125-main.jpg', 259.00, 323.75, 142.45, 268, 208, 353, '件', 3.10, 'abo-curated-v2:B07CTS3Q7Y:81lwga3GVEL'),
(8126, 'B07BH4XSXP', '81qipoF5liL', 'AmazonBasics 弹开式沙滩遮阳帐篷', '露营用品类型按源商品标题与主图整理。', '露营装备 AmazonBasics 弹开式沙滩遮阳帐篷 AmazonBasics', '288', 'crmebimage/public/open-data/abo-curated-v2/8126-main.jpg', 279.72, 349.65, 153.85, 285, 41, 319, '件', 3.20, 'abo-curated-v2:B07BH4XSXP:81qipoF5liL'),
(8127, 'B07DVLXYVP', '71puq8p1M7L', 'AmazonBasics 户外露营帐篷', '露营用品类型按源商品标题与主图整理。', '露营装备 AmazonBasics 户外露营帐篷 AmazonBasics', '288', 'crmebimage/public/open-data/abo-curated-v2/8127-main.jpg', 300.44, 375.55, 165.24, 302, 64, 285, '件', 3.30, 'abo-curated-v2:B07DVLXYVP:71puq8p1M7L'),
(8128, 'B0896G6LPJ', '811G-ppsl6L', 'Solimo 蓝色金属露营椅', '露营用品类型按源商品标题与主图整理。', '露营装备 Solimo 蓝色金属露营椅 Amazon Brand - Solimo', '288', 'crmebimage/public/open-data/abo-curated-v2/8128-main.jpg', 321.16, 401.45, 176.64, 319, 87, 251, '件', 3.40, 'abo-curated-v2:B0896G6LPJ:811G-ppsl6L'),
(8129, 'B07GX1ZMS2', '814kDQlstrL', 'AmazonBasics D形自行车锁含钢缆', '骑行锁具或收纳配件按源商品标题整理。', '骑行配件 AmazonBasics D形自行车锁含钢缆 AmazonBasics', '289', 'crmebimage/public/open-data/abo-curated-v2/8129-main.jpg', 139.00, 173.75, 76.45, 336, 110, 352, '件', 1.20, 'abo-curated-v2:B07GX1ZMS2:814kDQlstrL'),
(8130, 'B07T3F628P', '81Yhig+QmSL', 'Amazon Basics 黑色折叠自行车锁', '骑行锁具或收纳配件按源商品标题整理。', '骑行配件 Amazon Basics 黑色折叠自行车锁 Amazon Basics', '289', 'crmebimage/public/open-data/abo-curated-v2/8130-main.jpg', 150.12, 187.65, 82.57, 353, 133, 318, '件', 1.30, 'abo-curated-v2:B07T3F628P:81Yhig+QmSL'),
(8131, 'B07T4J9MP4', '81jxMqvzWWL', 'Amazon Basics 五位密码自行车链锁', '骑行锁具或收纳配件按源商品标题整理。', '骑行配件 Amazon Basics 五位密码自行车链锁 Amazon Basics', '289', 'crmebimage/public/open-data/abo-curated-v2/8131-main.jpg', 161.24, 201.55, 88.68, 370, 156, 284, '件', 1.40, 'abo-curated-v2:B07T4J9MP4:81jxMqvzWWL'),
(8132, 'B01E7815LS', '91L8i6XyTSL', 'AmazonBasics 自行车座垫包', '骑行锁具或收纳配件按源商品标题整理。', '骑行配件 AmazonBasics 自行车座垫包 Amazonベーシック(AmazonBasics)', '289', 'crmebimage/public/open-data/abo-curated-v2/8132-main.jpg', 172.36, 215.45, 94.80, 127, 179, 250, '件', 1.50, 'abo-curated-v2:B01E7815LS:91L8i6XyTSL'),
(8133, 'B07D56WS5V', '615p0wOO4lL', 'Eono 成人长发硅胶泳帽', '游泳用品类型、造型与颜色按源商品记录整理。', '游泳设备 Eono 成人长发硅胶泳帽 Eono', '290', 'crmebimage/public/open-data/abo-curated-v2/8133-main.jpg', 99.00, 123.75, 54.45, 144, 202, 351, '件', 0.60, 'abo-curated-v2:B07D56WS5V:615p0wOO4lL'),
(8134, 'B07CYJBZF7', '71HcVNwQa6L', 'Summer Palms 披萨造型泳池浮排', '游泳用品类型、造型与颜色按源商品记录整理。', '游泳设备 Summer Palms 披萨造型泳池浮排 Summer Palms', '290', 'crmebimage/public/open-data/abo-curated-v2/8134-main.jpg', 109.00, 136.25, 59.95, 161, 225, 317, '件', 0.70, 'abo-curated-v2:B07CYJBZF7:71HcVNwQa6L'),
(8135, 'B088W8DVVT', '61aMEj6AitL', 'Eono 灰色游泳更衣浴袍', '游泳用品类型、造型与颜色按源商品记录整理。', '游泳设备 Eono 灰色游泳更衣浴袍 Eono', '290', 'crmebimage/public/open-data/abo-curated-v2/8135-main.jpg', 119.00, 148.75, 65.45, 178, 58, 283, '件', 0.80, 'abo-curated-v2:B088W8DVVT:61aMEj6AitL'),
(8136, 'B07R4X1CZL', '919GtNIKylL', 'AmazonBasics 黑色平衡训练垫', '训练用品类型、尺寸或材质按源商品记录整理。', '瑜伽 AmazonBasics 黑色平衡训练垫 AmazonBasics', '803', 'crmebimage/public/open-data/abo-curated-v2/8136-main.jpg', 109.00, 136.25, 59.95, 195, 81, 350, '件', 1.00, 'abo-curated-v2:B07R4X1CZL:919GtNIKylL'),
(8137, 'B07R7XH1HY', '71MSTQGabsL', 'AmazonBasics 紫色橡胶麂皮瑜伽垫', '训练用品类型、尺寸或材质按源商品记录整理。', '瑜伽 AmazonBasics 紫色橡胶麂皮瑜伽垫 AmazonBasics', '803', 'crmebimage/public/open-data/abo-curated-v2/8137-main.jpg', 119.00, 148.75, 65.45, 212, 104, 316, '件', 1.10, 'abo-curated-v2:B07R7XH1HY:71MSTQGabsL'),
(8138, 'B01FN7XA38', '917ffgZSNCL', 'Amazon Basics 紫色瑜伽砖', '训练用品类型、尺寸或材质按源商品记录整理。', '瑜伽 Amazon Basics 紫色瑜伽砖 Amazonベーシック(AmazonBasics)', '803', 'crmebimage/public/open-data/abo-curated-v2/8138-main.jpg', 129.00, 161.25, 70.95, 229, 127, 282, '件', 1.20, 'abo-curated-v2:B01FN7XA38:917ffgZSNCL'),
(8139, 'B01LP0UKJE', '91ofLiMz2hL', 'AmazonBasics 红色加厚瑜伽垫', '训练用品类型、尺寸或材质按源商品记录整理。', '瑜伽 AmazonBasics 红色加厚瑜伽垫 AmazonBasics', '803', 'crmebimage/public/open-data/abo-curated-v2/8139-main.jpg', 139.00, 173.75, 76.45, 246, 150, 248, '件', 1.30, 'abo-curated-v2:B01LP0UKJE:91ofLiMz2hL'),
(8140, 'B0834T1QNW', '612u07R-iBL', 'UMI 粉色电动毛孔清洁仪', '面部清洁工具类型与配件数量按源商品记录整理。', '清洁仪 UMI 粉色电动毛孔清洁仪 UMI', '291', 'crmebimage/public/open-data/abo-curated-v2/8140-main.jpg', 159.00, 198.75, 87.45, 263, 173, 349, '套', 0.40, 'abo-curated-v2:B0834T1QNW:612u07R-iBL'),
(8141, 'B082W9KJQ6', '51JxDZ3KhtL', 'UMI 三档超声波面部清洁铲', '面部清洁工具类型与配件数量按源商品记录整理。', '清洁仪 UMI 三档超声波面部清洁铲 UMI', '291', 'crmebimage/public/open-data/abo-curated-v2/8141-main.jpg', 171.72, 214.65, 94.45, 280, 196, 315, '套', 0.50, 'abo-curated-v2:B082W9KJQ6:51JxDZ3KhtL'),
(8142, 'B07JD69ZYT', '51jGqaMZEiL', 'EONO 黑头清洁工具4件套', '面部清洁工具类型与配件数量按源商品记录整理。', '清洁仪 EONO 黑头清洁工具4件套 EONO', '291', 'crmebimage/public/open-data/abo-curated-v2/8142-main.jpg', 184.44, 230.55, 101.44, 297, 219, 281, '套', 0.60, 'abo-curated-v2:B07JD69ZYT:51jGqaMZEiL'),
(8143, 'B07ZTTVJ2Z', '7159-I4mszL', 'AmazonBasics 黑色直发器', '个护电器类型、功率或颜色按源商品记录整理。', '美容仪 AmazonBasics 黑色直发器 AmazonBasics', '292', 'crmebimage/public/open-data/abo-curated-v2/8143-main.jpg', 229.00, 286.25, 125.95, 314, 52, 348, '台', 0.90, 'abo-curated-v2:B07ZTTVJ2Z:7159-I4mszL'),
(8144, 'B07ZTTTJTC', '719uvFjjzyL', 'AmazonBasics 蓝色1400瓦折叠吹风机', '个护电器类型、功率或颜色按源商品记录整理。', '美容仪 AmazonBasics 蓝色1400瓦折叠吹风机 AmazonBasics', '292', 'crmebimage/public/open-data/abo-curated-v2/8144-main.jpg', 247.32, 309.15, 136.03, 331, 75, 314, '台', 1.00, 'abo-curated-v2:B07ZTTTJTC:719uvFjjzyL'),
(8145, 'B07ZTVG1GW', '71chWUdK2NL', 'AmazonBasics 1800瓦温控折叠吹风机', '个护电器类型、功率或颜色按源商品记录整理。', '美容仪 AmazonBasics 1800瓦温控折叠吹风机 AmazonBasics', '292', 'crmebimage/public/open-data/abo-curated-v2/8145-main.jpg', 265.64, 332.05, 146.10, 348, 98, 280, '台', 1.10, 'abo-curated-v2:B07ZTVG1GW:71chWUdK2NL'),
(8146, 'B084WNSCCW', '61LiM7FFXeL', 'UMI 金色纳米离子面部蒸汽仪', '个护电器类型、功率或颜色按源商品记录整理。', '美容仪 UMI 金色纳米离子面部蒸汽仪 UMI', '292', 'crmebimage/public/open-data/abo-curated-v2/8146-main.jpg', 283.96, 354.95, 156.18, 365, 121, 246, '台', 1.20, 'abo-curated-v2:B084WNSCCW:61LiM7FFXeL'),
(8147, 'B0834SPRVX', '61Nzib5iF2L', 'Eono 磁吸假睫毛眼线套装', '彩妆类型、色号或套装内容按源商品记录整理。', '彩妆 Eono 磁吸假睫毛眼线套装 Eono', '293', 'crmebimage/public/open-data/abo-curated-v2/8147-main.jpg', 139.00, 173.75, 76.45, 122, 144, 347, '套', 0.30, 'abo-curated-v2:B0834SPRVX:61Nzib5iF2L'),
(8148, 'B000UGZD9M', '71EZr0v7VAL', 'L''Oreal True Match W3裸米色粉饼', '彩妆类型、色号或套装内容按源商品记录整理。', '彩妆 L''Oreal True Match W3裸米色粉饼 L''Oreal Paris', '293', 'crmebimage/public/open-data/abo-curated-v2/8148-main.jpg', 150.12, 187.65, 82.57, 139, 167, 313, '套', 0.40, 'abo-curated-v2:B000UGZD9M:71EZr0v7VAL'),
(8149, 'B07CVBSCFC', '71xhcuO6cqL', 'find Princess of Shine哑光唇膏', '彩妆类型、色号或套装内容按源商品记录整理。', '彩妆 find Princess of Shine哑光唇膏 find.', '293', 'crmebimage/public/open-data/abo-curated-v2/8149-main.jpg', 161.24, 201.55, 88.68, 156, 190, 279, '套', 0.50, 'abo-curated-v2:B07CVBSCFC:71xhcuO6cqL'),
(8150, 'B07CTQQ7QD', '71-p+DipHHL', 'find 指甲护理三件套', '彩妆类型、色号或套装内容按源商品记录整理。', '彩妆 find 指甲护理三件套 find.', '293', 'crmebimage/public/open-data/abo-curated-v2/8150-main.jpg', 172.36, 215.45, 94.80, 173, 213, 245, '套', 0.60, 'abo-curated-v2:B07CTQQ7QD:71-p+DipHHL'),
(8151, 'B07R9NBLRL', '61QzLy8FC3L', 'Solimo 男士Regal Essence身体香氛120毫升', '香型与包装容量按源商品标题整理。', '香水 Solimo 男士Regal Essence身体香氛120毫升 Amazon Brand - Solimo', '294', 'crmebimage/public/open-data/abo-curated-v2/8151-main.jpg', 129.00, 161.25, 70.95, 190, 46, 346, '瓶', 0.40, 'abo-curated-v2:B07R9NBLRL:61QzLy8FC3L'),
(8152, 'B07M7D9P1M', '61lUIw3TG-L', 'Daily Essence 樱花身体喷雾8盎司', '香型与包装容量按源商品标题整理。', '香水 Daily Essence 樱花身体喷雾8盎司 Daily Essence', '294', 'crmebimage/public/open-data/abo-curated-v2/8152-main.jpg', 139.32, 174.15, 76.63, 207, 69, 312, '瓶', 0.50, 'abo-curated-v2:B07M7D9P1M:61lUIw3TG-L'),
(8153, 'B07MFQ97KJ', '61lsWbUSykL', 'Daily Essence 椰香青柠身体喷雾8盎司', '香型与包装容量按源商品标题整理。', '香水 Daily Essence 椰香青柠身体喷雾8盎司 Daily Essence', '294', 'crmebimage/public/open-data/abo-curated-v2/8153-main.jpg', 149.64, 187.05, 82.30, 224, 92, 278, '瓶', 0.60, 'abo-curated-v2:B07MFQ97KJ:61lsWbUSykL'),
(8154, 'B003BMI8D0', '71hfnlIXt4L', 'L''Oreal True Match甜姜色腮红', '修容、腮红或高光类型按源商品标题整理。', '修容 L''Oreal True Match甜姜色腮红 L''Oréal Paris', '295', 'crmebimage/public/open-data/abo-curated-v2/8154-main.jpg', 119.00, 148.75, 65.45, 241, 115, 345, '件', 0.20, 'abo-curated-v2:B003BMI8D0:71hfnlIXt4L'),
(8155, 'B07CTPNNZ6', '71Fw1plrrtL', 'find Sunkissed双色修容盘', '修容、腮红或高光类型按源商品标题整理。', '修容 find Sunkissed双色修容盘 find.', '295', 'crmebimage/public/open-data/abo-curated-v2/8155-main.jpg', 129.00, 161.25, 70.95, 258, 138, 311, '件', 0.30, 'abo-curated-v2:B07CTPNNZ6:71Fw1plrrtL'),
(8156, 'B07CTPNNYY', '71jw24OGaaL', 'find 高光腮红双头修容棒', '修容、腮红或高光类型按源商品标题整理。', '修容 find 高光腮红双头修容棒 find.', '295', 'crmebimage/public/open-data/abo-curated-v2/8156-main.jpg', 139.00, 173.75, 76.45, 275, 161, 277, '件', 0.40, 'abo-curated-v2:B07CTPNNYY:71jw24OGaaL'),
(8157, 'B07JD5DNYV', '51yty3Apw9L', 'Eono 折叠化妆刷晾晒架', '美妆工具或收纳用品类型按源商品记录整理。', '其他工具 Eono 折叠化妆刷晾晒架 Eono(イオーノ)', '296', 'crmebimage/public/open-data/abo-curated-v2/8157-main.jpg', 109.00, 136.25, 59.95, 292, 184, 344, '件', 0.70, 'abo-curated-v2:B07JD5DNYV:51yty3Apw9L'),
(8158, 'B07JCM49ZX', 'A1pp9k2iZtL', 'Solimo 红色三折悬挂洗漱包', '美妆工具或收纳用品类型按源商品记录整理。', '其他工具 Solimo 红色三折悬挂洗漱包 Amazon Brand - Solimo', '296', 'crmebimage/public/open-data/abo-curated-v2/8158-main.jpg', 119.00, 148.75, 65.45, 309, 207, 310, '件', 0.80, 'abo-curated-v2:B07JCM49ZX:A1pp9k2iZtL'),
(8159, 'B07ZZ9ZQKV', '91BRjzesGoL', 'Solimo 天蓝色化妆收纳包', '美妆工具或收纳用品类型按源商品记录整理。', '其他工具 Solimo 天蓝色化妆收纳包 Amazon Brand - Solimo', '296', 'crmebimage/public/open-data/abo-curated-v2/8159-main.jpg', 129.00, 161.25, 70.95, 326, 40, 276, '件', 0.90, 'abo-curated-v2:B07ZZ9ZQKV:91BRjzesGoL'),
(8160, 'B07CZCQ481', '91ZBXFSGfbL', 'Solimo 男士五层刀片剃须刀套装', '美妆工具或收纳用品类型按源商品记录整理。', '其他工具 Solimo 男士五层刀片剃须刀套装 Solimo', '296', 'crmebimage/public/open-data/abo-curated-v2/8160-main.jpg', 139.00, 173.75, 76.45, 343, 63, 242, '件', 1.00, 'abo-curated-v2:B07CZCQ481:91ZBXFSGfbL'),
(8161, 'B07NQZJML9', '71hyG0YqHFL', 'AmazonBasics 绿色运动按摩滚轮2件套', '按摩器类型与套装内容按源商品标题整理。', '按摩仪 AmazonBasics 绿色运动按摩滚轮2件套 AmazonBasics', '297', 'crmebimage/public/open-data/abo-curated-v2/8161-main.jpg', 179.00, 223.75, 98.45, 360, 86, 343, '件', 1.40, 'abo-curated-v2:B07NQZJML9:71hyG0YqHFL'),
(8162, 'B07MMMQJZF', '81zOkog60dL', 'AmazonBasics 手持全身按摩器', '按摩器类型与套装内容按源商品标题整理。', '按摩仪 AmazonBasics 手持全身按摩器 AmazonBasics', '297', 'crmebimage/public/open-data/abo-curated-v2/8162-main.jpg', 193.32, 241.65, 106.33, 377, 109, 309, '件', 1.50, 'abo-curated-v2:B07MMMQJZF:81zOkog60dL'),
(8163, 'B07FTMFG1H', '71WYpLlYJ3L', 'Healthican 八头加热揉捏按摩枕', '按摩器类型与套装内容按源商品标题整理。', '按摩仪 Healthican 八头加热揉捏按摩枕 Healthican', '297', 'crmebimage/public/open-data/abo-curated-v2/8163-main.jpg', 207.64, 259.55, 114.20, 134, 132, 275, '件', 1.60, 'abo-curated-v2:B07FTMFG1H:71WYpLlYJ3L'),
(8164, 'B07HMK2Z57', '71bezUegMkL', 'AmazonBasics USB麦克风游戏耳机', '耳机佩戴方式与连接类型按源商品标题整理。', '耳机 AmazonBasics USB麦克风游戏耳机 Amazonベーシック(AmazonBasics)', '298', 'crmebimage/public/open-data/abo-curated-v2/8164-main.jpg', 189.00, 236.25, 103.95, 151, 155, 342, '副', 0.40, 'abo-curated-v2:B07HMK2Z57:71bezUegMkL'),
(8165, 'B07K8XPS7J', '71xYdqrL9LL', 'AmazonBasics 轻量头戴式有线耳机', '耳机佩戴方式与连接类型按源商品标题整理。', '耳机 AmazonBasics 轻量头戴式有线耳机 AmazonBasics', '298', 'crmebimage/public/open-data/abo-curated-v2/8165-main.jpg', 204.12, 255.15, 112.27, 168, 178, 308, '副', 0.50, 'abo-curated-v2:B07K8XPS7J:71xYdqrL9LL'),
(8166, 'B01F2O18X6', '51L73ElRWML', 'Amazon Basics 黑色入耳式耳机', '耳机佩戴方式与连接类型按源商品标题整理。', '耳机 Amazon Basics 黑色入耳式耳机 Amazonベーシック(AmazonBasics)', '298', 'crmebimage/public/open-data/abo-curated-v2/8166-main.jpg', 219.24, 274.05, 120.58, 185, 201, 274, '副', 0.60, 'abo-curated-v2:B01F2O18X6:51L73ElRWML'),
(8167, 'B07FDJ4QDZ', '719hoe+OvIL', 'AmazonBasics 儿童限音分享接口耳机', '耳机佩戴方式与连接类型按源商品标题整理。', '耳机 AmazonBasics 儿童限音分享接口耳机 AmazonBasics', '298', 'crmebimage/public/open-data/abo-curated-v2/8167-main.jpg', 234.36, 292.95, 128.90, 202, 224, 240, '副', 0.70, 'abo-curated-v2:B07FDJ4QDZ:719hoe+OvIL'),
(8168, 'B084ZFLBGM', '51Hte8uOlqL', 'AmazonBasics Switch手柄四位充电座', '游戏配件适用平台按源商品标题整理。', '游戏机 AmazonBasics Switch手柄四位充电座 AMAZONBASICS', '804', 'crmebimage/public/open-data/abo-curated-v2/8168-main.jpg', 219.00, 273.75, 120.45, 219, 57, 341, '件', 0.60, 'abo-curated-v2:B084ZFLBGM:51Hte8uOlqL'),
(8169, 'B01MCY0680', '61RftItBI0L', 'AmazonBasics PS3无线游戏手柄', '游戏配件适用平台按源商品标题整理。', '游戏机 AmazonBasics PS3无线游戏手柄 AMAZONBASICS', '804', 'crmebimage/public/open-data/abo-curated-v2/8169-main.jpg', 236.52, 295.65, 130.09, 236, 80, 307, '件', 0.70, 'abo-curated-v2:B01MCY0680:61RftItBI0L'),
(8170, 'B07D12RPHX', '61bCiYn-rfL', 'AmazonBasics Xbox One白色有线手柄', '游戏配件适用平台按源商品标题整理。', '游戏机 AmazonBasics Xbox One白色有线手柄 AmazonBasics', '804', 'crmebimage/public/open-data/abo-curated-v2/8170-main.jpg', 254.04, 317.55, 139.72, 253, 103, 273, '件', 0.80, 'abo-curated-v2:B07D12RPHX:61bCiYn-rfL'),
(8171, 'B07D7TV5J3', '91Qr45nRJAL', 'AmazonBasics 黑色USB电脑音箱', '音箱供电、连接方式与声道按源商品标题整理。', '音响 AmazonBasics 黑色USB电脑音箱 AmazonBasics', '805', 'crmebimage/public/open-data/abo-curated-v2/8171-main.jpg', 239.00, 298.75, 131.45, 270, 126, 340, '套', 1.60, 'abo-curated-v2:B07D7TV5J3:91Qr45nRJAL'),
(8172, 'B07DDGBL5T', '9150Qb9FTwL', 'Amazon Basics 银色USB动态音箱', '音箱供电、连接方式与声道按源商品标题整理。', '音响 Amazon Basics 银色USB动态音箱 Amazonベーシック(AmazonBasics)', '805', 'crmebimage/public/open-data/abo-curated-v2/8172-main.jpg', 258.12, 322.65, 141.97, 287, 149, 306, '套', 1.70, 'abo-curated-v2:B07DDGBL5T:9150Qb9FTwL'),
(8173, 'B00JZVPKE6', '81yxpHbGqnL', 'AmazonBasics 灰色迷你蓝牙音箱', '音箱供电、连接方式与声道按源商品标题整理。', '音响 AmazonBasics 灰色迷你蓝牙音箱 AmazonBasics', '805', 'crmebimage/public/open-data/abo-curated-v2/8173-main.jpg', 277.24, 346.55, 152.48, 304, 172, 272, '套', 1.80, 'abo-curated-v2:B00JZVPKE6:81yxpHbGqnL'),
(8174, 'B07J647XGT', '81eu+GuuyJL', 'AmazonBasics 2.1声道蓝牙低音炮音箱', '音箱供电、连接方式与声道按源商品标题整理。', '音响 AmazonBasics 2.1声道蓝牙低音炮音箱 AmazonBasics', '805', 'crmebimage/public/open-data/abo-curated-v2/8174-main.jpg', 296.36, 370.45, 163.00, 321, 195, 238, '套', 1.90, 'abo-curated-v2:B07J647XGT:81eu+GuuyJL'),
(8175, 'B07S4LYDW8', '813Svcg30lL', 'AmazonBasics 塑料厨房收纳盒4件套', '日用收纳用品材质或包装数量按源商品记录整理。', '日用杂货 AmazonBasics 塑料厨房收纳盒4件套 AmazonBasics', '300', 'crmebimage/public/open-data/abo-curated-v2/8175-main.jpg', 79.00, 98.75, 43.45, 338, 218, 339, '套', 1.20, 'abo-curated-v2:B07S4LYDW8:813Svcg30lL'),
(8176, 'B07QFRBZ1Q', '81ExZL5E+xL', 'AmazonBasics 天然色圆筒布艺收纳篮', '日用收纳用品材质或包装数量按源商品记录整理。', '日用杂货 AmazonBasics 天然色圆筒布艺收纳篮 AmazonBasics', '300', 'crmebimage/public/open-data/abo-curated-v2/8176-main.jpg', 89.00, 111.25, 48.95, 355, 51, 305, '套', 1.30, 'abo-curated-v2:B07QFRBZ1Q:81ExZL5E+xL'),
(8177, 'B07B8NY189', '71HhBRyzBtL', 'Stone & Beam 胡桃木墙面挂钩', '日用收纳用品材质或包装数量按源商品记录整理。', '日用杂货 Stone & Beam 胡桃木墙面挂钩 Stone & Beam', '300', 'crmebimage/public/open-data/abo-curated-v2/8177-main.jpg', 99.00, 123.75, 54.45, 372, 74, 271, '套', 1.40, 'abo-curated-v2:B07B8NY189:71HhBRyzBtL'),
(8178, 'B07K1GVS17', '71RneLfQJ7L', 'AmazonBasics 防滑塑料衣架30只装', '日用收纳用品材质或包装数量按源商品记录整理。', '日用杂货 AmazonBasics 防滑塑料衣架30只装 AmazonBasics', '300', 'crmebimage/public/open-data/abo-curated-v2/8178-main.jpg', 109.00, 136.25, 59.95, 129, 97, 237, '套', 1.50, 'abo-curated-v2:B07K1GVS17:71RneLfQJ7L'),
(8179, 'B07YNJ1CGZ', '81sHh7JOoAL', 'Solimo 双层卷纸6卷装', '纸品层数、抽数或包装数量按源商品标题整理。', '纸品湿巾 Solimo 双层卷纸6卷装 Solimo', '301', 'crmebimage/public/open-data/abo-curated-v2/8179-main.jpg', 59.00, 73.75, 32.45, 146, 120, 338, '提', 2.40, 'abo-curated-v2:B07YNJ1CGZ:81sHh7JOoAL'),
(8180, 'B07RSRBZ26', '81r8fmAhOeL', 'Solimo 双层盒装面巾纸200抽', '纸品层数、抽数或包装数量按源商品标题整理。', '纸品湿巾 Solimo 双层盒装面巾纸200抽 Amazon Brand - Solimo', '301', 'crmebimage/public/open-data/abo-curated-v2/8180-main.jpg', 69.00, 86.25, 37.95, 163, 143, 304, '提', 2.50, 'abo-curated-v2:B07RSRBZ26:81r8fmAhOeL'),
(8181, 'B07XMFVN95', '71b3xX2lsDL', 'Mama Bear 无香婴儿湿巾800片', '纸品层数、抽数或包装数量按源商品标题整理。', '纸品湿巾 Mama Bear 无香婴儿湿巾800片 Mama Bear', '301', 'crmebimage/public/open-data/abo-curated-v2/8181-main.jpg', 79.00, 98.75, 43.45, 180, 166, 270, '提', 2.60, 'abo-curated-v2:B07XMFVN95:71b3xX2lsDL'),
(8182, 'B07JJJHDRY', 'A1OaFIMQ-0L', 'Amazon Basics 金属网格桌面收纳架', '办公用品类型与包装数量按源商品标题整理。', '办公文具 Amazon Basics 金属网格桌面收纳架 Amazonベーシック(AmazonBasics)', '302', 'crmebimage/public/open-data/abo-curated-v2/8182-main.jpg', 69.00, 86.25, 37.95, 197, 189, 337, '套', 0.80, 'abo-curated-v2:B07JJJHDRY:A1OaFIMQ-0L'),
(8183, 'B07KPH8SVS', '71hNdUscifL', 'AmazonBasics 灰色六口袋悬挂文件夹', '办公用品类型与包装数量按源商品标题整理。', '办公文具 AmazonBasics 灰色六口袋悬挂文件夹 AmazonBasics', '302', 'crmebimage/public/open-data/abo-curated-v2/8183-main.jpg', 79.00, 98.75, 43.45, 214, 212, 303, '套', 0.90, 'abo-curated-v2:B07KPH8SVS:71hNdUscifL'),
(8184, 'B07FGNVT1R', '912B3+5rKgL', 'Amazon Basics 4.2毫米修正带8件套', '办公用品类型与包装数量按源商品标题整理。', '办公文具 Amazon Basics 4.2毫米修正带8件套 AmazonBasics', '302', 'crmebimage/public/open-data/abo-curated-v2/8184-main.jpg', 89.00, 111.25, 48.95, 231, 45, 269, '套', 1.00, 'abo-curated-v2:B07FGNVT1R:912B3+5rKgL'),
(8185, 'B07YLTKDD7', '81ry2Fc-1cL', 'AmazonBasics 红色双口袋文件夹10件套', '办公用品类型与包装数量按源商品标题整理。', '办公文具 AmazonBasics 红色双口袋文件夹10件套 AmazonBasics', '302', 'crmebimage/public/open-data/abo-curated-v2/8185-main.jpg', 99.00, 123.75, 54.45, 248, 68, 235, '套', 1.10, 'abo-curated-v2:B07YLTKDD7:81ry2Fc-1cL'),
(8186, 'B00R3IGC68', '914q4wy1maL', 'Amazon Gear 男士长袖V领毛圈套头衫', '服装款式与适用人群按源商品标题整理。', '男装 Amazon Gear 男士长袖V领毛圈套头衫 Amazon Gear', '744', 'crmebimage/public/open-data/abo-curated-v2/8186-main.jpg', 269.00, 336.25, 147.95, 265, 91, 336, '件', 0.80, 'abo-curated-v2:B00R3IGC68:914q4wy1maL'),
(8187, 'B00MFQ4U9E', '91ZIp1MPQnL', 'Amazon Gear 中性全拉链连帽衫', '服装款式与适用人群按源商品标题整理。', '男装 Amazon Gear 中性全拉链连帽衫 Amazon Gear', '744', 'crmebimage/public/open-data/abo-curated-v2/8187-main.jpg', 290.52, 363.15, 159.79, 282, 114, 302, '件', 0.90, 'abo-curated-v2:B00MFQ4U9E:91ZIp1MPQnL'),
(8188, 'B00IJSL7WU', '81iuGL1slcL', 'Amazon Gear 男士条纹Polo衫', '服装款式与适用人群按源商品标题整理。', '男装 Amazon Gear 男士条纹Polo衫 Amazon Gear', '744', 'crmebimage/public/open-data/abo-curated-v2/8188-main.jpg', 312.04, 390.05, 171.62, 299, 137, 268, '件', 1.00, 'abo-curated-v2:B00IJSL7WU:81iuGL1slcL'),
(8189, 'B00IXJMQ8E', '71GfVwLPqoL', 'Amazon Gear 男士中层防风夹克', '服装款式与适用人群按源商品标题整理。', '男装 Amazon Gear 男士中层防风夹克 Amazon Gear', '744', 'crmebimage/public/open-data/abo-curated-v2/8189-main.jpg', 333.56, 416.95, 183.46, 316, 160, 234, '件', 1.10, 'abo-curated-v2:B00IXJMQ8E:71GfVwLPqoL'),
(8190, 'B085BZ3YS8', '81802izksOL', 'JPGO 女士收腹连体塑身衣', '女装款式与颜色按源商品记录整理。', '女装 JPGO 女士收腹连体塑身衣 JPGO', '745', 'crmebimage/public/open-data/abo-curated-v2/8190-main.jpg', 299.00, 373.75, 164.45, 333, 183, 335, '件', 0.70, 'abo-curated-v2:B085BZ3YS8:81802izksOL'),
(8191, 'B08F5FPWR6', '71Miub3nseL', 'CGTL 女士高腰微喇办公瑜伽裤', '女装款式与颜色按源商品记录整理。', '女装 CGTL 女士高腰微喇办公瑜伽裤 CGTL', '745', 'crmebimage/public/open-data/abo-curated-v2/8191-main.jpg', 322.92, 403.65, 177.61, 350, 206, 301, '件', 0.80, 'abo-curated-v2:B08F5FPWR6:71Miub3nseL'),
(8192, 'B00IXJMPB2', '71d3GfqzXwL', 'Amazon Gear 女士Seven J雨衣', '女装款式与颜色按源商品记录整理。', '女装 Amazon Gear 女士Seven J雨衣 Amazon Gear', '745', 'crmebimage/public/open-data/abo-curated-v2/8192-main.jpg', 346.84, 433.55, 190.76, 367, 39, 267, '件', 0.90, 'abo-curated-v2:B00IXJMPB2:71d3GfqzXwL'),
(8193, 'B00J67UZKS', '61OI8P3qTAL', 'Amazon Gear 女士海军蓝中层夹克', '女装款式与颜色按源商品记录整理。', '女装 Amazon Gear 女士海军蓝中层夹克 Amazon Gear', '745', 'crmebimage/public/open-data/abo-curated-v2/8193-main.jpg', 370.76, 463.45, 203.92, 124, 62, 233, '件', 1.00, 'abo-curated-v2:B00J67UZKS:61OI8P3qTAL'),
(8194, 'B07CKWTCG5', '71EkWUrkWPL', 'Carter''s 男童休闲运动鞋', '童鞋款式与颜色按源商品记录整理。', '童鞋 Carter''s 男童休闲运动鞋 Simple Joys by Carter''s', '746', 'crmebimage/public/open-data/abo-curated-v2/8194-main.jpg', 189.00, 236.25, 103.95, 141, 85, 334, '双', 0.50, 'abo-curated-v2:B07CKWTCG5:71EkWUrkWPL'),
(8195, 'B07CKY7WWB', '71DmTPMNJpL', 'Carter''s 女童粉色芭蕾平底鞋', '童鞋款式与颜色按源商品记录整理。', '童鞋 Carter''s 女童粉色芭蕾平底鞋 Simple Joys by Carter''s', '746', 'crmebimage/public/open-data/abo-curated-v2/8195-main.jpg', 204.12, 255.15, 112.27, 158, 108, 300, '双', 0.60, 'abo-curated-v2:B07CKY7WWB:71DmTPMNJpL'),
(8196, 'B07CKWPBNH', '91ey2aSsb7L', 'Carter''s 卡其色儿童冬靴', '童鞋款式与颜色按源商品记录整理。', '童鞋 Carter''s 卡其色儿童冬靴 Simple Joys by Carter''s', '746', 'crmebimage/public/open-data/abo-curated-v2/8196-main.jpg', 219.24, 274.05, 120.58, 175, 131, 266, '双', 0.70, 'abo-curated-v2:B07CKWPBNH:91ey2aSsb7L'),
(8197, 'B0881WNQNH', '81XVFNhRBZL', 'Carter''s 女童粉色针织运动鞋', '童鞋款式与颜色按源商品记录整理。', '童鞋 Carter''s 女童粉色针织运动鞋 Simple Joys by Carter''s', '746', 'crmebimage/public/open-data/abo-curated-v2/8197-main.jpg', 234.36, 292.95, 128.90, 192, 154, 232, '双', 0.80, 'abo-curated-v2:B0881WNQNH:81XVFNhRBZL'),
(8198, 'B0791W6Q8B', '81xVF3bjTXL', 'Symbol 男士运动鞋', '运动鞋款式与颜色按源商品记录整理。', '运动鞋 Symbol 男士运动鞋 Amazon Brand - Symbol', '796', 'crmebimage/public/open-data/abo-curated-v2/8198-main.jpg', 239.00, 298.75, 131.45, 209, 177, 333, '双', 0.70, 'abo-curated-v2:B0791W6Q8B:81xVF3bjTXL'),
(8199, 'B08CKVPSGY', '819agPzrzFL', 'Bourge 男士蓝色跑鞋', '运动鞋款式与颜色按源商品记录整理。', '运动鞋 Bourge 男士蓝色跑鞋 Bourge', '796', 'crmebimage/public/open-data/abo-curated-v2/8199-main.jpg', 258.12, 322.65, 141.97, 226, 200, 299, '双', 0.80, 'abo-curated-v2:B08CKVPSGY:819agPzrzFL'),
(8200, 'B086T2QGT3', '71GL7LNL6zL', 'Klepe 男士白色跑鞋', '运动鞋款式与颜色按源商品记录整理。', '运动鞋 Klepe 男士白色跑鞋 Klepe', '796', 'crmebimage/public/open-data/abo-curated-v2/8200-main.jpg', 277.24, 346.55, 152.48, 243, 223, 265, '双', 0.90, 'abo-curated-v2:B086T2QGT3:71GL7LNL6zL'),
(8201, 'B086T3WLBJ', '81peATVdQlL', 'Klepe 男士纯白跑鞋', '运动鞋款式与颜色按源商品记录整理。', '运动鞋 Klepe 男士纯白跑鞋 Klepe', '796', 'crmebimage/public/open-data/abo-curated-v2/8201-main.jpg', 296.36, 370.45, 163.00, 260, 56, 231, '双', 1.00, 'abo-curated-v2:B086T3WLBJ:81peATVdQlL'),
(8202, 'B01MSCV0FT', '71LVnzuqO8L', 'The Fix 黑色荷叶边绑带高跟凉鞋', '女鞋款式、鞋跟与颜色按源商品记录整理。', '高跟鞋 The Fix 黑色荷叶边绑带高跟凉鞋 The Fix', '797', 'crmebimage/public/open-data/abo-curated-v2/8202-main.jpg', 329.00, 411.25, 180.95, 277, 79, 332, '双', 0.80, 'abo-curated-v2:B01MSCV0FT:71LVnzuqO8L'),
(8203, 'B01MUG39DU', '81AV8NGwPFL', 'The Fix 裸粉透明粗跟凉鞋', '女鞋款式、鞋跟与颜色按源商品记录整理。', '高跟鞋 The Fix 裸粉透明粗跟凉鞋 The Fix', '797', 'crmebimage/public/open-data/abo-curated-v2/8203-main.jpg', 355.32, 444.15, 195.43, 294, 102, 298, '双', 0.90, 'abo-curated-v2:B01MUG39DU:81AV8NGwPFL'),
(8204, 'B01N2B34Z0', '71ApKpbX3eL', '206 Collective 女士高跟踝靴', '女鞋款式、鞋跟与颜色按源商品记录整理。', '高跟鞋 206 Collective 女士高跟踝靴 206 Collective', '797', 'crmebimage/public/open-data/abo-curated-v2/8204-main.jpg', 381.64, 477.05, 209.90, 311, 125, 264, '双', 1.00, 'abo-curated-v2:B01N2B34Z0:71ApKpbX3eL'),
(8205, 'B07D2NPSR9', '91cJXs9PdXL', 'Goodthreads 男士牛仔蓝针织帽', '帽型、颜色与适用人群按源商品记录整理。', '帽子 Goodthreads 男士牛仔蓝针织帽 Goodthreads', '798', 'crmebimage/public/open-data/abo-curated-v2/8205-main.jpg', 99.00, 123.75, 54.45, 328, 148, 331, '顶', 0.30, 'abo-curated-v2:B07D2NPSR9:91cJXs9PdXL'),
(8206, 'B07Q4VQLP5', '71KGx6i9O7L', 'PUMA 中性黑色弹力运动帽', '帽型、颜色与适用人群按源商品记录整理。', '帽子 PUMA 中性黑色弹力运动帽 Care of by Puma', '798', 'crmebimage/public/open-data/abo-curated-v2/8206-main.jpg', 109.00, 136.25, 59.95, 345, 171, 297, '顶', 0.40, 'abo-curated-v2:B07Q4VQLP5:71KGx6i9O7L'),
(8207, 'B07R7W81CH', '917NSTZZJLL', 'Amazon Essentials 黑色仿皮草护耳帽', '帽型、颜色与适用人群按源商品记录整理。', '帽子 Amazon Essentials 黑色仿皮草护耳帽 Amazon Essentials', '798', 'crmebimage/public/open-data/abo-curated-v2/8207-main.jpg', 119.00, 148.75, 65.45, 362, 194, 263, '顶', 0.50, 'abo-curated-v2:B07R7W81CH:917NSTZZJLL'),
(8208, 'B0836HBBJ2', '51QTT-WJWtL', 'JPGO 女士收腹连体塑身衣1411色', '女装款式与颜色按源商品记录整理。', '潮流女装 JPGO 女士收腹连体塑身衣1411色 JPGO', '809', 'crmebimage/public/open-data/abo-curated-v2/8208-main.jpg', 289.00, 361.25, 158.95, 379, 217, 330, '件', 0.60, 'abo-curated-v2:B0836HBBJ2:51QTT-WJWtL'),
(8209, 'B07L5C7P4V', '9169Julq8JL', 'find 女士开衩中长款衬衫裙', '女装款式与颜色按源商品记录整理。', '潮流女装 find 女士开衩中长款衬衫裙 find.', '809', 'crmebimage/public/open-data/abo-curated-v2/8209-main.jpg', 312.12, 390.15, 171.67, 136, 50, 296, '件', 0.70, 'abo-curated-v2:B07L5C7P4V:9169Julq8JL'),
(8210, 'B01HCCNSWU', '91pCPblx5xL', 'JAMES & ERIN 女士深V长裙', '女装款式与颜色按源商品记录整理。', '潮流女装 JAMES & ERIN 女士深V长裙 JAMES & ERIN', '809', 'crmebimage/public/open-data/abo-curated-v2/8210-main.jpg', 335.24, 419.05, 184.38, 153, 73, 262, '件', 0.80, 'abo-curated-v2:B01HCCNSWU:91pCPblx5xL'),
(8211, 'B07JLZC571', '910hnc9azIL', 'Stone & Beam 阳光色条纹装饰抱枕', '抱枕造型、尺寸或颜色按源商品记录整理。', '枕头 Stone & Beam 阳光色条纹装饰抱枕 Stone & Beam', '800', 'crmebimage/public/open-data/abo-curated-v2/8211-main.jpg', 169.00, 211.25, 92.95, 170, 96, 329, '个', 1.00, 'abo-curated-v2:B07JLZC571:910hnc9azIL'),
(8212, 'B07JKJSTVJ', '81QAkzSPz-L', 'Rivet 白色流苏腰枕', '抱枕造型、尺寸或颜色按源商品记录整理。', '枕头 Rivet 白色流苏腰枕 Rivet', '800', 'crmebimage/public/open-data/abo-curated-v2/8212-main.jpg', 182.52, 228.15, 100.39, 187, 119, 295, '个', 1.10, 'abo-curated-v2:B07JKJSTVJ:81QAkzSPz-L'),
(8213, 'B074VLST26', 'A1OiAslM+gL', 'Rivet 天蓝色天鹅绒长方形抱枕', '抱枕造型、尺寸或颜色按源商品记录整理。', '枕头 Rivet 天蓝色天鹅绒长方形抱枕 Rivet', '800', 'crmebimage/public/open-data/abo-curated-v2/8213-main.jpg', 196.04, 245.05, 107.82, 204, 142, 261, '个', 1.20, 'abo-curated-v2:B074VLST26:A1OiAslM+gL'),
(8214, 'B07TCJ4YK1', '91baO-Zo3WL', 'AmazonBasics Origami运动双肩包', '包袋类型、材质或适用尺寸按源商品记录整理。', '箱包 AmazonBasics Origami运动双肩包 AmazonBasics', '801', 'crmebimage/public/open-data/abo-curated-v2/8214-main.jpg', 299.00, 373.75, 164.45, 221, 165, 328, '个', 1.10, 'abo-curated-v2:B07TCJ4YK1:91baO-Zo3WL'),
(8215, 'B07QRZD489', '91p--tZQOsL', 'AmazonBasics 灰色15英寸电脑双肩包', '包袋类型、材质或适用尺寸按源商品记录整理。', '箱包 AmazonBasics 灰色15英寸电脑双肩包 AmazonBasics', '801', 'crmebimage/public/open-data/abo-curated-v2/8215-main.jpg', 322.92, 403.65, 177.61, 238, 188, 294, '个', 1.20, 'abo-curated-v2:B07QRZD489:91p--tZQOsL'),
(8216, 'B06WRPKD88', '91zxIlJkmfL', 'The Fix 橙红色真皮圆形斜挎包', '包袋类型、材质或适用尺寸按源商品记录整理。', '箱包 The Fix 橙红色真皮圆形斜挎包 The Fix', '801', 'crmebimage/public/open-data/abo-curated-v2/8216-main.jpg', 346.84, 433.55, 190.76, 255, 211, 260, '个', 1.30, 'abo-curated-v2:B06WRPKD88:91zxIlJkmfL'),
(8217, 'B06XPF6V5G', '81M3gjq3gGL', 'The Fix 黑蓝拼色手提包', '包袋类型、材质或适用尺寸按源商品记录整理。', '箱包 The Fix 黑蓝拼色手提包 The Fix', '801', 'crmebimage/public/open-data/abo-curated-v2/8217-main.jpg', 370.76, 463.45, 203.92, 272, 44, 226, '个', 1.40, 'abo-curated-v2:B06XPF6V5G:81M3gjq3gGL'),
(8218, 'B07R7G6M7N', '91BNU4+ciCL', 'AmazonBasics 红色28英寸硬壳行李箱', '旅行用品类型、尺寸与颜色按源商品记录整理。', '出行必备 AmazonBasics 红色28英寸硬壳行李箱 AmazonBasics', '802', 'crmebimage/public/open-data/abo-curated-v2/8218-main.jpg', 499.00, 623.75, 274.45, 289, 67, 327, '件', 3.60, 'abo-curated-v2:B07R7G6M7N:91BNU4+ciCL'),
(8219, 'B07FD762RS', '91IJTCsTRrL', 'AmazonBasics 黑色三折悬挂西装袋', '旅行用品类型、尺寸与颜色按源商品记录整理。', '出行必备 AmazonBasics 黑色三折悬挂西装袋 AmazonBasics', '802', 'crmebimage/public/open-data/abo-curated-v2/8219-main.jpg', 538.92, 673.65, 296.41, 306, 90, 293, '件', 3.70, 'abo-curated-v2:B07FD762RS:91IJTCsTRrL'),
(8220, 'B07GNJLHCW', '81pvo2-dHzL', 'AmazonBasics 绿色几何硬壳行李箱两件套', '旅行用品类型、尺寸与颜色按源商品记录整理。', '出行必备 AmazonBasics 绿色几何硬壳行李箱两件套 AmazonBasics', '802', 'crmebimage/public/open-data/abo-curated-v2/8220-main.jpg', 578.84, 723.55, 318.36, 323, 113, 259, '件', 3.80, 'abo-curated-v2:B07GNJLHCW:81pvo2-dHzL');

DROP TEMPORARY TABLE IF EXISTS tmp_demo_skus;
CREATE TEMPORARY TABLE tmp_demo_skus (
    id INT PRIMARY KEY,
    product_id INT NOT NULL,
    attr_id INT NOT NULL,
    option_id INT NOT NULL,
    attr_name VARCHAR(32) NOT NULL,
    attr_value VARCHAR(32) NOT NULL,
    unique_key CHAR(8) NOT NULL,
    bar_code VARCHAR(50) NOT NULL,
    UNIQUE KEY uk_demo_sku_product (product_id)
) ENGINE = MEMORY;

INSERT INTO tmp_demo_skus VALUES
(28101, 8101, 18101, 38101, '款式', '图示款', 'D0000001', 'D8101'),
(28102, 8102, 18102, 38102, '款式', '图示款', 'D0000002', 'D8102'),
(28103, 8103, 18103, 38103, '款式', '图示款', 'D0000003', 'D8103'),
(28104, 8104, 18104, 38104, '款式', '图示款', 'D0000004', 'D8104'),
(28105, 8105, 18105, 38105, '款式', '图示款', 'D0000005', 'D8105'),
(28106, 8106, 18106, 38106, '款式', '图示款', 'D0000006', 'D8106'),
(28107, 8107, 18107, 38107, '款式', '图示款', 'D0000007', 'D8107'),
(28108, 8108, 18108, 38108, '款式', '图示款', 'D0000008', 'D8108'),
(28109, 8109, 18109, 38109, '款式', '图示款', 'D0000009', 'D8109'),
(28110, 8110, 18110, 38110, '款式', '图示款', 'D0000010', 'D8110'),
(28111, 8111, 18111, 38111, '款式', '图示款', 'D0000011', 'D8111'),
(28112, 8112, 18112, 38112, '款式', '图示款', 'D0000012', 'D8112'),
(28113, 8113, 18113, 38113, '款式', '图示款', 'D0000013', 'D8113'),
(28114, 8114, 18114, 38114, '款式', '图示款', 'D0000014', 'D8114'),
(28115, 8115, 18115, 38115, '款式', '图示款', 'D0000015', 'D8115'),
(28116, 8116, 18116, 38116, '款式', '图示款', 'D0000016', 'D8116'),
(28117, 8117, 18117, 38117, '款式', '图示款', 'D0000017', 'D8117'),
(28118, 8118, 18118, 38118, '款式', '图示款', 'D0000018', 'D8118'),
(28119, 8119, 18119, 38119, '款式', '图示款', 'D0000019', 'D8119'),
(28120, 8120, 18120, 38120, '款式', '图示款', 'D0000020', 'D8120'),
(28121, 8121, 18121, 38121, '款式', '图示款', 'D0000021', 'D8121'),
(28122, 8122, 18122, 38122, '款式', '图示款', 'D0000022', 'D8122'),
(28123, 8123, 18123, 38123, '款式', '图示款', 'D0000023', 'D8123'),
(28124, 8124, 18124, 38124, '款式', '图示款', 'D0000024', 'D8124'),
(28125, 8125, 18125, 38125, '款式', '图示款', 'D0000025', 'D8125'),
(28126, 8126, 18126, 38126, '款式', '图示款', 'D0000026', 'D8126'),
(28127, 8127, 18127, 38127, '款式', '图示款', 'D0000027', 'D8127'),
(28128, 8128, 18128, 38128, '款式', '图示款', 'D0000028', 'D8128'),
(28129, 8129, 18129, 38129, '款式', '图示款', 'D0000029', 'D8129'),
(28130, 8130, 18130, 38130, '款式', '图示款', 'D0000030', 'D8130'),
(28131, 8131, 18131, 38131, '款式', '图示款', 'D0000031', 'D8131'),
(28132, 8132, 18132, 38132, '款式', '图示款', 'D0000032', 'D8132'),
(28133, 8133, 18133, 38133, '款式', '图示款', 'D0000033', 'D8133'),
(28134, 8134, 18134, 38134, '款式', '图示款', 'D0000034', 'D8134'),
(28135, 8135, 18135, 38135, '款式', '图示款', 'D0000035', 'D8135'),
(28136, 8136, 18136, 38136, '款式', '图示款', 'D0000036', 'D8136'),
(28137, 8137, 18137, 38137, '款式', '图示款', 'D0000037', 'D8137'),
(28138, 8138, 18138, 38138, '款式', '图示款', 'D0000038', 'D8138'),
(28139, 8139, 18139, 38139, '款式', '图示款', 'D0000039', 'D8139'),
(28140, 8140, 18140, 38140, '款式', '图示款', 'D0000040', 'D8140'),
(28141, 8141, 18141, 38141, '款式', '图示款', 'D0000041', 'D8141'),
(28142, 8142, 18142, 38142, '款式', '图示款', 'D0000042', 'D8142'),
(28143, 8143, 18143, 38143, '款式', '图示款', 'D0000043', 'D8143'),
(28144, 8144, 18144, 38144, '款式', '图示款', 'D0000044', 'D8144'),
(28145, 8145, 18145, 38145, '款式', '图示款', 'D0000045', 'D8145'),
(28146, 8146, 18146, 38146, '款式', '图示款', 'D0000046', 'D8146'),
(28147, 8147, 18147, 38147, '款式', '图示款', 'D0000047', 'D8147'),
(28148, 8148, 18148, 38148, '款式', '图示款', 'D0000048', 'D8148'),
(28149, 8149, 18149, 38149, '款式', '图示款', 'D0000049', 'D8149'),
(28150, 8150, 18150, 38150, '款式', '图示款', 'D0000050', 'D8150'),
(28151, 8151, 18151, 38151, '款式', '图示款', 'D0000051', 'D8151'),
(28152, 8152, 18152, 38152, '款式', '图示款', 'D0000052', 'D8152'),
(28153, 8153, 18153, 38153, '款式', '图示款', 'D0000053', 'D8153'),
(28154, 8154, 18154, 38154, '款式', '图示款', 'D0000054', 'D8154'),
(28155, 8155, 18155, 38155, '款式', '图示款', 'D0000055', 'D8155'),
(28156, 8156, 18156, 38156, '款式', '图示款', 'D0000056', 'D8156'),
(28157, 8157, 18157, 38157, '款式', '图示款', 'D0000057', 'D8157'),
(28158, 8158, 18158, 38158, '款式', '图示款', 'D0000058', 'D8158'),
(28159, 8159, 18159, 38159, '款式', '图示款', 'D0000059', 'D8159'),
(28160, 8160, 18160, 38160, '款式', '图示款', 'D0000060', 'D8160'),
(28161, 8161, 18161, 38161, '款式', '图示款', 'D0000061', 'D8161'),
(28162, 8162, 18162, 38162, '款式', '图示款', 'D0000062', 'D8162'),
(28163, 8163, 18163, 38163, '款式', '图示款', 'D0000063', 'D8163'),
(28164, 8164, 18164, 38164, '款式', '图示款', 'D0000064', 'D8164'),
(28165, 8165, 18165, 38165, '款式', '图示款', 'D0000065', 'D8165'),
(28166, 8166, 18166, 38166, '款式', '图示款', 'D0000066', 'D8166'),
(28167, 8167, 18167, 38167, '款式', '图示款', 'D0000067', 'D8167'),
(28168, 8168, 18168, 38168, '款式', '图示款', 'D0000068', 'D8168'),
(28169, 8169, 18169, 38169, '款式', '图示款', 'D0000069', 'D8169'),
(28170, 8170, 18170, 38170, '款式', '图示款', 'D0000070', 'D8170'),
(28171, 8171, 18171, 38171, '款式', '图示款', 'D0000071', 'D8171'),
(28172, 8172, 18172, 38172, '款式', '图示款', 'D0000072', 'D8172'),
(28173, 8173, 18173, 38173, '款式', '图示款', 'D0000073', 'D8173'),
(28174, 8174, 18174, 38174, '款式', '图示款', 'D0000074', 'D8174'),
(28175, 8175, 18175, 38175, '款式', '图示款', 'D0000075', 'D8175'),
(28176, 8176, 18176, 38176, '款式', '图示款', 'D0000076', 'D8176'),
(28177, 8177, 18177, 38177, '款式', '图示款', 'D0000077', 'D8177'),
(28178, 8178, 18178, 38178, '款式', '图示款', 'D0000078', 'D8178'),
(28179, 8179, 18179, 38179, '款式', '图示款', 'D0000079', 'D8179'),
(28180, 8180, 18180, 38180, '款式', '图示款', 'D0000080', 'D8180'),
(28181, 8181, 18181, 38181, '款式', '图示款', 'D0000081', 'D8181'),
(28182, 8182, 18182, 38182, '款式', '图示款', 'D0000082', 'D8182'),
(28183, 8183, 18183, 38183, '款式', '图示款', 'D0000083', 'D8183'),
(28184, 8184, 18184, 38184, '款式', '图示款', 'D0000084', 'D8184'),
(28185, 8185, 18185, 38185, '款式', '图示款', 'D0000085', 'D8185'),
(28186, 8186, 18186, 38186, '款式', '图示款', 'D0000086', 'D8186'),
(28187, 8187, 18187, 38187, '款式', '图示款', 'D0000087', 'D8187'),
(28188, 8188, 18188, 38188, '款式', '图示款', 'D0000088', 'D8188'),
(28189, 8189, 18189, 38189, '款式', '图示款', 'D0000089', 'D8189'),
(28190, 8190, 18190, 38190, '款式', '图示款', 'D0000090', 'D8190'),
(28191, 8191, 18191, 38191, '款式', '图示款', 'D0000091', 'D8191'),
(28192, 8192, 18192, 38192, '款式', '图示款', 'D0000092', 'D8192'),
(28193, 8193, 18193, 38193, '款式', '图示款', 'D0000093', 'D8193'),
(28194, 8194, 18194, 38194, '款式', '图示款', 'D0000094', 'D8194'),
(28195, 8195, 18195, 38195, '款式', '图示款', 'D0000095', 'D8195'),
(28196, 8196, 18196, 38196, '款式', '图示款', 'D0000096', 'D8196'),
(28197, 8197, 18197, 38197, '款式', '图示款', 'D0000097', 'D8197'),
(28198, 8198, 18198, 38198, '款式', '图示款', 'D0000098', 'D8198'),
(28199, 8199, 18199, 38199, '款式', '图示款', 'D0000099', 'D8199'),
(28200, 8200, 18200, 38200, '款式', '图示款', 'D0000100', 'D8200'),
(28201, 8201, 18201, 38201, '款式', '图示款', 'D0000101', 'D8201'),
(28202, 8202, 18202, 38202, '款式', '图示款', 'D0000102', 'D8202'),
(28203, 8203, 18203, 38203, '款式', '图示款', 'D0000103', 'D8203'),
(28204, 8204, 18204, 38204, '款式', '图示款', 'D0000104', 'D8204'),
(28205, 8205, 18205, 38205, '款式', '图示款', 'D0000105', 'D8205'),
(28206, 8206, 18206, 38206, '款式', '图示款', 'D0000106', 'D8206'),
(28207, 8207, 18207, 38207, '款式', '图示款', 'D0000107', 'D8207'),
(28208, 8208, 18208, 38208, '款式', '图示款', 'D0000108', 'D8208'),
(28209, 8209, 18209, 38209, '款式', '图示款', 'D0000109', 'D8209'),
(28210, 8210, 18210, 38210, '款式', '图示款', 'D0000110', 'D8210'),
(28211, 8211, 18211, 38211, '款式', '图示款', 'D0000111', 'D8211'),
(28212, 8212, 18212, 38212, '款式', '图示款', 'D0000112', 'D8212'),
(28213, 8213, 18213, 38213, '款式', '图示款', 'D0000113', 'D8213'),
(28214, 8214, 18214, 38214, '款式', '图示款', 'D0000114', 'D8214'),
(28215, 8215, 18215, 38215, '款式', '图示款', 'D0000115', 'D8215'),
(28216, 8216, 18216, 38216, '款式', '图示款', 'D0000116', 'D8216'),
(28217, 8217, 18217, 38217, '款式', '图示款', 'D0000117', 'D8217'),
(28218, 8218, 18218, 38218, '款式', '图示款', 'D0000118', 'D8218'),
(28219, 8219, 18219, 38219, '款式', '图示款', 'D0000119', 'D8219'),
(28220, 8220, 18220, 38220, '款式', '图示款', 'D0000120', 'D8220');

SET @demo_product_count = (SELECT COUNT(*) FROM tmp_demo_products);
-- END GENERATED ABO CURATED V2 PRODUCTS

-- Products, variants and rich detail content.
INSERT INTO eb_store_product (
    id, mer_id, image, slider_image, store_name, store_info, keyword, bar_code, cate_id,
    price, vip_price, ot_price, postage, unit_name, sort, sales, stock, is_show, is_hot,
    is_benefit, is_best, is_new, add_time, is_postage, is_del, mer_use, give_integral,
    cost, is_seckill, is_bargain, is_good, is_sub, ficti, browse, code_path, soure_link,
    video_link, temp_id, spec_type, activity, flat_pattern, is_recycle, version, guarantee_ids
)
SELECT
    p.id, 0, p.image, JSON_ARRAY(p.image), p.store_name, p.store_info, p.keyword,
    CONCAT('D', p.id), p.cate_id, p.price, ROUND(p.price * 0.95, 2), p.ot_price, 0,
    p.unit_name, p.sort_num, p.sales, p.stock, 1, IF(MOD(p.id, 3) = 0, 1, 0),
    IF(MOD(p.id, 4) = 0, 1, 0), IF(MOD(p.id, 5) = 0, 1, 0), IF(MOD(p.id, 2) = 0, 1, 0),
    UNIX_TIMESTAMP(DATE_SUB(@seed_now, INTERVAL MOD(p.id, 45) DAY)), 1, 0, 0,
    FLOOR(p.price / 10), p.cost,
    IF(MOD(p.id - 8101, 7) = 0, 1, 0), IF(MOD(p.id - 8101, 9) = 4, 1, 0),
    IF(MOD(p.id, 4) = 1, 1, 0), 0,
    FLOOR(p.sales * 0.35), 900 + MOD(p.id * 37, 1800), '', p.source_marker, '', 1, 0,
    '0,1,2,3', p.image, 0, 0, '0'
FROM tmp_demo_products p;

INSERT INTO eb_store_product_attr
    (id, product_id, attr_name, attr_values, type, is_del, is_show_image)
SELECT s.attr_id, s.product_id, s.attr_name, s.attr_value, 0, 0, 1
FROM tmp_demo_skus s;

INSERT INTO eb_store_product_attr_option
    (id, product_id, attr_id, option_name, image, sort, is_del)
SELECT s.option_id, s.product_id, s.attr_id, s.attr_value, p.image, 1, 0
FROM tmp_demo_skus s
JOIN tmp_demo_products p ON p.id = s.product_id;

INSERT INTO eb_store_product_attr_value (
    id, product_id, suk, stock, sales, price, image, `unique`, cost, bar_code, ot_price,
    weight, volume, brokerage, brokerage_two, type, quota, quota_show, attr_value,
    is_del, version, is_default, is_show
)
SELECT
    s.id, p.id, s.attr_value, p.stock, p.sales, p.price, p.image, s.unique_key, p.cost,
    s.bar_code, p.ot_price, p.weight, 0, ROUND(p.price * 0.06, 2),
    ROUND(p.price * 0.02, 2), 0, 0, 0, JSON_OBJECT(s.attr_name, s.attr_value),
    0, 0, 1, 1
FROM tmp_demo_skus s
JOIN tmp_demo_products p ON p.id = s.product_id;

INSERT INTO eb_store_product_description (id, product_id, description, type)
SELECT
    s.attr_id, p.id,
    CONCAT(
        '<section style="line-height:1.8;color:#333"><h2>', p.store_name,
        '</h2><p>', p.store_info,
        '</p><img src="http://127.0.0.1:8080/', p.image,
        '" style="width:100%;height:auto;display:block" />',
        '<h3>数据来源与许可</h3><p>商品元数据与图像来自 Amazon Berkeley Objects（ABO），',
        '来源标识：', p.item_id, ' / ', p.main_image_id, '。依据 CC BY 4.0 使用，',
        '本项目进行了中文标题整理和 800x800 白底归一化；价格、库存与销量为本地演示值。',
        'Amazon.com 与数据集构建者不为本项目背书。</p>',
        '<p><a href="https://amazon-berkeley-objects.s3.amazonaws.com/index.html">ABO 数据集</a> · ',
        '<a href="https://creativecommons.org/licenses/by/4.0/">CC BY 4.0</a></p></section>'
    ),
    0
FROM tmp_demo_products p
JOIN tmp_demo_skus s ON s.product_id = p.id;

-- Seckill: 12 activities.
DROP TEMPORARY TABLE IF EXISTS tmp_demo_seckill;
CREATE TEMPORARY TABLE tmp_demo_seckill (
    id INT PRIMARY KEY, product_id INT NOT NULL, time_id INT NOT NULL, discount DECIMAL(5, 2) NOT NULL
) ENGINE = MEMORY;
INSERT INTO tmp_demo_seckill (id, product_id, time_id, discount)
SELECT 8100 + n, 8101 + (n - 1) * 7, 1 + MOD(n, 3), CAST(0.70 + MOD(n, 4) * 0.03 AS DECIMAL(5, 2))
FROM tmp_demo_numbers WHERE n <= 12;

INSERT INTO eb_store_seckill (
    id, product_id, image, images, title, info, price, cost, ot_price, give_integral,
    sort, stock, sales, unit_name, postage, description, start_time, stop_time, create_time,
    status, is_postage, is_del, num, is_show, time_id, temp_id, weight, volume,
    quota, quota_show, spec_type
)
SELECT
    s.id, p.id, p.image, JSON_ARRAY(p.image), CONCAT('限时秒杀 · ', p.store_name),
    CONCAT('限量直降，售完即止：', p.store_info), ROUND(p.price * s.discount, 2), p.cost,
    p.ot_price, FLOOR(p.price / 20), 100 - (s.id - 8100), 68, 20 + (s.id - 8100) * 3,
    p.unit_name, 0,
    CONCAT('<p>限时秒杀活动商品：', p.store_name, '</p><img src="http://127.0.0.1:8080/', p.image, '" style="width:100%" />'),
    DATE_SUB(@seed_now, INTERVAL 1 DAY), DATE_ADD(@seed_now, INTERVAL 30 DAY), @seed_now,
    1, 1, 0, 3, 1, s.time_id, 1, p.weight, 0, 68, 68, 0
FROM tmp_demo_seckill s
JOIN tmp_demo_products p ON p.id = s.product_id;

INSERT INTO eb_store_product_attr
    (id, product_id, attr_name, attr_values, type, is_del, is_show_image)
SELECT 18600 + (s.id - 8100), s.id, sku.attr_name, sku.attr_value, 1, 0, 1
FROM tmp_demo_seckill s
JOIN tmp_demo_skus sku ON sku.product_id = s.product_id;

INSERT INTO eb_store_product_attr_option
    (id, product_id, attr_id, option_name, image, sort, is_del)
SELECT 39000 + (s.id - 8100), s.id, 18600 + (s.id - 8100), sku.attr_value, p.image, 1, 0
FROM tmp_demo_seckill s
JOIN tmp_demo_products p ON p.id = s.product_id
JOIN tmp_demo_skus sku ON sku.product_id = p.id;

INSERT INTO eb_store_product_attr_value (
    id, product_id, suk, stock, sales, price, image, `unique`, cost, bar_code, ot_price,
    weight, volume, brokerage, brokerage_two, type, quota, quota_show, attr_value,
    is_del, version, is_default, is_show
)
SELECT
    30000 + (s.id - 8100), s.id, sku.attr_value, 40, 12, ROUND(p.price * s.discount, 2),
    p.image, CONCAT('S', LPAD(s.id - 8100, 7, '0')), p.cost, CONCAT('S', s.id),
    p.ot_price, p.weight, 0, 0, 0, 1, 40, 40, JSON_OBJECT(sku.attr_name, sku.attr_value),
    0, 0, 1, 1
FROM tmp_demo_seckill s
JOIN tmp_demo_products p ON p.id = s.product_id
JOIN tmp_demo_skus sku ON sku.product_id = p.id;

INSERT INTO eb_store_product_description (id, product_id, description, type)
SELECT
    18600 + (s.id - 8100), s.id,
    CONCAT('<p>限时秒杀：', p.store_name, '</p><img src="http://127.0.0.1:8080/', p.image, '" style="width:100%" />'),
    1
FROM tmp_demo_seckill s JOIN tmp_demo_products p ON p.id = s.product_id;

-- Bargain: 10 activities.
DROP TEMPORARY TABLE IF EXISTS tmp_demo_bargain;
CREATE TEMPORARY TABLE tmp_demo_bargain (
    id INT PRIMARY KEY, product_id INT NOT NULL, discount DECIMAL(5, 2) NOT NULL
) ENGINE = MEMORY;
INSERT INTO tmp_demo_bargain (id, product_id, discount)
SELECT 8100 + n, 8105 + (n - 1) * 9, CAST(0.55 + MOD(n, 4) * 0.04 AS DECIMAL(5, 2))
FROM tmp_demo_numbers WHERE n <= 10;

INSERT INTO eb_store_bargain (
    id, product_id, title, image, unit_name, stock, sales, images, start_time, stop_time,
    store_name, price, min_price, num, bargain_max_price, bargain_min_price, bargain_num,
    status, give_integral, info, cost, sort, is_hot, is_del, add_time, is_postage, postage,
    rule, look, share, temp_id, weight, volume, quota, quota_show, people_num
)
SELECT
    b.id, p.id, CONCAT('好友助力砍价 · ', p.store_name), p.image, p.unit_name, 52,
    12 + (b.id - 8100) * 4, JSON_ARRAY(p.image), UNIX_TIMESTAMP(DATE_SUB(@seed_now, INTERVAL 1 DAY)) * 1000,
    UNIX_TIMESTAMP(DATE_ADD(@seed_now, INTERVAL 30 DAY)) * 1000, p.store_name, p.price,
    ROUND(p.price * b.discount, 2), 1, ROUND(p.price * 0.08, 2), ROUND(p.price * 0.02, 2),
    1, 1, FLOOR(p.price / 20), CONCAT('邀请好友助力，最低可砍至 ', ROUND(p.price * b.discount, 2), ' 元'),
    p.cost, 90 - (b.id - 8100), 1, 0, UNIX_TIMESTAMP(@seed_now) * 1000, 1, 0,
    '每位好友可助力一次，达到目标人数后按最低价购买。', 680 + (b.id - 8100) * 73,
    45 + (b.id - 8100) * 6, 1, p.weight, 0, 52, 52, 5
FROM tmp_demo_bargain b JOIN tmp_demo_products p ON p.id = b.product_id;

INSERT INTO eb_store_product_attr
    (id, product_id, attr_name, attr_values, type, is_del, is_show_image)
SELECT 18700 + (b.id - 8100), b.id, sku.attr_name, sku.attr_value, 2, 0, 1
FROM tmp_demo_bargain b
JOIN tmp_demo_skus sku ON sku.product_id = b.product_id;

INSERT INTO eb_store_product_attr_option
    (id, product_id, attr_id, option_name, image, sort, is_del)
SELECT 40000 + (b.id - 8100), b.id, 18700 + (b.id - 8100), sku.attr_value, p.image, 1, 0
FROM tmp_demo_bargain b
JOIN tmp_demo_products p ON p.id = b.product_id
JOIN tmp_demo_skus sku ON sku.product_id = p.id;

INSERT INTO eb_store_product_attr_value (
    id, product_id, suk, stock, sales, price, image, `unique`, cost, bar_code, ot_price,
    weight, volume, brokerage, brokerage_two, type, quota, quota_show, attr_value,
    is_del, version, is_default, is_show
)
SELECT
    32000 + (b.id - 8100), b.id, sku.attr_value, 52, 14, ROUND(p.price * b.discount, 2),
    p.image, CONCAT('B', LPAD(b.id - 8100, 7, '0')), p.cost, CONCAT('B', b.id),
    p.ot_price, p.weight, 0, 0, 0, 2, 52, 52, JSON_OBJECT(sku.attr_name, sku.attr_value),
    0, 0, 1, 1
FROM tmp_demo_bargain b
JOIN tmp_demo_products p ON p.id = b.product_id
JOIN tmp_demo_skus sku ON sku.product_id = p.id;

INSERT INTO eb_store_product_description (id, product_id, description, type)
SELECT
    18700 + (b.id - 8100), b.id,
    CONCAT('<p>好友助力砍价：', p.store_name, '</p><img src="http://127.0.0.1:8080/', p.image, '" style="width:100%" />'),
    2
FROM tmp_demo_bargain b JOIN tmp_demo_products p ON p.id = b.product_id;

-- Group buy: 10 activities.
DROP TEMPORARY TABLE IF EXISTS tmp_demo_combination;
CREATE TEMPORARY TABLE tmp_demo_combination (
    id INT PRIMARY KEY, product_id INT NOT NULL, people INT NOT NULL, discount DECIMAL(5, 2) NOT NULL
) ENGINE = MEMORY;
INSERT INTO tmp_demo_combination (id, product_id, people, discount)
SELECT 8100 + n, 8107 + (n - 1) * 10, 2 + MOD(n, 2), CAST(0.72 + MOD(n, 3) * 0.03 AS DECIMAL(5, 2))
FROM tmp_demo_numbers WHERE n <= 10;

INSERT INTO eb_store_combination (
    id, product_id, mer_id, image, images, title, attr, people, info, price, sort, sales,
    stock, add_time, is_host, is_show, is_del, combination, mer_use, is_postage, postage,
    start_time, stop_time, effective_time, cost, browse, unit_name, temp_id, weight, volume,
    num, quota, quota_show, ot_price, once_num, virtual_ration
)
SELECT
    c.id, p.id, 0, p.image, JSON_ARRAY(p.image), CONCAT(c.people, '人拼团 · ', p.store_name),
    sku.attr_value, c.people, CONCAT('邀请好友成团，', p.store_info), ROUND(p.price * c.discount, 2),
    80 - (c.id - 8100), 20 + (c.id - 8100) * 5, 72,
    UNIX_TIMESTAMP(@seed_now) * 1000, 1, 1, 0, 1, 0, 1, 0,
    UNIX_TIMESTAMP(DATE_SUB(@seed_now, INTERVAL 1 DAY)) * 1000,
    UNIX_TIMESTAMP(DATE_ADD(@seed_now, INTERVAL 30 DAY)) * 1000, 24, p.cost,
    720 + (c.id - 8100) * 89, p.unit_name, 1, p.weight, 0, 1, 72, 72, p.ot_price, 1, 100
FROM tmp_demo_combination c
JOIN tmp_demo_products p ON p.id = c.product_id
JOIN tmp_demo_skus sku ON sku.product_id = p.id;

INSERT INTO eb_store_product_attr
    (id, product_id, attr_name, attr_values, type, is_del, is_show_image)
SELECT 18800 + (c.id - 8100), c.id, sku.attr_name, sku.attr_value, 3, 0, 1
FROM tmp_demo_combination c
JOIN tmp_demo_skus sku ON sku.product_id = c.product_id;

INSERT INTO eb_store_product_attr_option
    (id, product_id, attr_id, option_name, image, sort, is_del)
SELECT 41000 + (c.id - 8100), c.id, 18800 + (c.id - 8100), sku.attr_value, p.image, 1, 0
FROM tmp_demo_combination c
JOIN tmp_demo_products p ON p.id = c.product_id
JOIN tmp_demo_skus sku ON sku.product_id = p.id;

INSERT INTO eb_store_product_attr_value (
    id, product_id, suk, stock, sales, price, image, `unique`, cost, bar_code, ot_price,
    weight, volume, brokerage, brokerage_two, type, quota, quota_show, attr_value,
    is_del, version, is_default, is_show
)
SELECT
    34000 + (c.id - 8100), c.id, sku.attr_value, 48, 14, ROUND(p.price * c.discount, 2),
    p.image, CONCAT('C', LPAD(c.id - 8100, 7, '0')), p.cost, CONCAT('C', c.id),
    p.ot_price, p.weight, 0, 0, 0, 3, 48, 48, JSON_OBJECT(sku.attr_name, sku.attr_value),
    0, 0, 1, 1
FROM tmp_demo_combination c
JOIN tmp_demo_products p ON p.id = c.product_id
JOIN tmp_demo_skus sku ON sku.product_id = p.id;

INSERT INTO eb_store_product_description (id, product_id, description, type)
SELECT
    18800 + (c.id - 8100), c.id,
    CONCAT('<p>多人拼团活动：', p.store_name, '</p><img src="http://127.0.0.1:8080/', p.image, '" style="width:100%" />'),
    3
FROM tmp_demo_combination c JOIN tmp_demo_products p ON p.id = c.product_id;

-- Users, addresses and account activity.
INSERT INTO eb_user (
    uid, account, pwd, real_name, birthday, card_id, mark, partner_id, group_id, tag_id,
    nickname, avatar, phone, add_ip, last_ip, now_money, brokerage_price, integral,
    experience, sign_num, status, level, spread_uid, spread_time, user_type, is_promoter,
    pay_count, spread_count, addres, adminid, login_type, create_time, update_time,
    last_login_time, path, subscribe, subscribe_time, sex, country, promoter_time,
    is_logoff
)
SELECT
    8100 + n, CONCAT('138', LPAD(800000 + n, 8, '0')),
    'b34Evwm5B/w=',
    ELT(MOD(n - 1, 20) + 1, '林晓雨', '陈子轩', '周可欣', '王一诺', '李沐阳', '赵思涵', '孙嘉乐', '吴若溪', '郑皓宇', '冯语桐',
        '蒋文博', '沈依然', '韩景行', '许安琪', '何俊熙', '高雨晴', '罗嘉佑', '梁梦瑶', '宋知远', '唐心悦'),
    DATE_FORMAT(DATE_SUB('2000-01-01', INTERVAL MOD(n * 173, 5000) DAY), '%Y-%m-%d'),
    '', @demo_tag, NULL, IF(MOD(n, 4) = 0, '2', '1'), IF(MOD(n, 3) = 0, '3', ''),
    ELT(MOD(n - 1, 20) + 1, '小雨同学', '橙子汽水', '可可日记', '一诺生活家', '木阳', '思思', '嘉乐同学', '若溪', '皓宇', '语桐',
        '文博', '依然', '景行', '安琪', '俊熙', '雨晴', '嘉佑', '梦瑶', '知远', '心悦'),
    ELT(MOD(n - 1, 11) + 1,
        'crmebimage/public/user/2025/05/30/4acd024b82a141649cd440a2b2eaadc44un1zxh7l7.png',
        'crmebimage/public/user/2025/11/05/64c22548a6824e90a45669be579ace13n481dyed9k.png',
        'crmebimage/public/user/2025/11/07/3b359670a28e429db46eec57e3b0b2ddugxv49lz0e.png',
        'crmebimage/public/user/2025/11/08/5e1e26445c8341f1b399d56349cfc037g21falarrm.png',
        'crmebimage/public/user/2025/10/29/b6963b7a01194f39929d23ac2a56b609tkd2yow4oq.jpg',
        'crmebimage/public/user/2025/10/29/774bb969e9bc49e4a9d91361b19db54cyaxk1ruo53.jpeg',
        'crmebimage/public/user/2025/10/17/3638df0690b34928bcb77084ba00a446mm0i1fqk8m.jpg',
        'crmebimage/public/user/2025/10/17/a6665aef5de643448cc2cf6edb86fce13frz1e1rtt.png',
        'crmebimage/public/user/2025/10/21/fde97edebbd94ee4a8ca64db2f2e27e7lb9s5vdnj0.png',
        'crmebimage/public/user/2025/10/15/e43ebbd9bcf64f2dbe5824c00164e6d0qww1i5fb8j.png',
        'crmebimage/public/user/2025/10/15/26b40aa6ca7b40779991fd87510a02483vzailsprp.jpg'
    ),
    CONCAT('138', LPAD(800000 + n, 8, '0')), CONCAT('10.0.', MOD(n, 250), '.', n),
    CONCAT('10.1.', MOD(n, 250), '.', n),
    50 + n * 13.50, IF(MOD(n, 5) = 0, 66.80 + n, 0), 180 + n * 37,
    260 + n * 51, MOD(n, 12), 1, MOD(n, 4),
    IF(n > 1 AND MOD(n, 3) = 0, 8101, 0),
    IF(n > 1 AND MOD(n, 3) = 0, DATE_SUB(@seed_now, INTERVAL n * 2 DAY), NULL),
    'h5', IF(MOD(n, 5) = 0, 1, 0), 0, IF(n = 1, 6, 0),
    ELT(MOD(n - 1, 5) + 1, '上海市浦东新区', '北京市朝阳区', '杭州市余杭区', '深圳市南山区', '成都市武侯区'),
    0, 'h5', DATE_SUB(@seed_now, INTERVAL 30 + n * 4 DAY), @seed_now,
    DATE_SUB(@seed_now, INTERVAL MOD(n, 7) DAY),
    IF(n > 1 AND MOD(n, 3) = 0, '/0/8101/', '/0/'), IF(MOD(n, 2) = 0, 1, 0),
    IF(MOD(n, 2) = 0, DATE_SUB(@seed_now, INTERVAL 20 + n DAY), NULL),
    IF(MOD(n, 2) = 0, 2, 1), 'CN',
    IF(MOD(n, 5) = 0, DATE_SUB(@seed_now, INTERVAL 15 + n DAY), NULL), 0
FROM tmp_demo_numbers WHERE n <= 100;

INSERT INTO eb_user_address (
    id, uid, real_name, phone, province, city, city_id, district, detail, post_code,
    longitude, latitude, is_default, is_del, create_time, update_time
)
SELECT
    560000 + n, 8100 + n,
    ELT(MOD(n - 1, 20) + 1, '林晓雨', '陈子轩', '周可欣', '王一诺', '李沐阳', '赵思涵', '孙嘉乐', '吴若溪', '郑皓宇', '冯语桐',
        '蒋文博', '沈依然', '韩景行', '许安琪', '何俊熙', '高雨晴', '罗嘉佑', '梁梦瑶', '宋知远', '唐心悦'),
    CONCAT('138', LPAD(800000 + n, 8, '0')),
    ELT(MOD(n - 1, 5) + 1, '上海市', '北京市', '浙江省', '广东省', '四川省'),
    ELT(MOD(n - 1, 5) + 1, '上海市', '北京市', '杭州市', '深圳市', '成都市'), 0,
    ELT(MOD(n - 1, 5) + 1, '浦东新区', '朝阳区', '余杭区', '南山区', '武侯区'),
    CONCAT(ELT(MOD(n - 1, 5) + 1, '张江路88号2栋1203室', '望京东路6号院3栋', '未来科技城海创园5幢', '科技园南区12栋806', '人民南路四段18号'), '-', n),
    ELT(MOD(n - 1, 5) + 1, 200120, 100102, 311121, 518057, 610041),
    ELT(MOD(n - 1, 5) + 1, '121.6062', '116.4800', '120.0102', '113.9440', '104.0648'),
    ELT(MOD(n - 1, 5) + 1, '31.2001', '39.9950', '30.2811', '22.5405', '30.5722'),
    1, 0, DATE_SUB(@seed_now, INTERVAL n * 3 DAY), @seed_now
FROM tmp_demo_numbers WHERE n <= 100;

INSERT INTO eb_user_address (
    id, uid, real_name, phone, province, city, city_id, district, detail, post_code,
    longitude, latitude, is_default, is_del, create_time, update_time
)
SELECT
    560200 + n, 8100 + n, CONCAT('备用收货人', n), CONCAT('137', LPAD(800000 + n, 8, '0')),
    '江苏省', '苏州市', 0, '工业园区', CONCAT('星湖街', 100 + n, '号'), 215000,
    '120.7200', '31.3000', 0, 0, DATE_SUB(@seed_now, INTERVAL n DAY), @seed_now
FROM tmp_demo_numbers WHERE n <= 30;

INSERT INTO eb_user_bill (
    id, uid, link_id, pm, title, category, type, number, balance, mark, status,
    create_time, update_time
)
SELECT
    570000 + n, 8101 + MOD(n - 1, 100), CONCAT('DEMO-BILL-', LPAD(n, 4, '0')),
    IF(MOD(n, 3) = 0, 0, 1),
    CASE MOD(n, 4)
        WHEN 0 THEN '购物赠送积分'
        WHEN 1 THEN '余额充值'
        WHEN 2 THEN '订单支付'
        ELSE '推广佣金'
    END,
    IF(MOD(n, 4) = 0, 'integral', IF(MOD(n, 4) = 3, 'brokerage_price', 'now_money')),
    CASE MOD(n, 4)
        WHEN 0 THEN 'gain'
        WHEN 1 THEN 'pay_recharge'
        WHEN 2 THEN 'pay_product'
        ELSE 'brokerage'
    END,
    5 + MOD(n * 17, 180), 100 + MOD(n * 31, 900),
    CONCAT(@demo_tag, ' 账户模拟流水'), 1,
    DATE_SUB(@seed_now, INTERVAL MOD(n * 5, 60) DAY), @seed_now
FROM tmp_demo_numbers WHERE n <= 400;

-- Coupons and coupon ownership records.
INSERT INTO eb_store_coupon (
    id, name, money, is_limited, total, last_total, use_type, primary_key, min_price,
    receive_start_time, receive_end_time, is_fixed_time, use_start_time, use_end_time,
    day, type, sort, status, is_del, create_time, update_time
) VALUES
(8101, '新人满99减10元', 10.00, 1, 500, 438, 1, '', 99.00, DATE_SUB(@seed_now, INTERVAL 15 DAY), DATE_ADD(@seed_now, INTERVAL 60 DAY), 0, NULL, NULL, 30, 2, 100, 1, 0, @seed_now, @seed_now),
(8102, '全场满299减30元', 30.00, 1, 300, 257, 1, '', 299.00, DATE_SUB(@seed_now, INTERVAL 10 DAY), DATE_ADD(@seed_now, INTERVAL 45 DAY), 1, DATE_SUB(@seed_now, INTERVAL 10 DAY), DATE_ADD(@seed_now, INTERVAL 60 DAY), 0, 1, 99, 1, 0, @seed_now, @seed_now),
(8103, '数码家电满899减80元', 80.00, 1, 200, 166, 3, '283', 899.00, DATE_SUB(@seed_now, INTERVAL 8 DAY), DATE_ADD(@seed_now, INTERVAL 40 DAY), 0, NULL, NULL, 20, 1, 98, 1, 0, @seed_now, @seed_now),
(8104, '指定商品立减20元', 20.00, 0, 0, 0, 2, '8109,8110,8111', 159.00, DATE_SUB(@seed_now, INTERVAL 5 DAY), DATE_ADD(@seed_now, INTERVAL 35 DAY), 0, NULL, NULL, 15, 1, 97, 1, 0, @seed_now, @seed_now),
(8105, '会员专享满599减60元', 60.00, 1, 150, 121, 1, '', 599.00, DATE_SUB(@seed_now, INTERVAL 3 DAY), DATE_ADD(@seed_now, INTERVAL 30 DAY), 1, DATE_SUB(@seed_now, INTERVAL 3 DAY), DATE_ADD(@seed_now, INTERVAL 45 DAY), 0, 3, 96, 1, 0, @seed_now, @seed_now),
(8106, '家居满199减20元', 20.00, 1, 400, 352, 1, '', 199.00, DATE_SUB(@seed_now, INTERVAL 12 DAY), DATE_ADD(@seed_now, INTERVAL 50 DAY), 0, NULL, NULL, 30, 1, 95, 1, 0, @seed_now, @seed_now),
(8107, '服饰满399减40元', 40.00, 1, 260, 218, 3, '744,745', 399.00, DATE_SUB(@seed_now, INTERVAL 11 DAY), DATE_ADD(@seed_now, INTERVAL 42 DAY), 0, NULL, NULL, 25, 1, 94, 1, 0, @seed_now, @seed_now),
(8108, '母婴用品满149减15元', 15.00, 1, 320, 286, 3, '286,806', 149.00, DATE_SUB(@seed_now, INTERVAL 9 DAY), DATE_ADD(@seed_now, INTERVAL 38 DAY), 0, NULL, NULL, 20, 1, 93, 1, 0, @seed_now, @seed_now),
(8109, '美妆个护满249减25元', 25.00, 1, 220, 181, 3, '291,293,294,296', 249.00, DATE_SUB(@seed_now, INTERVAL 7 DAY), DATE_ADD(@seed_now, INTERVAL 36 DAY), 0, NULL, NULL, 18, 1, 92, 1, 0, @seed_now, @seed_now),
(8110, '户外运动满499减50元', 50.00, 1, 160, 132, 3, '288,796', 499.00, DATE_SUB(@seed_now, INTERVAL 6 DAY), DATE_ADD(@seed_now, INTERVAL 34 DAY), 0, NULL, NULL, 16, 1, 91, 1, 0, @seed_now, @seed_now),
(8111, '食品清洁满59减5元', 5.00, 0, 0, 0, 1, '', 59.00, DATE_SUB(@seed_now, INTERVAL 4 DAY), DATE_ADD(@seed_now, INTERVAL 28 DAY), 0, NULL, NULL, 12, 2, 90, 1, 0, @seed_now, @seed_now),
(8112, '数码专享满999减100元', 100.00, 1, 100, 74, 3, '298,804', 999.00, DATE_SUB(@seed_now, INTERVAL 2 DAY), DATE_ADD(@seed_now, INTERVAL 26 DAY), 0, NULL, NULL, 10, 1, 89, 1, 0, @seed_now, @seed_now);

INSERT INTO eb_store_coupon_user (
    id, coupon_id, cid, uid, name, money, min_price, type, status, create_time, update_time,
    start_time, end_time, use_time, use_type, primary_key, order_id
)
SELECT
    590000 + n, c.id, c.id, 8101 + MOD(n - 1, 100), c.name, c.money, c.min_price,
    IF(MOD(n, 2) = 0, 'get', 'send'),
    CASE WHEN n <= 60 THEN 1 WHEN n <= 180 THEN 0 ELSE 2 END,
    DATE_SUB(@seed_now, INTERVAL MOD(n * 3, 40) DAY), @seed_now,
    CASE WHEN n > 180 THEN DATE_SUB(@seed_now, INTERVAL 60 DAY) ELSE DATE_SUB(@seed_now, INTERVAL 10 DAY) END,
    CASE WHEN n > 180 THEN DATE_SUB(@seed_now, INTERVAL 1 DAY) ELSE DATE_ADD(@seed_now, INTERVAL 30 DAY) END,
    IF(n <= 60, DATE_SUB(@seed_now, INTERVAL MOD(n, 12) DAY), NULL),
    c.use_type, c.primary_key,
    IF(n <= 60, 9150 + MOD(n - 1, 450), 0)
FROM tmp_demo_numbers dn
JOIN eb_store_coupon c ON c.id = 8101 + MOD(dn.n - 1, 12)
WHERE n <= 300;

-- Orders and line items:
--   1-150 unpaid, 151-250 pending shipment, 251-350 shipped, 351-450 pending review,
--   451-520 completed, 521-560 refunded, 561-600 completed.
INSERT INTO eb_store_order (
    id, order_id, uid, real_name, user_phone, user_address, freight_price, total_num,
    total_price, total_postage, pay_price, pay_postage, deduction_price, coupon_id,
    coupon_price, paid, pay_time, pay_type, create_time, status, refund_status,
    refund_reason_wap_explain, refund_reason_wap, refund_reason_time, refund_price,
    delivery_name, delivery_type, delivery_id, gain_integral, mark, remark, cost,
    is_channel, update_time, delivery_code, express_record_type, pro_total_price,
    before_pay_price, out_trade_no
)
SELECT
    9000 + dn.n, CONCAT('DM', DATE_FORMAT(@seed_now, '%Y%m%d'), LPAD(dn.n, 8, '0')),
    8101 + MOD(dn.n - 1, 100), u.real_name, u.phone,
    CONCAT(a.province, a.city, a.district, a.detail), 0, 1 + MOD(dn.n, 3),
    ROUND(p.price * (1 + MOD(dn.n, 3)), 2), 0,
    ROUND(GREATEST(p.price * (1 + MOD(dn.n, 3)) - IF(MOD(dn.n, 4) = 0, cp.money, 0), 0.01), 2),
    0, 0, IF(MOD(dn.n, 4) = 0, cp.id, 0),
    IF(MOD(dn.n, 4) = 0, cp.money, 0), IF(dn.n > 150, 1, 0),
    IF(dn.n > 150, DATE_ADD(DATE_SUB(DATE_SUB(@seed_now, INTERVAL MOD(dn.n * 7, 45) DAY), INTERVAL MOD(dn.n * 13, 20) HOUR), INTERVAL 5 MINUTE), NULL),
    IF(dn.n > 150, ELT(MOD(dn.n, 4) + 1, 'weixin', 'alipay', 'yue', 'weixin'), ''),
    DATE_SUB(DATE_SUB(@seed_now, INTERVAL MOD(dn.n * 7, 45) DAY), INTERVAL MOD(dn.n * 13, 20) HOUR),
    CASE
        WHEN dn.n <= 150 THEN 0
        WHEN dn.n <= 250 THEN 1
        WHEN dn.n <= 350 THEN 2
        WHEN dn.n <= 450 THEN 3
        WHEN dn.n <= 520 THEN 4
        WHEN dn.n <= 560 THEN 3
        ELSE 4
    END,
    IF(dn.n BETWEEN 521 AND 560, 2, 0),
    IF(dn.n BETWEEN 521 AND 560, '商品已退回，退款已原路到账', NULL),
    IF(dn.n BETWEEN 521 AND 560, '七天无理由退款', NULL),
    IF(dn.n BETWEEN 521 AND 560, DATE_SUB(@seed_now, INTERVAL MOD(dn.n, 4) DAY), NULL),
    IF(dn.n BETWEEN 521 AND 560,
       ROUND(GREATEST(p.price * (1 + MOD(dn.n, 3)) - IF(MOD(dn.n, 4) = 0, cp.money, 0), 0.01), 2), 0),
    IF(dn.n >= 251, ELT(MOD(dn.n, 3) + 1, '顺丰速运', '京东物流', '中通快递'), NULL),
    IF(dn.n >= 251, 'express', NULL),
    IF(dn.n >= 251, CONCAT('SF', DATE_FORMAT(@seed_now, '%m%d'), LPAD(9000 + dn.n, 8, '0')), NULL),
    FLOOR(p.price * (1 + MOD(dn.n, 3)) / 10),
    IF(MOD(dn.n, 6) = 0, '周末在家，请送货前电话联系', ''),
    @demo_tag, ROUND(p.cost * (1 + MOD(dn.n, 3)), 2), MOD(dn.n, 3), @seed_now,
    IF(dn.n >= 251, ELT(MOD(dn.n, 3) + 1, 'SF', 'JD', 'ZTO'), NULL),
    IF(dn.n >= 251, 1, NULL), ROUND(p.price * (1 + MOD(dn.n, 3)), 2),
    ROUND(p.price * (1 + MOD(dn.n, 3)), 2),
    IF(dn.n > 150, CONCAT('OUT', DATE_FORMAT(@seed_now, '%Y%m%d'), LPAD(dn.n, 8, '0')), NULL)
FROM tmp_demo_numbers dn
JOIN tmp_demo_products p ON p.id = 8101 + MOD(dn.n - 1, @demo_product_count)
JOIN eb_user u ON u.uid = 8101 + MOD(dn.n - 1, 100)
JOIN eb_user_address a ON a.id = 560001 + MOD(dn.n - 1, 100)
LEFT JOIN eb_store_coupon cp ON cp.id = 8101 + MOD(dn.n, 12)
WHERE dn.n <= 600;

INSERT INTO eb_store_order_info (
    id, order_id, product_id, info, `unique`, create_time, update_time, order_no,
    product_name, attr_value_id, image, sku, price, pay_num, weight, volume,
    give_integral, is_reply, is_sub, vip_price, product_type
)
SELECT
    550000 + dn.n, 9000 + dn.n, p.id,
    JSON_OBJECT(
        'image', p.image, 'productId', p.id,
        'attrValueId', sku.id,
        'weight', p.weight, 'giveIntegral', FLOOR(p.price / 10), 'isSub', FALSE,
        'productName', p.store_name, 'volume', 0, 'payNum', 1 + MOD(dn.n, 3),
        'price', p.price, 'vipPrice', ROUND(p.price * 0.95, 2),
        'tempId', 1, 'sku', sku.attr_value, 'productType', 0
    ),
    sku.unique_key,
    o.create_time, @seed_now, o.order_id, p.store_name,
    sku.id, p.image, sku.attr_value, p.price, 1 + MOD(dn.n, 3),
    p.weight, 0, FLOOR(p.price / 10),
    IF((dn.n BETWEEN 351 AND 520) OR (dn.n BETWEEN 561 AND 600), 1, 0), 0,
    ROUND(p.price * 0.95, 2), 0
FROM tmp_demo_numbers dn
JOIN tmp_demo_products p ON p.id = 8101 + MOD(dn.n - 1, @demo_product_count)
JOIN tmp_demo_skus sku ON sku.product_id = p.id
JOIN eb_store_order o ON o.id = 9000 + dn.n
WHERE dn.n <= 600;

INSERT INTO eb_store_order_status (oid, change_type, change_message, create_time)
SELECT o.id, 'cache_key_create_order', '订单生成', o.create_time
FROM eb_store_order o WHERE o.remark = @demo_tag
UNION ALL
SELECT o.id, 'pay_success', CONCAT('用户付款成功，支付方式：', o.pay_type), o.pay_time
FROM eb_store_order o WHERE o.remark = @demo_tag AND o.paid = 1
UNION ALL
SELECT o.id, 'delivery_goods', CONCAT('已由', o.delivery_name, '发货，运单号：', o.delivery_id), DATE_ADD(o.create_time, INTERVAL 1 DAY)
FROM eb_store_order o WHERE o.remark = @demo_tag AND o.id >= 9251
UNION ALL
SELECT o.id, 'take_delivery', '用户已确认收货', DATE_ADD(o.create_time, INTERVAL 4 DAY)
FROM eb_store_order o WHERE o.remark = @demo_tag
  AND (o.id BETWEEN 9351 AND 9520 OR o.id BETWEEN 9561 AND 9600)
UNION ALL
SELECT o.id, 'check_order_over', '订单已完成', DATE_ADD(o.create_time, INTERVAL 5 DAY)
FROM eb_store_order o WHERE o.remark = @demo_tag
  AND (o.id BETWEEN 9351 AND 9520 OR o.id BETWEEN 9561 AND 9600)
UNION ALL
SELECT o.id, 'refund_price', '退款成功，款项已原路退回', o.refund_reason_time
FROM eb_store_order o WHERE o.remark = @demo_tag AND o.id BETWEEN 9521 AND 9560;

-- Mark paid orders as activity orders and keep their SKU references coherent.
UPDATE eb_store_order o
JOIN eb_store_order_info oi ON oi.order_id = o.id
JOIN eb_store_seckill s ON s.product_id = oi.product_id
SET o.seckill_id = s.id,
    oi.product_type = 1,
    oi.attr_value_id = 30000 + (s.id - 8100),
    oi.`unique` = CONCAT('S', LPAD(s.id - 8100, 7, '0')),
    oi.info = JSON_SET(oi.info, '$.productType', 1, '$.attrValueId', 30000 + (s.id - 8100))
WHERE o.paid = 1 AND o.remark = @demo_tag;

UPDATE eb_store_order o
JOIN eb_store_order_info oi ON oi.order_id = o.id
JOIN eb_store_bargain b ON b.product_id = oi.product_id
SET o.bargain_id = b.id,
    oi.product_type = 2,
    oi.attr_value_id = 32000 + (b.id - 8100),
    oi.`unique` = CONCAT('B', LPAD(b.id - 8100, 7, '0')),
    oi.info = JSON_SET(oi.info, '$.productType', 2, '$.attrValueId', 32000 + (b.id - 8100))
WHERE o.paid = 1 AND o.remark = @demo_tag;

UPDATE eb_store_order o
JOIN eb_store_order_info oi ON oi.order_id = o.id
JOIN eb_store_combination c ON c.product_id = oi.product_id
SET o.combination_id = c.id,
    oi.product_type = 3,
    oi.attr_value_id = 34000 + (c.id - 8100),
    oi.`unique` = CONCAT('C', LPAD(c.id - 8100, 7, '0')),
    oi.info = JSON_SET(oi.info, '$.productType', 3, '$.attrValueId', 34000 + (c.id - 8100))
WHERE o.paid = 1 AND o.remark = @demo_tag;

INSERT INTO eb_store_pink (
    id, uid, order_id, order_id_key, total_num, total_price, cid, pid, people, price,
    add_time, stop_time, k_id, is_tpl, is_refund, status, is_virtual, nickname, avatar
)
SELECT
    8700 + ROW_NUMBER() OVER (ORDER BY o.id), o.uid, o.order_id, o.id, o.total_num,
    o.pay_price, c.id, oi.product_id, c.people, c.price,
    UNIX_TIMESTAMP(o.create_time) * 1000,
    UNIX_TIMESTAMP(DATE_ADD(o.create_time, INTERVAL 24 HOUR)) * 1000,
    0, 0, IF(o.refund_status = 2, 1, 0), IF(o.status >= 3, 2, 1), 0, u.nickname, u.avatar
FROM eb_store_order o
JOIN eb_store_combination c ON c.id = o.combination_id
JOIN eb_store_order_info oi ON oi.order_id = o.id
JOIN eb_user u ON u.uid = o.uid
WHERE o.remark = @demo_tag AND o.combination_id > 0;

UPDATE eb_store_order o
JOIN eb_store_pink p ON p.order_id_key = o.id
SET o.pink_id = p.id
WHERE o.remark = @demo_tag AND o.combination_id > 0;

-- Reviews tied to completed orders.
INSERT INTO eb_store_product_reply (
    id, uid, oid, `unique`, product_id, reply_type, product_score, service_score,
    comment, pics, merchant_reply_content, merchant_reply_time, is_del, is_reply,
    nickname, avatar, create_time, update_time, sku
)
SELECT
    580000 + dn.n, o.uid, o.id, oi.`unique`, oi.product_id, 'product',
    IF(MOD(dn.n, 7) = 0, 4, 5), IF(MOD(dn.n, 9) = 0, 4, 5),
    ELT(MOD(dn.n, 8) + 1,
        '实物和图片一致，包装完整，使用起来很顺手。',
        '发货速度快，客服回复及时，整体体验不错。',
        '做工比预期更好，细节处理到位，性价比很高。',
        '颜色耐看，规格合适，家里人也很满意。',
        '已经使用一段时间，质量稳定，会考虑回购。',
        '物流信息更新及时，收到后没有破损。',
        '功能够用，操作简单，适合日常使用。',
        '第二次购买了，品质一如既往，推荐。'
    ),
    IF(MOD(dn.n, 4) = 0, oi.image, ''),
    IF(MOD(dn.n, 3) = 0, '感谢您的认可，我们会继续做好商品与服务。', NULL),
    IF(MOD(dn.n, 3) = 0, UNIX_TIMESTAMP(DATE_ADD(o.create_time, INTERVAL 6 DAY)), NULL),
    0, IF(MOD(dn.n, 3) = 0, 1, 0), u.nickname, u.avatar,
    DATE_ADD(o.create_time, INTERVAL 5 DAY), @seed_now, oi.sku
FROM tmp_demo_numbers dn
JOIN eb_store_order o ON o.id = 9000 + dn.n
JOIN eb_store_order_info oi ON oi.order_id = o.id
JOIN eb_user u ON u.uid = o.uid
WHERE (dn.n BETWEEN 351 AND 520) OR (dn.n BETWEEN 561 AND 600);

UPDATE eb_user u
JOIN (
    SELECT uid, COUNT(*) AS pay_count
    FROM eb_store_order
    WHERE remark = @demo_tag AND paid = 1 AND refund_status = 0
    GROUP BY uid
) x ON x.uid = u.uid
SET u.pay_count = x.pay_count
WHERE u.uid BETWEEN 8101 AND 8200;

-- Collections and active carts.
INSERT INTO eb_store_product_relation (id, uid, product_id, type, category, create_time, update_time)
SELECT
    610000 + n, 8101 + MOD(n - 1, 100),
    8101 + MOD(n * 7 + FLOOR((n - 1) / 100), @demo_product_count),
    'collect', 'product', DATE_SUB(@seed_now, INTERVAL MOD(n * 2, 35) DAY), @seed_now
FROM tmp_demo_numbers WHERE n <= 300;

INSERT INTO eb_store_cart (
    id, uid, type, product_id, product_attr_unique, cart_num, is_new,
    combination_id, seckill_id, bargain_id, create_time, update_time, status
)
SELECT
    600000 + n, 8101 + MOD(n - 1, 100), 'product', p.id,
    sku.unique_key, 1 + MOD(n, 2), 0, 0, 0, 0,
    DATE_SUB(@seed_now, INTERVAL MOD(n, 10) DAY), @seed_now, 1
FROM tmp_demo_numbers dn
JOIN tmp_demo_products p ON p.id = 8101 + MOD(dn.n - 1, @demo_product_count)
JOIN tmp_demo_skus sku ON sku.product_id = p.id
WHERE n <= 100;

-- Articles use local images and absolute URLs inside rich text.
DROP TEMPORARY TABLE IF EXISTS tmp_demo_articles;
CREATE TEMPORARY TABLE tmp_demo_articles (
    id INT PRIMARY KEY, cid VARCHAR(16) NOT NULL, title VARCHAR(200) NOT NULL,
    author VARCHAR(64) NOT NULL, synopsis VARCHAR(300) NOT NULL, visit VARCHAR(16) NOT NULL,
    sort_num INT NOT NULL, product_id INT NOT NULL, is_hot TINYINT NOT NULL, is_banner TINYINT NOT NULL
) ENGINE = MEMORY;
INSERT INTO tmp_demo_articles
SELECT
    8100 + dn.n,
    ELT(MOD(dn.n - 1, 3) + 1, '601', '807', '808'),
    CONCAT(p.store_name, '：选购与使用参考'),
    '商城编辑部',
    CONCAT('基于商品名称、主图和开放源记录，整理 ', p.store_name, ' 的规格与使用场景。'),
    CAST(320 + MOD(dn.n * 97, 1200) AS CHAR),
    101 - dn.n,
    p.id,
    IF(MOD(dn.n, 4) = 0, 1, 0),
    IF(dn.n IN (1, 10, 20, 30), 1, 0)
FROM tmp_demo_numbers dn
JOIN tmp_demo_products p ON p.id = 8101 + MOD((dn.n - 1) * 4, @demo_product_count)
WHERE dn.n <= 30;

INSERT INTO eb_article (
    id, cid, title, author, image_input, synopsis, share_title, share_synopsis,
    visit, sort, url, media_id, status, hide, admin_id, mer_id, product_id,
    is_hot, is_banner, content, create_time, update_time
)
SELECT
    a.id, a.cid, a.title, a.author, p.image, a.synopsis, a.title,
    CONCAT('关于', a.title, '的实用要点整理'), a.visit, a.sort_num, '', NULL, 0, 0, 1, 0,
    a.product_id, a.is_hot, a.is_banner,
    CONCAT('<h2>', a.title, '</h2><p>', a.synopsis,
           '</p><img src="http://127.0.0.1:8080/', p.image,
           '" style="width:100%" /><h3>要点整理</h3><p>',
           '展示名称与图片来自同一 ABO 商品记录，页面规格采用图示单规格。',
           '</p><p>价格、库存与销量为本地演示值；图片依据 CC BY 4.0 使用并做方图归一化。</p>'),
    DATE_SUB(@seed_now, INTERVAL MOD(a.id, 30) DAY), @seed_now
FROM tmp_demo_articles a
JOIN eb_store_product p ON p.id = a.product_id;

-- Sixty days of coherent dashboard and product statistics.
DROP TEMPORARY TABLE IF EXISTS tmp_demo_days;
CREATE TEMPORARY TABLE tmp_demo_days (
    day_no INT PRIMARY KEY,
    record_date VARCHAR(20) NOT NULL
) ENGINE = MEMORY;
INSERT INTO tmp_demo_days (day_no, record_date)
SELECT n - 1, DATE_FORMAT(DATE_SUB(CURDATE(), INTERVAL n - 1 DAY), '%Y-%m-%d')
FROM tmp_demo_numbers WHERE n <= 60;

INSERT INTO eb_trading_day_record (
    id, date, product_order_num, product_order_pay_num, product_order_pay_fee,
    product_order_refund_num, product_order_refund_fee, recharge_order_num,
    recharge_order_fee, balance_pay_fee, brokerage_fee
)
SELECT
    -900001 - day_no, record_date, 28 + MOD(day_no * 7, 42), 24 + MOD(day_no * 5, 38),
    4200 + MOD(day_no * 379, 9800), IF(MOD(day_no, 8) = 0, 3, MOD(day_no, 3)),
    IF(MOD(day_no, 8) = 0, 499.00 + MOD(day_no * 31, 800), MOD(day_no, 3) * 89.00),
    3 + MOD(day_no, 6), 200 + MOD(day_no * 73, 1200),
    180 + MOD(day_no * 41, 1300), 35 + MOD(day_no * 17, 220)
FROM tmp_demo_days;

INSERT INTO eb_shopping_product_day_record (
    id, date, add_product_num, page_view, collect_num, add_cart_num,
    order_product_num, order_success_product_num
)
SELECT
    -910001 - day_no, record_date, IF(day_no < 40, 1, 0),
    980 + MOD(day_no * 83, 1520), 32 + MOD(day_no * 11, 88),
    68 + MOD(day_no * 17, 180), 35 + MOD(day_no * 7, 78),
    29 + MOD(day_no * 5, 59)
FROM tmp_demo_days;

INSERT INTO eb_product_day_record (
    id, date, product_id, page_view, collect_num, add_cart_num,
    order_product_num, order_success_product_fee
)
SELECT
    -920001 - d.day_no * 200 - (CAST(p.id AS SIGNED) - 8101), d.record_date, p.id,
    18 + MOD(d.day_no * 19 + p.id * 7, 120),
    1 + MOD(d.day_no + p.id, 18),
    2 + MOD(d.day_no * 3 + p.id, 26),
    1 + MOD(d.day_no + p.id * 2, 12),
    ROUND(p.price * (1 + MOD(d.day_no + p.id, 6)), 2)
FROM tmp_demo_days d
CROSS JOIN tmp_demo_products p;

INSERT INTO eb_user_visit_record (id, date, uid, visit_type)
SELECT
    -930001 - d.day_no * 100 - (CAST(u.uid AS SIGNED) - 8101), d.record_date, u.uid,
    1 + MOD(d.day_no + u.uid, 4)
FROM tmp_demo_days d
CROSS JOIN eb_user u
WHERE u.uid BETWEEN 8101 AND 8200;

-- Keep the active home theme and its reset snapshot on the curated catalog.
UPDATE eb_theme
SET
    home_data = JSON_SET(
        home_data,
        '$.value."1772508227561009".goodsList.list',
        JSON_ARRAY(
            JSON_OBJECT('id', 8101),
            JSON_OBJECT('id', 8105),
            JSON_OBJECT('id', 8109),
            JSON_OBJECT('id', 8112)
        ),
        '$.value."1772508227561007".tabConfig.list[0].goodsList.list',
        JSON_ARRAY(
            JSON_OBJECT('id', 8101),
            JSON_OBJECT('id', 8105),
            JSON_OBJECT('id', 8109),
            JSON_OBJECT('id', 8112)
        )
    ),
    home_default_data = JSON_SET(
        home_default_data,
        '$.value."1772508227561009".goodsList.list',
        JSON_ARRAY(
            JSON_OBJECT('id', 8101),
            JSON_OBJECT('id', 8105),
            JSON_OBJECT('id', 8109),
            JSON_OBJECT('id', 8112)
        ),
        '$.value."1772508227561007".tabConfig.list[0].goodsList.list',
        JSON_ARRAY(
            JSON_OBJECT('id', 8101),
            JSON_OBJECT('id', 8105),
            JSON_OBJECT('id', 8109),
            JSON_OBJECT('id', 8112)
        )
    ),
    home_data_update_time = UNIX_TIMESTAMP(@seed_now),
    up_time = UNIX_TIMESTAMP(@seed_now)
WHERE id = 1
  AND JSON_VALID(home_data)
  AND JSON_VALID(home_default_data);

-- Repair references left by older demo-catalog revisions. Historical orders remain
-- intact and are rebound only when their product still exists in this curated set.
UPDATE eb_store_order_info oi
JOIN tmp_demo_skus s ON s.product_id = oi.product_id
LEFT JOIN eb_store_product_attr_value current_sku
  ON current_sku.id = oi.attr_value_id
 AND current_sku.product_id = oi.product_id
SET oi.attr_value_id = s.id,
    oi.`unique` = s.unique_key,
    oi.sku = s.attr_value
WHERE current_sku.id IS NULL;

-- A cart row cannot be recovered when either its product or selected SKU was
-- removed. Such rows would otherwise break cart rendering and checkout.
DELETE c
FROM eb_store_cart c
LEFT JOIN eb_store_product p ON p.id = c.product_id
LEFT JOIN eb_store_product_attr_value sku
  ON sku.product_id = c.product_id
 AND sku.`unique` = c.product_attr_unique
 AND sku.is_del = 0
WHERE p.id IS NULL OR sku.id IS NULL;

COMMIT;

DROP TEMPORARY TABLE IF EXISTS tmp_demo_articles;
DROP TEMPORARY TABLE IF EXISTS tmp_demo_days;
DROP TEMPORARY TABLE IF EXISTS tmp_demo_combination;
DROP TEMPORARY TABLE IF EXISTS tmp_demo_bargain;
DROP TEMPORARY TABLE IF EXISTS tmp_demo_seckill;
DROP TEMPORARY TABLE IF EXISTS tmp_demo_skus;
DROP TEMPORARY TABLE IF EXISTS tmp_demo_products;
DROP TEMPORARY TABLE IF EXISTS tmp_demo_numbers;
DROP TEMPORARY TABLE IF EXISTS tmp_owned_combination;
DROP TEMPORARY TABLE IF EXISTS tmp_owned_bargain;
DROP TEMPORARY TABLE IF EXISTS tmp_owned_seckill;
DROP TEMPORARY TABLE IF EXISTS tmp_owned_products;

SET FOREIGN_KEY_CHECKS = @old_foreign_key_checks;

SELECT 'ABO-CURATED-V2 demo data imported' AS result;
