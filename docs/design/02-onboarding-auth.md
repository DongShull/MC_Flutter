# MovieClaw Flutter 登录与引导设计

> 对应原 Android `feature/onboarding` + `core/session`（见 `MovieClaw/docs/design/login-devices.md`、`device-auth.md`、`lan-discovery.md`、`server-addresses.md`）。
> 覆盖：服务器探测与登录流程、凭证存储、多服务器多账号、冷启动快开、局域网发现。

## 1. 登录流程（探测 → bootstrap → 设备登录）

```
用户输入/自动发现地址
  │
  ├─ ① GET /api/v1/health（匿名）
  │     → {status, service, environment, spec_hash, instance_id}
  │     验证可达 + 确认连上的是 movieclaw。探活跟随重定向（http→https）
  │     并采用最终地址作为基址（支持反代强制跳转与子路径部署）。
  │
  ├─ ② bootstrap 检查：health 返回未初始化状态时，自动进入「创建管理员」页
  │
  └─ ③ POST /api/v1/auth/device/login（公开端点，限速同网页登录）
        ← {username, password,
           client: {kind: "flutter",
                    installation_id: <本机安装标识>,
                    name?: "小米 14", platform?, client_version?}}
        → {token, device, session}
```

要点：

- `kind` 用 `flutter`（服务端 `login_device.kind` 枚举若未含，需服务端同步加；在此之前 Android 端先用 `android`，iOS 用 `ios`，按平台报）。
- `installation_id` 存 flutter_secure_storage，首次启动生成 UUID；同一人同设备重新登录时服务端替换旧行（login-devices.md §4）。
- 登录成功后立即 `GET /api/v1/server/addresses` 拉地址簿，存入该服务器的路由表。
- 退出登录调 `DELETE /api/v1/auth/devices/current`（服务端作废令牌），再清本地凭证。
- 手动输入地址只填了主机（如 `192.168.1.10`）时，依次试 `http://主机:3000` → `http://主机` → `https://主机` 的健康检查，用第一个通过的；都不通过按 `http://主机` 继续，让登录步骤报出真实错误。

## 2. 凭证存储（flutter_secure_storage）

对齐 iOS 钥匙串 / Android Keystore 方案：

| 项 | 键 | 值 |
|---|---|---|
| 安装标识 | `mc_installation_id` | UUID，一次生成终身用（也作为播放上报设备标识） |
| 服务器快照列表 | `mc_servers` | JSON 数组，见 §3 |
| 每账号令牌 | `mc_token:<server_origin>:<username>` | `mclaw_...` 令牌明文 |

配置：`AndroidOptions(encryptedSharedPreferences: true)`；iOS `AccessibilityKeychain` 用默认（解锁后可读）。`mc_servers` 快照里**不含令牌明文**（令牌单独按账号存），快照只存：origin、实例号、主机签名公钥 `host_key`、账号名、display name、session 缓存、地址簿、按网络记忆的路由结论。

权限边界：每请求带 `Authorization: Bearer <token>`，彻底不用 Cookie。

## 3. 多服务器多账号快照

对齐 Android「多服务器多账号」与 iOS「多账号完全在本机，切换不联网」：

```json
// mc_servers
[
  {
    "origin": "http://192.168.1.10:3300",
    "instance_id": "9f2c…",
    "host_key": "3qFjm9hy…",
    "accounts": [
      {"username": "yi", "display_name": "Yi", "is_current": true, "device_id": "ld-12"},
      {"username": "mom", "display_name": "妈妈", "is_current": false}
    ],
    "routes": {"address_book": [/* /server/addresses 的 addresses */],
               "network_memory": [/* 最近 8 个网络指纹 → 选中地址 */]},
    "session_cache": { /* /auth/me 的 SessionView 快照，供冷启动直出 */ }
  }
]
```

- 切换账号**不联网**：改 `is_current` + 换令牌，直接重放 session 缓存。
- 失效账号（401）标记「需重新输密码」，不自动删除。
- 「移除本机账号」= 调 `DELETE /auth/devices/current` 后删快照与令牌。
- 「退出全部账号」带确认框。

## 4. 冷启动快开

对齐 Android 已验证的行为（README「冷启动快开」条目）：

