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
  // —— 投屏 ——
  static const castToDevice = '投放到设备';
  static const stopCast = '停止投屏';
  static const noCastDevice = '未发现局域网内的 DLNA 设备';
  static const castingNow = '正在投屏';
}
