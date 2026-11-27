import 'models.dart';

/// 媒体库首页的「行清单」：合并规则、排序预设与命名推荐。
/// 1:1 对齐 upstream iOS `LibraryHomeRows.swift` & Web `home-rows.ts`。
abstract final class HomeRows {
  /// 库行 / 合集行 / 类型行可选的排序档（另含首页独有的 random）。
  static const allSorts = [
    'added_at',
    'release_date',
    'last_played',
    'rating',
    'random',
    'title',
  ];

  /// 「我的收藏」行的排序档。
  static const favoritesSorts = [
    'unwatched_first',
    'favorited_at',
    'rating',
    'title',
  ];

  /// 能做「按类型」跨库行的库类型。照片库不做。
  static const mediaKinds = ['movie', 'tv', 'video'];

  /// 有类型色块行的库类型：TMDB 的类型表只分电影与剧集。
  static const genreKinds = ['movie', 'tv'];

  /// TMDB 类型 ID → 中文名（对齐 iOS `GenreLabels`）。
  static const Map<int, String> genreNames = {
    28: '动作',
    12: '冒险',
    16: '动画',
    35: '喜剧',
    80: '犯罪',
    99: '纪录',
    18: '剧情',
    10751: '家庭',
    14: '奇幻',
    36: '历史',
    27: '恐怖',
    10402: '音乐',
    9648: '悬疑',
    10749: '爱情',
    878: '科幻',
    10770: '电视电影',
    53: '惊悚',
    10752: '战争',
    37: '西部',
    10759: '动作冒险',
    10762: '儿童',
    10763: '新闻',
    10764: '真人秀',
    10765: '科幻奇幻',
    10766: '肥皂剧',
    10767: '脱口秀',
    10768: '战争政治',
  };

  static String mediaKindLabel(String kind) => switch (kind) {
        'tv' => '剧集',
        'video' => '其他视频',
        'photo' => '照片',
        _ => '电影',
      };

  static String watchEmptyTitle(String watch) => switch (watch) {
        'unwatched' => '没有未看过的作品',
        'seen' => '还没有看过的作品',
        _ => '没有还没看完的作品',
      };

  /// 一档排序的方向档案（自然方向 + 两个方向的人话）。
  static ({bool naturalAsc, String asc, String desc})? direction(String sort) =>
      switch (sort) {
        'release_date' => (naturalAsc: false, asc: '旧→新', desc: '新→旧'),
        'last_played' => (naturalAsc: false, asc: '远→近', desc: '近→远'),
        'rating' => (naturalAsc: false, asc: '低→高', desc: '高→低'),
        'title' || 'probing' => (naturalAsc: true, asc: 'A→Z', desc: 'Z→A'),
        'runtime' => (naturalAsc: true, asc: '短→长', desc: '长→短'),
        'size' => (naturalAsc: false, asc: '小→大', desc: '大→小'),
        'added_at' => (naturalAsc: false, asc: '旧→新', desc: '新→旧'),
        'favorited_at' => (naturalAsc: false, asc: '旧→新', desc: '新→旧'),
        _ => null,
      };

  /// 反转了自然方向才带 order（与 Web orderParam 同一条规矩）。
  static String? orderParam(String sort, bool reversed) {
    final d = direction(sort);
    if (d == null || !reversed) return null;
    return d.naturalAsc ? 'desc' : 'asc';
  }

  /// 存下来的 order → 是否反转。
  static bool isReversed(String? sort, String? order) {
    final d = sort == null ? null : direction(sort);
    if (d == null || order == null) return false;
    return (order == 'asc') != d.naturalAsc;
  }

  /// 当前方向的人话。
  static String directionLabel(String? sort, bool reversed) {
    final d = sort == null ? null : direction(sort);
    if (d == null) return '';
    return d.naturalAsc != reversed ? d.asc : d.desc;
  }

