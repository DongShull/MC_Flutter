# 06 多设备适配（手机 / 平板 / TV pad）

> 定位：mc_flutter 取代 Android 原生，成为 MovieClaw 唯一客户端。
> 本文档约束所有 feature 在三种形态下的布局与交互。

## 1. 形态判定（core/designsystem/adaptive.dart）
- `McDeviceForm`：phone / tablet / tv。
- 判定顺序：显式覆盖（McFormOverride provider，测试/设置可改）→ TV
  （hasNavigationBarGestureInsets==false 且 shortestSide>=960 或
  diagonal>=9 英寸启发 + Android TV feature）→ 平板（shortestSide>=600）→ 手机。
- `McWindowClass`：compact(<600) / medium(600–1024) / expanded(>=1024)。
  断点与 Material 3 window size classes 一致。

## 2. 布局规则
| 维度 | 手机 | 平板 | TV pad |
|---|---|---|---|
| 全局导航 | 底部悬浮胶囊（现状保留） | 左侧 NavigationRail（64px 折叠 / 256px 展开） | 左侧 Rail + 焦点高亮，遥控器 D-pad 可达 |
| 媒体墙网格 | 3 列（现状） | 列数随宽度自适应 `adaptiveGridCrossAxisCount`（每格约 160px） | 5–7 列，条目放大，焦点放大 1.06 |
| 详情页 | 单列（现状） | 左海报右信息的双栏 master-detail | 双栏 + 焦点化操作条 |
| 播放页 | 全屏（现状） | 全屏 + 侧滑抽屉 | 全屏 + 常驻底部控制条（D-pad 聚焦） |
| 设置/列表 | 单列 | 600+ 时 master-detail（设置左菜单右详情） | 双栏 + 焦点 |

## 3. TV 交互铁律
1. 一切可交互元素必须可聚焦：MaterialState focus 高亮统一走 `McFocusRing`
   （2px accent 描边 + 外发光），不允许只有 ripple 的控件。
2. D-pad 语义：上下=条目/网格移动，左右=页内横移或 Rail 切换，
   确认=select，返回=pop；菜单键=各页现有 popup。
3. 焦点记忆：列表/网格翻页后恢复原焦点位置。
4. 禁止依赖触摸手势的唯一操作（播放页手势层在 TV 形态下自动启用常驻按钮）。

## 4. 实施里程碑（M6）
- M6.1 core 适配层：adaptive.dart（判定/断点/AdaptiveScaffold/adaptiveGrid/McFocusRing）。✅本提交
- M6.2 root 壳适配：root_page 按形态切换 底部胶囊/Rail，角标与 tab 总线不变。
- M6.3 浏览类适配：library/discover/search/detail/subscriptions/reels 网格自适应+详情双栏。
- M6.4 其余功能：settings master-detail、player TV 常驻控制条、activity/agent/offline 网格化。
- M6.5 验收：三形态冒烟（手机 390x844 / 平板 1024x1366 / TV 1920x1080）、analyze+test 全绿、PROGRESS.md 记录。

## 5. 取代 Android 原生的边界
- Flutter 承接全部业务功能；Android 原生工程仅作 API/交互参考，不再演进。
- 平台通道类 TODO（离线字节搬运、播放会话协商、agent 流式）随 M6 一并收口。
