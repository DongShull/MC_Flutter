// P2 widget 测试用的假 McApi：不发网络，直接返回预设模型，
// 并记录调用（供断言“走通了哪个端点”）。
//
// flutter_test 的 TestWidgetsFlutterBinding 会把 dart:io HttpClient
// 换成返回 400 的 mock，widget 测试里走真实 Dio 必然失败，
// 故页面级测试一律用本 fake；真实信封解包由 P1 的
// test/mc_api_envelope_test.dart（纯 test，无 widget 绑定）覆盖。
import 'package:mc_flutter/core/api/mc_api.dart';
import 'package:mc_flutter/core/api/mc_client.dart';
import 'package:mc_flutter/core/api/models.dart';
import 'package:mc_flutter/core/session/session_store.dart';

class FakeMcApi extends McApi {
  FakeMcApi() : super(McClient(session: SessionStore()));

  /// 调用的端点记录（如 'preview:7'、'submit:7'、'favorites'）。
  final requests = <String>[];

  SubtitleGenPreviewView subtitlePreview = const SubtitleGenPreviewView();
  JobView subtitleJob = const JobView(id: 'job-1', status: 'running');

  FavoritesPageView favoritesPage = const FavoritesPageView();
  PlaybackHistoryView historyPage = const PlaybackHistoryView();

  dynamic trashedData = {'items': const []};
  dynamic duplicatesData = {'items': const []};
  List<LibraryView> librariesData = const [];

  CollectionTitles collectionTitlesData = const CollectionTitles();

  TrickplayView trickplayData = const TrickplayView();

  @override
  Future<SubtitleGenPreviewView> subtitleGenerationPreview(
    int fileId, {
    String? targetLanguage,
    String? secondaryLanguage,
    String? sourceCandidateKey,
  }) async {
    requests.add('preview:$fileId');
    return subtitlePreview;
  }

  @override
  Future<JobView> startSubtitleGeneration(
    int fileId, {
    required SubtitleGenStartPayload body,
  }) async {
    requests.add('submit:$fileId');
    return subtitleJob;
  }

  @override
  Future<FavoritesPageView> favorites({
    int? limit,
    int? offset,
    bool? unwatchedFirst,
    String? sort,
    String? order,
  }) async {
    requests.add('favorites');
    return favoritesPage;
  }

  @override
  Future<PlaybackHistoryView> playbackHistory({
    int? limit,
    int? before,
  }) async {
    requests.add('history');
    return historyPage;
  }

  @override
  Future<HistoryClearView> clearPlaybackHistory({
    String? scope,
    int? mediaItemId,
    int? libraryId,
  }) async {
    requests.add('clear-history');
    historyPage = const PlaybackHistoryView();
    return const HistoryClearView();
  }

  @override
  Future<dynamic> trashedFiles() async {
    requests.add('trashed');
    return trashedData;
  }

  @override
  Future<dynamic> restoreTrashed({
    required Map<String, dynamic> body,
  }) async {
    requests.add('restore');
    final ids = (body['ids'] as List?)?.toList() ?? const [];
    final items = (trashedData is Map
            ? (trashedData['items'] as List? ?? const [])
            : const [])
        .where((row) {
          if (row is! Map) return true;
          final files = row['files'] as List? ?? const [];
          return !files.any(
            (f) => f is Map && ids.contains(f['id']),
          );
        })
        .toList();
    trashedData = {'items': items};
    return {};
  }

  @override
  Future<dynamic> duplicateFiles() async {
    requests.add('duplicates');
    return duplicatesData;
  }

  @override
  Future<dynamic> scanDuplicates() async {
    requests.add('scan-duplicates');
    return {};
  }

  @override
  Future<List<LibraryView>> libraries({String? kind, String? scope}) async {
    requests.add('libraries');
    return librariesData;
  }

  @override
  Future<dynamic> refreshLibraryMetadata(int libraryId) async {
    requests.add('refresh-metadata:$libraryId');
    return {};
  }

  @override
  Future<dynamic> stopLibraryMetadataRefresh(int libraryId) async {
    requests.add('stop-metadata:$libraryId');
    return {};
  }

  @override
  Future<CollectionTitles> collectionTitles({
    required String collectionRef,
    int? limit,
    int? page,
  }) async {
    requests.add('collection:$collectionRef');
    return collectionTitlesData;
  }

  @override
  Future<TrickplayView> playbackFileTrickplay(
    int fileId, {
    String? token,
  }) async {
    requests.add('trickplay:$fileId');
    return trickplayData;
  }

  @override
  Future<ItemJobView> regenerateItemChapters(
    int libraryId,
    int mediaItemId,
  ) async {
    requests.add('regen-chapters:$libraryId:$mediaItemId');
    return const ItemJobView(started: true, jobId: 'job-ch');
  }
}