  /// 排序档的短标签（自定义页每行的小字）。
  static String shortLabel(String sort, bool reversed) => switch (sort) {
        'release_date' => reversed ? '最早上映' : '最近上映',
        'last_played' => reversed ? '很久没看' : '最近观看',
        'rating' => reversed ? '评分最低' : '评分最高',
        'random' => '随便看看',
        'title' => reversed ? 'Z–A' : 'A–Z',
        'favorited_at' => reversed ? '最早收藏' : '最近收藏',
        'unwatched_first' => '未看优先',
        'runtime' => reversed ? '片长最长' : '片长最短',
        'size' => reversed ? '体积最小' : '体积最大',
        _ => reversed ? '最早添加' : '最近添加',
      };

  /// 排序依据的叫法（不带方向；自定义单行设置页用）。
  static String sortTitle(String sort) => switch (sort) {
        'unwatched_first' => '未看优先',
        'favorited_at' => '收藏时间',
        'release_date' => '上映日期',
        'last_played' => '最近观看',
        'rating' => '评分',
        'random' => '随便看看',
        'title' => '名称',
        'runtime' => '片长',
        'size' => '文件大小',
        _ => '添加时间',
      };

  static String? sortHint(String sort) => switch (sort) {
        'unwatched_first' => '没看过的排前面，同状态按收藏时间',
        'last_played' => '只展示曾经播过的作品',
        'random' => '每次刷新随机挑一批',
        _ => null,
      };

  /// 库行 / 合集行的默认名（带库名 / 短标签的推荐名）。
  static String presetName(String sort, String library, bool reversed) =>
      switch (sort) {
        'release_date' => reversed ? '最早上映的$library' : '最近上映的$library',
        'last_played' => reversed ? '很久没看的$library' : '最近观看的$library',
        'rating' => reversed ? '评分最低的$library' : '评分最高的$library',
        'random' => '随便看看 · $library',
        'title' => reversed ? '$library Z–A' : '$library A–Z',
        _ => reversed ? '最早添加的$library' : '最近添加的$library',
      };

  /// 类型行的推荐名：「全部电影 · 最近添加」。
  static String mediaKindRowName(
    String kind, {
    required String sort,
    required bool reversed,
  }) =>
      '全部${mediaKindLabel(kind)} · ${shortLabel(sort, reversed)}';

  /// 排序档按类型裁剪：评分、上映对家庭录像与照片没有意义。
  static List<String> sortsFor(String kind) => switch (kind) {
        'photo' => ['added_at', 'title', 'random'],
        'video' => ['added_at', 'last_played', 'title', 'random'],
        _ => allSorts,
      };

  /// 「我的收藏」行的排序档裁剪。
  static List<String> favoritesSortsFor() => favoritesSorts;

  /// 每种类型由哪些库组成：可见 ∩ 该类型 ∩ 没勾「从首页排除」。
  static List<({String kind, List<LibraryView> libraries})> mediaKindGroups(
    List<LibraryView> libraries,
  ) {
    final out = <({String kind, List<LibraryView> libraries})>[];
    for (final kind in mediaKinds) {
      final members = libraries
          .where((l) => l.viewerAccess && l.kind == kind && !l.excludeFromHome)
          .toList();
      if (members.isNotEmpty) {
        out.add((kind: kind, libraries: members));
      }
    }
    return out;
  }

  /// 「我的媒体库」里的虚拟库入口：合并首页合集行中可见的合集以及 `showOnHome == true` 的合集。
  static List<CollectionView> pinnedCollections(
    List<HomeRow> rows, {
    List<CollectionView> allCollections = const [],
  }) {
    final seen = <int>{};
    final out = <CollectionView>[];
    for (final row in rows) {
      final k = row.kind;
      if (!row.hidden && k is CollectionRowKind) {
        if (seen.add(k.collection.id)) {
          out.add(k.collection);
        }
      }
    }
    for (final c in allCollections) {
      if (c.showOnHome && !c.hidden && seen.add(c.id)) {
        out.add(c);
      }
    }
    return out;
  }

