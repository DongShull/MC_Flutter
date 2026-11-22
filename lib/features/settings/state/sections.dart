// 设置分区注册表（P4）：25 个 parity 分区 + 激活 + 定时任务。
// 来源：web settingsSectionGroups（mock-data.ts）与安卓 SettingsSection
// （SettingsScreens.kt）。全部 25 个分区在 P4 均为原生实现，
// web_managed 不再承载任何分区，只保留作未知深链的兜底。
// 成员可见：profile / devices / notifications / appearance（与 web
// MEMBER_SECTION_IDS 一致）；其余仅管理员。

/// 一个设置分区。
class SettingsSectionSpec {
  const SettingsSectionSpec({
    required this.id,
    required this.title,
    required this.group,
    required this.route,
    this.subtitle = '',
    this.adminOnly = true,
  });

  /// 与 web settings id 一致。
  final String id;
  final String title;
  final String group;
  final String route;
  final String subtitle;
  final bool adminOnly;
}

/// 分组顺序与 web settingsSectionGroups 一致。
const List<String> settingsGroups = [
  '总览',
  '账号',
  '成员',
  '下载',
  '媒体库',
  '集成',
  '系统',
];

/// 全部设置分区（按分组顺序）。
const List<SettingsSectionSpec> settingsSections = [
  SettingsSectionSpec(
    id: 'overview',
    title: '总览',
    group: '总览',
    route: '/settings/overview',
    subtitle: '开局清单与链路体检',
  ),
  SettingsSectionSpec(
    id: 'profile',
    title: '个人信息',
    group: '账号',
    route: '/settings/profile',
    adminOnly: false,
  ),
  SettingsSectionSpec(
    id: 'devices',
    title: '我的设备',
    group: '账号',
    route: '/settings/devices',
    subtitle: '已配对的登录设备与播放器',
    adminOnly: false,
  ),
  SettingsSectionSpec(
    id: 'activate',
    title: '设备激活',
    group: '账号',
    route: '/settings/activate',
    subtitle: '批准新设备的登录请求',
    adminOnly: false,
  ),
  SettingsSectionSpec(
    id: 'notifications',
    title: '通知与提醒',
    group: '账号',
    route: '/settings/notifications',
    subtitle: '选择接收哪些推送事件',
    adminOnly: false,
  ),
  SettingsSectionSpec(
    id: 'appearance',
    title: '外观',
    group: '账号',
    route: '/settings/appearance',
    subtitle: '语言与主题',
    adminOnly: false,
  ),
  SettingsSectionSpec(
    id: 'members',
    title: '成员',
    group: '成员',
    route: '/settings/members',
    subtitle: '账号、权限与状态',
  ),
  SettingsSectionSpec(
    id: 'subscription',
    title: '订阅设置',
    group: '下载',
    route: '/settings/subscription',
    subtitle: '智能默认、智能计划与记忆',
  ),
  SettingsSectionSpec(
    id: 'sites',
    title: '站点',
    group: '下载',
    route: '/settings/sites',
    subtitle: '资源站点接入与浏览器扩展',
  ),
  SettingsSectionSpec(
    id: 'downloaders',
    title: '下载器',
    group: '下载',
    route: '/settings/downloaders',
    subtitle: '下载客户端与限速',
  ),
  SettingsSectionSpec(
    id: 'import-watch',
    title: '导入监听',
    group: '下载',
    route: '/settings/import-watch',
    subtitle: '自动入库目录',
  ),
  SettingsSectionSpec(
    id: 'scrape',
    title: '刮削',
    group: '媒体库',
    route: '/settings/scrape',
    subtitle: '元数据与图片偏好',
  ),
  SettingsSectionSpec(
    id: 'playback',
    title: '播放设置',
    group: '媒体库',
    route: '/settings/playback',
    subtitle: '转码 / 预览图 / 缓存',
    adminOnly: false,
  ),
  SettingsSectionSpec(
    id: 'drives',
    title: '网盘',
    group: '媒体库',
    route: '/settings/drives',
    subtitle: '网盘账号与导入设置',
  ),
  SettingsSectionSpec(
    id: 'app-push',
    title: '应用推送',
    group: '集成',
    route: '/settings/app-push',
    subtitle: '推送通道与我的事件偏好',
  ),
  SettingsSectionSpec(
    id: 'im-push',
    title: 'IM 推送',
    group: '集成',
    route: '/settings/im-push',
    subtitle: '即时通讯推送配置',
  ),
  SettingsSectionSpec(
    id: 'webhook',
    title: 'Webhook',
    group: '集成',
    route: '/settings/webhook',
    subtitle: '事件推送端点',
  ),
  SettingsSectionSpec(
    id: 'llm',
    title: '模型接入',
    group: '集成',
    route: '/settings/llm',
    subtitle: 'LLM 供应商与 ChatGPT 计划',
  ),
  SettingsSectionSpec(
    id: 'mcp',
    title: 'MCP',
    group: '集成',
    route: '/settings/mcp',
    subtitle: '模型上下文协议服务',
  ),
  SettingsSectionSpec(
    id: 'ai',
    title: 'AI 设定',
    group: '集成',
    route: '/settings/ai',
    subtitle: '默认模型、联网搜索与搜索预设',
  ),
  SettingsSectionSpec(
    id: 'cloud',
    title: '云',
    group: '系统',
    route: '/settings/cloud',
    subtitle: 'MovieClaw Cloud 连接',
  ),
  SettingsSectionSpec(
    id: 'app',
    title: '应用',
    group: '系统',
    route: '/settings/app',
    subtitle: '更新、GitHub Token 与识别模型',
  ),
  SettingsSectionSpec(
    id: 'plugins',
    title: '插件',
    group: '系统',
    route: '/settings/plugins',
    subtitle: '内置插件与功能开关',
  ),
  SettingsSectionSpec(
    id: 'network',
    title: '网络',
    group: '系统',
    route: '/settings/network',
    subtitle: '代理与上游地址',
  ),
  SettingsSectionSpec(
    id: 'logs',
    title: '系统日志',
    group: '系统',
    route: '/settings/logs',
    subtitle: '服务端日志浏览',
  ),
  SettingsSectionSpec(
    id: 'scheduled-tasks',
    title: '定时任务',
    group: '系统',
    route: '/settings/scheduled-tasks',
    subtitle: '后台定时任务开关与周期',
  ),
  SettingsSectionSpec(
    id: 'external-access',
    title: '外部访问',
    group: '系统',
    route: '/settings/external-access',
    subtitle: '外部地址与 Web 端口',
  ),
];

/// 按角色过滤后的分区：成员只看到个人分区。
List<SettingsSectionSpec> visibleSections(bool isAdmin) =>
    settingsSections.where((s) => isAdmin || !s.adminOnly).toList();
