import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/designsystem/adaptive.dart';
import '../../../core/designsystem/state_views.dart';
import '../state/mc_api.dart';
import '../state/models.dart';

/// 订阅墙（对齐设计文档 04 §5.4 / SubscriptionWall）：
/// 传 [subscriptionId] = GET /subscriptions/{id}/items（单订阅资源墙）；
/// 否则 GET /subscriptions 全量按 kind 过滤（剧集/电影订阅墙）。
class SubscriptionWallPage extends ConsumerStatefulWidget {
  const SubscriptionWallPage({super.key, this.subscriptionId, this.kind});

  final int? subscriptionId;
  final String? kind;

  @override
  ConsumerState<SubscriptionWallPage> createState() => _SubscriptionWallPageState();
}

class _SubscriptionWallPageState extends ConsumerState<SubscriptionWallPage> {
  List<WallItem>? _items;
  List<SubscriptionView>? _subs;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final api = ref.read(subscriptionsApiProvider);
    try {
      if (widget.subscriptionId != null) {
        final items = await api.subscriptionItems(widget.subscriptionId!);
        if (!mounted) return;
        setState(() {
          _items = items;
          _loading = false;
        });
      } else {
        final subs = await api.subscriptions(kind: widget.kind);
        if (!mounted) return;
        setState(() {
          _subs = subs;
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.subscriptionId != null
        ? '订阅资源墙'
        : widget.kind == 'movie'
            ? '电影订阅'
            : widget.kind == 'tv'
                ? '剧集订阅'
                : '订阅墙';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: _loading
          ? const McLoadingView()
          : _error != null
              ? McErrorView(text: _error!)
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    final form = McFormWatch.of(context);
    SliverGridDelegate wallDelegate(McDeviceForm form, double aspect) {
      // 平板/TV 自适应列数；手机保持现有密度不变。
      if (form == McDeviceForm.phone) {
        return const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 150,
          mainAxisSpacing: 14,
          crossAxisSpacing: 12,
          childAspectRatio: 126 / 220,
        );
      }
      return SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: mcGridCrossAxisCount(
            form,
            BoxConstraints.tightFor(
                width: MediaQuery.widthOf(context) - 24),
        cellExtent: 150),
        mainAxisSpacing: 14,
        crossAxisSpacing: 12,
        childAspectRatio: aspect,
      );
    }
    // 单订阅资源墙
    final items = _items;
    if (items != null) {
      if (items.isEmpty) {
        return const Center(child: Text('暂无资源'));
      }
      return GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: wallDelegate(form, 126 / 220),
        itemCount: items.length,
        itemBuilder: (context, i) => McFocusRing(
          borderRadius: 10,
          child: _PosterTile(
            title: items[i].title,
            posterUrl: items[i].posterUrl,
            subtitle: items[i].kind,
          ),
        ),
      );
    }
    // 全量订阅墙：订阅卡片列表，点进详情
    final subs = _subs ?? const <SubscriptionView>[];
    if (subs.isEmpty) return const Center(child: Text('暂无订阅'));
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: wallDelegate(form, 126 / 220),
      itemCount: subs.length,
      itemBuilder: (context, i) {
        final s = subs[i];
        return McFocusRing(
          borderRadius: 10,
          child: _PosterTile(
            title: s.media.title,
            posterUrl: s.media.posterUrl,
            subtitle:
                '${subscriptionStatusLabel(s)} · ${subscriptionProgressNote(s)}',
            onTap: () => context.push('/subscriptions/detail/${s.id}'),
          ),
        );
      },
    );
  }
}

class _PosterTile extends StatelessWidget {
  const _PosterTile({
    required this.title,
    this.posterUrl,
    this.subtitle,
    this.onTap,
  });

  final String title;
  final String? posterUrl;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox.expand(
                child: posterUrl != null
                    ? CachedNetworkImage(
                        imageUrl: posterUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(color: Colors.white10),
                      )
                    : Container(color: Colors.white10),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 10, color: Colors.white.withValues(alpha: 0.55)),
            ),
        ],
      ),
    );
  }
}
