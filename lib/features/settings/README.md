# feature/settings

- 原 Kotlin 模块：apps/android .../feature/settings（SettingsSectionScreen 及各分区）
- 设计文档：docs/design/05-misc-features.md（设置页规范）
- 状态：✅ 已实现（Avatar 上传除外，见 TODO）
- P4（2026-11-22）：25 个 parity 分区全部原生实现，分区注册表见 state/sections.dart；
  索引页按注册表分组渲染（账号/成员/下载/媒体库/集成/系统 + 总览），手机 push 路由、平板/TV master-detail。
  新增页：总览、外观、通知与提醒、设备激活、成员、订阅设置、规则集、站点（含浏览器扩展同步令牌）、
  下载器、导入监听、刮削、网盘、应用推送、IM 推送、Webhook、模型接入（含 ChatGPT 计划连接）、MCP、
  AI 设定、云、应用、插件、网络、系统日志、定时任务、外部访问。
  web_managed_page.dart 只保留作未知深链兜底，索引不再链向它。
  设备管理唯一实现在 pages/devices_page.dart（/settings/devices）；account 的重复实现已删（P4 合并）。

## 页面
- pages/settings_page.dart — 索引页：按注册表分组（总览 / 账号 / 成员 / 下载 / 媒体库 / 集成 / 系统），入口见 state/sections.dart；手机单列+push，平板/TV master-detail（左分区菜单右详情，TV 菜单项包 McFocusRing）
- pages/profile_page.dart — 个人信息：头像展示 / 修改昵称（PUT /auth/profile）/ 修改密码（PUT /auth/password）/ 退出登录
- pages/devices_page.dart — 我的设备：当前 / 转码专用 badge、改名（PATCH /auth/devices/{id}）、注销（DELETE）、清理 sheet（7/30/90 天，先 dryRun 预览「将注销 N 台设备」）
- pages/playback_page.dart — 播放设置：允许软件转码 / 进度条预览图 / 保留转码产物（PUT /playback/policy，乐观更新失败回滚）+ 硬件能力卡
- pages/maintenance_page.dart — 服务器维护（超管）：版本 / 待更新入口 / 重启（POST /app/restart）/ 存储用量与逐目录清理
- pages/web_managed_page.dart — 未知深链兜底（P4 起不再承载已知分区）+ 服务器地址（浏览器打开）

## 状态
- state/models.dart — McSession / LoginDevice / PlaybackPolicy / StorageState / PendingUpdate 等（对齐 Kotlin Settings.kt / Maintenance.kt，camel/snake 双兼容解析）
- state/mc_api.dart — SettingsApi（McClient + SessionStore），sessionStoreProvider 本域自持
- state/controllers.dart — profile / devices / playback / maintenance 四个 Notifier

## 路由
/routes.dart 导出 /settings 及全部 25 个分区路由 + /settings/activate、/settings/rule-sets、/settings/scheduled-tasks、/settings/maintenance、/settings/web（兜底）

## TODO
- 头像上传（POST /auth/avatar multipart，McClient 暂缺 multipart 支持）
- 浏览器打开 Web 管理页（缺 url_launcher）
- 退出登录后跳转登录页（登录路由落定后补）
