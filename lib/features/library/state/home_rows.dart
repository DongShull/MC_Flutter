import 'models.dart';

/// 媒体库首页的「行清单」：合并规则、排序预设与命名推荐。
/// 移植自 Kotlin core/model/HomeRows.kt（= iOS LibraryHomeRows.swift = Web home-rows.ts）。
///
/// 首页 = 每个成员一份有序行清单；每一行 = 来源 × 排序 × 名字，存在
/// `ui.preferences.home.rows`。约定：**存下来的是提示，不是契约**——
///  - 存过的行按存的顺序在前；
///  - 没存过的内置行、可见库默认行按出厂顺序补在后面；
///  - 指向已删库 / 不可见合集的行直接忽略；
///  - 空清单 = 出厂布局，「恢复默认」就是存一个空列表。
abstract final class HomeRows {
  /// 库行 / 合集行可选的排序档（另含首页独有的 random）。
  static const allSorts = ['added_at', 'release_date', 'last_played', 'rating', 'random', 'title'];

  /// 「我的收藏」行的排序档。
  static const favoritesSorts = ['unwatched_first', 'favorited_at', 'rating', 'title'];

  /// 有类型色块行的库类型：TMDB 的类型表只分电影与剧集。
  static const genreKinds = ['movie', 'tv'];

  /// 一档排序的方向档案（自然方向 + 两个方向的人话）。
  static ({bool naturalAsc, String asc, String desc})? direction(String sort) => switch (sort) {
        'release_date' => (naturalAsc: false, asc: '旧→新', desc: '新→旧'),
        'last_played' => (naturalAsc: false, asc: '远→近', desc: '近→远'),
        'rating' => (naturalAsc: false, asc: '低→高', desc: '高→低'),
        'title' => (naturalAsc: true, asc: 'A→Z', desc: 'Z→A'),
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
        _ => reversed ? '最早添加' : '最近添加',
      };

  /// 库行 / 合集行的默认名（带库名 / 短标签的推荐名）。
  static String presetName(String sort, String library, bool reversed) => switch (sort) {
        'release_date' => reversed ? '最早上映的$library' : '最近上映的$library',
        'last_played' => reversed ? '很久没看的$library' : '最近观看的$library',
        'rating' => reversed ? '评分最低的$library' : '评分最高的$library',
        'random' => '随便看看 · $library',
        'title' => reversed ? '$library Z–A' : '$library A–Z',
        _ => reversed ? '最早添加的$library' : '最近添加的$library',
      };

  /// 排序档按类型裁剪：评分、上映对家庭录像与照片没有意义。
  static List<String> sortsFor(String kind) => switch (kind) {
        'photo' => ['added_at', 'title', 'random'],
        'video' => ['added_at', 'last_played', 'title', 'random'],
        _ => allSorts,
      };

  /// 「我的收藏」行的排序档裁剪。
  static List<String> favoritesSortsFor() => favoritesSorts;

