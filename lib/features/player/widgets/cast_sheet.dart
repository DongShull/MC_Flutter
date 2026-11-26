import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cast/cast_controller.dart';
import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_glass.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/mc_strings.dart';
import '../../../core/designsystem/state_views.dart';
import '../../../core/designsystem/theme.dart';

/// DLNA 投屏设备选择毛玻璃弹层。
class CastSheet extends ConsumerStatefulWidget {
  const CastSheet({super.key, required this.streamUrl, this.title});

  final String streamUrl;
  final String? title;

  static Future<void> show(
    BuildContext context, {
    required String streamUrl,
    String? title,
  }) {
    return showMcSheet<void>(
      context: context,
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(McIcons.cast, size: 19, color: McTokens.text),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(McStrings.castToDevice, style: McText.titleSm),
              ),
              if (cast.casting)
                McActionPill(
                  label: McStrings.stopCast,
                  primary: false,
                  tone: McGlassTone.danger,
                  height: 34,
                  onTap: () =>
                      ref.read(castControllerProvider.notifier).disconnect(),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (cast.searching)
            const SizedBox(height: 130, child: McLoadingView())
          else if (cast.devices.isEmpty)
            McEmptyView(
              icon: McIcons.cast,
              text: cast.lastError ?? McStrings.noCastDevice,
              actionLabel: '重新扫描',
              onRetry: () => ref.read(castControllerProvider.notifier).search(),
            )
          else
            McInsetGroup(
              margin: EdgeInsets.zero,
              children: [
                for (final d in cast.devices)
                  McInsetRow(
                    icon: McIcons.tv,
                    iconColor: cast.activeDevice == d && cast.casting
                        ? McTokens.ok
                        : McTokens.textMuted,
                    title: d.friendlyName,
                    subtitle: cast.activeDevice == d && cast.casting
                        ? McStrings.castingNow
                        : d.location,
                    trailing: cast.activeDevice == d && cast.casting
                        ? const Icon(
                            McIcons.checkCircleFill,
                            size: 18,
                            color: McTokens.ok,
                          )
                        : null,
                    onTap: () {
                      ref
                          .read(castControllerProvider.notifier)
                          .castTo(d, widget.streamUrl, title: widget.title);
                      Navigator.of(context).pop();
                    },
                  ),
              ],
            ),
          if (cast.lastError != null && cast.devices.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              cast.lastError!,
              style: McText.caption.copyWith(color: McTokens.danger),
            ),
          ],
        ],
      ),
    );
  }
}
