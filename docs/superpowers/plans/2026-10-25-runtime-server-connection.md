# 移动端运行时服务器连接 Implementation Plan

> **For agentic workers:** Implement this plan task-by-task in the current workspace, preserving existing uncommitted changes. Use targeted edits and the checks below; user has authorized implementation of runtime IP configuration and backend connectivity.

**Goal:** 为手机增加持久化服务器 IP/域名及端口配置，使换局域网 IP 后无需重新打包，并交付可升级安装的 APK。

**Architecture:** 手机保存版本化的单设备连接配置；两个匿名只读后端接口验证商城与图片服务，验证成功才应用候选配置。原生启动先检查已保存连接，失败或未配置时停留在连接设置页；成功后进入现有引导和商城。接口地址、上传、图片及本地资源链接从同一连接配置派生，切换不同接口地址时隔离旧账号与业务缓存。

**Tech Stack:** uni-app Vue 3、Pinia、Spring Boot Java 8、HBuilderX 5.26、Android APK 本地资源重建及独立证书签名。

---

## Configuration Safety Review

### Change Class And Confirmation

| Class | Required Checks | Confirmation Path | Decision Rationale |
| --- | --- | --- | --- |
| 低风险开发实现 | 地址与端口语义校验、匿名探测、缓存隔离、错误恢复、构建与设备验证 | 用户已要求增加该功能；具体连接地址由使用者点击“保存并连接”确认 | 新增后端只读自检及手机本地配置，不修改数据库、全站域名或生产路由 |

### Contract

| Setting | Meaning | Default | Bounds / Invariants |
| --- | --- | --- | --- |
| version | 持久化结构版本 | 1 | 未知版本或损坏配置不用于连接 |
| scheme | 协议 | http | 仅 http / https |
| host | IP 或域名 | 首次输入 | 非空；禁止凭据、查询、片段和脚本协议；IPv4 各段 0–255，域名标签合法 |
| apiPort | 商城端口 | 8081 | 整数 1–65535 |
| imagePort | 图片服务端口 | 8080 | 整数 1–65535 |
| connection proof | 两个候选地址的检测结果 | 无 | 必须匹配当前表单候选地址及后端服务标识、协议版本；编辑表单后失效 |

`apiBaseUrl = scheme + "://" + host + ":" + apiPort`，图片地址同理使用 imagePort。允许解析用户输入的完整 http(s) origin 并在预览中明确显示生效端口，不接受携带账号密码或业务路径的地址。

### Validation, Application And Recovery

- 探测请求不发送 Authorization、Cookie、手机号等账号信息，不通过已有业务请求封装注入旧 token。
- 商城接口 `GET /api/front/connection/info` 返回 `service=crmeb-front`、`protocolVersion=1`、推荐图片端口。只将这个确切路径加入匿名白名单。
- 图片接口 `GET /api/public/connection/info` 返回 `service=crmeb-admin`、`protocolVersion=1`、`imageRoot=/crmebimage` 和目录可读状态；不暴露服务器文件系统路径。
- 每次检测有有限超时；表单在检测过程中变化时丢弃旧检测结果，失败的候选配置不持久化。
- 保存失败不切换连接；不同 API origin 保存成功后清除旧登录与服务缓存，再重启应用，以刷新所有模块中的地址和组件状态。
- 相同 API origin 的图片配置调整保留登录，刷新图片相关缓存；设备连接配置不被一般“清理缓存”误删。
- 原生未配置或启动检测失败时，设置页可离线显示与修改；启动探测成功前不进行账号请求。
- 已保存地址在设置页可重新载入。上次有效配置不会被失败检测覆盖。
- 原生图片/资源 URL 转换仅在启用运行时连接时生效；本地 `/crmebimage/` 资源以及旧 loopback/LAN 图片域名映射到当前图片服务，外部 CDN、付款及授权链接保留。
- 执行期间只启动或重启完成验证所需的本地开发服务；不提交已有工作区改动、不更改生产站点配置。

## File Structure And Tasks

### Task 1: 运行时连接契约与持久化

**Create:** `frontend/uni-app/config/serverConnection.js`。
**Modify:** `frontend/uni-app/config/app.js`。
**Tests:** 用 Node 内建 test runner 验证纯配置逻辑及模拟 uni storage/request 的协议行为；最终测试文件放项目测试目录，临时 bundling 和日志放 `/tmp`。

- [ ] 实现合法 host、http(s) origin、端口及损坏缓存的校验，派生 API/image origin。
- [ ] 实现无凭据双服务探测、超时、服务身份/版本检查与候选指纹。
- [ ] 实现成功检测后的配置提交、不同接口地址的旧缓存隔离、相同地址的登录保留、图片缓存更新。
- [ ] 实现共享启动检查 promise、连接就绪状态，以及相应的拒绝/恢复行为。
- [ ] 使用 ES live bindings / getter 保持已有 HTTP_REQUEST_URL、HTTP_H5_URL 和 $config 消费方式兼容。
- [ ] 实现响应中的本地图片和资源地址规范化；覆盖数组、对象、HTML、旧 LAN 图片域名、外部 CDN 不变。

