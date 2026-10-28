# CRMEB Java 开源商城 — 本地部署与交接说明

> 适用路径：`c:\Users\EDY\Desktop\安卓app\crmeb_java`  
> 文档日期：2026-10-15  
> 版本：**CRMEB-JAVA-KY-v3.1**（代码与 `Crmeb_v3.1.sql` 对齐）

---

## 1. 项目结构

```
crmeb_java/
├── backend/                 # Maven 多模块 Spring Boot
│   ├── crmeb-common/        # 公共模块（jar，勿单独 install）
│   ├── crmeb-service/
│   ├── crmeb-admin/         # 管理端 API，默认端口 8080
│   ├── crmeb-front/         # 商城 C 端 API，默认端口 8081
│   └── sql/
│       ├── Crmeb_v3.1.sql           # 新装整库脚本
│       ├── v3.0-to-v3.1-upgrade.sql # 仅从 v3.0 升级时用
│       └── local-config-align.sql   # 本地 URL 对齐（本机已用）
└── frontend/
    ├── admin/               # Vue3 + Vite 管理后台（开发端口通常 9527）
    ├── uni-app/             # H5 / 小程序 / App（uni-app）
    └── pc/                  # PC 商城（按需）
```

**说明：** 移动端是 **uni-app**，不是 Android Studio 原生 Java 工程；打包 App 可用 HBuilderX 或 `uni-app` 的 `dev:app` / `build:app`。

官方文档：https://doc.crmeb.com/java/crmeb_java_30/41909  
在线演示（账号与本地库无关）：https://admin.java.crmeb.net（`demo` / `crmeb.com`）

---

## 2. 环境要求

| 组件 | 要求 |
|------|------|
| **JDK** | **17（Java 17）** — 与 `backend/pom.xml` 的 `release=17` 一致；编译与运行均使用 JDK 17 |
| Maven | 3.6+ |
| MySQL | **8.0** |
| Redis | 默认 `127.0.0.1:6379`，无密码（与 yml 一致） |
| Node.js | 管理后台 / uni-app 建议 **Node 16+**（admin 使用 Vite 5） |
| IDE | IntelliJ IDEA 跑两个 Spring Boot 主类；前端 VS Code / Cursor |

---

## 3. 数据库初始化

### 3.1 全新安装（推荐）

1. 创建库并导入 **`backend/sql/Crmeb_v3.1.sql`**。  
   本仓库 SQL 开头为：

   ```sql
   create database `dexter_dianshang`;
   use `dexter_dianshang`;
   ```

2. 确认 `application.yml` / `application-dev.yml` 中 JDBC URL 与库名一致：

   ```text
   jdbc:mysql://127.0.0.1:3306/dexter_dianshang?...
   username: root
   password: 123456   # 按本机 MySQL 修改
   ```

### 3.2 `v3.0-to-v3.1-upgrade.sql` 是什么？

- **仅当** 数据库已是官方 **v3.0 全量库**、代码升级到 v3.1 时执行。
- **从零安装不要跑升级脚本**，直接用 `Crmeb_v3.1.sql`。
- 执行前 **整库备份**。

### 3.3 本地 URL 对齐（图片 / 接口域名）

执行（或核对）`backend/sql/local-config-align.sql`：

```sql
USE `dexter_dianshang`;

UPDATE `eb_system_config` SET `value` = 'http://127.0.0.1:8080', `update_time` = NOW()
WHERE `name` IN ('localUploadUrl', 'site_url', 'api_url');

UPDATE `eb_system_config` SET `value` = 'http://127.0.0.1:8081', `update_time` = NOW()
WHERE `name` = 'front_api_url';
```

**踩坑：** 若 `eb_system_config` 里仍是演示站域名，会出现 **登录页背景 / 商品图 404**、H5 请求错域。

---

## 4. 后端构建与启动

### 4.1 Maven 构建（正确方式）

在 **父工程** 目录执行，**不要**只在 `crmeb-common` 子模块点 IDEA Install：

```powershell
cd "c:\Users\EDY\Desktop\安卓app\crmeb_java\backend"
mvn clean install -DskipTests
```

