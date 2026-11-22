import 'package:freezed_annotation/freezed_annotation.dart';

part 'models.freezed.dart';
part 'models.g.dart';

/// 核心响应/请求模型：字段与类型由生成脚本从安卓端 Kotlin data class
///（以 apps/android-core/model/generated/Models.kt 服务端契约为准，
/// 其次 apps/android/.../core/model）机械转写；全部字段带安全缺省值，
/// 服务端缺字段时解析不抛错（与既有手写 fromJson 的容错口径一致）。
/// 未建模的嵌套类型退化为 Map<String, dynamic> / String，见 P1-core.md。

/// Kotlin `ActiveFileDownload`（Activity.kt）。
@freezed
abstract class ActiveFileDownload with _$ActiveFileDownload {
  const factory ActiveFileDownload({
    @Default('') String deviceId,
    @Default("") String memberName,
    @Default("") String client,
    @Default("") String deviceName,
    @Default(true) bool revocable,
    MediaActivityTarget? media,
    @Default("") String fileName,
    @Default(0) int sizeBytes,
    @Default(0) int bytesSent,
    double? rateBytesPerSecond,
    @Default(1) int connections,
    @Default(0) int positionBytes,
    int? progressPercent,
  }) = _ActiveFileDownload;

  factory ActiveFileDownload.fromJson(Map<String, dynamic> json) => _$ActiveFileDownloadFromJson(json);
}

/// Kotlin `ActivePlaybackSession`（Activity.kt）。
@freezed
abstract class ActivePlaybackSession with _$ActivePlaybackSession {
  const factory ActivePlaybackSession({
    @Default('') String deviceId,
    @Default("") String memberName,
    @Default("") String client,
    @Default("") String deviceName,
    @Default(MediaActivityTarget()) MediaActivityTarget media,
    int? positionMs,
    int? durationMs,
    int? progressPercent,
    @Default(false) bool paused,
    @Default("") String playMethod,
    double? rateBytesPerSecond,
    PlaybackDelivery? delivery,
    @Default(true) bool revocable,
  }) = _ActivePlaybackSession;

  factory ActivePlaybackSession.fromJson(Map<String, dynamic> json) => _$ActivePlaybackSessionFromJson(json);
}

/// Kotlin `ActorView`（Models.kt）。
@freezed
abstract class ActorView with _$ActorView {
  const factory ActorView({
    @Default("") String name,
    String? role,
    @JsonKey(name: 'thumb_url')
    String? thumbUrl,
    @JsonKey(name: 'tmdb_person_id')
    int? tmdbPersonId,
  }) = _ActorView;

  factory ActorView.fromJson(Map<String, dynamic> json) => _$ActorViewFromJson(json);
}

/// Kotlin `AgentAttachment`（Agent.kt）。
@freezed
abstract class AgentAttachment with _$AgentAttachment {
  const factory AgentAttachment({
    @Default('') String attachmentId,
    @Default("") String name,
    @Default(0) int width,
    @Default(0) int height,
    @Default(0) int bytes,
  }) = _AgentAttachment;

  factory AgentAttachment.fromJson(Map<String, dynamic> json) => _$AgentAttachmentFromJson(json);
}

/// Kotlin `AgentSessionStart`（Agent.kt）。
@freezed
abstract class AgentSessionStart with _$AgentSessionStart {
  const factory AgentSessionStart({
    @Default('') String content,
    String? sessionId,
    @Default([]) List<String> attachments,
    @Default("") String model,
    String? thinkingLevel,
  }) = _AgentSessionStart;

  factory AgentSessionStart.fromJson(Map<String, dynamic> json) => _$AgentSessionStartFromJson(json);
}

/// Kotlin `AppConfig`（Maintenance.kt）。
@freezed
abstract class AppConfig with _$AppConfig {
  const factory AppConfig({
    @JsonKey(name: 'external_url')
    @Default("") String externalUrl,
    @JsonKey(name: 'web_port')
    @Default(0) int webPort,
    @JsonKey(name: 'web_port_source')
    @Default("default") String webPortSource,
    @JsonKey(name: 'web_port_default')
    @Default(0) int webPortDefault,
    @JsonKey(name: 'web_port_rejected')
    int? webPortRejected,
    @JsonKey(name: 'web_port_configurable')
    @Default(false) bool webPortConfigurable,
  }) = _AppConfig;

  factory AppConfig.fromJson(Map<String, dynamic> json) => _$AppConfigFromJson(json);
}

/// Kotlin `AppConfigPayload`（Maintenance.kt）。
@freezed
abstract class AppConfigPayload with _$AppConfigPayload {
  const factory AppConfigPayload({
    @JsonKey(name: 'external_url')
    @Default('') String externalUrl,
  }) = _AppConfigPayload;

  factory AppConfigPayload.fromJson(Map<String, dynamic> json) => _$AppConfigPayloadFromJson(json);
}

/// Kotlin `ArtworkCandidateView`（ItemActions.kt）。
@freezed
abstract class ArtworkCandidateView with _$ArtworkCandidateView {
  const factory ArtworkCandidateView({
    @Default("") String filePath,
    @Default("") String previewUrl,
    int? width,
    int? height,
    String? language,
    double? voteAverage,
    int? voteCount,
    @Default("tmdb") String source,
    int? likes,
    @Default(false) bool unlisted,
  }) = _ArtworkCandidateView;

  factory ArtworkCandidateView.fromJson(Map<String, dynamic> json) => _$ArtworkCandidateViewFromJson(json);
}

/// Kotlin `ArtworkCandidatesView`（ItemActions.kt）。
@freezed
abstract class ArtworkCandidatesView with _$ArtworkCandidatesView {
  const factory ArtworkCandidatesView({
    @Default([]) List<ArtworkCandidateView> posters,
    @Default([]) List<ArtworkCandidateView> backdrops,
    @Default([]) List<ArtworkCandidateView> logos,
    String? currentPoster,
    String? currentBackdrop,
    String? currentLogo,
    @Default(false) bool posterLocked,
    @Default(false) bool backdropLocked,
    @Default(false) bool logoLocked,
    @Default("none") String fanart,
  }) = _ArtworkCandidatesView;

  factory ArtworkCandidatesView.fromJson(Map<String, dynamic> json) => _$ArtworkCandidatesViewFromJson(json);
}

/// Kotlin `ArtworkLockView`（ItemActions.kt）。
@freezed
abstract class ArtworkLockView with _$ArtworkLockView {
  const factory ArtworkLockView({
    @Default(false) bool locked,
  }) = _ArtworkLockView;

  factory ArtworkLockView.fromJson(Map<String, dynamic> json) => _$ArtworkLockViewFromJson(json);
}

/// Kotlin `ArtworkSelectPayload`（ItemActions.kt）。
@freezed
abstract class ArtworkSelectPayload with _$ArtworkSelectPayload {
  const factory ArtworkSelectPayload({
    @Default('') String kind,
    String? filePath,
  }) = _ArtworkSelectPayload;

  factory ArtworkSelectPayload.fromJson(Map<String, dynamic> json) => _$ArtworkSelectPayloadFromJson(json);
}

/// Kotlin `AudioPlanView`（Models.kt）。
@freezed
abstract class AudioPlanView with _$AudioPlanView {
  const factory AudioPlanView({
    @Default("") String action,
    @JsonKey(name: 'track_ref')
    String? trackRef,
    String? codec,
    int? channels,
    @Default(false) bool downmix,
  }) = _AudioPlanView;

  factory AudioPlanView.fromJson(Map<String, dynamic> json) => _$AudioPlanViewFromJson(json);
}

/// Kotlin `AudioStreamView`（Models.kt）。
@freezed
abstract class AudioStreamView with _$AudioStreamView {
  const factory AudioStreamView({
    String? codec,
    String? profile,
    int? channels,
    @JsonKey(name: 'channel_layout')
    String? channelLayout,
    String? language,
    String? title,
    @JsonKey(name: 'default')
    @Default(false) bool defaultValue,
  }) = _AudioStreamView;

  factory AudioStreamView.fromJson(Map<String, dynamic> json) => _$AudioStreamViewFromJson(json);
}

/// Kotlin `AudioSupportIn`（Models.kt）。
@freezed
abstract class AudioSupportIn with _$AudioSupportIn {
  const factory AudioSupportIn({
    @Default('') String codec,
    @JsonKey(name: 'max_channels')
    int? maxChannels,
  }) = _AudioSupportIn;

  factory AudioSupportIn.fromJson(Map<String, dynamic> json) => _$AudioSupportInFromJson(json);
}

/// Kotlin `AudioTrackView`（Models.kt）。
@freezed
abstract class AudioTrackView with _$AudioTrackView {
  const factory AudioTrackView({
    @Default("") String ref,
    String? codec,
    int? channels,
    String? language,
    @JsonKey(name: 'is_default')
    @Default(false) bool isDefault,
  }) = _AudioTrackView;

  factory AudioTrackView.fromJson(Map<String, dynamic> json) => _$AudioTrackViewFromJson(json);
}

/// Kotlin `AuthTypeRequirement`（SiteAdmin.kt）。
@freezed
abstract class AuthTypeRequirement with _$AuthTypeRequirement {
  const factory AuthTypeRequirement({
    @Default("") String authType,
    @Default([]) List<String> requiredFields,
  }) = _AuthTypeRequirement;

  factory AuthTypeRequirement.fromJson(Map<String, dynamic> json) => _$AuthTypeRequirementFromJson(json);
}

/// Kotlin `BootstrapStatus`（Models.kt）。
@freezed
abstract class BootstrapStatus with _$BootstrapStatus {
  const factory BootstrapStatus({
    @Default(false) bool initialized,
    @JsonKey(name: 'native_device_kinds')
    List<String>? nativeDeviceKinds,
  }) = _BootstrapStatus;

  factory BootstrapStatus.fromJson(Map<String, dynamic> json) => _$BootstrapStatusFromJson(json);
}

/// Kotlin `CastMember`（Discovery.kt）。
@freezed
abstract class CastMember with _$CastMember {
  const factory CastMember({
    @Default("") String name,
    String? role,
    String? character,
    String? avatarUrl,
    int? tmdbPersonId,
  }) = _CastMember;

  factory CastMember.fromJson(Map<String, dynamic> json) => _$CastMemberFromJson(json);
}

/// Kotlin `ChangePasswordRequest`（Settings.kt）。
@freezed
abstract class ChangePasswordRequest with _$ChangePasswordRequest {
  const factory ChangePasswordRequest({
    @Default('') String oldPassword,
    @Default('') String newPassword,
    @Default(false) bool signOutPaired,
  }) = _ChangePasswordRequest;

  factory ChangePasswordRequest.fromJson(Map<String, dynamic> json) => _$ChangePasswordRequestFromJson(json);
}

/// Kotlin `ChannelPushConfigView`（Agent.kt）。
@freezed
abstract class ChannelPushConfigView with _$ChannelPushConfigView {
  const factory ChannelPushConfigView({
    @JsonKey(name: 'push_dispatch')
    @Default(false) bool pushDispatch,
    @JsonKey(name: 'push_imported')
    @Default(false) bool pushImported,
  }) = _ChannelPushConfigView;

  factory ChannelPushConfigView.fromJson(Map<String, dynamic> json) => _$ChannelPushConfigViewFromJson(json);
}

/// Kotlin `ChapterJobView`（Models.kt）。
@freezed
abstract class ChapterJobView with _$ChapterJobView {
  const factory ChapterJobView({
    @JsonKey(name: 'job_id')
    @Default("") String jobId,
    @Default("") String status,
    @Default(0) int processed,
    @Default(0) int total,
    @Default(0) int failed,
    double? percent,
    @Default(false) bool stopping,
  }) = _ChapterJobView;

  factory ChapterJobView.fromJson(Map<String, dynamic> json) => _$ChapterJobViewFromJson(json);
}

/// Kotlin `ChapterView`（Models.kt）。
@freezed
abstract class ChapterView with _$ChapterView {
  const factory ChapterView({
    @Default(0) int index,
    @JsonKey(name: 'start_ms')
    @Default(0) int startMs,
    @JsonKey(name: 'end_ms')
    int? endMs,
    @JsonKey(name: 'frame_ms')
    int? frameMs,
    String? title,
    @Default(false) bool synthetic,
    @JsonKey(name: 'image_url')
    String? imageUrl,
  }) = _ChapterView;

  factory ChapterView.fromJson(Map<String, dynamic> json) => _$ChapterViewFromJson(json);
}

/// Kotlin `ClaimBatchPayload`（ItemActions.kt）。
@freezed
abstract class ClaimBatchPayload with _$ClaimBatchPayload {
  const factory ClaimBatchPayload({
    @Default([]) List<int> fileIds,
    @Default('') String titleRef,
    int? seasonNumber,
  }) = _ClaimBatchPayload;

  factory ClaimBatchPayload.fromJson(Map<String, dynamic> json) => _$ClaimBatchPayloadFromJson(json);
}

/// Kotlin `ClaimPayload`（ImportWatch.kt）。
@freezed
abstract class ClaimPayload with _$ClaimPayload {
  const factory ClaimPayload({
    @Default(0) int tmdbId,
    String? entryFile,
  }) = _ClaimPayload;

  factory ClaimPayload.fromJson(Map<String, dynamic> json) => _$ClaimPayloadFromJson(json);
}

/// Kotlin `CleanResult`（Maintenance.kt）。
@freezed
abstract class CleanResult with _$CleanResult {
  const factory CleanResult({
    @Default("") String key,
    @Default("") String mode,
    @Default(0) int removed,
    @Default(0) int skippedBusy,
    @Default(0) int freedBytes,
  }) = _CleanResult;

  factory CleanResult.fromJson(Map<String, dynamic> json) => _$CleanResultFromJson(json);
}

/// Kotlin `ClientCapabilityIn`（Models.kt）。
@freezed
abstract class ClientCapabilityIn with _$ClientCapabilityIn {
  const factory ClientCapabilityIn({
    List<VideoSupportIn>? video,
    List<AudioSupportIn>? audio,
    List<String>? containers,
    @JsonKey(name: 'hdr_passthrough')
    bool? hdrPassthrough,
    String? mse,
    @JsonKey(name: 'is_mobile')
    bool? isMobile,
    @JsonKey(name: 'native_hls')
    bool? nativeHls,
    bool? universal,
    @JsonKey(name: 'disc_image')
    bool? discImage,
    @JsonKey(name: 'disc_folder')
    bool? discFolder,
    @JsonKey(name: 'bluray_clips')
    bool? blurayClips,
    @JsonKey(name: 'local_tracks')
    bool? localTracks,
    @JsonKey(name: 'dolby_vision_profiles')
    List<int>? dolbyVisionProfiles,
    @JsonKey(name: 'dolby_vision_base_layer_profiles')
    List<int>? dolbyVisionBaseLayerProfiles,
    @JsonKey(name: 'dolby_vision_record_audit')
    bool? dolbyVisionRecordAudit,
    @JsonKey(name: 'mp4_sample_limit')
    int? mp4SampleLimit,
    @JsonKey(name: 'hevc_transcode')
    bool? hevcTranscode,
    @JsonKey(name: 'pgs_overlay')
    bool? pgsOverlay,
  }) = _ClientCapabilityIn;

  factory ClientCapabilityIn.fromJson(Map<String, dynamic> json) => _$ClientCapabilityInFromJson(json);
}

/// Kotlin `ClientReleaseView`（Models.kt）。
@freezed
abstract class ClientReleaseView with _$ClientReleaseView {
  const factory ClientReleaseView({
    @Default("") String product,
    @Default("") String version,
    @Default(0) int build,
    @Default(0) int size,
    @Default("") String sha256,
    @JsonKey(name: 'certificate_sha256')
    String? certificateSha256,
    @JsonKey(name: 'minimum_sdk')
    int? minimumSdk,
    @Default("") String changelog,
    @JsonKey(name: 'published_at')
    String? publishedAt,
    @JsonKey(name: 'release_url')
    @Default("") String releaseUrl,
  }) = _ClientReleaseView;

  factory ClientReleaseView.fromJson(Map<String, dynamic> json) => _$ClientReleaseViewFromJson(json);
}

/// Kotlin `CloudFolderReportView`（Models.kt）。
@freezed
abstract class CloudFolderReportView with _$CloudFolderReportView {
  const factory CloudFolderReportView({
    @JsonKey(name: 'finished_at')
    @Default("") String finishedAt,
    @Default(0.0) double seconds,
    @Default(0) int calls,
    @Default(0) int videos,
    @Default(0) int identified,
    @Default(0) int pending,
    @Default({}) Map<String, int> skipped,
    @Default(false) bool cancelled,
  }) = _CloudFolderReportView;

  factory CloudFolderReportView.fromJson(Map<String, dynamic> json) => _$CloudFolderReportViewFromJson(json);
}

/// Kotlin `CloudFolderView`（Models.kt）。
@freezed
abstract class CloudFolderView with _$CloudFolderView {
  const factory CloudFolderView({
    @Default(0) int id,
    @JsonKey(name: 'account_id')
    @Default(0) int accountId,
    @JsonKey(name: 'account_name')
    @Default("") String accountName,
    @Default("") String backend,
    @JsonKey(name: 'backend_title')
    @Default("") String backendTitle,
    @JsonKey(name: 'remote_dir_id')
    @Default("") String remoteDirId,
    @JsonKey(name: 'display_path')
    @Default("") String displayPath,
    @JsonKey(name: 'is_primary')
    @Default(false) bool isPrimary,
    @JsonKey(name: 'file_count')
    @Default(0) int fileCount,
    @JsonKey(name: 'listed_at')
    String? listedAt,
    CloudFolderReportView? report,
  }) = _CloudFolderView;

  factory CloudFolderView.fromJson(Map<String, dynamic> json) => _$CloudFolderViewFromJson(json);
}

/// Kotlin `CloudSettingsRequest`（Agent.kt）。
@freezed
abstract class CloudSettingsRequest with _$CloudSettingsRequest {
  const factory CloudSettingsRequest({
    @JsonKey(name: 'report_stats')
    @Default(false) bool reportStats,
  }) = _CloudSettingsRequest;

  factory CloudSettingsRequest.fromJson(Map<String, dynamic> json) => _$CloudSettingsRequestFromJson(json);
}

/// Kotlin `CloudStatusView`（Agent.kt）。
@freezed
abstract class CloudStatusView with _$CloudStatusView {
  const factory CloudStatusView({
    @Default("disconnected") String state,
    String? health,
    @JsonKey(name: 'health_message')
    String? healthMessage,
    @JsonKey(name: 'cloud_url')
    @Default("") String cloudUrl,
    @JsonKey(name: 'server_name')
    @Default("") String serverName,
    @JsonKey(name: 'report_stats')
    @Default(false) bool reportStats,
    @JsonKey(name: 'last_report_at')
    String? lastReportAt,
  }) = _CloudStatusView;

  factory CloudStatusView.fromJson(Map<String, dynamic> json) => _$CloudStatusViewFromJson(json);
}

/// Kotlin `CloudUploadView`（Models.kt）。
@freezed
abstract class CloudUploadView with _$CloudUploadView {
  const factory CloudUploadView({
    @JsonKey(name: 'job_id')
    @Default("") String jobId,
    @Default("") String status,
    @Default(0) int processed,
    @Default(0) int total,
    @Default(0) int rapid,
    @Default(0) int failed,
    double? percent,
    @Default("") String message,
  }) = _CloudUploadView;

  factory CloudUploadView.fromJson(Map<String, dynamic> json) => _$CloudUploadViewFromJson(json);
}

/// Kotlin `CollectionCover`（Models.kt）。
@freezed
abstract class CollectionCover with _$CollectionCover {
  const factory CollectionCover({
    @Default("") String url,
    String? blur,
  }) = _CollectionCover;

  factory CollectionCover.fromJson(Map<String, dynamic> json) => _$CollectionCoverFromJson(json);
}

/// Kotlin `CollectionItemsPayload`（Collections.kt）。
@freezed
abstract class CollectionItemsPayload with _$CollectionItemsPayload {
  const factory CollectionItemsPayload({
    @Default([]) List<int> mediaItemIds,
  }) = _CollectionItemsPayload;

  factory CollectionItemsPayload.fromJson(Map<String, dynamic> json) => _$CollectionItemsPayloadFromJson(json);
}

/// Kotlin `CollectionPayload`（Collections.kt）。
@freezed
abstract class CollectionPayload with _$CollectionPayload {
  const factory CollectionPayload({
    String? name,
    int? libraryId,
    dynamic rules,
    String? sort,
    String? visibility,
    bool? hidden,
    List<int>? itemIds,
    bool? snapshot,
  }) = _CollectionPayload;

  factory CollectionPayload.fromJson(Map<String, dynamic> json) => _$CollectionPayloadFromJson(json);
}

/// Kotlin `CollectionSeriesView`（Models.kt）。
@freezed
abstract class CollectionSeriesView with _$CollectionSeriesView {
  const factory CollectionSeriesView({
    @JsonKey(name: 'series_name')
    String? seriesName,
    @JsonKey(name: 'owned_count')
    @Default(0) int ownedCount,
    @Default(0) int total,
    @JsonKey(name: 'image_url')
    String? imageUrl,
    @Default([]) List<SeriesPartView> parts,
    @Default(false) bool available,
  }) = _CollectionSeriesView;

  factory CollectionSeriesView.fromJson(Map<String, dynamic> json) => _$CollectionSeriesViewFromJson(json);
}

/// Kotlin `CollectionTitles`（Discovery.kt）。
@freezed
abstract class CollectionTitles with _$CollectionTitles {
  const factory CollectionTitles({
    @Default(DiscoveryCollectionInfo()) DiscoveryCollectionInfo collection,
    @Default([]) List<DiscoveredTitle> titles,
    @Default(1) int page,
    @Default(1) int totalPages,
    @Default(0) int totalResults,
    @Default(false) bool hasMore,
  }) = _CollectionTitles;

  factory CollectionTitles.fromJson(Map<String, dynamic> json) => _$CollectionTitlesFromJson(json);
}

/// Kotlin `CollectionView`（Models.kt）。
@freezed
abstract class CollectionView with _$CollectionView {
  const factory CollectionView({
    @Default(0) int id,
    @Default("") String name,
    @JsonKey(name: 'library_id')
    int? libraryId,
    @Default([]) List<dynamic> rules,
    @Default("") String sort,
    @Default("") String visibility,
    String? builtin,
    @Default(false) bool editable,
    @Default(false) bool manageable,
    @JsonKey(name: 'rule_driven')
    @Default(false) bool ruleDriven,
    @JsonKey(name: 'item_count')
    @Default(0) int itemCount,
    @JsonKey(name: 'cover_item_id')
    int? coverItemId,
    @Default([]) List<CollectionCover> covers,
    @Default("") String kind,
    @Default(false) bool hidden,
    @Default(0) int position,
  }) = _CollectionView;

  factory CollectionView.fromJson(Map<String, dynamic> json) => _$CollectionViewFromJson(json);
}

/// Kotlin `ConfiguredSite`（SiteAdmin.kt）。
@freezed
abstract class ConfiguredSite with _$ConfiguredSite {
  const factory ConfiguredSite({
    @Default("") String siteId,
    @Default("") String authType,
    @Default(true) bool enabled,
    @Default("") String status,
    @Default(false) bool usable,
    @JsonKey(name: 'protected')
    @Default(false) bool isProtected,
    @Default(false) bool boostEnabled,
    @Default(false) bool boostPaused,
    @Default(0) int boostBudgetBytes,
    int? boostHoldDays,
    int? boostDownloaderId,
    String? lastVerifiedAt,
    String? lastCheckedAt,
    String? lastError,
    SiteProfile? profile,
  }) = _ConfiguredSite;

  factory ConfiguredSite.fromJson(Map<String, dynamic> json) => _$ConfiguredSiteFromJson(json);
}

/// Kotlin `CreateAdminRequest`（Models.kt）。
@freezed
abstract class CreateAdminRequest with _$CreateAdminRequest {
  const factory CreateAdminRequest({
    @Default('') String username,
    @Default('') String password,
  }) = _CreateAdminRequest;

  factory CreateAdminRequest.fromJson(Map<String, dynamic> json) => _$CreateAdminRequestFromJson(json);
}

/// Kotlin `DeleteFollowUpView`（Library.kt）。
@freezed
abstract class DeleteFollowUpView with _$DeleteFollowUpView {
  const factory DeleteFollowUpView({
    @Default("") String option,
    @Default("") String label,
    @Default('') String jobId,
  }) = _DeleteFollowUpView;

  factory DeleteFollowUpView.fromJson(Map<String, dynamic> json) => _$DeleteFollowUpViewFromJson(json);
}

/// Kotlin `DeleteOptionView`（Library.kt）。
@freezed
abstract class DeleteOptionView with _$DeleteOptionView {
  const factory DeleteOptionView({
    @Default('') String key,
    @Default('') String label,
    @Default("") String help,
    @Default(true) bool available,
    String? reason,
    @Default([]) List<DeletePreviewLineView> lines,
  }) = _DeleteOptionView;

  factory DeleteOptionView.fromJson(Map<String, dynamic> json) => _$DeleteOptionViewFromJson(json);
}

/// Kotlin `DeletePreviewLineView`（Library.kt）。
@freezed
abstract class DeletePreviewLineView with _$DeletePreviewLineView {
  const factory DeletePreviewLineView({
    @Default('') String text,
    @Default("info") String tone,
  }) = _DeletePreviewLineView;

  factory DeletePreviewLineView.fromJson(Map<String, dynamic> json) => _$DeletePreviewLineViewFromJson(json);
}

/// Kotlin `DetachPayload`（ItemActions.kt）。
@freezed
abstract class DetachPayload with _$DetachPayload {
  const factory DetachPayload({
    @Default([]) List<int> fileIds,
  }) = _DetachPayload;

  factory DetachPayload.fromJson(Map<String, dynamic> json) => _$DetachPayloadFromJson(json);
}

/// Kotlin `DeviceAuthorizeRequest`（Models.kt）。
@freezed
abstract class DeviceAuthorizeRequest with _$DeviceAuthorizeRequest {
  const factory DeviceAuthorizeRequest({
    @JsonKey(name: 'client_type')
    @Default('') String clientType,
    @JsonKey(name: 'client_name')
    @Default('') String clientName,
    @JsonKey(name: 'installation_id')
    String? installationId,
    String? platform,
    @JsonKey(name: 'client_version')
    String? clientVersion,
  }) = _DeviceAuthorizeRequest;

  factory DeviceAuthorizeRequest.fromJson(Map<String, dynamic> json) => _$DeviceAuthorizeRequestFromJson(json);
}

/// Kotlin `DeviceAuthorizeView`（Models.kt）。
@freezed
abstract class DeviceAuthorizeView with _$DeviceAuthorizeView {
  const factory DeviceAuthorizeView({
    @JsonKey(name: 'user_code')
    @Default("") String userCode,
    @JsonKey(name: 'device_code')
    @Default("") String deviceCode,
    @JsonKey(name: 'verification_uri')
    @Default("") String verificationUri,
    @JsonKey(name: 'verification_uri_complete')
    @Default("") String verificationUriComplete,
    @Default(0) int interval,
    @JsonKey(name: 'expires_in')
    @Default(0) int expiresIn,
  }) = _DeviceAuthorizeView;

  factory DeviceAuthorizeView.fromJson(Map<String, dynamic> json) => _$DeviceAuthorizeViewFromJson(json);
}

/// Kotlin `DeviceBrief`（Models.kt）。
@freezed
abstract class DeviceBrief with _$DeviceBrief {
  const factory DeviceBrief({
    @Default("") String id,
    @Default("") String kind,
    @Default("") String name,
  }) = _DeviceBrief;

  factory DeviceBrief.fromJson(Map<String, dynamic> json) => _$DeviceBriefFromJson(json);
}

/// Kotlin `DeviceCleanupItem`（Settings.kt）。
@freezed
abstract class DeviceCleanupItem with _$DeviceCleanupItem {
  const factory DeviceCleanupItem({
    @Default("") String id,
    @Default("") String name,
    @Default("") String ownerNickname,
  }) = _DeviceCleanupItem;

  factory DeviceCleanupItem.fromJson(Map<String, dynamic> json) => _$DeviceCleanupItemFromJson(json);
}

/// Kotlin `DeviceCleanupRequest`（Settings.kt）。
@freezed
abstract class DeviceCleanupRequest with _$DeviceCleanupRequest {
  const factory DeviceCleanupRequest({
    @Default(0) int inactiveDays,
    @Default(false) bool all,
    @Default(false) bool dryRun,
  }) = _DeviceCleanupRequest;

  factory DeviceCleanupRequest.fromJson(Map<String, dynamic> json) => _$DeviceCleanupRequestFromJson(json);
}

/// Kotlin `DeviceCleanupView`（Settings.kt）。
@freezed
abstract class DeviceCleanupView with _$DeviceCleanupView {
  const factory DeviceCleanupView({
    @Default([]) List<DeviceCleanupItem> devices,
  }) = _DeviceCleanupView;

  factory DeviceCleanupView.fromJson(Map<String, dynamic> json) => _$DeviceCleanupViewFromJson(json);
}

/// Kotlin `DeviceClientInfo`（Models.kt）。
@freezed
abstract class DeviceClientInfo with _$DeviceClientInfo {
  const factory DeviceClientInfo({
    @Default('') String kind,
    @JsonKey(name: 'installation_id')
    @Default('') String installationId,
    String? name,
    String? platform,
    @JsonKey(name: 'client_version')
    String? clientVersion,
  }) = _DeviceClientInfo;

  factory DeviceClientInfo.fromJson(Map<String, dynamic> json) => _$DeviceClientInfoFromJson(json);
}

/// Kotlin `DeviceLoginRequest`（Models.kt）。
@freezed
abstract class DeviceLoginRequest with _$DeviceLoginRequest {
  const factory DeviceLoginRequest({
    @Default('') String username,
    @Default('') String password,
    @Default(DeviceClientInfo()) DeviceClientInfo client,
  }) = _DeviceLoginRequest;

  factory DeviceLoginRequest.fromJson(Map<String, dynamic> json) => _$DeviceLoginRequestFromJson(json);
}

/// Kotlin `DeviceLoginView`（Models.kt）。
@freezed
abstract class DeviceLoginView with _$DeviceLoginView {
  const factory DeviceLoginView({
    @Default("") String token,
    @Default(LoginDeviceView()) LoginDeviceView device,
    @Default(SessionView()) SessionView session,
  }) = _DeviceLoginView;

  factory DeviceLoginView.fromJson(Map<String, dynamic> json) => _$DeviceLoginViewFromJson(json);
}

/// Kotlin `DevicePushView`（Models.kt）。
@freezed
abstract class DevicePushView with _$DevicePushView {
  const factory DevicePushView({
    @Default("") String status,
    @JsonKey(name: 'status_text')
    @Default("") String statusText,
  }) = _DevicePushView;

  factory DevicePushView.fromJson(Map<String, dynamic> json) => _$DevicePushViewFromJson(json);
}

/// Kotlin `DeviceRenameRequest`（Settings.kt）。
@freezed
abstract class DeviceRenameRequest with _$DeviceRenameRequest {
  const factory DeviceRenameRequest({
    @Default('') String name,
  }) = _DeviceRenameRequest;

  factory DeviceRenameRequest.fromJson(Map<String, dynamic> json) => _$DeviceRenameRequestFromJson(json);
}

/// Kotlin `DeviceRequestView`（DeviceRequest.kt）。
@freezed
abstract class DeviceRequestView with _$DeviceRequestView {
  const factory DeviceRequestView({
    @Default("") String userCode,
    @Default("") String clientType,
    @Default("") String clientName,
    @Default("") String sourceIp,
    @Default(0) int expiresIn,
    String? platform,
    String? clientVersion,
    @Default(false) bool requiresAdmin,
  }) = _DeviceRequestView;