  /// 把存下来的（sort, order）归一到（档位, 是否反转）。
  static (String, bool) asRowSort(
    String? value,
    String? order,
    List<String> allowed,
  ) {
    if (value == 'release_date_asc' && allowed.contains('release_date')) {
      return ('release_date', true);
    }
    final sort =
        (value != null && allowed.contains(value)) ? value : allowed.first;
    return (sort, isReversed(sort, order));
  }

  /// 新加的行用随机 id：`row:` + 6 位 base36（与 Web / iOS 同形）。
  static String newRowId() {
    const chars = '0123456789abcdefghijklmnopqrstuvwxyz';
    final rnd = DateTime.now().microsecondsSinceEpoch;
    final buf = StringBuffer('row:');
    var seed = rnd;
    for (var i = 0; i < 6; i++) {
      buf.write(chars[seed % chars.length]);
      seed ~/= chars.length;
      seed ^= rnd << (i + 3);
      seed = seed & 0x7FFFFFFFFFFFFF;
    }
    return buf.toString();
  }

  static HomeRow newLibraryRow(LibraryView library) => HomeRow(
        id: newRowId(),
        kind: HomeRowKind.library(
          library: library,
          sort: 'added_at',
          reversed: false,
          unwatched: false,
        ),
      );

  static HomeRow newMediaKindRow(String kind, List<LibraryView> libraries) =>
      HomeRow(
        id: newRowId(),
        kind: HomeRowKind.mediaKind(
          kind: kind,
          libraries: libraries,
          sort: 'added_at',
          reversed: false,
          unwatched: false,
        ),
      );

  static HomeRow newCollectionRow(CollectionView collection) {
    final (sort, reversed) = asRowSort(collection.sort, null, allSorts);
    return HomeRow(
      id: newRowId(),
      kind: HomeRowKind.collection(
        collection: collection,
        sort: sort,
        reversed: reversed,
      ),
    );
  }

  /// 出厂布局：接下来继续 → 我的收藏 → 我的媒体库 → 类型色块行 → 每库一行「最近添加」。
  static List<HomeRow> defaultRows(List<LibraryView> libraries) {
    final visible = libraries.where((l) => l.viewerAccess).toList();
    final rows = <HomeRow>[
      const HomeRow(id: 'up-next', hidden: false, kind: HomeRowKind.upNext()),
      const HomeRow(
        id: 'favorites',
        hidden: false,
        kind: HomeRowKind.favorites(sort: 'unwatched_first', reversed: false),
      ),
      const HomeRow(
        id: 'libraries',
        hidden: false,
        kind: HomeRowKind.libraries(),
      ),
    ];
    for (final group in mediaKindGroups(visible)) {
      if (genreKinds.contains(group.kind)) {
        rows.add(
          HomeRow(
            id: 'genres:${group.kind}',
            kind: HomeRowKind.genres(
              group.kind,
              libraries: group.libraries,
            ),
          ),
        );
      }
    }
    for (final lib in visible.where((l) => !l.excludeFromHome)) {
      rows.add(
        HomeRow(
          id: 'lib:${lib.id}',
          kind: HomeRowKind.library(
            library: lib,
            sort: 'added_at',
            reversed: false,
            unwatched: false,
            builtin: true,
          ),
        ),
      );
    }
    return rows;
  }

