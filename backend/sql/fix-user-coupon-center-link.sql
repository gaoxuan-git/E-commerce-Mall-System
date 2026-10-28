-- Correct the existing local theme's coupon-center destination without changing
-- the separate "my coupons" entry. Safe to run repeatedly.
UPDATE eb_theme
SET user_data = JSON_SET(
    user_data,
    '$.value."1772524664735005".menuConfig.list[2].info[1].value',
    '/pages/users/user_get_coupon/index'
)
WHERE id = 1
  AND JSON_VALID(user_data)
  AND JSON_UNQUOTE(JSON_EXTRACT(
      user_data, '$.value."1772524664735005".menuConfig.list[2].info[0].value'
  )) = '领券中心'
  AND JSON_UNQUOTE(JSON_EXTRACT(
      user_data, '$.value."1772524664735005".menuConfig.list[2].info[1].value'
  )) = '/pages/users/user_coupon/index';