  factory DeviceRequestView.fromJson(Map<String, dynamic> json) => _$DeviceRequestViewFromJson(json);
}

/// Kotlin `DeviceTokenRequest`（Models.kt）。
@freezed
abstract class DeviceTokenRequest with _$DeviceTokenRequest {
  const factory DeviceTokenRequest({
    @JsonKey(name: 'device_code')
    @Default('') String deviceCode,
  }) = _DeviceTokenRequest;

  factory DeviceTokenRequest.fromJson(Map<String, dynamic> json) => _$DeviceTokenRequestFromJson(json);
}

/// Kotlin `DeviceTokenView`（Models.kt）。
@freezed
abstract class DeviceTokenView with _$DeviceTokenView {
  const factory DeviceTokenView({
    @Default("") String token,
    @JsonKey(name: 'client_name')
    @Default("") String clientName,
    @JsonKey(name: 'client_type')
    @Default("") String clientType,
    @JsonKey(name: 'granted_by')
    @Default("") String grantedBy,
  }) = _DeviceTokenView;

  factory DeviceTokenView.fromJson(Map<String, dynamic> json) => _$DeviceTokenViewFromJson(json);
}

/// Kotlin `DirectorView`（Models.kt）。
@freezed
abstract class DirectorView with _$DirectorView {
  const factory DirectorView({
    @Default("") String name,
    @JsonKey(name: 'thumb_url')
    String? thumbUrl,
    @JsonKey(name: 'tmdb_person_id')
    @Default(0) int tmdbPersonId,
  }) = _DirectorView;

  factory DirectorView.fromJson(Map<String, dynamic> json) => _$DirectorViewFromJson(json);
}

/// Kotlin `DiscoveredTitle`（Search.kt）。
@freezed
abstract class DiscoveredTitle with _$DiscoveredTitle {
  const factory DiscoveredTitle({
    @Default("") String titleRef,
    @Default("") String provider,
    @Default("") String externalId,
    String? mediaType,
    @Default("") String title,
    @Default("") String originalTitle,
    int? releaseYear,
    @Default(0.0) double providerRating,
    @Default([]) List<String> genres,
    @Default("") String extentLabel,
    @Default("") String overview,
    String? posterUrl,
    String? backdropUrl,
    MediaLibraryStatus? libraryStatus,
  }) = _DiscoveredTitle;

  factory DiscoveredTitle.fromJson(Map<String, dynamic> json) => _$DiscoveredTitleFromJson(json);
}

/// Kotlin `DiscoveryCollectionInfo`（Discovery.kt）。
@freezed
abstract class DiscoveryCollectionInfo with _$DiscoveryCollectionInfo {
  const factory DiscoveryCollectionInfo({
    @Default("") String collectionRef,
    @Default("") String name,
    @Default("") String description,
    @Default(false) bool isRanked,
    @Default(20) int defaultLimit,
    @Default(false) bool supportsFullListing,
  }) = _DiscoveryCollectionInfo;

  factory DiscoveryCollectionInfo.fromJson(Map<String, dynamic> json) => _$DiscoveryCollectionInfoFromJson(json);
}

/// Kotlin `DiscoveryPage`（Discovery.kt）。
@freezed
abstract class DiscoveryPage with _$DiscoveryPage {
  const factory DiscoveryPage({
    @Default("tmdb") String provider,
    @Default("movie") String mediaType,
    @Default([]) List<DiscoverySection> sections,
  }) = _DiscoveryPage;

  factory DiscoveryPage.fromJson(Map<String, dynamic> json) => _$DiscoveryPageFromJson(json);
}

/// Kotlin `DiscoverySection`（Discovery.kt）。
@freezed
abstract class DiscoverySection with _$DiscoverySection {
  const factory DiscoverySection({
    @Default("") String collectionRef,
    @Default("") String title,
    @Default("poster-row") String presentation,
    @Default(12) int previewLimit,
    @Default(false) bool supportsFullListing,
  }) = _DiscoverySection;

  factory DiscoverySection.fromJson(Map<String, dynamic> json) => _$DiscoverySectionFromJson(json);
}

/// Kotlin `DispatchPreviewView`（Models.kt）。
@freezed
abstract class DispatchPreviewView with _$DispatchPreviewView {
  const factory DispatchPreviewView({
    @Default("") String mode,
    String? path,
    @JsonKey(name: 'entry_dir')
    String? entryDir,
    @JsonKey(name: 'staging_path')
    String? stagingPath,
    @JsonKey(name: 'library_id')
    int? libraryId,
    @JsonKey(name: 'library_name')
    String? libraryName,
    @JsonKey(name: 'downloader_name')
    String? downloaderName,
    @JsonKey(name: 'route_matched')
    bool? routeMatched,
    @JsonKey(name: 'route_reason_key')
    String? routeReasonKey,
    @JsonKey(name: 'route_reason_params')
    Map<String, dynamic>? routeReasonParams,
    @JsonKey(name: 'route_reason')
    String? routeReason,
    @JsonKey(name: 'rule_set_id')
    int? ruleSetId,
    @JsonKey(name: 'rule_set_name')
    String? ruleSetName,
    @JsonKey(name: 'rule_set_matched')
    bool? ruleSetMatched,
    @JsonKey(name: 'rule_set_reason_key')
    String? ruleSetReasonKey,
    @JsonKey(name: 'rule_set_reason_params')
    Map<String, dynamic>? ruleSetReasonParams,
    @JsonKey(name: 'rule_set_reason')
    String? ruleSetReason,
    @Default(false) bool ok,
    @JsonKey(name: 'warning_key')
    String? warningKey,
    @JsonKey(name: 'warning_params')
    Map<String, dynamic>? warningParams,
    String? warning,
  }) = _DispatchPreviewView;

  factory DispatchPreviewView.fromJson(Map<String, dynamic> json) => _$DispatchPreviewViewFromJson(json);
}

/// Kotlin `DoubanEpisodesView`（Models.kt）。
@freezed
abstract class DoubanEpisodesView with _$DoubanEpisodesView {
  const factory DoubanEpisodesView({
    @JsonKey(name: 'season_number')
    @Default(0) int seasonNumber,
    @JsonKey(name: 'douban_count')
    @Default(0) int doubanCount,
    @JsonKey(name: 'tmdb_count')
    @Default(0) int tmdbCount,
  }) = _DoubanEpisodesView;

  factory DoubanEpisodesView.fromJson(Map<String, dynamic> json) => _$DoubanEpisodesViewFromJson(json);
}

/// Kotlin `DownloadSubmitRequest`（Search.kt）。
@freezed
abstract class DownloadSubmitRequest with _$DownloadSubmitRequest {
  const factory DownloadSubmitRequest({
    @Default('') String siteId,
    @Default('') String downloadUrl,
    String? torrentId,
    int? libraryId,
    String? title,
    int? year,
    String? subtitle,
    @Default(false) bool autoRoute,
    String? mediaKind,
    int? tmdbId,
    String? savePath,
    int? downloaderId,
    String? category,
  }) = _DownloadSubmitRequest;

  factory DownloadSubmitRequest.fromJson(Map<String, dynamic> json) => _$DownloadSubmitRequestFromJson(json);
}

/// Kotlin `DownloadSubmitView`（DownloadTarget.kt）。
@freezed
abstract class DownloadSubmitView with _$DownloadSubmitView {
  const factory DownloadSubmitView({
    String? infoHash,
    @Default("") String name,
    @Default(false) bool alreadyExists,
    @Default(0) int downloaderId,
    @Default("") String downloaderName,
    String? savePath,
  }) = _DownloadSubmitView;

  factory DownloadSubmitView.fromJson(Map<String, dynamic> json) => _$DownloadSubmitViewFromJson(json);
}

/// Kotlin `DownloadTargetPrefView`（DownloadTarget.kt）。
@freezed
abstract class DownloadTargetPrefView with _$DownloadTargetPrefView {
  const factory DownloadTargetPrefView({
    @Default("other") String category,
    @Default("default") String kind,
    String? savePath,
    int? downloaderId,
    String? downloaderName,
    String? updatedAt,
  }) = _DownloadTargetPrefView;

  factory DownloadTargetPrefView.fromJson(Map<String, dynamic> json) => _$DownloadTargetPrefViewFromJson(json);
}

/// Kotlin `DownloadTask`（Activity.kt）。
@freezed
abstract class DownloadTask with _$DownloadTask {
  const factory DownloadTask({
    @Default('') String id,
    @Default("") String infoHash,
    String? name,
    int? downloaderId,
    String? downloaderName,
    double? progress,
    int? sizeBytes,
    int? dlspeedBytes,
    int? upspeedBytes,
    int? etaSeconds,
    @Default("") String state,
    @Default("") String source,
    String? siteName,
    String? resolution,
    String? mediaSource,
    String? mediaTitle,
    String? mediaKind,
    String? posterUrl,
    String? errorMessage,
    String? landingError,
    @Default(false) bool canReplace,
    int? mediaItemId,
    @Default([]) List<DownloadTaskSubscription> subscriptions,
  }) = _DownloadTask;

  factory DownloadTask.fromJson(Map<String, dynamic> json) => _$DownloadTaskFromJson(json);
}

/// Kotlin `DownloadTaskList`（Activity.kt）。
@freezed
abstract class DownloadTaskList with _$DownloadTaskList {
  const factory DownloadTaskList({
    @Default([]) List<DownloadTask> items,
  }) = _DownloadTaskList;

  factory DownloadTaskList.fromJson(Map<String, dynamic> json) => _$DownloadTaskListFromJson(json);
}

/// Kotlin `DownloadTaskSubscription`（Activity.kt）。
@freezed
abstract class DownloadTaskSubscription with _$DownloadTaskSubscription {
  const factory DownloadTaskSubscription({
    @Default(0) int id,
    @Default(0) int mediaItemId,
    @Default("") String mediaTitle,
    @Default("") String mediaKind,
    String? posterUrl,
    @Default("download") String purpose,
    @Default([]) List<DownloadTaskUnit> units,
  }) = _DownloadTaskSubscription;

  factory DownloadTaskSubscription.fromJson(Map<String, dynamic> json) => _$DownloadTaskSubscriptionFromJson(json);
}

/// Kotlin `DownloadTaskUnit`（Activity.kt）。
@freezed
abstract class DownloadTaskUnit with _$DownloadTaskUnit {
  const factory DownloadTaskUnit({
    @Default(0) int seasonNumber,
    @Default(0) int episodeNumber,
    @Default("grabbed") String status,
    @Default(false) bool replaced,
    @Default(false) bool contentMissing,
  }) = _DownloadTaskUnit;

  factory DownloadTaskUnit.fromJson(Map<String, dynamic> json) => _$DownloadTaskUnitFromJson(json);
}

/// Kotlin `DownloadUnitView`（Subscription.kt）。
@freezed
abstract class DownloadUnitView with _$DownloadUnitView {
  const factory DownloadUnitView({
    @Default(0) int seasonNumber,
    @Default(0) int episodeNumber,
    double? progress,
  }) = _DownloadUnitView;

  factory DownloadUnitView.fromJson(Map<String, dynamic> json) => _$DownloadUnitViewFromJson(json);
}

/// Kotlin `DownloaderDeleteResult`（DownloadTarget.kt）。
@freezed
abstract class DownloaderDeleteResult with _$DownloaderDeleteResult {
  const factory DownloaderDeleteResult({
    @Default([]) List<String> boostDisabledSites,
  }) = _DownloaderDeleteResult;

  factory DownloaderDeleteResult.fromJson(Map<String, dynamic> json) => _$DownloaderDeleteResultFromJson(json);
}

/// Kotlin `DownloaderLimits`（DownloadTarget.kt）。
@freezed
abstract class DownloaderLimits with _$DownloaderLimits {
  const factory DownloaderLimits({
    int? downloadLimitBytes,
    int? uploadLimitBytes,
    bool? altSpeedEnabled,
    bool? queueEnabled,
    int? maxActiveDownloads,
    int? maxActiveUploads,
    int? maxActiveTorrents,
  }) = _DownloaderLimits;

  factory DownloaderLimits.fromJson(Map<String, dynamic> json) => _$DownloaderLimitsFromJson(json);
}

/// Kotlin `DownloaderPayload`（DownloadTarget.kt）。
@freezed
abstract class DownloaderPayload with _$DownloaderPayload {
  const factory DownloaderPayload({
    @Default('') String name,
    @Default('') String clientType,
    @Default('') String url,
    String? username,
    String? password,
    String? savePath,
    List<PathMapping>? pathMappings,
    @Default(true) bool enabled,
  }) = _DownloaderPayload;

  factory DownloaderPayload.fromJson(Map<String, dynamic> json) => _$DownloaderPayloadFromJson(json);
}

/// Kotlin `DownloaderStatusPayload`（DownloadTarget.kt）。
@freezed
abstract class DownloaderStatusPayload with _$DownloaderStatusPayload {
  const factory DownloaderStatusPayload({
    @Default(false) bool enabled,
  }) = _DownloaderStatusPayload;

  factory DownloaderStatusPayload.fromJson(Map<String, dynamic> json) => _$DownloaderStatusPayloadFromJson(json);
}

/// Kotlin `DownloaderTypeInfo`（DownloadTarget.kt）。
@freezed
abstract class DownloaderTypeInfo with _$DownloaderTypeInfo {
  const factory DownloaderTypeInfo({
    @Default("") String type,
    @Default("") String title,
    @Default("") String connection,
    String? urlLabel,
    String? urlPlaceholder,
    @Default(false) bool needsUsername,
    String? help,
  }) = _DownloaderTypeInfo;

  factory DownloaderTypeInfo.fromJson(Map<String, dynamic> json) => _$DownloaderTypeInfoFromJson(json);
}

/// Kotlin `DownloaderView`（DownloadTarget.kt）。
@freezed
abstract class DownloaderView with _$DownloaderView {
  const factory DownloaderView({
    @Default(0) int id,
    @Default("") String name,
    @Default("") String clientType,
    @Default("") String url,
    String? username,
    String? savePath,
    List<PathMapping>? pathMappings,
    @Default(true) bool enabled,
    @Default(false) bool isDefault,
    @Default("") String status,
    @Default(false) bool usable,
    String? version,
    String? lastError,
    String? lastCheckedAt,
    @Default([]) List<PathHealthView> pathHealth,
    @Default(true) bool pathsHealthy,
    String? createdAt,
    String? updatedAt,
  }) = _DownloaderView;

  factory DownloaderView.fromJson(Map<String, dynamic> json) => _$DownloaderViewFromJson(json);
}

/// Kotlin `EgressService`（Maintenance.kt）。
@freezed
abstract class EgressService with _$EgressService {
  const factory EgressService({
    @Default("") String id,
    @Default("") String label,
    @Default("") String description,
  }) = _EgressService;

  factory EgressService.fromJson(Map<String, dynamic> json) => _$EgressServiceFromJson(json);
}

/// Kotlin `EpisodeArrivalView`（Models.kt）。
@freezed
abstract class EpisodeArrivalView with _$EpisodeArrivalView {
  const factory EpisodeArrivalView({
    @JsonKey(name: 'episode_number')
    @Default(0) int episodeNumber,
    @Default("") String stage,
    @JsonKey(name: 'expected_at')
    String? expectedAt,
  }) = _EpisodeArrivalView;

  factory EpisodeArrivalView.fromJson(Map<String, dynamic> json) => _$EpisodeArrivalViewFromJson(json);
}

/// Kotlin `EpisodeCapSpec`（Models.kt）。
@freezed
abstract class EpisodeCapSpec with _$EpisodeCapSpec {
  const factory EpisodeCapSpec({
    @Default(0) int start,
    int? end,
  }) = _EpisodeCapSpec;

  factory EpisodeCapSpec.fromJson(Map<String, dynamic> json) => _$EpisodeCapSpecFromJson(json);
}

/// Kotlin `EpisodeHintView`（Models.kt）。
@freezed
abstract class EpisodeHintView with _$EpisodeHintView {
  const factory EpisodeHintView({
    @JsonKey(name: 'season_number')
    @Default(0) int seasonNumber,
    @JsonKey(name: 'tmdb_count')
    @Default(0) int tmdbCount,
    int? floor,
    @Default(0) int suggested,
    @JsonKey(name: 'site_episode')
    int? siteEpisode,
    @JsonKey(name: 'site_title')
    String? siteTitle,
    @JsonKey(name: 'douban_count')
    int? doubanCount,
  }) = _EpisodeHintView;

  factory EpisodeHintView.fromJson(Map<String, dynamic> json) => _$EpisodeHintViewFromJson(json);
}

/// Kotlin `EpisodeSeasonView`（Models.kt）。
@freezed
abstract class EpisodeSeasonView with _$EpisodeSeasonView {
  const factory EpisodeSeasonView({
    @JsonKey(name: 'season_number')
    @Default(0) int seasonNumber,
    @JsonKey(name: 'tmdb_count')
    @Default(0) int tmdbCount,
    int? floor,
    EpisodeCapSpec? window,
  }) = _EpisodeSeasonView;

  factory EpisodeSeasonView.fromJson(Map<String, dynamic> json) => _$EpisodeSeasonViewFromJson(json);
}

/// Kotlin `EpisodeView`（Models.kt）。
@freezed
abstract class EpisodeView with _$EpisodeView {
  const factory EpisodeView({
    @JsonKey(name: 'episode_number')
    @Default(0) int episodeNumber,
    String? name,
    String? overview,
    @JsonKey(name: 'air_date')
    String? airDate,
    @JsonKey(name: 'still_url')
    String? stillUrl,
    @Default(false) bool owned,
    @JsonKey(name: 'file_ids')
    @Default([]) List<int> fileIds,
    @JsonKey(name: 'position_ms')
    @Default(0) int positionMs,
    @Default(false) bool played,
    @JsonKey(name: 'progress_percent')
    int? progressPercent,
    @JsonKey(name: 'site_season_note')
    String? siteSeasonNote,
  }) = _EpisodeView;

  factory EpisodeView.fromJson(Map<String, dynamic> json) => _$EpisodeViewFromJson(json);
}

/// Kotlin `EpisodeWindowView`（Models.kt）。
@freezed
abstract class EpisodeWindowView with _$EpisodeWindowView {
  const factory EpisodeWindowView({
    @JsonKey(name: 'season_number')
    @Default(0) int seasonNumber,
    @Default(0) int start,
    int? end,
    @Default(0) int total,
    bool? airing,
  }) = _EpisodeWindowView;

  factory EpisodeWindowView.fromJson(Map<String, dynamic> json) => _$EpisodeWindowViewFromJson(json);
}

/// Kotlin `FacetValue`（Library.kt）。
@freezed
abstract class FacetValue with _$FacetValue {
  const factory FacetValue({
    @Default("") String value,
    @Default("") String label,
    @Default(0) int count,
  }) = _FacetValue;

  factory FacetValue.fromJson(Map<String, dynamic> json) => _$FacetValueFromJson(json);
}

/// Kotlin `FavoriteItemView`（Models.kt）。
@freezed
abstract class FavoriteItemView with _$FavoriteItemView {
  const factory FavoriteItemView({
    @JsonKey(name: 'media_item_id')
    @Default(0) int mediaItemId,
    @Default("") String kind,
    @JsonKey(name: 'library_id')
    @Default(0) int libraryId,
    @Default("") String source,
    @JsonKey(name: 'tmdb_id')
    int? tmdbId,
    @Default("") String title,
    int? year,
    @JsonKey(name: 'poster_url')
    String? posterUrl,
    @JsonKey(name: 'backdrop_url')
    String? backdropUrl,
    @JsonKey(name: 'primary_aspect')
    @Default(0.0) double primaryAspect,
    @JsonKey(name: 'release_date')
    String? releaseDate,
    double? rating,
    @JsonKey(name: 'poster_blur')
    String? posterBlur,
    @JsonKey(name: 'primary_file_id')
    int? primaryFileId,
    @JsonKey(name: 'file_count')
    @Default(0) int fileCount,
    @JsonKey(name: 'total_size_bytes')
    @Default(0) int totalSizeBytes,
    @Default([]) List<int> seasons,
    @JsonKey(name: 'episode_count')
    @Default(0) int episodeCount,
    @Default([]) List<String> resolutions,
    @JsonKey(name: 'missing_count')
    @Default(0) int missingCount,
    @JsonKey(name: 'air_status')
    String? airStatus,
    @JsonKey(name: 'missing_episode_count')
    @Default(0) int missingEpisodeCount,
    @JsonKey(name: 'added_at')
    String? addedAt,
    @JsonKey(name: 'is_favorite')
    @Default(false) bool isFavorite,
    @JsonKey(name: 'recent_addition')
    LibraryRecentAdditionView? recentAddition,
    @JsonKey(name: 'inventory_summary')
    LibraryInventorySummaryView? inventorySummary,
    @JsonKey(name: 'probe_pending_count')
    @Default(0) int probePendingCount,
    @JsonKey(name: 'dynamic_range')
    String? dynamicRange,
    @JsonKey(name: 'has_atmos')
    bool? hasAtmos,
    @JsonKey(name: 'has_chinese_subtitle')
    bool? hasChineseSubtitle,
    @JsonKey(name: 'progress_percent')
    int? progressPercent,
    @JsonKey(name: 'unplayed_count')
    int? unplayedCount,
    @JsonKey(name: 'favorite_season_number')
    int? favoriteSeasonNumber,
    @JsonKey(name: 'favorite_episode_number')
    int? favoriteEpisodeNumber,
  }) = _FavoriteItemView;

  factory FavoriteItemView.fromJson(Map<String, dynamic> json) => _$FavoriteItemViewFromJson(json);
}

/// Kotlin `FavoritesPageView`（Favorites.kt）。
@freezed
abstract class FavoritesPageView with _$FavoritesPageView {
  const factory FavoritesPageView({
    @Default([]) List<FavoriteItemView> items,
    @Default(0) int total,
  }) = _FavoritesPageView;

  factory FavoritesPageView.fromJson(Map<String, dynamic> json) => _$FavoritesPageViewFromJson(json);
}

/// Kotlin `FavoritesView`（Models.kt）。
@freezed
abstract class FavoritesView with _$FavoritesView {
  const factory FavoritesView({
    @Default([]) List<FavoriteItemView> items,
    @Default(0) int total,
  }) = _FavoritesView;

  factory FavoritesView.fromJson(Map<String, dynamic> json) => _$FavoritesViewFromJson(json);
}

/// Kotlin `FileCloudView`（Models.kt）。
@freezed
abstract class FileCloudView with _$FileCloudView {
  const factory FileCloudView({
    @JsonKey(name: 'backend_title')
    @Default("") String backendTitle,
    @JsonKey(name: 'account_name')
    @Default("") String accountName,
    @JsonKey(name: 'remote_path')
    String? remotePath,
    @Default(false) bool local,
    @Default("") String origin,
    @Default("") String state,
    String? error,
  }) = _FileCloudView;

  factory FileCloudView.fromJson(Map<String, dynamic> json) => _$FileCloudViewFromJson(json);
}

/// Kotlin `FileOriginView`（Models.kt）。
@freezed
abstract class FileOriginView with _$FileOriginView {
  const factory FileOriginView({
    @Default("") String kind,
    @Default("") String label,
    String? detail,
  }) = _FileOriginView;

  factory FileOriginView.fromJson(Map<String, dynamic> json) => _$FileOriginViewFromJson(json);
}

/// Kotlin `FollowFutureRequest`（Subscription.kt）。
@freezed
abstract class FollowFutureRequest with _$FollowFutureRequest {
  const factory FollowFutureRequest({
    @Default(false) bool enabled,
  }) = _FollowFutureRequest;

  factory FollowFutureRequest.fromJson(Map<String, dynamic> json) => _$FollowFutureRequestFromJson(json);
}

/// Kotlin `FsBrowseView`（Models.kt）。
@freezed
abstract class FsBrowseView with _$FsBrowseView {
  const factory FsBrowseView({
    @Default('') String path,
    String? parent,
    @Default([]) List<FsEntry> entries,
  }) = _FsBrowseView;

  factory FsBrowseView.fromJson(Map<String, dynamic> json) => _$FsBrowseViewFromJson(json);
}

/// Kotlin `FsEntry`（Models.kt）。
@freezed
abstract class FsEntry with _$FsEntry {
  const factory FsEntry({
    @Default('') String name,
    @Default('') String path,
  }) = _FsEntry;

  factory FsEntry.fromJson(Map<String, dynamic> json) => _$FsEntryFromJson(json);
}

/// Kotlin `GenreOption`（RoutingOptions.kt）。
@freezed
abstract class GenreOption with _$GenreOption {
  const factory GenreOption({
    @Default(0) int id,
    @Default("") String label,
  }) = _GenreOption;

  factory GenreOption.fromJson(Map<String, dynamic> json) => _$GenreOptionFromJson(json);
}

/// Kotlin `GithubToken`（Maintenance.kt）。
@freezed
abstract class GithubToken with _$GithubToken {
  const factory GithubToken({
    @Default(false) bool configured,
    @Default("") String masked,
  }) = _GithubToken;

  factory GithubToken.fromJson(Map<String, dynamic> json) => _$GithubTokenFromJson(json);
}

/// Kotlin `GithubTokenPayload`（Maintenance.kt）。
@freezed
abstract class GithubTokenPayload with _$GithubTokenPayload {
  const factory GithubTokenPayload({
    @Default('') String token,
  }) = _GithubTokenPayload;

  factory GithubTokenPayload.fromJson(Map<String, dynamic> json) => _$GithubTokenPayloadFromJson(json);
}

/// Kotlin `GrabPayload`（DownloadTarget.kt）。
@freezed
abstract class GrabPayload with _$GrabPayload {
  const factory GrabPayload({
    @Default('') String siteId,
    @Default('') String torrentId,
    @Default('') String title,
    String? subtitle,
    String? category,
    String? downloadUrl,
    int? sizeBytes,
    int? seeders,
    bool? isFree,
    bool? hitAndRun,
    Map<String, dynamic>? attrs,
    String? imdbId,
    String? doubanId,
    String? publishTime,
  }) = _GrabPayload;

  factory GrabPayload.fromJson(Map<String, dynamic> json) => _$GrabPayloadFromJson(json);
}

/// Kotlin `GrabResultView`（DownloadTarget.kt）。
@freezed
abstract class GrabResultView with _$GrabResultView {
  const factory GrabResultView({
    @Default([]) List<DownloadUnitView> units,
  }) = _GrabResultView;

  factory GrabResultView.fromJson(Map<String, dynamic> json) => _$GrabResultViewFromJson(json);
}

/// Kotlin `HandoffPrompt`（Agent.kt）。
@freezed
abstract class HandoffPrompt with _$HandoffPrompt {
  const factory HandoffPrompt({
    @Default("") String title,
    @Default("") String prompt,
  }) = _HandoffPrompt;

  factory HandoffPrompt.fromJson(Map<String, dynamic> json) => _$HandoffPromptFromJson(json);
}

/// Kotlin `HandoffRequest`（Agent.kt）。
@freezed
abstract class HandoffRequest with _$HandoffRequest {
  const factory HandoffRequest({
    @Default('') String kind,
    @Default('') String ref,
  }) = _HandoffRequest;

  factory HandoffRequest.fromJson(Map<String, dynamic> json) => _$HandoffRequestFromJson(json);
}

/// Kotlin `HealthResponse`（Models.kt）。
@freezed
abstract class HealthResponse with _$HealthResponse {
  const factory HealthResponse({
    @Default("") String status,
    @Default("") String service,
    @Default("") String environment,
    @JsonKey(name: 'spec_hash')
    @Default("") String specHash,
    String? version,
    @JsonKey(name: 'instance_id')
    String? instanceId,
    String? proof,
  }) = _HealthResponse;

  factory HealthResponse.fromJson(Map<String, dynamic> json) => _$HealthResponseFromJson(json);
}

/// Kotlin `HealthView`（Models.kt）。
@freezed
abstract class HealthView with _$HealthView {
  const factory HealthView({
    String? status,
    String? service,
    String? environment,
    String? specHash,
    String? instanceId,
  }) = _HealthView;

  factory HealthView.fromJson(Map<String, dynamic> json) => _$HealthViewFromJson(json);
}

/// Kotlin `HistoryClearView`（ItemActions.kt）。
@freezed
abstract class HistoryClearView with _$HistoryClearView {
  const factory HistoryClearView({
    @Default(0) int deletedStates,
    @Default(0) int deletedMetrics,
  }) = _HistoryClearView;

  factory HistoryClearView.fromJson(Map<String, dynamic> json) => _$HistoryClearViewFromJson(json);
}

/// Kotlin `HomeRowPref`（Models.kt）。
@freezed
abstract class HomeRowPref with _$HomeRowPref {
  const factory HomeRowPref({
    @Default("") String id,
    String? sort,
    String? order,
    String? name,
    bool? unwatched,
    bool? unfinished,
    bool? hidden,
    @JsonKey(name: 'library_id')
    int? libraryId,
    @JsonKey(name: 'collection_id')
    int? collectionId,
    @JsonKey(name: 'media_kind')
    String? mediaKind,
  }) = _HomeRowPref;

  factory HomeRowPref.fromJson(Map<String, dynamic> json) => _$HomeRowPrefFromJson(json);
}

/// Kotlin `HomeUiPrefs`（Models.kt）。
@freezed
abstract class HomeUiPrefs with _$HomeUiPrefs {
  const factory HomeUiPrefs({
    @Default([]) List<HomeRowPref> rows,
  }) = _HomeUiPrefs;

  factory HomeUiPrefs.fromJson(Map<String, dynamic> json) => _$HomeUiPrefsFromJson(json);
}

/// Kotlin `ImportWatchPayload`（ImportWatch.kt）。
@freezed
abstract class ImportWatchPayload with _$ImportWatchPayload {
  const factory ImportWatchPayload({
    @Default('') String sourcePath,
    @Default('') String strategy,
    int? libraryId,
    String? targetPath,
    String? kind,
    @Default(true) bool processExisting,
  }) = _ImportWatchPayload;

  factory ImportWatchPayload.fromJson(Map<String, dynamic> json) => _$ImportWatchPayloadFromJson(json);
}

/// Kotlin `ImportWatchView`（ImportWatch.kt）。
@freezed
abstract class ImportWatchView with _$ImportWatchView {
  const factory ImportWatchView({
    @Default(0) int id,
    @Default("") String sourcePath,
    @Default("hardlink") String strategy,
    int? libraryId,
    String? libraryName,
    String? targetPath,
    String? kind,
    @Default("") String targetLabel,
    @Default(true) bool processExisting,
    @Default({}) Map<String, int> stats,
    @Default(0) int importedFiles,
    @Default(0) int importedWorks,
    String? createdAt,
  }) = _ImportWatchView;

  factory ImportWatchView.fromJson(Map<String, dynamic> json) => _$ImportWatchViewFromJson(json);
}

/// Kotlin `IngestEntriesView`（ImportWatch.kt）。
@freezed
abstract class IngestEntriesView with _$IngestEntriesView {
  const factory IngestEntriesView({
    @Default({}) Map<String, int> counts,
    @Default([]) List<IngestEntryView> entries,
  }) = _IngestEntriesView;

  factory IngestEntriesView.fromJson(Map<String, dynamic> json) => _$IngestEntriesViewFromJson(json);
}

/// Kotlin `IngestEntryView`（ImportWatch.kt）。
@freezed
abstract class IngestEntryView with _$IngestEntryView {
  const factory IngestEntryView({
    @Default(0) int id,
    @Default("") String name,
    @Default("") String entryPath,
    @Default("") String status,
    String? message,
    @Default(0) int importedCount,
    String? attemptedAt,
    @Default([]) List<String> unresolvedFiles,
  }) = _IngestEntryView;

  factory IngestEntryView.fromJson(Map<String, dynamic> json) => _$IngestEntryViewFromJson(json);
}

