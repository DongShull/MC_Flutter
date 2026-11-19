# feature/settings

- 原 Kotlin 模块：apps/android .../feature/settings（SettingsSectionScreen 及各分区）
- 设计文档：docs/design/05-misc-features.md（设置页规范）
- 状态：✅ 已实现（Avatar 上传除外，见 TODO）

## 页面
- pages/settings_page.dart — 索引页：分组「账号 / 播放 / 服务器」（超管多维护入口），入口：个人信息 / 我的设备 / 通知与提醒 / 播放设置 / 网页托管 / 服务器维护 / 检查更新；手机单列+push（现状零差异），平板/TV master-detail（左分区菜单右详情，TV 菜单项包 McFocusRing）
- pages/profile_page.dart — 个人信息：头像展示 / 修改昵称（PUT /auth/profile）/ 修改密码（PUT /auth/password）/ 退出登录
- pages/devices_page.dart — 我的设备：当前 / 转码专用 badge、改名（PATCH /auth/devices/{id}）、注销（DELETE）、清理 sheet（7/30/90 天，先 dryRun 预览「将注销 N 台设备」）
- pages/playback_page.dart — 播放设置：允许软件转码 / 进度条预览图 / 保留转码产物（PUT /playback/policy，乐观更新失败回滚）+ 硬件能力卡
- pages/maintenance_page.dart — 服务器维护（超管）：版本 / 待更新入口 / 重启（POST /app/restart）/ 存储用量与逐目录清理
- pages/web_managed_page.dart — 网页托管分区说明 + 服务器地址（浏览器打开 TODO：缺 url_launcher）

## 状态
- state/models.dart — McSession / LoginDevice / PlaybackPolicy / StorageState / PendingUpdate 等（对齐 Kotlin Settings.kt / Maintenance.kt，camel/snake 双兼容解析）
- state/mc_api.dart — SettingsApi（McClient + SessionStore），sessionStoreProvider 本域自持
- state/controllers.dart — profile / devices / playback / maintenance 四个 Notifier

## 路由
/routes.dart 导出 /settings、/settings/profile、/settings/devices、/settings/playback、/settings/maintenance、/settings/web

## TODO
- 头像上传（POST /auth/avatar multipart，McClient 暂缺 multipart 支持）
- 浏览器打开 Web 管理页（缺 url_launcher）
- 退出登录后跳转登录页（登录路由落定后补）
