import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'mc_client.dart';
import 'session_providers.dart';

/// 一条待批准的设备接入请求（GET /auth/devices/requests/{user_code}）。
class DeviceRequestView {
  const DeviceRequestView({
    required this.userCode,
    this.clientType,
    this.clientName,
    this.sourceIp,
    this.expiresIn = 0,
    this.platform,
    this.clientVersion,
    this.requiresAdmin = false,
  });

  factory DeviceRequestView.fromJson(Map<String, dynamic> json) =>
      DeviceRequestView(
        userCode: (json['user_code'] ?? '').toString(),
        clientType: json['client_type']?.toString(),
        clientName: json['client_name']?.toString(),
        sourceIp: json['source_ip']?.toString(),
        expiresIn:
            int.tryParse(json['expires_in']?.toString() ?? '') ?? 0,
        platform: json['platform']?.toString(),
        clientVersion: json['client_version']?.toString(),
        requiresAdmin: json['requires_admin'] == true,
      );

  final String userCode;
  final String? clientType;
  final String? clientName;
  final String? sourceIp;
  final int expiresIn;
  final String? platform;
  final String? clientVersion;
  final bool requiresAdmin;
}

/// 设备接入批准（对齐鸿蒙 SettingsSectionPage.openApproval / 后端 auth.devices.*）。
class DeviceRequestsApi {
  DeviceRequestsApi(this._client);

  final McClient _client;

  static const _base = '/api/v1/auth/devices/requests';

  /// 按配对码查看请求详情（不存在/过期抛 ApiException）。
  Future<DeviceRequestView> request(String userCode) async {
    final body = await _client.unwrap<Map<String, dynamic>>(
      Channel.general,
      'GET',
      '$_base/${Uri.encodeComponent(userCode)}',
    );
    return DeviceRequestView.fromJson(body);
  }

  /// 批准（令牌归属批准者）。
  Future<void> approve(String userCode) => _client.unwrap<void>(
    Channel.general,
    'POST',
    '$_base/${Uri.encodeComponent(userCode)}/approve',
  );

  /// 拒绝（服务端不留痕）。
  Future<void> deny(String userCode) => _client.unwrap<void>(
    Channel.general,
    'POST',
    '$_base/${Uri.encodeComponent(userCode)}/deny',
  );
}

final deviceRequestsApiProvider = Provider<DeviceRequestsApi>(
  (ref) => DeviceRequestsApi(ref.watch(mcClientProvider)),
);