/// Kotlin `InvalidateTipRequest`（Tips.kt）。
@freezed
abstract class InvalidateTipRequest with _$InvalidateTipRequest {
  const factory InvalidateTipRequest({
    String? reason,
  }) = _InvalidateTipRequest;

  factory InvalidateTipRequest.fromJson(Map<String, dynamic> json) => _$InvalidateTipRequestFromJson(json);
}

/// Kotlin `ItemCollectionRef`（Models.kt）。
@freezed
abstract class ItemCollectionRef with _$ItemCollectionRef {
  const factory ItemCollectionRef({
    @Default(0) int id,
    @Default("") String name,
  }) = _ItemCollectionRef;

  factory ItemCollectionRef.fromJson(Map<String, dynamic> json) => _$ItemCollectionRefFromJson(json);
}

/// Kotlin `ItemDeletePreviewView`（Library.kt）。
@freezed
abstract class ItemDeletePreviewView with _$ItemDeletePreviewView {
  const factory ItemDeletePreviewView({
    @Default(false) bool wholeItem,
    @Default(0) int linkedBytes,
    @Default([]) List<DeleteOptionView> options,
  }) = _ItemDeletePreviewView;

  factory ItemDeletePreviewView.fromJson(Map<String, dynamic> json) => _$ItemDeletePreviewViewFromJson(json);
}

/// Kotlin `ItemDeleteResultView`（Library.kt）。
@freezed
abstract class ItemDeleteResultView with _$ItemDeleteResultView {
  const factory ItemDeleteResultView({
    @Default([]) List<String> removedPaths,
    @Default(0) int rowsDeleted,
    @Default(0) int freedBytes,
    @Default([]) List<String> errors,
    List<DeleteFollowUpView>? followUps,
  }) = _ItemDeleteResultView;

  factory ItemDeleteResultView.fromJson(Map<String, dynamic> json) => _$ItemDeleteResultViewFromJson(json);
}

/// Kotlin `ItemJobView`（ItemActions.kt）。
@freezed
abstract class ItemJobView with _$ItemJobView {
  const factory ItemJobView({
    @Default(false) bool started,
    String? jobId,
    @Default(false) bool created,
  }) = _ItemJobView;

  factory ItemJobView.fromJson(Map<String, dynamic> json) => _$ItemJobViewFromJson(json);
}

/// Kotlin `JobCancelView`（SubtitleGen.kt）。
@freezed
abstract class JobCancelView with _$JobCancelView {
  const factory JobCancelView({
    @Default(false) bool cancelled,
    JobView? job,
  }) = _JobCancelView;

  factory JobCancelView.fromJson(Map<String, dynamic> json) => _$JobCancelViewFromJson(json);
}

/// Kotlin `JobErrorAction`（Activity.kt）。
@freezed
abstract class JobErrorAction with _$JobErrorAction {
  const factory JobErrorAction({
    @Default("") String type,
    @Default("") String label,
  }) = _JobErrorAction;

  factory JobErrorAction.fromJson(Map<String, dynamic> json) => _$JobErrorActionFromJson(json);
}

/// Kotlin `JobErrorView`（Activity.kt）。
@freezed
abstract class JobErrorView with _$JobErrorView {
  const factory JobErrorView({
    @Default("") String code,
    @Default("") String message,
    @Default([]) List<JobErrorAction> actions,
  }) = _JobErrorView;

  factory JobErrorView.fromJson(Map<String, dynamic> json) => _$JobErrorViewFromJson(json);
}

/// Kotlin `JobListView`（Activity.kt）。
@freezed
abstract class JobListView with _$JobListView {
  const factory JobListView({
    @Default([]) List<JobView> items,
    @Default(false) bool running,
  }) = _JobListView;

  factory JobListView.fromJson(Map<String, dynamic> json) => _$JobListViewFromJson(json);
}

/// Kotlin `JobProgress`（Activity.kt）。
@freezed
abstract class JobProgress with _$JobProgress {
  const factory JobProgress({
    @Default("") String mode,
    @Default("") String phase,
    @Default("") String message,
    int? current,
    int? total,
    double? percent,
    int? phaseIndex,
    int? phaseCount,
    Map<String, dynamic>? details,
  }) = _JobProgress;

  factory JobProgress.fromJson(Map<String, dynamic> json) => _$JobProgressFromJson(json);
}

/// Kotlin `JobResourceView`（Activity.kt）。
@freezed
abstract class JobResourceView with _$JobResourceView {
  const factory JobResourceView({
    @Default("") String resourceType,
    @Default("") String resourceId,
    @Default("") String relation,
  }) = _JobResourceView;

  factory JobResourceView.fromJson(Map<String, dynamic> json) => _$JobResourceViewFromJson(json);
}

/// Kotlin `JobUsage`（Activity.kt）。
@freezed
abstract class JobUsage with _$JobUsage {
  const factory JobUsage({
    @Default(0) int requestCount,
    @Default(0) int totalTokens,
  }) = _JobUsage;

  factory JobUsage.fromJson(Map<String, dynamic> json) => _$JobUsageFromJson(json);
}

/// Kotlin `JobView`（Activity.kt）。
@freezed
abstract class JobView with _$JobView {
  const factory JobView({
    @Default('') String id,
    @Default("") String jobType,
    String? jobTypeLabel,
    String? subject,
    @Default("") String status,
    @Default(JobProgress()) JobProgress progress,
    JobErrorView? error,
    @Default([]) List<JobResourceView> resources,
    Map<String, dynamic>? inputData,
    Map<String, dynamic>? result,
    @Default(JobUsage()) JobUsage usage,
    String? startedAt,
    String? dismissedAt,
    String? cancelRequestedBy,
    String? finishedAt,
    @Default("") String origin,
    String? actorName,
    @Default(1) int attempt,
    @Default(1) int maxAttempts,
    String? createdAt,
    String? updatedAt,
  }) = _JobView;

  factory JobView.fromJson(Map<String, dynamic> json) => _$JobViewFromJson(json);
}

/// Kotlin `LastAbnormalExit`（Maintenance.kt）。
@freezed
abstract class LastAbnormalExit with _$LastAbnormalExit {
  const factory LastAbnormalExit({
    @Default("") String at,
    @Default(0) int exitCode,
    @Default("") String detail,
  }) = _LastAbnormalExit;

  factory LastAbnormalExit.fromJson(Map<String, dynamic> json) => _$LastAbnormalExitFromJson(json);
}

/// Kotlin `LastOrganizeView`（Models.kt）。
@freezed
abstract class LastOrganizeView with _$LastOrganizeView {
  const factory LastOrganizeView({
    @JsonKey(name: 'finished_at')
    @Default("") String finishedAt,
    @Default(0) int renamed,
    @JsonKey(name: 'sidecars_renamed')
    @Default(0) int sidecarsRenamed,
    @JsonKey(name: 'entry_assets_moved')
    @Default(0) int entryAssetsMoved,
    @JsonKey(name: 'already_ok')
    @Default(0) int alreadyOk,
    @Default(0) int skipped,
    @JsonKey(name: 'removed_dirs')
    @Default(0) int removedDirs,
    @Default([]) List<String> errors,
  }) = _LastOrganizeView;

  factory LastOrganizeView.fromJson(Map<String, dynamic> json) => _$LastOrganizeViewFromJson(json);
}

/// Kotlin `LastScanView`（Models.kt）。
@freezed
abstract class LastScanView with _$LastScanView {
  const factory LastScanView({
    @JsonKey(name: 'finished_at')
    @Default("") String finishedAt,
    @Default(0) int scanned,
    @Default(0) int identified,
    @Default(0) int unidentified,
    @JsonKey(name: 'marked_missing')
    @Default(0) int markedMissing,
    @JsonKey(name: 'cleared_missing')
    @Default(0) int clearedMissing,
    @JsonKey(name: 'removed_root_marked_missing')
    @Default(0) int removedRootMarkedMissing,
    @JsonKey(name: 'removed_root_cleared')
    @Default(0) int removedRootCleared,
    @JsonKey(name: 'removed_root_conflicts')
    @Default(0) int removedRootConflicts,
    @JsonKey(name: 'deferred')
    @Default(0) int deferredValue,
    @Default(0) int retried,
    @Default(false) bool cancelled,
    @Default([]) List<String> errors,
  }) = _LastScanView;

  factory LastScanView.fromJson(Map<String, dynamic> json) => _$LastScanViewFromJson(json);
}

/// Kotlin `LibraryCapabilitiesView`（Models.kt）。
@freezed
abstract class LibraryCapabilitiesView with _$LibraryCapabilitiesView {
  const factory LibraryCapabilitiesView({
    @Default(false) bool scraped,
    @Default(false) bool episodic,
    @Default(false) bool naming,
    @Default(false) bool subscribable,
    @JsonKey(name: 'write_nfo')
    @Default(false) bool writeNfo,
    @JsonKey(name: 'default_aspect')
    @Default(0.0) double defaultAspect,
    @JsonKey(name: 'jellyfin_collection')
    @Default("") String jellyfinCollection,
    @Default(false) bool playable,
  }) = _LibraryCapabilitiesView;

  factory LibraryCapabilitiesView.fromJson(Map<String, dynamic> json) => _$LibraryCapabilitiesViewFromJson(json);
}

/// Kotlin `LibraryFacets`（Library.kt）。
@freezed
abstract class LibraryFacets with _$LibraryFacets {
  const factory LibraryFacets({
    @Default(0) int total,
    @Default([]) List<FacetValue> genres,
    @Default([]) List<FacetValue> countries,
    @Default([]) List<FacetValue> decades,
    @Default([]) List<FacetValue> watch,
    @Default([]) List<FacetValue> ratings,
    @Default([]) List<FacetValue> runtimes,
    @Default([]) List<FacetValue> languages,
    @Default([]) List<FacetValue> resolutions,
    @Default([]) List<FacetValue> hdr,
    @Default([]) List<FacetValue> stock,
  }) = _LibraryFacets;

  factory LibraryFacets.fromJson(Map<String, dynamic> json) => _$LibraryFacetsFromJson(json);
}

/// Kotlin `LibraryFileView`（Models.kt）。
@freezed
abstract class LibraryFileView with _$LibraryFileView {
  const factory LibraryFileView({
    @Default(0) int id,
    @JsonKey(name: 'file_path')
    @Default("") String filePath,
    @JsonKey(name: 'file_name')
    @Default("") String fileName,
    @JsonKey(name: 'size_bytes')
    @Default(0) int sizeBytes,
    String? container,
    String? resolution,
    @JsonKey(name: 'video_codec')
    String? videoCodec,
    String? hdr,
    @JsonKey(name: 'bit_depth')
    int? bitDepth,
    @JsonKey(name: 'duration_seconds')
    int? durationSeconds,
    @JsonKey(name: 'bit_rate')
    int? bitRate,
    @JsonKey(name: 'frame_rate')
    double? frameRate,
    @JsonKey(name: 'color_space')
    String? colorSpace,
    @JsonKey(name: 'media_source')
    String? mediaSource,
    @JsonKey(name: 'media_source_manual')
    @Default(false) bool mediaSourceManual,
    @JsonKey(name: 'release_group')
    String? releaseGroup,
    @Default("") String source,
    @JsonKey(name: 'season_number')
    @Default(0) int seasonNumber,
    @JsonKey(name: 'episode_number')
    @Default(0) int episodeNumber,
    @Default(false) bool missing,
    @Default("") String state,
    @JsonKey(name: 'purge_after')
    String? purgeAfter,
    @JsonKey(name: 'trash_note')
    String? trashNote,
    @Default(FileOriginView()) FileOriginView origin,
    @JsonKey(name: 'kept_at')
    String? keptAt,
    @JsonKey(name: 'audio_streams')
    List<AudioStreamView>? audioStreams,
    @JsonKey(name: 'subtitle_streams')
    @Default([]) List<SubtitleStreamView> subtitleStreams,
    @JsonKey(name: 'playback_defaults')
    TrackDefaultsView? playbackDefaults,
    List<ChapterView>? chapters,
    FileCloudView? cloud,
    @JsonKey(name: 'added_at')
    @Default("") String addedAt,
  }) = _LibraryFileView;

  factory LibraryFileView.fromJson(Map<String, dynamic> json) => _$LibraryFileViewFromJson(json);
}

/// Kotlin `LibraryGalleryGroupView`（LibraryGallery.kt）。
@freezed
abstract class LibraryGalleryGroupView with _$LibraryGalleryGroupView {
  const factory LibraryGalleryGroupView({
    @Default(0) int mediaItemId,
    @Default(0) int libraryId,
    @Default("movie") String kind,
    @Default("") String title,
    int? year,
    @Default(false) bool isFavorite,
    @Default([]) List<LibraryGalleryImageView> images,
  }) = _LibraryGalleryGroupView;

  factory LibraryGalleryGroupView.fromJson(Map<String, dynamic> json) => _$LibraryGalleryGroupViewFromJson(json);
}

/// Kotlin `LibraryGalleryImageView`（LibraryGallery.kt）。
@freezed
abstract class LibraryGalleryImageView with _$LibraryGalleryImageView {
  const factory LibraryGalleryImageView({
    @Default("poster") String kind,
    @Default("") String url,
    @Default(0.0) double aspect,
    @Default("") String label,
    int? season,
    int? episode,
    double? tSeconds,
  }) = _LibraryGalleryImageView;

  factory LibraryGalleryImageView.fromJson(Map<String, dynamic> json) => _$LibraryGalleryImageViewFromJson(json);
}

/// Kotlin `LibraryIndexEntry`（Library.kt）。
@freezed
abstract class LibraryIndexEntry with _$LibraryIndexEntry {
  const factory LibraryIndexEntry({
    @Default("") String initial,
    @Default(0) int count,
    @Default(0) int offset,
  }) = _LibraryIndexEntry;

  factory LibraryIndexEntry.fromJson(Map<String, dynamic> json) => _$LibraryIndexEntryFromJson(json);
}

/// Kotlin `LibraryInventorySummaryView`（Models.kt）。
@freezed
abstract class LibraryInventorySummaryView with _$LibraryInventorySummaryView {
  const factory LibraryInventorySummaryView({
    @JsonKey(name: 'season_count')
    @Default(0) int seasonCount,
    @JsonKey(name: 'episode_count')
    @Default(0) int episodeCount,
    @JsonKey(name: 'season_number')
    int? seasonNumber,
    @JsonKey(name: 'total_episode_count')
    int? totalEpisodeCount,
    @JsonKey(name: 'all_seasons_owned')
    @Default(false) bool allSeasonsOwned,
    @JsonKey(name: 'all_episodes_owned')
    @Default(false) bool allEpisodesOwned,
  }) = _LibraryInventorySummaryView;

  factory LibraryInventorySummaryView.fromJson(Map<String, dynamic> json) => _$LibraryInventorySummaryViewFromJson(json);
}

/// Kotlin `LibraryItemDetailView`（Models.kt）。
@freezed
abstract class LibraryItemDetailView with _$LibraryItemDetailView {
  const factory LibraryItemDetailView({
    @JsonKey(name: 'media_item_id')
    @Default(0) int mediaItemId,
    @Default("") String kind,
    @Default("") String source,
    @JsonKey(name: 'tmdb_id')
    int? tmdbId,
    @JsonKey(name: 'imdb_id')
    String? imdbId,
    @JsonKey(name: 'douban_id')
    String? doubanId,
    @Default("") String title,
    @JsonKey(name: 'original_title')
    @Default("") String originalTitle,
    @JsonKey(name: 'english_title')
    String? englishTitle,
    @JsonKey(name: 'chinese_title')
    String? chineseTitle,
    int? year,
    @JsonKey(name: 'poster_url')
    String? posterUrl,
    @JsonKey(name: 'backdrop_url')
    String? backdropUrl,
    @JsonKey(name: 'logo_url')
    String? logoUrl,
    @JsonKey(name: 'primary_aspect')
    @Default(0.0) double primaryAspect,
    @JsonKey(name: 'local_meta')
    LocalMetaView? localMeta,
    @JsonKey(name: 'entry_dirs')
    @Default([]) List<String> entryDirs,
    @Default([]) List<LibraryFileView> files,
    @JsonKey(name: 'file_count')
    @Default(0) int fileCount,
    @JsonKey(name: 'total_size_bytes')
    @Default(0) int totalSizeBytes,
    @Default([]) List<int> seasons,
    @Default(false) bool scraping,
    @JsonKey(name: 'scraping_phase')
    String? scrapingPhase,
    @JsonKey(name: 'chapters_pending')
    @Default(false) bool chaptersPending,
    @JsonKey(name: 'series_name')
    String? seriesName,
    @JsonKey(name: 'series_collection_id')
    int? seriesCollectionId,
    @Default([]) List<ItemCollectionRef> collections,
    @JsonKey(name: 'air_status')
    String? airStatus,
  }) = _LibraryItemDetailView;

  factory LibraryItemDetailView.fromJson(Map<String, dynamic> json) => _$LibraryItemDetailViewFromJson(json);
}

/// Kotlin `LibraryItemShowcaseView`（Models.kt）。
@freezed
abstract class LibraryItemShowcaseView with _$LibraryItemShowcaseView {
  const factory LibraryItemShowcaseView({
    @JsonKey(name: 'media_item_id')
    @Default(0) int mediaItemId,
    @JsonKey(name: 'backdrop_url')
    String? backdropUrl,
    @JsonKey(name: 'logo_url')
    String? logoUrl,
    String? overview,
    @Default([]) List<String> genres,
    @JsonKey(name: 'runtime_minutes')
    int? runtimeMinutes,
    @JsonKey(name: 'content_rating')
    String? contentRating,
  }) = _LibraryItemShowcaseView;

  factory LibraryItemShowcaseView.fromJson(Map<String, dynamic> json) => _$LibraryItemShowcaseViewFromJson(json);
}

/// Kotlin `LibraryItemView`（Models.kt）。
@freezed
abstract class LibraryItemView with _$LibraryItemView {
  const factory LibraryItemView({
    @JsonKey(name: 'media_item_id')
    @Default(0) int mediaItemId,
    @Default("") String kind,
    @JsonKey(name: 'library_id')
    int? libraryId,
    @Default("") String source,
    @JsonKey(name: 'tmdb_id')
    int? tmdbId,
    @Default("") String title,
    int? year,
    @JsonKey(name: 'poster_url')
    String? posterUrl,
    @JsonKey(name: 'backdrop_url')
    String? backdropUrl,
    @JsonKey(name: 'primary_aspect')
    @Default(0.0) double primaryAspect,
    @JsonKey(name: 'release_date')
    String? releaseDate,
    double? rating,
    @JsonKey(name: 'poster_blur')
    String? posterBlur,
    @JsonKey(name: 'primary_file_id')
    int? primaryFileId,
    @JsonKey(name: 'file_count')
    @Default(0) int fileCount,
    @JsonKey(name: 'total_size_bytes')
    @Default(0) int totalSizeBytes,
    @Default([]) List<int> seasons,
    @JsonKey(name: 'episode_count')
    @Default(0) int episodeCount,
    @Default([]) List<String> resolutions,
    @JsonKey(name: 'missing_count')
    @Default(0) int missingCount,
    @JsonKey(name: 'air_status')
    String? airStatus,
    @JsonKey(name: 'missing_episode_count')
    @Default(0) int missingEpisodeCount,
    @JsonKey(name: 'added_at')
    String? addedAt,
    @JsonKey(name: 'is_favorite')
    @Default(false) bool isFavorite,
    @JsonKey(name: 'recent_addition')
    LibraryRecentAdditionView? recentAddition,
    @JsonKey(name: 'inventory_summary')
    LibraryInventorySummaryView? inventorySummary,
    @JsonKey(name: 'probe_pending_count')
    @Default(0) int probePendingCount,
    @JsonKey(name: 'dynamic_range')
    String? dynamicRange,
    @JsonKey(name: 'has_atmos')
    bool? hasAtmos,
    @JsonKey(name: 'has_chinese_subtitle')
    bool? hasChineseSubtitle,
    @JsonKey(name: 'progress_percent')
    int? progressPercent,
    @JsonKey(name: 'unplayed_count')
    int? unplayedCount,
  }) = _LibraryItemView;

  factory LibraryItemView.fromJson(Map<String, dynamic> json) => _$LibraryItemViewFromJson(json);
}

/// Kotlin `LibraryKindGenreView`（Models.kt）。
@freezed
abstract class LibraryKindGenreView with _$LibraryKindGenreView {
  const factory LibraryKindGenreView({
    @Default("") String value,
    @Default("") String label,
    @Default(0) int count,
    @JsonKey(name: 'cover_item_id')
    int? coverItemId,
    @JsonKey(name: 'cover_title')
    String? coverTitle,
    @JsonKey(name: 'cover_url')
    String? coverUrl,
  }) = _LibraryKindGenreView;

  factory LibraryKindGenreView.fromJson(Map<String, dynamic> json) => _$LibraryKindGenreViewFromJson(json);
}

/// Kotlin `LibraryKindSummaryView`（Library.kt）。
@freezed
abstract class LibraryKindSummaryView with _$LibraryKindSummaryView {
  const factory LibraryKindSummaryView({
    @Default("movie") String kind,
    @Default([]) List<int> libraryIds,
    @Default(0) int itemCount,
  }) = _LibraryKindSummaryView;

  factory LibraryKindSummaryView.fromJson(Map<String, dynamic> json) => _$LibraryKindSummaryViewFromJson(json);
}

/// Kotlin `LibraryPayload`（LibraryPayload.kt）。
@freezed
abstract class LibraryPayload with _$LibraryPayload {
  const factory LibraryPayload({
    @Default('') String name,
    @Default("movie") String kind,
    String? source,
    @Default([]) List<String> rootPaths,
    bool? generateThumbnails,
    bool? extractChapterImages,
    bool? detectMediaSegments,
    bool? excludeFromHome,
    bool? autoSeriesCollections,
    String? accessMode,
    List<int>? memberIds,
    bool? autoClearMissing,
    bool? realtimeWatch,
    @JsonKey(name: 'scrape_overrides')
    Map<String, dynamic>? scrapeOverrides,
  }) = _LibraryPayload;

  factory LibraryPayload.fromJson(Map<String, dynamic> json) => _$LibraryPayloadFromJson(json);
}

/// Kotlin `LibraryRecentAdditionView`（Models.kt）。
@freezed
abstract class LibraryRecentAdditionView with _$LibraryRecentAdditionView {
  const factory LibraryRecentAdditionView({
    @JsonKey(name: 'season_count')
    @Default(0) int seasonCount,
    @JsonKey(name: 'episode_count')
    @Default(0) int episodeCount,
    @JsonKey(name: 'season_number')
    int? seasonNumber,
    @JsonKey(name: 'first_episode_number')
    int? firstEpisodeNumber,
    @JsonKey(name: 'last_episode_number')
    int? lastEpisodeNumber,
    @JsonKey(name: 'complete_season')
    @Default(false) bool completeSeason,
  }) = _LibraryRecentAdditionView;

  factory LibraryRecentAdditionView.fromJson(Map<String, dynamic> json) => _$LibraryRecentAdditionViewFromJson(json);
}

/// Kotlin `LibraryRelaxView`（Models.kt）。
@freezed
abstract class LibraryRelaxView with _$LibraryRelaxView {
  const factory LibraryRelaxView({
    @Default(0) int total,
    @Default([]) List<RelaxSuggestionView> suggestions,
  }) = _LibraryRelaxView;

  factory LibraryRelaxView.fromJson(Map<String, dynamic> json) => _$LibraryRelaxViewFromJson(json);
}

/// Kotlin `LibrarySearchGroup`（Search.kt）。
@freezed
abstract class LibrarySearchGroup with _$LibrarySearchGroup {
  const factory LibrarySearchGroup({
    @Default(0) int libraryId,
    @Default("") String libraryName,
    @Default("movie") String kind,
    @Default([]) List<LibraryItemView> items,
  }) = _LibrarySearchGroup;

  factory LibrarySearchGroup.fromJson(Map<String, dynamic> json) => _$LibrarySearchGroupFromJson(json);
}

/// Kotlin `LibrarySearchHit`（Models.kt）。
@freezed
abstract class LibrarySearchHit with _$LibrarySearchHit {
  const factory LibrarySearchHit({
    @Default(LibraryItemView()) LibraryItemView item,
    @JsonKey(name: 'library_ids')
    @Default([]) List<int> libraryIds,
    @Default(LibrarySearchMatch()) LibrarySearchMatch match,
  }) = _LibrarySearchHit;

  factory LibrarySearchHit.fromJson(Map<String, dynamic> json) => _$LibrarySearchHitFromJson(json);
}

/// Kotlin `LibrarySearchMatch`（Models.kt）。
@freezed
abstract class LibrarySearchMatch with _$LibrarySearchMatch {
  const factory LibrarySearchMatch({
    @Default("") String type,
    @JsonKey(name: 'source_field')
    @Default("") String sourceField,
    @JsonKey(name: 'matched_name')
    @Default("") String matchedName,
    @Default("") String label,
    @JsonKey(name: 'label_key')
    String? labelKey,
    @JsonKey(name: 'label_params')
    Map<String, dynamic>? labelParams,
    @JsonKey(name: 'person_id')
    int? personId,
  }) = _LibrarySearchMatch;

  factory LibrarySearchMatch.fromJson(Map<String, dynamic> json) => _$LibrarySearchMatchFromJson(json);
}

/// Kotlin `LibrarySearchPerson`（Models.kt）。
@freezed
abstract class LibrarySearchPerson with _$LibrarySearchPerson {
  const factory LibrarySearchPerson({
    @Default(0) int id,
    @JsonKey(name: 'tmdb_person_id')
    int? tmdbPersonId,
    @Default("") String name,
    @JsonKey(name: 'profile_path')
    String? profilePath,
    @JsonKey(name: 'avatar_url')
    String? avatarUrl,
    @JsonKey(name: 'item_count')
    @Default(0) int itemCount,
    @Default(LibrarySearchMatch()) LibrarySearchMatch match,
  }) = _LibrarySearchPerson;

  factory LibrarySearchPerson.fromJson(Map<String, dynamic> json) => _$LibrarySearchPersonFromJson(json);
}

/// Kotlin `LibrarySearchSuggestion`（Models.kt）。
@freezed
abstract class LibrarySearchSuggestion with _$LibrarySearchSuggestion {
  const factory LibrarySearchSuggestion({
    @Default("") String type,
    @Default("") String text,
    String? label,
    @JsonKey(name: 'media_item_id')
    int? mediaItemId,
    @JsonKey(name: 'person_id')
    int? personId,
  }) = _LibrarySearchSuggestion;

  factory LibrarySearchSuggestion.fromJson(Map<String, dynamic> json) => _$LibrarySearchSuggestionFromJson(json);
}

/// Kotlin `LibrarySearchView`（Models.kt）。
@freezed
abstract class LibrarySearchView with _$LibrarySearchView {
  const factory LibrarySearchView({
    @Default("") String query,
    @JsonKey(name: 'person_id')
    int? personId,
    @Default([]) List<LibrarySearchHit> items,
    @Default([]) List<LibrarySearchPerson> people,
    @Default([]) List<LibrarySearchSuggestion> suggestions,
    @JsonKey(name: 'next_cursor')
    String? nextCursor,
    @JsonKey(name: 'index_pending')
    @Default(false) bool indexPending,
  }) = _LibrarySearchView;

  factory LibrarySearchView.fromJson(Map<String, dynamic> json) => _$LibrarySearchViewFromJson(json);
}

/// Kotlin `LibraryStats`（Models.kt）。
@freezed
abstract class LibraryStats with _$LibraryStats {
  const factory LibraryStats({
    @JsonKey(name: 'item_count')
    @Default(0) int itemCount,
    @JsonKey(name: 'file_count')
    @Default(0) int fileCount,
    @JsonKey(name: 'total_size_bytes')
    @Default(0) int totalSizeBytes,
    @JsonKey(name: 'unidentified_count')
    @Default(0) int unidentifiedCount,
    @JsonKey(name: 'missing_count')
    @Default(0) int missingCount,
    @JsonKey(name: 'ignored_count')
    @Default(0) int ignoredCount,
  }) = _LibraryStats;

  factory LibraryStats.fromJson(Map<String, dynamic> json) => _$LibraryStatsFromJson(json);
}

/// Kotlin `LibraryView`（Models.kt）。
@freezed
abstract class LibraryView with _$LibraryView {
  const factory LibraryView({
    @Default(0) int id,
    @Default("") String name,
    @Default("") String kind,
    @Default("") String source,
    @JsonKey(name: 'source_title')
    String? sourceTitle,
    @JsonKey(name: 'source_icon')
    String? sourceIcon,
    @JsonKey(name: 'source_configured')
    @Default(false) bool sourceConfigured,
    @JsonKey(name: 'last_source_sync_at')
    String? lastSourceSyncAt,
    @Default(LibraryCapabilitiesView()) LibraryCapabilitiesView capabilities,
    @JsonKey(name: 'generate_thumbnails')
    @Default(false) bool generateThumbnails,
    @JsonKey(name: 'extract_chapter_images')
    @Default(false) bool extractChapterImages,
    @JsonKey(name: 'detect_media_segments')
    @Default(false) bool detectMediaSegments,
    @JsonKey(name: 'exclude_from_home')
    @Default(false) bool excludeFromHome,
    @JsonKey(name: 'auto_series_collections')
    @Default(false) bool autoSeriesCollections,
    @JsonKey(name: 'access_mode')
    @Default("") String accessMode,
    @JsonKey(name: 'admin_visible')
    @Default(false) bool adminVisible,
    @JsonKey(name: 'member_ids')
    @Default([]) List<int> memberIds,
    @JsonKey(name: 'viewer_access')
    @Default(false) bool viewerAccess,
    @JsonKey(name: 'root_paths')
    @Default([]) List<String> rootPaths,
    @JsonKey(name: 'primary_root')
    String? primaryRoot,
    @JsonKey(name: 'is_default')
    @Default(false) bool isDefault,
    @JsonKey(name: 'match_rules')
    @Default([]) List<Map<String, dynamic>> matchRules,
    @JsonKey(name: 'auto_clear_missing')
    @Default(false) bool autoClearMissing,
    @JsonKey(name: 'realtime_watch')
    @Default(false) bool realtimeWatch,
    @JsonKey(name: 'keep_local')
    bool? keepLocal,
    @JsonKey(name: 'network_mount')
    @Default(false) bool networkMount,
    @JsonKey(name: 'custom_cover')
    @Default(false) bool customCover,
    @JsonKey(name: 'scrape_overrides')
    @Default({}) Map<String, dynamic> scrapeOverrides,
    @Default(LibraryStats()) LibraryStats stats,
    @Default(false) bool scanning,
    @JsonKey(name: 'scan_progress')
    ScanProgressView? scanProgress,
    @JsonKey(name: 'last_scan')
    LastScanView? lastScan,
    @Default(false) bool organizing,
    @JsonKey(name: 'organize_progress')
    ScanProgressView? organizeProgress,
    @JsonKey(name: 'last_organize')
    LastOrganizeView? lastOrganize,
    @JsonKey(name: 'metadata_refresh')
    MetadataRefreshView? metadataRefresh,
    @JsonKey(name: 'chapter_job')
    ChapterJobView? chapterJob,
    @JsonKey(name: 'cloud_upload')
    CloudUploadView? cloudUpload,
    @JsonKey(name: 'cloud_folders')
    List<CloudFolderView>? cloudFolders,
    @JsonKey(name: 'created_at')
    @Default("") String createdAt,
    @JsonKey(name: 'updated_at')
    @Default("") String updatedAt,
  }) = _LibraryView;

  factory LibraryView.fromJson(Map<String, dynamic> json) => _$LibraryViewFromJson(json);
}

/// Kotlin `LlmDefaultsPayload`（Agent.kt）。
@freezed
abstract class LlmDefaultsPayload with _$LlmDefaultsPayload {
  const factory LlmDefaultsPayload({
    @JsonKey(name: 'agent_model')
    String? agentModel,
    @JsonKey(name: 'subtitle_model')
    String? subtitleModel,
  }) = _LlmDefaultsPayload;

