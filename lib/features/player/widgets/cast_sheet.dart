import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cast/cast_controller.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/mc_strings.dart';

/// 投屏设备选择面板：SSDP 搜索 + 选中即推流。
class CastSheet extends ConsumerStatefulWidget {
  const CastSheet({
    super.key,
    required this.streamUrl,
    this.title,
  });

  final String streamUrl;
  final String? title;

  /// 弹出辅助入口。
  static Future<void> show(
    BuildContext context, {
    required String streamUrl,
    String? title,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF16181D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => CastSheet(streamUrl: streamUrl, title: title),
    );
  }

  @override
  ConsumerState<CastSheet> createState() => _CastSheetState();
}

class _CastSheetState extends ConsumerState<CastSheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(castControllerProvider.notifier).search();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cast = ref.watch(castControllerProvider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(McIcons.cast, size: 20),
                const SizedBox(width: 8),
                Text(McStrings.castToDevice,
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                if (cast.casting)
                  TextButton(
                    onPressed: () {
                      ref.read(castControllerProvider.notifier).disconnect();
                    },
                    child: const Text(McStrings.stopCast),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (cast.searching)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (cast.devices.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    cast.lastError ?? McStrings.noCastDevice,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              )
            else
              ...cast.devices.map((d) => ListTile(
                    leading: Icon(
                      McIcons.cast,
                      color: cast.activeDevice == d
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                    title: Text(d.friendlyName),
                    subtitle: Text(
                      cast.activeDevice == d && cast.casting
                          ? McStrings.castingNow
                          : d.location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () {
                      ref
                          .read(castControllerProvider.notifier)
                          .castTo(d, widget.streamUrl, title: widget.title);
                      Navigator.of(context).pop();
                    },
                  )),
            if (cast.lastError != null && cast.devices.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  cast.lastError!,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
