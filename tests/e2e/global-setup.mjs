import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { apiRequest, loginAdmin, loginFront } from './helpers/api.mjs';
import { queryScalar } from './helpers/database.mjs';

const rootDir = path.dirname(fileURLToPath(import.meta.url));

function required(name) {
  const value = process.env[name];
  if (!value) throw new Error(`Missing required E2E environment variable: ${name}`);
  return value;
}

async function assertService(url, expectsJson = false) {
  const response = await fetch(url, { signal: AbortSignal.timeout(10_000) });
  if (!response.ok) throw new Error(`Health check failed: ${url} returned HTTP ${response.status}`);
  if (expectsJson) {
    const payload = await response.json();
    if (![0, 200].includes(payload?.code)) {
      throw new Error(`Health check failed: ${url} returned business code ${payload?.code}`);
    }
  }
}

function writeJson(relativePath, value) {
  const target = path.join(rootDir, relativePath);
  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.writeFileSync(target, `${JSON.stringify(value, null, 2)}\n`);
}

export default async function globalSetup() {
  const frontApi = process.env.FRONT_API_URL || 'http://127.0.0.1:8081';
  const adminApi = process.env.ADMIN_API_URL || 'http://127.0.0.1:8080';
  const h5Base = process.env.H5_BASE_URL || 'http://127.0.0.1:5273';
  const adminBase = process.env.ADMIN_BASE_URL || 'http://127.0.0.1:9527';
  const runId = process.env.E2E_RUN_ID || `e2e-${new Date().toISOString().replace(/[-:.TZ]/g, '').slice(0, 14)}`;

  await Promise.all([
    assertService(`${frontApi}/api/front/category`, true),
    assertService(`${adminApi}/api/admin/getLoginPic`, true),
    assertService(h5Base),
    assertService(adminBase),
  ]);

  const admin = await loginAdmin(adminApi, required('E2E_ADMIN_ACCOUNT'), required('E2E_ADMIN_PASSWORD'));
  const h5 = await loginFront(frontApi, required('E2E_USER_ACCOUNT'), required('E2E_USER_PASSWORD'));
  const secondH5 = await loginFront(
    frontApi,
    required('E2E_SECOND_USER_ACCOUNT'),
    required('E2E_SECOND_USER_PASSWORD'),
  );
  const menuTree = await apiRequest(adminApi, '/api/admin/getMenus', { token: admin.token });
  if (![0, 200].includes(menuTree.payload?.code)) {
    throw new Error(`Admin menu API returned business code ${menuTree.payload?.code}`);
  }

  const adminRoutes = [];
  const collectRoutes = (items) => {
    for (const item of items || []) {
      if (item.menuType === 'C' && item.component) {
        adminRoutes.push({ id: item.id, name: item.name, path: item.component });
      }
      collectRoutes(item.childList);
    }
  };
  collectRoutes(menuTree.payload.data);

  const nowSeconds = Math.floor(Date.now() / 1000);
  writeJson('auth/admin.json', {
    cookies: [
      {
        name: 'Authorization',
        value: admin.token,
        domain: '127.0.0.1',
        path: '/',
        expires: nowSeconds + 6 * 24 * 60 * 60,
        httpOnly: false,
        secure: false,
        sameSite: 'Lax',
      },
    ],
    origins: [],
  });
  writeJson('auth/h5.json', {
    cookies: [],
    origins: [
      {
        origin: new URL(h5Base).origin,
        localStorage: [
          { name: 'LOGIN_STATUS_TOKEN', value: h5.token },
          { name: 'EXPIRES_TIME', value: String(nowSeconds + 6 * 24 * 60 * 60) },
          { name: 'UID', value: String(h5.uid) },
        ],
      },
    ],
  });

  // 全量套件创建 11 件普通商品订单；购物车最多同时校验 3 件。
  // 预留 16 件，并同时检查商品及实际选中 SKU，避免占用旧订单恢复后的少量库存。
  const stockBudget = 16;
  const productId = Number(
    queryScalar(
      `SELECT p.id FROM eb_store_product p
       WHERE p.id BETWEEN 8101 AND 8220 AND p.is_show = 1 AND p.is_del = 0 AND p.stock >= ${stockBudget}
       AND EXISTS (SELECT 1 FROM eb_store_product_attr_value a
                   WHERE a.product_id = p.id AND a.type = 0 AND a.stock >= ${stockBudget})
       ORDER BY p.id LIMIT 1`,
    ),
  );
  const secondProductId = Number(
    queryScalar(
      `SELECT p.id FROM eb_store_product p
       WHERE p.id BETWEEN 8101 AND 8220 AND p.is_show = 1 AND p.is_del = 0 AND p.stock >= ${stockBudget}
       AND p.id <> ${productId}
       AND EXISTS (SELECT 1 FROM eb_store_product_attr_value a
                   WHERE a.product_id = p.id AND a.type = 0 AND a.stock >= ${stockBudget})
       ORDER BY p.id LIMIT 1`,
    ),
  );
  if (!productId || !secondProductId) {
    throw new Error(`Two demo products with at least ${stockBudget} units of product and SKU stock are required`);
  }
  const fixtures = {
    runId,
    primaryUserId: h5.uid,
    secondUserId: secondH5.uid,
    productId,
    secondProductId,
    productName: queryScalar(`SELECT store_name FROM eb_store_product WHERE id = ${productId}`),
    productPrice: Number(queryScalar(
      `SELECT price FROM eb_store_product_attr_value WHERE product_id = ${productId} AND type = 0 AND stock >= ${stockBudget} ORDER BY id LIMIT 1`,
    )),
    productImage: queryScalar(
      `SELECT image FROM eb_store_product_attr_value WHERE product_id = ${productId} AND type = 0 AND stock >= ${stockBudget} ORDER BY id LIMIT 1`,
    ),
    secondProductPrice: Number(queryScalar(
      `SELECT price FROM eb_store_product_attr_value WHERE product_id = ${secondProductId} AND type = 0 AND stock >= ${stockBudget} ORDER BY id LIMIT 1`,
    )),
    productAttrValueId: Number(
      queryScalar(
        `SELECT id FROM eb_store_product_attr_value WHERE product_id = ${productId} AND type = 0 AND stock >= ${stockBudget} ORDER BY id LIMIT 1`,
      ),
    ),
    productAttrUnique: queryScalar(
      `SELECT \`unique\` FROM eb_store_product_attr_value WHERE product_id = ${productId} AND type = 0 AND stock >= ${stockBudget} ORDER BY id LIMIT 1`,
    ),
    secondProductAttrValueId: Number(
      queryScalar(
        `SELECT id FROM eb_store_product_attr_value WHERE product_id = ${secondProductId} AND type = 0 AND stock >= ${stockBudget} ORDER BY id LIMIT 1`,
      ),
    ),
    secondProductAttrUnique: queryScalar(
      `SELECT \`unique\` FROM eb_store_product_attr_value WHERE product_id = ${secondProductId} AND type = 0 AND stock >= ${stockBudget} ORDER BY id LIMIT 1`,
    ),
    categoryId: Number(
      queryScalar(
        `SELECT p.cate_id
         FROM eb_store_product p
         WHERE p.id BETWEEN 8101 AND 8220
           AND p.is_show = 1
           AND p.is_del = 0
           AND NOT EXISTS (
             SELECT 1
             FROM eb_store_product other_product
             WHERE other_product.is_show = 1
               AND other_product.is_del = 0
               AND other_product.id NOT BETWEEN 8101 AND 8220
               AND FIND_IN_SET(p.cate_id, other_product.cate_id) > 0
           )
         ORDER BY p.id
         LIMIT 1`,
      )?.split(',')[0] || 0,
    ),
    seckillId: Number(queryScalar('SELECT id FROM eb_store_seckill WHERE is_del = 0 ORDER BY id LIMIT 1') || 0),
    bargainId: Number(queryScalar('SELECT id FROM eb_store_bargain WHERE is_del = 0 ORDER BY id LIMIT 1') || 0),
    combinationId: Number(
      queryScalar('SELECT id FROM eb_store_combination WHERE is_del = 0 ORDER BY id LIMIT 1') || 0,
    ),
    pinkId: Number(queryScalar('SELECT id FROM eb_store_pink ORDER BY id DESC LIMIT 1') || 0),
    themeId: Number(
      queryScalar('SELECT id FROM eb_theme WHERE is_use = 1 AND is_del = 0 ORDER BY id DESC LIMIT 1') || 0,
    ),
    articleId: Number(
      queryScalar('SELECT id FROM eb_article WHERE status = 0 AND hide = 0 ORDER BY id LIMIT 1') || 0,
    ),
    orderId: Number(
      queryScalar(`SELECT id FROM eb_store_order WHERE uid = ${Number(h5.uid)} ORDER BY id DESC LIMIT 1`) || 0,
    ),
    addressId: Number(
      queryScalar(`SELECT id FROM eb_user_address WHERE uid = ${Number(h5.uid)} ORDER BY is_default DESC, id LIMIT 1`) ||
        0,
    ),
    secondAddressId: Number(
      queryScalar(
        `SELECT id FROM eb_user_address WHERE uid = ${Number(secondH5.uid)} ORDER BY is_default DESC, id LIMIT 1`,
      ) || 0,
    ),
    adminToken: admin.token,
    h5Token: h5.token,
    secondH5Token: secondH5.token,
    adminRoutes,
    frontApi,
    adminApi,
    webPageUrl: new URL('/pages/guide/index', h5Base).toString(),
  };
  writeJson('runtime/fixtures.json', fixtures);
  writeJson('runtime/run.json', {
    runId,
    startedAt: new Date().toISOString(),
    serviceUrls: { frontApi, adminApi, h5Base, adminBase },
  });

  const anonymous = await apiRequest(frontApi, '/api/front/user', { allowHttpError: true });
  if (![401, 402, 410000, 410001, 410002].includes(anonymous.payload?.code)) {
    throw new Error(`Anonymous authorization gate returned unexpected code ${anonymous.payload?.code}`);
  }
}