  factory LlmDefaultsPayload.fromJson(Map<String, dynamic> json) => _$LlmDefaultsPayloadFromJson(json);
}

/// Kotlin `LlmDefaultsView`（Agent.kt）。
@freezed
abstract class LlmDefaultsView with _$LlmDefaultsView {
  const factory LlmDefaultsView({
    @JsonKey(name: 'agent_model')
    String? agentModel,
    @JsonKey(name: 'subtitle_model')
    String? subtitleModel,
    @JsonKey(name: 'effective_agent_model')
    String? effectiveAgentModel,
    @JsonKey(name: 'effective_subtitle_model')
    String? effectiveSubtitleModel,
  }) = _LlmDefaultsView;

  factory LlmDefaultsView.fromJson(Map<String, dynamic> json) => _$LlmDefaultsViewFromJson(json);
}

/// Kotlin `LlmModelInfo`（Llm.kt）。
@freezed
abstract class LlmModelInfo with _$LlmModelInfo {
  const factory LlmModelInfo({
    @Default("") String id,
    int? contextWindow,
    int? maxInputTokens,
    int? maxOutputTokens,
    @Default(true) bool supportsTools,
    @Default(false) bool supportsParallelToolCalls,
    @Default(false) bool supportsThinking,
    int? maxThinkingTokens,
    LlmThinkingControl? thinkingControl,
    @Default([]) List<String> modalities,
    @Default([]) List<String> thinkingLevels,
  }) = _LlmModelInfo;

  factory LlmModelInfo.fromJson(Map<String, dynamic> json) => _$LlmModelInfoFromJson(json);
}

/// Kotlin `LlmModelOption`（Agent.kt）。
@freezed
abstract class LlmModelOption with _$LlmModelOption {
  const factory LlmModelOption({
    @Default("") String ref,
    @Default("") String label,
    String? modelId,
    int? providerId,
    String? providerName,
    @Default(false) bool isDefault,
    @Default([]) List<String> thinkingLevels,
  }) = _LlmModelOption;

  factory LlmModelOption.fromJson(Map<String, dynamic> json) => _$LlmModelOptionFromJson(json);
}

/// Kotlin `LlmPresetView`（Llm.kt）。
@freezed
abstract class LlmPresetView with _$LlmPresetView {
  const factory LlmPresetView({
    @Default("") String id,
    @Default("") String displayName,
    String? baseUrl,
    @Default(false) bool requiresBaseUrl,
    @Default("") String defaultUserAgent,
    String? protocol,
    @Default([]) List<String> selectableProtocols,
    @Default([]) List<LlmModelInfo> models,
  }) = _LlmPresetView;

  factory LlmPresetView.fromJson(Map<String, dynamic> json) => _$LlmPresetViewFromJson(json);
}

/// Kotlin `LlmProviderPayload`（Llm.kt）。
@freezed
abstract class LlmProviderPayload with _$LlmProviderPayload {
  const factory LlmProviderPayload({
    @Default('') String name,
    @Default('') String providerType,
    String? baseUrl,
    String? userAgent,
    String? apiProtocol,
    String? apiKey,
    String? defaultModel,
    @Default([]) List<LlmModelInfo> extraModels,
  }) = _LlmProviderPayload;

  factory LlmProviderPayload.fromJson(Map<String, dynamic> json) => _$LlmProviderPayloadFromJson(json);
}

/// Kotlin `LlmProviderView`（Llm.kt）。
@freezed
abstract class LlmProviderView with _$LlmProviderView {
  const factory LlmProviderView({
    @Default(0) int id,
    @Default("") String name,
    @Default("") String providerType,
    String? baseUrl,
    String? userAgent,
    String? apiProtocol,
    @Default("") String defaultModel,
    @Default("pending") String status,
    @Default(false) bool usable,
    String? lastError,
    String? lastCheckedAt,
    List<String>? availableModels,
    @Default([]) List<LlmModelInfo> extraModels,
    String? createdAt,
    String? updatedAt,
  }) = _LlmProviderView;

  factory LlmProviderView.fromJson(Map<String, dynamic> json) => _$LlmProviderViewFromJson(json);
}

/// Kotlin `LlmThinkingControl`（Llm.kt）。
@freezed
abstract class LlmThinkingControl with _$LlmThinkingControl {
  const factory LlmThinkingControl({
    @Default("") String kind,
    @Default([]) List<String> levels,
    @Default(false) bool supportsOff,
  }) = _LlmThinkingControl;

  factory LlmThinkingControl.fromJson(Map<String, dynamic> json) => _$LlmThinkingControlFromJson(json);
}

/// Kotlin `LocalMetaView`（Models.kt）。
@freezed
abstract class LocalMetaView with _$LocalMetaView {
  const factory LocalMetaView({
    String? plot,
    double? rating,
    @JsonKey(name: 'runtime_minutes')
    int? runtimeMinutes,
    @Default([]) List<String> genres,
    @Default([]) List<String> directors,
    @JsonKey(name: 'director_credits')
    @Default([]) List<DirectorView> directorCredits,
    @Default([]) List<ActorView> actors,
    @JsonKey(name: 'nfo_name')
    @Default("") String nfoName,
    @Default("") String source,
  }) = _LocalMetaView;

  factory LocalMetaView.fromJson(Map<String, dynamic> json) => _$LocalMetaViewFromJson(json);
}

/// Kotlin `LogContent`（Maintenance.kt）。
@freezed
abstract class LogContent with _$LogContent {
  const factory LogContent({
    @Default("") String day,
    @Default([]) List<String> lines,
    @Default(0) int totalLines,
    @Default(false) bool truncated,
    @Default(0) int sizeBytes,
  }) = _LogContent;

  factory LogContent.fromJson(Map<String, dynamic> json) => _$LogContentFromJson(json);
}

/// Kotlin `LogDay`（Maintenance.kt）。
@freezed
abstract class LogDay with _$LogDay {
  const factory LogDay({
    @Default("") String day,
    @Default(0) int sizeBytes,
  }) = _LogDay;

  factory LogDay.fromJson(Map<String, dynamic> json) => _$LogDayFromJson(json);
}

/// Kotlin `LogDayList`（Maintenance.kt）。
@freezed
abstract class LogDayList with _$LogDayList {
  const factory LogDayList({
    @Default([]) List<LogDay> days,
  }) = _LogDayList;

  factory LogDayList.fromJson(Map<String, dynamic> json) => _$LogDayListFromJson(json);
}

/// Kotlin `LoginDevice`（Settings.kt）。
@freezed
abstract class LoginDevice with _$LoginDevice {
  const factory LoginDevice({
    @Default('') String id,
    @Default("") String kind,
    @Default("") String kindLabel,
    @Default("") String family,
    @Default("") String name,
    @Default("full") String scope,
    String? platform,
    String? clientVersion,
    String? createdAt,
    String? lastSeenAt,
    String? lastSeenIp,
    @Default(false) bool current,
    @Default(false) bool connected,
    @Default(true) bool renamable,
    @Default(0) int ownerId,
    @Default("") String ownerUsername,
    @Default("") String ownerNickname,
  }) = _LoginDevice;

  factory LoginDevice.fromJson(Map<String, dynamic> json) => _$LoginDeviceFromJson(json);
}

/// Kotlin `LoginDeviceView`（Models.kt）。
@freezed
abstract class LoginDeviceView with _$LoginDeviceView {
  const factory LoginDeviceView({
    @Default("") String id,
    @Default("") String kind,
    @JsonKey(name: 'kind_label')
    @Default("") String kindLabel,
    @Default("") String family,
    @Default("") String name,
    @Default("") String scope,
    String? platform,
    @JsonKey(name: 'client_version')
    String? clientVersion,
    @JsonKey(name: 'created_at')
    @Default("") String createdAt,
    @JsonKey(name: 'last_seen_at')
    String? lastSeenAt,
    @JsonKey(name: 'last_seen_ip')
    String? lastSeenIp,
    @JsonKey(name: 'expires_at')
    String? expiresAt,
    @Default(false) bool current,
    @Default(false) bool connected,
    @Default(false) bool renamable,
    @JsonKey(name: 'owner_id')
    @Default(0) int ownerId,
    @JsonKey(name: 'owner_username')
    @Default("") String ownerUsername,
    @JsonKey(name: 'owner_nickname')
    @Default("") String ownerNickname,
    DevicePushView? push,
  }) = _LoginDeviceView;

  factory LoginDeviceView.fromJson(Map<String, dynamic> json) => _$LoginDeviceViewFromJson(json);
}

/// Kotlin `ManualDownloadCandidateView`（DownloadTarget.kt）。
@freezed
abstract class ManualDownloadCandidateView with _$ManualDownloadCandidateView {
  const factory ManualDownloadCandidateView({
    @Default(0) int tmdbId,
    @Default("movie") String kind,
    @Default("") String title,
    int? year,
    int? episodeCount,
    String? posterUrl,
  }) = _ManualDownloadCandidateView;

  factory ManualDownloadCandidateView.fromJson(Map<String, dynamic> json) => _$ManualDownloadCandidateViewFromJson(json);
}

/// Kotlin `ManualDownloadTargetRequest`（DownloadTarget.kt）。
@freezed
abstract class ManualDownloadTargetRequest with _$ManualDownloadTargetRequest {
  const factory ManualDownloadTargetRequest({
    String? kind,
    String? title,
    int? year,
    String? subtitle,
    String? hint,
    int? downloaderId,
    int? selectedTmdbId,
    String? selectedKind,
  }) = _ManualDownloadTargetRequest;

  factory ManualDownloadTargetRequest.fromJson(Map<String, dynamic> json) => _$ManualDownloadTargetRequestFromJson(json);
}

/// Kotlin `ManualDownloadTargetView`（DownloadTarget.kt）。
@freezed
abstract class ManualDownloadTargetView with _$ManualDownloadTargetView {
  const factory ManualDownloadTargetView({
    @Default("not_found") String status,
    int? tmdbId,
    String? kind,
    String? title,
    int? year,
    @Default([]) List<ManualDownloadCandidateView> candidates,
    int? libraryId,
    String? libraryName,
    String? mode,
    String? path,
    String? entryDir,
    String? stagingPath,
    bool? routeMatched,
    String? routeReason,
    @Default(false) bool ok,
    String? warning,
  }) = _ManualDownloadTargetView;

  factory ManualDownloadTargetView.fromJson(Map<String, dynamic> json) => _$ManualDownloadTargetViewFromJson(json);
}

/// Kotlin `MatroskaCuesView`（Models.kt）。
@freezed
abstract class MatroskaCuesView with _$MatroskaCuesView {
  const factory MatroskaCuesView({
    @Default(0) int offset,
    @Default("") String data,
    @JsonKey(name: 'original_bytes')
    @Default(0) int originalBytes,
  }) = _MatroskaCuesView;

  factory MatroskaCuesView.fromJson(Map<String, dynamic> json) => _$MatroskaCuesViewFromJson(json);
}

/// Kotlin `McpEndpointView`（Agent.kt）。
@freezed
abstract class McpEndpointView with _$McpEndpointView {
  const factory McpEndpointView({
    @Default("") String id,
    @Default("") String slug,
    @Default("") String name,
    @Default("") String description,
    @Default(false) bool enabled,
    @Default([]) List<String> services,
    @JsonKey(name: 'tool_count')
    @Default(0) int toolCount,
    @Default("") String url,
    @JsonKey(name: 'last_used_at')
    String? lastUsedAt,
  }) = _McpEndpointView;

  factory McpEndpointView.fromJson(Map<String, dynamic> json) => _$McpEndpointViewFromJson(json);
}

/// Kotlin `McpStatusView`（Agent.kt）。
@freezed
abstract class McpStatusView with _$McpStatusView {
  const factory McpStatusView({
    @Default(false) bool enabled,
    @JsonKey(name: 'base_url')
    @Default("") String baseUrl,
    @JsonKey(name: 'external_url_configured')
    @Default(false) bool externalUrlConfigured,
    @Default([]) List<McpEndpointView> endpoints,
  }) = _McpStatusView;

  factory McpStatusView.fromJson(Map<String, dynamic> json) => _$McpStatusViewFromJson(json);
}

/// Kotlin `McpToggleRequest`（Agent.kt）。
@freezed
abstract class McpToggleRequest with _$McpToggleRequest {
  const factory McpToggleRequest({
    @Default(false) bool enabled,
  }) = _McpToggleRequest;

  factory McpToggleRequest.fromJson(Map<String, dynamic> json) => _$McpToggleRequestFromJson(json);
}

/// Kotlin `MediaActivityTarget`（Activity.kt）。
@freezed
abstract class MediaActivityTarget with _$MediaActivityTarget {
  const factory MediaActivityTarget({
    @Default(0) int mediaItemId,
    int? libraryId,
    @Default(true) bool browsable,
    @Default("movie") String kind,
    @Default("") String title,
    int? year,
    String? posterUrl,
    @Default(0) int seasonNumber,
    @Default(0) int episodeNumber,
  }) = _MediaActivityTarget;

  factory MediaActivityTarget.fromJson(Map<String, dynamic> json) => _$MediaActivityTargetFromJson(json);
}

/// Kotlin `MediaBrief`（Models.kt）。
@freezed
abstract class MediaBrief with _$MediaBrief {
  const factory MediaBrief({
    @JsonKey(name: 'media_item_id')
    @Default(0) int mediaItemId,
    @Default("") String kind,
    @JsonKey(name: 'tmdb_id')
    @Default(0) int tmdbId,
    @JsonKey(name: 'douban_id')
    String? doubanId,
    @Default("") String title,
    @JsonKey(name: 'original_title')
    @Default("") String originalTitle,
    @JsonKey(name: 'english_title')
    String? englishTitle,
    int? year,
    @JsonKey(name: 'poster_url')
    String? posterUrl,
    @JsonKey(name: 'backdrop_url')
    String? backdropUrl,
    @JsonKey(name: 'logo_url')
    String? logoUrl,
    String? status,
  }) = _MediaBrief;

  factory MediaBrief.fromJson(Map<String, dynamic> json) => _$MediaBriefFromJson(json);
}

/// Kotlin `MediaImage`（Discovery.kt）。
@freezed
abstract class MediaImage with _$MediaImage {
  const factory MediaImage({
    @Default("") String previewUrl,
    @Default("") String fullUrl,
    @Default(0) int width,
    @Default(0) int height,
  }) = _MediaImage;

  factory MediaImage.fromJson(Map<String, dynamic> json) => _$MediaImageFromJson(json);
}

/// Kotlin `MediaLibraryLink`（Discovery.kt）。
@freezed
abstract class MediaLibraryLink with _$MediaLibraryLink {
  const factory MediaLibraryLink({
    @Default(0) int libraryId,
    @Default("") String libraryName,
    @Default(0) int mediaItemId,
  }) = _MediaLibraryLink;

  factory MediaLibraryLink.fromJson(Map<String, dynamic> json) => _$MediaLibraryLinkFromJson(json);
}

/// Kotlin `MediaLibraryStatus`（Search.kt）。
@freezed
abstract class MediaLibraryStatus with _$MediaLibraryStatus {
  const factory MediaLibraryStatus({
    @Default(0) int mediaItemId,
    @Default(0) int libraryCount,
    @Default(0) int fileCount,
  }) = _MediaLibraryStatus;

  factory MediaLibraryStatus.fromJson(Map<String, dynamic> json) => _$MediaLibraryStatusFromJson(json);
}

/// Kotlin `MediaVideo`（Discovery.kt）。
@freezed
abstract class MediaVideo with _$MediaVideo {
  const factory MediaVideo({
    @Default("") String key,
    @Default("") String name,
  }) = _MediaVideo;

  factory MediaVideo.fromJson(Map<String, dynamic> json) => _$MediaVideoFromJson(json);
}

/// Kotlin `MemberCreateRequest`（Settings.kt）。
@freezed
abstract class MemberCreateRequest with _$MemberCreateRequest {
  const factory MemberCreateRequest({
    @Default('') String username,
    @Default('') String password,
    @Default("") String nickname,
  }) = _MemberCreateRequest;

  factory MemberCreateRequest.fromJson(Map<String, dynamic> json) => _$MemberCreateRequestFromJson(json);
}

/// Kotlin `MemberPasswordReset`（Settings.kt）。
@freezed
abstract class MemberPasswordReset with _$MemberPasswordReset {
  const factory MemberPasswordReset({
    @Default(0) int id,
    @Default("") String username,
    @Default("") String password,
  }) = _MemberPasswordReset;

  factory MemberPasswordReset.fromJson(Map<String, dynamic> json) => _$MemberPasswordResetFromJson(json);
}

/// Kotlin `MemberStatusRequest`（Settings.kt）。
@freezed
abstract class MemberStatusRequest with _$MemberStatusRequest {
  const factory MemberStatusRequest({
    @Default(false) bool enabled,
  }) = _MemberStatusRequest;

  factory MemberStatusRequest.fromJson(Map<String, dynamic> json) => _$MemberStatusRequestFromJson(json);
}

/// Kotlin `MemberUpdateRequest`（Settings.kt）。
@freezed
abstract class MemberUpdateRequest with _$MemberUpdateRequest {
  const factory MemberUpdateRequest({
    String? nickname,
    bool? allowSubscribe,
    bool? allowSearch,
    bool? allowDirectDownload,
    bool? allLibraries,
    List<int>? libraryIds,
  }) = _MemberUpdateRequest;

  factory MemberUpdateRequest.fromJson(Map<String, dynamic> json) => _$MemberUpdateRequestFromJson(json);
}

/// Kotlin `MemberView`（Settings.kt）。
@freezed
abstract class MemberView with _$MemberView {
  const factory MemberView({
    @Default(0) int id,
    @Default("") String username,
    @Default("") String nickname,
    String? avatarUrl,
    @Default("active") String status,
    String? lastLoginAt,
    @Default(false) bool allowSubscribe,
    @Default(false) bool allowSearch,
    @Default(false) bool allowDirectDownload,
    @Default(true) bool allLibraries,
    @Default([]) List<int> libraryIds,
    @Default(0) int deviceCount,
  }) = _MemberView;

  factory MemberView.fromJson(Map<String, dynamic> json) => _$MemberViewFromJson(json);
}

/// Kotlin `MetadataRefreshView`（Models.kt）。
@freezed
abstract class MetadataRefreshView with _$MetadataRefreshView {
  const factory MetadataRefreshView({
    @Default(false) bool refreshing,
    @Default(0) int processed,
    @Default(0) int total,
    @Default(0) int failed,
    @Default(false) bool stopping,
    @Default([]) List<RefreshActiveView> active,
  }) = _MetadataRefreshView;

  factory MetadataRefreshView.fromJson(Map<String, dynamic> json) => _$MetadataRefreshViewFromJson(json);
}

/// Kotlin `ModelUpdateCheck`（Maintenance.kt）。
@freezed
abstract class ModelUpdateCheck with _$ModelUpdateCheck {
  const factory ModelUpdateCheck({
    String? currentTag,
    @Default("") String latestTag,
    @Default(false) bool updateAvailable,
    @Default(false) bool installable,
    @Default("") String publishedAt,
  }) = _ModelUpdateCheck;

  factory ModelUpdateCheck.fromJson(Map<String, dynamic> json) => _$ModelUpdateCheckFromJson(json);
}

/// Kotlin `MyPushView`（Push.kt）。
@freezed
abstract class MyPushView with _$MyPushView {
  const factory MyPushView({
    @Default([]) List<PushEventPref> events,
  }) = _MyPushView;

  factory MyPushView.fromJson(Map<String, dynamic> json) => _$MyPushViewFromJson(json);
}

/// Kotlin `NavUiPrefs`（Models.kt）。
@freezed
abstract class NavUiPrefs with _$NavUiPrefs {
  const factory NavUiPrefs({
    @Default([]) List<String> order,
    List<String>? hidden,
  }) = _NavUiPrefs;

  factory NavUiPrefs.fromJson(Map<String, dynamic> json) => _$NavUiPrefsFromJson(json);
}

/// Kotlin `NetworkConfig`（Maintenance.kt）。
@freezed
abstract class NetworkConfig with _$NetworkConfig {
  const factory NetworkConfig({
    @Default("off") String proxyMode,
    @Default("") String proxyUrl,
    @Default([]) List<String> proxyServices,
    @Default("") String tmdbApiBaseUrl,
    @Default("") String tmdbImageBaseUrl,
    @Default("") String doubanApiBaseUrl,
    @Default([]) List<EgressService> services,
    @JsonKey(name: 'env_proxy_detected')
    @Default("") String envProxyDetected,
    @JsonKey(name: 'mirror_defaults')
    @Default({}) Map<String, String> mirrorDefaults,
  }) = _NetworkConfig;

  factory NetworkConfig.fromJson(Map<String, dynamic> json) => _$NetworkConfigFromJson(json);
}

/// Kotlin `NetworkTestPayload`（Maintenance.kt）。
@freezed
abstract class NetworkTestPayload with _$NetworkTestPayload {
  const factory NetworkTestPayload({
    @Default('') String service,
  }) = _NetworkTestPayload;

  factory NetworkTestPayload.fromJson(Map<String, dynamic> json) => _$NetworkTestPayloadFromJson(json);
}

/// Kotlin `NetworkTestResult`（Maintenance.kt）。
@freezed
abstract class NetworkTestResult with _$NetworkTestResult {
  const factory NetworkTestResult({
    @Default(false) bool ok,
    int? latencyMs,
    @Default("") String message,
  }) = _NetworkTestResult;

  factory NetworkTestResult.fromJson(Map<String, dynamic> json) => _$NetworkTestResultFromJson(json);
}

/// Kotlin `Notice`（Search.kt）。
@freezed
abstract class Notice with _$Notice {
  const factory Notice({
    @Default(0) int id,
    @Default("info") String severity,
    @Default("") String source,
    @Default("") String title,
    @Default("") String message,
    Map<String, dynamic>? payload,
    String? createdAt,
    String? updatedAt,
  }) = _Notice;

  factory Notice.fromJson(Map<String, dynamic> json) => _$NoticeFromJson(json);
}

/// Kotlin `OfficialChannelRequest`（Agent.kt）。
@freezed
abstract class OfficialChannelRequest with _$OfficialChannelRequest {
  const factory OfficialChannelRequest({
    @Default(false) bool enabled,
  }) = _OfficialChannelRequest;

  factory OfficialChannelRequest.fromJson(Map<String, dynamic> json) => _$OfficialChannelRequestFromJson(json);
}

/// Kotlin `OfflineExport`（OfflineModels.kt）。
@freezed
abstract class OfflineExport with _$OfflineExport {
  const factory OfflineExport({
    @Default("") String exportId,
    @Default("") String status,
    @Default("") String etag,
    @Default(0) int expectedBytes,
    int? finalBytes,
    String? error,
    int? queuePosition,
    @Default("") String contentUrl,
  }) = _OfflineExport;

  factory OfflineExport.fromJson(Map<String, dynamic> json) => _$OfflineExportFromJson(json);
}

/// Kotlin `OfflineExportRequest`（OfflineModels.kt）。
@freezed
abstract class OfflineExportRequest with _$OfflineExportRequest {
  const factory OfflineExportRequest({
    @Default(0) int fileId,
    @Default('') String profile,
    String? audioTrack,
  }) = _OfflineExportRequest;

  factory OfflineExportRequest.fromJson(Map<String, dynamic> json) => _$OfflineExportRequestFromJson(json);
}

/// Kotlin `OfflineFileProfiles`（OfflineModels.kt）。
@freezed
abstract class OfflineFileProfiles with _$OfflineFileProfiles {
  const factory OfflineFileProfiles({
    @Default(0) int fileId,
    @Default(0) int mediaItemId,
    @Default(0) int seasonNumber,
    @Default(0) int episodeNumber,
    String? container,
    List<OfflineProfile>? profiles,
    String? unavailableReason,
  }) = _OfflineFileProfiles;

  factory OfflineFileProfiles.fromJson(Map<String, dynamic> json) => _$OfflineFileProfilesFromJson(json);
}

/// Kotlin `OfflineManifest`（OfflineModels.kt）。
@freezed
abstract class OfflineManifest with _$OfflineManifest {
  const factory OfflineManifest({
    @Default(0) int fileId,
    @Default(0) int mediaItemId,
    @Default(0) int libraryId,
    @Default(0) int seasonNumber,
    @Default(0) int episodeNumber,
    String? container,
    @Default(0) int sizeBytes,
    int? durationMs,
    dynamic item,
    @JsonKey(name: 'library')
    dynamic libraryValue,
    dynamic season,
    dynamic chapters,
    dynamic segments,
    dynamic audioTracks,
    String? defaultAudio,
    String? defaultSubtitle,
    @Default([]) List<OfflineSubtitleRef> subtitles,
    String? fontsUrl,
    @Default([]) List<OfflineProfile> profiles,
    String? unavailableReason,
    int? resumePositionMs,
  }) = _OfflineManifest;

  factory OfflineManifest.fromJson(Map<String, dynamic> json) => _$OfflineManifestFromJson(json);
}

/// Kotlin `OfflineProfile`（OfflineModels.kt）。
@freezed
abstract class OfflineProfile with _$OfflineProfile {
  const factory OfflineProfile({
    @Default("") String profile,
    @Default("") String label,
    int? height,
    @Default(0) int expectedBytes,
  }) = _OfflineProfile;

  factory OfflineProfile.fromJson(Map<String, dynamic> json) => _$OfflineProfileFromJson(json);
}

/// Kotlin `OfflineProfilesRequest`（OfflineModels.kt）。
@freezed
abstract class OfflineProfilesRequest with _$OfflineProfilesRequest {
  const factory OfflineProfilesRequest({
    @Default([]) List<int> fileIds,
  }) = _OfflineProfilesRequest;

  factory OfflineProfilesRequest.fromJson(Map<String, dynamic> json) => _$OfflineProfilesRequestFromJson(json);
}

/// Kotlin `OfflineProfilesView`（OfflineModels.kt）。
@freezed
abstract class OfflineProfilesView with _$OfflineProfilesView {
  const factory OfflineProfilesView({
    List<OfflineFileProfiles>? files,
  }) = _OfflineProfilesView;

  factory OfflineProfilesView.fromJson(Map<String, dynamic> json) => _$OfflineProfilesViewFromJson(json);
}

/// Kotlin `OfflineSubtitleRef`（OfflineModels.kt）。
@freezed
abstract class OfflineSubtitleRef with _$OfflineSubtitleRef {
  const factory OfflineSubtitleRef({
    @Default("") String trackRef,
    @Default("") String format,
    String? language,
    String? title,
    @Default(false) bool isDefault,
    @Default(false) bool isForced,
    @Default(false) bool isAi,
    @Default(false) bool embedded,
    String? url,
  }) = _OfflineSubtitleRef;

  factory OfflineSubtitleRef.fromJson(Map<String, dynamic> json) => _$OfflineSubtitleRefFromJson(json);
}

/// Kotlin `OfflineViewingRecord`（OfflineModels.kt）。
@freezed
abstract class OfflineViewingRecord with _$OfflineViewingRecord {
  const factory OfflineViewingRecord({
    @Default('') String viewingId,
    @Default(0) int mediaItemId,
    @Default(0) int seasonNumber,
    @Default(0) int episodeNumber,
    int? fileId,
    @Default('') String startedAt,
    @Default('') String updatedAt,
    @Default(0) int startPositionMs,
    @Default(0) int positionMs,
    @Default(0) int watchedMs,
    @Default(false) bool completed,
    @Default(false) bool ended,
    int? durationMs,
  }) = _OfflineViewingRecord;

  factory OfflineViewingRecord.fromJson(Map<String, dynamic> json) => _$OfflineViewingRecordFromJson(json);
}

/// Kotlin `OfflineViewingResult`（OfflineModels.kt）。
@freezed
abstract class OfflineViewingResult with _$OfflineViewingResult {
  const factory OfflineViewingResult({
    @Default("") String viewingId,
    @Default("") String status,
  }) = _OfflineViewingResult;

  factory OfflineViewingResult.fromJson(Map<String, dynamic> json) => _$OfflineViewingResultFromJson(json);
}

/// Kotlin `OfflineViewingsRequest`（OfflineModels.kt）。
@freezed
abstract class OfflineViewingsRequest with _$OfflineViewingsRequest {
  const factory OfflineViewingsRequest({
    @Default('') String sentAt,
    @Default([]) List<OfflineViewingRecord> records,
  }) = _OfflineViewingsRequest;

  factory OfflineViewingsRequest.fromJson(Map<String, dynamic> json) => _$OfflineViewingsRequestFromJson(json);
}

/// Kotlin `OfflineViewingsView`（OfflineModels.kt）。
@freezed
abstract class OfflineViewingsView with _$OfflineViewingsView {
  const factory OfflineViewingsView({
    @Default([]) List<OfflineViewingResult> results,
  }) = _OfflineViewingsView;

  factory OfflineViewingsView.fromJson(Map<String, dynamic> json) => _$OfflineViewingsViewFromJson(json);
}

/// Kotlin `PathHealthView`（DownloadTarget.kt）。
@freezed
abstract class PathHealthView with _$PathHealthView {
  const factory PathHealthView({
    @Default("") String local,
    @Default("") String remote,
    @Default("") String state,
    String? detail,
  }) = _PathHealthView;

  factory PathHealthView.fromJson(Map<String, dynamic> json) => _$PathHealthViewFromJson(json);
}

/// Kotlin `PathMapping`（DownloadTarget.kt）。
@freezed
abstract class PathMapping with _$PathMapping {
  const factory PathMapping({
    @Default("") String local,
    @Default("") String remote,
  }) = _PathMapping;

  factory PathMapping.fromJson(Map<String, dynamic> json) => _$PathMappingFromJson(json);
}

/// Kotlin `PendingUpdate`（Maintenance.kt）。
@freezed
abstract class PendingUpdate with _$PendingUpdate {
  const factory PendingUpdate({
    String? appVersion,
    @Default(true) bool appCompatible,
    @Default("") String appChangelog,
    @Default("") String appPublishedAt,
    String? modelTag,
    String? checkedAt,
  }) = _PendingUpdate;

  factory PendingUpdate.fromJson(Map<String, dynamic> json) => _$PendingUpdateFromJson(json);
}

/// Kotlin `PendingView`（SubtitleGen.kt）。
@freezed
abstract class PendingView with _$PendingView {
  const factory PendingView({
    @Default("") String message,
    @Default("") String candidateKey,
    @Default(2500) int retryAfterMs,
  }) = _PendingView;

  factory PendingView.fromJson(Map<String, dynamic> json) => _$PendingViewFromJson(json);
}

/// Kotlin `PgsConversionView`（SubtitleGen.kt）。
@freezed
abstract class PgsConversionView with _$PgsConversionView {
  const factory PgsConversionView({
    @Default("") String candidateKey,
    String? language,
    @Default(false) bool available,
    String? engine,
    @Default("") String platform,
    @Default("") String architecture,
    @Default(false) bool cached,
    @Default("") String message,
    @Default([]) List<String> suggestions,
    String? ocrLanguage,
    String? ocrLanguageLabel,
    @Default(false) bool languageConfirmationRequired,
    @Default("") String languageReason,
    @Default([]) List<PgsLanguageOption> languageOptions,
  }) = _PgsConversionView;

  factory PgsConversionView.fromJson(Map<String, dynamic> json) => _$PgsConversionViewFromJson(json);
}

/// Kotlin `PgsLanguageOption`（SubtitleGen.kt）。
@freezed
abstract class PgsLanguageOption with _$PgsLanguageOption {
  const factory PgsLanguageOption({
    @Default("") String code,
    @Default("") String label,
  }) = _PgsLanguageOption;

  factory PgsLanguageOption.fromJson(Map<String, dynamic> json) => _$PgsLanguageOptionFromJson(json);
}

