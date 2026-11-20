# 11 - 飞牛深度探测第二轮 + mc_flutter 现状总结（2026-11-20）

## 一、本轮新挖到的飞牛技术点

### 已抄
1. **fl_chart 图表库**：NOTICES.Z 实锤飞牛图表用 fl_chart。mc_flutter activity 观看统计的
   逐日柱状从 LinearProgressIndicator 手搓条迁移到 fl_chart BarChart（触控 tooltip、
   归一化透明度、自动稀疏日期轴），选型与原型完全一致。
2. **Fragment Shader**：flutter_assets/shaders/ 有自定义 stretch_effect.frag（拉伸/果冻
   效果，配合可拉拽列表/海报）。 Flutter FragmentProgram 路线已记录，待有具体交互场景再抄。

### 记录未抄（评估过）
| 飞牛包 | 评估 | 结论 |
|---|---|---|
| liquid_glass_widgets | iOS 26 液态玻璃风格组件 | 等 Flutter 侧生态稳定再评估；当前 M3 视觉已定 |
| spring_animation | iOS 原生弹簧动画桥 | 动画细节迭代期再抄 |
| modal_bottom_sheet | iOS 风格弹层 | 设置抽屉已用 M3 实现，暂不换 |
| lottie（backup_always_on.lottie 等） | 开机/空态动画 | 无对应场景 |
| flutter_zxing | 扫码 | MC 目前无 QR 配对功能；若加「扫码连服务器」直接用 |
| wechat_kit / tencent_kit / flutter_oss_aliyun | 国内社交登录/对象存储 | 不在 MC 功能范围 |
| trim_music + ALIBABAFont | 飞牛音乐模块 | MC 无音乐功能 |
| stretch_effect.frag | 果冻拉伸 shader | 记录路线：FragmentProgram.fromAsset |

## 二、mc_flutter 现状总结（截至本日）

### 完成度
- **功能 18/18**：onboarding/root/library/discover/search/detail/player/subscriptions/
  activity/offline/reels/account/notices/agent/settings/share/update/more，全部真实实现，
  FeaturePlaceholder=0，跨 feature import=0，lib 约 150 文件 2.4 万行。
- **多设备**：phone/tablet/tv 三形态（McDeviceForm+McAdaptiveScaffold+McFocusRing+网格）。
- **平台**：Android 可出 apk；iOS 工程就绪（mac 侧出 ipa）；鸿蒙=ohos SDK+overrides 路线
  （docs/07）；运行时探测 McPlatform（HarmonyUtilApi 口径）。
- **飞牛对齐**：启动页流程（登录→启动页→主界面）、思源黑体全局字体、McIcons 192 处、
  McStrings 文案令牌、fl_chart 图表、分阶段启动/进即用/预取/重试/isolate 解析/
  会话协议/进度上报/协商弹窗。
- **质量**：flutter analyze No issues；test +5 全绿；GitHub main 同步。

### 遗留 TODO（按优先级）
1. 选集数据接口化（PlayerPageArgs 手传 → detail 接口取季/集）
2. 离线字节搬运平台通道（trim_native_download 对应）
3. agent 聊天流式（当前轮询 transcript）
4. cast 投屏真实实现（现为入口占位）
5. stretch_effect 类高级动效（有交互场景时）
6. QR 扫码连服务器（若产品需要，zxing 选型已记录）

### 工程约定
- 新文案进 McStrings；新图标优先 McIcons；业务禁编译期平台分叉（McPlatform.target()）；
  模块化铁律与设计文档索引见 PROGRESS.md 顶部。