  /// 把存下来的清单与当前可见的库、合集合并成首页要渲染的行。
  static List<HomeRow> build(
    List<HomeRowPref> prefs,
    List<LibraryView> libraries,
    List<CollectionView> collections,
  ) {
    final visible = libraries.where((l) => l.viewerAccess).toList();
    final defaults = defaultRows(visible);
    if (prefs.isEmpty) return defaults;
    final libById = {for (final l in visible) l.id: l};
    final colById = {for (final c in collections) c.id: c};
    final kindGroups = {
      for (final g in mediaKindGroups(visible)) g.kind: g.libraries,
    };
    final seen = <String>{};
    final rows = <HomeRow>[];
    for (final pref in prefs) {
      if (seen.contains(pref.id)) continue;
      final row = resolve(pref, libById, colById, kindGroups);
      if (row == null) continue;
      seen.add(pref.id);
      rows.add(row);
    }
    // 没存过的内置行追加在末尾（版本升级新增的入口不能消失）。
    for (final row in defaults) {
      final k = row.kind;
      if (k is LibraryRowKind || k is GenresRowKind) continue;
      if (seen.contains(row.id)) continue;
      seen.add(row.id);
      rows.add(row);
    }
    // 没存过的类型色块行插在「我的媒体库」之后，与出厂布局同一位置。
    final missingGenres = defaults
        .where((r) => r.kind is GenresRowKind && !seen.contains(r.id))
        .toList();
    if (missingGenres.isNotEmpty) {
      for (final r in missingGenres) {
        seen.add(r.id);
      }
      var at = rows.indexWhere((r) => r.kind is LibrariesRowKind);
      at = at < 0 ? rows.length : at + 1;
      rows.insertAll(at.clamp(0, rows.length), missingGenres);
    }
    // 没存过的库补一条默认行，插在最后一条库行之后。
    final missing = defaults
        .where((r) => r.kind is LibraryRowKind && !seen.contains(r.id))
        .toList();
    if (missing.isNotEmpty) {
      var at = rows.length;
      final last = rows.lastIndexWhere((r) => r.kind is LibraryRowKind);
      if (last >= 0) {
        at = last + 1;
      } else {
        final libs = rows.indexWhere((r) => r.kind is LibrariesRowKind);
        if (libs >= 0) {
          at = libs + 1;
          while (at < rows.length && rows[at].kind is GenresRowKind) {
            at++;
          }
        }
      }
      rows.insertAll(at.clamp(0, rows.length), missing);
    }
    return rows;
  }

  static HomeRow? resolve(
    HomeRowPref pref,
    Map<int, LibraryView> libById,
    Map<int, CollectionView> colById,
    Map<String, List<LibraryView>> kindGroups,
  ) {
    final hidden = pref.hidden == true;
    switch (pref.id) {
      case 'up-next':
        return HomeRow(
          id: pref.id,
          hidden: hidden,
          kind: const HomeRowKind.upNext(),
        );
      case 'libraries':
        return HomeRow(
          id: pref.id,
          hidden: hidden,
          kind: const HomeRowKind.libraries(),
        );
      case 'favorites':
        final sort = (pref.sort != null && favoritesSorts.contains(pref.sort))
            ? pref.sort!
            : 'unwatched_first';
        return HomeRow(
          id: pref.id,
          hidden: hidden,
          kind: HomeRowKind.favorites(
            sort: sort,
            reversed: isReversed(
              sort == 'unwatched_first' ? null : sort,
              pref.order,
            ),
          ),
        );
    }
    if (pref.id.startsWith('lib:')) {
      final id = int.tryParse(pref.id.substring(4));
      if (id == null) return null;
      final library = libById[id];
      if (library == null || library.excludeFromHome) return null;
      return libraryRow(pref, library, builtin: true);
    }
    if (pref.id.startsWith('genres:')) {
      final kind = pref.id.substring(7);
      if (!genreKinds.contains(kind)) return null;
      final members = kindGroups[kind];
      if (members == null || members.isEmpty) return null;
      return HomeRow(
        id: pref.id,
        hidden: hidden,
        kind: HomeRowKind.genres(kind, libraries: members),
      );
    }
    if (pref.id.startsWith('kind:')) {
      if (hidden) return null;
      final kind = pref.id.substring(5);
      final members = kindGroups[kind];
      if (members == null || members.isEmpty) return null;
      return mediaKindRow(pref, kind, members, builtin: false);
    }
    if (!pref.id.startsWith('row:')) return null;
    if (pref.mediaKind != null) {
      final members = kindGroups[pref.mediaKind!];
      if (members == null || members.isEmpty) return null;
      return mediaKindRow(pref, pref.mediaKind!, members, builtin: false);
    }
    final cid = pref.collectionId;
    if (cid != null) {
      final collection = colById[cid];
      if (collection == null) return null;
      final (sort, reversed) = pref.sort != null
          ? asRowSort(pref.sort, pref.order, allSorts)
          : asRowSort(collection.sort, null, allSorts);
      return HomeRow(
        id: pref.id,
        hidden: hidden,
        kind: HomeRowKind.collection(
          collection: collection,
          sort: sort,
          reversed: reversed,
          name: (pref.name ?? '').trim(),
        ),
      );
    }
    final lid = pref.libraryId;
    if (lid != null) {
      final library = libById[lid];
      if (library == null) return null;
      return libraryRow(pref, library, builtin: false);
    }
    return null;
  }