/// Kotlin `PipelineHealth`（Subscription.kt）。
@freezed
abstract class PipelineHealth with _$PipelineHealth {
  const factory PipelineHealth({
    @Default("ok") String status,
    @Default(0) int errorCount,
    @Default(0) int warnCount,
    @Default(false) bool downloaderOk,
    @Default(false) bool sitesConfigured,
    @Default(false) bool downloadersConfigured,
  }) = _PipelineHealth;

  factory PipelineHealth.fromJson(Map<String, dynamic> json) => _$PipelineHealthFromJson(json);
}

/// Kotlin `PlaybackActivityView`（Activity.kt）。
@freezed
abstract class PlaybackActivityView with _$PlaybackActivityView {
  const factory PlaybackActivityView({
    @Default([]) List<ActivePlaybackSession> sessions,
    @Default([]) List<ActiveFileDownload> downloads,
  }) = _PlaybackActivityView;

  factory PlaybackActivityView.fromJson(Map<String, dynamic> json) => _$PlaybackActivityViewFromJson(json);
}

/// Kotlin `PlaybackArtifactUploadView`（Models.kt）。
@freezed
abstract class PlaybackArtifactUploadView with _$PlaybackArtifactUploadView {
  const factory PlaybackArtifactUploadView({
    @Default("") String name,
    @Default(0) int status,
    @JsonKey(name: 'received_bytes')
    @Default(0) int receivedBytes,
    @JsonKey(name: 'content_length')
    int? contentLength,
    @JsonKey(name: 'transfer_encoding')
    String? transferEncoding,
    @JsonKey(name: 'occurred_at_ms')
    @Default(0) int occurredAtMs,
  }) = _PlaybackArtifactUploadView;

  factory PlaybackArtifactUploadView.fromJson(Map<String, dynamic> json) => _$PlaybackArtifactUploadViewFromJson(json);
}

/// Kotlin `PlaybackAutoSkipRequest`（Models.kt）。
@freezed
abstract class PlaybackAutoSkipRequest with _$PlaybackAutoSkipRequest {
  const factory PlaybackAutoSkipRequest({
    @Default(false) bool enabled,
  }) = _PlaybackAutoSkipRequest;

  factory PlaybackAutoSkipRequest.fromJson(Map<String, dynamic> json) => _$PlaybackAutoSkipRequestFromJson(json);
}

/// Kotlin `PlaybackAutoSkipView`（Models.kt）。
@freezed
abstract class PlaybackAutoSkipView with _$PlaybackAutoSkipView {
  const factory PlaybackAutoSkipView({
    @Default(false) bool enabled,
    @Default(false) bool intro,
  }) = _PlaybackAutoSkipView;

  factory PlaybackAutoSkipView.fromJson(Map<String, dynamic> json) => _$PlaybackAutoSkipViewFromJson(json);
}

/// Kotlin `PlaybackBlurayClipView`（Models.kt）。
@freezed
abstract class PlaybackBlurayClipView with _$PlaybackBlurayClipView {
  const factory PlaybackBlurayClipView({
    @Default("") String url,
    @JsonKey(name: 'in_time')
    @Default(0) int inTime,
    @JsonKey(name: 'out_time')
    @Default(0) int outTime,
    @JsonKey(name: 'entry_pts')
    @Default([]) List<int> entryPts,
    @JsonKey(name: 'entry_spn')
    @Default([]) List<int> entrySpn,
  }) = _PlaybackBlurayClipView;

  factory PlaybackBlurayClipView.fromJson(Map<String, dynamic> json) => _$PlaybackBlurayClipViewFromJson(json);
}

/// Kotlin `PlaybackBlurayStreamView`（Models.kt）。
@freezed
abstract class PlaybackBlurayStreamView with _$PlaybackBlurayStreamView {
  const factory PlaybackBlurayStreamView({
    @Default("") String ref,
    int? pid,
    String? codec,
    String? language,
    int? channels,
  }) = _PlaybackBlurayStreamView;

  factory PlaybackBlurayStreamView.fromJson(Map<String, dynamic> json) => _$PlaybackBlurayStreamViewFromJson(json);
}

/// Kotlin `PlaybackBlurayView`（Models.kt）。
@freezed
abstract class PlaybackBlurayView with _$PlaybackBlurayView {
  const factory PlaybackBlurayView({
    @Default("") String playlist,
    @Default([]) List<PlaybackBlurayClipView> clips,
    @Default([]) List<PlaybackBlurayStreamView> audio,
    @Default([]) List<PlaybackBlurayStreamView> subtitles,
  }) = _PlaybackBlurayView;

  factory PlaybackBlurayView.fromJson(Map<String, dynamic> json) => _$PlaybackBlurayViewFromJson(json);
}

/// Kotlin `PlaybackChapterMarkView`（Models.kt）。
@freezed
abstract class PlaybackChapterMarkView with _$PlaybackChapterMarkView {
  const factory PlaybackChapterMarkView({
    @JsonKey(name: 'start_ms')
    @Default(0) int startMs,
    String? title,
  }) = _PlaybackChapterMarkView;

  factory PlaybackChapterMarkView.fromJson(Map<String, dynamic> json) => _$PlaybackChapterMarkViewFromJson(json);
}

/// Kotlin `PlaybackClientLogPayload`（Models.kt）。
@freezed
abstract class PlaybackClientLogPayload with _$PlaybackClientLogPayload {
  const factory PlaybackClientLogPayload({
    @Default('') String event,
    Map<String, dynamic>? detail,
  }) = _PlaybackClientLogPayload;

  factory PlaybackClientLogPayload.fromJson(Map<String, dynamic> json) => _$PlaybackClientLogPayloadFromJson(json);
}

/// Kotlin `PlaybackDecideRequest`（Models.kt）。
@freezed
abstract class PlaybackDecideRequest with _$PlaybackDecideRequest {
  const factory PlaybackDecideRequest({
    @JsonKey(name: 'file_id')
    int? fileId,
    @JsonKey(name: 'media_item_id')
    int? mediaItemId,
    @JsonKey(name: 'season_number')
    int? seasonNumber,
    @JsonKey(name: 'episode_number')
    int? episodeNumber,
    @Default(ClientCapabilityIn()) ClientCapabilityIn capability,
    @JsonKey(name: 'failed_tiers')
    List<int>? failedTiers,
    @JsonKey(name: 'audio_track')
    String? audioTrack,
    @JsonKey(name: 'subtitle_track')
    String? subtitleTrack,
    @JsonKey(name: 'burn_requested')
    bool? burnRequested,
    @JsonKey(name: 'max_height')
    int? maxHeight,
    @JsonKey(name: 'device_id')
    String? deviceId,
    @JsonKey(name: 'downlink_bps')
    int? downlinkBps,
  }) = _PlaybackDecideRequest;

  factory PlaybackDecideRequest.fromJson(Map<String, dynamic> json) => _$PlaybackDecideRequestFromJson(json);
}

/// Kotlin `PlaybackDecisionView`（Models.kt）。
@freezed
abstract class PlaybackDecisionView with _$PlaybackDecisionView {
  const factory PlaybackDecisionView({
    @Default("") String outcome,
    int? tier,
    @JsonKey(name: 'file_id')
    int? fileId,
    String? container,
    VideoPlanView? video,
    AudioPlanView? audio,
    @JsonKey(name: 'audio_tracks')
    @Default([]) List<AudioTrackView> audioTracks,
    @Default([]) List<SubtitlePlanView> subtitles,
    @JsonKey(name: 'degraded_from')
    int? degradedFrom,
    String? disc,
    @JsonKey(name: 'disc_playlist')
    String? discPlaylist,
    @JsonKey(name: 'cost_hint')
    String? costHint,
    @JsonKey(name: 'can_self_enable')
    bool? canSelfEnable,
    @JsonKey(name: 'setting_namespace')
    String? settingNamespace,
    @JsonKey(name: 'setting_key')
    String? settingKey,
    @Default("") String reason,
    String? suggestion,
  }) = _PlaybackDecisionView;

  factory PlaybackDecisionView.fromJson(Map<String, dynamic> json) => _$PlaybackDecisionViewFromJson(json);
}

/// Kotlin `PlaybackDelivery`（Activity.kt）。
@freezed
abstract class PlaybackDelivery with _$PlaybackDelivery {
  const factory PlaybackDelivery({
    @Default("direct") String mode,
    @Default("") String label,
    String? target,
    String? executor,
    String? reason,
  }) = _PlaybackDelivery;

  factory PlaybackDelivery.fromJson(Map<String, dynamic> json) => _$PlaybackDeliveryFromJson(json);
}

/// Kotlin `PlaybackDiagnosticsView`（Models.kt）。
@freezed
abstract class PlaybackDiagnosticsView with _$PlaybackDiagnosticsView {
  const factory PlaybackDiagnosticsView({
    @JsonKey(name: 'session_state')
    @Default("") String sessionState,
    @JsonKey(name: 'session_error')
    String? sessionError,
    @JsonKey(name: 'processing_mode')
    @Default("") String processingMode,
    @JsonKey(name: 'execution_location')
    @Default("") String executionLocation,
    String? backend,
    String? encoder,
    @JsonKey(name: 'worker_id')
    String? workerId,
    @JsonKey(name: 'worker_version')
    String? workerVersion,
    @JsonKey(name: 'worker_platform')
    String? workerPlatform,
    @JsonKey(name: 'worker_arch')
    String? workerArch,
    @JsonKey(name: 'ffmpeg_version')
    String? ffmpegVersion,
    @JsonKey(name: 'worker_online')
    bool? workerOnline,
    @JsonKey(name: 'worker_last_seen_seconds')
    double? workerLastSeenSeconds,
    @JsonKey(name: 'job_id')
    String? jobId,
    @JsonKey(name: 'attempt_id')
    String? attemptId,
    @JsonKey(name: 'job_state')
    String? jobState,
    @JsonKey(name: 'job_out_time_ms')
    int? jobOutTimeMs,
    @JsonKey(name: 'job_speed')
    String? jobSpeed,
    @JsonKey(name: 'job_phase')
    String? jobPhase,
    @JsonKey(name: 'job_exit_code')
    int? jobExitCode,
    @JsonKey(name: 'job_error')
    String? jobError,
    @JsonKey(name: 'job_stderr_tail')
    String? jobStderrTail,
    @JsonKey(name: 'head_segment')
    int? headSegment,
    @JsonKey(name: 'highest_produced_segment')
    int? highestProducedSegment,
    @JsonKey(name: 'requested_segment')
    int? requestedSegment,
    @JsonKey(name: 'served_segment')
    int? servedSegment,
    @JsonKey(name: 'segment_wait_ms')
    int? segmentWaitMs,
    @JsonKey(name: 'segment_status')
    int? segmentStatus,
    @JsonKey(name: 'pending_segments')
    @Default([]) List<int> pendingSegments,
    @JsonKey(name: 'failed_segments')
    @Default([]) List<int> failedSegments,
    @JsonKey(name: 'historical_failed_segments')
    @Default([]) List<int> historicalFailedSegments,
    @JsonKey(name: 'recent_uploads')
    @Default([]) List<PlaybackArtifactUploadView> recentUploads,
    @JsonKey(name: 'cache_bytes')
    @Default(0) int cacheBytes,
    @JsonKey(name: 'total_segments')
    int? totalSegments,
    @JsonKey(name: 'lead_seconds')
    double? leadSeconds,
    @JsonKey(name: 'pause_reasons')
    @Default([]) List<String> pauseReasons,
    @JsonKey(name: 'cache_hit')
    @Default(false) bool cacheHit,
    @JsonKey(name: 'cached_segments')
    @Default(0) int cachedSegments,
    @Default([]) List<Map<String, dynamic>> timeline,
  }) = _PlaybackDiagnosticsView;

  factory PlaybackDiagnosticsView.fromJson(Map<String, dynamic> json) => _$PlaybackDiagnosticsViewFromJson(json);
}

/// Kotlin `PlaybackHistoryView`（Activity.kt）。
@freezed
abstract class PlaybackHistoryView with _$PlaybackHistoryView {
  const factory PlaybackHistoryView({
    @Default([]) List<PlaybackLogEntry> entries,
    @Default(0) int hiddenCount,
    @Default(false) bool hasMore,
    int? nextCursor,
  }) = _PlaybackHistoryView;

  factory PlaybackHistoryView.fromJson(Map<String, dynamic> json) => _$PlaybackHistoryViewFromJson(json);
}

/// Kotlin `PlaybackItemView`（Models.kt）。
@freezed
abstract class PlaybackItemView with _$PlaybackItemView {
  const factory PlaybackItemView({
    @JsonKey(name: 'media_item_id')
    @Default(0) int mediaItemId,
    @JsonKey(name: 'library_id')
    @Default(0) int libraryId,
    @Default("") String kind,
    @Default("") String title,
    int? year,
    @JsonKey(name: 'poster_url')
    String? posterUrl,
    List<int>? seasons,
  }) = _PlaybackItemView;

  factory PlaybackItemView.fromJson(Map<String, dynamic> json) => _$PlaybackItemViewFromJson(json);
}

/// Kotlin `PlaybackLogEntry`（Activity.kt）。
@freezed
abstract class PlaybackLogEntry with _$PlaybackLogEntry {
  const factory PlaybackLogEntry({
    @Default(0) int id,
    @Default("") String memberName,
    @Default(MediaActivityTarget()) MediaActivityTarget media,
    @Default("") String client,
    @Default("") String deviceName,
    @Default("") String startedAt,
    String? endedAt,
    @Default(0) int watchedMs,
    int? progressPercent,
    @Default(false) bool completed,
  }) = _PlaybackLogEntry;

  factory PlaybackLogEntry.fromJson(Map<String, dynamic> json) => _$PlaybackLogEntryFromJson(json);
}

/// Kotlin `PlaybackMarks`（Playback.kt）。
@freezed
abstract class PlaybackMarks with _$PlaybackMarks {
  const factory PlaybackMarks({
    @Default(false) bool played,
    @Default(false) bool isFavorite,
    int? unplayedCount,
  }) = _PlaybackMarks;

  factory PlaybackMarks.fromJson(Map<String, dynamic> json) => _$PlaybackMarksFromJson(json);
}

/// Kotlin `PlaybackMarksRequest`（Models.kt）。
@freezed
abstract class PlaybackMarksRequest with _$PlaybackMarksRequest {
  const factory PlaybackMarksRequest({
    @JsonKey(name: 'media_item_id')
    @Default(0) int mediaItemId,
    @JsonKey(name: 'season_number')
    int? seasonNumber,
    @JsonKey(name: 'episode_number')
    int? episodeNumber,
    bool? played,
    bool? favorite,
    @JsonKey(name: 'device_id')
    String? deviceId,
  }) = _PlaybackMarksRequest;

  factory PlaybackMarksRequest.fromJson(Map<String, dynamic> json) => _$PlaybackMarksRequestFromJson(json);
}

/// Kotlin `PlaybackMetricPayload`（Models.kt）。
@freezed
abstract class PlaybackMetricPayload with _$PlaybackMetricPayload {
  const factory PlaybackMetricPayload({
    @JsonKey(name: 'library_file_id')
    int? libraryFileId,
    @Default(0) int tier,
    @JsonKey(name: 'degraded_from')
    int? degradedFrom,
    String? engine,
    @JsonKey(name: 'hw_backend')
    String? hwBackend,
    @JsonKey(name: 'ttff_ms')
    int? ttffMs,
    @JsonKey(name: 'rebuffer_ms')
    int? rebufferMs,
    @JsonKey(name: 'rebuffer_count')
    int? rebufferCount,
    @JsonKey(name: 'seek_count')
    int? seekCount,
    @JsonKey(name: 'dropped_frames')
    int? droppedFrames,
    @JsonKey(name: 'total_frames')
    int? totalFrames,
    @JsonKey(name: 'watched_ms')
    int? watchedMs,
    @JsonKey(name: 'attempt_id')
    String? attemptId,
    String? outcome,
    @JsonKey(name: 'media_item_id')
    int? mediaItemId,
    @JsonKey(name: 'season_number')
    int? seasonNumber,
    @JsonKey(name: 'episode_number')
    int? episodeNumber,
    String? origin,
    String? client,
    @JsonKey(name: 'lab_scenario')
    String? labScenario,
    String? route,
    @JsonKey(name: 'network_class')
    String? networkClass,
    @JsonKey(name: 'app_version')
    String? appVersion,
    @JsonKey(name: 'first_frame_ms')
    int? firstFrameMs,
    @JsonKey(name: 'playing_ms')
    int? playingMs,
    @JsonKey(name: 'user_wait_ms')
    int? userWaitMs,
    @JsonKey(name: 'error_kind')
    String? errorKind,
    @JsonKey(name: 'error_category')
    String? errorCategory,
    @JsonKey(name: 'error_stage')
    String? errorStage,
    Map<String, dynamic>? detail,
    @JsonKey(name: 'log_tail')
    String? logTail,
  }) = _PlaybackMetricPayload;

  factory PlaybackMetricPayload.fromJson(Map<String, dynamic> json) => _$PlaybackMetricPayloadFromJson(json);
}

/// Kotlin `PlaybackPolicy`（Settings.kt）。
@freezed
abstract class PlaybackPolicy with _$PlaybackPolicy {
  const factory PlaybackPolicy({
    @Default(false) bool softwareTranscodeEnabled,
    @Default(true) bool trickplayEnabled,
    @Default(true) bool transcodeCacheEnabled,
    @Default(false) bool hardwareAvailable,
    @Default([]) List<String> hwBackends,
  }) = _PlaybackPolicy;

  factory PlaybackPolicy.fromJson(Map<String, dynamic> json) => _$PlaybackPolicyFromJson(json);
}

/// Kotlin `PlaybackPolicyPatchFull`（Settings.kt）。
@freezed
abstract class PlaybackPolicyPatchFull with _$PlaybackPolicyPatchFull {
  const factory PlaybackPolicyPatchFull({
    bool? softwareTranscodeEnabled,
    bool? trickplayEnabled,
    bool? transcodeCacheEnabled,
  }) = _PlaybackPolicyPatchFull;

  factory PlaybackPolicyPatchFull.fromJson(Map<String, dynamic> json) => _$PlaybackPolicyPatchFullFromJson(json);
}

/// Kotlin `PlaybackProgressRequest`（Models.kt）。
@freezed
abstract class PlaybackProgressRequest with _$PlaybackProgressRequest {
  const factory PlaybackProgressRequest({
    @JsonKey(name: 'media_item_id')
    @Default(0) int mediaItemId,
    @JsonKey(name: 'season_number')
    int? seasonNumber,
    @JsonKey(name: 'episode_number')
    int? episodeNumber,
    String? event,
    @JsonKey(name: 'position_ms')
    int? positionMs,
    @JsonKey(name: 'audio_track')
    String? audioTrack,
    @JsonKey(name: 'subtitle_track')
    String? subtitleTrack,
    @JsonKey(name: 'file_id')
    int? fileId,
    @JsonKey(name: 'device_id')
    String? deviceId,
    bool? paused,
  }) = _PlaybackProgressRequest;

  factory PlaybackProgressRequest.fromJson(Map<String, dynamic> json) => _$PlaybackProgressRequestFromJson(json);
}

/// Kotlin `PlaybackSegmentView`（Models.kt）。
@freezed
abstract class PlaybackSegmentView with _$PlaybackSegmentView {
  const factory PlaybackSegmentView({
    @Default("") String type,
    @JsonKey(name: 'start_ms')
    @Default(0) int startMs,
    @JsonKey(name: 'end_ms')
    @Default(0) int endMs,
    @JsonKey(name: 'to_end')
    @Default(false) bool toEnd,
  }) = _PlaybackSegmentView;

  factory PlaybackSegmentView.fromJson(Map<String, dynamic> json) => _$PlaybackSegmentViewFromJson(json);
}

/// Kotlin `PlaybackSessionRequest`（Models.kt）。
@freezed
abstract class PlaybackSessionRequest with _$PlaybackSessionRequest {
  const factory PlaybackSessionRequest({
    @JsonKey(name: 'file_id')
    int? fileId,
    @JsonKey(name: 'media_item_id')
    int? mediaItemId,
    @JsonKey(name: 'season_number')
    int? seasonNumber,
    @JsonKey(name: 'episode_number')
    int? episodeNumber,
    @Default(ClientCapabilityIn()) ClientCapabilityIn capability,
    @JsonKey(name: 'failed_tiers')
    List<int>? failedTiers,
    @JsonKey(name: 'audio_track')
    String? audioTrack,
    @JsonKey(name: 'subtitle_track')
    String? subtitleTrack,
    @JsonKey(name: 'burn_requested')
    bool? burnRequested,
    @JsonKey(name: 'max_height')
    int? maxHeight,
    @JsonKey(name: 'device_id')
    String? deviceId,
    @JsonKey(name: 'downlink_bps')
    int? downlinkBps,
    @JsonKey(name: 'start_ms')
    int? startMs,
    @JsonKey(name: 'attempt_id')
    String? attemptId,
    String? client,
  }) = _PlaybackSessionRequest;

  factory PlaybackSessionRequest.fromJson(Map<String, dynamic> json) => _$PlaybackSessionRequestFromJson(json);
}

/// Kotlin `PlaybackSessionView`（Models.kt）。
@freezed
abstract class PlaybackSessionView with _$PlaybackSessionView {
  const factory PlaybackSessionView({
    @Default(PlaybackDecisionView()) PlaybackDecisionView decision,
    @JsonKey(name: 'session_id')
    String? sessionId,
    @JsonKey(name: 'stream_url')
    String? streamUrl,
    @JsonKey(name: 'progressive_segments')
    @Default(false) bool progressiveSegments,
    @JsonKey(name: 'start_ms')
    @Default(0) int startMs,
    @Default("") String timeline,
    @JsonKey(name: 'subtitle_urls')
    @Default([]) List<String> subtitleUrls,
    @JsonKey(name: 'master_url')
    String? masterUrl,
    @JsonKey(name: 'hw_backend')
    String? hwBackend,
    PlaybackStateView? watch,
    PlaybackSourceView? source,
    @Default([]) List<PlaybackChapterMarkView> chapters,
    List<PlaybackSegmentView>? segments,
    @JsonKey(name: 'auto_skip')
    PlaybackAutoSkipView? autoSkip,
    @JsonKey(name: 'matroska_cues')
    MatroskaCuesView? matroskaCues,
  }) = _PlaybackSessionView;

  factory PlaybackSessionView.fromJson(Map<String, dynamic> json) => _$PlaybackSessionViewFromJson(json);
}

/// Kotlin `PlaybackSourceView`（Models.kt）。
@freezed
abstract class PlaybackSourceView with _$PlaybackSourceView {
  const factory PlaybackSourceView({
    String? container,
    String? resolution,
    @JsonKey(name: 'video_codec')
    String? videoCodec,
    String? hdr,
    @JsonKey(name: 'bit_rate')
    int? bitRate,
    @JsonKey(name: 'frame_rate')
    double? frameRate,
    @JsonKey(name: 'size_bytes')
    int? sizeBytes,
    @JsonKey(name: 'on_drive')
    bool? onDrive,
  }) = _PlaybackSourceView;

  factory PlaybackSourceView.fromJson(Map<String, dynamic> json) => _$PlaybackSourceViewFromJson(json);
}

/// Kotlin `PlaybackStateView`（Models.kt）。
@freezed
abstract class PlaybackStateView with _$PlaybackStateView {
  const factory PlaybackStateView({
    @JsonKey(name: 'position_ms')
    @Default(0) int positionMs,
    @Default(false) bool played,
    @JsonKey(name: 'play_count')
    @Default(0) int playCount,
    @JsonKey(name: 'duration_ms')
    int? durationMs,
    @JsonKey(name: 'audio_track')
    String? audioTrack,
    @JsonKey(name: 'subtitle_track')
    String? subtitleTrack,
    @JsonKey(name: 'ended_by_admin')
    @Default(false) bool endedByAdmin,
  }) = _PlaybackStateView;

  factory PlaybackStateView.fromJson(Map<String, dynamic> json) => _$PlaybackStateViewFromJson(json);
}

/// Kotlin `PlaybackStatsClientRow`（Activity.kt）。
@freezed
abstract class PlaybackStatsClientRow with _$PlaybackStatsClientRow {
  const factory PlaybackStatsClientRow({
    @Default("") String client,
    @Default(0) int plays,
    @Default(0) int watchedMs,
  }) = _PlaybackStatsClientRow;

  factory PlaybackStatsClientRow.fromJson(Map<String, dynamic> json) => _$PlaybackStatsClientRowFromJson(json);
}

/// Kotlin `PlaybackStatsDayRow`（Activity.kt）。
@freezed
abstract class PlaybackStatsDayRow with _$PlaybackStatsDayRow {
  const factory PlaybackStatsDayRow({
    @Default("") String date,
    @Default(0) int plays,
    @Default(0) int watchedMs,
    @Default(0) int completed,
    @Default(0) int members,
  }) = _PlaybackStatsDayRow;

  factory PlaybackStatsDayRow.fromJson(Map<String, dynamic> json) => _$PlaybackStatsDayRowFromJson(json);
}

/// Kotlin `PlaybackStatsMemberRow`（Activity.kt）。
@freezed
abstract class PlaybackStatsMemberRow with _$PlaybackStatsMemberRow {
  const factory PlaybackStatsMemberRow({
    @Default(0) int memberId,
    @Default("") String memberName,
    @Default(0) int plays,
    @Default(0) int watchedMs,
    @Default(0) int completed,
  }) = _PlaybackStatsMemberRow;

  factory PlaybackStatsMemberRow.fromJson(Map<String, dynamic> json) => _$PlaybackStatsMemberRowFromJson(json);
}

/// Kotlin `PlaybackStatsTierRow`（Activity.kt）。
@freezed
abstract class PlaybackStatsTierRow with _$PlaybackStatsTierRow {
  const factory PlaybackStatsTierRow({
    @Default(0) int tier,
    @Default("") String label,
    @Default(0) int plays,
  }) = _PlaybackStatsTierRow;

  factory PlaybackStatsTierRow.fromJson(Map<String, dynamic> json) => _$PlaybackStatsTierRowFromJson(json);
}

/// Kotlin `PlaybackStatsTitleRow`（Activity.kt）。
@freezed
abstract class PlaybackStatsTitleRow with _$PlaybackStatsTitleRow {
  const factory PlaybackStatsTitleRow({
    @Default(MediaActivityTarget()) MediaActivityTarget media,
    @Default(0) int plays,
    @Default(0) int watchedMs,
    @Default(0) int members,
  }) = _PlaybackStatsTitleRow;

  factory PlaybackStatsTitleRow.fromJson(Map<String, dynamic> json) => _$PlaybackStatsTitleRowFromJson(json);
}

/// Kotlin `PlaybackStatsTotals`（Activity.kt）。
@freezed
abstract class PlaybackStatsTotals with _$PlaybackStatsTotals {
  const factory PlaybackStatsTotals({
    @Default(0) int plays,
    @Default(0) int watchedMs,
    @Default(0) int completed,
    @Default(0) int activeMembers,
  }) = _PlaybackStatsTotals;

  factory PlaybackStatsTotals.fromJson(Map<String, dynamic> json) => _$PlaybackStatsTotalsFromJson(json);
}

/// Kotlin `PlaybackWatchStatsView`（Activity.kt）。
@freezed
abstract class PlaybackWatchStatsView with _$PlaybackWatchStatsView {
  const factory PlaybackWatchStatsView({
    @Default(7) int days,
    @Default(PlaybackStatsTotals()) PlaybackStatsTotals current,
    @Default(PlaybackStatsTotals()) PlaybackStatsTotals previous,
    @Default(false) bool previousAvailable,
    @Default([]) List<PlaybackStatsDayRow> byDay,
    @Default([]) List<PlaybackStatsDayRow> previousByDay,
    @Default([]) List<List<int>> byHour,
    @Default([]) List<PlaybackStatsMemberRow> byMember,
    @Default([]) List<PlaybackStatsClientRow> byClient,
    @Default([]) List<PlaybackStatsTierRow> byTier,
    @Default([]) List<PlaybackStatsTitleRow> topTitles,
    @Default(0) int hiddenTitleCount,
    @Default([]) List<PlaybackStatsTitleRow> favorites,
    @Default([]) List<PlaybackStatsTitleRow> previousFavorites,
  }) = _PlaybackWatchStatsView;

  factory PlaybackWatchStatsView.fromJson(Map<String, dynamic> json) => _$PlaybackWatchStatsViewFromJson(json);
}

/// Kotlin `PosterBadgePrefs`（Models.kt）。
@freezed
abstract class PosterBadgePrefs with _$PosterBadgePrefs {
  const factory PosterBadgePrefs({
    @Default(false) bool rating,
    @Default(false) bool year,
    @Default(false) bool resolution,
    @Default(false) bool format,
    @Default(false) bool ended,
    @Default(false) bool airing,
    @JsonKey(name: 'chinese_subtitle')
    @Default(false) bool chineseSubtitle,
    @Default(false) bool progress,
    @Default(false) bool unwatched,
    @JsonKey(name: 'hover_only')
    @Default(false) bool hoverOnly,
    @JsonKey(name: 'min_rating')
    @Default(0.0) double minRating,
  }) = _PosterBadgePrefs;

  factory PosterBadgePrefs.fromJson(Map<String, dynamic> json) => _$PosterBadgePrefsFromJson(json);
}

/// Kotlin `PrepareView`（Models.kt）。
@freezed
abstract class PrepareView with _$PrepareView {
  const factory PrepareView({
    @Default("") String status,
    MediaBrief? media,
    @Default([]) List<SeasonOverview> seasons,
    @JsonKey(name: 'existing_subscription_id')
    int? existingSubscriptionId,
    @JsonKey(name: 'movie_owned')
    @Default(false) bool movieOwned,
    @JsonKey(name: 'suggested_seasons')
    @Default([]) List<int> suggestedSeasons,
    @Default([]) List<ResolveCandidateView> candidates,
    @JsonKey(name: 'douban_episodes')
    DoubanEpisodesView? doubanEpisodes,
    SmartPlanView? smart,
  }) = _PrepareView;

  factory PrepareView.fromJson(Map<String, dynamic> json) => _$PrepareViewFromJson(json);
}

/// Kotlin `ProgressView`（Models.kt）。
@freezed
abstract class ProgressView with _$ProgressView {
  const factory ProgressView({
    @Default(0) int total,
    @Default(0) int wanted,
    @Default(0) int grabbed,
    @Default(0) int downloaded,
    @Default(0) int imported,
    @Default(0) int upgrading,
  }) = _ProgressView;

  factory ProgressView.fromJson(Map<String, dynamic> json) => _$ProgressViewFromJson(json);
}

/// Kotlin `PushAckBody`（Push.kt）。
@freezed
abstract class PushAckBody with _$PushAckBody {
  const factory PushAckBody({
    @Default(0) int upTo,
  }) = _PushAckBody;

  factory PushAckBody.fromJson(Map<String, dynamic> json) => _$PushAckBodyFromJson(json);
}

/// Kotlin `PushAckView`（Push.kt）。
@freezed
abstract class PushAckView with _$PushAckView {
  const factory PushAckView({
    @Default(0) int acked,
  }) = _PushAckView;

  factory PushAckView.fromJson(Map<String, dynamic> json) => _$PushAckViewFromJson(json);
}

/// Kotlin `PushChannelView`（Agent.kt）。
@freezed
abstract class PushChannelView with _$PushChannelView {
  const factory PushChannelView({
    @Default("") String id,
    @Default("") String kind,
    @Default("") String name,
    @Default(false) bool enabled,
    @Default("") String state,
    @JsonKey(name: 'status_text')
    @Default("") String statusText,
  }) = _PushChannelView;

  factory PushChannelView.fromJson(Map<String, dynamic> json) => _$PushChannelViewFromJson(json);
}