  /// 把存下来的（sort, order）归一到（档位, 是否反转）。
  static (String, bool) asRowSort(String? value, String? order, List<String> allowed) {
    if (value == 'release_date_asc' && allowed.contains('release_date')) {
      return ('release_date', true);
    }
    final sort = (value != null && allowed.contains(value)) ? value : allowed.first;
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

  /// 出厂布局：接下来继续 → 我的收藏 → 我的媒体库 → 类型色块行 → 每库一行「最近添加」。
  static List<HomeRow> defaultRows(List<LibraryView> libraries) {
    final rows = <HomeRow>[
      const HomeRow(id: 'up-next', hidden: false, kind: HomeRowKind.upNext()),
      const HomeRow(
        id: 'favorites',
        hidden: false,
        kind: HomeRowKind.favorites(sort: 'unwatched_first', reversed: false),
      ),
      const HomeRow(id: 'libraries', hidden: false, kind: HomeRowKind.libraries()),
    ];
    for (final kind in genreKinds) {
      final libs = libraries.where((l) => l.kind == kind).toList();
      if (libs.isNotEmpty) rows.add(HomeRow(id: 'genres:$kind', kind: HomeRowKind.genres(kind)));
    }
    for (final lib in libraries.where((l) => !l.excludeFromHome)) {
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
    final seen = <String>{};
    final rows = <HomeRow>[];
    for (final pref in prefs) {
      if (seen.contains(pref.id)) continue;
      final row = resolve(pref, libById, colById);
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
    final missingGenres =
        defaults.where((r) => r.kind is GenresRowKind && !seen.contains(r.id)).toList();
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
  ) {
    final hidden = pref.hidden == true;
    switch (pref.id) {
      case 'up-next':
        return HomeRow(id: pref.id, hidden: hidden, kind: const HomeRowKind.upNext());
      case 'libraries':
        return HomeRow(id: pref.id, hidden: hidden, kind: const HomeRowKind.libraries());
      case 'favorites':
        final sort = (pref.sort != null && favoritesSorts.contains(pref.sort))
            ? pref.sort!
            : 'unwatched_first';
        return HomeRow(
          id: pref.id,
          hidden: hidden,
          kind: HomeRowKind.favorites(
            sort: sort,
            reversed: isReversed(sort == 'unwatched_first' ? null : sort, pref.order),
          ),
        );
    }
    if (pref.id.startsWith('lib:')) {
      // 管理员勾了「从首页排除」的库：默认行不出现，存过也一样。
      final id = int.tryParse(pref.id.substring(4));
      if (id == null) return null;
      final library = libById[id];
      if (library == null || library.excludeFromHome) return null;
      return libraryRow(pref, library, builtin: true);
    }
    if (pref.id.startsWith('genres:')) {
      final kind = pref.id.substring(7);
      if (!genreKinds.contains(kind)) return null;
      final libs = libById.values.where((l) => l.kind == kind).toList();
      if (libs.isEmpty) return null;
      return HomeRow(id: pref.id, hidden: hidden, kind: HomeRowKind.genres(kind));
    }
    if (!pref.id.startsWith('row:')) return null;
    final cid = pref.collectionId;
    if (cid != null) {
      final collection = colById[cid];
      if (collection == null) return null;
      // 没存排序时沿用合集自己的序（含方向）。
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
    // media_kind 来源的自加行 Android 尚未展示：原样保留在 toPrefs。
    return null;
  }

  static HomeRow libraryRow(HomeRowPref pref, LibraryView library, {required bool builtin}) {
    final (sort, reversed) = asRowSort(pref.sort, pref.order, sortsFor(library.kind));
    // 「最近观看」只要播过的，与「只看没看过的」互斥：以排序为准，开关作废。
    return HomeRow(
      id: pref.id,
      hidden: pref.hidden == true,
      kind: HomeRowKind.library(
        library: library,
        sort: sort,
        reversed: reversed,
        unwatched: pref.unwatched == true && sort != 'last_played',
        name: (pref.name ?? '').trim(),
        builtin: builtin,
      ),
    );
  }

  /// 反向：把合并后的行写回可存的形状。只存与默认不同的字段，空即默认。
  /// media_kind 来源的行无法重建，原样保留。
  static List<HomeRowPref> toPrefs(List<HomeRow> rows, {List<HomeRowPref> passthrough = const []}) {
    final out = <HomeRowPref>[];
    for (final row in rows) {
      if (row is PassthroughHomeRow) {
        // 类型聚合行（kind:<kind> / media_kind）不展示但保存时按原位保留。
        final idx = row.prefIndex;
        if (idx >= 0 && idx < passthrough.length) {
          out.add(passthrough[idx]);
        }
        continue;
      }
      final k = row.kind;
      String? sort;
      String? order;
      String? name;
      bool? unwatched;
      int? libraryId;
      int? collectionId;
      if (k is FavoritesRowKind) {
        if (k.sort != 'unwatched_first') sort = k.sort;
        order = orderParam(k.sort == 'unwatched_first' ? 'favorited_at' : k.sort, k.reversed);
        if (k.sort == 'unwatched_first') order = null;
      } else if (k is LibraryRowKind) {
        if (!k.builtin) libraryId = k.library.id;
        sort = k.sort;
        order = orderParam(k.sort, k.reversed);
        if (k.unwatched) unwatched = true;
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
          hidden: row.hidden ? true : null,
          libraryId: libraryId,
          collectionId: collectionId,
        ),
      );
    }
    return out;
  }
}

/* ---------------- 行模型 ---------------- */

/// 行来源的判别基类（对齐 Kotlin HomeRows.Kind 的 sealed interface）。
sealed class HomeRowKind {
  const HomeRowKind();

  const factory HomeRowKind.upNext() = UpNextRowKind;
  const factory HomeRowKind.libraries() = LibrariesRowKind;
  const factory HomeRowKind.favorites({required String sort, required bool reversed}) =
      FavoritesRowKind;
  const factory HomeRowKind.genres(String kind) = GenresRowKind;
  const factory HomeRowKind.library({
    required LibraryView library,
    required String sort,
    required bool reversed,
    required bool unwatched,
    String name,
    bool builtin,
  }) = LibraryRowKind;
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
  const GenresRowKind(this.kind);

  final String kind;
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
    required this.kind,
  });

  final String id;
  final bool hidden;
  final HomeRowKind kind;

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
    if (k is CollectionRowKind) {
      return k.name.isEmpty ? k.collection.name : k.name;
    }
    return id;
  }

  /// 自定义页里每行的小字：来源 · 排序 · 只看没看过的。
  String meta() {
    final k = kind;
    if (k is UpNextRowKind) return '内置 · 我正在看的';
    if (k is FavoritesRowKind) {
      return '内置 · ${HomeRows.shortLabel(k.sort, k.reversed)}';
    }
    if (k is LibrariesRowKind) return '内置 · 管理页的库顺序';
    if (k is GenresRowKind) return '内置 · 每个类型一格';
    if (k is LibraryRowKind) {
      return [
        '${k.library.name}库',
        HomeRows.shortLabel(k.sort, k.reversed),
        if (k.unwatched) '只看没看过的',
      ].join(' · ');
    }
    if (k is CollectionRowKind) {
      return '合集 · ${HomeRows.shortLabel(k.sort, k.reversed)}';
    }
    return '';
  }

  /// 库行 / 合集行的默认名（改名输入框的占位）。
  String defaultTitle() {
    final k = kind;
    if (k is LibraryRowKind) return HomeRows.presetName(k.sort, k.library.name, k.reversed);
    if (k is CollectionRowKind) return k.collection.name;
    return title();
  }

  String customName() {
    final k = kind;
    if (k is LibraryRowKind) return k.name;
    if (k is CollectionRowKind) return k.name;
    return '';
  }

  /// 能否删除：自加的行（row:）与老版本存下的类型行（kind:）能删，内置行只能藏。
  bool removable() => id.startsWith('row:') || id.startsWith('kind:');
}

/// toPrefs 时原位保留的未展示行（media_kind / kind:<kind>）。
class PassthroughHomeRow extends HomeRow {
  const PassthroughHomeRow({required this.prefIndex})
      : super(id: 'kind:passthrough', kind: const HomeRowKind.upNext());

  final int prefIndex;
}