  static HomeRow libraryRow(
    HomeRowPref pref,
    LibraryView library, {
    required bool builtin,
  }) {
    final (sort, reversed) =
        asRowSort(pref.sort, pref.order, sortsFor(library.kind));
    final unfinished = pref.unfinished == true && sort != 'last_played';
    final unwatched =
        pref.unwatched == true && !unfinished && sort != 'last_played';
    return HomeRow(
      id: pref.id,
      hidden: pref.hidden == true,
      unfinished: unfinished,
      kind: HomeRowKind.library(
        library: library,
        sort: sort,
        reversed: reversed,
        unwatched: unwatched,
        name: (pref.name ?? '').trim(),
        builtin: builtin,
      ),
    );
  }

  static HomeRow mediaKindRow(
    HomeRowPref pref,
    String kind,
    List<LibraryView> libraries, {
    required bool builtin,
  }) {
    final (sort, reversed) = asRowSort(pref.sort, pref.order, sortsFor(kind));
    final unfinished = pref.unfinished == true && sort != 'last_played';
    final unwatched =
        pref.unwatched == true && !unfinished && sort != 'last_played';
    return HomeRow(
      id: pref.id,
      hidden: pref.hidden == true,
      unfinished: unfinished,
      kind: HomeRowKind.mediaKind(
        kind: kind,
        libraries: libraries,
        sort: sort,
        reversed: reversed,
        unwatched: unwatched,
        name: (pref.name ?? '').trim(),
        builtin: builtin,
      ),
    );
  }

  /// 反向：把合并后的行写回可存的形状。只存与默认不同的字段，空即默认。
  static List<HomeRowPref> toPrefs(List<HomeRow> rows) {
    final out = <HomeRowPref>[];
    for (final row in rows) {
      final k = row.kind;
      String? sort;
      String? order;
      String? name;
      bool? unwatched;
      bool? unfinished;
      int? libraryId;
      int? collectionId;
      String? mediaKind;
      if (k is FavoritesRowKind) {
        if (k.sort != 'unwatched_first') sort = k.sort;
        order = k.sort == 'unwatched_first'
            ? null
            : orderParam(k.sort, k.reversed);
      } else if (k is LibraryRowKind) {
        if (!k.builtin) libraryId = k.library.id;
        sort = k.sort;
        order = orderParam(k.sort, k.reversed);
        if (row.watch == 'unfinished') {
          unfinished = true;
        } else if (k.unwatched) {
          unwatched = true;
        }
        if (k.name.isNotEmpty) name = k.name;
      } else if (k is MediaKindRowKind) {
        if (row.id.startsWith('row:')) mediaKind = k.kind;
        sort = k.sort;
        order = orderParam(k.sort, k.reversed);
        if (row.watch == 'unfinished') {
          unfinished = true;
        } else if (k.unwatched) {
          unwatched = true;
        }
        if (k.name.isNotEmpty) name = k.name;
      } else if (k is CollectionRowKind) {
        collectionId = k.collection.id;
        sort = k.sort;
        order = orderParam(k.sort, k.reversed);
        if (k.name.isNotEmpty) name = k.name;
      }
      out.add(
        HomeRowPref(
          id: row.id,
          sort: sort,
          order: order,
          name: name,
          unwatched: unwatched,
          unfinished: unfinished,
          hidden: row.hidden ? true : null,
          libraryId: libraryId,
          collectionId: collectionId,
          mediaKind: mediaKind,
        ),
      );
    }
    return out;
  }
}