/// Kotlin `PushChannelsView`（Agent.kt）。
@freezed
abstract class PushChannelsView with _$PushChannelsView {
  const factory PushChannelsView({
    @JsonKey(name: 'cloud_state')
    @Default("disconnected") String cloudState,
    @Default([]) List<PushChannelView> channels,
  }) = _PushChannelsView;

  factory PushChannelsView.fromJson(Map<String, dynamic> json) => _$PushChannelsViewFromJson(json);
}

/// Kotlin `PushEventPref`（Push.kt）。
@freezed
abstract class PushEventPref with _$PushEventPref {
  const factory PushEventPref({
    @Default("") String key,
    @Default("") String title,
    @Default("") String description,
    @Default("") String group,
    @Default(false) bool enabled,
  }) = _PushEventPref;

  factory PushEventPref.fromJson(Map<String, dynamic> json) => _$PushEventPrefFromJson(json);
}

/// Kotlin `PushPreferencesBody`（Push.kt）。
@freezed
abstract class PushPreferencesBody with _$PushPreferencesBody {
  const factory PushPreferencesBody({
    @Default({}) Map<String, bool> events,
  }) = _PushPreferencesBody;

  factory PushPreferencesBody.fromJson(Map<String, dynamic> json) => _$PushPreferencesBodyFromJson(json);
}

/// Kotlin `PushRegistrationBody`（Push.kt）。
@freezed
abstract class PushRegistrationBody with _$PushRegistrationBody {
  const factory PushRegistrationBody({
    @Default('') String permission,
    @Default(false) bool stream,
    String? clientVersion,
  }) = _PushRegistrationBody;

  factory PushRegistrationBody.fromJson(Map<String, dynamic> json) => _$PushRegistrationBodyFromJson(json);
}

/// Kotlin `PushRegistrationView`（Push.kt）。
@freezed
abstract class PushRegistrationView with _$PushRegistrationView {
  const factory PushRegistrationView({
    @Default(false) bool registered,
    @Default("") String status,
    @Default("") String statusText,
    String? channelName,
  }) = _PushRegistrationView;

  factory PushRegistrationView.fromJson(Map<String, dynamic> json) => _$PushRegistrationViewFromJson(json);
}

/// Kotlin `PushTestResult`（Push.kt）。
@freezed
abstract class PushTestResult with _$PushTestResult {
  const factory PushTestResult({
    @Default("") String deviceId,
    @Default("") String deviceName,
    @Default("") String result,
    @Default("") String message,
  }) = _PushTestResult;

  factory PushTestResult.fromJson(Map<String, dynamic> json) => _$PushTestResultFromJson(json);
}

/// Kotlin `PushTestView`（Push.kt）。
@freezed
abstract class PushTestView with _$PushTestView {
  const factory PushTestView({
    @Default(0) int sent,
    @Default([]) List<PushTestResult> results,
  }) = _PushTestView;

  factory PushTestView.fromJson(Map<String, dynamic> json) => _$PushTestViewFromJson(json);
}

/// Kotlin `RecentArrivalUnit`（Subscription.kt）。
@freezed
abstract class RecentArrivalUnit with _$RecentArrivalUnit {
  const factory RecentArrivalUnit({
    @Default(0) int seasonNumber,
    @Default(0) int episodeNumber,
  }) = _RecentArrivalUnit;

  factory RecentArrivalUnit.fromJson(Map<String, dynamic> json) => _$RecentArrivalUnitFromJson(json);
}

/// Kotlin `RecentArrivalView`（Subscription.kt）。
@freezed
abstract class RecentArrivalView with _$RecentArrivalView {
  const factory RecentArrivalView({
    @Default(0) int subscriptionId,
    @Default(MediaBrief()) MediaBrief media,
    @Default(0) int seasonNumber,
    @Default(0) int episodeNumber,
    String? episodeName,
    String? stillUrl,
    @Default([]) List<RecentArrivalUnit> units,
    int? progressPercent,
  }) = _RecentArrivalView;

  factory RecentArrivalView.fromJson(Map<String, dynamic> json) => _$RecentArrivalViewFromJson(json);
}

/// Kotlin `ReelByteRangeView`（Models.kt）。
@freezed
abstract class ReelByteRangeView with _$ReelByteRangeView {
  const factory ReelByteRangeView({
    @Default(0) int offset,
    @Default(0) int length,
    @Default("") String purpose,
  }) = _ReelByteRangeView;

  factory ReelByteRangeView.fromJson(Map<String, dynamic> json) => _$ReelByteRangeViewFromJson(json);
}

/// Kotlin `ReelEpisodeView`（Models.kt）。
@freezed
abstract class ReelEpisodeView with _$ReelEpisodeView {
  const factory ReelEpisodeView({
    @Default(0) int season,
    @Default(0) int episode,
    String? name,
    String? overview,
  }) = _ReelEpisodeView;

  factory ReelEpisodeView.fromJson(Map<String, dynamic> json) => _$ReelEpisodeViewFromJson(json);
}

/// Kotlin `ReelEventBatch`（Reels.kt）。
@freezed
abstract class ReelEventBatch with _$ReelEventBatch {
  const factory ReelEventBatch({
    @Default([]) List<ReelEventView> events,
  }) = _ReelEventBatch;

  factory ReelEventBatch.fromJson(Map<String, dynamic> json) => _$ReelEventBatchFromJson(json);
}

/// Kotlin `ReelEventResult`（Reels.kt）。
@freezed
abstract class ReelEventResult with _$ReelEventResult {
  const factory ReelEventResult({
    @Default(0) int accepted,
  }) = _ReelEventResult;

  factory ReelEventResult.fromJson(Map<String, dynamic> json) => _$ReelEventResultFromJson(json);
}

/// Kotlin `ReelEventView`（Reels.kt）。
@freezed
abstract class ReelEventView with _$ReelEventView {
  const factory ReelEventView({
    @Default('') String reelId,
    @Default('') String kind,
    @Default("seek") String mode,
    int? mediaItemId,
    int? fileId,
    int? positionMs,
    int? watchedMs,
    int? waitMs,
    String? detail,
  }) = _ReelEventView;

  factory ReelEventView.fromJson(Map<String, dynamic> json) => _$ReelEventViewFromJson(json);
}

/// Kotlin `ReelFacetsView`（Reels.kt）。
@freezed
abstract class ReelFacetsView with _$ReelFacetsView {
  const factory ReelFacetsView({
    @Default(0) int total,
    @Default(true) bool filterable,
    @Default([]) List<FacetValue> kinds,
    @Default([]) List<FacetValue> genres,
    @Default([]) List<FacetValue> countries,
    @Default([]) List<FacetValue> decades,
    @Default([]) List<FacetValue> ratings,
    @Default([]) List<FacetValue> runtimes,
    @Default([]) List<FacetValue> watch,
  }) = _ReelFacetsView;

  factory ReelFacetsView.fromJson(Map<String, dynamic> json) => _$ReelFacetsViewFromJson(json);
}

/// Kotlin `ReelFeedView`（Reels.kt）。
@freezed
abstract class ReelFeedView with _$ReelFeedView {
  const factory ReelFeedView({
    @Default(0) int seed,
    @Default(0) int nextOffset,
    @Default(false) bool hasMore,
    @Default([]) List<ReelItemView> items,
  }) = _ReelFeedView;

  factory ReelFeedView.fromJson(Map<String, dynamic> json) => _$ReelFeedViewFromJson(json);
}

/// Kotlin `ReelItemView`（Models.kt）。
@freezed
abstract class ReelItemView with _$ReelItemView {
  const factory ReelItemView({
    @Default("") String id,
    @Default(ReelTitleView()) ReelTitleView title,
    @JsonKey(name: 'cover_url')
    String? coverUrl,
    @Default(ReelSegmentView()) ReelSegmentView segment,
    @Default(ReelPlayView()) ReelPlayView play,
  }) = _ReelItemView;

  factory ReelItemView.fromJson(Map<String, dynamic> json) => _$ReelItemViewFromJson(json);
}

/// Kotlin `ReelPersonView`（Models.kt）。
@freezed
abstract class ReelPersonView with _$ReelPersonView {
  const factory ReelPersonView({
    @Default("") String name,
    @JsonKey(name: 'tmdb_person_id')
    int? tmdbPersonId,
    @JsonKey(name: 'avatar_url')
    String? avatarUrl,
  }) = _ReelPersonView;

  factory ReelPersonView.fromJson(Map<String, dynamic> json) => _$ReelPersonViewFromJson(json);
}

/// Kotlin `ReelPlayView`（Models.kt）。
@freezed
abstract class ReelPlayView with _$ReelPlayView {
  const factory ReelPlayView({
    @Default("") String mode,
    @JsonKey(name: 'stream_url')
    String? streamUrl,
    @JsonKey(name: 'clip_url')
    String? clipUrl,
    @JsonKey(name: 'clip_size_bytes')
    int? clipSizeBytes,
    @JsonKey(name: 'size_bytes')
    int? sizeBytes,
    String? disc,
    @JsonKey(name: 'audio_ordinal')
    int? audioOrdinal,
    ReelSubtitleView? subtitle,
    @Default([]) List<ReelByteRangeView> prefetch,
  }) = _ReelPlayView;

  factory ReelPlayView.fromJson(Map<String, dynamic> json) => _$ReelPlayViewFromJson(json);
}

/// Kotlin `ReelSegmentView`（Models.kt）。
@freezed
abstract class ReelSegmentView with _$ReelSegmentView {
  const factory ReelSegmentView({
    @JsonKey(name: 'file_id')
    @Default(0) int fileId,
    @JsonKey(name: 'start_ms')
    @Default(0) int startMs,
    @JsonKey(name: 'end_ms')
    @Default(0) int endMs,
    @JsonKey(name: 'duration_ms')
    int? durationMs,
    @Default("") String method,
  }) = _ReelSegmentView;

  factory ReelSegmentView.fromJson(Map<String, dynamic> json) => _$ReelSegmentViewFromJson(json);
}

/// Kotlin `ReelSubtitleView`（Models.kt）。
@freezed
abstract class ReelSubtitleView with _$ReelSubtitleView {
  const factory ReelSubtitleView({
    @Default(0) int ordinal,
    String? language,
    String? title,
    String? codec,
    String? url,
    String? format,
  }) = _ReelSubtitleView;

  factory ReelSubtitleView.fromJson(Map<String, dynamic> json) => _$ReelSubtitleViewFromJson(json);
}

/// Kotlin `ReelTitleView`（Models.kt）。
@freezed
abstract class ReelTitleView with _$ReelTitleView {
  const factory ReelTitleView({
    @JsonKey(name: 'media_item_id')
    @Default(0) int mediaItemId,
    @JsonKey(name: 'library_id')
    @Default(0) int libraryId,
    @Default("") String kind,
    @Default("") String name,
    int? year,
    double? rating,
    @JsonKey(name: 'runtime_minutes')
    int? runtimeMinutes,
    @Default([]) List<String> genres,
    String? tagline,
    String? overview,
    @Default(false) bool favorite,
    @Default(false) bool played,
    @JsonKey(name: 'progress_percent')
    int? progressPercent,
    @Default([]) List<ReelPersonView> directors,
    @JsonKey(name: 'poster_url')
    String? posterUrl,
    @JsonKey(name: 'backdrop_url')
    String? backdropUrl,
    @JsonKey(name: 'logo_url')
    String? logoUrl,
    ReelEpisodeView? episode,
  }) = _ReelTitleView;

  factory ReelTitleView.fromJson(Map<String, dynamic> json) => _$ReelTitleViewFromJson(json);
}

/// Kotlin `RefreshActiveView`（Models.kt）。
@freezed
abstract class RefreshActiveView with _$RefreshActiveView {
  const factory RefreshActiveView({
    @JsonKey(name: 'media_item_id')
    @Default(0) int mediaItemId,
    @Default("") String title,
    @Default("") String phase,
  }) = _RefreshActiveView;

  factory RefreshActiveView.fromJson(Map<String, dynamic> json) => _$RefreshActiveViewFromJson(json);
}

/// Kotlin `RegionPreset`（RoutingOptions.kt）。
@freezed
abstract class RegionPreset with _$RegionPreset {
  const factory RegionPreset({
    @Default("") String key,
    @Default("") String label,
    @Default([]) List<String> countries,
  }) = _RegionPreset;

  factory RegionPreset.fromJson(Map<String, dynamic> json) => _$RegionPresetFromJson(json);
}

/// Kotlin `ReidentifyGroupView`（ItemActions.kt）。
@freezed
abstract class ReidentifyGroupView with _$ReidentifyGroupView {
  const factory ReidentifyGroupView({
    @Default("") String key,
    @Default(ReidentifyOutcomeView()) ReidentifyOutcomeView outcome,
    @Default([]) List<int> fileIds,
    @Default(0) int fileCount,
    @Default(0) int totalSizeBytes,
    @Default([]) List<String> sampleNames,
  }) = _ReidentifyGroupView;

  factory ReidentifyGroupView.fromJson(Map<String, dynamic> json) => _$ReidentifyGroupViewFromJson(json);
}

/// Kotlin `ReidentifyOutcomeView`（ItemActions.kt）。
@freezed
abstract class ReidentifyOutcomeView with _$ReidentifyOutcomeView {
  const factory ReidentifyOutcomeView({
    int? mediaItemId,
    int? tmdbId,
    String? title,
    int? year,
    String? posterUrl,
    String? source,
    @Default(false) bool sameAsCurrent,
    String? reason,
    String? code,
    @Default([]) List<UnidentifiedCandidateView> candidates,
  }) = _ReidentifyOutcomeView;

  factory ReidentifyOutcomeView.fromJson(Map<String, dynamic> json) => _$ReidentifyOutcomeViewFromJson(json);
}

/// Kotlin `ReidentifyPreviewView`（ItemActions.kt）。
@freezed
abstract class ReidentifyPreviewView with _$ReidentifyPreviewView {
  const factory ReidentifyPreviewView({
    @Default(ReviewItemView()) ReviewItemView current,
    @Default(true) bool movie,
    @Default([]) List<ReidentifyGroupView> groups,
    @Default(ReidentifyOutcomeView()) ReidentifyOutcomeView outcome,
    @Default(0) int skippedMissing,
    @Default(false) bool pinnedIdentity,
    @Default(false) bool unreachable,
    @Default("") String searchSeed,
  }) = _ReidentifyPreviewView;

  factory ReidentifyPreviewView.fromJson(Map<String, dynamic> json) => _$ReidentifyPreviewViewFromJson(json);
}

/// Kotlin `ReidentifyResultView`（ItemActions.kt）。
@freezed
abstract class ReidentifyResultView with _$ReidentifyResultView {
  const factory ReidentifyResultView({
    @Default(0) int total,
    @Default(0) int identified,
    @Default(0) int unidentified,
    @Default(0) int skippedMissing,
    @Default(0) int keptOnError,
    @Default(false) bool changed,
    int? newMediaItemId,
    String? newTitle,
    @Default(false) bool pinnedIdentity,
    @Default("") String message,
  }) = _ReidentifyResultView;

  factory ReidentifyResultView.fromJson(Map<String, dynamic> json) => _$ReidentifyResultViewFromJson(json);
}

/// Kotlin `RelaxSuggestionView`（Models.kt）。
@freezed
abstract class RelaxSuggestionView with _$RelaxSuggestionView {
  const factory RelaxSuggestionView({
    @Default("") String dim,
    @JsonKey(name: 'dim_label')
    @Default("") String dimLabel,
    @Default("") String value,
    @Default("") String label,
    @Default(0) int count,
  }) = _RelaxSuggestionView;

  factory RelaxSuggestionView.fromJson(Map<String, dynamic> json) => _$RelaxSuggestionViewFromJson(json);
}

/// Kotlin `ResolveCandidateView`（Models.kt）。
@freezed
abstract class ResolveCandidateView with _$ResolveCandidateView {
  const factory ResolveCandidateView({
    @JsonKey(name: 'tmdb_id')
    @Default(0) int tmdbId,
    @JsonKey(name: 'title_ref')
    @Default("") String titleRef,
    @Default("") String title,
    @JsonKey(name: 'original_title')
    @Default("") String originalTitle,
    int? year,
    @JsonKey(name: 'poster_url')
    String? posterUrl,
  }) = _ResolveCandidateView;

  factory ResolveCandidateView.fromJson(Map<String, dynamic> json) => _$ResolveCandidateViewFromJson(json);
}

/// Kotlin `ResourceTimingView`（Models.kt）。
@freezed
abstract class ResourceTimingView with _$ResourceTimingView {
  const factory ResourceTimingView({
    @JsonKey(name: 'site_id')
    @Default("") String siteId,
    @JsonKey(name: 'torrent_id')
    @Default("") String torrentId,
    @JsonKey(name: 'publish_time')
    String? publishTime,
    @JsonKey(name: 'first_seen_at')
    String? firstSeenAt,
    @JsonKey(name: 'submitted_at')
    @Default("") String submittedAt,
    @JsonKey(name: 'publish_to_seen_seconds')
    int? publishToSeenSeconds,
    @JsonKey(name: 'seen_to_submit_seconds')
    int? seenToSubmitSeconds,
    @JsonKey(name: 'publish_to_submit_seconds')
    int? publishToSubmitSeconds,
    @JsonKey(name: 'dry_run')
    @Default(false) bool dryRun,
  }) = _ResourceTimingView;

  factory ResourceTimingView.fromJson(Map<String, dynamic> json) => _$ResourceTimingViewFromJson(json);
}

/// Kotlin `RetentionRequest`（Maintenance.kt）。
@freezed
abstract class RetentionRequest with _$RetentionRequest {
  const factory RetentionRequest({
    @JsonKey(name: 'keep_versions')
    @Default(0) int keepVersions,
  }) = _RetentionRequest;

  factory RetentionRequest.fromJson(Map<String, dynamic> json) => _$RetentionRequestFromJson(json);
}

/// Kotlin `ReviewItemView`（ItemActions.kt）。
@freezed
abstract class ReviewItemView with _$ReviewItemView {
  const factory ReviewItemView({
    @Default(0) int mediaItemId,
    int? tmdbId,
    @Default("") String title,
    int? year,
    String? posterUrl,
  }) = _ReviewItemView;

  factory ReviewItemView.fromJson(Map<String, dynamic> json) => _$ReviewItemViewFromJson(json);
}

/// Kotlin `RollbackOptions`（Maintenance.kt）。
@freezed
abstract class RollbackOptions with _$RollbackOptions {
  const factory RollbackOptions({
    @Default([]) List<RollbackTarget> targets,
    @Default(0) int versionsDirBytes,
    @Default(3) int keepVersions,
  }) = _RollbackOptions;

  factory RollbackOptions.fromJson(Map<String, dynamic> json) => _$RollbackOptionsFromJson(json);
}

/// Kotlin `RollbackRequest`（Maintenance.kt）。
@freezed
abstract class RollbackRequest with _$RollbackRequest {
  const factory RollbackRequest({
    @Default('') String target,
    @JsonKey(name: 'restore_backup')
    @Default(false) bool restoreBackup,
  }) = _RollbackRequest;

  factory RollbackRequest.fromJson(Map<String, dynamic> json) => _$RollbackRequestFromJson(json);
}

/// Kotlin `RollbackTarget`（Maintenance.kt）。
@freezed
abstract class RollbackTarget with _$RollbackTarget {
  const factory RollbackTarget({
    @Default("version") String kind,
    String? version,
    String? changelog,
    String? installedAt,
    int? sizeBytes,
    @Default("unknown") String schemaAction,
    String? backupTakenAt,
  }) = _RollbackTarget;

  factory RollbackTarget.fromJson(Map<String, dynamic> json) => _$RollbackTargetFromJson(json);
}

/// Kotlin `RoutingOptionsView`（RoutingOptions.kt）。
@freezed
abstract class RoutingOptionsView with _$RoutingOptionsView {
  const factory RoutingOptionsView({
    @Default([]) List<GenreOption> movieGenres,
    @Default([]) List<GenreOption> tvGenres,
    @Default([]) List<RegionPreset> regionPresets,
    @Default({}) Map<String, String> countryNames,
  }) = _RoutingOptionsView;

  factory RoutingOptionsView.fromJson(Map<String, dynamic> json) => _$RoutingOptionsViewFromJson(json);
}

/// Kotlin `RuleSetPayload`（Subscription.kt）。
@freezed
abstract class RuleSetPayload with _$RuleSetPayload {
  const factory RuleSetPayload({
    @Default('') String name,
    @Default({}) Map<String, dynamic> spec,
    String? matchRules,
  }) = _RuleSetPayload;

  factory RuleSetPayload.fromJson(Map<String, dynamic> json) => _$RuleSetPayloadFromJson(json);
}

/// Kotlin `RuleSetView`（Subscription.kt）。
@freezed
abstract class RuleSetView with _$RuleSetView {
  const factory RuleSetView({
    @Default(0) int id,
    @Default("") String name,
    @Default(false) bool isDefault,
    @Default(0) int referenceCount,
    Map<String, dynamic>? spec,
    @Default([]) List<Map<String, dynamic>> matchRules,
  }) = _RuleSetView;

  factory RuleSetView.fromJson(Map<String, dynamic> json) => _$RuleSetViewFromJson(json);
}

/// Kotlin `ScanProgressView`（Models.kt）。
@freezed
abstract class ScanProgressView with _$ScanProgressView {
  const factory ScanProgressView({
    @Default("") String phase,
    @Default(0) int processed,
    @Default(0) int total,
  }) = _ScanProgressView;

  factory ScanProgressView.fromJson(Map<String, dynamic> json) => _$ScanProgressViewFromJson(json);
}

/// Kotlin `ScheduledTask`（Maintenance.kt）。
@freezed
abstract class ScheduledTask with _$ScheduledTask {
  const factory ScheduledTask({
    @Default("") String key,
    @Default("") String title,
    @Default("") String description,
    @Default(false) bool enabled,
    @Default("interval") String triggerType,
    int? intervalSeconds,
    String? cronExpr,
    String? lastRunAt,
    String? nextRunAt,
  }) = _ScheduledTask;

  factory ScheduledTask.fromJson(Map<String, dynamic> json) => _$ScheduledTaskFromJson(json);
}

/// Kotlin `ScheduledTaskUpdate`（Maintenance.kt）。
@freezed
abstract class ScheduledTaskUpdate with _$ScheduledTaskUpdate {
  const factory ScheduledTaskUpdate({
    @Default(false) bool enabled,
    @JsonKey(name: 'trigger_type')
    @Default('') String triggerType,
    @JsonKey(name: 'interval_seconds')
    int? intervalSeconds,
    @JsonKey(name: 'cron_expr')
    String? cronExpr,
  }) = _ScheduledTaskUpdate;

  factory ScheduledTaskUpdate.fromJson(Map<String, dynamic> json) => _$ScheduledTaskUpdateFromJson(json);
}

/// Kotlin `ScrapeConfigView`（Agent.kt）。
@freezed
abstract class ScrapeConfigView with _$ScrapeConfigView {
  const factory ScrapeConfigView({
    @Default(ScrapeSetting()) ScrapeSetting setting,
    @Default(ScrapeEffectiveView()) ScrapeEffectiveView effective,
  }) = _ScrapeConfigView;

  factory ScrapeConfigView.fromJson(Map<String, dynamic> json) => _$ScrapeConfigViewFromJson(json);
}

/// Kotlin `ScrapeCountryOption`（Agent.kt）。
@freezed
abstract class ScrapeCountryOption with _$ScrapeCountryOption {
  const factory ScrapeCountryOption({
    @Default("") String code,
    @Default("") String name,
  }) = _ScrapeCountryOption;

  factory ScrapeCountryOption.fromJson(Map<String, dynamic> json) => _$ScrapeCountryOptionFromJson(json);
}

/// Kotlin `ScrapeEffectiveView`（Agent.kt）。
@freezed
abstract class ScrapeEffectiveView with _$ScrapeEffectiveView {
  const factory ScrapeEffectiveView({
    @JsonKey(name: 'language_priority')
    @Default([]) List<String> languagePriority,
    @JsonKey(name: 'cert_country_priority')
    @Default([]) List<String> certCountryPriority,
    @JsonKey(name: 'poster_size')
    @Default("") String posterSize,
    @JsonKey(name: 'backdrop_size')
    @Default("") String backdropSize,
    @JsonKey(name: 'still_size')
    @Default("") String stillSize,
    @JsonKey(name: 'profile_size')
    @Default("") String profileSize,
    @JsonKey(name: 'image_quality')
    @Default("") String imageQuality,
  }) = _ScrapeEffectiveView;

  factory ScrapeEffectiveView.fromJson(Map<String, dynamic> json) => _$ScrapeEffectiveViewFromJson(json);
}

/// Kotlin `ScrapeFanartKeyPayload`（Agent.kt）。
@freezed
abstract class ScrapeFanartKeyPayload with _$ScrapeFanartKeyPayload {
  const factory ScrapeFanartKeyPayload({
    @Default("") String key,
  }) = _ScrapeFanartKeyPayload;

  factory ScrapeFanartKeyPayload.fromJson(Map<String, dynamic> json) => _$ScrapeFanartKeyPayloadFromJson(json);
}

/// Kotlin `ScrapeFanartView`（Agent.kt）。
@freezed
abstract class ScrapeFanartView with _$ScrapeFanartView {
  const factory ScrapeFanartView({
    @Default(false) bool configured,
    @JsonKey(name: 'key_invalid')
    @Default(false) bool keyInvalid,
    @JsonKey(name: 'key_hint')
    @Default("") String keyHint,
  }) = _ScrapeFanartView;

  factory ScrapeFanartView.fromJson(Map<String, dynamic> json) => _$ScrapeFanartViewFromJson(json);
}

/// Kotlin `ScrapeLanguageOption`（Agent.kt）。
@freezed
abstract class ScrapeLanguageOption with _$ScrapeLanguageOption {
  const factory ScrapeLanguageOption({
    @Default("") String code,
    @Default("") String name,
    @JsonKey(name: 'english_name')
    @Default("") String englishName,
  }) = _ScrapeLanguageOption;

  factory ScrapeLanguageOption.fromJson(Map<String, dynamic> json) => _$ScrapeLanguageOptionFromJson(json);
}

/// Kotlin `ScrapeSetting`（Agent.kt）。
@freezed
abstract class ScrapeSetting with _$ScrapeSetting {
  const factory ScrapeSetting({
    @JsonKey(name: 'language_priority')
    @Default([]) List<String> languagePriority,
    @JsonKey(name: 'cert_country_priority')
    @Default([]) List<String> certCountryPriority,
    @JsonKey(name: 'poster_mode')
    @Default("language") String posterMode,
    @JsonKey(name: 'poster_language_priority')
    @Default([]) List<String> posterLanguagePriority,
    @JsonKey(name: 'backdrop_language_priority')
    @Default([]) List<String> backdropLanguagePriority,
    @JsonKey(name: 'logo_language_priority')
    List<String>? logoLanguagePriority,
    @JsonKey(name: 'poster_min_width')
    @Default(0) int posterMinWidth,
    @JsonKey(name: 'backdrop_min_width')
    @Default(0) int backdropMinWidth,
    @JsonKey(name: 'poster_size')
    @Default("original") String posterSize,
    @JsonKey(name: 'backdrop_size')
    @Default("original") String backdropSize,
    @JsonKey(name: 'still_size')
    @Default("original") String stillSize,
    @JsonKey(name: 'profile_size')
    @Default("original") String profileSize,
    @JsonKey(name: 'image_quality')
    @Default("original") String imageQuality,
    @JsonKey(name: 'fanart_enabled')
    bool? fanartEnabled,
    @JsonKey(name: 'poster_source_order')
    List<String>? posterSourceOrder,
    @JsonKey(name: 'backdrop_source_order')
    List<String>? backdropSourceOrder,
    @JsonKey(name: 'logo_source_order')
    List<String>? logoSourceOrder,
    @JsonKey(name: 'season_poster_source_order')
    List<String>? seasonPosterSourceOrder,
    @JsonKey(name: 'naming_entry_dir')
    @Default("") String namingEntryDir,
    @JsonKey(name: 'naming_movie_file')
    @Default("") String namingMovieFile,
    @JsonKey(name: 'naming_season_dir')
    @Default("") String namingSeasonDir,
    @JsonKey(name: 'naming_episode_file')
    @Default("") String namingEpisodeFile,
    @JsonKey(name: 'mirror_images')
    @Default(false) bool mirrorImages,
    @JsonKey(name: 'mirror_nfo')
    @Default(false) bool mirrorNfo,
    @JsonKey(name: 'mirror_episode_thumbs')
    @Default(false) bool mirrorEpisodeThumbs,
  }) = _ScrapeSetting;

  factory ScrapeSetting.fromJson(Map<String, dynamic> json) => _$ScrapeSettingFromJson(json);
}

/// Kotlin `ScrapeStorageEstimate`（Agent.kt）。
@freezed
abstract class ScrapeStorageEstimate with _$ScrapeStorageEstimate {
  const factory ScrapeStorageEstimate({
    @JsonKey(name: 'current_quality')
    @Default("") String currentQuality,
    @JsonKey(name: 'current_bytes')
    @Default(0) int currentBytes,
    @Default({}) Map<String, int> presets,
  }) = _ScrapeStorageEstimate;

  factory ScrapeStorageEstimate.fromJson(Map<String, dynamic> json) => _$ScrapeStorageEstimateFromJson(json);
}

/// Kotlin `ScrimUiPrefs`（Models.kt）。
@freezed
abstract class ScrimUiPrefs with _$ScrimUiPrefs {
  const factory ScrimUiPrefs({
    @Default(0.0) double blur,
    @Default(0.0) double dark,
  }) = _ScrimUiPrefs;

  factory ScrimUiPrefs.fromJson(Map<String, dynamic> json) => _$ScrimUiPrefsFromJson(json);
}

/// Kotlin `SearchHistoryItem`（Search.kt）。
@freezed
abstract class SearchHistoryItem with _$SearchHistoryItem {
  const factory SearchHistoryItem({
    @Default(0) int id,
    @Default("") String keyword,
    @Default("torrents") String vertical,
    String? label,
    @Default([]) List<String> categories,
    @Default([]) List<String> siteIds,
    @Default(0) int searchCount,
    String? lastSearchedAt,
    @Default(false) bool hasSnapshot,
  }) = _SearchHistoryItem;

  factory SearchHistoryItem.fromJson(Map<String, dynamic> json) => _$SearchHistoryItemFromJson(json);
}

/// Kotlin `SearchPresetsPayload`（SearchPresets.kt）。
@freezed
abstract class SearchPresetsPayload with _$SearchPresetsPayload {
  const factory SearchPresetsPayload({
    @Default([]) List<Map<String, dynamic>> presets,
  }) = _SearchPresetsPayload;

  factory SearchPresetsPayload.fromJson(Map<String, dynamic> json) => _$SearchPresetsPayloadFromJson(json);
}

/// Kotlin `SearchPresetsView`（SearchPresets.kt）。
@freezed
abstract class SearchPresetsView with _$SearchPresetsView {
  const factory SearchPresetsView({
    @Default([]) List<SearchTabView> presets,
  }) = _SearchPresetsView;

  factory SearchPresetsView.fromJson(Map<String, dynamic> json) => _$SearchPresetsViewFromJson(json);
}

/// Kotlin `SearchTabView`（SearchPresets.kt）。
@freezed
abstract class SearchTabView with _$SearchTabView {
  const factory SearchTabView({
    @Default("category") String type,
    @Default("") String id,
    @Default(true) bool visible,
    String? name,
    @Default([]) List<String> categories,
    @Default([]) List<String> siteIds,
    @Default(false) bool posterMode,
    @Default(false) bool skipHistory,
  }) = _SearchTabView;

  factory SearchTabView.fromJson(Map<String, dynamic> json) => _$SearchTabViewFromJson(json);
}

