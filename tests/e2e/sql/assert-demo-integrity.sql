-- Every result row must report violations = 0.
SELECT 'demo_product_count' AS check_name,
       ABS(COUNT(*) - 120) AS violations,
       CONCAT('actual=', COUNT(*), ', expected=120') AS details
FROM eb_store_product
WHERE soure_link LIKE 'abo-curated-v2:%';

SELECT 'demo_leaf_category_count',
       ABS(COUNT(DISTINCT cate_id) - 34),
       CONCAT('actual=', COUNT(DISTINCT cate_id), ', expected=34')
FROM eb_store_product
WHERE soure_link LIKE 'abo-curated-v2:%';

SELECT 'demo_maternity_outing_category',
       ABS(COUNT(*) - 1),
       IF(COUNT(*) = 1, 'ok', 'category 285 must be named 母婴出行 and use the curated local image')
FROM eb_category
WHERE id = 285
  AND pid = 280
  AND name = '母婴出行'
  AND extra = 'crmebimage/public/open-data/abo-curated-v2/8114-main.jpg';

SELECT 'demo_products_per_category',
       COUNT(*),
       COALESCE(GROUP_CONCAT(CONCAT(cate_id, ':', product_count) ORDER BY cate_id), 'ok')
FROM (
    SELECT cate_id, COUNT(*) AS product_count
    FROM eb_store_product
    WHERE soure_link LIKE 'abo-curated-v2:%'
    GROUP BY cate_id
    HAVING COUNT(*) NOT BETWEEN 3 AND 4
) invalid_categories;

SELECT 'demo_product_single_description',
       COUNT(*),
       COALESCE(GROUP_CONCAT(product_id ORDER BY product_id), 'ok')
FROM (
    SELECT p.id AS product_id
    FROM eb_store_product p
    LEFT JOIN eb_store_product_description d ON d.product_id = p.id AND d.type = 0
    WHERE p.soure_link LIKE 'abo-curated-v2:%'
    GROUP BY p.id
    HAVING COUNT(d.id) <> 1
) invalid_descriptions;

SELECT 'demo_product_valid_sku',
       COUNT(*),
       COALESCE(GROUP_CONCAT(product_id ORDER BY product_id), 'ok')
FROM (
    SELECT p.id AS product_id
    FROM eb_store_product p
    LEFT JOIN eb_store_product_attr_value sku
      ON sku.product_id = p.id AND sku.type = 0 AND sku.is_del = 0 AND sku.is_show = 1
    WHERE p.soure_link LIKE 'abo-curated-v2:%'
    GROUP BY p.id
    HAVING COUNT(sku.id) < 1
) invalid_skus;

SELECT 'demo_product_stock_sales_match_sku',
       COUNT(*),
       COALESCE(GROUP_CONCAT(product_id ORDER BY product_id), 'ok')
FROM (
    SELECT p.id AS product_id
    FROM eb_store_product p
    JOIN eb_store_product_attr_value sku
      ON sku.product_id = p.id AND sku.type = 0 AND sku.is_del = 0
    WHERE p.soure_link LIKE 'abo-curated-v2:%'
    GROUP BY p.id, p.stock, p.sales
    HAVING p.stock <> SUM(sku.stock) OR p.sales <> SUM(sku.sales)
) invalid_totals;

SELECT 'demo_seckill_count',
       ABS(COUNT(*) - 12),
       CONCAT('actual=', COUNT(*), ', expected=12')
FROM eb_store_seckill s
JOIN eb_store_product p ON p.id = s.product_id
WHERE p.soure_link LIKE 'abo-curated-v2:%' AND s.is_del = 0;

SELECT 'demo_bargain_count',
       ABS(COUNT(*) - 10),
       CONCAT('actual=', COUNT(*), ', expected=10')
FROM eb_store_bargain b
JOIN eb_store_product p ON p.id = b.product_id
WHERE p.soure_link LIKE 'abo-curated-v2:%' AND b.is_del = 0;

SELECT 'demo_combination_count',
       ABS(COUNT(*) - 10),
       CONCAT('actual=', COUNT(*), ', expected=10')
FROM eb_store_combination c
JOIN eb_store_product p ON p.id = c.product_id
WHERE p.soure_link LIKE 'abo-curated-v2:%' AND c.is_del = 0;

SELECT 'demo_user_count',
       ABS(COUNT(*) - 100),
       CONCAT('actual=', COUNT(*), ', expected=100')
FROM eb_user
WHERE uid BETWEEN 8101 AND 8200 AND mark = '[DEMO-SEED-V1]';

SELECT 'demo_user_password_format',
       COUNT(*),
       COALESCE(GROUP_CONCAT(uid ORDER BY uid), 'ok')
FROM eb_user
WHERE uid BETWEEN 8101 AND 8200
  AND mark = '[DEMO-SEED-V1]'
  AND pwd <> 'b34Evwm5B/w=';