**踩坑：`crmeb-common` … did not assign a file to the build artifact`**

- 原因：未完整 **compile → package** 就单独 `install`，或构建时间极短（0.x 秒）说明未真正编译。
- 处理：在 `backend` 根目录 `mvn clean install -DskipTests`。
- IDEA：**Settings → Build → Compiler → Annotation Processors** 勾选 **Enable annotation processing**（Lombok 大量注解）。

### 4.2 启动两个服务

| 模块 | 主类 | 默认端口 |
|------|------|----------|
| crmeb-admin | `com.zbkj.admin.CrmebAdminApplication` | **8080** |
| crmeb-front | `com.zbkj.front.CrmebFrontApplication` | **8081** |

**配置要点：**

- `crmeb-admin` 的 `application-dev.yml` 中 `spring.profiles.active: dev`（dev 环境）。
- **图片物理路径** `crmeb.imagePath` 必须指向 **`backend/crmebimage` 的上一级目录**，且 **以 `/` 结尾**：

  ```yaml
  # crmeb-admin / crmeb-front 的 application.yml 或 application-dev.yml
  crmeb:
    imagePath: C:/Users/EDY/Desktop/安卓app/crmeb_java/backend/
  ```

  静态资源实际目录：`backend/crmebimage/`（商品图、登录背景等）。

**踩坑（图片不显示）：**

1. `imagePath` 仍为占位符「你的站点绝对路径」→ 404。  
2. 只改了 yml，未改数据库 `eb_system_config` 的 `localUploadUrl` / `site_url`。  
3. `jwt-secret` 留空时每次重启生成临时密钥 → **需重新登录**（属正常）。

**Redis：**

- admin 默认 `database: 10`，front 默认 `database: 10`，微信 token 等用 `second.database: 13`。  
- Redis 未启动会导致启动失败或缓存异常。

---

## 5. 前端部署

### 5.1 管理后台（admin）

```powershell
cd "c:\Users\EDY\Desktop\安卓app\crmeb_java\frontend\admin"
npm install
npm run dev
```

- 开发地址：**http://127.0.0.1:9527/**（Vite 默认，以终端输出为准）
- API 配置：`frontend/admin/.env.development`

  ```env
  VITE_APP_BASE_API = 'http://127.0.0.1:8080'
  ```

  须与 **crmeb-admin** 端口一致；改端口后需 **重启** `npm run dev`。

**本地默认管理员（导入 Crmeb_v3.1.sql 且未改数据）：**

| 项目 | 值 |
|------|-----|
| 用户名 | `admin` |
| 密码 | `123456` |

**C 端测试用户（可选）：**

| 手机号 | 密码 |
|--------|------|
| `13000000000` | `crmeb@123456` |

### 5.2 商城 H5（uni-app）

```powershell
cd "c:\Users\EDY\Desktop\安卓app\crmeb_java\frontend\uni-app"
npm install
npm run dev:h5
```

- 接口配置：`frontend/uni-app/config/app.js`

  ```javascript
  export const HTTP_REQUEST_URL = 'http://127.0.0.1:8081';
  ```

  须与 **crmeb-front** 一致。

**踩坑：** 只起 admin 不起 front → H5 全部接口失败；只起 front 不起 Redis/MySQL → 500。

---

## 6. 端口与联调一览

| 服务 | 地址 | 说明 |
|------|------|------|
| crmeb-admin | http://127.0.0.1:8080 | 管理 API + 图片静态映射 |
| crmeb-front | http://127.0.0.1:8081 | 商城 API |
| admin 前端 | http://127.0.0.1:9527 | Vue 管理 UI |
| uni-app H5 | 以 `npm run dev:h5` 终端为准 | 一般 5173 等 |
| MySQL | 127.0.0.1:3306 | 库名 `dexter_dianshang` |
| Redis | 127.0.0.1:6379 | 无密码 |

推荐启动顺序：**MySQL → Redis → mvn install（首次）→ admin + front → admin 前端 → uni-app H5**。

---

## 7. 踩坑清单（交接重点）

| # | 现象 | 原因 | 处理 |
|---|------|------|------|
| 1 | Maven `crmeb-common` install 失败 | 子模块单独 install、无 jar 产物 | 在 `backend` 根目录 `mvn clean install -DskipTests` |
| 2 | 登录页 / 商品无图 | `imagePath` 或 DB 域名不对 | 改 yml + 跑 `local-config-align.sql` |
| 3 | 管理后台接口 404 / 跨域 | admin 未启动或 `VITE_APP_BASE_API` 端口错 | 8080 与 `.env.development` 对齐 |
| 4 | H5 白屏 / 接口失败 | front 未启动或 `app.js` 仍指向外网 | 8081 与 `HTTP_REQUEST_URL` 对齐 |
| 5 | 升级脚本误执行 | 新装跑了 v3.0→v3.1 upgrade | 新装只用 `Crmeb_v3.1.sql` |
| 6 | 每次重启都要重新登录 | JWT 临时密钥 | 生产环境配置固定 `crmeb.jwt-secret` 或环境变量 `CRMEB_JWT_SECRET` |
| 7 | JDK 版本不对 | 使用 JDK 8 编译或运行 Java 17 产物 | 后端统一 **JDK 17**，同步 Maven 与 IDE 的 JDK 配置 |
| 8 | 路径含中文 | Windows 下图片路径 | 使用正斜杠 `C:/Users/.../backend/`，与当前工程路径一致 |

---

## 8. 换机器 / 换目录 checklist

1. 安装 MySQL 8、Redis、JDK 17、Maven、Node。
2. 导入 `Crmeb_v3.1.sql`（或迁移原库）。
3. 全局搜索替换配置中的 **旧绝对路径**：
   - `backend/crmeb-admin/src/main/resources/application*.yml` → `crmeb.imagePath`
   - `backend/crmeb-front/src/main/resources/application*.yml` → `crmeb.imagePath`
4. 修改 MySQL 账号密码（admin + front 两处 datasource）。
5. 执行 `local-config-align.sql`（或按新 IP/端口改 SQL）。
6. `mvn clean install -DskipTests`
7. 启动 `CrmebAdminApplication`、`CrmebFrontApplication`
8. `frontend/admin` → `npm install && npm run dev`
9. `frontend/uni-app` → `npm install && npm run dev:h5`
10. 浏览器验证：9527 登录、商品图、H5 首页。

---

## 9. 与本工作区其他项目的关系

```
安卓app/
├── GoodWeather-Project/    # 好天气 Android + Flask（见《部署交接说明-GoodWeather.md》）
└── crmeb_java/             # 本商城项目（独立，无代码依赖）
```

两套项目 **互不影响**；仅共用「本机 MySQL/Redis 端口占用」需注意。

---

## 10. 参考

- 中文 README：`README_ZH.md`
- 安装视频 / 步骤：https://doc.crmeb.com/java/crmeb_java_30/41909
- 接口文档：https://s.apifox.cn/f6079100-abee-40fe-959d-846e44f1a048
- Gitee：https://gitee.com/ZhongBangKeJi/crmeb_java