/// Kotlin `SeasonAirScheduleView`（Models.kt）。
@freezed
abstract class SeasonAirScheduleView with _$SeasonAirScheduleView {
  const factory SeasonAirScheduleView({
    @Default("") String today,
    String? region,
    @Default([]) List<int> weekdays,
    @JsonKey(name: 'last_air_date')
    String? lastAirDate,
    @JsonKey(name: 'subscription_id')
    int? subscriptionId,
    @JsonKey(name: 'missing_episodes')
    @Default([]) List<int> missingEpisodes,
    @Default([]) List<EpisodeArrivalView> arrivals,
  }) = _SeasonAirScheduleView;

  factory SeasonAirScheduleView.fromJson(Map<String, dynamic> json) => _$SeasonAirScheduleViewFromJson(json);
}

/// Kotlin `SeasonEpisodesView`（Models.kt）。
@freezed
abstract class SeasonEpisodesView with _$SeasonEpisodesView {
  const factory SeasonEpisodesView({
    @JsonKey(name: 'season_number')
    @Default(0) int seasonNumber,
    @Default([]) List<EpisodeView> episodes,
    @JsonKey(name: 'resume_episode')
    int? resumeEpisode,
    @JsonKey(name: 'air_schedule')
    SeasonAirScheduleView? airSchedule,
  }) = _SeasonEpisodesView;

  factory SeasonEpisodesView.fromJson(Map<String, dynamic> json) => _$SeasonEpisodesViewFromJson(json);
}

/// Kotlin `SeasonOverview`（Models.kt）。
@freezed
abstract class SeasonOverview with _$SeasonOverview {
  const factory SeasonOverview({
    @JsonKey(name: 'season_number')
    @Default(0) int seasonNumber,
    @Default("") String name,
    @JsonKey(name: 'air_date')
    String? airDate,
    @JsonKey(name: 'episode_count')
    int? episodeCount,
    @JsonKey(name: 'aired_count')
    @Default(0) int airedCount,
    @JsonKey(name: 'owned_count')
    @Default(0) int ownedCount,
  }) = _SeasonOverview;

  factory SeasonOverview.fromJson(Map<String, dynamic> json) => _$SeasonOverviewFromJson(json);
}

/// Kotlin `SeriesPartView`（Models.kt）。
@freezed
abstract class SeriesPartView with _$SeriesPartView {
  const factory SeriesPartView({
    @JsonKey(name: 'tmdb_id')
    @Default(0) int tmdbId,
    @Default("") String title,
    @JsonKey(name: 'release_date')
    String? releaseDate,
    @JsonKey(name: 'poster_url')
    String? posterUrl,
    @JsonKey(name: 'media_item_id')
    int? mediaItemId,
    @Default(false) bool subscribed,
  }) = _SeriesPartView;

  factory SeriesPartView.fromJson(Map<String, dynamic> json) => _$SeriesPartViewFromJson(json);
}

/// Kotlin `ServerAddressItem`（ServerAddressesModels.kt）。
@freezed
abstract class ServerAddressItem with _$ServerAddressItem {
  const factory ServerAddressItem({
    @Default('') String url,
    @Default('') String kind,
    @Default('') String source,
    @JsonKey(name: 'last_seen')
    String? lastSeen,
  }) = _ServerAddressItem;

  factory ServerAddressItem.fromJson(Map<String, dynamic> json) => _$ServerAddressItemFromJson(json);
}

/// Kotlin `ServerAddressesView`（ServerAddressesModels.kt）。
@freezed
abstract class ServerAddressesView with _$ServerAddressesView {
  const factory ServerAddressesView({
    @JsonKey(name: 'instance_id')
    @Default("") String instanceId,
    @JsonKey(name: 'host_key')
    @Default("") String hostKey,
    @Default([]) List<ServerAddressItem> addresses,
    @JsonKey(name: 'lan_subnets')
    @Default([]) List<String> lanSubnets,
  }) = _ServerAddressesView;

  factory ServerAddressesView.fromJson(Map<String, dynamic> json) => _$ServerAddressesViewFromJson(json);
}

/// Kotlin `SessionAccepted`（Agent.kt）。
@freezed
abstract class SessionAccepted with _$SessionAccepted {
  const factory SessionAccepted({
    @Default('') String sessionId,
    @Default("") String messageId,
  }) = _SessionAccepted;

  factory SessionAccepted.fromJson(Map<String, dynamic> json) => _$SessionAcceptedFromJson(json);
}

/// Kotlin `SessionCapabilities`（Models.kt）。
@freezed
abstract class SessionCapabilities with _$SessionCapabilities {
  const factory SessionCapabilities({
    @JsonKey(name: 'allow_subscribe')
    @Default(false) bool allowSubscribe,
    @JsonKey(name: 'allow_search')
    @Default(false) bool allowSearch,
    @JsonKey(name: 'allow_direct_download')
    @Default(false) bool allowDirectDownload,
    @JsonKey(name: 'allow_video_download')
    bool? allowVideoDownload,
  }) = _SessionCapabilities;

  factory SessionCapabilities.fromJson(Map<String, dynamic> json) => _$SessionCapabilitiesFromJson(json);
}

/// Kotlin `SessionMessage`（Agent.kt）。
@freezed
abstract class SessionMessage with _$SessionMessage {
  const factory SessionMessage({
    @Default("user") String role,
    dynamic content,
    List<ToolCallInfo>? toolCalls,
    String? toolCallId,
    String? name,
  }) = _SessionMessage;

  factory SessionMessage.fromJson(Map<String, dynamic> json) => _$SessionMessageFromJson(json);
}

/// Kotlin `SessionRename`（Agent.kt）。
@freezed
abstract class SessionRename with _$SessionRename {
  const factory SessionRename({
    @Default('') String title,
  }) = _SessionRename;

  factory SessionRename.fromJson(Map<String, dynamic> json) => _$SessionRenameFromJson(json);
}

/// Kotlin `SessionRetry`（Agent.kt）。
@freezed
abstract class SessionRetry with _$SessionRetry {
  const factory SessionRetry({
    String? messageId,
    String? content,
  }) = _SessionRetry;

  factory SessionRetry.fromJson(Map<String, dynamic> json) => _$SessionRetryFromJson(json);
}

/// Kotlin `SessionSummary`（Agent.kt）。
@freezed
abstract class SessionSummary with _$SessionSummary {
  const factory SessionSummary({
    @Default('') String id,
    String? title,
    String? lastPrompt,
    @Default(0) int entryCount,
    @Default(false) bool running,
    String? createdAt,
    String? updatedAt,
  }) = _SessionSummary;

  factory SessionSummary.fromJson(Map<String, dynamic> json) => _$SessionSummaryFromJson(json);
}

/// Kotlin `SessionTranscript`（Agent.kt）。
@freezed
abstract class SessionTranscript with _$SessionTranscript {
  const factory SessionTranscript({
    @Default(SessionSummary()) SessionSummary session,
    @Default([]) List<TranscriptEntry> entries,
  }) = _SessionTranscript;

  factory SessionTranscript.fromJson(Map<String, dynamic> json) => _$SessionTranscriptFromJson(json);
}

/// Kotlin `SessionView`（Models.kt）。
@freezed
abstract class SessionView with _$SessionView {
  const factory SessionView({
    @Default("") String username,
    @Default("") String nickname,
    @JsonKey(name: 'avatar_url')
    String? avatarUrl,
    @Default("") String role,
    @Default(SessionCapabilities()) SessionCapabilities capabilities,
    DeviceBrief? device,
  }) = _SessionView;

  factory SessionView.fromJson(Map<String, dynamic> json) => _$SessionViewFromJson(json);
}

/// Kotlin `ShareCreateRequest`（Share.kt）。
@freezed
abstract class ShareCreateRequest with _$ShareCreateRequest {
  const factory ShareCreateRequest({
    @Default(7) int expiresInDays,
    String? password,
  }) = _ShareCreateRequest;

  factory ShareCreateRequest.fromJson(Map<String, dynamic> json) => _$ShareCreateRequestFromJson(json);
}

/// Kotlin `SharePublic`（Share.kt）。
@freezed
abstract class SharePublic with _$SharePublic {
  const factory SharePublic({
    @Default(false) bool requiresPassword,
    @Default(false) bool unlocked,
    String? expiresAt,
    int? mediaItemId,
    int? collectionId,
  }) = _SharePublic;

  factory SharePublic.fromJson(Map<String, dynamic> json) => _$SharePublicFromJson(json);
}

/// Kotlin `ShareRevokedView`（Share.kt）。
@freezed
abstract class ShareRevokedView with _$ShareRevokedView {
  const factory ShareRevokedView({
    @Default(false) bool revoked,
  }) = _ShareRevokedView;

  factory ShareRevokedView.fromJson(Map<String, dynamic> json) => _$ShareRevokedViewFromJson(json);
}

/// Kotlin `ShareUnlockRequest`（Share.kt）。
@freezed
abstract class ShareUnlockRequest with _$ShareUnlockRequest {
  const factory ShareUnlockRequest({
    @Default('') String password,
  }) = _ShareUnlockRequest;

  factory ShareUnlockRequest.fromJson(Map<String, dynamic> json) => _$ShareUnlockRequestFromJson(json);
}

/// Kotlin `ShareView`（Share.kt）。
@freezed
abstract class ShareView with _$ShareView {
  const factory ShareView({
    @Default(0) int id,
    @Default("") String slug,
    @Default("") String url,
    int? mediaItemId,
    int? collectionId,
    int? libraryId,
    @Default("") String title,
    String? kind,
    int? year,
    String? posterUrl,
    int? itemCount,
    String? password,
    String? expiresAt,
    String? createdAt,
    @Default(0) int viewCount,
    String? lastAccessedAt,
  }) = _ShareView;

  factory ShareView.fromJson(Map<String, dynamic> json) => _$ShareViewFromJson(json);
}

/// Kotlin `SharedCollection`（Share.kt）。
@freezed
abstract class SharedCollection with _$SharedCollection {
  const factory SharedCollection({
    int? id,
    @Default("") String name,
    String? description,
    @Default([]) List<SharedCollectionItem> items,
    String? expiresAt,
  }) = _SharedCollection;

  factory SharedCollection.fromJson(Map<String, dynamic> json) => _$SharedCollectionFromJson(json);
}

/// Kotlin `SharedCollectionItem`（Share.kt）。
@freezed
abstract class SharedCollectionItem with _$SharedCollectionItem {
  const factory SharedCollectionItem({
    @Default(0) int mediaItemId,
    @Default("") String title,
    int? year,
    @Default("movie") String kind,
    String? posterUrl,
  }) = _SharedCollectionItem;

  factory SharedCollectionItem.fromJson(Map<String, dynamic> json) => _$SharedCollectionItemFromJson(json);
}

/// Kotlin `SharedFile`（Share.kt）。
@freezed
abstract class SharedFile with _$SharedFile {
  const factory SharedFile({
    @Default(0) int id,
    @Default(0) int sizeBytes,
    String? container,
    String? resolution,
    String? videoCodec,
    String? hdr,
    @Default(0) int seasonNumber,
    @Default(0) int episodeNumber,
  }) = _SharedFile;

  factory SharedFile.fromJson(Map<String, dynamic> json) => _$SharedFileFromJson(json);
}

/// Kotlin `SharedItem`（Share.kt）。
@freezed
abstract class SharedItem with _$SharedItem {
  const factory SharedItem({
    @Default(0) int mediaItemId,
    @Default("movie") String kind,
    @Default("") String title,
    String? originalTitle,
    int? year,
    String? posterUrl,
    String? backdropUrl,
    @Default(0.6667) double primaryAspect,
    LocalMetaView? localMeta,
    @Default([]) List<SharedFile> files,
    @Default([]) List<int> seasons,
    String? expiresAt,
  }) = _SharedItem;

  factory SharedItem.fromJson(Map<String, dynamic> json) => _$SharedItemFromJson(json);
}

/// Kotlin `SidebarUiPrefs`（Models.kt）。
@freezed
abstract class SidebarUiPrefs with _$SidebarUiPrefs {
  const factory SidebarUiPrefs({
    @Default(0.0) double transparency,
    @Default(0.0) double brightness,
    @Default(0.0) double depth,
  }) = _SidebarUiPrefs;

  factory SidebarUiPrefs.fromJson(Map<String, dynamic> json) => _$SidebarUiPrefsFromJson(json);
}

/// Kotlin `SiteBoostPayload`（SiteAdmin.kt）。
@freezed
abstract class SiteBoostPayload with _$SiteBoostPayload {
  const factory SiteBoostPayload({
    @Default(false) bool enabled,
    int? budgetBytes,
    int? holdDays,
    int? downloaderId,
  }) = _SiteBoostPayload;

  factory SiteBoostPayload.fromJson(Map<String, dynamic> json) => _$SiteBoostPayloadFromJson(json);
}

/// Kotlin `SiteCatalogItem`（SiteAdmin.kt）。
@freezed
abstract class SiteCatalogItem with _$SiteCatalogItem {
  const factory SiteCatalogItem({
    @Default("") String siteId,
    @Default("") String displayName,
    String? baseUrl,
    @Default([]) List<AuthTypeRequirement> supportedAuthTypes,
  }) = _SiteCatalogItem;

  factory SiteCatalogItem.fromJson(Map<String, dynamic> json) => _$SiteCatalogItemFromJson(json);
}

/// Kotlin `SiteConfigCreate`（SiteAdmin.kt）。
@freezed
abstract class SiteConfigCreate with _$SiteConfigCreate {
  const factory SiteConfigCreate({
    @Default('') String siteId,
    @Default('') String authType,
    String? cookie,
    String? apiKey,
    String? username,
    String? password,
    @Default(true) bool enabled,
  }) = _SiteConfigCreate;

  factory SiteConfigCreate.fromJson(Map<String, dynamic> json) => _$SiteConfigCreateFromJson(json);
}

/// Kotlin `SiteConfigUpdate`（SiteAdmin.kt）。
@freezed
abstract class SiteConfigUpdate with _$SiteConfigUpdate {
  const factory SiteConfigUpdate({
    @Default('') String authType,
    String? cookie,
    String? apiKey,
    String? username,
    String? password,
    @Default(true) bool enabled,
  }) = _SiteConfigUpdate;

  factory SiteConfigUpdate.fromJson(Map<String, dynamic> json) => _$SiteConfigUpdateFromJson(json);
}

/// Kotlin `SiteEnabledPayload`（SiteAdmin.kt）。
@freezed
abstract class SiteEnabledPayload with _$SiteEnabledPayload {
  const factory SiteEnabledPayload({
    @Default(false) bool enabled,
  }) = _SiteEnabledPayload;

  factory SiteEnabledPayload.fromJson(Map<String, dynamic> json) => _$SiteEnabledPayloadFromJson(json);
}

/// Kotlin `SitePausePayload`（SiteAdmin.kt）。
@freezed
abstract class SitePausePayload with _$SitePausePayload {
  const factory SitePausePayload({
    @Default(false) bool paused,
  }) = _SitePausePayload;

  factory SitePausePayload.fromJson(Map<String, dynamic> json) => _$SitePausePayloadFromJson(json);
}

/// Kotlin `SiteProfile`（SiteAdmin.kt）。
@freezed
abstract class SiteProfile with _$SiteProfile {
  const factory SiteProfile({
    String? username,
    String? userClass,
    @Default(0) int uploadedBytes,
    @Default(0) int downloadedBytes,
    double? ratio,
    double? bonus,
    @Default(0) int seedingCount,
    @Default(0) int leechingCount,
    String? fetchedAt,
  }) = _SiteProfile;

  factory SiteProfile.fromJson(Map<String, dynamic> json) => _$SiteProfileFromJson(json);
}

/// Kotlin `SiteProtectedPayload`（SiteAdmin.kt）。
@freezed
abstract class SiteProtectedPayload with _$SiteProtectedPayload {
  const factory SiteProtectedPayload({
    @JsonKey(name: 'protected')
    @Default(false) bool isProtected,
  }) = _SiteProtectedPayload;

  factory SiteProtectedPayload.fromJson(Map<String, dynamic> json) => _$SiteProtectedPayloadFromJson(json);
}

/// Kotlin `SkillView`（Agent.kt）。
@freezed
abstract class SkillView with _$SkillView {
  const factory SkillView({
    @Default("") String name,
    String? description,
    String? scope,
  }) = _SkillView;

  factory SkillView.fromJson(Map<String, dynamic> json) => _$SkillViewFromJson(json);
}

/// Kotlin `SmartDefaultsPayload`（Subscription.kt）。
@freezed
abstract class SmartDefaultsPayload with _$SmartDefaultsPayload {
  const factory SmartDefaultsPayload({
    @Default(0) int movieRevision,
    @Default(0) int tvRevision,
    @Default('') String resolution,
    @Default('') String source,
    @Default(false) bool allowUpgrade,
    @Default(false) bool strictResolution,
    @Default(0) int movieWaitSeconds,
    @Default(0) int tvWaitSeconds,
  }) = _SmartDefaultsPayload;

  factory SmartDefaultsPayload.fromJson(Map<String, dynamic> json) => _$SmartDefaultsPayloadFromJson(json);
}

/// Kotlin `SmartDefaultsView`（Subscription.kt）。
@freezed
abstract class SmartDefaultsView with _$SmartDefaultsView {
  const factory SmartDefaultsView({
    @Default(false) bool configured,
    @Default(0) int movieRevision,
    @Default(0) int tvRevision,
    @Default("2160p") String resolution,
    @Default("web-dl") String source,
    @Default(true) bool allowUpgrade,
    @Default(false) bool strictResolution,
    @Default(86400) int movieWaitSeconds,
    @Default(10800) int tvWaitSeconds,
  }) = _SmartDefaultsView;

  factory SmartDefaultsView.fromJson(Map<String, dynamic> json) => _$SmartDefaultsViewFromJson(json);
}

/// Kotlin `SmartHabitView`（Subscription.kt）。
@freezed
abstract class SmartHabitView with _$SmartHabitView {
  const factory SmartHabitView({
    @Default("") String key,
    @Default("") String label,
    @Default("") String qualityLabel,
    String? sourceTitle,
  }) = _SmartHabitView;

  factory SmartHabitView.fromJson(Map<String, dynamic> json) => _$SmartHabitViewFromJson(json);
}

/// Kotlin `SmartLanguageOptionView`（Subscription.kt）。
@freezed
abstract class SmartLanguageOptionView with _$SmartLanguageOptionView {
  const factory SmartLanguageOptionView({
    @Default("") String key,
    @Default("") String label,
  }) = _SmartLanguageOptionView;

  factory SmartLanguageOptionView.fromJson(Map<String, dynamic> json) => _$SmartLanguageOptionViewFromJson(json);
}

/// Kotlin `SmartLanguageView`（Subscription.kt）。
@freezed
abstract class SmartLanguageView with _$SmartLanguageView {
  const factory SmartLanguageView({
    @Default("") String key,
    @Default("") String label,
    String? sourceTitle,
    @Default(true) bool removable,
  }) = _SmartLanguageView;

  factory SmartLanguageView.fromJson(Map<String, dynamic> json) => _$SmartLanguageViewFromJson(json);
}

/// Kotlin `SmartMemoryPatch`（Subscription.kt）。
@freezed
abstract class SmartMemoryPatch with _$SmartMemoryPatch {
  const factory SmartMemoryPatch({
    @Default(0) int revision,
    String? language,
    bool? understood,
    String? removeHabit,
  }) = _SmartMemoryPatch;

  factory SmartMemoryPatch.fromJson(Map<String, dynamic> json) => _$SmartMemoryPatchFromJson(json);
}

/// Kotlin `SmartMemoryView`（Subscription.kt）。
@freezed
abstract class SmartMemoryView with _$SmartMemoryView {
  const factory SmartMemoryView({
    @Default(0) int revision,
    @Default([]) List<SmartLanguageView> languages,
    @Default([]) List<SmartLanguageOptionView> addableLanguages,
    @Default([]) List<SmartHabitView> habits,
  }) = _SmartMemoryView;

  factory SmartMemoryView.fromJson(Map<String, dynamic> json) => _$SmartMemoryViewFromJson(json);
}

/// Kotlin `SmartPlanView`（Models.kt）。
@freezed
abstract class SmartPlanView with _$SmartPlanView {
  const factory SmartPlanView({
    @Default(false) bool configured,
    @JsonKey(name: 'profile_revision')
    @Default(0) int profileRevision,
    @JsonKey(name: 'memory_revision')
    @Default(0) int memoryRevision,
    String? resolution,
    String? source,
    @JsonKey(name: 'quality_label')
    String? qualityLabel,
    @JsonKey(name: 'quality_note')
    String? qualityNote,
    @JsonKey(name: 'quality_shadow')
    String? qualityShadow,
    @JsonKey(name: 'wait_label')
    String? waitLabel,
    @JsonKey(name: 'subtitle_language')
    String? subtitleLanguage,
    @JsonKey(name: 'subtitle_language_label')
    String? subtitleLanguageLabel,
    @JsonKey(name: 'subtitle_understood')
    bool? subtitleUnderstood,
    @JsonKey(name: 'subtitle_line')
    String? subtitleLine,
    SmartQuestionView? question,
    @JsonKey(name: 'subtitle_edit_question')
    SmartQuestionView? subtitleEditQuestion,
    @JsonKey(name: 'scope_options')
    @Default([]) List<SmartScopeOptionView> scopeOptions,
    @JsonKey(name: 'can_edit')
    @Default(false) bool canEdit,
  }) = _SmartPlanView;

  factory SmartPlanView.fromJson(Map<String, dynamic> json) => _$SmartPlanViewFromJson(json);
}

/// Kotlin `SmartPreferences`（Subscription.kt）。
@freezed
abstract class SmartPreferences with _$SmartPreferences {
  const factory SmartPreferences({
    @Default("2160p") String resolution,
    @Default("web-dl") String source,
    @Default(7200) int waitSeconds,
    @Default(true) bool allowUpgrade,
    @Default(false) bool strictResolution,
  }) = _SmartPreferences;

  factory SmartPreferences.fromJson(Map<String, dynamic> json) => _$SmartPreferencesFromJson(json);
}

/// Kotlin `SmartProfilePayload`（Subscription.kt）。
@freezed
abstract class SmartProfilePayload with _$SmartProfilePayload {
  const factory SmartProfilePayload({
    @Default(0) int revision,
    @Default(SmartPreferences()) SmartPreferences preferences,
  }) = _SmartProfilePayload;

  factory SmartProfilePayload.fromJson(Map<String, dynamic> json) => _$SmartProfilePayloadFromJson(json);
}

/// Kotlin `SmartProfileView`（Subscription.kt）。
@freezed
abstract class SmartProfileView with _$SmartProfileView {
  const factory SmartProfileView({
    @Default("movie") String kind,
    @Default(0) int revision,
    SmartPreferences? preferences,
  }) = _SmartProfileView;

  factory SmartProfileView.fromJson(Map<String, dynamic> json) => _$SmartProfileViewFromJson(json);
}

/// Kotlin `SmartQuestionView`（Models.kt）。
@freezed
abstract class SmartQuestionView with _$SmartQuestionView {
  const factory SmartQuestionView({
    @Default("") String language,
    @Default("") String prompt,
    @JsonKey(name: 'subtitles_label')
    @Default("") String subtitlesLabel,
    @JsonKey(name: 'understood_label')
    @Default("") String understoodLabel,
  }) = _SmartQuestionView;

  factory SmartQuestionView.fromJson(Map<String, dynamic> json) => _$SmartQuestionViewFromJson(json);
}

/// Kotlin `SmartScopeOptionView`（Models.kt）。
@freezed
abstract class SmartScopeOptionView with _$SmartScopeOptionView {
  const factory SmartScopeOptionView({
    @Default("") String value,
    @Default("") String label,
  }) = _SmartScopeOptionView;

  factory SmartScopeOptionView.fromJson(Map<String, dynamic> json) => _$SmartScopeOptionViewFromJson(json);
}

/// Kotlin `SmartSubtitleView`（Models.kt）。
@freezed
abstract class SmartSubtitleView with _$SmartSubtitleView {
  const factory SmartSubtitleView({
    @Default("") String language,
    @JsonKey(name: 'language_label')
    @Default("") String languageLabel,
    @Default("") String line,
    @Default(false) bool understood,
  }) = _SmartSubtitleView;

  factory SmartSubtitleView.fromJson(Map<String, dynamic> json) => _$SmartSubtitleViewFromJson(json);
}

/// Kotlin `SmartWaitPayload`（Subscription.kt）。
@freezed
abstract class SmartWaitPayload with _$SmartWaitPayload {
  const factory SmartWaitPayload({
    @Default(0) int version,
    int? extendSeconds,
    String? candidateKey,
  }) = _SmartWaitPayload;

  factory SmartWaitPayload.fromJson(Map<String, dynamic> json) => _$SmartWaitPayloadFromJson(json);
}

/// Kotlin `StorageDir`（Maintenance.kt）。
@freezed
abstract class StorageDir with _$StorageDir {
  const factory StorageDir({
    @Default("") String key,
    @Default("") String title,
    @Default("") String summary,
    @Default("") String description,
    @Default("") String path,
    @Default("data") String group,
    @Default("none") String rebuildCost,
    @Default(false) bool clearable,
    @Default(false) bool orphanAware,
    @Default(true) bool exists,
  }) = _StorageDir;

  factory StorageDir.fromJson(Map<String, dynamic> json) => _$StorageDirFromJson(json);
}

/// Kotlin `StorageState`（Maintenance.kt）。
@freezed
abstract class StorageState with _$StorageState {
  const factory StorageState({
    StorageUsage? usage,
    @Default(false) bool computing,
    String? error,
  }) = _StorageState;

  factory StorageState.fromJson(Map<String, dynamic> json) => _$StorageStateFromJson(json);
}

/// Kotlin `StorageUsage`（Maintenance.kt）。
@freezed
abstract class StorageUsage with _$StorageUsage {
  const factory StorageUsage({
    @Default("") String dataRoot,
    @Default(0) int diskTotal,
    @Default(0) int diskUsed,
    @Default(0) int diskFree,
    @Default(0) int cacheBytes,
    @Default(0) int dataBytes,
    @Default([]) List<StorageDir> dirs,
    @Default(0) int computedAt,
  }) = _StorageUsage;

  factory StorageUsage.fromJson(Map<String, dynamic> json) => _$StorageUsageFromJson(json);
}

/// Kotlin `SubActivityView`（Subscription.kt）。
@freezed
abstract class SubActivityView with _$SubActivityView {
  const factory SubActivityView({
    @Default(0) int id,
    @Default("") String type,
    @Default("") String message,
    String? createdAt,
  }) = _SubActivityView;

  factory SubActivityView.fromJson(Map<String, dynamic> json) => _$SubActivityViewFromJson(json);
}

/// Kotlin `SubscriptionCreateRequest`（Subscription.kt）。
@freezed
abstract class SubscriptionCreateRequest with _$SubscriptionCreateRequest {
  const factory SubscriptionCreateRequest({
    @Default('') String titleRef,
    String? sourceTitleRef,
    @Default([]) List<int> selectedSeasons,
    @Default(false) bool followFuture,
    int? ruleSetId,
    int? libraryId,
    String? selectionMode,
    int? smartProfileRevision,
    String? smartLanguageAnswer,
    String? smartResolution,
    String? smartSource,
    String? smartScope,
    int? smartMemoryRevision,
  }) = _SubscriptionCreateRequest;

  factory SubscriptionCreateRequest.fromJson(Map<String, dynamic> json) => _$SubscriptionCreateRequestFromJson(json);
}

/// Kotlin `SubscriptionCreateView`（Models.kt）。
@freezed
abstract class SubscriptionCreateView with _$SubscriptionCreateView {
  const factory SubscriptionCreateView({
    @Default(SubscriptionDetailView()) SubscriptionDetailView subscription,
    @JsonKey(name: 'download_routing')
    DispatchPreviewView? downloadRouting,
  }) = _SubscriptionCreateView;

  factory SubscriptionCreateView.fromJson(Map<String, dynamic> json) => _$SubscriptionCreateViewFromJson(json);
}

/// Kotlin `SubscriptionDetailView`（Models.kt）。
@freezed
abstract class SubscriptionDetailView with _$SubscriptionDetailView {
  const factory SubscriptionDetailView({
    @Default(0) int id,
    @Default(MediaBrief()) MediaBrief media,
    @Default("") String status,
    @JsonKey(name: 'selected_seasons')
    @Default([]) List<int> selectedSeasons,
    @JsonKey(name: 'follow_future')
    @Default(false) bool followFuture,
    @JsonKey(name: 'rule_set_id')
    @Default(0) int ruleSetId,
    @JsonKey(name: 'selection_mode')
    @Default("") String selectionMode,
    @JsonKey(name: 'smart_policy')
    Map<String, dynamic>? smartPolicy,
    @JsonKey(name: 'smart_status')
    String? smartStatus,
    @JsonKey(name: 'library_id')
    int? libraryId,
    @Default(ProgressView()) ProgressView progress,
    @JsonKey(name: 'season_collection')
    @Default([]) List<SeasonOverview> seasonCollection,
    @JsonKey(name: 'episode_windows')
    List<EpisodeWindowView>? episodeWindows,
    @JsonKey(name: 'created_at')
    @Default("") String createdAt,
    @JsonKey(name: 'updated_at')
    @Default("") String updatedAt,
    @Default([]) List<WantedView> wanted,
    @JsonKey(name: 'episode_seasons')
    List<EpisodeSeasonView>? episodeSeasons,
    @JsonKey(name: 'episode_hints')
    List<EpisodeHintView>? episodeHints,
    @JsonKey(name: 'can_manage')
    @Default(false) bool canManage,
    @JsonKey(name: 'forecast_pending')
    @Default(false) bool forecastPending,
    @JsonKey(name: 'smart_subtitle')
    SmartSubtitleView? smartSubtitle,
    @JsonKey(name: 'smart_quality_note')
    String? smartQualityNote,
  }) = _SubscriptionDetailView;

  factory SubscriptionDetailView.fromJson(Map<String, dynamic> json) => _$SubscriptionDetailViewFromJson(json);
}

/// Kotlin `SubscriptionDownloadView`（Subscription.kt）。
@freezed
abstract class SubscriptionDownloadView with _$SubscriptionDownloadView {
  const factory SubscriptionDownloadView({
    @Default("") String infoHash,
    String? name,
    double? progress,
    int? sizeBytes,
    int? dlspeedBytes,
    int? etaSeconds,
    @Default("unknown") String state,
    String? errorMessage,
    String? downloaderName,
    @Default([]) List<DownloadUnitView> units,
  }) = _SubscriptionDownloadView;

  factory SubscriptionDownloadView.fromJson(Map<String, dynamic> json) => _$SubscriptionDownloadViewFromJson(json);
}

/// Kotlin `SubscriptionView`（Subscription.kt）。
@freezed
abstract class SubscriptionView with _$SubscriptionView {
  const factory SubscriptionView({
    @Default(0) int id,
    @Default(MediaBrief()) MediaBrief media,
    @Default("") String status,
    @Default([]) List<int> selectedSeasons,
    @Default(false) bool followFuture,
    int? ruleSetId,
    int? libraryId,
    @Default(ProgressView()) ProgressView progress,
    @Default([]) List<SeasonOverview> seasonCollection,
    List<EpisodeWindowView>? episodeWindows,
    String? createdAt,
    String? updatedAt,
    @Default([]) List<WantedView> wanted,
    @Default(true) bool canManage,
    @Default(false) bool forecastPending,
    @Default("rules") String selectionMode,
    Map<String, dynamic>? smartPolicy,
    String? smartStatus,
    SmartSubtitleView? smartSubtitle,
    String? smartQualityNote,
  }) = _SubscriptionView;

  factory SubscriptionView.fromJson(Map<String, dynamic> json) => _$SubscriptionViewFromJson(json);
}