SELECT 'demo_address_count',
       ABS(COUNT(*) - 130),
       CONCAT('actual=', COUNT(*), ', expected=130')
FROM eb_user_address
WHERE uid BETWEEN 8101 AND 8200;

SELECT 'demo_order_count',
       ABS(COUNT(*) - 600),
       CONCAT('actual=', COUNT(*), ', expected=600')
FROM eb_store_order
WHERE remark = '[DEMO-SEED-V1]';

SELECT 'demo_reply_count',
       ABS(COUNT(*) - 210),
       CONCAT('actual=', COUNT(*), ', expected=210')
FROM eb_store_product_reply r
JOIN eb_store_product p ON p.id = r.product_id
WHERE p.soure_link LIKE 'abo-curated-v2:%' AND r.is_del = 0;

SELECT 'orphan_order_info_order',
       COUNT(*),
       COALESCE(SUBSTRING_INDEX(GROUP_CONCAT(oi.id ORDER BY oi.id), ',', 20), 'ok')
FROM eb_store_order_info oi
LEFT JOIN eb_store_order o ON o.id = oi.order_id
WHERE o.id IS NULL;

SELECT 'orphan_order_info_product',
       COUNT(*),
       COALESCE(SUBSTRING_INDEX(GROUP_CONCAT(oi.id ORDER BY oi.id), ',', 20), 'ok')
FROM eb_store_order_info oi
LEFT JOIN eb_store_product p ON p.id = oi.product_id
WHERE p.id IS NULL;

SELECT 'orphan_order_info_sku',
       COUNT(*),
       COALESCE(SUBSTRING_INDEX(GROUP_CONCAT(oi.id ORDER BY oi.id), ',', 20), 'ok')
FROM eb_store_order_info oi
LEFT JOIN eb_store_product_attr_value sku ON sku.id = oi.attr_value_id
WHERE oi.attr_value_id IS NOT NULL AND oi.attr_value_id > 0 AND sku.id IS NULL;

SELECT 'orphan_cart_product',
       COUNT(*),
       COALESCE(SUBSTRING_INDEX(GROUP_CONCAT(c.id ORDER BY c.id), ',', 20), 'ok')
FROM eb_store_cart c
LEFT JOIN eb_store_product p ON p.id = c.product_id
WHERE p.id IS NULL;

SELECT 'orphan_cart_sku',
       COUNT(*),
       COALESCE(SUBSTRING_INDEX(GROUP_CONCAT(c.id ORDER BY c.id), ',', 20), 'ok')
FROM eb_store_cart c
LEFT JOIN eb_store_product_attr_value sku ON sku.`unique` = c.product_attr_unique
WHERE c.product_attr_unique <> '' AND sku.id IS NULL;

SELECT 'orphan_collection_product',
       COUNT(*),
       COALESCE(SUBSTRING_INDEX(GROUP_CONCAT(r.id ORDER BY r.id), ',', 20), 'ok')
FROM eb_store_product_relation r
LEFT JOIN eb_store_product p ON p.id = r.product_id
WHERE p.id IS NULL;

SELECT 'orphan_reply_product',
       COUNT(*),
       COALESCE(SUBSTRING_INDEX(GROUP_CONCAT(r.id ORDER BY r.id), ',', 20), 'ok')
FROM eb_store_product_reply r
LEFT JOIN eb_store_product p ON p.id = r.product_id
WHERE p.id IS NULL;

SELECT 'orphan_seckill_product',
       COUNT(*),
       COALESCE(SUBSTRING_INDEX(GROUP_CONCAT(s.id ORDER BY s.id), ',', 20), 'ok')
FROM eb_store_seckill s
LEFT JOIN eb_store_product p ON p.id = s.product_id
WHERE p.id IS NULL;

SELECT 'orphan_bargain_product',
       COUNT(*),
       COALESCE(SUBSTRING_INDEX(GROUP_CONCAT(b.id ORDER BY b.id), ',', 20), 'ok')
FROM eb_store_bargain b
LEFT JOIN eb_store_product p ON p.id = b.product_id
WHERE p.id IS NULL;

SELECT 'orphan_combination_product',
       COUNT(*),
       COALESCE(SUBSTRING_INDEX(GROUP_CONCAT(c.id ORDER BY c.id), ',', 20), 'ok')
FROM eb_store_combination c
LEFT JOIN eb_store_product p ON p.id = c.product_id
WHERE p.id IS NULL;

SELECT 'orphan_product_day_record',
       COUNT(*),
       COALESCE(SUBSTRING_INDEX(GROUP_CONCAT(r.id ORDER BY r.id), ',', 20), 'ok')
FROM eb_product_day_record r
LEFT JOIN eb_store_product p ON p.id = r.product_id
WHERE p.id IS NULL;
