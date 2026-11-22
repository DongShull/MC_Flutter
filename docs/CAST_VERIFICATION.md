# 投屏（DLNA）代码走查与真机验证清单（P3）

> 范围：`lib/core/cast/`（`DlnaDiscovery` SSDP 发现、
> `DlnaRenderer` SOAP AVTransport、`CastController`）与播放页
> `cast_sheet.dart`。本次只做了**代码走查 + 本地回环假设备测试**
> （见 `test/cast_soap_test.dart`），**没有真机**，以下凡写“未验证”
> 都是实话，不要当成已验证。

## 走查结论（代码级）

| # | 检查点 | 结论 |
|---|---|---|
| 1 | SSDP M-SEARCH | 组播 `239.255.255.250:1900`，`ST: MediaRenderer:1`，发两次；应答按 `LOCATION`/`USN` 去重，只认 `MediaRenderer`/`AVTransport`/`upnp:rootdevice`。回环假设备测试通过；真机未验证 |
| 2 | 设备描述解析 | 拉 `LOCATION` 的 XML，取 `friendlyName` 与 AVTransport `controlURL`（相对地址按 `Uri.resolve` 拼绝对地址）。正则解析 XML（非 XML 解析器）：描述里若有命名空间前缀变体或多个 service，可能取错——见未完成 |
| 3 | SetAVTransportURI + Play | SOAP 1.1 信封 + `SOAPACTION` 头 + 最小 DIDL-Lite（含 `videoItem.movie` 与 `http-get:*:video/*:*`）。回环假设备测试通过 |
| 4 | 失败是否诚实 | **P3 已修**：此前 `_action` 收到 500 也不抛，`CastController` 会把失败当成功置 `casting=true`。现 `setUriAndPlay` 在非 200 时抛错，`castTo` 据实置 `lastError`；`play`/`pause`/`stop` 尽力而为，返回是否成功 |
| 5 | `_nextPacket` 重复 complete | **P3 已修**：同一 read 事件多次触发时第二次 `complete` 会抛 `StateError`；现加 `isCompleted` 守卫 |
| 6 | 进度/状态查询 | **P3 新增** `getPositionInfo`（`RelTime`/`TrackDuration`）与 `getTransportState`；播放页暂未接 UI（投屏时不显示远端进度），先供后续使用 |
| 7 | 投屏地址来源 | 播放页 `_showCastSheet` 取 `PlayerController.lastStreamUrl`（当前会话流地址）直连渲染器，不走 MC 服务器。HLS 会话地址（master.m3u8）很多电视渲染器播不了——见未完成 |
| 8 | 订阅/事件 | 无 GENA 事件订阅：渲染器播完、出错、被别家抢占，App 不知道；`casting` 态只在本地维护。未验证 |
| 9 | 权限 | 安卓 `INTERNET`/`ACCESS_NETWORK_STATE`/`ACCESS_WIFI_STATE` 已在 Manifest；**已确认缺失**：`CHANGE_WIFI_MULTICAST_STATE`（部分机型收组播应答要它）不在 Manifest 里，`NSLocalNetworkUsageDescription` 不在 `Info.plist` 里（iOS 14+ 上没有该键就弹不出局域网权限，SSDP 会被静默拦截）。缺失是否真挡事，需真机验证 |
| 10 | 发现超时 | `search()` 默认 3 秒；局域网设备多/响应慢时可能漏设备。未验证 |

## 真机验证清单（全部未验证，需设备）

前置：手机与目标设备在同一局域网（同一 SSID/网段，无 AP 隔离）。

### 发现
- [ ] 安卓真机：小米电视 / 索尼电视 / LG webOS / 三星 Tizen 各 1 台，`搜索` 能列出设备名（不是 `DLNA 设备` 兜底名）
- [ ] iOS 真机：同上；首次搜索弹 Local Network 权限，拒绝后有明确提示（不是静默空列表）
- [ ] 群晖 / 威联通 DLNA（Media Server 是 DMS 不是 DMR，应**不**出现在列表里）
- [ ] 同一设备只出现一次（USN 去重），设备改名后刷新能更新

### 投屏播放
- [ ] 直链 MP4（download 能力会话的 `streamUrl`）能播出画面与声音
- [ ] HLS 会话地址（master.m3u8）：电视播不了时 App 是否如实报错（而不是一直转圈/假装投屏中）
- [ ] 投屏后本机播放器应暂停（或按产品决策保持），不要两边同时出声
- [ ] 暂停 / 继续 / 停止 三个动作在电视上有对应反应
- [ ] 停止后 `casting` 态清掉，再次投屏能重新 `SetAVTransportURI`

### 边界
- [ ] 设备中途断电/断网：App 在合理时间内（不是永远）报投屏失败
- [ ] 投屏 URL 是需要鉴权的地址时，电视端表现（预期失败，需如实报错）
- [ ] 切集后投屏地址是否更新（`lastStreamUrl` 是否跟着当前集走）
- [ ] 锁屏/切后台后投屏是否继续（无后台保活，预期由电视端自行续播）

## 未完成（P3 之后）

- [ ] `friendlyName`/`controlURL` 改用真正的 XML 解析（当前正则在命名空间变体下可能取错）
- [ ] `NSLocalNetworkUsageDescription`（iOS 局域网权限文案）缺失：`Info.plist` 已确认无该键，需补上，否则 iOS 14+ 上 SSDP 会被系统静默拦截（真机验证前无法确认影响面）
- [ ] Android multicast lock：`CHANGE_WIFI_MULTICAST_STATE` 已确认不在 Manifest 里；部分机型收不到组播应答时要加 `WifiManager.MulticastLock`，需真机验证
- [ ] HLS 投屏策略：电视播不了 m3u8 时是转直链 MP4、还是提示“该设备不支持”、还是走服务端转码——需产品决策
- [ ] GENA 事件订阅（播完/被抢占通知）与远端进度 UI（`getPositionInfo` 已备好，未接 UI）
- [ ] 投屏选集/进度同步：投屏中切集、拖进度是否同步到渲染器（目前只有 Play/Pause/Stop）
- [ ] 上述真机验证清单全部未做（无设备）