```
main()
  ├─ await SecureStorage 初始化
  ├─ 读 mc_servers → 有当前账号？
  │    ├─ 无 → 状态机 NEEDS_LOGIN → go_router redirect /onboarding
  │    └─ 有 → 状态机直接置 READY，用 session_cache 渲染主壳（首帧即内容）
  │              同时后台 GET /api/v1/auth/me revalidate
  │                   ├─ 200 → 更新 session_cache，无感
  │                   └─ 401 → 回落登录页，账号标「需重新输密码」
  └─ 顺手后台刷新 GET /server/addresses（几百字节，不做条件请求）
```

实现：`core/session/session_controller.dart` 的 `Notifier<SessionState>`，go_router 的 `redirect` 读它。READY 直出时首页数据仍走正常请求；`/auth/me` 期间 UI 不显示任何加载遮罩。

## 5. 局域网发现（Flutter 实现）

对齐 `lan-discovery.md`：**不用 mDNS**（Docker 桥接组播出不了容器），沿用 UDP 7359 单播。

### 5.1 协议

- 对本机所在网段（最多一个 /24）逐个地址单播，每个地址发两条询问：
  - `who is MovieClawServer?`（自家协议）
  - `who is JellyfinServer?`（兼容旧服务器）
- 应答（UTF-8 JSON，单播回询问来源端口）：

```json
{"type":"movieclaw.discovery","version":1,"instance_id":"9f2c…","name":"MovieClaw",
 "server_version":"0.41.0","addresses":["http://192.168.1.10:3300"],
 "endpoints":[{"url":"http://192.168.1.10:3300","kind":"lan"}]}
```

### 5.2 Flutter 实现方式

- `dart:io` 的 `RawDatagramSocket.bind(InternetAddress.anyIPv4, port: 0)`（客户端用任意源端口，不需占用 7359）。
- 取本机 IP：`NetworkInterface.list()` 取 Wi-Fi/以太网网卡的 IPv4，按 /24 展开地址列表（跳过 .0/.255）。
- 逐个 `socket.send(codeUnits, addr, 7359)`；为避免并发洪泛，每 50 个地址一批、批间 20ms。
- `socket.listen` 收应答，设 2 秒总超时窗口；收到即解析 JSON，按 `type == "movieclaw.discovery"` 区分自家与 Jellyfin 应答，`instance_id` 去重。
- 逐个单播而不是广播：iOS 广播要组播权限（MC 域），桥接部署广播也进不了容器；单播经 `-p 7359:7359/udp` 能转进去。iOS 需在 Info.plist 声明本地网络权限文案（NSLocalNetworkUsageDescription）。

### 5.3 应答 → 候选地址

对每台应答的服务器，按顺序拼候选并并发 `GET /api/v1/health`，取第一个 `status:"ok"` 的：

1. 应答 `addresses`（/ `endpoints` 里 kind=lan 的）；
2. 应答报文来源 IP + 上面出现过的每个端口；
3. 来源 IP + 3000（docker-compose 默认端口）。

发现结果展示在登录页（星空背景 + 「局域网内的服务器」列表），点击即填入地址并进入 §1 流程。

## 6. 引导页（onboarding）动线

1. 登录页：地址输入框（含自动发现列表）+ 用户名/密码 + 登录按钮。
2. 探测失败分支：显示中文错误（`friendlyMessage`）；未初始化服务器自动跳「创建管理员」页。
3. 登录成功：写凭证 → 拉地址簿 → 进五 Tab 主壳。
4. 配对码批准入口：登录页提供「扫二维码批准设备」入口（对齐 login-devices.md：iPhone 在「我的」页右上角有扫码钮），扫 `/activate?code=MCLW-XXXX` 二维码直达批准页；也可手动输入配对码。
5. 手机上批准设备用 `GET /auth/devices/requests/{code}` 查看请求（含 `requires_admin`）→ `POST …/approve|deny`；转码器只有超管能批。

## 7. 验收

1. 探测：错地址/反代子路径/http→https 跳转各一例，基址都落对。
2. 登录：正确/错误密码、未初始化服务器、限速 429。
3. 快开：杀进程重启，首帧直出主壳；令牌吊销后重启 401 回落登录页。
4. 发现：与服务器同网段真机可发现；不同网段 / 服务器关闭 7359 时回退手动输入。
5. 多账号：两台服务器 × 各两账号切换不联网；失效账号提示重新输密码。
