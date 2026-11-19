# feature/share

- 原 Kotlin 模块：apps/android .../feature/share（ShareScreen.kt / ShareViewModel）
- 设计文档：docs/design/05-misc-features.md §4.3（访客侧，深链 /share/:slug 独立壳）
- 状态：✅ 已实现（访客侧）
  - `state/models.dart`：SharePublic / SharedItem / SharedCollection / 分集等模型（字段容错解析）
  - `state/mc_api.dart`：GuestShareApi（GET /share/{slug}、POST …/unlock、GET …/item、…/collection、…/episodes?season=）
    - 说明：访客深链 origin 可不同于会话服务器，而 McClient 的 baseUrl 绑定会话（SessionStore
      无公开 setter，login 会覆盖会话落盘），故本域用同一信封协议直连 origin（复用 core 的
      ApiException/unwrapEnvelope 语义）；接口不带成员令牌（访客通道）。
  - `state/share_controller.dart`：ShareController（探测→密码门→条目/合集→分集，401/限流错误文案）
  - `pages/share_page.dart`：密码卡片（密码前不露片名海报）、条目详情（海报/年份/简介/播放）、
    合集列表、季选择 + 分集列表（缺集灰显）、分享说明卡
  - `routes.dart`：`/share` 主路由名不变；新增 `/share/:slug` 深链（origin 经查询参数）
- 播放相关：play() 仅做导航意图 + TODO（铁律 4）；实际播放须走 core/player PlayerService 的
  ShareBackend（/api/v1/share/{slug}/playback/…），续播记本机不写成员进度（05 §4.3）。