/// Kotlin `SubtitleGenBlockerView`（SubtitleGen.kt）。
@freezed
abstract class SubtitleGenBlockerView with _$SubtitleGenBlockerView {
  const factory SubtitleGenBlockerView({
    @Default("") String code,
    @Default("") String title,
    @Default("") String message,
    @Default([]) List<String> suggestions,
  }) = _SubtitleGenBlockerView;

  factory SubtitleGenBlockerView.fromJson(Map<String, dynamic> json) => _$SubtitleGenBlockerViewFromJson(json);
}

/// Kotlin `SubtitleGenCandidateView`（SubtitleGen.kt）。
@freezed
abstract class SubtitleGenCandidateView with _$SubtitleGenCandidateView {
  const factory SubtitleGenCandidateView({
    @Default("") String kind,
    @Default("") String key,
    String? language,
    String? format,
    @Default("original") String provenance,
    String? excluded,
    @Default([]) List<String> reasons,
    @Default(true) bool selectable,
    @Default(false) bool requiresOcr,
  }) = _SubtitleGenCandidateView;

  factory SubtitleGenCandidateView.fromJson(Map<String, dynamic> json) => _$SubtitleGenCandidateViewFromJson(json);
}

/// Kotlin `SubtitleGenPreviewView`（SubtitleGen.kt）。
@freezed
abstract class SubtitleGenPreviewView with _$SubtitleGenPreviewView {
  const factory SubtitleGenPreviewView({
    @Default([]) List<SubtitleGenCandidateView> candidates,
    String? chosenKey,
    String? selectedSourceKey,
    @Default(0) int eventCount,
    @Default(0) int estimatedTokens,
    @Default(false) bool alreadyGenerated,
    @Default([]) List<String> warnings,
    PgsConversionView? pgsConversion,
    SubtitleGenBlockerView? blocker,
    String? outputFilename,
    String? referenceNotice,
    PendingView? pending,
  }) = _SubtitleGenPreviewView;

  factory SubtitleGenPreviewView.fromJson(Map<String, dynamic> json) => _$SubtitleGenPreviewViewFromJson(json);
}

/// Kotlin `SubtitleGenStartPayload`（SubtitleGen.kt）。
@freezed
abstract class SubtitleGenStartPayload with _$SubtitleGenStartPayload {
  const factory SubtitleGenStartPayload({
    @Default("chs") String targetLanguage,
    String? secondaryLanguage,
    String? sourceCandidateKey,
    @Default(false) bool convertPgs,
    String? pgsOcrLanguage,
  }) = _SubtitleGenStartPayload;

  factory SubtitleGenStartPayload.fromJson(Map<String, dynamic> json) => _$SubtitleGenStartPayloadFromJson(json);
}

/// Kotlin `SubtitlePlanView`（Models.kt）。
@freezed
abstract class SubtitlePlanView with _$SubtitlePlanView {
  const factory SubtitlePlanView({
    @JsonKey(name: 'track_ref')
    @Default("") String trackRef,
    @Default("") String kind,
    String? language,
    @JsonKey(name: 'is_default')
    @Default(false) bool isDefault,
    @JsonKey(name: 'is_ai')
    @Default(false) bool isAi,
    String? title,
    @JsonKey(name: 'is_forced')
    bool? isForced,
  }) = _SubtitlePlanView;

  factory SubtitlePlanView.fromJson(Map<String, dynamic> json) => _$SubtitlePlanViewFromJson(json);
}

/// Kotlin `SubtitleStreamView`（Models.kt）。
@freezed
abstract class SubtitleStreamView with _$SubtitleStreamView {
  const factory SubtitleStreamView({
    String? codec,
    String? language,
    String? title,
    @Default(false) bool forced,
    @JsonKey(name: 'default')
    @Default(false) bool defaultValue,
    @JsonKey(name: 'external')
    @Default(false) bool externalValue,
    @JsonKey(name: 'file_name')
    String? fileName,
  }) = _SubtitleStreamView;

  factory SubtitleStreamView.fromJson(Map<String, dynamic> json) => _$SubtitleStreamViewFromJson(json);
}

/// Kotlin `TipRecordView`（Tips.kt）。
@freezed
abstract class TipRecordView with _$TipRecordView {
  const factory TipRecordView({
    @Default("") String tipId,
    @Default(0) int displayCount,
    String? firstDisplayedAt,
    String? lastDisplayedAt,
    String? invalidatedAt,
    String? invalidatedReason,
  }) = _TipRecordView;

  factory TipRecordView.fromJson(Map<String, dynamic> json) => _$TipRecordViewFromJson(json);
}

/// Kotlin `TipStateView`（Tips.kt）。
@freezed
abstract class TipStateView with _$TipStateView {
  const factory TipStateView({
    @Default([]) List<TipRecordView> tips,
  }) = _TipStateView;

  factory TipStateView.fromJson(Map<String, dynamic> json) => _$TipStateViewFromJson(json);
}

/// Kotlin `TitleDetails`（Discovery.kt）。
@freezed
abstract class TitleDetails with _$TitleDetails {
  const factory TitleDetails({
    @Default(DiscoveredTitle()) DiscoveredTitle title,
    @Default(TitleMetadata()) TitleMetadata metadata,
    String? backdropOriginalUrl,
    @Default([]) List<DiscoveredTitle> recommendations,
    @Default([]) List<MediaLibraryLink> libraryLinks,
    @Default([]) List<MediaImage> backdrops,
    @Default([]) List<MediaImage> posters,
    @Default([]) List<MediaVideo> videos,
  }) = _TitleDetails;

  factory TitleDetails.fromJson(Map<String, dynamic> json) => _$TitleDetailsFromJson(json);
}

/// Kotlin `TitleMetadata`（Discovery.kt）。
@freezed
abstract class TitleMetadata with _$TitleMetadata {
  const factory TitleMetadata({
    String? plot,
    int? runtimeMinutes,
    @Default([]) List<String> genres,
    @Default([]) List<String> directors,
    @Default([]) List<CastMember> cast,
    @Default("") String country,
    @Default("") String language,
    @Default("") String released,
    String? network,
  }) = _TitleMetadata;

  factory TitleMetadata.fromJson(Map<String, dynamic> json) => _$TitleMetadataFromJson(json);
}

/// Kotlin `TitlePreviewRequest`（Subscription.kt）。
@freezed
abstract class TitlePreviewRequest with _$TitlePreviewRequest {
  const factory TitlePreviewRequest({
    @Default('') String titleRef,
  }) = _TitlePreviewRequest;

  factory TitlePreviewRequest.fromJson(Map<String, dynamic> json) => _$TitlePreviewRequestFromJson(json);
}

/// Kotlin `TitleSearchRequest`（Search.kt）。
@freezed
abstract class TitleSearchRequest with _$TitleSearchRequest {
  const factory TitleSearchRequest({
    @Default('') String query,
    @Default("all") String provider,
    @Default(true) bool saveHistory,
  }) = _TitleSearchRequest;

  factory TitleSearchRequest.fromJson(Map<String, dynamic> json) => _$TitleSearchRequestFromJson(json);
}

/// Kotlin `TitleSearchView`（Search.kt）。
@freezed
abstract class TitleSearchView with _$TitleSearchView {
  const factory TitleSearchView({
    @Default("") String query,
    @Default([]) List<DiscoveredTitle> titles,
    int? historyId,
  }) = _TitleSearchView;

  factory TitleSearchView.fromJson(Map<String, dynamic> json) => _$TitleSearchViewFromJson(json);
}

/// Kotlin `TodayArrival`（Subscription.kt）。
@freezed
abstract class TodayArrival with _$TodayArrival {
  const factory TodayArrival({
    @Default(0) int subscriptionId,
    @Default("") String mediaTitle,
    @Default("tv") String mediaKind,
    @Default(0) int seasonNumber,
    @Default(0) int episodeNumber,
    @Default("wanted") String status,
    String? airDate,
    String? expectedDay,
    @Default(0) int daysAhead,
    int? estimatedReleaseToImportMinutes,
  }) = _TodayArrival;

  factory TodayArrival.fromJson(Map<String, dynamic> json) => _$TodayArrivalFromJson(json);
}

/// Kotlin `TodayArrivalFull`（Subscription.kt）。
@freezed
abstract class TodayArrivalFull with _$TodayArrivalFull {
  const factory TodayArrivalFull({
    @Default(0) int subscriptionId,
    @Default("") String mediaTitle,
    @Default("tv") String mediaKind,
    @Default(0) int seasonNumber,
    @Default(0) int episodeNumber,
    @Default("wanted") String status,
    String? airDate,
    String? expectedDay,
    @Default(0) int daysAhead,
    String? grabbedAt,
    String? downloadedAt,
    String? infoHash,
    int? estimatedReleaseToImportMinutes,
    int? estimatedDownloadToImportMinutes,
    Map<String, dynamic>? releaseForecast,
    String? nextProbeAt,
  }) = _TodayArrivalFull;

  factory TodayArrivalFull.fromJson(Map<String, dynamic> json) => _$TodayArrivalFullFromJson(json);
}

/// Kotlin `ToolCallInfo`（Agent.kt）。
@freezed
abstract class ToolCallInfo with _$ToolCallInfo {
  const factory ToolCallInfo({
    @Default("") String id,
    @Default("") String name,
    dynamic arguments,
    String? rawArguments,
    String? parseError,
  }) = _ToolCallInfo;

  factory ToolCallInfo.fromJson(Map<String, dynamic> json) => _$ToolCallInfoFromJson(json);
}

/// Kotlin `TrackDefaultsView`（Models.kt）。
@freezed
abstract class TrackDefaultsView with _$TrackDefaultsView {
  const factory TrackDefaultsView({
    @JsonKey(name: 'audio_track')
    String? audioTrack,
    @JsonKey(name: 'audio_reason')
    @Default("") String audioReason,
    @JsonKey(name: 'audio_note')
    @Default("") String audioNote,
    @JsonKey(name: 'subtitle_track')
    String? subtitleTrack,
    @JsonKey(name: 'subtitle_reason')
    @Default("") String subtitleReason,
    @JsonKey(name: 'subtitle_note')
    @Default("") String subtitleNote,
  }) = _TrackDefaultsView;

  factory TrackDefaultsView.fromJson(Map<String, dynamic> json) => _$TrackDefaultsViewFromJson(json);
}

/// Kotlin `TrackingStateRequest`（Subscription.kt）。
@freezed
abstract class TrackingStateRequest with _$TrackingStateRequest {
  const factory TrackingStateRequest({
    @Default('') String state,
  }) = _TrackingStateRequest;

  factory TrackingStateRequest.fromJson(Map<String, dynamic> json) => _$TrackingStateRequestFromJson(json);
}

/// Kotlin `TranscriptEntry`（Agent.kt）。
@freezed
abstract class TranscriptEntry with _$TranscriptEntry {
  const factory TranscriptEntry({
    String? messageId,
    String? compactionId,
    String? handoffId,
    String? timestamp,
    SessionMessage? message,
    String? summary,
    int? tokensBefore,
    int? tokensAfter,
    String? model,
    String? sourceTitle,
  }) = _TranscriptEntry;

  factory TranscriptEntry.fromJson(Map<String, dynamic> json) => _$TranscriptEntryFromJson(json);
}

/// Kotlin `TransferMoveView`（ItemActions.kt）。
@freezed
abstract class TransferMoveView with _$TransferMoveView {
  const factory TransferMoveView({
    @Default("") String sourcePath,
    @Default("") String targetPath,
    @Default(false) bool isDir,
    @Default(0) int sizeBytes,
    @Default(0) int fileCount,
  }) = _TransferMoveView;

  factory TransferMoveView.fromJson(Map<String, dynamic> json) => _$TransferMoveViewFromJson(json);
}

/// Kotlin `TransferPayload`（ItemActions.kt）。
@freezed
abstract class TransferPayload with _$TransferPayload {
  const factory TransferPayload({
    @Default(0) int targetLibraryId,
  }) = _TransferPayload;

  factory TransferPayload.fromJson(Map<String, dynamic> json) => _$TransferPayloadFromJson(json);
}

/// Kotlin `TransferPreviewView`（ItemActions.kt）。
@freezed
abstract class TransferPreviewView with _$TransferPreviewView {
  const factory TransferPreviewView({
    @Default(0) int targetLibraryId,
    @Default("") String targetLibraryName,
    @Default("") String targetRoot,
    @Default([]) List<TransferMoveView> moves,
    @Default([]) List<TransferSkipView> skips,
    @Default(0) int totalBytes,
    @Default(0) int missingCount,
    @Default(false) bool crossDevice,
    @Default([]) List<String> blocked,
  }) = _TransferPreviewView;

  factory TransferPreviewView.fromJson(Map<String, dynamic> json) => _$TransferPreviewViewFromJson(json);
}

/// Kotlin `TransferSkipView`（ItemActions.kt）。
@freezed
abstract class TransferSkipView with _$TransferSkipView {
  const factory TransferSkipView({
    @Default("") String filePath,
    @Default("") String reason,
  }) = _TransferSkipView;

  factory TransferSkipView.fromJson(Map<String, dynamic> json) => _$TransferSkipViewFromJson(json);
}

/// Kotlin `TransferStartView`（ItemActions.kt）。
@freezed
abstract class TransferStartView with _$TransferStartView {
  const factory TransferStartView({
    @Default(false) bool started,
    @Default("") String message,
    String? jobId,
    @Default(false) bool created,
  }) = _TransferStartView;

  factory TransferStartView.fromJson(Map<String, dynamic> json) => _$TransferStartViewFromJson(json);
}

/// Kotlin `TransferStatusView`（ItemActions.kt）。
@freezed
abstract class TransferStatusView with _$TransferStatusView {
  const factory TransferStatusView({
    @Default(false) bool running,
    int? mediaItemId,
    String? title,
    int? targetLibraryId,
    @Default(0) int processed,
    @Default(0) int total,
    String? finishedAt,
    String? targetLibraryName,
    @Default([]) List<String> movedPaths,
    @Default(0) int filesRelocated,
    @Default(0) int bytesMoved,
    @Default(0) int removedDirs,
    @Default(false) bool subscriptionMoved,
    @Default(0) int movedItems,
    @Default(0) int skippedItems,
    @Default(0) int failedItems,
    @Default([]) List<String> skips,
    @Default([]) List<String> errors,
  }) = _TransferStatusView;

  factory TransferStatusView.fromJson(Map<String, dynamic> json) => _$TransferStatusViewFromJson(json);
}

/// Kotlin `TrickplayView`（Models.kt）。
@freezed
abstract class TrickplayView with _$TrickplayView {
  const factory TrickplayView({
    @Default(false) bool ready,
    @JsonKey(name: 'interval_ms')
    @Default(0) int intervalMs,
    @JsonKey(name: 'tile_width')
    @Default(0) int tileWidth,
    @JsonKey(name: 'tile_height')
    @Default(0) int tileHeight,
    @Default(0) int columns,
    @Default(0) int rows,
    @Default(0) int count,
    @Default([]) List<String> sheets,
  }) = _TrickplayView;

  factory TrickplayView.fromJson(Map<String, dynamic> json) => _$TrickplayViewFromJson(json);
}

/// Kotlin `UiPreferencesSetting`（Models.kt）。
@freezed
abstract class UiPreferencesSetting with _$UiPreferencesSetting {
  const factory UiPreferencesSetting({
    @Default("") String language,
    @Default("") String theme,
    @JsonKey(name: 'theme_desktop')
    String? themeDesktop,
    @JsonKey(name: 'theme_mobile')
    String? themeMobile,
    @Default(SidebarUiPrefs()) SidebarUiPrefs sidebar,
    @Default(ScrimUiPrefs()) ScrimUiPrefs scrim,
    @Default(NavUiPrefs()) NavUiPrefs nav,
    @Default(HomeUiPrefs()) HomeUiPrefs home,
    @JsonKey(name: 'poster_badges')
    @Default(PosterBadgePrefs()) PosterBadgePrefs posterBadges,
  }) = _UiPreferencesSetting;

  factory UiPreferencesSetting.fromJson(Map<String, dynamic> json) => _$UiPreferencesSettingFromJson(json);
}

/// Kotlin `UnidentifiedCandidateView`（ItemActions.kt）。
@freezed
abstract class UnidentifiedCandidateView with _$UnidentifiedCandidateView {
  const factory UnidentifiedCandidateView({
    @Default(0) int tmdbId,
    @Default("") String title,
    int? year,
    int? episodeCount,
    @Default([]) List<String> reasons,
  }) = _UnidentifiedCandidateView;

  factory UnidentifiedCandidateView.fromJson(Map<String, dynamic> json) => _$UnidentifiedCandidateViewFromJson(json);
}

/// Kotlin `UpNextItem`（Models.kt）。
@freezed
abstract class UpNextItem with _$UpNextItem {
  const factory UpNextItem({
    @Default(0) int mediaItemId,
    @Default(0) int libraryId,
    @Default("movie") String kind,
    @Default('') String title,
    int? year,
    String? posterUrl,
    @Default(0.0) double posterAspect,
    String? backdropUrl,
    String? episodeStillUrl,
    @Default(0) int seasonNumber,
    @Default(0) int episodeNumber,
    String? episodeTitle,
    @Default(0) int unwatchedAheadCount,
    @Default(0) int positionMs,
    @Default(0) int durationMs,
    @Default(0) int progressPercent,
    @Default(false) bool advanced,
    String? lastPlayedAt,
  }) = _UpNextItem;

  factory UpNextItem.fromJson(Map<String, dynamic> json) => _$UpNextItemFromJson(json);
}

/// Kotlin `UpNextItemView`（Models.kt）。
@freezed
abstract class UpNextItemView with _$UpNextItemView {
  const factory UpNextItemView({
    @JsonKey(name: 'media_item_id')
    @Default(0) int mediaItemId,
    @JsonKey(name: 'library_id')
    @Default(0) int libraryId,
    @Default("") String kind,
    @Default("") String title,
    int? year,
    @JsonKey(name: 'poster_url')
    String? posterUrl,
    @JsonKey(name: 'poster_aspect')
    @Default(0.0) double posterAspect,
    @JsonKey(name: 'backdrop_url')
    String? backdropUrl,
    @JsonKey(name: 'episode_still_url')
    String? episodeStillUrl,
    @JsonKey(name: 'episode_still_original_url')
    String? episodeStillOriginalUrl,
    @JsonKey(name: 'logo_url')
    String? logoUrl,
    String? overview,
    List<String>? genres,
    @JsonKey(name: 'season_number')
    @Default(0) int seasonNumber,
    @JsonKey(name: 'episode_number')
    @Default(0) int episodeNumber,
    @JsonKey(name: 'episode_title')
    String? episodeTitle,
    @JsonKey(name: 'unwatched_ahead_count')
    @Default(0) int unwatchedAheadCount,
    @JsonKey(name: 'position_ms')
    @Default(0) int positionMs,
    @JsonKey(name: 'duration_ms')
    int? durationMs,
    @JsonKey(name: 'progress_percent')
    int? progressPercent,
    @Default(false) bool advanced,
    @JsonKey(name: 'last_played_at')
    @Default("") String lastPlayedAt,
  }) = _UpNextItemView;

  factory UpNextItemView.fromJson(Map<String, dynamic> json) => _$UpNextItemViewFromJson(json);
}

/// Kotlin `UpNextView`（Models.kt）。
@freezed
abstract class UpNextView with _$UpNextView {
  const factory UpNextView({
    @Default([]) List<UpNextItemView> items,
  }) = _UpNextView;

  factory UpNextView.fromJson(Map<String, dynamic> json) => _$UpNextViewFromJson(json);
}

/// Kotlin `UpdateCheck`（Maintenance.kt）。
@freezed
abstract class UpdateCheck with _$UpdateCheck {
  const factory UpdateCheck({
    @Default("") String currentVersion,
    @Default("") String latestVersion,
    @Default(false) bool updateAvailable,
    @Default(true) bool compatible,
    @Default(0) int requiresRuntime,
    @Default("") String changelog,
    @Default("") String publishedAt,
    @Default(false) bool latestKnownBad,
  }) = _UpdateCheck;

  factory UpdateCheck.fromJson(Map<String, dynamic> json) => _$UpdateCheckFromJson(json);
}

/// Kotlin `UpdateProfileRequest`（Settings.kt）。
@freezed
abstract class UpdateProfileRequest with _$UpdateProfileRequest {
  const factory UpdateProfileRequest({
    @Default('') String nickname,
  }) = _UpdateProfileRequest;

  factory UpdateProfileRequest.fromJson(Map<String, dynamic> json) => _$UpdateProfileRequestFromJson(json);
}

/// Kotlin `UpdateProgress`（Maintenance.kt）。
@freezed
abstract class UpdateProgress with _$UpdateProgress {
  const factory UpdateProgress({
    @Default("") String phase,
    @Default("") String detail,
    double? percent,
    String? error,
    String? targetVersion,
  }) = _UpdateProgress;

  factory UpdateProgress.fromJson(Map<String, dynamic> json) => _$UpdateProgressFromJson(json);
}

/// Kotlin `UpdateStatus`（Maintenance.kt）。
@freezed
abstract class UpdateStatus with _$UpdateStatus {
  const factory UpdateStatus({
    @Default("") String currentVersion,
    @Default("") String codeSource,
    String? overlayVersion,
    int? runtimeVersion,
    @Default(false) bool canUpdate,
    @Default(false) bool hasPrevious,
    String? previousVersion,
    @Default([]) List<String> badVersions,
    String? modelTag,
    String? inactiveOverlayVersion,
    String? inactiveOverlayReason,
    LastAbnormalExit? lastAbnormalExit,
  }) = _UpdateStatus;

  factory UpdateStatus.fromJson(Map<String, dynamic> json) => _$UpdateStatusFromJson(json);
}

/// Kotlin `UpgradeRunPayload`（Subscription.kt）。
@freezed
abstract class UpgradeRunPayload with _$UpgradeRunPayload {
  const factory UpgradeRunPayload({
    int? ruleSetId,
  }) = _UpgradeRunPayload;

  factory UpgradeRunPayload.fromJson(Map<String, dynamic> json) => _$UpgradeRunPayloadFromJson(json);
}

/// Kotlin `UpgradeRunView`（Subscription.kt）。
@freezed
abstract class UpgradeRunView with _$UpgradeRunView {
  const factory UpgradeRunView({
    @Default("") String targetLabel,
    int? ruleSetId,
    @Default("") String summary,
    @Default({}) Map<String, int> counts,
  }) = _UpgradeRunView;

  factory UpgradeRunView.fromJson(Map<String, dynamic> json) => _$UpgradeRunViewFromJson(json);
}

/// Kotlin `VideoPlanView`（Models.kt）。
@freezed
abstract class VideoPlanView with _$VideoPlanView {
  const factory VideoPlanView({
    @Default("") String action,
    String? codec,
    int? height,
    @JsonKey(name: 'tone_map')
    @Default(false) bool toneMap,
    @JsonKey(name: 'bitrate_cap_bps')
    int? bitrateCapBps,
    @JsonKey(name: 'burn_subtitle')
    String? burnSubtitle,
  }) = _VideoPlanView;

  factory VideoPlanView.fromJson(Map<String, dynamic> json) => _$VideoPlanViewFromJson(json);
}

/// Kotlin `VideoSupportIn`（Models.kt）。
@freezed
abstract class VideoSupportIn with _$VideoSupportIn {
  const factory VideoSupportIn({
    @Default('') String codec,
    @JsonKey(name: 'max_height')
    int? maxHeight,
    bool? smooth,
    @JsonKey(name: 'power_efficient')
    bool? powerEfficient,
  }) = _VideoSupportIn;

  factory VideoSupportIn.fromJson(Map<String, dynamic> json) => _$VideoSupportInFromJson(json);
}

/// Kotlin `WantedUpgradeView`（Models.kt）。
@freezed
abstract class WantedUpgradeView with _$WantedUpgradeView {
  const factory WantedUpgradeView({
    @Default(false) bool active,
    @JsonKey(name: 'current_label')
    @Default("") String currentLabel,
    @JsonKey(name: 'target_label')
    @Default("") String targetLabel,
    @JsonKey(name: 'search_attempts')
    @Default(0) int searchAttempts,
    @Default(false) bool indeterminate,
  }) = _WantedUpgradeView;

  factory WantedUpgradeView.fromJson(Map<String, dynamic> json) => _$WantedUpgradeViewFromJson(json);
}

/// Kotlin `WantedView`（Models.kt）。
@freezed
abstract class WantedView with _$WantedView {
  const factory WantedView({
    @Default(0) int id,
    @JsonKey(name: 'season_number')
    @Default(0) int seasonNumber,
    @JsonKey(name: 'episode_number')
    @Default(0) int episodeNumber,
    @Default("") String status,
    @JsonKey(name: 'air_date')
    String? airDate,
    @Default(0) int priority,
    @JsonKey(name: 'info_hash')
    String? infoHash,
    @JsonKey(name: 'next_search_at')
    String? nextSearchAt,
    @JsonKey(name: 'search_attempts')
    @Default(0) int searchAttempts,
    @JsonKey(name: 'last_search_at')
    String? lastSearchAt,
    @JsonKey(name: 'release_forecast')
    Map<String, dynamic>? releaseForecast,
    @JsonKey(name: 'resource_timing')
    ResourceTimingView? resourceTiming,
    @JsonKey(name: 'grabbed_at')
    String? grabbedAt,
    @JsonKey(name: 'downloaded_at')
    String? downloadedAt,
    @JsonKey(name: 'imported_at')
    String? importedAt,
    @JsonKey(name: 'last_reject_reason')
    String? lastRejectReason,
    @JsonKey(name: 'grab_title')
    String? grabTitle,
    WantedUpgradeView? upgrade,
    @JsonKey(name: 'selection_state')
    Map<String, dynamic>? selectionState,
    @JsonKey(name: 'selection_version')
    @Default(0) int selectionVersion,
    bool? provisional,
  }) = _WantedView;

  factory WantedView.fromJson(Map<String, dynamic> json) => _$WantedViewFromJson(json);
}

/// Kotlin `WebPortPayload`（Maintenance.kt）。
@freezed
abstract class WebPortPayload with _$WebPortPayload {
  const factory WebPortPayload({
    int? port,
  }) = _WebPortPayload;

  factory WebPortPayload.fromJson(Map<String, dynamic> json) => _$WebPortPayloadFromJson(json);
}

/// Kotlin `WebSearchConfig`（Llm.kt）。
@freezed
abstract class WebSearchConfig with _$WebSearchConfig {
  const factory WebSearchConfig({
    String? provider,
    @Default(false) bool configured,
    @JsonKey(name: 'key_hint')
    @Default("") String keyHint,
    @Default([]) List<WebSearchProviderOption> providers,
  }) = _WebSearchConfig;

  factory WebSearchConfig.fromJson(Map<String, dynamic> json) => _$WebSearchConfigFromJson(json);
}

/// Kotlin `WebSearchProviderOption`（Llm.kt）。
@freezed
abstract class WebSearchProviderOption with _$WebSearchProviderOption {
  const factory WebSearchProviderOption({
    @Default("") String id,
    @Default("") String label,
    @JsonKey(name: 'signup_url')
    String? signupUrl,
  }) = _WebSearchProviderOption;

  factory WebSearchProviderOption.fromJson(Map<String, dynamic> json) => _$WebSearchProviderOptionFromJson(json);
}

/// Kotlin `WebSearchSavePayload`（Llm.kt）。
@freezed
abstract class WebSearchSavePayload with _$WebSearchSavePayload {
  const factory WebSearchSavePayload({
    @Default('') String provider,
    @JsonKey(name: 'api_key')
    String? apiKey,
  }) = _WebSearchSavePayload;

  factory WebSearchSavePayload.fromJson(Map<String, dynamic> json) => _$WebSearchSavePayloadFromJson(json);
}

/// Kotlin `WebSearchTestPayload`（Llm.kt）。
@freezed
abstract class WebSearchTestPayload with _$WebSearchTestPayload {
  const factory WebSearchTestPayload({
    String? provider,
    @JsonKey(name: 'api_key')
    String? apiKey,
  }) = _WebSearchTestPayload;

  factory WebSearchTestPayload.fromJson(Map<String, dynamic> json) => _$WebSearchTestPayloadFromJson(json);
}

/// Kotlin `WebSearchTestResult`（Llm.kt）。
@freezed
abstract class WebSearchTestResult with _$WebSearchTestResult {
  const factory WebSearchTestResult({
    @Default(false) bool ok,
    @Default("") String message,
    @JsonKey(name: 'sample_title')
    String? sampleTitle,
  }) = _WebSearchTestResult;

  factory WebSearchTestResult.fromJson(Map<String, dynamic> json) => _$WebSearchTestResultFromJson(json);
}

/// Kotlin `WebhookConfigPayload`（Agent.kt）。
@freezed
abstract class WebhookConfigPayload with _$WebhookConfigPayload {
  const factory WebhookConfigPayload({
    @Default(false) bool enabled,
    @Default([]) List<WebhookEndpointPayload> endpoints,
  }) = _WebhookConfigPayload;

  factory WebhookConfigPayload.fromJson(Map<String, dynamic> json) => _$WebhookConfigPayloadFromJson(json);
}

/// Kotlin `WebhookConfigView`（Agent.kt）。
@freezed
abstract class WebhookConfigView with _$WebhookConfigView {
  const factory WebhookConfigView({
    @Default(false) bool enabled,
    @Default([]) List<WebhookEndpointView> endpoints,
  }) = _WebhookConfigView;

  factory WebhookConfigView.fromJson(Map<String, dynamic> json) => _$WebhookConfigViewFromJson(json);
}

/// Kotlin `WebhookDeliveryView`（Agent.kt）。
@freezed
abstract class WebhookDeliveryView with _$WebhookDeliveryView {
  const factory WebhookDeliveryView({
    @JsonKey(name: 'event_id')
    @Default("") String eventId,
    @Default("") String event,
    @Default(false) bool ok,
    @JsonKey(name: 'status_code')
    int? statusCode,
    @JsonKey(name: 'duration_ms')
    @Default(0) int durationMs,
    @Default(0) int attempts,
    @Default("") String error,
    @Default("") String at,
  }) = _WebhookDeliveryView;

  factory WebhookDeliveryView.fromJson(Map<String, dynamic> json) => _$WebhookDeliveryViewFromJson(json);
}

/// Kotlin `WebhookEndpointPayload`（Agent.kt）。
@freezed
abstract class WebhookEndpointPayload with _$WebhookEndpointPayload {
  const factory WebhookEndpointPayload({
    @Default("") String id,
    @Default("") String name,
    @Default("") String url,
    @Default("movieclaw") String format,
    @Default(true) bool enabled,
    @Default([]) List<String> events,
    @Default("") String template,
    @Default({}) Map<String, String> headers,
    @JsonKey(name: 'egress_scope')
    @Default("lan") String egressScope,
  }) = _WebhookEndpointPayload;

  factory WebhookEndpointPayload.fromJson(Map<String, dynamic> json) => _$WebhookEndpointPayloadFromJson(json);
}

/// Kotlin `WebhookEndpointView`（Agent.kt）。
@freezed
abstract class WebhookEndpointView with _$WebhookEndpointView {
  const factory WebhookEndpointView({
    @Default("") String id,
    @Default("") String name,
    @Default("") String url,
    @Default("") String format,
    @Default(false) bool enabled,
    @Default([]) List<String> events,
    @Default("") String template,
    @Default({}) Map<String, String> headers,
    @JsonKey(name: 'egress_scope')
    @Default("lan") String egressScope,
    @JsonKey(name: 'secret_masked')
    @Default("") String secretMasked,
    @JsonKey(name: 'last_delivery')
    WebhookDeliveryView? lastDelivery,
  }) = _WebhookEndpointView;

  factory WebhookEndpointView.fromJson(Map<String, dynamic> json) => _$WebhookEndpointViewFromJson(json);
}