/* ---------------- 行模型 ---------------- */

/// 行来源的判别基类。
sealed class HomeRowKind {
  const HomeRowKind();

  const factory HomeRowKind.upNext() = UpNextRowKind;
  const factory HomeRowKind.libraries() = LibrariesRowKind;
  const factory HomeRowKind.favorites({
    required String sort,
    required bool reversed,
  }) = FavoritesRowKind;
  const factory HomeRowKind.genres(
    String kind, {
    List<LibraryView> libraries,
  }) = GenresRowKind;
  const factory HomeRowKind.library({
    required LibraryView library,
    required String sort,
    required bool reversed,
    required bool unwatched,
    String name,
    bool builtin,
  }) = LibraryRowKind;
  const factory HomeRowKind.mediaKind({
    required String kind,
    required List<LibraryView> libraries,
    required String sort,
    required bool reversed,
    required bool unwatched,
    String name,
    bool builtin,
  }) = MediaKindRowKind;
  const factory HomeRowKind.collection({
    required CollectionView collection,
    required String sort,
    required bool reversed,
    String name,
  }) = CollectionRowKind;
}

class UpNextRowKind extends HomeRowKind {
  const UpNextRowKind();
}

class LibrariesRowKind extends HomeRowKind {
  const LibrariesRowKind();
}

class FavoritesRowKind extends HomeRowKind {
  const FavoritesRowKind({required this.sort, required this.reversed});

  final String sort;
  final bool reversed;
}

class GenresRowKind extends HomeRowKind {
  const GenresRowKind(this.kind, {this.libraries = const []});

  final String kind;
  final List<LibraryView> libraries;
}

class LibraryRowKind extends HomeRowKind {
  const LibraryRowKind({
    required this.library,
    required this.sort,
    required this.reversed,
    required this.unwatched,
    this.name = '',
    this.builtin = false,
  });

  final LibraryView library;
  final String sort;
  final bool reversed;
  final bool unwatched;
  final String name;
  final bool builtin;
}

class MediaKindRowKind extends HomeRowKind {
  const MediaKindRowKind({
    required this.kind,
    this.libraries = const [],
    required this.sort,
    required this.reversed,
    required this.unwatched,
    this.name = '',
    this.builtin = false,
  });

  final String kind;
  final List<LibraryView> libraries;
  final String sort;
  final bool reversed;
  final bool unwatched;
  final String name;
  final bool builtin;
}

class CollectionRowKind extends HomeRowKind {
  const CollectionRowKind({
    required this.collection,
    required this.sort,
    required this.reversed,
    this.name = '',
  });

  final CollectionView collection;
  final String sort;
  final bool reversed;
  final String name;
}

/// 合并后的一行：来源已解析、排序与名字已落到具体值，首页与自定义页直接消费。
class HomeRow {
  const HomeRow({
    required this.id,
    this.hidden = false,
    this.unfinished = false,
    required this.kind,
  });

  final String id;
  final bool hidden;
  final bool unfinished;
  final HomeRowKind kind;

  /// 首页取数和展开列表共用同一观看条件。
  String? get watch {
    final k = kind;
    if (k is LibraryRowKind) {
      return k.sort == 'last_played'
          ? 'seen'
          : unfinished
              ? 'unfinished'
              : k.unwatched
                  ? 'unwatched'
                  : null;
    }
    if (k is MediaKindRowKind) {
      return k.sort == 'last_played'
          ? 'seen'
          : unfinished
              ? 'unfinished'
              : k.unwatched
                  ? 'unwatched'
                  : null;
    }
    return null;
  }