### Task 2: 后端匿名连接自检

**Create:** `backend/crmeb-front/src/main/java/com/zbkj/front/controller/ConnectionController.java`。
**Create:** `backend/crmeb-admin/src/main/java/com/zbkj/admin/controller/MobileConnectionController.java`。
**Modify:** `backend/crmeb-front/src/main/java/com/zbkj/front/config/WebConfig.java`。
**Modify:** `backend/crmeb-front/src/main/resources/application-dev.yml`（推荐图片端口可通过 CRMEB_MOBILE_IMAGE_PORT 指定；默认 8080）。

- [ ] 检查 admin 的真实 security 配置，保证新 public 自检端点匿名可用且不扩大其他权限。
- [ ] 增加两个只读端点及稳定、可验证的响应标识。
- [ ] 图片目录检测使用既有 CrmebConfig.imagePath，不返回绝对路径，不创建文件。
- [ ] 商城白名单仅新增精确自检路径。
- [ ] 用控制器协议测试及实际匿名 curl 验证 metadata、错误状态和旧受保护接口仍要求登录。

### Task 3: 设置界面、启动和离线入口

**Create:** `frontend/uni-app/pages/server_connection/index.vue`。
**Modify:** `frontend/uni-app/pages.json`、`App.vue`。
**Modify:** `components/accountDrawer/index.vue`、`pages/user/index.vue`。

- [ ] 用本地 UI 提供 IP/域名、API 端口、图片端口、协议、当前生效地址预览、“检测连接”和“保存并连接”。
- [ ] 检测状态分别展示商城与图片服务；保存前清楚说明不同服务器地址需要重新登录。
- [ ] APP-PLUS 的启动首屏为连接页；已有连接在成功检查后进入原引导页，无配置或失败则停留。
- [ ] App.onLaunch 和 onMounted 的服务/账号初始化等待同一个启动检查，不在未确认服务器上发送 token。
- [ ] 在账户菜单添加不依赖登录/后台数据的服务器设置入口；H5 开发模式也可操作以便验证。
- [ ] 设置保存后原生重启，H5 完整重新加载现有引导路线，使所有模块重新读取持久化地址。

### Task 4: 业务地址覆盖与缓存一致性

**Modify:** `frontend/uni-app/utils/request.js`、`utils/util.js`（如有必要）、`utils/checkOverdue.js`、验证码 `utils/axios.js`。
**Modify:** `frontend/uni-app/store/app.js`（缓存清理保留连接配置）。

- [ ] 业务响应按配置转换本地图片地址；旧服务器的在途响应不能污染新连接状态。
- [ ] 直接请求、上传、验证码、登录和商品媒体采用当前地址，不只修改请求封装。
- [ ] 清缓存动作保留设备连接配置，断网后仍能进入设置。
- [ ] 检查 HTTP_H5_URL、组件挂载时的 URL 捕获；用重启保证地址一致性。

### Task 5: 验证、一次性升级 APK 与交付

- [ ] 运行前端语义测试；包括非法 IP/端口、协议/服务不匹配、超时、检测不带旧 token、候选变化、保存失败、旧缓存隔离、同地址保留登录、图片转换。
- [ ] 使用 Java 8 构建并验证两个后端；更新本地服务后验证匿名连接自检。
- [ ] 构建 H5 和 APP-PLUS，验证现有 H5 默认 localhost 开发连接未被改变。
- [ ] 浏览器/安卓模拟器验证首次配置、断网设置入口、保存后重启、IP 切换、接口/图片、登录缓存和一般清缓存。
- [ ] 同一 APK 在模拟器中切换两种可达 host（例如电脑 LAN IP 与 Android 模拟器宿主地址），证明无需重打包。
- [ ] 在生成新版 APK 前加载 SEM 要求的 release-build-reproducibility 与 production-readiness-review，输出针对开发包的简要审查并记录回执；不发布到生产。
- [ ] 原生 SDK 未改变时可用之前的原生 APK 重建 www 资源及版本信息，避免不必要的云端排队；保持包名和独立证书，递增 Android versionCode。
- [ ] 验证新版 APK 签名、16 KB ZIP 对齐、覆盖安装、启动、设置页和接口图片。
- [ ] 最终交付文件放 `APK安装包` 下，更新安装与运行时连接说明，保留旧 APK 和独立签名。

## Acceptance

同一台手机在不同可互通局域网中，填写当前后端 IP 并检测成功后，商城接口和图片服务均可连接；关掉重开仍使用保存配置。配置错误或服务不可达时保留原配置并可离线修改。切换不同服务器地址不携带旧账号数据。用户只需要安装一次带配置功能的新版 APK，后续换 IP 不再改源码或打包。
