/// 全局文案令牌（对齐飞牛 ui_strings_zh.txt 口径；新文案先进这里再引用）。
abstract final class McStrings {
  // —— 启动 / 连接 ——
  static const appName = 'MovieClaw';
  static const connecting = '正在连接…';
  static const connectionLost = '主连接已断开';
  static const useSecureConnection = '使用安全连接';
  static const editConnection = '修改连接设置';
  static const welcomeBack = '欢迎回来';
  // —— 播放 ——
  static const skipIntro = '跳过片头';
  static const playbackFailed = '播放失败';
  static const needTranscodeConfirm = '该片源需要服务器转码后播放，可能增加延迟与功耗。要继续吗？';
  static const rejectedByServer = '服务器拒绝了本次播放请求（可能无可用转码通道），已尝试按原始链接播放。';
  static const continuePlay = '继续播放';
  // —— 通用 ——
  static const retry = '重试';
  static const confirm = '确定';
  static const cancel = '取消';
  static const delete = '删除';
  static const save = '保存';
  static const loading = '加载中…';
  static const empty = '暂无内容';
  static const networkError = '网络错误，请检查地址后重试';
  // —— 订阅 ——
  static const subsHomeTitle = '订阅';
  static const subsEmptyTitle = '从一部想看的作品开始';
  static const subsEmptyBody = '去发现页挑选一部剧集或电影，打开详情并点击「订阅追踪」，有合适资源时会自动下载入库。';
  static const subsEmptyNoPermission = '当前账号暂未开启订阅权限，请联系管理员为你开启。';
  static const subsGoDiscover = '去发现剧集';
  static const subsLoadFailed = '订阅列表加载失败';
  static const subsRecentTitle = '刚刚入库';
  static const subsScheduleTitle = '日程';
  static const subsTvShelfTitle = '剧集订阅';
  static const subsMovieShelfTitle = '电影订阅';
  static const subsViewAll = '查看全部';
  static const subsViewSubscription = '查看订阅';
  static const subsNewEpisodes = '新 N 集';
  static const subsToday = '今天';
  static const subsPlay = '播放';
  static const subsOpenSubscriptionDetail = '查看订阅详情';
  static const subsOpenMediaDetail = '查看影片详情';
  static const subsContinuePlay = '继续播放';
  static const subsNewEpisode = '新一集';
  static String subsNewEpisodesN(int n) => '新 $n 集';
  static const subsMovieWord = '电影';
  static const subsTimePending = '待定';
  static const subsScheduleEmptyDay = '这一天暂无安排';
  static String subsCountN(int n) => '$n 部';
  static String subsScheduleCaption(String date, int count) => '$date · $count 部';
  static const subsWallSectionActive = '进行中';
  static const subsWallSectionPaused = '已暂停';
  static String subsWallSummary(int total, int active) =>
      active > 0 ? '共 $total 部 · $active 部进行中' : '共 $total 部';
  static String subsWallSection(String label, int count) => '$label · $count';
  // —— 投屏 ——
  static const castToDevice = '投放到设备';
  static const stopCast = '停止投屏';
  static const noCastDevice = '未发现局域网内的 DLNA 设备';
  static const castingNow = '正在投屏';
  // —— 我的页（对应鸿蒙 MorePage） ——
  static const moreTab = '我的';
  static const notLoggedIn = '未登录';
  static const switchAccount = '切换账号';
  static const sectionConversations = '会话';
  static const sectionDownloads = '下载';
  static const sectionServer = '服务器';
  static const conversationsEmptyTitle = '还没有会话';
  static const conversationsEmptyHint = '在下方输入框里问点什么吧。';
  static const runningBadge = '进行中';
  static const forkSessionAction = '续接';
  static const renameSessionAction = '重命名';
  static const renameSessionTitle = '重命名会话';
  static const deleteSessionTitle = '删除会话';
  static const deleteSessionConfirmBody = '将彻底删除「%s」，无法恢复。';
  static const renamedToast = '已重命名';
  static const deletedToast = '已删除';
  static const forkFailedToast = '续接会话失败';
  static const groupToday = '今天';
  static const groupYesterday = '昨天';
  static const groupEarlier = '更早';
  static const downloadsTitle = '离线下载';
  static const downloadsSubtitle = '进行中与已下载的内容在这里管理';
  static const currentServerLabel = '当前服务器';
  static const serverNotConnected = '未连接服务器';
  static const serverSettings = '服务器设置';
  static const pendingTileTitle = '待处理';
  static const pendingTileDetail = '查看提醒';
  static const updateTileTitle = '可用更新';
  static const updateTileDetail = '查看版本详情';
  static const itemsSuffix = ' 项';
  static const settingsGroupAccount = '账号';
  static const settingsGroupMedia = '媒体库';
  static const settingsGroupSystem = '系统';
  static const settingsDevicesTitle = '设备';
  static const settingsDevicesSubtitle = '登录着你的账号的浏览器、App、命令行与转码器';
  static const settingsPlaybackTitle = '播放';
  static const settingsPlaybackSubtitle = '远程转码与播放体验';
  static const settingsMaintenanceTitle = '更新与维护';
  static const settingsMaintenanceSubtitle = '版本更新与应用重启';
  static const settingsWebTitle = 'Web';
  static const settingsWebSubtitle = '在浏览器里打开服务器管理页';
  static const accountSwitcherTitle = '切换账号';
  static const accountSwitchedToastPrefix = '已切换到 ';
  static const accountSwitchFailedToast = '切换失败：目标账号没有已存令牌';
}