  String? get sort {
    final k = kind;
    if (k is FavoritesRowKind) return k.sort;
    if (k is LibraryRowKind) return k.sort;
    if (k is MediaKindRowKind) return k.sort;
    if (k is CollectionRowKind) return k.sort;
    return null;
  }

  bool get reversed {
    final k = kind;
    if (k is FavoritesRowKind) return k.reversed;
    if (k is LibraryRowKind) return k.reversed;
    if (k is MediaKindRowKind) return k.reversed;
    if (k is CollectionRowKind) return k.reversed;
    return false;
  }

  bool get configurable => sort != null;

  /// 这一行显示的名字：用户起的优先，空则跟随默认。
  String title() {
    final k = kind;
    if (k is UpNextRowKind) return '接下来继续';
    if (k is FavoritesRowKind) return '我的收藏';
    if (k is LibrariesRowKind) return '我的媒体库';
    if (k is GenresRowKind) return k.kind == 'tv' ? '按类型找剧集' : '按类型找电影';
    if (k is LibraryRowKind) {
      return k.name.isEmpty
          ? HomeRows.presetName(k.sort, k.library.name, k.reversed)
          : k.name;
    }
    if (k is MediaKindRowKind) {
      return k.name.isEmpty
          ? HomeRows.mediaKindRowName(k.kind, sort: k.sort, reversed: k.reversed)
          : k.name;
    }
    if (k is CollectionRowKind) {
      return k.name.isEmpty ? k.collection.name : k.name;
    }
    return id;
  }

  /// 自定义页里每行的小字：来源 · 排序 · 观看过滤。
  String meta() {
    final k = kind;
    if (k is UpNextRowKind) return '内置 · 我正在看的';
    if (k is FavoritesRowKind) {
      return '内置 · ${HomeRows.shortLabel(k.sort, k.reversed)}';
    }
    if (k is LibrariesRowKind) return '内置 · 管理页的库顺序';
    if (k is GenresRowKind) {
      return k.libraries.isNotEmpty
          ? '内置 · ${k.libraries.length} 个库合并'
          : '内置 · 每个类型一格';
    }
    if (k is LibraryRowKind) {
      return [
        '${k.library.name}库',
        HomeRows.shortLabel(k.sort, k.reversed),
        if (unfinished)
          '未看完'
        else if (k.unwatched)
          '只看没看过的',
      ].join(' · ');
    }
    if (k is MediaKindRowKind) {
      return [
        '全部${HomeRows.mediaKindLabel(k.kind)} (${k.libraries.length} 个库)',
        HomeRows.shortLabel(k.sort, k.reversed),
        if (unfinished)
          '未看完'
        else if (k.unwatched)
          '只看没看过的',
      ].join(' · ');
    }
    if (k is CollectionRowKind) {
      return '合集 · ${HomeRows.shortLabel(k.sort, k.reversed)}';
    }
    return '';
  }

  /// 库行 / 类型行 / 合集行的默认名（改名输入框的占位）。
  String defaultTitle() {
    final k = kind;
    if (k is LibraryRowKind) {
      return HomeRows.presetName(k.sort, k.library.name, k.reversed);
    }
    if (k is MediaKindRowKind) {
      return HomeRows.mediaKindRowName(
        k.kind,
        sort: k.sort,
        reversed: k.reversed,
      );
    }
    if (k is CollectionRowKind) return k.collection.name;
    return title();
  }

  String customName() {
    final k = kind;
    if (k is LibraryRowKind) return k.name;
    if (k is MediaKindRowKind) return k.name;
    if (k is CollectionRowKind) return k.name;
    return '';
  }

  /// 能否删除：自加的行（row:）与老版本存下的类型行（kind:）能删，内置行只能藏。
  bool removable() => id.startsWith('row:') || id.startsWith('kind:');

  HomeRow copyWith({
    bool? hidden,
    bool? unfinished,
    HomeRowKind? kind,
  }) =>
      HomeRow(
        id: id,
        hidden: hidden ?? this.hidden,
        unfinished: unfinished ?? this.unfinished,
        kind: kind ?? this.kind,
      );
}
