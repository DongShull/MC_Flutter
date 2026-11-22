// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ActiveFileDownload _$ActiveFileDownloadFromJson(Map<String, dynamic> json) =>
    _ActiveFileDownload(
      deviceId: json['deviceId'] as String? ?? '',
      memberName: json['memberName'] as String? ?? "",
      client: json['client'] as String? ?? "",
      deviceName: json['deviceName'] as String? ?? "",
      revocable: json['revocable'] as bool? ?? true,
      media: json['media'] == null
          ? null
          : MediaActivityTarget.fromJson(json['media'] as Map<String, dynamic>),
      fileName: json['fileName'] as String? ?? "",
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
      bytesSent: (json['bytesSent'] as num?)?.toInt() ?? 0,
      rateBytesPerSecond: (json['rateBytesPerSecond'] as num?)?.toDouble(),
      connections: (json['connections'] as num?)?.toInt() ?? 1,
      positionBytes: (json['positionBytes'] as num?)?.toInt() ?? 0,
      progressPercent: (json['progressPercent'] as num?)?.toInt(),
    );

Map<String, dynamic> _$ActiveFileDownloadToJson(_ActiveFileDownload instance) =>
    <String, dynamic>{
      'deviceId': instance.deviceId,
      'memberName': instance.memberName,
      'client': instance.client,
      'deviceName': instance.deviceName,
      'revocable': instance.revocable,
      'media': instance.media,
      'fileName': instance.fileName,
      'sizeBytes': instance.sizeBytes,
      'bytesSent': instance.bytesSent,
      'rateBytesPerSecond': instance.rateBytesPerSecond,
      'connections': instance.connections,
      'positionBytes': instance.positionBytes,
      'progressPercent': instance.progressPercent,
    };

_ActivePlaybackSession _$ActivePlaybackSessionFromJson(
  Map<String, dynamic> json,
) => _ActivePlaybackSession(
  deviceId: json['deviceId'] as String? ?? '',
  memberName: json['memberName'] as String? ?? "",
  client: json['client'] as String? ?? "",
  deviceName: json['deviceName'] as String? ?? "",
  media: json['media'] == null
      ? const MediaActivityTarget()
      : MediaActivityTarget.fromJson(json['media'] as Map<String, dynamic>),
  positionMs: (json['positionMs'] as num?)?.toInt(),
  durationMs: (json['durationMs'] as num?)?.toInt(),
  progressPercent: (json['progressPercent'] as num?)?.toInt(),
  paused: json['paused'] as bool? ?? false,
  playMethod: json['playMethod'] as String? ?? "",
  rateBytesPerSecond: (json['rateBytesPerSecond'] as num?)?.toDouble(),
  delivery: json['delivery'] == null
      ? null
      : PlaybackDelivery.fromJson(json['delivery'] as Map<String, dynamic>),
  revocable: json['revocable'] as bool? ?? true,
);

Map<String, dynamic> _$ActivePlaybackSessionToJson(
  _ActivePlaybackSession instance,
) => <String, dynamic>{
  'deviceId': instance.deviceId,
  'memberName': instance.memberName,
  'client': instance.client,
  'deviceName': instance.deviceName,
  'media': instance.media,
  'positionMs': instance.positionMs,
  'durationMs': instance.durationMs,
  'progressPercent': instance.progressPercent,
  'paused': instance.paused,
  'playMethod': instance.playMethod,
  'rateBytesPerSecond': instance.rateBytesPerSecond,
  'delivery': instance.delivery,
  'revocable': instance.revocable,
};

_ActorView _$ActorViewFromJson(Map<String, dynamic> json) => _ActorView(
  name: json['name'] as String? ?? "",
  role: json['role'] as String?,
  thumbUrl: json['thumb_url'] as String?,
  tmdbPersonId: (json['tmdb_person_id'] as num?)?.toInt(),
);

Map<String, dynamic> _$ActorViewToJson(_ActorView instance) =>
    <String, dynamic>{
      'name': instance.name,
      'role': instance.role,
      'thumb_url': instance.thumbUrl,
      'tmdb_person_id': instance.tmdbPersonId,
    };

_AgentAttachment _$AgentAttachmentFromJson(Map<String, dynamic> json) =>
    _AgentAttachment(
      attachmentId: json['attachmentId'] as String? ?? '',
      name: json['name'] as String? ?? "",
      width: (json['width'] as num?)?.toInt() ?? 0,
      height: (json['height'] as num?)?.toInt() ?? 0,
      bytes: (json['bytes'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$AgentAttachmentToJson(_AgentAttachment instance) =>
    <String, dynamic>{
      'attachmentId': instance.attachmentId,
      'name': instance.name,
      'width': instance.width,
      'height': instance.height,
      'bytes': instance.bytes,
    };

_AgentSessionStart _$AgentSessionStartFromJson(Map<String, dynamic> json) =>
    _AgentSessionStart(
      content: json['content'] as String? ?? '',
      sessionId: json['sessionId'] as String?,
      attachments:
          (json['attachments'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      model: json['model'] as String? ?? "",
      thinkingLevel: json['thinkingLevel'] as String?,
    );

Map<String, dynamic> _$AgentSessionStartToJson(_AgentSessionStart instance) =>
    <String, dynamic>{
      'content': instance.content,
      'sessionId': instance.sessionId,
      'attachments': instance.attachments,
      'model': instance.model,
      'thinkingLevel': instance.thinkingLevel,
    };

_AppConfig _$AppConfigFromJson(Map<String, dynamic> json) => _AppConfig(
  externalUrl: json['external_url'] as String? ?? "",
  webPort: (json['web_port'] as num?)?.toInt() ?? 0,
  webPortSource: json['web_port_source'] as String? ?? "default",
  webPortDefault: (json['web_port_default'] as num?)?.toInt() ?? 0,
  webPortRejected: (json['web_port_rejected'] as num?)?.toInt(),
  webPortConfigurable: json['web_port_configurable'] as bool? ?? false,
);

Map<String, dynamic> _$AppConfigToJson(_AppConfig instance) =>
    <String, dynamic>{
      'external_url': instance.externalUrl,
      'web_port': instance.webPort,
      'web_port_source': instance.webPortSource,
      'web_port_default': instance.webPortDefault,
      'web_port_rejected': instance.webPortRejected,
      'web_port_configurable': instance.webPortConfigurable,
    };

_AppConfigPayload _$AppConfigPayloadFromJson(Map<String, dynamic> json) =>
    _AppConfigPayload(externalUrl: json['external_url'] as String? ?? '');

Map<String, dynamic> _$AppConfigPayloadToJson(_AppConfigPayload instance) =>
    <String, dynamic>{'external_url': instance.externalUrl};

_ArtworkCandidateView _$ArtworkCandidateViewFromJson(
  Map<String, dynamic> json,
) => _ArtworkCandidateView(
  filePath: json['filePath'] as String? ?? "",
  previewUrl: json['previewUrl'] as String? ?? "",
  width: (json['width'] as num?)?.toInt(),
  height: (json['height'] as num?)?.toInt(),
  language: json['language'] as String?,
  voteAverage: (json['voteAverage'] as num?)?.toDouble(),
  voteCount: (json['voteCount'] as num?)?.toInt(),
  source: json['source'] as String? ?? "tmdb",
  likes: (json['likes'] as num?)?.toInt(),
  unlisted: json['unlisted'] as bool? ?? false,
);

Map<String, dynamic> _$ArtworkCandidateViewToJson(
  _ArtworkCandidateView instance,
) => <String, dynamic>{
  'filePath': instance.filePath,
  'previewUrl': instance.previewUrl,
  'width': instance.width,
  'height': instance.height,
  'language': instance.language,
  'voteAverage': instance.voteAverage,
  'voteCount': instance.voteCount,
  'source': instance.source,
  'likes': instance.likes,
  'unlisted': instance.unlisted,
};

_ArtworkCandidatesView _$ArtworkCandidatesViewFromJson(
  Map<String, dynamic> json,
) => _ArtworkCandidatesView(
  posters:
      (json['posters'] as List<dynamic>?)
          ?.map((e) => ArtworkCandidateView.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  backdrops:
      (json['backdrops'] as List<dynamic>?)
          ?.map((e) => ArtworkCandidateView.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  logos:
      (json['logos'] as List<dynamic>?)
          ?.map((e) => ArtworkCandidateView.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  currentPoster: json['currentPoster'] as String?,
  currentBackdrop: json['currentBackdrop'] as String?,
  currentLogo: json['currentLogo'] as String?,
  posterLocked: json['posterLocked'] as bool? ?? false,
  backdropLocked: json['backdropLocked'] as bool? ?? false,
  logoLocked: json['logoLocked'] as bool? ?? false,
  fanart: json['fanart'] as String? ?? "none",
);

Map<String, dynamic> _$ArtworkCandidatesViewToJson(
  _ArtworkCandidatesView instance,
) => <String, dynamic>{
  'posters': instance.posters,
  'backdrops': instance.backdrops,
  'logos': instance.logos,
  'currentPoster': instance.currentPoster,
  'currentBackdrop': instance.currentBackdrop,
  'currentLogo': instance.currentLogo,
  'posterLocked': instance.posterLocked,
  'backdropLocked': instance.backdropLocked,
  'logoLocked': instance.logoLocked,
  'fanart': instance.fanart,
};

_ArtworkLockView _$ArtworkLockViewFromJson(Map<String, dynamic> json) =>
    _ArtworkLockView(locked: json['locked'] as bool? ?? false);

Map<String, dynamic> _$ArtworkLockViewToJson(_ArtworkLockView instance) =>
    <String, dynamic>{'locked': instance.locked};

_ArtworkSelectPayload _$ArtworkSelectPayloadFromJson(
  Map<String, dynamic> json,
) => _ArtworkSelectPayload(
  kind: json['kind'] as String? ?? '',
  filePath: json['filePath'] as String?,
);

Map<String, dynamic> _$ArtworkSelectPayloadToJson(
  _ArtworkSelectPayload instance,
) => <String, dynamic>{'kind': instance.kind, 'filePath': instance.filePath};

_AudioPlanView _$AudioPlanViewFromJson(Map<String, dynamic> json) =>
    _AudioPlanView(
      action: json['action'] as String? ?? "",
      trackRef: json['track_ref'] as String?,
      codec: json['codec'] as String?,
      channels: (json['channels'] as num?)?.toInt(),
      downmix: json['downmix'] as bool? ?? false,
    );

Map<String, dynamic> _$AudioPlanViewToJson(_AudioPlanView instance) =>
    <String, dynamic>{
      'action': instance.action,
      'track_ref': instance.trackRef,
      'codec': instance.codec,
      'channels': instance.channels,
      'downmix': instance.downmix,
    };

_AudioStreamView _$AudioStreamViewFromJson(Map<String, dynamic> json) =>
    _AudioStreamView(
      codec: json['codec'] as String?,
      profile: json['profile'] as String?,
      channels: (json['channels'] as num?)?.toInt(),
      channelLayout: json['channel_layout'] as String?,
      language: json['language'] as String?,
      title: json['title'] as String?,
      defaultValue: json['default'] as bool? ?? false,
    );

Map<String, dynamic> _$AudioStreamViewToJson(_AudioStreamView instance) =>
    <String, dynamic>{
      'codec': instance.codec,
      'profile': instance.profile,
      'channels': instance.channels,
      'channel_layout': instance.channelLayout,
      'language': instance.language,
      'title': instance.title,
      'default': instance.defaultValue,
    };

_AudioSupportIn _$AudioSupportInFromJson(Map<String, dynamic> json) =>
    _AudioSupportIn(
      codec: json['codec'] as String? ?? '',
      maxChannels: (json['max_channels'] as num?)?.toInt(),
    );

Map<String, dynamic> _$AudioSupportInToJson(_AudioSupportIn instance) =>
    <String, dynamic>{
      'codec': instance.codec,
      'max_channels': instance.maxChannels,
    };

_AudioTrackView _$AudioTrackViewFromJson(Map<String, dynamic> json) =>
    _AudioTrackView(
      ref: json['ref'] as String? ?? "",
      codec: json['codec'] as String?,
      channels: (json['channels'] as num?)?.toInt(),
      language: json['language'] as String?,
      isDefault: json['is_default'] as bool? ?? false,
    );

Map<String, dynamic> _$AudioTrackViewToJson(_AudioTrackView instance) =>
    <String, dynamic>{
      'ref': instance.ref,
      'codec': instance.codec,
      'channels': instance.channels,
      'language': instance.language,
      'is_default': instance.isDefault,
    };

_AuthTypeRequirement _$AuthTypeRequirementFromJson(Map<String, dynamic> json) =>
    _AuthTypeRequirement(
      authType: json['authType'] as String? ?? "",
      requiredFields:
          (json['requiredFields'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );

Map<String, dynamic> _$AuthTypeRequirementToJson(
  _AuthTypeRequirement instance,
) => <String, dynamic>{
  'authType': instance.authType,
  'requiredFields': instance.requiredFields,
};

_BootstrapStatus _$BootstrapStatusFromJson(Map<String, dynamic> json) =>
    _BootstrapStatus(
      initialized: json['initialized'] as bool? ?? false,
      nativeDeviceKinds: (json['native_device_kinds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$BootstrapStatusToJson(_BootstrapStatus instance) =>
    <String, dynamic>{
      'initialized': instance.initialized,
      'native_device_kinds': instance.nativeDeviceKinds,
    };

_CastMember _$CastMemberFromJson(Map<String, dynamic> json) => _CastMember(
  name: json['name'] as String? ?? "",
  role: json['role'] as String?,
  character: json['character'] as String?,
  avatarUrl: json['avatarUrl'] as String?,
  tmdbPersonId: (json['tmdbPersonId'] as num?)?.toInt(),
);

Map<String, dynamic> _$CastMemberToJson(_CastMember instance) =>
    <String, dynamic>{
      'name': instance.name,
      'role': instance.role,
      'character': instance.character,
      'avatarUrl': instance.avatarUrl,
      'tmdbPersonId': instance.tmdbPersonId,
    };

_ChangePasswordRequest _$ChangePasswordRequestFromJson(
  Map<String, dynamic> json,
) => _ChangePasswordRequest(
  oldPassword: json['oldPassword'] as String? ?? '',
  newPassword: json['newPassword'] as String? ?? '',
  signOutPaired: json['signOutPaired'] as bool? ?? false,
);

Map<String, dynamic> _$ChangePasswordRequestToJson(
  _ChangePasswordRequest instance,
) => <String, dynamic>{
  'oldPassword': instance.oldPassword,
  'newPassword': instance.newPassword,
  'signOutPaired': instance.signOutPaired,
};

_ChannelPushConfigView _$ChannelPushConfigViewFromJson(
  Map<String, dynamic> json,
) => _ChannelPushConfigView(
  pushDispatch: json['push_dispatch'] as bool? ?? false,
  pushImported: json['push_imported'] as bool? ?? false,
);

Map<String, dynamic> _$ChannelPushConfigViewToJson(
  _ChannelPushConfigView instance,
) => <String, dynamic>{
  'push_dispatch': instance.pushDispatch,
  'push_imported': instance.pushImported,
};

_ChapterJobView _$ChapterJobViewFromJson(Map<String, dynamic> json) =>
    _ChapterJobView(
      jobId: json['job_id'] as String? ?? "",
      status: json['status'] as String? ?? "",
      processed: (json['processed'] as num?)?.toInt() ?? 0,
      total: (json['total'] as num?)?.toInt() ?? 0,
      failed: (json['failed'] as num?)?.toInt() ?? 0,
      percent: (json['percent'] as num?)?.toDouble(),
      stopping: json['stopping'] as bool? ?? false,
    );

Map<String, dynamic> _$ChapterJobViewToJson(_ChapterJobView instance) =>
    <String, dynamic>{
      'job_id': instance.jobId,
      'status': instance.status,
      'processed': instance.processed,
      'total': instance.total,
      'failed': instance.failed,
      'percent': instance.percent,
      'stopping': instance.stopping,
    };

_ChapterView _$ChapterViewFromJson(Map<String, dynamic> json) => _ChapterView(
  index: (json['index'] as num?)?.toInt() ?? 0,
  startMs: (json['start_ms'] as num?)?.toInt() ?? 0,
  endMs: (json['end_ms'] as num?)?.toInt(),
  frameMs: (json['frame_ms'] as num?)?.toInt(),
  title: json['title'] as String?,
  synthetic: json['synthetic'] as bool? ?? false,
  imageUrl: json['image_url'] as String?,
);

Map<String, dynamic> _$ChapterViewToJson(_ChapterView instance) =>
    <String, dynamic>{
      'index': instance.index,
      'start_ms': instance.startMs,
      'end_ms': instance.endMs,
      'frame_ms': instance.frameMs,
      'title': instance.title,
      'synthetic': instance.synthetic,
      'image_url': instance.imageUrl,
    };

_ClaimBatchPayload _$ClaimBatchPayloadFromJson(Map<String, dynamic> json) =>
    _ClaimBatchPayload(
      fileIds:
          (json['fileIds'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [],
      titleRef: json['titleRef'] as String? ?? '',
      seasonNumber: (json['seasonNumber'] as num?)?.toInt(),
    );

Map<String, dynamic> _$ClaimBatchPayloadToJson(_ClaimBatchPayload instance) =>
    <String, dynamic>{
      'fileIds': instance.fileIds,
      'titleRef': instance.titleRef,
      'seasonNumber': instance.seasonNumber,
    };

_ClaimPayload _$ClaimPayloadFromJson(Map<String, dynamic> json) =>
    _ClaimPayload(
      tmdbId: (json['tmdbId'] as num?)?.toInt() ?? 0,
      entryFile: json['entryFile'] as String?,
    );

Map<String, dynamic> _$ClaimPayloadToJson(_ClaimPayload instance) =>
    <String, dynamic>{
      'tmdbId': instance.tmdbId,
      'entryFile': instance.entryFile,
    };

_CleanResult _$CleanResultFromJson(Map<String, dynamic> json) => _CleanResult(
  key: json['key'] as String? ?? "",
  mode: json['mode'] as String? ?? "",
  removed: (json['removed'] as num?)?.toInt() ?? 0,
  skippedBusy: (json['skippedBusy'] as num?)?.toInt() ?? 0,
  freedBytes: (json['freedBytes'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$CleanResultToJson(_CleanResult instance) =>
    <String, dynamic>{
      'key': instance.key,
      'mode': instance.mode,
      'removed': instance.removed,
      'skippedBusy': instance.skippedBusy,
      'freedBytes': instance.freedBytes,
    };

_ClientCapabilityIn _$ClientCapabilityInFromJson(Map<String, dynamic> json) =>
    _ClientCapabilityIn(
      video: (json['video'] as List<dynamic>?)
          ?.map((e) => VideoSupportIn.fromJson(e as Map<String, dynamic>))
          .toList(),
      audio: (json['audio'] as List<dynamic>?)
          ?.map((e) => AudioSupportIn.fromJson(e as Map<String, dynamic>))
          .toList(),
      containers: (json['containers'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      hdrPassthrough: json['hdr_passthrough'] as bool?,
      mse: json['mse'] as String?,
      isMobile: json['is_mobile'] as bool?,
      nativeHls: json['native_hls'] as bool?,
      universal: json['universal'] as bool?,
      discImage: json['disc_image'] as bool?,
      discFolder: json['disc_folder'] as bool?,
      blurayClips: json['bluray_clips'] as bool?,
      localTracks: json['local_tracks'] as bool?,
      dolbyVisionProfiles: (json['dolby_vision_profiles'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList(),
      dolbyVisionBaseLayerProfiles:
          (json['dolby_vision_base_layer_profiles'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList(),
      dolbyVisionRecordAudit: json['dolby_vision_record_audit'] as bool?,
      mp4SampleLimit: (json['mp4_sample_limit'] as num?)?.toInt(),
      hevcTranscode: json['hevc_transcode'] as bool?,
      pgsOverlay: json['pgs_overlay'] as bool?,
    );

Map<String, dynamic> _$ClientCapabilityInToJson(_ClientCapabilityIn instance) =>
    <String, dynamic>{
      'video': instance.video,
      'audio': instance.audio,
      'containers': instance.containers,
      'hdr_passthrough': instance.hdrPassthrough,
      'mse': instance.mse,
      'is_mobile': instance.isMobile,
      'native_hls': instance.nativeHls,
      'universal': instance.universal,
      'disc_image': instance.discImage,
      'disc_folder': instance.discFolder,
      'bluray_clips': instance.blurayClips,
      'local_tracks': instance.localTracks,
      'dolby_vision_profiles': instance.dolbyVisionProfiles,
      'dolby_vision_base_layer_profiles': instance.dolbyVisionBaseLayerProfiles,
      'dolby_vision_record_audit': instance.dolbyVisionRecordAudit,
      'mp4_sample_limit': instance.mp4SampleLimit,
      'hevc_transcode': instance.hevcTranscode,
      'pgs_overlay': instance.pgsOverlay,
    };

_ClientReleaseView _$ClientReleaseViewFromJson(Map<String, dynamic> json) =>
    _ClientReleaseView(
      product: json['product'] as String? ?? "",
      version: json['version'] as String? ?? "",
      build: (json['build'] as num?)?.toInt() ?? 0,
      size: (json['size'] as num?)?.toInt() ?? 0,
      sha256: json['sha256'] as String? ?? "",
      certificateSha256: json['certificate_sha256'] as String?,
      minimumSdk: (json['minimum_sdk'] as num?)?.toInt(),
      changelog: json['changelog'] as String? ?? "",
      publishedAt: json['published_at'] as String?,
      releaseUrl: json['release_url'] as String? ?? "",
    );

Map<String, dynamic> _$ClientReleaseViewToJson(_ClientReleaseView instance) =>
    <String, dynamic>{
      'product': instance.product,
      'version': instance.version,
      'build': instance.build,
      'size': instance.size,
      'sha256': instance.sha256,
      'certificate_sha256': instance.certificateSha256,
      'minimum_sdk': instance.minimumSdk,
      'changelog': instance.changelog,
      'published_at': instance.publishedAt,
      'release_url': instance.releaseUrl,
    };

_CloudFolderReportView _$CloudFolderReportViewFromJson(
  Map<String, dynamic> json,
) => _CloudFolderReportView(
  finishedAt: json['finished_at'] as String? ?? "",
  seconds: (json['seconds'] as num?)?.toDouble() ?? 0.0,
  calls: (json['calls'] as num?)?.toInt() ?? 0,
  videos: (json['videos'] as num?)?.toInt() ?? 0,
  identified: (json['identified'] as num?)?.toInt() ?? 0,
  pending: (json['pending'] as num?)?.toInt() ?? 0,
  skipped:
      (json['skipped'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, (e as num).toInt()),
      ) ??
      const {},
  cancelled: json['cancelled'] as bool? ?? false,
);

Map<String, dynamic> _$CloudFolderReportViewToJson(
  _CloudFolderReportView instance,
) => <String, dynamic>{
  'finished_at': instance.finishedAt,
  'seconds': instance.seconds,
  'calls': instance.calls,
  'videos': instance.videos,
  'identified': instance.identified,
  'pending': instance.pending,
  'skipped': instance.skipped,
  'cancelled': instance.cancelled,
};

_CloudFolderView _$CloudFolderViewFromJson(Map<String, dynamic> json) =>
    _CloudFolderView(
      id: (json['id'] as num?)?.toInt() ?? 0,
      accountId: (json['account_id'] as num?)?.toInt() ?? 0,
      accountName: json['account_name'] as String? ?? "",
      backend: json['backend'] as String? ?? "",
      backendTitle: json['backend_title'] as String? ?? "",
      remoteDirId: json['remote_dir_id'] as String? ?? "",
      displayPath: json['display_path'] as String? ?? "",
      isPrimary: json['is_primary'] as bool? ?? false,
      fileCount: (json['file_count'] as num?)?.toInt() ?? 0,
      listedAt: json['listed_at'] as String?,
      report: json['report'] == null
          ? null
          : CloudFolderReportView.fromJson(
              json['report'] as Map<String, dynamic>,
            ),
    );

Map<String, dynamic> _$CloudFolderViewToJson(_CloudFolderView instance) =>
    <String, dynamic>{
      'id': instance.id,
      'account_id': instance.accountId,
      'account_name': instance.accountName,
      'backend': instance.backend,
      'backend_title': instance.backendTitle,
      'remote_dir_id': instance.remoteDirId,
      'display_path': instance.displayPath,
      'is_primary': instance.isPrimary,
      'file_count': instance.fileCount,
      'listed_at': instance.listedAt,
      'report': instance.report,
    };

_CloudSettingsRequest _$CloudSettingsRequestFromJson(
  Map<String, dynamic> json,
) => _CloudSettingsRequest(reportStats: json['report_stats'] as bool? ?? false);

Map<String, dynamic> _$CloudSettingsRequestToJson(
  _CloudSettingsRequest instance,
) => <String, dynamic>{'report_stats': instance.reportStats};

_CloudStatusView _$CloudStatusViewFromJson(Map<String, dynamic> json) =>
    _CloudStatusView(
      state: json['state'] as String? ?? "disconnected",
      health: json['health'] as String?,
      healthMessage: json['health_message'] as String?,
      cloudUrl: json['cloud_url'] as String? ?? "",
      serverName: json['server_name'] as String? ?? "",
      reportStats: json['report_stats'] as bool? ?? false,
      lastReportAt: json['last_report_at'] as String?,
    );

Map<String, dynamic> _$CloudStatusViewToJson(_CloudStatusView instance) =>
    <String, dynamic>{
      'state': instance.state,
      'health': instance.health,
      'health_message': instance.healthMessage,
      'cloud_url': instance.cloudUrl,
      'server_name': instance.serverName,
      'report_stats': instance.reportStats,
      'last_report_at': instance.lastReportAt,
    };

_CloudUploadView _$CloudUploadViewFromJson(Map<String, dynamic> json) =>
    _CloudUploadView(
      jobId: json['job_id'] as String? ?? "",
      status: json['status'] as String? ?? "",
      processed: (json['processed'] as num?)?.toInt() ?? 0,
      total: (json['total'] as num?)?.toInt() ?? 0,
      rapid: (json['rapid'] as num?)?.toInt() ?? 0,
      failed: (json['failed'] as num?)?.toInt() ?? 0,
      percent: (json['percent'] as num?)?.toDouble(),
      message: json['message'] as String? ?? "",
    );

Map<String, dynamic> _$CloudUploadViewToJson(_CloudUploadView instance) =>
    <String, dynamic>{
      'job_id': instance.jobId,
      'status': instance.status,
      'processed': instance.processed,
      'total': instance.total,
      'rapid': instance.rapid,
      'failed': instance.failed,
      'percent': instance.percent,
      'message': instance.message,
    };

_CollectionCover _$CollectionCoverFromJson(Map<String, dynamic> json) =>
    _CollectionCover(
      url: json['url'] as String? ?? "",
      blur: json['blur'] as String?,
    );

Map<String, dynamic> _$CollectionCoverToJson(_CollectionCover instance) =>
    <String, dynamic>{'url': instance.url, 'blur': instance.blur};

_CollectionItemsPayload _$CollectionItemsPayloadFromJson(
  Map<String, dynamic> json,
) => _CollectionItemsPayload(
  mediaItemIds:
      (json['mediaItemIds'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList() ??
      const [],
);

Map<String, dynamic> _$CollectionItemsPayloadToJson(
  _CollectionItemsPayload instance,
) => <String, dynamic>{'mediaItemIds': instance.mediaItemIds};

_CollectionPayload _$CollectionPayloadFromJson(Map<String, dynamic> json) =>
    _CollectionPayload(
      name: json['name'] as String?,
      libraryId: (json['libraryId'] as num?)?.toInt(),
      rules: json['rules'],
      sort: json['sort'] as String?,
      visibility: json['visibility'] as String?,
      hidden: json['hidden'] as bool?,
      itemIds: (json['itemIds'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList(),
      snapshot: json['snapshot'] as bool?,
    );

Map<String, dynamic> _$CollectionPayloadToJson(_CollectionPayload instance) =>
    <String, dynamic>{
      'name': instance.name,
      'libraryId': instance.libraryId,
      'rules': instance.rules,
      'sort': instance.sort,
      'visibility': instance.visibility,
      'hidden': instance.hidden,
      'itemIds': instance.itemIds,
      'snapshot': instance.snapshot,
    };

_CollectionSeriesView _$CollectionSeriesViewFromJson(
  Map<String, dynamic> json,
) => _CollectionSeriesView(
  seriesName: json['series_name'] as String?,
  ownedCount: (json['owned_count'] as num?)?.toInt() ?? 0,
  total: (json['total'] as num?)?.toInt() ?? 0,
  imageUrl: json['image_url'] as String?,
  parts:
      (json['parts'] as List<dynamic>?)
          ?.map((e) => SeriesPartView.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  available: json['available'] as bool? ?? false,
);

Map<String, dynamic> _$CollectionSeriesViewToJson(
  _CollectionSeriesView instance,
) => <String, dynamic>{
  'series_name': instance.seriesName,
  'owned_count': instance.ownedCount,
  'total': instance.total,
  'image_url': instance.imageUrl,
  'parts': instance.parts,
  'available': instance.available,
};

_CollectionTitles _$CollectionTitlesFromJson(Map<String, dynamic> json) =>
    _CollectionTitles(
      collection: json['collection'] == null
          ? const DiscoveryCollectionInfo()
          : DiscoveryCollectionInfo.fromJson(
              json['collection'] as Map<String, dynamic>,
            ),
      titles:
          (json['titles'] as List<dynamic>?)
              ?.map((e) => DiscoveredTitle.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      page: (json['page'] as num?)?.toInt() ?? 1,
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 1,
      totalResults: (json['totalResults'] as num?)?.toInt() ?? 0,
      hasMore: json['hasMore'] as bool? ?? false,
    );

Map<String, dynamic> _$CollectionTitlesToJson(_CollectionTitles instance) =>
    <String, dynamic>{
      'collection': instance.collection,
      'titles': instance.titles,
      'page': instance.page,
      'totalPages': instance.totalPages,
      'totalResults': instance.totalResults,
      'hasMore': instance.hasMore,
    };

_CollectionView _$CollectionViewFromJson(Map<String, dynamic> json) =>
    _CollectionView(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? "",
      libraryId: (json['library_id'] as num?)?.toInt(),
      rules: json['rules'] as List<dynamic>? ?? const [],
      sort: json['sort'] as String? ?? "",
      visibility: json['visibility'] as String? ?? "",
      builtin: json['builtin'] as String?,
      editable: json['editable'] as bool? ?? false,
      manageable: json['manageable'] as bool? ?? false,
      ruleDriven: json['rule_driven'] as bool? ?? false,
      itemCount: (json['item_count'] as num?)?.toInt() ?? 0,
      coverItemId: (json['cover_item_id'] as num?)?.toInt(),
      covers:
          (json['covers'] as List<dynamic>?)
              ?.map((e) => CollectionCover.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      kind: json['kind'] as String? ?? "",
      hidden: json['hidden'] as bool? ?? false,
      position: (json['position'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$CollectionViewToJson(_CollectionView instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'library_id': instance.libraryId,
      'rules': instance.rules,
      'sort': instance.sort,
      'visibility': instance.visibility,
      'builtin': instance.builtin,
      'editable': instance.editable,
      'manageable': instance.manageable,
      'rule_driven': instance.ruleDriven,
      'item_count': instance.itemCount,
      'cover_item_id': instance.coverItemId,
      'covers': instance.covers,
      'kind': instance.kind,
      'hidden': instance.hidden,
      'position': instance.position,
    };

_ConfiguredSite _$ConfiguredSiteFromJson(Map<String, dynamic> json) =>
    _ConfiguredSite(
      siteId: json['siteId'] as String? ?? "",
      authType: json['authType'] as String? ?? "",
      enabled: json['enabled'] as bool? ?? true,
      status: json['status'] as String? ?? "",
      usable: json['usable'] as bool? ?? false,
      isProtected: json['protected'] as bool? ?? false,
      boostEnabled: json['boostEnabled'] as bool? ?? false,
      boostPaused: json['boostPaused'] as bool? ?? false,
      boostBudgetBytes: (json['boostBudgetBytes'] as num?)?.toInt() ?? 0,
      boostHoldDays: (json['boostHoldDays'] as num?)?.toInt(),
      boostDownloaderId: (json['boostDownloaderId'] as num?)?.toInt(),
      lastVerifiedAt: json['lastVerifiedAt'] as String?,
      lastCheckedAt: json['lastCheckedAt'] as String?,
      lastError: json['lastError'] as String?,
      profile: json['profile'] == null
          ? null
          : SiteProfile.fromJson(json['profile'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$ConfiguredSiteToJson(_ConfiguredSite instance) =>
    <String, dynamic>{
      'siteId': instance.siteId,
      'authType': instance.authType,
      'enabled': instance.enabled,
      'status': instance.status,
      'usable': instance.usable,
      'protected': instance.isProtected,
      'boostEnabled': instance.boostEnabled,
      'boostPaused': instance.boostPaused,
      'boostBudgetBytes': instance.boostBudgetBytes,
      'boostHoldDays': instance.boostHoldDays,
      'boostDownloaderId': instance.boostDownloaderId,
      'lastVerifiedAt': instance.lastVerifiedAt,
      'lastCheckedAt': instance.lastCheckedAt,
      'lastError': instance.lastError,
      'profile': instance.profile,
    };

_CreateAdminRequest _$CreateAdminRequestFromJson(Map<String, dynamic> json) =>
    _CreateAdminRequest(
      username: json['username'] as String? ?? '',
      password: json['password'] as String? ?? '',
    );

Map<String, dynamic> _$CreateAdminRequestToJson(_CreateAdminRequest instance) =>
    <String, dynamic>{
      'username': instance.username,
      'password': instance.password,
    };

_DeleteFollowUpView _$DeleteFollowUpViewFromJson(Map<String, dynamic> json) =>
    _DeleteFollowUpView(
      option: json['option'] as String? ?? "",
      label: json['label'] as String? ?? "",
      jobId: json['jobId'] as String? ?? '',
    );

Map<String, dynamic> _$DeleteFollowUpViewToJson(_DeleteFollowUpView instance) =>
    <String, dynamic>{
      'option': instance.option,
      'label': instance.label,
      'jobId': instance.jobId,
    };

_DeleteOptionView _$DeleteOptionViewFromJson(Map<String, dynamic> json) =>
    _DeleteOptionView(
      key: json['key'] as String? ?? '',
      label: json['label'] as String? ?? '',
      help: json['help'] as String? ?? "",
      available: json['available'] as bool? ?? true,
      reason: json['reason'] as String?,
      lines:
          (json['lines'] as List<dynamic>?)
              ?.map(
                (e) =>
                    DeletePreviewLineView.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const [],
    );

Map<String, dynamic> _$DeleteOptionViewToJson(_DeleteOptionView instance) =>
    <String, dynamic>{
      'key': instance.key,
      'label': instance.label,
      'help': instance.help,
      'available': instance.available,
      'reason': instance.reason,
      'lines': instance.lines,
    };

_DeletePreviewLineView _$DeletePreviewLineViewFromJson(
  Map<String, dynamic> json,
) => _DeletePreviewLineView(
  text: json['text'] as String? ?? '',
  tone: json['tone'] as String? ?? "info",
);

Map<String, dynamic> _$DeletePreviewLineViewToJson(
  _DeletePreviewLineView instance,
) => <String, dynamic>{'text': instance.text, 'tone': instance.tone};

_DetachPayload _$DetachPayloadFromJson(Map<String, dynamic> json) =>
    _DetachPayload(
      fileIds:
          (json['fileIds'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [],
    );

Map<String, dynamic> _$DetachPayloadToJson(_DetachPayload instance) =>
    <String, dynamic>{'fileIds': instance.fileIds};

_DeviceAuthorizeRequest _$DeviceAuthorizeRequestFromJson(
  Map<String, dynamic> json,
) => _DeviceAuthorizeRequest(
  clientType: json['client_type'] as String? ?? '',
  clientName: json['client_name'] as String? ?? '',
  installationId: json['installation_id'] as String?,
  platform: json['platform'] as String?,
  clientVersion: json['client_version'] as String?,
);

Map<String, dynamic> _$DeviceAuthorizeRequestToJson(
  _DeviceAuthorizeRequest instance,
) => <String, dynamic>{
  'client_type': instance.clientType,
  'client_name': instance.clientName,
  'installation_id': instance.installationId,
  'platform': instance.platform,
  'client_version': instance.clientVersion,
};

_DeviceAuthorizeView _$DeviceAuthorizeViewFromJson(Map<String, dynamic> json) =>
    _DeviceAuthorizeView(
      userCode: json['user_code'] as String? ?? "",
      deviceCode: json['device_code'] as String? ?? "",
      verificationUri: json['verification_uri'] as String? ?? "",
      verificationUriComplete:
          json['verification_uri_complete'] as String? ?? "",
      interval: (json['interval'] as num?)?.toInt() ?? 0,
      expiresIn: (json['expires_in'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$DeviceAuthorizeViewToJson(
  _DeviceAuthorizeView instance,
) => <String, dynamic>{
  'user_code': instance.userCode,
  'device_code': instance.deviceCode,
  'verification_uri': instance.verificationUri,
  'verification_uri_complete': instance.verificationUriComplete,
  'interval': instance.interval,
  'expires_in': instance.expiresIn,
};

_DeviceBrief _$DeviceBriefFromJson(Map<String, dynamic> json) => _DeviceBrief(
  id: json['id'] as String? ?? "",
  kind: json['kind'] as String? ?? "",
  name: json['name'] as String? ?? "",
);

Map<String, dynamic> _$DeviceBriefToJson(_DeviceBrief instance) =>
    <String, dynamic>{
      'id': instance.id,
      'kind': instance.kind,
      'name': instance.name,
    };

_DeviceCleanupItem _$DeviceCleanupItemFromJson(Map<String, dynamic> json) =>
    _DeviceCleanupItem(
      id: json['id'] as String? ?? "",
      name: json['name'] as String? ?? "",
      ownerNickname: json['ownerNickname'] as String? ?? "",
    );

Map<String, dynamic> _$DeviceCleanupItemToJson(_DeviceCleanupItem instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'ownerNickname': instance.ownerNickname,
    };

_DeviceCleanupRequest _$DeviceCleanupRequestFromJson(
  Map<String, dynamic> json,
) => _DeviceCleanupRequest(
  inactiveDays: (json['inactiveDays'] as num?)?.toInt() ?? 0,
  all: json['all'] as bool? ?? false,
  dryRun: json['dryRun'] as bool? ?? false,
);

Map<String, dynamic> _$DeviceCleanupRequestToJson(
  _DeviceCleanupRequest instance,
) => <String, dynamic>{
  'inactiveDays': instance.inactiveDays,
  'all': instance.all,
  'dryRun': instance.dryRun,
};

_DeviceCleanupView _$DeviceCleanupViewFromJson(Map<String, dynamic> json) =>
    _DeviceCleanupView(
      devices:
          (json['devices'] as List<dynamic>?)
              ?.map(
                (e) => DeviceCleanupItem.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const [],
    );

Map<String, dynamic> _$DeviceCleanupViewToJson(_DeviceCleanupView instance) =>
    <String, dynamic>{'devices': instance.devices};

_DeviceClientInfo _$DeviceClientInfoFromJson(Map<String, dynamic> json) =>
    _DeviceClientInfo(
      kind: json['kind'] as String? ?? '',
      installationId: json['installation_id'] as String? ?? '',
      name: json['name'] as String?,
      platform: json['platform'] as String?,
      clientVersion: json['client_version'] as String?,
    );

Map<String, dynamic> _$DeviceClientInfoToJson(_DeviceClientInfo instance) =>
    <String, dynamic>{
      'kind': instance.kind,
      'installation_id': instance.installationId,
      'name': instance.name,
      'platform': instance.platform,
      'client_version': instance.clientVersion,
    };

_DeviceLoginRequest _$DeviceLoginRequestFromJson(Map<String, dynamic> json) =>
    _DeviceLoginRequest(
      username: json['username'] as String? ?? '',
      password: json['password'] as String? ?? '',
      client: json['client'] == null
          ? const DeviceClientInfo()
          : DeviceClientInfo.fromJson(json['client'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$DeviceLoginRequestToJson(_DeviceLoginRequest instance) =>
    <String, dynamic>{
      'username': instance.username,
      'password': instance.password,
      'client': instance.client,
    };

_DeviceLoginView _$DeviceLoginViewFromJson(Map<String, dynamic> json) =>
    _DeviceLoginView(
      token: json['token'] as String? ?? "",
      device: json['device'] == null
          ? const LoginDeviceView()
          : LoginDeviceView.fromJson(json['device'] as Map<String, dynamic>),
      session: json['session'] == null
          ? const SessionView()
          : SessionView.fromJson(json['session'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$DeviceLoginViewToJson(_DeviceLoginView instance) =>
    <String, dynamic>{
      'token': instance.token,
      'device': instance.device,
      'session': instance.session,
    };

_DevicePushView _$DevicePushViewFromJson(Map<String, dynamic> json) =>
    _DevicePushView(
      status: json['status'] as String? ?? "",
      statusText: json['status_text'] as String? ?? "",
    );

Map<String, dynamic> _$DevicePushViewToJson(_DevicePushView instance) =>
    <String, dynamic>{
      'status': instance.status,
      'status_text': instance.statusText,
    };

_DeviceRenameRequest _$DeviceRenameRequestFromJson(Map<String, dynamic> json) =>
    _DeviceRenameRequest(name: json['name'] as String? ?? '');

Map<String, dynamic> _$DeviceRenameRequestToJson(
  _DeviceRenameRequest instance,
) => <String, dynamic>{'name': instance.name};

_DeviceRequestView _$DeviceRequestViewFromJson(Map<String, dynamic> json) =>
    _DeviceRequestView(
      userCode: json['userCode'] as String? ?? "",
      clientType: json['clientType'] as String? ?? "",
      clientName: json['clientName'] as String? ?? "",
      sourceIp: json['sourceIp'] as String? ?? "",
      expiresIn: (json['expiresIn'] as num?)?.toInt() ?? 0,
      platform: json['platform'] as String?,
      clientVersion: json['clientVersion'] as String?,
      requiresAdmin: json['requiresAdmin'] as bool? ?? false,
    );

Map<String, dynamic> _$DeviceRequestViewToJson(_DeviceRequestView instance) =>
    <String, dynamic>{
      'userCode': instance.userCode,
      'clientType': instance.clientType,
      'clientName': instance.clientName,
      'sourceIp': instance.sourceIp,
      'expiresIn': instance.expiresIn,
      'platform': instance.platform,
      'clientVersion': instance.clientVersion,
      'requiresAdmin': instance.requiresAdmin,
    };

_DeviceTokenRequest _$DeviceTokenRequestFromJson(Map<String, dynamic> json) =>
    _DeviceTokenRequest(deviceCode: json['device_code'] as String? ?? '');

Map<String, dynamic> _$DeviceTokenRequestToJson(_DeviceTokenRequest instance) =>
    <String, dynamic>{'device_code': instance.deviceCode};

_DeviceTokenView _$DeviceTokenViewFromJson(Map<String, dynamic> json) =>
    _DeviceTokenView(
      token: json['token'] as String? ?? "",
      clientName: json['client_name'] as String? ?? "",
      clientType: json['client_type'] as String? ?? "",
      grantedBy: json['granted_by'] as String? ?? "",
    );

Map<String, dynamic> _$DeviceTokenViewToJson(_DeviceTokenView instance) =>
    <String, dynamic>{
      'token': instance.token,
      'client_name': instance.clientName,
      'client_type': instance.clientType,
      'granted_by': instance.grantedBy,
    };

_DirectorView _$DirectorViewFromJson(Map<String, dynamic> json) =>
    _DirectorView(
      name: json['name'] as String? ?? "",
      thumbUrl: json['thumb_url'] as String?,
      tmdbPersonId: (json['tmdb_person_id'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$DirectorViewToJson(_DirectorView instance) =>
    <String, dynamic>{
      'name': instance.name,
      'thumb_url': instance.thumbUrl,
      'tmdb_person_id': instance.tmdbPersonId,
    };

_DiscoveredTitle _$DiscoveredTitleFromJson(Map<String, dynamic> json) =>
    _DiscoveredTitle(
      titleRef: json['titleRef'] as String? ?? "",
      provider: json['provider'] as String? ?? "",
      externalId: json['externalId'] as String? ?? "",
      mediaType: json['mediaType'] as String?,
      title: json['title'] as String? ?? "",
      originalTitle: json['originalTitle'] as String? ?? "",
      releaseYear: (json['releaseYear'] as num?)?.toInt(),
      providerRating: (json['providerRating'] as num?)?.toDouble() ?? 0.0,
      genres:
          (json['genres'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      extentLabel: json['extentLabel'] as String? ?? "",
      overview: json['overview'] as String? ?? "",
      posterUrl: json['posterUrl'] as String?,
      backdropUrl: json['backdropUrl'] as String?,
      libraryStatus: json['libraryStatus'] == null
          ? null
          : MediaLibraryStatus.fromJson(
              json['libraryStatus'] as Map<String, dynamic>,
            ),
    );

Map<String, dynamic> _$DiscoveredTitleToJson(_DiscoveredTitle instance) =>
    <String, dynamic>{
      'titleRef': instance.titleRef,
      'provider': instance.provider,
      'externalId': instance.externalId,
      'mediaType': instance.mediaType,
      'title': instance.title,
      'originalTitle': instance.originalTitle,
      'releaseYear': instance.releaseYear,
      'providerRating': instance.providerRating,
      'genres': instance.genres,
      'extentLabel': instance.extentLabel,
      'overview': instance.overview,
      'posterUrl': instance.posterUrl,
      'backdropUrl': instance.backdropUrl,
      'libraryStatus': instance.libraryStatus,
    };

_DiscoveryCollectionInfo _$DiscoveryCollectionInfoFromJson(
  Map<String, dynamic> json,
) => _DiscoveryCollectionInfo(
  collectionRef: json['collectionRef'] as String? ?? "",
  name: json['name'] as String? ?? "",
  description: json['description'] as String? ?? "",
  isRanked: json['isRanked'] as bool? ?? false,
  defaultLimit: (json['defaultLimit'] as num?)?.toInt() ?? 20,
  supportsFullListing: json['supportsFullListing'] as bool? ?? false,
);

Map<String, dynamic> _$DiscoveryCollectionInfoToJson(
  _DiscoveryCollectionInfo instance,
) => <String, dynamic>{
  'collectionRef': instance.collectionRef,
  'name': instance.name,
  'description': instance.description,
  'isRanked': instance.isRanked,
  'defaultLimit': instance.defaultLimit,
  'supportsFullListing': instance.supportsFullListing,
};

_DiscoveryPage _$DiscoveryPageFromJson(Map<String, dynamic> json) =>
    _DiscoveryPage(
      provider: json['provider'] as String? ?? "tmdb",
      mediaType: json['mediaType'] as String? ?? "movie",
      sections:
          (json['sections'] as List<dynamic>?)
              ?.map((e) => DiscoverySection.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$DiscoveryPageToJson(_DiscoveryPage instance) =>
    <String, dynamic>{
      'provider': instance.provider,
      'mediaType': instance.mediaType,
      'sections': instance.sections,
    };

_DiscoverySection _$DiscoverySectionFromJson(Map<String, dynamic> json) =>
    _DiscoverySection(
      collectionRef: json['collectionRef'] as String? ?? "",
      title: json['title'] as String? ?? "",
      presentation: json['presentation'] as String? ?? "poster-row",
      previewLimit: (json['previewLimit'] as num?)?.toInt() ?? 12,
      supportsFullListing: json['supportsFullListing'] as bool? ?? false,
    );

Map<String, dynamic> _$DiscoverySectionToJson(_DiscoverySection instance) =>
    <String, dynamic>{
      'collectionRef': instance.collectionRef,
      'title': instance.title,
      'presentation': instance.presentation,
      'previewLimit': instance.previewLimit,
      'supportsFullListing': instance.supportsFullListing,
    };

_DispatchPreviewView _$DispatchPreviewViewFromJson(Map<String, dynamic> json) =>
    _DispatchPreviewView(
      mode: json['mode'] as String? ?? "",
      path: json['path'] as String?,
      entryDir: json['entry_dir'] as String?,
      stagingPath: json['staging_path'] as String?,
      libraryId: (json['library_id'] as num?)?.toInt(),
      libraryName: json['library_name'] as String?,
      downloaderName: json['downloader_name'] as String?,
      routeMatched: json['route_matched'] as bool?,
      routeReasonKey: json['route_reason_key'] as String?,
      routeReasonParams: json['route_reason_params'] as Map<String, dynamic>?,
      routeReason: json['route_reason'] as String?,
      ruleSetId: (json['rule_set_id'] as num?)?.toInt(),
      ruleSetName: json['rule_set_name'] as String?,
      ruleSetMatched: json['rule_set_matched'] as bool?,
      ruleSetReasonKey: json['rule_set_reason_key'] as String?,
      ruleSetReasonParams:
          json['rule_set_reason_params'] as Map<String, dynamic>?,
      ruleSetReason: json['rule_set_reason'] as String?,
      ok: json['ok'] as bool? ?? false,
      warningKey: json['warning_key'] as String?,
      warningParams: json['warning_params'] as Map<String, dynamic>?,
      warning: json['warning'] as String?,
    );

Map<String, dynamic> _$DispatchPreviewViewToJson(
  _DispatchPreviewView instance,
) => <String, dynamic>{
  'mode': instance.mode,
  'path': instance.path,
  'entry_dir': instance.entryDir,
  'staging_path': instance.stagingPath,
  'library_id': instance.libraryId,
  'library_name': instance.libraryName,
  'downloader_name': instance.downloaderName,
  'route_matched': instance.routeMatched,
  'route_reason_key': instance.routeReasonKey,
  'route_reason_params': instance.routeReasonParams,
  'route_reason': instance.routeReason,
  'rule_set_id': instance.ruleSetId,
  'rule_set_name': instance.ruleSetName,
  'rule_set_matched': instance.ruleSetMatched,
  'rule_set_reason_key': instance.ruleSetReasonKey,
  'rule_set_reason_params': instance.ruleSetReasonParams,
  'rule_set_reason': instance.ruleSetReason,
  'ok': instance.ok,
  'warning_key': instance.warningKey,
  'warning_params': instance.warningParams,
  'warning': instance.warning,
};

_DoubanEpisodesView _$DoubanEpisodesViewFromJson(Map<String, dynamic> json) =>
    _DoubanEpisodesView(
      seasonNumber: (json['season_number'] as num?)?.toInt() ?? 0,
      doubanCount: (json['douban_count'] as num?)?.toInt() ?? 0,
      tmdbCount: (json['tmdb_count'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$DoubanEpisodesViewToJson(_DoubanEpisodesView instance) =>
    <String, dynamic>{
      'season_number': instance.seasonNumber,
      'douban_count': instance.doubanCount,
      'tmdb_count': instance.tmdbCount,
    };

_DownloadSubmitRequest _$DownloadSubmitRequestFromJson(
  Map<String, dynamic> json,
) => _DownloadSubmitRequest(
  siteId: json['siteId'] as String? ?? '',
  downloadUrl: json['downloadUrl'] as String? ?? '',
  torrentId: json['torrentId'] as String?,
  libraryId: (json['libraryId'] as num?)?.toInt(),
  title: json['title'] as String?,
  year: (json['year'] as num?)?.toInt(),
  subtitle: json['subtitle'] as String?,
  autoRoute: json['autoRoute'] as bool? ?? false,
  mediaKind: json['mediaKind'] as String?,
  tmdbId: (json['tmdbId'] as num?)?.toInt(),
  savePath: json['savePath'] as String?,
  downloaderId: (json['downloaderId'] as num?)?.toInt(),
  category: json['category'] as String?,
);

Map<String, dynamic> _$DownloadSubmitRequestToJson(
  _DownloadSubmitRequest instance,
) => <String, dynamic>{
  'siteId': instance.siteId,
  'downloadUrl': instance.downloadUrl,
  'torrentId': instance.torrentId,
  'libraryId': instance.libraryId,
  'title': instance.title,
  'year': instance.year,
  'subtitle': instance.subtitle,
  'autoRoute': instance.autoRoute,
  'mediaKind': instance.mediaKind,
  'tmdbId': instance.tmdbId,
  'savePath': instance.savePath,
  'downloaderId': instance.downloaderId,
  'category': instance.category,
};

_DownloadSubmitView _$DownloadSubmitViewFromJson(Map<String, dynamic> json) =>
    _DownloadSubmitView(
      infoHash: json['infoHash'] as String?,
      name: json['name'] as String? ?? "",
      alreadyExists: json['alreadyExists'] as bool? ?? false,
      downloaderId: (json['downloaderId'] as num?)?.toInt() ?? 0,
      downloaderName: json['downloaderName'] as String? ?? "",
      savePath: json['savePath'] as String?,
    );

Map<String, dynamic> _$DownloadSubmitViewToJson(_DownloadSubmitView instance) =>
    <String, dynamic>{
      'infoHash': instance.infoHash,
      'name': instance.name,
      'alreadyExists': instance.alreadyExists,
      'downloaderId': instance.downloaderId,
      'downloaderName': instance.downloaderName,
      'savePath': instance.savePath,
    };

_DownloadTargetPrefView _$DownloadTargetPrefViewFromJson(
  Map<String, dynamic> json,
) => _DownloadTargetPrefView(
  category: json['category'] as String? ?? "other",
  kind: json['kind'] as String? ?? "default",
  savePath: json['savePath'] as String?,
  downloaderId: (json['downloaderId'] as num?)?.toInt(),
  downloaderName: json['downloaderName'] as String?,
  updatedAt: json['updatedAt'] as String?,
);

Map<String, dynamic> _$DownloadTargetPrefViewToJson(
  _DownloadTargetPrefView instance,
) => <String, dynamic>{
  'category': instance.category,
  'kind': instance.kind,
  'savePath': instance.savePath,
  'downloaderId': instance.downloaderId,
  'downloaderName': instance.downloaderName,
  'updatedAt': instance.updatedAt,
};

_DownloadTask _$DownloadTaskFromJson(Map<String, dynamic> json) =>
    _DownloadTask(
      id: json['id'] as String? ?? '',
      infoHash: json['infoHash'] as String? ?? "",
      name: json['name'] as String?,
      downloaderId: (json['downloaderId'] as num?)?.toInt(),
      downloaderName: json['downloaderName'] as String?,
      progress: (json['progress'] as num?)?.toDouble(),
      sizeBytes: (json['sizeBytes'] as num?)?.toInt(),
      dlspeedBytes: (json['dlspeedBytes'] as num?)?.toInt(),
      upspeedBytes: (json['upspeedBytes'] as num?)?.toInt(),
      etaSeconds: (json['etaSeconds'] as num?)?.toInt(),
      state: json['state'] as String? ?? "",
      source: json['source'] as String? ?? "",
      siteName: json['siteName'] as String?,
      resolution: json['resolution'] as String?,
      mediaSource: json['mediaSource'] as String?,
      mediaTitle: json['mediaTitle'] as String?,
      mediaKind: json['mediaKind'] as String?,
      posterUrl: json['posterUrl'] as String?,
      errorMessage: json['errorMessage'] as String?,
      landingError: json['landingError'] as String?,
      canReplace: json['canReplace'] as bool? ?? false,
      mediaItemId: (json['mediaItemId'] as num?)?.toInt(),
      subscriptions:
          (json['subscriptions'] as List<dynamic>?)
              ?.map(
                (e) => DownloadTaskSubscription.fromJson(
                  e as Map<String, dynamic>,
                ),
              )
              .toList() ??
          const [],
    );

Map<String, dynamic> _$DownloadTaskToJson(_DownloadTask instance) =>
    <String, dynamic>{
      'id': instance.id,
      'infoHash': instance.infoHash,
      'name': instance.name,
      'downloaderId': instance.downloaderId,
      'downloaderName': instance.downloaderName,
      'progress': instance.progress,
      'sizeBytes': instance.sizeBytes,
      'dlspeedBytes': instance.dlspeedBytes,
      'upspeedBytes': instance.upspeedBytes,
      'etaSeconds': instance.etaSeconds,
      'state': instance.state,
      'source': instance.source,
      'siteName': instance.siteName,
      'resolution': instance.resolution,
      'mediaSource': instance.mediaSource,
      'mediaTitle': instance.mediaTitle,
      'mediaKind': instance.mediaKind,
      'posterUrl': instance.posterUrl,
      'errorMessage': instance.errorMessage,
      'landingError': instance.landingError,
      'canReplace': instance.canReplace,
      'mediaItemId': instance.mediaItemId,
      'subscriptions': instance.subscriptions,
    };

_DownloadTaskList _$DownloadTaskListFromJson(Map<String, dynamic> json) =>
    _DownloadTaskList(
      items:
          (json['items'] as List<dynamic>?)
              ?.map((e) => DownloadTask.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$DownloadTaskListToJson(_DownloadTaskList instance) =>
    <String, dynamic>{'items': instance.items};

_DownloadTaskSubscription _$DownloadTaskSubscriptionFromJson(
  Map<String, dynamic> json,
) => _DownloadTaskSubscription(
  id: (json['id'] as num?)?.toInt() ?? 0,
  mediaItemId: (json['mediaItemId'] as num?)?.toInt() ?? 0,
  mediaTitle: json['mediaTitle'] as String? ?? "",
  mediaKind: json['mediaKind'] as String? ?? "",
  posterUrl: json['posterUrl'] as String?,
  purpose: json['purpose'] as String? ?? "download",
  units:
      (json['units'] as List<dynamic>?)
          ?.map((e) => DownloadTaskUnit.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
);

Map<String, dynamic> _$DownloadTaskSubscriptionToJson(
  _DownloadTaskSubscription instance,
) => <String, dynamic>{
  'id': instance.id,
  'mediaItemId': instance.mediaItemId,
  'mediaTitle': instance.mediaTitle,
  'mediaKind': instance.mediaKind,
  'posterUrl': instance.posterUrl,
  'purpose': instance.purpose,
  'units': instance.units,
};

_DownloadTaskUnit _$DownloadTaskUnitFromJson(Map<String, dynamic> json) =>
    _DownloadTaskUnit(
      seasonNumber: (json['seasonNumber'] as num?)?.toInt() ?? 0,
      episodeNumber: (json['episodeNumber'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? "grabbed",
      replaced: json['replaced'] as bool? ?? false,
      contentMissing: json['contentMissing'] as bool? ?? false,
    );

Map<String, dynamic> _$DownloadTaskUnitToJson(_DownloadTaskUnit instance) =>
    <String, dynamic>{
      'seasonNumber': instance.seasonNumber,
      'episodeNumber': instance.episodeNumber,
      'status': instance.status,
      'replaced': instance.replaced,
      'contentMissing': instance.contentMissing,
    };

_DownloadUnitView _$DownloadUnitViewFromJson(Map<String, dynamic> json) =>
    _DownloadUnitView(
      seasonNumber: (json['seasonNumber'] as num?)?.toInt() ?? 0,
      episodeNumber: (json['episodeNumber'] as num?)?.toInt() ?? 0,
      progress: (json['progress'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$DownloadUnitViewToJson(_DownloadUnitView instance) =>
    <String, dynamic>{
      'seasonNumber': instance.seasonNumber,
      'episodeNumber': instance.episodeNumber,
      'progress': instance.progress,
    };

_DownloaderDeleteResult _$DownloaderDeleteResultFromJson(
  Map<String, dynamic> json,
) => _DownloaderDeleteResult(
  boostDisabledSites:
      (json['boostDisabledSites'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
);

Map<String, dynamic> _$DownloaderDeleteResultToJson(
  _DownloaderDeleteResult instance,
) => <String, dynamic>{'boostDisabledSites': instance.boostDisabledSites};

_DownloaderLimits _$DownloaderLimitsFromJson(Map<String, dynamic> json) =>
    _DownloaderLimits(
      downloadLimitBytes: (json['downloadLimitBytes'] as num?)?.toInt(),
      uploadLimitBytes: (json['uploadLimitBytes'] as num?)?.toInt(),
      altSpeedEnabled: json['altSpeedEnabled'] as bool?,
      queueEnabled: json['queueEnabled'] as bool?,
      maxActiveDownloads: (json['maxActiveDownloads'] as num?)?.toInt(),
      maxActiveUploads: (json['maxActiveUploads'] as num?)?.toInt(),
      maxActiveTorrents: (json['maxActiveTorrents'] as num?)?.toInt(),
    );

Map<String, dynamic> _$DownloaderLimitsToJson(_DownloaderLimits instance) =>
    <String, dynamic>{
      'downloadLimitBytes': instance.downloadLimitBytes,
      'uploadLimitBytes': instance.uploadLimitBytes,
      'altSpeedEnabled': instance.altSpeedEnabled,
      'queueEnabled': instance.queueEnabled,
      'maxActiveDownloads': instance.maxActiveDownloads,
      'maxActiveUploads': instance.maxActiveUploads,
      'maxActiveTorrents': instance.maxActiveTorrents,
    };

_DownloaderPayload _$DownloaderPayloadFromJson(Map<String, dynamic> json) =>
    _DownloaderPayload(
      name: json['name'] as String? ?? '',
      clientType: json['clientType'] as String? ?? '',
      url: json['url'] as String? ?? '',
      username: json['username'] as String?,
      password: json['password'] as String?,
      savePath: json['savePath'] as String?,
      pathMappings: (json['pathMappings'] as List<dynamic>?)
          ?.map((e) => PathMapping.fromJson(e as Map<String, dynamic>))
          .toList(),
      enabled: json['enabled'] as bool? ?? true,
    );

Map<String, dynamic> _$DownloaderPayloadToJson(_DownloaderPayload instance) =>
    <String, dynamic>{
      'name': instance.name,
      'clientType': instance.clientType,
      'url': instance.url,
      'username': instance.username,
      'password': instance.password,
      'savePath': instance.savePath,
      'pathMappings': instance.pathMappings,
      'enabled': instance.enabled,
    };

_DownloaderStatusPayload _$DownloaderStatusPayloadFromJson(
  Map<String, dynamic> json,
) => _DownloaderStatusPayload(enabled: json['enabled'] as bool? ?? false);

Map<String, dynamic> _$DownloaderStatusPayloadToJson(
  _DownloaderStatusPayload instance,
) => <String, dynamic>{'enabled': instance.enabled};

_DownloaderTypeInfo _$DownloaderTypeInfoFromJson(Map<String, dynamic> json) =>
    _DownloaderTypeInfo(
      type: json['type'] as String? ?? "",
      title: json['title'] as String? ?? "",
      connection: json['connection'] as String? ?? "",
      urlLabel: json['urlLabel'] as String?,
      urlPlaceholder: json['urlPlaceholder'] as String?,
      needsUsername: json['needsUsername'] as bool? ?? false,
      help: json['help'] as String?,
    );

Map<String, dynamic> _$DownloaderTypeInfoToJson(_DownloaderTypeInfo instance) =>
    <String, dynamic>{
      'type': instance.type,
      'title': instance.title,
      'connection': instance.connection,
      'urlLabel': instance.urlLabel,
      'urlPlaceholder': instance.urlPlaceholder,
      'needsUsername': instance.needsUsername,
      'help': instance.help,
    };

_DownloaderView _$DownloaderViewFromJson(Map<String, dynamic> json) =>
    _DownloaderView(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? "",
      clientType: json['clientType'] as String? ?? "",
      url: json['url'] as String? ?? "",
      username: json['username'] as String?,
      savePath: json['savePath'] as String?,
      pathMappings: (json['pathMappings'] as List<dynamic>?)
          ?.map((e) => PathMapping.fromJson(e as Map<String, dynamic>))
          .toList(),
      enabled: json['enabled'] as bool? ?? true,
      isDefault: json['isDefault'] as bool? ?? false,
      status: json['status'] as String? ?? "",
      usable: json['usable'] as bool? ?? false,
      version: json['version'] as String?,
      lastError: json['lastError'] as String?,
      lastCheckedAt: json['lastCheckedAt'] as String?,
      pathHealth:
          (json['pathHealth'] as List<dynamic>?)
              ?.map((e) => PathHealthView.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      pathsHealthy: json['pathsHealthy'] as bool? ?? true,
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
    );

Map<String, dynamic> _$DownloaderViewToJson(_DownloaderView instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'clientType': instance.clientType,
      'url': instance.url,
      'username': instance.username,
      'savePath': instance.savePath,
      'pathMappings': instance.pathMappings,
      'enabled': instance.enabled,
      'isDefault': instance.isDefault,
      'status': instance.status,
      'usable': instance.usable,
      'version': instance.version,
      'lastError': instance.lastError,
      'lastCheckedAt': instance.lastCheckedAt,
      'pathHealth': instance.pathHealth,
      'pathsHealthy': instance.pathsHealthy,
      'createdAt': instance.createdAt,
      'updatedAt': instance.updatedAt,
    };

_EgressService _$EgressServiceFromJson(Map<String, dynamic> json) =>
    _EgressService(
      id: json['id'] as String? ?? "",
      label: json['label'] as String? ?? "",
      description: json['description'] as String? ?? "",
    );

Map<String, dynamic> _$EgressServiceToJson(_EgressService instance) =>
    <String, dynamic>{
      'id': instance.id,
      'label': instance.label,
      'description': instance.description,
    };

_EpisodeArrivalView _$EpisodeArrivalViewFromJson(Map<String, dynamic> json) =>
    _EpisodeArrivalView(
      episodeNumber: (json['episode_number'] as num?)?.toInt() ?? 0,
      stage: json['stage'] as String? ?? "",
      expectedAt: json['expected_at'] as String?,
    );

Map<String, dynamic> _$EpisodeArrivalViewToJson(_EpisodeArrivalView instance) =>
    <String, dynamic>{
      'episode_number': instance.episodeNumber,
      'stage': instance.stage,
      'expected_at': instance.expectedAt,
    };

_EpisodeCapSpec _$EpisodeCapSpecFromJson(Map<String, dynamic> json) =>
    _EpisodeCapSpec(
      start: (json['start'] as num?)?.toInt() ?? 0,
      end: (json['end'] as num?)?.toInt(),
    );

Map<String, dynamic> _$EpisodeCapSpecToJson(_EpisodeCapSpec instance) =>
    <String, dynamic>{'start': instance.start, 'end': instance.end};

_EpisodeHintView _$EpisodeHintViewFromJson(Map<String, dynamic> json) =>
    _EpisodeHintView(
      seasonNumber: (json['season_number'] as num?)?.toInt() ?? 0,
      tmdbCount: (json['tmdb_count'] as num?)?.toInt() ?? 0,
      floor: (json['floor'] as num?)?.toInt(),
      suggested: (json['suggested'] as num?)?.toInt() ?? 0,
      siteEpisode: (json['site_episode'] as num?)?.toInt(),
      siteTitle: json['site_title'] as String?,
      doubanCount: (json['douban_count'] as num?)?.toInt(),
    );

Map<String, dynamic> _$EpisodeHintViewToJson(_EpisodeHintView instance) =>
    <String, dynamic>{
      'season_number': instance.seasonNumber,
      'tmdb_count': instance.tmdbCount,
      'floor': instance.floor,
      'suggested': instance.suggested,
      'site_episode': instance.siteEpisode,
      'site_title': instance.siteTitle,
      'douban_count': instance.doubanCount,
    };

_EpisodeSeasonView _$EpisodeSeasonViewFromJson(Map<String, dynamic> json) =>
    _EpisodeSeasonView(
      seasonNumber: (json['season_number'] as num?)?.toInt() ?? 0,
      tmdbCount: (json['tmdb_count'] as num?)?.toInt() ?? 0,
      floor: (json['floor'] as num?)?.toInt(),
      window: json['window'] == null
          ? null
          : EpisodeCapSpec.fromJson(json['window'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$EpisodeSeasonViewToJson(_EpisodeSeasonView instance) =>
    <String, dynamic>{
      'season_number': instance.seasonNumber,
      'tmdb_count': instance.tmdbCount,
      'floor': instance.floor,
      'window': instance.window,
    };

_EpisodeView _$EpisodeViewFromJson(Map<String, dynamic> json) => _EpisodeView(
  episodeNumber: (json['episode_number'] as num?)?.toInt() ?? 0,
  name: json['name'] as String?,
  overview: json['overview'] as String?,
  airDate: json['air_date'] as String?,
  stillUrl: json['still_url'] as String?,
  owned: json['owned'] as bool? ?? false,
  fileIds:
      (json['file_ids'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList() ??
      const [],
  positionMs: (json['position_ms'] as num?)?.toInt() ?? 0,
  played: json['played'] as bool? ?? false,
  progressPercent: (json['progress_percent'] as num?)?.toInt(),
  siteSeasonNote: json['site_season_note'] as String?,
);

Map<String, dynamic> _$EpisodeViewToJson(_EpisodeView instance) =>
    <String, dynamic>{
      'episode_number': instance.episodeNumber,
      'name': instance.name,
      'overview': instance.overview,
      'air_date': instance.airDate,
      'still_url': instance.stillUrl,
      'owned': instance.owned,
      'file_ids': instance.fileIds,
      'position_ms': instance.positionMs,
      'played': instance.played,
      'progress_percent': instance.progressPercent,
      'site_season_note': instance.siteSeasonNote,
    };

_EpisodeWindowView _$EpisodeWindowViewFromJson(Map<String, dynamic> json) =>
    _EpisodeWindowView(
      seasonNumber: (json['season_number'] as num?)?.toInt() ?? 0,
      start: (json['start'] as num?)?.toInt() ?? 0,
      end: (json['end'] as num?)?.toInt(),
      total: (json['total'] as num?)?.toInt() ?? 0,
      airing: json['airing'] as bool?,
    );

Map<String, dynamic> _$EpisodeWindowViewToJson(_EpisodeWindowView instance) =>
    <String, dynamic>{
      'season_number': instance.seasonNumber,
      'start': instance.start,
      'end': instance.end,
      'total': instance.total,
      'airing': instance.airing,
    };

_FacetValue _$FacetValueFromJson(Map<String, dynamic> json) => _FacetValue(
  value: json['value'] as String? ?? "",
  label: json['label'] as String? ?? "",
  count: (json['count'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$FacetValueToJson(_FacetValue instance) =>
    <String, dynamic>{
      'value': instance.value,
      'label': instance.label,
      'count': instance.count,
    };

_FavoriteItemView _$FavoriteItemViewFromJson(Map<String, dynamic> json) =>
    _FavoriteItemView(
      mediaItemId: (json['media_item_id'] as num?)?.toInt() ?? 0,
      kind: json['kind'] as String? ?? "",
      libraryId: (json['library_id'] as num?)?.toInt() ?? 0,
      source: json['source'] as String? ?? "",
      tmdbId: (json['tmdb_id'] as num?)?.toInt(),
      title: json['title'] as String? ?? "",
      year: (json['year'] as num?)?.toInt(),
      posterUrl: json['poster_url'] as String?,
      backdropUrl: json['backdrop_url'] as String?,
      primaryAspect: (json['primary_aspect'] as num?)?.toDouble() ?? 0.0,
      releaseDate: json['release_date'] as String?,
      rating: (json['rating'] as num?)?.toDouble(),
      posterBlur: json['poster_blur'] as String?,
      primaryFileId: (json['primary_file_id'] as num?)?.toInt(),
      fileCount: (json['file_count'] as num?)?.toInt() ?? 0,
      totalSizeBytes: (json['total_size_bytes'] as num?)?.toInt() ?? 0,
      seasons:
          (json['seasons'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [],
      episodeCount: (json['episode_count'] as num?)?.toInt() ?? 0,
      resolutions:
          (json['resolutions'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      missingCount: (json['missing_count'] as num?)?.toInt() ?? 0,
      airStatus: json['air_status'] as String?,
      missingEpisodeCount:
          (json['missing_episode_count'] as num?)?.toInt() ?? 0,
      addedAt: json['added_at'] as String?,
      isFavorite: json['is_favorite'] as bool? ?? false,
      recentAddition: json['recent_addition'] == null
          ? null
          : LibraryRecentAdditionView.fromJson(
              json['recent_addition'] as Map<String, dynamic>,
            ),
      inventorySummary: json['inventory_summary'] == null
          ? null
          : LibraryInventorySummaryView.fromJson(
              json['inventory_summary'] as Map<String, dynamic>,
            ),
      probePendingCount: (json['probe_pending_count'] as num?)?.toInt() ?? 0,
      dynamicRange: json['dynamic_range'] as String?,
      hasAtmos: json['has_atmos'] as bool?,
      hasChineseSubtitle: json['has_chinese_subtitle'] as bool?,
      progressPercent: (json['progress_percent'] as num?)?.toInt(),
      unplayedCount: (json['unplayed_count'] as num?)?.toInt(),
      favoriteSeasonNumber: (json['favorite_season_number'] as num?)?.toInt(),
      favoriteEpisodeNumber: (json['favorite_episode_number'] as num?)?.toInt(),
    );

Map<String, dynamic> _$FavoriteItemViewToJson(_FavoriteItemView instance) =>
    <String, dynamic>{
      'media_item_id': instance.mediaItemId,
      'kind': instance.kind,
      'library_id': instance.libraryId,
      'source': instance.source,
      'tmdb_id': instance.tmdbId,
      'title': instance.title,
      'year': instance.year,
      'poster_url': instance.posterUrl,
      'backdrop_url': instance.backdropUrl,
      'primary_aspect': instance.primaryAspect,
      'release_date': instance.releaseDate,
      'rating': instance.rating,
      'poster_blur': instance.posterBlur,
      'primary_file_id': instance.primaryFileId,
      'file_count': instance.fileCount,
      'total_size_bytes': instance.totalSizeBytes,
      'seasons': instance.seasons,
      'episode_count': instance.episodeCount,
      'resolutions': instance.resolutions,
      'missing_count': instance.missingCount,
      'air_status': instance.airStatus,
      'missing_episode_count': instance.missingEpisodeCount,
      'added_at': instance.addedAt,
      'is_favorite': instance.isFavorite,
      'recent_addition': instance.recentAddition,
      'inventory_summary': instance.inventorySummary,
      'probe_pending_count': instance.probePendingCount,
      'dynamic_range': instance.dynamicRange,
      'has_atmos': instance.hasAtmos,
      'has_chinese_subtitle': instance.hasChineseSubtitle,
      'progress_percent': instance.progressPercent,
      'unplayed_count': instance.unplayedCount,
      'favorite_season_number': instance.favoriteSeasonNumber,
      'favorite_episode_number': instance.favoriteEpisodeNumber,
    };

_FavoritesPageView _$FavoritesPageViewFromJson(Map<String, dynamic> json) =>
    _FavoritesPageView(
      items:
          (json['items'] as List<dynamic>?)
              ?.map((e) => FavoriteItemView.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      total: (json['total'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$FavoritesPageViewToJson(_FavoritesPageView instance) =>
    <String, dynamic>{'items': instance.items, 'total': instance.total};

_FavoritesView _$FavoritesViewFromJson(Map<String, dynamic> json) =>
    _FavoritesView(
      items:
          (json['items'] as List<dynamic>?)
              ?.map((e) => FavoriteItemView.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      total: (json['total'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$FavoritesViewToJson(_FavoritesView instance) =>
    <String, dynamic>{'items': instance.items, 'total': instance.total};

_FileCloudView _$FileCloudViewFromJson(Map<String, dynamic> json) =>
    _FileCloudView(
      backendTitle: json['backend_title'] as String? ?? "",
      accountName: json['account_name'] as String? ?? "",
      remotePath: json['remote_path'] as String?,
      local: json['local'] as bool? ?? false,
      origin: json['origin'] as String? ?? "",
      state: json['state'] as String? ?? "",
      error: json['error'] as String?,
    );

Map<String, dynamic> _$FileCloudViewToJson(_FileCloudView instance) =>
    <String, dynamic>{
      'backend_title': instance.backendTitle,
      'account_name': instance.accountName,
      'remote_path': instance.remotePath,
      'local': instance.local,
      'origin': instance.origin,
      'state': instance.state,
      'error': instance.error,
    };

_FileOriginView _$FileOriginViewFromJson(Map<String, dynamic> json) =>
    _FileOriginView(
      kind: json['kind'] as String? ?? "",
      label: json['label'] as String? ?? "",
      detail: json['detail'] as String?,
    );

Map<String, dynamic> _$FileOriginViewToJson(_FileOriginView instance) =>
    <String, dynamic>{
      'kind': instance.kind,
      'label': instance.label,
      'detail': instance.detail,
    };

_FollowFutureRequest _$FollowFutureRequestFromJson(Map<String, dynamic> json) =>
    _FollowFutureRequest(enabled: json['enabled'] as bool? ?? false);

Map<String, dynamic> _$FollowFutureRequestToJson(
  _FollowFutureRequest instance,
) => <String, dynamic>{'enabled': instance.enabled};

_FsBrowseView _$FsBrowseViewFromJson(Map<String, dynamic> json) =>
    _FsBrowseView(
      path: json['path'] as String? ?? '',
      parent: json['parent'] as String?,
      entries:
          (json['entries'] as List<dynamic>?)
              ?.map((e) => FsEntry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$FsBrowseViewToJson(_FsBrowseView instance) =>
    <String, dynamic>{
      'path': instance.path,
      'parent': instance.parent,
      'entries': instance.entries,
    };

_FsEntry _$FsEntryFromJson(Map<String, dynamic> json) => _FsEntry(
  name: json['name'] as String? ?? '',
  path: json['path'] as String? ?? '',
);

Map<String, dynamic> _$FsEntryToJson(_FsEntry instance) => <String, dynamic>{
  'name': instance.name,
  'path': instance.path,
};

_GenreOption _$GenreOptionFromJson(Map<String, dynamic> json) => _GenreOption(
  id: (json['id'] as num?)?.toInt() ?? 0,
  label: json['label'] as String? ?? "",
);

Map<String, dynamic> _$GenreOptionToJson(_GenreOption instance) =>
    <String, dynamic>{'id': instance.id, 'label': instance.label};

_GithubToken _$GithubTokenFromJson(Map<String, dynamic> json) => _GithubToken(
  configured: json['configured'] as bool? ?? false,
  masked: json['masked'] as String? ?? "",
);

Map<String, dynamic> _$GithubTokenToJson(_GithubToken instance) =>
    <String, dynamic>{
      'configured': instance.configured,
      'masked': instance.masked,
    };

_GithubTokenPayload _$GithubTokenPayloadFromJson(Map<String, dynamic> json) =>
    _GithubTokenPayload(token: json['token'] as String? ?? '');

Map<String, dynamic> _$GithubTokenPayloadToJson(_GithubTokenPayload instance) =>
    <String, dynamic>{'token': instance.token};

_GrabPayload _$GrabPayloadFromJson(Map<String, dynamic> json) => _GrabPayload(
  siteId: json['siteId'] as String? ?? '',
  torrentId: json['torrentId'] as String? ?? '',
  title: json['title'] as String? ?? '',
  subtitle: json['subtitle'] as String?,
  category: json['category'] as String?,
  downloadUrl: json['downloadUrl'] as String?,
  sizeBytes: (json['sizeBytes'] as num?)?.toInt(),
  seeders: (json['seeders'] as num?)?.toInt(),
  isFree: json['isFree'] as bool?,
  hitAndRun: json['hitAndRun'] as bool?,
  attrs: json['attrs'] as Map<String, dynamic>?,
  imdbId: json['imdbId'] as String?,
  doubanId: json['doubanId'] as String?,
  publishTime: json['publishTime'] as String?,
);

Map<String, dynamic> _$GrabPayloadToJson(_GrabPayload instance) =>
    <String, dynamic>{
      'siteId': instance.siteId,
      'torrentId': instance.torrentId,
      'title': instance.title,
      'subtitle': instance.subtitle,
      'category': instance.category,
      'downloadUrl': instance.downloadUrl,
      'sizeBytes': instance.sizeBytes,
      'seeders': instance.seeders,
      'isFree': instance.isFree,
      'hitAndRun': instance.hitAndRun,
      'attrs': instance.attrs,
      'imdbId': instance.imdbId,
      'doubanId': instance.doubanId,
      'publishTime': instance.publishTime,
    };

_GrabResultView _$GrabResultViewFromJson(Map<String, dynamic> json) =>
    _GrabResultView(
      units:
          (json['units'] as List<dynamic>?)
              ?.map((e) => DownloadUnitView.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$GrabResultViewToJson(_GrabResultView instance) =>
    <String, dynamic>{'units': instance.units};

_HandoffPrompt _$HandoffPromptFromJson(Map<String, dynamic> json) =>
    _HandoffPrompt(
      title: json['title'] as String? ?? "",
      prompt: json['prompt'] as String? ?? "",
    );

Map<String, dynamic> _$HandoffPromptToJson(_HandoffPrompt instance) =>
    <String, dynamic>{'title': instance.title, 'prompt': instance.prompt};

_HandoffRequest _$HandoffRequestFromJson(Map<String, dynamic> json) =>
    _HandoffRequest(
      kind: json['kind'] as String? ?? '',
      ref: json['ref'] as String? ?? '',
    );

Map<String, dynamic> _$HandoffRequestToJson(_HandoffRequest instance) =>
    <String, dynamic>{'kind': instance.kind, 'ref': instance.ref};

_HealthResponse _$HealthResponseFromJson(Map<String, dynamic> json) =>
    _HealthResponse(
      status: json['status'] as String? ?? "",
      service: json['service'] as String? ?? "",
      environment: json['environment'] as String? ?? "",
      specHash: json['spec_hash'] as String? ?? "",
      version: json['version'] as String?,
      instanceId: json['instance_id'] as String?,
      proof: json['proof'] as String?,
    );

Map<String, dynamic> _$HealthResponseToJson(_HealthResponse instance) =>
    <String, dynamic>{
      'status': instance.status,
      'service': instance.service,
      'environment': instance.environment,
      'spec_hash': instance.specHash,
      'version': instance.version,
      'instance_id': instance.instanceId,
      'proof': instance.proof,
    };

_HealthView _$HealthViewFromJson(Map<String, dynamic> json) => _HealthView(
  status: json['status'] as String?,
  service: json['service'] as String?,
  environment: json['environment'] as String?,
  specHash: json['specHash'] as String?,
  instanceId: json['instanceId'] as String?,
);

Map<String, dynamic> _$HealthViewToJson(_HealthView instance) =>
    <String, dynamic>{
      'status': instance.status,
      'service': instance.service,
      'environment': instance.environment,
      'specHash': instance.specHash,
      'instanceId': instance.instanceId,
    };

_HistoryClearView _$HistoryClearViewFromJson(Map<String, dynamic> json) =>
    _HistoryClearView(
      deletedStates: (json['deletedStates'] as num?)?.toInt() ?? 0,
      deletedMetrics: (json['deletedMetrics'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$HistoryClearViewToJson(_HistoryClearView instance) =>
    <String, dynamic>{
      'deletedStates': instance.deletedStates,
      'deletedMetrics': instance.deletedMetrics,
    };

_HomeRowPref _$HomeRowPrefFromJson(Map<String, dynamic> json) => _HomeRowPref(
  id: json['id'] as String? ?? "",
  sort: json['sort'] as String?,
  order: json['order'] as String?,
  name: json['name'] as String?,
  unwatched: json['unwatched'] as bool?,
  unfinished: json['unfinished'] as bool?,
  hidden: json['hidden'] as bool?,
  libraryId: (json['library_id'] as num?)?.toInt(),
  collectionId: (json['collection_id'] as num?)?.toInt(),
  mediaKind: json['media_kind'] as String?,
);

Map<String, dynamic> _$HomeRowPrefToJson(_HomeRowPref instance) =>
    <String, dynamic>{
      'id': instance.id,
      'sort': instance.sort,
      'order': instance.order,
      'name': instance.name,
      'unwatched': instance.unwatched,
      'unfinished': instance.unfinished,
      'hidden': instance.hidden,
      'library_id': instance.libraryId,
      'collection_id': instance.collectionId,
      'media_kind': instance.mediaKind,
    };

_HomeUiPrefs _$HomeUiPrefsFromJson(Map<String, dynamic> json) => _HomeUiPrefs(
  rows:
      (json['rows'] as List<dynamic>?)
          ?.map((e) => HomeRowPref.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
);

Map<String, dynamic> _$HomeUiPrefsToJson(_HomeUiPrefs instance) =>
    <String, dynamic>{'rows': instance.rows};

_ImportWatchPayload _$ImportWatchPayloadFromJson(Map<String, dynamic> json) =>
    _ImportWatchPayload(
      sourcePath: json['sourcePath'] as String? ?? '',
      strategy: json['strategy'] as String? ?? '',
      libraryId: (json['libraryId'] as num?)?.toInt(),
      targetPath: json['targetPath'] as String?,
      kind: json['kind'] as String?,
      processExisting: json['processExisting'] as bool? ?? true,
    );

Map<String, dynamic> _$ImportWatchPayloadToJson(_ImportWatchPayload instance) =>
    <String, dynamic>{
      'sourcePath': instance.sourcePath,
      'strategy': instance.strategy,
      'libraryId': instance.libraryId,
      'targetPath': instance.targetPath,
      'kind': instance.kind,
      'processExisting': instance.processExisting,
    };

_ImportWatchView _$ImportWatchViewFromJson(Map<String, dynamic> json) =>
    _ImportWatchView(
      id: (json['id'] as num?)?.toInt() ?? 0,
      sourcePath: json['sourcePath'] as String? ?? "",
      strategy: json['strategy'] as String? ?? "hardlink",
      libraryId: (json['libraryId'] as num?)?.toInt(),
      libraryName: json['libraryName'] as String?,
      targetPath: json['targetPath'] as String?,
      kind: json['kind'] as String?,
      targetLabel: json['targetLabel'] as String? ?? "",
      processExisting: json['processExisting'] as bool? ?? true,
      stats:
          (json['stats'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, (e as num).toInt()),
          ) ??
          const {},
      importedFiles: (json['importedFiles'] as num?)?.toInt() ?? 0,
      importedWorks: (json['importedWorks'] as num?)?.toInt() ?? 0,
      createdAt: json['createdAt'] as String?,
    );

Map<String, dynamic> _$ImportWatchViewToJson(_ImportWatchView instance) =>
    <String, dynamic>{
      'id': instance.id,
      'sourcePath': instance.sourcePath,
      'strategy': instance.strategy,
      'libraryId': instance.libraryId,
      'libraryName': instance.libraryName,
      'targetPath': instance.targetPath,
      'kind': instance.kind,
      'targetLabel': instance.targetLabel,
      'processExisting': instance.processExisting,
      'stats': instance.stats,
      'importedFiles': instance.importedFiles,
      'importedWorks': instance.importedWorks,
      'createdAt': instance.createdAt,
    };

_IngestEntriesView _$IngestEntriesViewFromJson(Map<String, dynamic> json) =>
    _IngestEntriesView(
      counts:
          (json['counts'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, (e as num).toInt()),
          ) ??
          const {},
      entries:
          (json['entries'] as List<dynamic>?)
              ?.map((e) => IngestEntryView.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$IngestEntriesViewToJson(_IngestEntriesView instance) =>
    <String, dynamic>{'counts': instance.counts, 'entries': instance.entries};

_IngestEntryView _$IngestEntryViewFromJson(Map<String, dynamic> json) =>
    _IngestEntryView(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? "",
      entryPath: json['entryPath'] as String? ?? "",
      status: json['status'] as String? ?? "",
      message: json['message'] as String?,
      importedCount: (json['importedCount'] as num?)?.toInt() ?? 0,
      attemptedAt: json['attemptedAt'] as String?,
      unresolvedFiles:
          (json['unresolvedFiles'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );

Map<String, dynamic> _$IngestEntryViewToJson(_IngestEntryView instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'entryPath': instance.entryPath,
      'status': instance.status,
      'message': instance.message,
      'importedCount': instance.importedCount,
      'attemptedAt': instance.attemptedAt,
      'unresolvedFiles': instance.unresolvedFiles,
    };

_InvalidateTipRequest _$InvalidateTipRequestFromJson(
  Map<String, dynamic> json,
) => _InvalidateTipRequest(reason: json['reason'] as String?);

Map<String, dynamic> _$InvalidateTipRequestToJson(
  _InvalidateTipRequest instance,
) => <String, dynamic>{'reason': instance.reason};

_ItemCollectionRef _$ItemCollectionRefFromJson(Map<String, dynamic> json) =>
    _ItemCollectionRef(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? "",
    );

Map<String, dynamic> _$ItemCollectionRefToJson(_ItemCollectionRef instance) =>
    <String, dynamic>{'id': instance.id, 'name': instance.name};

_ItemDeletePreviewView _$ItemDeletePreviewViewFromJson(
  Map<String, dynamic> json,
) => _ItemDeletePreviewView(
  wholeItem: json['wholeItem'] as bool? ?? false,
  linkedBytes: (json['linkedBytes'] as num?)?.toInt() ?? 0,
  options:
      (json['options'] as List<dynamic>?)
          ?.map((e) => DeleteOptionView.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
);

Map<String, dynamic> _$ItemDeletePreviewViewToJson(
  _ItemDeletePreviewView instance,
) => <String, dynamic>{
  'wholeItem': instance.wholeItem,
  'linkedBytes': instance.linkedBytes,
  'options': instance.options,
};

_ItemDeleteResultView _$ItemDeleteResultViewFromJson(
  Map<String, dynamic> json,
) => _ItemDeleteResultView(
  removedPaths:
      (json['removedPaths'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  rowsDeleted: (json['rowsDeleted'] as num?)?.toInt() ?? 0,
  freedBytes: (json['freedBytes'] as num?)?.toInt() ?? 0,
  errors:
      (json['errors'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  followUps: (json['followUps'] as List<dynamic>?)
      ?.map((e) => DeleteFollowUpView.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$ItemDeleteResultViewToJson(
  _ItemDeleteResultView instance,
) => <String, dynamic>{
  'removedPaths': instance.removedPaths,
  'rowsDeleted': instance.rowsDeleted,
  'freedBytes': instance.freedBytes,
  'errors': instance.errors,
  'followUps': instance.followUps,
};

_ItemJobView _$ItemJobViewFromJson(Map<String, dynamic> json) => _ItemJobView(
  started: json['started'] as bool? ?? false,
  jobId: json['jobId'] as String?,
  created: json['created'] as bool? ?? false,
);

Map<String, dynamic> _$ItemJobViewToJson(_ItemJobView instance) =>
    <String, dynamic>{
      'started': instance.started,
      'jobId': instance.jobId,
      'created': instance.created,
    };

_JobCancelView _$JobCancelViewFromJson(Map<String, dynamic> json) =>
    _JobCancelView(
      cancelled: json['cancelled'] as bool? ?? false,
      job: json['job'] == null
          ? null
          : JobView.fromJson(json['job'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$JobCancelViewToJson(_JobCancelView instance) =>
    <String, dynamic>{'cancelled': instance.cancelled, 'job': instance.job};

_JobErrorAction _$JobErrorActionFromJson(Map<String, dynamic> json) =>
    _JobErrorAction(
      type: json['type'] as String? ?? "",
      label: json['label'] as String? ?? "",
    );

Map<String, dynamic> _$JobErrorActionToJson(_JobErrorAction instance) =>
    <String, dynamic>{'type': instance.type, 'label': instance.label};

_JobErrorView _$JobErrorViewFromJson(Map<String, dynamic> json) =>
    _JobErrorView(
      code: json['code'] as String? ?? "",
      message: json['message'] as String? ?? "",
      actions:
          (json['actions'] as List<dynamic>?)
              ?.map((e) => JobErrorAction.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$JobErrorViewToJson(_JobErrorView instance) =>
    <String, dynamic>{
      'code': instance.code,
      'message': instance.message,
      'actions': instance.actions,
    };

_JobListView _$JobListViewFromJson(Map<String, dynamic> json) => _JobListView(
  items:
      (json['items'] as List<dynamic>?)
          ?.map((e) => JobView.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  running: json['running'] as bool? ?? false,
);

Map<String, dynamic> _$JobListViewToJson(_JobListView instance) =>
    <String, dynamic>{'items': instance.items, 'running': instance.running};

_JobProgress _$JobProgressFromJson(Map<String, dynamic> json) => _JobProgress(
  mode: json['mode'] as String? ?? "",
  phase: json['phase'] as String? ?? "",
  message: json['message'] as String? ?? "",
  current: (json['current'] as num?)?.toInt(),
  total: (json['total'] as num?)?.toInt(),
  percent: (json['percent'] as num?)?.toDouble(),
  phaseIndex: (json['phaseIndex'] as num?)?.toInt(),
  phaseCount: (json['phaseCount'] as num?)?.toInt(),
  details: json['details'] as Map<String, dynamic>?,
);

Map<String, dynamic> _$JobProgressToJson(_JobProgress instance) =>
    <String, dynamic>{
      'mode': instance.mode,
      'phase': instance.phase,
      'message': instance.message,
      'current': instance.current,
      'total': instance.total,
      'percent': instance.percent,
      'phaseIndex': instance.phaseIndex,
      'phaseCount': instance.phaseCount,
      'details': instance.details,
    };

_JobResourceView _$JobResourceViewFromJson(Map<String, dynamic> json) =>
    _JobResourceView(
      resourceType: json['resourceType'] as String? ?? "",
      resourceId: json['resourceId'] as String? ?? "",
      relation: json['relation'] as String? ?? "",
    );

Map<String, dynamic> _$JobResourceViewToJson(_JobResourceView instance) =>
    <String, dynamic>{
      'resourceType': instance.resourceType,
      'resourceId': instance.resourceId,
      'relation': instance.relation,
    };

_JobUsage _$JobUsageFromJson(Map<String, dynamic> json) => _JobUsage(
  requestCount: (json['requestCount'] as num?)?.toInt() ?? 0,
  totalTokens: (json['totalTokens'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$JobUsageToJson(_JobUsage instance) => <String, dynamic>{
  'requestCount': instance.requestCount,
  'totalTokens': instance.totalTokens,
};

_JobView _$JobViewFromJson(Map<String, dynamic> json) => _JobView(
  id: json['id'] as String? ?? '',
  jobType: json['jobType'] as String? ?? "",
  jobTypeLabel: json['jobTypeLabel'] as String?,
  subject: json['subject'] as String?,
  status: json['status'] as String? ?? "",
  progress: json['progress'] == null
      ? const JobProgress()
      : JobProgress.fromJson(json['progress'] as Map<String, dynamic>),
  error: json['error'] == null
      ? null
      : JobErrorView.fromJson(json['error'] as Map<String, dynamic>),
  resources:
      (json['resources'] as List<dynamic>?)
          ?.map((e) => JobResourceView.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  inputData: json['inputData'] as Map<String, dynamic>?,
  result: json['result'] as Map<String, dynamic>?,
  usage: json['usage'] == null
      ? const JobUsage()
      : JobUsage.fromJson(json['usage'] as Map<String, dynamic>),
  startedAt: json['startedAt'] as String?,
  dismissedAt: json['dismissedAt'] as String?,
  cancelRequestedBy: json['cancelRequestedBy'] as String?,
  finishedAt: json['finishedAt'] as String?,
  origin: json['origin'] as String? ?? "",
  actorName: json['actorName'] as String?,
  attempt: (json['attempt'] as num?)?.toInt() ?? 1,
  maxAttempts: (json['maxAttempts'] as num?)?.toInt() ?? 1,
  createdAt: json['createdAt'] as String?,
  updatedAt: json['updatedAt'] as String?,
);

Map<String, dynamic> _$JobViewToJson(_JobView instance) => <String, dynamic>{
  'id': instance.id,
  'jobType': instance.jobType,
  'jobTypeLabel': instance.jobTypeLabel,
  'subject': instance.subject,
  'status': instance.status,
  'progress': instance.progress,
  'error': instance.error,
  'resources': instance.resources,
  'inputData': instance.inputData,
  'result': instance.result,
  'usage': instance.usage,
  'startedAt': instance.startedAt,
  'dismissedAt': instance.dismissedAt,
  'cancelRequestedBy': instance.cancelRequestedBy,
  'finishedAt': instance.finishedAt,
  'origin': instance.origin,
  'actorName': instance.actorName,
  'attempt': instance.attempt,
  'maxAttempts': instance.maxAttempts,
  'createdAt': instance.createdAt,
  'updatedAt': instance.updatedAt,
};

_LastAbnormalExit _$LastAbnormalExitFromJson(Map<String, dynamic> json) =>
    _LastAbnormalExit(
      at: json['at'] as String? ?? "",
      exitCode: (json['exitCode'] as num?)?.toInt() ?? 0,
      detail: json['detail'] as String? ?? "",
    );

Map<String, dynamic> _$LastAbnormalExitToJson(_LastAbnormalExit instance) =>
    <String, dynamic>{
      'at': instance.at,
      'exitCode': instance.exitCode,
      'detail': instance.detail,
    };

_LastOrganizeView _$LastOrganizeViewFromJson(Map<String, dynamic> json) =>
    _LastOrganizeView(
      finishedAt: json['finished_at'] as String? ?? "",
      renamed: (json['renamed'] as num?)?.toInt() ?? 0,
      sidecarsRenamed: (json['sidecars_renamed'] as num?)?.toInt() ?? 0,
      entryAssetsMoved: (json['entry_assets_moved'] as num?)?.toInt() ?? 0,
      alreadyOk: (json['already_ok'] as num?)?.toInt() ?? 0,
      skipped: (json['skipped'] as num?)?.toInt() ?? 0,
      removedDirs: (json['removed_dirs'] as num?)?.toInt() ?? 0,
      errors:
          (json['errors'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );

Map<String, dynamic> _$LastOrganizeViewToJson(_LastOrganizeView instance) =>
    <String, dynamic>{
      'finished_at': instance.finishedAt,
      'renamed': instance.renamed,
      'sidecars_renamed': instance.sidecarsRenamed,
      'entry_assets_moved': instance.entryAssetsMoved,
      'already_ok': instance.alreadyOk,
      'skipped': instance.skipped,
      'removed_dirs': instance.removedDirs,
      'errors': instance.errors,
    };

_LastScanView _$LastScanViewFromJson(
  Map<String, dynamic> json,
) => _LastScanView(
  finishedAt: json['finished_at'] as String? ?? "",
  scanned: (json['scanned'] as num?)?.toInt() ?? 0,
  identified: (json['identified'] as num?)?.toInt() ?? 0,
  unidentified: (json['unidentified'] as num?)?.toInt() ?? 0,
  markedMissing: (json['marked_missing'] as num?)?.toInt() ?? 0,
  clearedMissing: (json['cleared_missing'] as num?)?.toInt() ?? 0,
  removedRootMarkedMissing:
      (json['removed_root_marked_missing'] as num?)?.toInt() ?? 0,
  removedRootCleared: (json['removed_root_cleared'] as num?)?.toInt() ?? 0,
  removedRootConflicts: (json['removed_root_conflicts'] as num?)?.toInt() ?? 0,
  deferredValue: (json['deferred'] as num?)?.toInt() ?? 0,
  retried: (json['retried'] as num?)?.toInt() ?? 0,
  cancelled: json['cancelled'] as bool? ?? false,
  errors:
      (json['errors'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
);

Map<String, dynamic> _$LastScanViewToJson(_LastScanView instance) =>
    <String, dynamic>{
      'finished_at': instance.finishedAt,
      'scanned': instance.scanned,
      'identified': instance.identified,
      'unidentified': instance.unidentified,
      'marked_missing': instance.markedMissing,
      'cleared_missing': instance.clearedMissing,
      'removed_root_marked_missing': instance.removedRootMarkedMissing,
      'removed_root_cleared': instance.removedRootCleared,
      'removed_root_conflicts': instance.removedRootConflicts,
      'deferred': instance.deferredValue,
      'retried': instance.retried,
      'cancelled': instance.cancelled,
      'errors': instance.errors,
    };

_LibraryCapabilitiesView _$LibraryCapabilitiesViewFromJson(
  Map<String, dynamic> json,
) => _LibraryCapabilitiesView(
  scraped: json['scraped'] as bool? ?? false,
  episodic: json['episodic'] as bool? ?? false,
  naming: json['naming'] as bool? ?? false,
  subscribable: json['subscribable'] as bool? ?? false,
  writeNfo: json['write_nfo'] as bool? ?? false,
  defaultAspect: (json['default_aspect'] as num?)?.toDouble() ?? 0.0,
  jellyfinCollection: json['jellyfin_collection'] as String? ?? "",
  playable: json['playable'] as bool? ?? false,
);

Map<String, dynamic> _$LibraryCapabilitiesViewToJson(
  _LibraryCapabilitiesView instance,
) => <String, dynamic>{
  'scraped': instance.scraped,
  'episodic': instance.episodic,
  'naming': instance.naming,
  'subscribable': instance.subscribable,
  'write_nfo': instance.writeNfo,
  'default_aspect': instance.defaultAspect,
  'jellyfin_collection': instance.jellyfinCollection,
  'playable': instance.playable,
};

_LibraryFacets _$LibraryFacetsFromJson(Map<String, dynamic> json) =>
    _LibraryFacets(
      total: (json['total'] as num?)?.toInt() ?? 0,
      genres:
          (json['genres'] as List<dynamic>?)
              ?.map((e) => FacetValue.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      countries:
          (json['countries'] as List<dynamic>?)
              ?.map((e) => FacetValue.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      decades:
          (json['decades'] as List<dynamic>?)
              ?.map((e) => FacetValue.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      watch:
          (json['watch'] as List<dynamic>?)
              ?.map((e) => FacetValue.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      ratings:
          (json['ratings'] as List<dynamic>?)
              ?.map((e) => FacetValue.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      runtimes:
          (json['runtimes'] as List<dynamic>?)
              ?.map((e) => FacetValue.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      languages:
          (json['languages'] as List<dynamic>?)
              ?.map((e) => FacetValue.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      resolutions:
          (json['resolutions'] as List<dynamic>?)
              ?.map((e) => FacetValue.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      hdr:
          (json['hdr'] as List<dynamic>?)
              ?.map((e) => FacetValue.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      stock:
          (json['stock'] as List<dynamic>?)
              ?.map((e) => FacetValue.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$LibraryFacetsToJson(_LibraryFacets instance) =>
    <String, dynamic>{
      'total': instance.total,
      'genres': instance.genres,
      'countries': instance.countries,
      'decades': instance.decades,
      'watch': instance.watch,
      'ratings': instance.ratings,
      'runtimes': instance.runtimes,
      'languages': instance.languages,
      'resolutions': instance.resolutions,
      'hdr': instance.hdr,
      'stock': instance.stock,
    };

_LibraryFileView _$LibraryFileViewFromJson(Map<String, dynamic> json) =>
    _LibraryFileView(
      id: (json['id'] as num?)?.toInt() ?? 0,
      filePath: json['file_path'] as String? ?? "",
      fileName: json['file_name'] as String? ?? "",
      sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
      container: json['container'] as String?,
      resolution: json['resolution'] as String?,
      videoCodec: json['video_codec'] as String?,
      hdr: json['hdr'] as String?,
      bitDepth: (json['bit_depth'] as num?)?.toInt(),
      durationSeconds: (json['duration_seconds'] as num?)?.toInt(),
      bitRate: (json['bit_rate'] as num?)?.toInt(),
      frameRate: (json['frame_rate'] as num?)?.toDouble(),
      colorSpace: json['color_space'] as String?,
      mediaSource: json['media_source'] as String?,
      mediaSourceManual: json['media_source_manual'] as bool? ?? false,
      releaseGroup: json['release_group'] as String?,
      source: json['source'] as String? ?? "",
      seasonNumber: (json['season_number'] as num?)?.toInt() ?? 0,
      episodeNumber: (json['episode_number'] as num?)?.toInt() ?? 0,
      missing: json['missing'] as bool? ?? false,
      state: json['state'] as String? ?? "",
      purgeAfter: json['purge_after'] as String?,
      trashNote: json['trash_note'] as String?,
      origin: json['origin'] == null
          ? const FileOriginView()
          : FileOriginView.fromJson(json['origin'] as Map<String, dynamic>),
      keptAt: json['kept_at'] as String?,
      audioStreams: (json['audio_streams'] as List<dynamic>?)
          ?.map((e) => AudioStreamView.fromJson(e as Map<String, dynamic>))
          .toList(),
      subtitleStreams:
          (json['subtitle_streams'] as List<dynamic>?)
              ?.map(
                (e) => SubtitleStreamView.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const [],
      playbackDefaults: json['playback_defaults'] == null
          ? null
          : TrackDefaultsView.fromJson(
              json['playback_defaults'] as Map<String, dynamic>,
            ),
      chapters: (json['chapters'] as List<dynamic>?)
          ?.map((e) => ChapterView.fromJson(e as Map<String, dynamic>))
          .toList(),
      cloud: json['cloud'] == null
          ? null
          : FileCloudView.fromJson(json['cloud'] as Map<String, dynamic>),
      addedAt: json['added_at'] as String? ?? "",
    );

Map<String, dynamic> _$LibraryFileViewToJson(_LibraryFileView instance) =>
    <String, dynamic>{
      'id': instance.id,
      'file_path': instance.filePath,
      'file_name': instance.fileName,
      'size_bytes': instance.sizeBytes,
      'container': instance.container,
      'resolution': instance.resolution,
      'video_codec': instance.videoCodec,
      'hdr': instance.hdr,
      'bit_depth': instance.bitDepth,
      'duration_seconds': instance.durationSeconds,
      'bit_rate': instance.bitRate,
      'frame_rate': instance.frameRate,
      'color_space': instance.colorSpace,
      'media_source': instance.mediaSource,
      'media_source_manual': instance.mediaSourceManual,
      'release_group': instance.releaseGroup,
      'source': instance.source,
      'season_number': instance.seasonNumber,
      'episode_number': instance.episodeNumber,
      'missing': instance.missing,
      'state': instance.state,
      'purge_after': instance.purgeAfter,
      'trash_note': instance.trashNote,
      'origin': instance.origin,
      'kept_at': instance.keptAt,
      'audio_streams': instance.audioStreams,
      'subtitle_streams': instance.subtitleStreams,
      'playback_defaults': instance.playbackDefaults,
      'chapters': instance.chapters,
      'cloud': instance.cloud,
      'added_at': instance.addedAt,
    };

_LibraryGalleryGroupView _$LibraryGalleryGroupViewFromJson(
  Map<String, dynamic> json,
) => _LibraryGalleryGroupView(
  mediaItemId: (json['mediaItemId'] as num?)?.toInt() ?? 0,
  libraryId: (json['libraryId'] as num?)?.toInt() ?? 0,
  kind: json['kind'] as String? ?? "movie",
  title: json['title'] as String? ?? "",
  year: (json['year'] as num?)?.toInt(),
  isFavorite: json['isFavorite'] as bool? ?? false,
  images:
      (json['images'] as List<dynamic>?)
          ?.map(
            (e) => LibraryGalleryImageView.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const [],
);

Map<String, dynamic> _$LibraryGalleryGroupViewToJson(
  _LibraryGalleryGroupView instance,
) => <String, dynamic>{
  'mediaItemId': instance.mediaItemId,
  'libraryId': instance.libraryId,
  'kind': instance.kind,
  'title': instance.title,
  'year': instance.year,
  'isFavorite': instance.isFavorite,
  'images': instance.images,
};

_LibraryGalleryImageView _$LibraryGalleryImageViewFromJson(
  Map<String, dynamic> json,
) => _LibraryGalleryImageView(
  kind: json['kind'] as String? ?? "poster",
  url: json['url'] as String? ?? "",
  aspect: (json['aspect'] as num?)?.toDouble() ?? 0.0,
  label: json['label'] as String? ?? "",
  season: (json['season'] as num?)?.toInt(),
  episode: (json['episode'] as num?)?.toInt(),
  tSeconds: (json['tSeconds'] as num?)?.toDouble(),
);

Map<String, dynamic> _$LibraryGalleryImageViewToJson(
  _LibraryGalleryImageView instance,
) => <String, dynamic>{
  'kind': instance.kind,
  'url': instance.url,
  'aspect': instance.aspect,
  'label': instance.label,
  'season': instance.season,
  'episode': instance.episode,
  'tSeconds': instance.tSeconds,
};

_LibraryIndexEntry _$LibraryIndexEntryFromJson(Map<String, dynamic> json) =>
    _LibraryIndexEntry(
      initial: json['initial'] as String? ?? "",
      count: (json['count'] as num?)?.toInt() ?? 0,
      offset: (json['offset'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$LibraryIndexEntryToJson(_LibraryIndexEntry instance) =>
    <String, dynamic>{
      'initial': instance.initial,
      'count': instance.count,
      'offset': instance.offset,
    };

_LibraryInventorySummaryView _$LibraryInventorySummaryViewFromJson(
  Map<String, dynamic> json,
) => _LibraryInventorySummaryView(
  seasonCount: (json['season_count'] as num?)?.toInt() ?? 0,
  episodeCount: (json['episode_count'] as num?)?.toInt() ?? 0,
  seasonNumber: (json['season_number'] as num?)?.toInt(),
  totalEpisodeCount: (json['total_episode_count'] as num?)?.toInt(),
  allSeasonsOwned: json['all_seasons_owned'] as bool? ?? false,
  allEpisodesOwned: json['all_episodes_owned'] as bool? ?? false,
);

Map<String, dynamic> _$LibraryInventorySummaryViewToJson(
  _LibraryInventorySummaryView instance,
) => <String, dynamic>{
  'season_count': instance.seasonCount,
  'episode_count': instance.episodeCount,
  'season_number': instance.seasonNumber,
  'total_episode_count': instance.totalEpisodeCount,
  'all_seasons_owned': instance.allSeasonsOwned,
  'all_episodes_owned': instance.allEpisodesOwned,
};

_LibraryItemDetailView _$LibraryItemDetailViewFromJson(
  Map<String, dynamic> json,
) => _LibraryItemDetailView(
  mediaItemId: (json['media_item_id'] as num?)?.toInt() ?? 0,
  kind: json['kind'] as String? ?? "",
  source: json['source'] as String? ?? "",
  tmdbId: (json['tmdb_id'] as num?)?.toInt(),
  imdbId: json['imdb_id'] as String?,
  doubanId: json['douban_id'] as String?,
  title: json['title'] as String? ?? "",
  originalTitle: json['original_title'] as String? ?? "",
  englishTitle: json['english_title'] as String?,
  chineseTitle: json['chinese_title'] as String?,
  year: (json['year'] as num?)?.toInt(),
  posterUrl: json['poster_url'] as String?,
  backdropUrl: json['backdrop_url'] as String?,
  logoUrl: json['logo_url'] as String?,
  primaryAspect: (json['primary_aspect'] as num?)?.toDouble() ?? 0.0,
  localMeta: json['local_meta'] == null
      ? null
      : LocalMetaView.fromJson(json['local_meta'] as Map<String, dynamic>),
  entryDirs:
      (json['entry_dirs'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  files:
      (json['files'] as List<dynamic>?)
          ?.map((e) => LibraryFileView.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  fileCount: (json['file_count'] as num?)?.toInt() ?? 0,
  totalSizeBytes: (json['total_size_bytes'] as num?)?.toInt() ?? 0,
  seasons:
      (json['seasons'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList() ??
      const [],
  scraping: json['scraping'] as bool? ?? false,
  scrapingPhase: json['scraping_phase'] as String?,
  chaptersPending: json['chapters_pending'] as bool? ?? false,
  seriesName: json['series_name'] as String?,
  seriesCollectionId: (json['series_collection_id'] as num?)?.toInt(),
  collections:
      (json['collections'] as List<dynamic>?)
          ?.map((e) => ItemCollectionRef.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  airStatus: json['air_status'] as String?,
);

Map<String, dynamic> _$LibraryItemDetailViewToJson(
  _LibraryItemDetailView instance,
) => <String, dynamic>{
  'media_item_id': instance.mediaItemId,
  'kind': instance.kind,
  'source': instance.source,
  'tmdb_id': instance.tmdbId,
  'imdb_id': instance.imdbId,
  'douban_id': instance.doubanId,
  'title': instance.title,
  'original_title': instance.originalTitle,
  'english_title': instance.englishTitle,
  'chinese_title': instance.chineseTitle,
  'year': instance.year,
  'poster_url': instance.posterUrl,
  'backdrop_url': instance.backdropUrl,
  'logo_url': instance.logoUrl,
  'primary_aspect': instance.primaryAspect,
  'local_meta': instance.localMeta,
  'entry_dirs': instance.entryDirs,
  'files': instance.files,
  'file_count': instance.fileCount,
  'total_size_bytes': instance.totalSizeBytes,
  'seasons': instance.seasons,
  'scraping': instance.scraping,
  'scraping_phase': instance.scrapingPhase,
  'chapters_pending': instance.chaptersPending,
  'series_name': instance.seriesName,
  'series_collection_id': instance.seriesCollectionId,
  'collections': instance.collections,
  'air_status': instance.airStatus,
};

_LibraryItemShowcaseView _$LibraryItemShowcaseViewFromJson(
  Map<String, dynamic> json,
) => _LibraryItemShowcaseView(
  mediaItemId: (json['media_item_id'] as num?)?.toInt() ?? 0,
  backdropUrl: json['backdrop_url'] as String?,
  logoUrl: json['logo_url'] as String?,
  overview: json['overview'] as String?,
  genres:
      (json['genres'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  runtimeMinutes: (json['runtime_minutes'] as num?)?.toInt(),
  contentRating: json['content_rating'] as String?,
);

Map<String, dynamic> _$LibraryItemShowcaseViewToJson(
  _LibraryItemShowcaseView instance,
) => <String, dynamic>{
  'media_item_id': instance.mediaItemId,
  'backdrop_url': instance.backdropUrl,
  'logo_url': instance.logoUrl,
  'overview': instance.overview,
  'genres': instance.genres,
  'runtime_minutes': instance.runtimeMinutes,
  'content_rating': instance.contentRating,
};

_LibraryItemView _$LibraryItemViewFromJson(Map<String, dynamic> json) =>
    _LibraryItemView(
      mediaItemId: (json['media_item_id'] as num?)?.toInt() ?? 0,
      kind: json['kind'] as String? ?? "",
      libraryId: (json['library_id'] as num?)?.toInt(),
      source: json['source'] as String? ?? "",
      tmdbId: (json['tmdb_id'] as num?)?.toInt(),
      title: json['title'] as String? ?? "",
      year: (json['year'] as num?)?.toInt(),
      posterUrl: json['poster_url'] as String?,
      backdropUrl: json['backdrop_url'] as String?,
      primaryAspect: (json['primary_aspect'] as num?)?.toDouble() ?? 0.0,
      releaseDate: json['release_date'] as String?,
      rating: (json['rating'] as num?)?.toDouble(),
      posterBlur: json['poster_blur'] as String?,
      primaryFileId: (json['primary_file_id'] as num?)?.toInt(),
      fileCount: (json['file_count'] as num?)?.toInt() ?? 0,
      totalSizeBytes: (json['total_size_bytes'] as num?)?.toInt() ?? 0,
      seasons:
          (json['seasons'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [],
      episodeCount: (json['episode_count'] as num?)?.toInt() ?? 0,
      resolutions:
          (json['resolutions'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      missingCount: (json['missing_count'] as num?)?.toInt() ?? 0,
      airStatus: json['air_status'] as String?,
      missingEpisodeCount:
          (json['missing_episode_count'] as num?)?.toInt() ?? 0,
      addedAt: json['added_at'] as String?,
      isFavorite: json['is_favorite'] as bool? ?? false,
      recentAddition: json['recent_addition'] == null
          ? null
          : LibraryRecentAdditionView.fromJson(
              json['recent_addition'] as Map<String, dynamic>,
            ),
      inventorySummary: json['inventory_summary'] == null
          ? null
          : LibraryInventorySummaryView.fromJson(
              json['inventory_summary'] as Map<String, dynamic>,
            ),
      probePendingCount: (json['probe_pending_count'] as num?)?.toInt() ?? 0,
      dynamicRange: json['dynamic_range'] as String?,
      hasAtmos: json['has_atmos'] as bool?,
      hasChineseSubtitle: json['has_chinese_subtitle'] as bool?,
      progressPercent: (json['progress_percent'] as num?)?.toInt(),
      unplayedCount: (json['unplayed_count'] as num?)?.toInt(),
    );

Map<String, dynamic> _$LibraryItemViewToJson(_LibraryItemView instance) =>
    <String, dynamic>{
      'media_item_id': instance.mediaItemId,
      'kind': instance.kind,
      'library_id': instance.libraryId,
      'source': instance.source,
      'tmdb_id': instance.tmdbId,
      'title': instance.title,
      'year': instance.year,
      'poster_url': instance.posterUrl,
      'backdrop_url': instance.backdropUrl,
      'primary_aspect': instance.primaryAspect,
      'release_date': instance.releaseDate,
      'rating': instance.rating,
      'poster_blur': instance.posterBlur,
      'primary_file_id': instance.primaryFileId,
      'file_count': instance.fileCount,
      'total_size_bytes': instance.totalSizeBytes,
      'seasons': instance.seasons,
      'episode_count': instance.episodeCount,
      'resolutions': instance.resolutions,
      'missing_count': instance.missingCount,
      'air_status': instance.airStatus,
      'missing_episode_count': instance.missingEpisodeCount,
      'added_at': instance.addedAt,
      'is_favorite': instance.isFavorite,
      'recent_addition': instance.recentAddition,
      'inventory_summary': instance.inventorySummary,
      'probe_pending_count': instance.probePendingCount,
      'dynamic_range': instance.dynamicRange,
      'has_atmos': instance.hasAtmos,
      'has_chinese_subtitle': instance.hasChineseSubtitle,
      'progress_percent': instance.progressPercent,
      'unplayed_count': instance.unplayedCount,
    };

_LibraryKindGenreView _$LibraryKindGenreViewFromJson(
  Map<String, dynamic> json,
) => _LibraryKindGenreView(
  value: json['value'] as String? ?? "",
  label: json['label'] as String? ?? "",
  count: (json['count'] as num?)?.toInt() ?? 0,
  coverItemId: (json['cover_item_id'] as num?)?.toInt(),
  coverTitle: json['cover_title'] as String?,
  coverUrl: json['cover_url'] as String?,
);

Map<String, dynamic> _$LibraryKindGenreViewToJson(
  _LibraryKindGenreView instance,
) => <String, dynamic>{
  'value': instance.value,
  'label': instance.label,
  'count': instance.count,
  'cover_item_id': instance.coverItemId,
  'cover_title': instance.coverTitle,
  'cover_url': instance.coverUrl,
};

_LibraryKindSummaryView _$LibraryKindSummaryViewFromJson(
  Map<String, dynamic> json,
) => _LibraryKindSummaryView(
  kind: json['kind'] as String? ?? "movie",
  libraryIds:
      (json['libraryIds'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList() ??
      const [],
  itemCount: (json['itemCount'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$LibraryKindSummaryViewToJson(
  _LibraryKindSummaryView instance,
) => <String, dynamic>{
  'kind': instance.kind,
  'libraryIds': instance.libraryIds,
  'itemCount': instance.itemCount,
};

_LibraryPayload _$LibraryPayloadFromJson(Map<String, dynamic> json) =>
    _LibraryPayload(
      name: json['name'] as String? ?? '',
      kind: json['kind'] as String? ?? "movie",
      source: json['source'] as String?,
      rootPaths:
          (json['rootPaths'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      generateThumbnails: json['generateThumbnails'] as bool?,
      extractChapterImages: json['extractChapterImages'] as bool?,
      detectMediaSegments: json['detectMediaSegments'] as bool?,
      excludeFromHome: json['excludeFromHome'] as bool?,
      autoSeriesCollections: json['autoSeriesCollections'] as bool?,
      accessMode: json['accessMode'] as String?,
      memberIds: (json['memberIds'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList(),
      autoClearMissing: json['autoClearMissing'] as bool?,
      realtimeWatch: json['realtimeWatch'] as bool?,
      scrapeOverrides: json['scrape_overrides'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$LibraryPayloadToJson(_LibraryPayload instance) =>
    <String, dynamic>{
      'name': instance.name,
      'kind': instance.kind,
      'source': instance.source,
      'rootPaths': instance.rootPaths,
      'generateThumbnails': instance.generateThumbnails,
      'extractChapterImages': instance.extractChapterImages,
      'detectMediaSegments': instance.detectMediaSegments,
      'excludeFromHome': instance.excludeFromHome,
      'autoSeriesCollections': instance.autoSeriesCollections,
      'accessMode': instance.accessMode,
      'memberIds': instance.memberIds,
      'autoClearMissing': instance.autoClearMissing,
      'realtimeWatch': instance.realtimeWatch,
      'scrape_overrides': instance.scrapeOverrides,
    };

_LibraryRecentAdditionView _$LibraryRecentAdditionViewFromJson(
  Map<String, dynamic> json,
) => _LibraryRecentAdditionView(
  seasonCount: (json['season_count'] as num?)?.toInt() ?? 0,
  episodeCount: (json['episode_count'] as num?)?.toInt() ?? 0,
  seasonNumber: (json['season_number'] as num?)?.toInt(),
  firstEpisodeNumber: (json['first_episode_number'] as num?)?.toInt(),
  lastEpisodeNumber: (json['last_episode_number'] as num?)?.toInt(),
  completeSeason: json['complete_season'] as bool? ?? false,
);

Map<String, dynamic> _$LibraryRecentAdditionViewToJson(
  _LibraryRecentAdditionView instance,
) => <String, dynamic>{
  'season_count': instance.seasonCount,
  'episode_count': instance.episodeCount,
  'season_number': instance.seasonNumber,
  'first_episode_number': instance.firstEpisodeNumber,
  'last_episode_number': instance.lastEpisodeNumber,
  'complete_season': instance.completeSeason,
};

_LibraryRelaxView _$LibraryRelaxViewFromJson(Map<String, dynamic> json) =>
    _LibraryRelaxView(
      total: (json['total'] as num?)?.toInt() ?? 0,
      suggestions:
          (json['suggestions'] as List<dynamic>?)
              ?.map(
                (e) => RelaxSuggestionView.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const [],
    );

Map<String, dynamic> _$LibraryRelaxViewToJson(_LibraryRelaxView instance) =>
    <String, dynamic>{
      'total': instance.total,
      'suggestions': instance.suggestions,
    };

_LibrarySearchGroup _$LibrarySearchGroupFromJson(Map<String, dynamic> json) =>
    _LibrarySearchGroup(
      libraryId: (json['libraryId'] as num?)?.toInt() ?? 0,
      libraryName: json['libraryName'] as String? ?? "",
      kind: json['kind'] as String? ?? "movie",
      items:
          (json['items'] as List<dynamic>?)
              ?.map((e) => LibraryItemView.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$LibrarySearchGroupToJson(_LibrarySearchGroup instance) =>
    <String, dynamic>{
      'libraryId': instance.libraryId,
      'libraryName': instance.libraryName,
      'kind': instance.kind,
      'items': instance.items,
    };

_LibrarySearchHit _$LibrarySearchHitFromJson(Map<String, dynamic> json) =>
    _LibrarySearchHit(
      item: json['item'] == null
          ? const LibraryItemView()
          : LibraryItemView.fromJson(json['item'] as Map<String, dynamic>),
      libraryIds:
          (json['library_ids'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [],
      match: json['match'] == null
          ? const LibrarySearchMatch()
          : LibrarySearchMatch.fromJson(json['match'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$LibrarySearchHitToJson(_LibrarySearchHit instance) =>
    <String, dynamic>{
      'item': instance.item,
      'library_ids': instance.libraryIds,
      'match': instance.match,
    };

_LibrarySearchMatch _$LibrarySearchMatchFromJson(Map<String, dynamic> json) =>
    _LibrarySearchMatch(
      type: json['type'] as String? ?? "",
      sourceField: json['source_field'] as String? ?? "",
      matchedName: json['matched_name'] as String? ?? "",
      label: json['label'] as String? ?? "",
      labelKey: json['label_key'] as String?,
      labelParams: json['label_params'] as Map<String, dynamic>?,
      personId: (json['person_id'] as num?)?.toInt(),
    );

Map<String, dynamic> _$LibrarySearchMatchToJson(_LibrarySearchMatch instance) =>
    <String, dynamic>{
      'type': instance.type,
      'source_field': instance.sourceField,
      'matched_name': instance.matchedName,
      'label': instance.label,
      'label_key': instance.labelKey,
      'label_params': instance.labelParams,
      'person_id': instance.personId,
    };

_LibrarySearchPerson _$LibrarySearchPersonFromJson(Map<String, dynamic> json) =>
    _LibrarySearchPerson(
      id: (json['id'] as num?)?.toInt() ?? 0,
      tmdbPersonId: (json['tmdb_person_id'] as num?)?.toInt(),
      name: json['name'] as String? ?? "",
      profilePath: json['profile_path'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      itemCount: (json['item_count'] as num?)?.toInt() ?? 0,
      match: json['match'] == null
          ? const LibrarySearchMatch()
          : LibrarySearchMatch.fromJson(json['match'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$LibrarySearchPersonToJson(
  _LibrarySearchPerson instance,
) => <String, dynamic>{
  'id': instance.id,
  'tmdb_person_id': instance.tmdbPersonId,
  'name': instance.name,
  'profile_path': instance.profilePath,
  'avatar_url': instance.avatarUrl,
  'item_count': instance.itemCount,
  'match': instance.match,
};

_LibrarySearchSuggestion _$LibrarySearchSuggestionFromJson(
  Map<String, dynamic> json,
) => _LibrarySearchSuggestion(
  type: json['type'] as String? ?? "",
  text: json['text'] as String? ?? "",
  label: json['label'] as String?,
  mediaItemId: (json['media_item_id'] as num?)?.toInt(),
  personId: (json['person_id'] as num?)?.toInt(),
);

Map<String, dynamic> _$LibrarySearchSuggestionToJson(
  _LibrarySearchSuggestion instance,
) => <String, dynamic>{
  'type': instance.type,
  'text': instance.text,
  'label': instance.label,
  'media_item_id': instance.mediaItemId,
  'person_id': instance.personId,
};

_LibrarySearchView _$LibrarySearchViewFromJson(Map<String, dynamic> json) =>
    _LibrarySearchView(
      query: json['query'] as String? ?? "",
      personId: (json['person_id'] as num?)?.toInt(),
      items:
          (json['items'] as List<dynamic>?)
              ?.map((e) => LibrarySearchHit.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      people:
          (json['people'] as List<dynamic>?)
              ?.map(
                (e) => LibrarySearchPerson.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const [],
      suggestions:
          (json['suggestions'] as List<dynamic>?)
              ?.map(
                (e) =>
                    LibrarySearchSuggestion.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const [],
      nextCursor: json['next_cursor'] as String?,
      indexPending: json['index_pending'] as bool? ?? false,
    );

Map<String, dynamic> _$LibrarySearchViewToJson(_LibrarySearchView instance) =>
    <String, dynamic>{
      'query': instance.query,
      'person_id': instance.personId,
      'items': instance.items,
      'people': instance.people,
      'suggestions': instance.suggestions,
      'next_cursor': instance.nextCursor,
      'index_pending': instance.indexPending,
    };

_LibraryStats _$LibraryStatsFromJson(Map<String, dynamic> json) =>
    _LibraryStats(
      itemCount: (json['item_count'] as num?)?.toInt() ?? 0,
      fileCount: (json['file_count'] as num?)?.toInt() ?? 0,
      totalSizeBytes: (json['total_size_bytes'] as num?)?.toInt() ?? 0,
      unidentifiedCount: (json['unidentified_count'] as num?)?.toInt() ?? 0,
      missingCount: (json['missing_count'] as num?)?.toInt() ?? 0,
      ignoredCount: (json['ignored_count'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$LibraryStatsToJson(_LibraryStats instance) =>
    <String, dynamic>{
      'item_count': instance.itemCount,
      'file_count': instance.fileCount,
      'total_size_bytes': instance.totalSizeBytes,
      'unidentified_count': instance.unidentifiedCount,
      'missing_count': instance.missingCount,
      'ignored_count': instance.ignoredCount,
    };

_LibraryView _$LibraryViewFromJson(Map<String, dynamic> json) => _LibraryView(
  id: (json['id'] as num?)?.toInt() ?? 0,
  name: json['name'] as String? ?? "",
  kind: json['kind'] as String? ?? "",
  source: json['source'] as String? ?? "",
  sourceTitle: json['source_title'] as String?,
  sourceIcon: json['source_icon'] as String?,
  sourceConfigured: json['source_configured'] as bool? ?? false,
  lastSourceSyncAt: json['last_source_sync_at'] as String?,
  capabilities: json['capabilities'] == null
      ? const LibraryCapabilitiesView()
      : LibraryCapabilitiesView.fromJson(
          json['capabilities'] as Map<String, dynamic>,
        ),
  generateThumbnails: json['generate_thumbnails'] as bool? ?? false,
  extractChapterImages: json['extract_chapter_images'] as bool? ?? false,
  detectMediaSegments: json['detect_media_segments'] as bool? ?? false,
  excludeFromHome: json['exclude_from_home'] as bool? ?? false,
  autoSeriesCollections: json['auto_series_collections'] as bool? ?? false,
  accessMode: json['access_mode'] as String? ?? "",
  adminVisible: json['admin_visible'] as bool? ?? false,
  memberIds:
      (json['member_ids'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList() ??
      const [],
  viewerAccess: json['viewer_access'] as bool? ?? false,
  rootPaths:
      (json['root_paths'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  primaryRoot: json['primary_root'] as String?,
  isDefault: json['is_default'] as bool? ?? false,
  matchRules:
      (json['match_rules'] as List<dynamic>?)
          ?.map((e) => e as Map<String, dynamic>)
          .toList() ??
      const [],
  autoClearMissing: json['auto_clear_missing'] as bool? ?? false,
  realtimeWatch: json['realtime_watch'] as bool? ?? false,
  keepLocal: json['keep_local'] as bool?,
  networkMount: json['network_mount'] as bool? ?? false,
  customCover: json['custom_cover'] as bool? ?? false,
  scrapeOverrides:
      json['scrape_overrides'] as Map<String, dynamic>? ?? const {},
  stats: json['stats'] == null
      ? const LibraryStats()
      : LibraryStats.fromJson(json['stats'] as Map<String, dynamic>),
  scanning: json['scanning'] as bool? ?? false,
  scanProgress: json['scan_progress'] == null
      ? null
      : ScanProgressView.fromJson(
          json['scan_progress'] as Map<String, dynamic>,
        ),
  lastScan: json['last_scan'] == null
      ? null
      : LastScanView.fromJson(json['last_scan'] as Map<String, dynamic>),
  organizing: json['organizing'] as bool? ?? false,
  organizeProgress: json['organize_progress'] == null
      ? null
      : ScanProgressView.fromJson(
          json['organize_progress'] as Map<String, dynamic>,
        ),
  lastOrganize: json['last_organize'] == null
      ? null
      : LastOrganizeView.fromJson(
          json['last_organize'] as Map<String, dynamic>,
        ),
  metadataRefresh: json['metadata_refresh'] == null
      ? null
      : MetadataRefreshView.fromJson(
          json['metadata_refresh'] as Map<String, dynamic>,
        ),
  chapterJob: json['chapter_job'] == null
      ? null
      : ChapterJobView.fromJson(json['chapter_job'] as Map<String, dynamic>),
  cloudUpload: json['cloud_upload'] == null
      ? null
      : CloudUploadView.fromJson(json['cloud_upload'] as Map<String, dynamic>),
  cloudFolders: (json['cloud_folders'] as List<dynamic>?)
      ?.map((e) => CloudFolderView.fromJson(e as Map<String, dynamic>))
      .toList(),
  createdAt: json['created_at'] as String? ?? "",
  updatedAt: json['updated_at'] as String? ?? "",
);

Map<String, dynamic> _$LibraryViewToJson(_LibraryView instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'kind': instance.kind,
      'source': instance.source,
      'source_title': instance.sourceTitle,
      'source_icon': instance.sourceIcon,
      'source_configured': instance.sourceConfigured,
      'last_source_sync_at': instance.lastSourceSyncAt,
      'capabilities': instance.capabilities,
      'generate_thumbnails': instance.generateThumbnails,
      'extract_chapter_images': instance.extractChapterImages,
      'detect_media_segments': instance.detectMediaSegments,
      'exclude_from_home': instance.excludeFromHome,
      'auto_series_collections': instance.autoSeriesCollections,
      'access_mode': instance.accessMode,
      'admin_visible': instance.adminVisible,
      'member_ids': instance.memberIds,
      'viewer_access': instance.viewerAccess,
      'root_paths': instance.rootPaths,
      'primary_root': instance.primaryRoot,
      'is_default': instance.isDefault,
      'match_rules': instance.matchRules,
      'auto_clear_missing': instance.autoClearMissing,
      'realtime_watch': instance.realtimeWatch,
      'keep_local': instance.keepLocal,
      'network_mount': instance.networkMount,
      'custom_cover': instance.customCover,
      'scrape_overrides': instance.scrapeOverrides,
      'stats': instance.stats,
      'scanning': instance.scanning,
      'scan_progress': instance.scanProgress,
      'last_scan': instance.lastScan,
      'organizing': instance.organizing,
      'organize_progress': instance.organizeProgress,
      'last_organize': instance.lastOrganize,
      'metadata_refresh': instance.metadataRefresh,
      'chapter_job': instance.chapterJob,
      'cloud_upload': instance.cloudUpload,
      'cloud_folders': instance.cloudFolders,
      'created_at': instance.createdAt,
      'updated_at': instance.updatedAt,
    };

_LlmDefaultsPayload _$LlmDefaultsPayloadFromJson(Map<String, dynamic> json) =>
    _LlmDefaultsPayload(
      agentModel: json['agent_model'] as String?,
      subtitleModel: json['subtitle_model'] as String?,
    );

Map<String, dynamic> _$LlmDefaultsPayloadToJson(_LlmDefaultsPayload instance) =>
    <String, dynamic>{
      'agent_model': instance.agentModel,
      'subtitle_model': instance.subtitleModel,
    };

_LlmDefaultsView _$LlmDefaultsViewFromJson(Map<String, dynamic> json) =>
    _LlmDefaultsView(
      agentModel: json['agent_model'] as String?,
      subtitleModel: json['subtitle_model'] as String?,
      effectiveAgentModel: json['effective_agent_model'] as String?,
      effectiveSubtitleModel: json['effective_subtitle_model'] as String?,
    );

Map<String, dynamic> _$LlmDefaultsViewToJson(_LlmDefaultsView instance) =>
    <String, dynamic>{
      'agent_model': instance.agentModel,
      'subtitle_model': instance.subtitleModel,
      'effective_agent_model': instance.effectiveAgentModel,
      'effective_subtitle_model': instance.effectiveSubtitleModel,
    };

_LlmModelInfo _$LlmModelInfoFromJson(Map<String, dynamic> json) =>
    _LlmModelInfo(
      id: json['id'] as String? ?? "",
      contextWindow: (json['contextWindow'] as num?)?.toInt(),
      maxInputTokens: (json['maxInputTokens'] as num?)?.toInt(),
      maxOutputTokens: (json['maxOutputTokens'] as num?)?.toInt(),
      supportsTools: json['supportsTools'] as bool? ?? true,
      supportsParallelToolCalls:
          json['supportsParallelToolCalls'] as bool? ?? false,
      supportsThinking: json['supportsThinking'] as bool? ?? false,
      maxThinkingTokens: (json['maxThinkingTokens'] as num?)?.toInt(),
      thinkingControl: json['thinkingControl'] == null
          ? null
          : LlmThinkingControl.fromJson(
              json['thinkingControl'] as Map<String, dynamic>,
            ),
      modalities:
          (json['modalities'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      thinkingLevels:
          (json['thinkingLevels'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );

Map<String, dynamic> _$LlmModelInfoToJson(_LlmModelInfo instance) =>
    <String, dynamic>{
      'id': instance.id,
      'contextWindow': instance.contextWindow,
      'maxInputTokens': instance.maxInputTokens,
      'maxOutputTokens': instance.maxOutputTokens,
      'supportsTools': instance.supportsTools,
      'supportsParallelToolCalls': instance.supportsParallelToolCalls,
      'supportsThinking': instance.supportsThinking,
      'maxThinkingTokens': instance.maxThinkingTokens,
      'thinkingControl': instance.thinkingControl,
      'modalities': instance.modalities,
      'thinkingLevels': instance.thinkingLevels,
    };

_LlmModelOption _$LlmModelOptionFromJson(Map<String, dynamic> json) =>
    _LlmModelOption(
      ref: json['ref'] as String? ?? "",
      label: json['label'] as String? ?? "",
      modelId: json['modelId'] as String?,
      providerId: (json['providerId'] as num?)?.toInt(),
      providerName: json['providerName'] as String?,
      isDefault: json['isDefault'] as bool? ?? false,
      thinkingLevels:
          (json['thinkingLevels'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );

Map<String, dynamic> _$LlmModelOptionToJson(_LlmModelOption instance) =>
    <String, dynamic>{
      'ref': instance.ref,
      'label': instance.label,
      'modelId': instance.modelId,
      'providerId': instance.providerId,
      'providerName': instance.providerName,
      'isDefault': instance.isDefault,
      'thinkingLevels': instance.thinkingLevels,
    };

_LlmPresetView _$LlmPresetViewFromJson(Map<String, dynamic> json) =>
    _LlmPresetView(
      id: json['id'] as String? ?? "",
      displayName: json['displayName'] as String? ?? "",
      baseUrl: json['baseUrl'] as String?,
      requiresBaseUrl: json['requiresBaseUrl'] as bool? ?? false,
      defaultUserAgent: json['defaultUserAgent'] as String? ?? "",
      protocol: json['protocol'] as String?,
      selectableProtocols:
          (json['selectableProtocols'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      models:
          (json['models'] as List<dynamic>?)
              ?.map((e) => LlmModelInfo.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$LlmPresetViewToJson(_LlmPresetView instance) =>
    <String, dynamic>{
      'id': instance.id,
      'displayName': instance.displayName,
      'baseUrl': instance.baseUrl,
      'requiresBaseUrl': instance.requiresBaseUrl,
      'defaultUserAgent': instance.defaultUserAgent,
      'protocol': instance.protocol,
      'selectableProtocols': instance.selectableProtocols,
      'models': instance.models,
    };

_LlmProviderPayload _$LlmProviderPayloadFromJson(Map<String, dynamic> json) =>
    _LlmProviderPayload(
      name: json['name'] as String? ?? '',
      providerType: json['providerType'] as String? ?? '',
      baseUrl: json['baseUrl'] as String?,
      userAgent: json['userAgent'] as String?,
      apiProtocol: json['apiProtocol'] as String?,
      apiKey: json['apiKey'] as String?,
      defaultModel: json['defaultModel'] as String?,
      extraModels:
          (json['extraModels'] as List<dynamic>?)
              ?.map((e) => LlmModelInfo.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$LlmProviderPayloadToJson(_LlmProviderPayload instance) =>
    <String, dynamic>{
      'name': instance.name,
      'providerType': instance.providerType,
      'baseUrl': instance.baseUrl,
      'userAgent': instance.userAgent,
      'apiProtocol': instance.apiProtocol,
      'apiKey': instance.apiKey,
      'defaultModel': instance.defaultModel,
      'extraModels': instance.extraModels,
    };

_LlmProviderView _$LlmProviderViewFromJson(Map<String, dynamic> json) =>
    _LlmProviderView(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? "",
      providerType: json['providerType'] as String? ?? "",
      baseUrl: json['baseUrl'] as String?,
      userAgent: json['userAgent'] as String?,
      apiProtocol: json['apiProtocol'] as String?,
      defaultModel: json['defaultModel'] as String? ?? "",
      status: json['status'] as String? ?? "pending",
      usable: json['usable'] as bool? ?? false,
      lastError: json['lastError'] as String?,
      lastCheckedAt: json['lastCheckedAt'] as String?,
      availableModels: (json['availableModels'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      extraModels:
          (json['extraModels'] as List<dynamic>?)
              ?.map((e) => LlmModelInfo.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
    );

Map<String, dynamic> _$LlmProviderViewToJson(_LlmProviderView instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'providerType': instance.providerType,
      'baseUrl': instance.baseUrl,
      'userAgent': instance.userAgent,
      'apiProtocol': instance.apiProtocol,
      'defaultModel': instance.defaultModel,
      'status': instance.status,
      'usable': instance.usable,
      'lastError': instance.lastError,
      'lastCheckedAt': instance.lastCheckedAt,
      'availableModels': instance.availableModels,
      'extraModels': instance.extraModels,
      'createdAt': instance.createdAt,
      'updatedAt': instance.updatedAt,
    };

_LlmThinkingControl _$LlmThinkingControlFromJson(Map<String, dynamic> json) =>
    _LlmThinkingControl(
      kind: json['kind'] as String? ?? "",
      levels:
          (json['levels'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      supportsOff: json['supportsOff'] as bool? ?? false,
    );

Map<String, dynamic> _$LlmThinkingControlToJson(_LlmThinkingControl instance) =>
    <String, dynamic>{
      'kind': instance.kind,
      'levels': instance.levels,
      'supportsOff': instance.supportsOff,
    };

_LocalMetaView _$LocalMetaViewFromJson(
  Map<String, dynamic> json,
) => _LocalMetaView(
  plot: json['plot'] as String?,
  rating: (json['rating'] as num?)?.toDouble(),
  runtimeMinutes: (json['runtime_minutes'] as num?)?.toInt(),
  genres:
      (json['genres'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  directors:
      (json['directors'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  directorCredits:
      (json['director_credits'] as List<dynamic>?)
          ?.map((e) => DirectorView.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  actors:
      (json['actors'] as List<dynamic>?)
          ?.map((e) => ActorView.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  nfoName: json['nfo_name'] as String? ?? "",
  source: json['source'] as String? ?? "",
);

Map<String, dynamic> _$LocalMetaViewToJson(_LocalMetaView instance) =>
    <String, dynamic>{
      'plot': instance.plot,
      'rating': instance.rating,
      'runtime_minutes': instance.runtimeMinutes,
      'genres': instance.genres,
      'directors': instance.directors,
      'director_credits': instance.directorCredits,
      'actors': instance.actors,
      'nfo_name': instance.nfoName,
      'source': instance.source,
    };

_LogContent _$LogContentFromJson(Map<String, dynamic> json) => _LogContent(
  day: json['day'] as String? ?? "",
  lines:
      (json['lines'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  totalLines: (json['totalLines'] as num?)?.toInt() ?? 0,
  truncated: json['truncated'] as bool? ?? false,
  sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$LogContentToJson(_LogContent instance) =>
    <String, dynamic>{
      'day': instance.day,
      'lines': instance.lines,
      'totalLines': instance.totalLines,
      'truncated': instance.truncated,
      'sizeBytes': instance.sizeBytes,
    };

_LogDay _$LogDayFromJson(Map<String, dynamic> json) => _LogDay(
  day: json['day'] as String? ?? "",
  sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$LogDayToJson(_LogDay instance) => <String, dynamic>{
  'day': instance.day,
  'sizeBytes': instance.sizeBytes,
};

_LogDayList _$LogDayListFromJson(Map<String, dynamic> json) => _LogDayList(
  days:
      (json['days'] as List<dynamic>?)
          ?.map((e) => LogDay.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
);

Map<String, dynamic> _$LogDayListToJson(_LogDayList instance) =>
    <String, dynamic>{'days': instance.days};

_LoginDevice _$LoginDeviceFromJson(Map<String, dynamic> json) => _LoginDevice(
  id: json['id'] as String? ?? '',
  kind: json['kind'] as String? ?? "",
  kindLabel: json['kindLabel'] as String? ?? "",
  family: json['family'] as String? ?? "",
  name: json['name'] as String? ?? "",
  scope: json['scope'] as String? ?? "full",
  platform: json['platform'] as String?,
  clientVersion: json['clientVersion'] as String?,
  createdAt: json['createdAt'] as String?,
  lastSeenAt: json['lastSeenAt'] as String?,
  lastSeenIp: json['lastSeenIp'] as String?,
  current: json['current'] as bool? ?? false,
  connected: json['connected'] as bool? ?? false,
  renamable: json['renamable'] as bool? ?? true,
  ownerId: (json['ownerId'] as num?)?.toInt() ?? 0,
  ownerUsername: json['ownerUsername'] as String? ?? "",
  ownerNickname: json['ownerNickname'] as String? ?? "",
);

Map<String, dynamic> _$LoginDeviceToJson(_LoginDevice instance) =>
    <String, dynamic>{
      'id': instance.id,
      'kind': instance.kind,
      'kindLabel': instance.kindLabel,
      'family': instance.family,
      'name': instance.name,
      'scope': instance.scope,
      'platform': instance.platform,
      'clientVersion': instance.clientVersion,
      'createdAt': instance.createdAt,
      'lastSeenAt': instance.lastSeenAt,
      'lastSeenIp': instance.lastSeenIp,
      'current': instance.current,
      'connected': instance.connected,
      'renamable': instance.renamable,
      'ownerId': instance.ownerId,
      'ownerUsername': instance.ownerUsername,
      'ownerNickname': instance.ownerNickname,
    };

_LoginDeviceView _$LoginDeviceViewFromJson(Map<String, dynamic> json) =>
    _LoginDeviceView(
      id: json['id'] as String? ?? "",
      kind: json['kind'] as String? ?? "",
      kindLabel: json['kind_label'] as String? ?? "",
      family: json['family'] as String? ?? "",
      name: json['name'] as String? ?? "",
      scope: json['scope'] as String? ?? "",
      platform: json['platform'] as String?,
      clientVersion: json['client_version'] as String?,
      createdAt: json['created_at'] as String? ?? "",
      lastSeenAt: json['last_seen_at'] as String?,
      lastSeenIp: json['last_seen_ip'] as String?,
      expiresAt: json['expires_at'] as String?,
      current: json['current'] as bool? ?? false,
      connected: json['connected'] as bool? ?? false,
      renamable: json['renamable'] as bool? ?? false,
      ownerId: (json['owner_id'] as num?)?.toInt() ?? 0,
      ownerUsername: json['owner_username'] as String? ?? "",
      ownerNickname: json['owner_nickname'] as String? ?? "",
      push: json['push'] == null
          ? null
          : DevicePushView.fromJson(json['push'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$LoginDeviceViewToJson(_LoginDeviceView instance) =>
    <String, dynamic>{
      'id': instance.id,
      'kind': instance.kind,
      'kind_label': instance.kindLabel,
      'family': instance.family,
      'name': instance.name,
      'scope': instance.scope,
      'platform': instance.platform,
      'client_version': instance.clientVersion,
      'created_at': instance.createdAt,
      'last_seen_at': instance.lastSeenAt,
      'last_seen_ip': instance.lastSeenIp,
      'expires_at': instance.expiresAt,
      'current': instance.current,
      'connected': instance.connected,
      'renamable': instance.renamable,
      'owner_id': instance.ownerId,
      'owner_username': instance.ownerUsername,
      'owner_nickname': instance.ownerNickname,
      'push': instance.push,
    };

_ManualDownloadCandidateView _$ManualDownloadCandidateViewFromJson(
  Map<String, dynamic> json,
) => _ManualDownloadCandidateView(
  tmdbId: (json['tmdbId'] as num?)?.toInt() ?? 0,
  kind: json['kind'] as String? ?? "movie",
  title: json['title'] as String? ?? "",
  year: (json['year'] as num?)?.toInt(),
  episodeCount: (json['episodeCount'] as num?)?.toInt(),
  posterUrl: json['posterUrl'] as String?,
);

Map<String, dynamic> _$ManualDownloadCandidateViewToJson(
  _ManualDownloadCandidateView instance,
) => <String, dynamic>{
  'tmdbId': instance.tmdbId,
  'kind': instance.kind,
  'title': instance.title,
  'year': instance.year,
  'episodeCount': instance.episodeCount,
  'posterUrl': instance.posterUrl,
};

_ManualDownloadTargetRequest _$ManualDownloadTargetRequestFromJson(
  Map<String, dynamic> json,
) => _ManualDownloadTargetRequest(
  kind: json['kind'] as String?,
  title: json['title'] as String?,
  year: (json['year'] as num?)?.toInt(),
  subtitle: json['subtitle'] as String?,
  hint: json['hint'] as String?,
  downloaderId: (json['downloaderId'] as num?)?.toInt(),
  selectedTmdbId: (json['selectedTmdbId'] as num?)?.toInt(),
  selectedKind: json['selectedKind'] as String?,
);

Map<String, dynamic> _$ManualDownloadTargetRequestToJson(
  _ManualDownloadTargetRequest instance,
) => <String, dynamic>{
  'kind': instance.kind,
  'title': instance.title,
  'year': instance.year,
  'subtitle': instance.subtitle,
  'hint': instance.hint,
  'downloaderId': instance.downloaderId,
  'selectedTmdbId': instance.selectedTmdbId,
  'selectedKind': instance.selectedKind,
};

_ManualDownloadTargetView _$ManualDownloadTargetViewFromJson(
  Map<String, dynamic> json,
) => _ManualDownloadTargetView(
  status: json['status'] as String? ?? "not_found",
  tmdbId: (json['tmdbId'] as num?)?.toInt(),
  kind: json['kind'] as String?,
  title: json['title'] as String?,
  year: (json['year'] as num?)?.toInt(),
  candidates:
      (json['candidates'] as List<dynamic>?)
          ?.map(
            (e) =>
                ManualDownloadCandidateView.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const [],
  libraryId: (json['libraryId'] as num?)?.toInt(),
  libraryName: json['libraryName'] as String?,
  mode: json['mode'] as String?,
  path: json['path'] as String?,
  entryDir: json['entryDir'] as String?,
  stagingPath: json['stagingPath'] as String?,
  routeMatched: json['routeMatched'] as bool?,
  routeReason: json['routeReason'] as String?,
  ok: json['ok'] as bool? ?? false,
  warning: json['warning'] as String?,
);

Map<String, dynamic> _$ManualDownloadTargetViewToJson(
  _ManualDownloadTargetView instance,
) => <String, dynamic>{
  'status': instance.status,
  'tmdbId': instance.tmdbId,
  'kind': instance.kind,
  'title': instance.title,
  'year': instance.year,
  'candidates': instance.candidates,
  'libraryId': instance.libraryId,
  'libraryName': instance.libraryName,
  'mode': instance.mode,
  'path': instance.path,
  'entryDir': instance.entryDir,
  'stagingPath': instance.stagingPath,
  'routeMatched': instance.routeMatched,
  'routeReason': instance.routeReason,
  'ok': instance.ok,
  'warning': instance.warning,
};

_MatroskaCuesView _$MatroskaCuesViewFromJson(Map<String, dynamic> json) =>
    _MatroskaCuesView(
      offset: (json['offset'] as num?)?.toInt() ?? 0,
      data: json['data'] as String? ?? "",
      originalBytes: (json['original_bytes'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$MatroskaCuesViewToJson(_MatroskaCuesView instance) =>
    <String, dynamic>{
      'offset': instance.offset,
      'data': instance.data,
      'original_bytes': instance.originalBytes,
    };

_McpEndpointView _$McpEndpointViewFromJson(Map<String, dynamic> json) =>
    _McpEndpointView(
      id: json['id'] as String? ?? "",
      slug: json['slug'] as String? ?? "",
      name: json['name'] as String? ?? "",
      description: json['description'] as String? ?? "",
      enabled: json['enabled'] as bool? ?? false,
      services:
          (json['services'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      toolCount: (json['tool_count'] as num?)?.toInt() ?? 0,
      url: json['url'] as String? ?? "",
      lastUsedAt: json['last_used_at'] as String?,
    );

Map<String, dynamic> _$McpEndpointViewToJson(_McpEndpointView instance) =>
    <String, dynamic>{
      'id': instance.id,
      'slug': instance.slug,
      'name': instance.name,
      'description': instance.description,
      'enabled': instance.enabled,
      'services': instance.services,
      'tool_count': instance.toolCount,
      'url': instance.url,
      'last_used_at': instance.lastUsedAt,
    };

_McpStatusView _$McpStatusViewFromJson(Map<String, dynamic> json) =>
    _McpStatusView(
      enabled: json['enabled'] as bool? ?? false,
      baseUrl: json['base_url'] as String? ?? "",
      externalUrlConfigured: json['external_url_configured'] as bool? ?? false,
      endpoints:
          (json['endpoints'] as List<dynamic>?)
              ?.map((e) => McpEndpointView.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$McpStatusViewToJson(_McpStatusView instance) =>
    <String, dynamic>{
      'enabled': instance.enabled,
      'base_url': instance.baseUrl,
      'external_url_configured': instance.externalUrlConfigured,
      'endpoints': instance.endpoints,
    };

_McpToggleRequest _$McpToggleRequestFromJson(Map<String, dynamic> json) =>
    _McpToggleRequest(enabled: json['enabled'] as bool? ?? false);

Map<String, dynamic> _$McpToggleRequestToJson(_McpToggleRequest instance) =>
    <String, dynamic>{'enabled': instance.enabled};

_MediaActivityTarget _$MediaActivityTargetFromJson(Map<String, dynamic> json) =>
    _MediaActivityTarget(
      mediaItemId: (json['mediaItemId'] as num?)?.toInt() ?? 0,
      libraryId: (json['libraryId'] as num?)?.toInt(),
      browsable: json['browsable'] as bool? ?? true,
      kind: json['kind'] as String? ?? "movie",
      title: json['title'] as String? ?? "",
      year: (json['year'] as num?)?.toInt(),
      posterUrl: json['posterUrl'] as String?,
      seasonNumber: (json['seasonNumber'] as num?)?.toInt() ?? 0,
      episodeNumber: (json['episodeNumber'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$MediaActivityTargetToJson(
  _MediaActivityTarget instance,
) => <String, dynamic>{
  'mediaItemId': instance.mediaItemId,
  'libraryId': instance.libraryId,
  'browsable': instance.browsable,
  'kind': instance.kind,
  'title': instance.title,
  'year': instance.year,
  'posterUrl': instance.posterUrl,
  'seasonNumber': instance.seasonNumber,
  'episodeNumber': instance.episodeNumber,
};

_MediaBrief _$MediaBriefFromJson(Map<String, dynamic> json) => _MediaBrief(
  mediaItemId: (json['media_item_id'] as num?)?.toInt() ?? 0,
  kind: json['kind'] as String? ?? "",
  tmdbId: (json['tmdb_id'] as num?)?.toInt() ?? 0,
  doubanId: json['douban_id'] as String?,
  title: json['title'] as String? ?? "",
  originalTitle: json['original_title'] as String? ?? "",
  englishTitle: json['english_title'] as String?,
  year: (json['year'] as num?)?.toInt(),
  posterUrl: json['poster_url'] as String?,
  backdropUrl: json['backdrop_url'] as String?,
  logoUrl: json['logo_url'] as String?,
  status: json['status'] as String?,
);

Map<String, dynamic> _$MediaBriefToJson(_MediaBrief instance) =>
    <String, dynamic>{
      'media_item_id': instance.mediaItemId,
      'kind': instance.kind,
      'tmdb_id': instance.tmdbId,
      'douban_id': instance.doubanId,
      'title': instance.title,
      'original_title': instance.originalTitle,
      'english_title': instance.englishTitle,
      'year': instance.year,
      'poster_url': instance.posterUrl,
      'backdrop_url': instance.backdropUrl,
      'logo_url': instance.logoUrl,
      'status': instance.status,
    };

_MediaImage _$MediaImageFromJson(Map<String, dynamic> json) => _MediaImage(
  previewUrl: json['previewUrl'] as String? ?? "",
  fullUrl: json['fullUrl'] as String? ?? "",
  width: (json['width'] as num?)?.toInt() ?? 0,
  height: (json['height'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$MediaImageToJson(_MediaImage instance) =>
    <String, dynamic>{
      'previewUrl': instance.previewUrl,
      'fullUrl': instance.fullUrl,
      'width': instance.width,
      'height': instance.height,
    };

_MediaLibraryLink _$MediaLibraryLinkFromJson(Map<String, dynamic> json) =>
    _MediaLibraryLink(
      libraryId: (json['libraryId'] as num?)?.toInt() ?? 0,
      libraryName: json['libraryName'] as String? ?? "",
      mediaItemId: (json['mediaItemId'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$MediaLibraryLinkToJson(_MediaLibraryLink instance) =>
    <String, dynamic>{
      'libraryId': instance.libraryId,
      'libraryName': instance.libraryName,
      'mediaItemId': instance.mediaItemId,
    };

_MediaLibraryStatus _$MediaLibraryStatusFromJson(Map<String, dynamic> json) =>
    _MediaLibraryStatus(
      mediaItemId: (json['mediaItemId'] as num?)?.toInt() ?? 0,
      libraryCount: (json['libraryCount'] as num?)?.toInt() ?? 0,
      fileCount: (json['fileCount'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$MediaLibraryStatusToJson(_MediaLibraryStatus instance) =>
    <String, dynamic>{
      'mediaItemId': instance.mediaItemId,
      'libraryCount': instance.libraryCount,
      'fileCount': instance.fileCount,
    };

_MediaVideo _$MediaVideoFromJson(Map<String, dynamic> json) => _MediaVideo(
  key: json['key'] as String? ?? "",
  name: json['name'] as String? ?? "",
);

Map<String, dynamic> _$MediaVideoToJson(_MediaVideo instance) =>
    <String, dynamic>{'key': instance.key, 'name': instance.name};

_MemberCreateRequest _$MemberCreateRequestFromJson(Map<String, dynamic> json) =>
    _MemberCreateRequest(
      username: json['username'] as String? ?? '',
      password: json['password'] as String? ?? '',
      nickname: json['nickname'] as String? ?? "",
    );

Map<String, dynamic> _$MemberCreateRequestToJson(
  _MemberCreateRequest instance,
) => <String, dynamic>{
  'username': instance.username,
  'password': instance.password,
  'nickname': instance.nickname,
};

_MemberPasswordReset _$MemberPasswordResetFromJson(Map<String, dynamic> json) =>
    _MemberPasswordReset(
      id: (json['id'] as num?)?.toInt() ?? 0,
      username: json['username'] as String? ?? "",
      password: json['password'] as String? ?? "",
    );

Map<String, dynamic> _$MemberPasswordResetToJson(
  _MemberPasswordReset instance,
) => <String, dynamic>{
  'id': instance.id,
  'username': instance.username,
  'password': instance.password,
};

_MemberStatusRequest _$MemberStatusRequestFromJson(Map<String, dynamic> json) =>
    _MemberStatusRequest(enabled: json['enabled'] as bool? ?? false);

Map<String, dynamic> _$MemberStatusRequestToJson(
  _MemberStatusRequest instance,
) => <String, dynamic>{'enabled': instance.enabled};

_MemberUpdateRequest _$MemberUpdateRequestFromJson(Map<String, dynamic> json) =>
    _MemberUpdateRequest(
      nickname: json['nickname'] as String?,
      allowSubscribe: json['allowSubscribe'] as bool?,
      allowSearch: json['allowSearch'] as bool?,
      allowDirectDownload: json['allowDirectDownload'] as bool?,
      allLibraries: json['allLibraries'] as bool?,
      libraryIds: (json['libraryIds'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList(),
    );

Map<String, dynamic> _$MemberUpdateRequestToJson(
  _MemberUpdateRequest instance,
) => <String, dynamic>{
  'nickname': instance.nickname,
  'allowSubscribe': instance.allowSubscribe,
  'allowSearch': instance.allowSearch,
  'allowDirectDownload': instance.allowDirectDownload,
  'allLibraries': instance.allLibraries,
  'libraryIds': instance.libraryIds,
};

_MemberView _$MemberViewFromJson(Map<String, dynamic> json) => _MemberView(
  id: (json['id'] as num?)?.toInt() ?? 0,
  username: json['username'] as String? ?? "",
  nickname: json['nickname'] as String? ?? "",
  avatarUrl: json['avatarUrl'] as String?,
  status: json['status'] as String? ?? "active",
  lastLoginAt: json['lastLoginAt'] as String?,
  allowSubscribe: json['allowSubscribe'] as bool? ?? false,
  allowSearch: json['allowSearch'] as bool? ?? false,
  allowDirectDownload: json['allowDirectDownload'] as bool? ?? false,
  allLibraries: json['allLibraries'] as bool? ?? true,
  libraryIds:
      (json['libraryIds'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList() ??
      const [],
  deviceCount: (json['deviceCount'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$MemberViewToJson(_MemberView instance) =>
    <String, dynamic>{
      'id': instance.id,
      'username': instance.username,
      'nickname': instance.nickname,
      'avatarUrl': instance.avatarUrl,
      'status': instance.status,
      'lastLoginAt': instance.lastLoginAt,
      'allowSubscribe': instance.allowSubscribe,
      'allowSearch': instance.allowSearch,
      'allowDirectDownload': instance.allowDirectDownload,
      'allLibraries': instance.allLibraries,
      'libraryIds': instance.libraryIds,
      'deviceCount': instance.deviceCount,
    };

_MetadataRefreshView _$MetadataRefreshViewFromJson(Map<String, dynamic> json) =>
    _MetadataRefreshView(
      refreshing: json['refreshing'] as bool? ?? false,
      processed: (json['processed'] as num?)?.toInt() ?? 0,
      total: (json['total'] as num?)?.toInt() ?? 0,
      failed: (json['failed'] as num?)?.toInt() ?? 0,
      stopping: json['stopping'] as bool? ?? false,
      active:
          (json['active'] as List<dynamic>?)
              ?.map(
                (e) => RefreshActiveView.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const [],
    );

Map<String, dynamic> _$MetadataRefreshViewToJson(
  _MetadataRefreshView instance,
) => <String, dynamic>{
  'refreshing': instance.refreshing,
  'processed': instance.processed,
  'total': instance.total,
  'failed': instance.failed,
  'stopping': instance.stopping,
  'active': instance.active,
};

_ModelUpdateCheck _$ModelUpdateCheckFromJson(Map<String, dynamic> json) =>
    _ModelUpdateCheck(
      currentTag: json['currentTag'] as String?,
      latestTag: json['latestTag'] as String? ?? "",
      updateAvailable: json['updateAvailable'] as bool? ?? false,
      installable: json['installable'] as bool? ?? false,
      publishedAt: json['publishedAt'] as String? ?? "",
    );

Map<String, dynamic> _$ModelUpdateCheckToJson(_ModelUpdateCheck instance) =>
    <String, dynamic>{
      'currentTag': instance.currentTag,
      'latestTag': instance.latestTag,
      'updateAvailable': instance.updateAvailable,
      'installable': instance.installable,
      'publishedAt': instance.publishedAt,
    };

_MyPushView _$MyPushViewFromJson(Map<String, dynamic> json) => _MyPushView(
  events:
      (json['events'] as List<dynamic>?)
          ?.map((e) => PushEventPref.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
);

Map<String, dynamic> _$MyPushViewToJson(_MyPushView instance) =>
    <String, dynamic>{'events': instance.events};

_NavUiPrefs _$NavUiPrefsFromJson(Map<String, dynamic> json) => _NavUiPrefs(
  order:
      (json['order'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  hidden: (json['hidden'] as List<dynamic>?)?.map((e) => e as String).toList(),
);

Map<String, dynamic> _$NavUiPrefsToJson(_NavUiPrefs instance) =>
    <String, dynamic>{'order': instance.order, 'hidden': instance.hidden};

_NetworkConfig _$NetworkConfigFromJson(Map<String, dynamic> json) =>
    _NetworkConfig(
      proxyMode: json['proxyMode'] as String? ?? "off",
      proxyUrl: json['proxyUrl'] as String? ?? "",
      proxyServices:
          (json['proxyServices'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      tmdbApiBaseUrl: json['tmdbApiBaseUrl'] as String? ?? "",
      tmdbImageBaseUrl: json['tmdbImageBaseUrl'] as String? ?? "",
      doubanApiBaseUrl: json['doubanApiBaseUrl'] as String? ?? "",
      services:
          (json['services'] as List<dynamic>?)
              ?.map((e) => EgressService.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      envProxyDetected: json['env_proxy_detected'] as String? ?? "",
      mirrorDefaults:
          (json['mirror_defaults'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, e as String),
          ) ??
          const {},
    );

Map<String, dynamic> _$NetworkConfigToJson(_NetworkConfig instance) =>
    <String, dynamic>{
      'proxyMode': instance.proxyMode,
      'proxyUrl': instance.proxyUrl,
      'proxyServices': instance.proxyServices,
      'tmdbApiBaseUrl': instance.tmdbApiBaseUrl,
      'tmdbImageBaseUrl': instance.tmdbImageBaseUrl,
      'doubanApiBaseUrl': instance.doubanApiBaseUrl,
      'services': instance.services,
      'env_proxy_detected': instance.envProxyDetected,
      'mirror_defaults': instance.mirrorDefaults,
    };

_NetworkTestPayload _$NetworkTestPayloadFromJson(Map<String, dynamic> json) =>
    _NetworkTestPayload(service: json['service'] as String? ?? '');

Map<String, dynamic> _$NetworkTestPayloadToJson(_NetworkTestPayload instance) =>
    <String, dynamic>{'service': instance.service};

_NetworkTestResult _$NetworkTestResultFromJson(Map<String, dynamic> json) =>
    _NetworkTestResult(
      ok: json['ok'] as bool? ?? false,
      latencyMs: (json['latencyMs'] as num?)?.toInt(),
      message: json['message'] as String? ?? "",
    );

Map<String, dynamic> _$NetworkTestResultToJson(_NetworkTestResult instance) =>
    <String, dynamic>{
      'ok': instance.ok,
      'latencyMs': instance.latencyMs,
      'message': instance.message,
    };

_Notice _$NoticeFromJson(Map<String, dynamic> json) => _Notice(
  id: (json['id'] as num?)?.toInt() ?? 0,
  severity: json['severity'] as String? ?? "info",
  source: json['source'] as String? ?? "",
  title: json['title'] as String? ?? "",
  message: json['message'] as String? ?? "",
  payload: json['payload'] as Map<String, dynamic>?,
  createdAt: json['createdAt'] as String?,
  updatedAt: json['updatedAt'] as String?,
);

Map<String, dynamic> _$NoticeToJson(_Notice instance) => <String, dynamic>{
  'id': instance.id,
  'severity': instance.severity,
  'source': instance.source,
  'title': instance.title,
  'message': instance.message,
  'payload': instance.payload,
  'createdAt': instance.createdAt,
  'updatedAt': instance.updatedAt,
};

_OfficialChannelRequest _$OfficialChannelRequestFromJson(
  Map<String, dynamic> json,
) => _OfficialChannelRequest(enabled: json['enabled'] as bool? ?? false);

Map<String, dynamic> _$OfficialChannelRequestToJson(
  _OfficialChannelRequest instance,
) => <String, dynamic>{'enabled': instance.enabled};

_OfflineExport _$OfflineExportFromJson(Map<String, dynamic> json) =>
    _OfflineExport(
      exportId: json['exportId'] as String? ?? "",
      status: json['status'] as String? ?? "",
      etag: json['etag'] as String? ?? "",
      expectedBytes: (json['expectedBytes'] as num?)?.toInt() ?? 0,
      finalBytes: (json['finalBytes'] as num?)?.toInt(),
      error: json['error'] as String?,
      queuePosition: (json['queuePosition'] as num?)?.toInt(),
      contentUrl: json['contentUrl'] as String? ?? "",
    );

Map<String, dynamic> _$OfflineExportToJson(_OfflineExport instance) =>
    <String, dynamic>{
      'exportId': instance.exportId,
      'status': instance.status,
      'etag': instance.etag,
      'expectedBytes': instance.expectedBytes,
      'finalBytes': instance.finalBytes,
      'error': instance.error,
      'queuePosition': instance.queuePosition,
      'contentUrl': instance.contentUrl,
    };

_OfflineExportRequest _$OfflineExportRequestFromJson(
  Map<String, dynamic> json,
) => _OfflineExportRequest(
  fileId: (json['fileId'] as num?)?.toInt() ?? 0,
  profile: json['profile'] as String? ?? '',
  audioTrack: json['audioTrack'] as String?,
);

Map<String, dynamic> _$OfflineExportRequestToJson(
  _OfflineExportRequest instance,
) => <String, dynamic>{
  'fileId': instance.fileId,
  'profile': instance.profile,
  'audioTrack': instance.audioTrack,
};

_OfflineFileProfiles _$OfflineFileProfilesFromJson(Map<String, dynamic> json) =>
    _OfflineFileProfiles(
      fileId: (json['fileId'] as num?)?.toInt() ?? 0,
      mediaItemId: (json['mediaItemId'] as num?)?.toInt() ?? 0,
      seasonNumber: (json['seasonNumber'] as num?)?.toInt() ?? 0,
      episodeNumber: (json['episodeNumber'] as num?)?.toInt() ?? 0,
      container: json['container'] as String?,
      profiles: (json['profiles'] as List<dynamic>?)
          ?.map((e) => OfflineProfile.fromJson(e as Map<String, dynamic>))
          .toList(),
      unavailableReason: json['unavailableReason'] as String?,
    );

Map<String, dynamic> _$OfflineFileProfilesToJson(
  _OfflineFileProfiles instance,
) => <String, dynamic>{
  'fileId': instance.fileId,
  'mediaItemId': instance.mediaItemId,
  'seasonNumber': instance.seasonNumber,
  'episodeNumber': instance.episodeNumber,
  'container': instance.container,
  'profiles': instance.profiles,
  'unavailableReason': instance.unavailableReason,
};

_OfflineManifest _$OfflineManifestFromJson(Map<String, dynamic> json) =>
    _OfflineManifest(
      fileId: (json['fileId'] as num?)?.toInt() ?? 0,
      mediaItemId: (json['mediaItemId'] as num?)?.toInt() ?? 0,
      libraryId: (json['libraryId'] as num?)?.toInt() ?? 0,
      seasonNumber: (json['seasonNumber'] as num?)?.toInt() ?? 0,
      episodeNumber: (json['episodeNumber'] as num?)?.toInt() ?? 0,
      container: json['container'] as String?,
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
      durationMs: (json['durationMs'] as num?)?.toInt(),
      item: json['item'],
      libraryValue: json['library'],
      season: json['season'],
      chapters: json['chapters'],
      segments: json['segments'],
      audioTracks: json['audioTracks'],
      defaultAudio: json['defaultAudio'] as String?,
      defaultSubtitle: json['defaultSubtitle'] as String?,
      subtitles:
          (json['subtitles'] as List<dynamic>?)
              ?.map(
                (e) => OfflineSubtitleRef.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const [],
      fontsUrl: json['fontsUrl'] as String?,
      profiles:
          (json['profiles'] as List<dynamic>?)
              ?.map((e) => OfflineProfile.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      unavailableReason: json['unavailableReason'] as String?,
      resumePositionMs: (json['resumePositionMs'] as num?)?.toInt(),
    );

Map<String, dynamic> _$OfflineManifestToJson(_OfflineManifest instance) =>
    <String, dynamic>{
      'fileId': instance.fileId,
      'mediaItemId': instance.mediaItemId,
      'libraryId': instance.libraryId,
      'seasonNumber': instance.seasonNumber,
      'episodeNumber': instance.episodeNumber,
      'container': instance.container,
      'sizeBytes': instance.sizeBytes,
      'durationMs': instance.durationMs,
      'item': instance.item,
      'library': instance.libraryValue,
      'season': instance.season,
      'chapters': instance.chapters,
      'segments': instance.segments,
      'audioTracks': instance.audioTracks,
      'defaultAudio': instance.defaultAudio,
      'defaultSubtitle': instance.defaultSubtitle,
      'subtitles': instance.subtitles,
      'fontsUrl': instance.fontsUrl,
      'profiles': instance.profiles,
      'unavailableReason': instance.unavailableReason,
      'resumePositionMs': instance.resumePositionMs,
    };

_OfflineProfile _$OfflineProfileFromJson(Map<String, dynamic> json) =>
    _OfflineProfile(
      profile: json['profile'] as String? ?? "",
      label: json['label'] as String? ?? "",
      height: (json['height'] as num?)?.toInt(),
      expectedBytes: (json['expectedBytes'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$OfflineProfileToJson(_OfflineProfile instance) =>
    <String, dynamic>{
      'profile': instance.profile,
      'label': instance.label,
      'height': instance.height,
      'expectedBytes': instance.expectedBytes,
    };

_OfflineProfilesRequest _$OfflineProfilesRequestFromJson(
  Map<String, dynamic> json,
) => _OfflineProfilesRequest(
  fileIds:
      (json['fileIds'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList() ??
      const [],
);

Map<String, dynamic> _$OfflineProfilesRequestToJson(
  _OfflineProfilesRequest instance,
) => <String, dynamic>{'fileIds': instance.fileIds};

_OfflineProfilesView _$OfflineProfilesViewFromJson(Map<String, dynamic> json) =>
    _OfflineProfilesView(
      files: (json['files'] as List<dynamic>?)
          ?.map((e) => OfflineFileProfiles.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$OfflineProfilesViewToJson(
  _OfflineProfilesView instance,
) => <String, dynamic>{'files': instance.files};

_OfflineSubtitleRef _$OfflineSubtitleRefFromJson(Map<String, dynamic> json) =>
    _OfflineSubtitleRef(
      trackRef: json['trackRef'] as String? ?? "",
      format: json['format'] as String? ?? "",
      language: json['language'] as String?,
      title: json['title'] as String?,
      isDefault: json['isDefault'] as bool? ?? false,
      isForced: json['isForced'] as bool? ?? false,
      isAi: json['isAi'] as bool? ?? false,
      embedded: json['embedded'] as bool? ?? false,
      url: json['url'] as String?,
    );

Map<String, dynamic> _$OfflineSubtitleRefToJson(_OfflineSubtitleRef instance) =>
    <String, dynamic>{
      'trackRef': instance.trackRef,
      'format': instance.format,
      'language': instance.language,
      'title': instance.title,
      'isDefault': instance.isDefault,
      'isForced': instance.isForced,
      'isAi': instance.isAi,
      'embedded': instance.embedded,
      'url': instance.url,
    };

_OfflineViewingRecord _$OfflineViewingRecordFromJson(
  Map<String, dynamic> json,
) => _OfflineViewingRecord(
  viewingId: json['viewingId'] as String? ?? '',
  mediaItemId: (json['mediaItemId'] as num?)?.toInt() ?? 0,
  seasonNumber: (json['seasonNumber'] as num?)?.toInt() ?? 0,
  episodeNumber: (json['episodeNumber'] as num?)?.toInt() ?? 0,
  fileId: (json['fileId'] as num?)?.toInt(),
  startedAt: json['startedAt'] as String? ?? '',
  updatedAt: json['updatedAt'] as String? ?? '',
  startPositionMs: (json['startPositionMs'] as num?)?.toInt() ?? 0,
  positionMs: (json['positionMs'] as num?)?.toInt() ?? 0,
  watchedMs: (json['watchedMs'] as num?)?.toInt() ?? 0,
  completed: json['completed'] as bool? ?? false,
  ended: json['ended'] as bool? ?? false,
  durationMs: (json['durationMs'] as num?)?.toInt(),
);

Map<String, dynamic> _$OfflineViewingRecordToJson(
  _OfflineViewingRecord instance,
) => <String, dynamic>{
  'viewingId': instance.viewingId,
  'mediaItemId': instance.mediaItemId,
  'seasonNumber': instance.seasonNumber,
  'episodeNumber': instance.episodeNumber,
  'fileId': instance.fileId,
  'startedAt': instance.startedAt,
  'updatedAt': instance.updatedAt,
  'startPositionMs': instance.startPositionMs,
  'positionMs': instance.positionMs,
  'watchedMs': instance.watchedMs,
  'completed': instance.completed,
  'ended': instance.ended,
  'durationMs': instance.durationMs,
};

_OfflineViewingResult _$OfflineViewingResultFromJson(
  Map<String, dynamic> json,
) => _OfflineViewingResult(
  viewingId: json['viewingId'] as String? ?? "",
  status: json['status'] as String? ?? "",
);

Map<String, dynamic> _$OfflineViewingResultToJson(
  _OfflineViewingResult instance,
) => <String, dynamic>{
  'viewingId': instance.viewingId,
  'status': instance.status,
};

_OfflineViewingsRequest _$OfflineViewingsRequestFromJson(
  Map<String, dynamic> json,
) => _OfflineViewingsRequest(
  sentAt: json['sentAt'] as String? ?? '',
  records:
      (json['records'] as List<dynamic>?)
          ?.map((e) => OfflineViewingRecord.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
);

Map<String, dynamic> _$OfflineViewingsRequestToJson(
  _OfflineViewingsRequest instance,
) => <String, dynamic>{'sentAt': instance.sentAt, 'records': instance.records};

_OfflineViewingsView _$OfflineViewingsViewFromJson(Map<String, dynamic> json) =>
    _OfflineViewingsView(
      results:
          (json['results'] as List<dynamic>?)
              ?.map(
                (e) => OfflineViewingResult.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const [],
    );

Map<String, dynamic> _$OfflineViewingsViewToJson(
  _OfflineViewingsView instance,
) => <String, dynamic>{'results': instance.results};

_PathHealthView _$PathHealthViewFromJson(Map<String, dynamic> json) =>
    _PathHealthView(
      local: json['local'] as String? ?? "",
      remote: json['remote'] as String? ?? "",
      state: json['state'] as String? ?? "",
      detail: json['detail'] as String?,
    );

Map<String, dynamic> _$PathHealthViewToJson(_PathHealthView instance) =>
    <String, dynamic>{
      'local': instance.local,
      'remote': instance.remote,
      'state': instance.state,
      'detail': instance.detail,
    };

_PathMapping _$PathMappingFromJson(Map<String, dynamic> json) => _PathMapping(
  local: json['local'] as String? ?? "",
  remote: json['remote'] as String? ?? "",
);

Map<String, dynamic> _$PathMappingToJson(_PathMapping instance) =>
    <String, dynamic>{'local': instance.local, 'remote': instance.remote};

_PendingUpdate _$PendingUpdateFromJson(Map<String, dynamic> json) =>
    _PendingUpdate(
      appVersion: json['appVersion'] as String?,
      appCompatible: json['appCompatible'] as bool? ?? true,
      appChangelog: json['appChangelog'] as String? ?? "",
      appPublishedAt: json['appPublishedAt'] as String? ?? "",
      modelTag: json['modelTag'] as String?,
      checkedAt: json['checkedAt'] as String?,
    );

Map<String, dynamic> _$PendingUpdateToJson(_PendingUpdate instance) =>
    <String, dynamic>{
      'appVersion': instance.appVersion,
      'appCompatible': instance.appCompatible,
      'appChangelog': instance.appChangelog,
      'appPublishedAt': instance.appPublishedAt,
      'modelTag': instance.modelTag,
      'checkedAt': instance.checkedAt,
    };

_PendingView _$PendingViewFromJson(Map<String, dynamic> json) => _PendingView(
  message: json['message'] as String? ?? "",
  candidateKey: json['candidateKey'] as String? ?? "",
  retryAfterMs: (json['retryAfterMs'] as num?)?.toInt() ?? 2500,
);

Map<String, dynamic> _$PendingViewToJson(_PendingView instance) =>
    <String, dynamic>{
      'message': instance.message,
      'candidateKey': instance.candidateKey,
      'retryAfterMs': instance.retryAfterMs,
    };

_PgsConversionView _$PgsConversionViewFromJson(Map<String, dynamic> json) =>
    _PgsConversionView(
      candidateKey: json['candidateKey'] as String? ?? "",
      language: json['language'] as String?,
      available: json['available'] as bool? ?? false,
      engine: json['engine'] as String?,
      platform: json['platform'] as String? ?? "",
      architecture: json['architecture'] as String? ?? "",
      cached: json['cached'] as bool? ?? false,
      message: json['message'] as String? ?? "",
      suggestions:
          (json['suggestions'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      ocrLanguage: json['ocrLanguage'] as String?,
      ocrLanguageLabel: json['ocrLanguageLabel'] as String?,
      languageConfirmationRequired:
          json['languageConfirmationRequired'] as bool? ?? false,
      languageReason: json['languageReason'] as String? ?? "",
      languageOptions:
          (json['languageOptions'] as List<dynamic>?)
              ?.map(
                (e) => PgsLanguageOption.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const [],
    );

Map<String, dynamic> _$PgsConversionViewToJson(_PgsConversionView instance) =>
    <String, dynamic>{
      'candidateKey': instance.candidateKey,
      'language': instance.language,
      'available': instance.available,
      'engine': instance.engine,
      'platform': instance.platform,
      'architecture': instance.architecture,
      'cached': instance.cached,
      'message': instance.message,
      'suggestions': instance.suggestions,
      'ocrLanguage': instance.ocrLanguage,
      'ocrLanguageLabel': instance.ocrLanguageLabel,
      'languageConfirmationRequired': instance.languageConfirmationRequired,
      'languageReason': instance.languageReason,
      'languageOptions': instance.languageOptions,
    };

_PgsLanguageOption _$PgsLanguageOptionFromJson(Map<String, dynamic> json) =>
    _PgsLanguageOption(
      code: json['code'] as String? ?? "",
      label: json['label'] as String? ?? "",
    );

Map<String, dynamic> _$PgsLanguageOptionToJson(_PgsLanguageOption instance) =>
    <String, dynamic>{'code': instance.code, 'label': instance.label};

_PipelineHealth _$PipelineHealthFromJson(Map<String, dynamic> json) =>
    _PipelineHealth(
      status: json['status'] as String? ?? "ok",
      errorCount: (json['errorCount'] as num?)?.toInt() ?? 0,
      warnCount: (json['warnCount'] as num?)?.toInt() ?? 0,
      downloaderOk: json['downloaderOk'] as bool? ?? false,
      sitesConfigured: json['sitesConfigured'] as bool? ?? false,
      downloadersConfigured: json['downloadersConfigured'] as bool? ?? false,
    );

Map<String, dynamic> _$PipelineHealthToJson(_PipelineHealth instance) =>
    <String, dynamic>{
      'status': instance.status,
      'errorCount': instance.errorCount,
      'warnCount': instance.warnCount,
      'downloaderOk': instance.downloaderOk,
      'sitesConfigured': instance.sitesConfigured,
      'downloadersConfigured': instance.downloadersConfigured,
    };

_PlaybackActivityView _$PlaybackActivityViewFromJson(
  Map<String, dynamic> json,
) => _PlaybackActivityView(
  sessions:
      (json['sessions'] as List<dynamic>?)
          ?.map(
            (e) => ActivePlaybackSession.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const [],
  downloads:
      (json['downloads'] as List<dynamic>?)
          ?.map((e) => ActiveFileDownload.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
);

Map<String, dynamic> _$PlaybackActivityViewToJson(
  _PlaybackActivityView instance,
) => <String, dynamic>{
  'sessions': instance.sessions,
  'downloads': instance.downloads,
};

_PlaybackArtifactUploadView _$PlaybackArtifactUploadViewFromJson(
  Map<String, dynamic> json,
) => _PlaybackArtifactUploadView(
  name: json['name'] as String? ?? "",
  status: (json['status'] as num?)?.toInt() ?? 0,
  receivedBytes: (json['received_bytes'] as num?)?.toInt() ?? 0,
  contentLength: (json['content_length'] as num?)?.toInt(),
  transferEncoding: json['transfer_encoding'] as String?,
  occurredAtMs: (json['occurred_at_ms'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$PlaybackArtifactUploadViewToJson(
  _PlaybackArtifactUploadView instance,
) => <String, dynamic>{
  'name': instance.name,
  'status': instance.status,
  'received_bytes': instance.receivedBytes,
  'content_length': instance.contentLength,
  'transfer_encoding': instance.transferEncoding,
  'occurred_at_ms': instance.occurredAtMs,
};

_PlaybackAutoSkipRequest _$PlaybackAutoSkipRequestFromJson(
  Map<String, dynamic> json,
) => _PlaybackAutoSkipRequest(enabled: json['enabled'] as bool? ?? false);

Map<String, dynamic> _$PlaybackAutoSkipRequestToJson(
  _PlaybackAutoSkipRequest instance,
) => <String, dynamic>{'enabled': instance.enabled};

_PlaybackAutoSkipView _$PlaybackAutoSkipViewFromJson(
  Map<String, dynamic> json,
) => _PlaybackAutoSkipView(
  enabled: json['enabled'] as bool? ?? false,
  intro: json['intro'] as bool? ?? false,
);

Map<String, dynamic> _$PlaybackAutoSkipViewToJson(
  _PlaybackAutoSkipView instance,
) => <String, dynamic>{'enabled': instance.enabled, 'intro': instance.intro};

_PlaybackBlurayClipView _$PlaybackBlurayClipViewFromJson(
  Map<String, dynamic> json,
) => _PlaybackBlurayClipView(
  url: json['url'] as String? ?? "",
  inTime: (json['in_time'] as num?)?.toInt() ?? 0,
  outTime: (json['out_time'] as num?)?.toInt() ?? 0,
  entryPts:
      (json['entry_pts'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList() ??
      const [],
  entrySpn:
      (json['entry_spn'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList() ??
      const [],
);

Map<String, dynamic> _$PlaybackBlurayClipViewToJson(
  _PlaybackBlurayClipView instance,
) => <String, dynamic>{
  'url': instance.url,
  'in_time': instance.inTime,
  'out_time': instance.outTime,
  'entry_pts': instance.entryPts,
  'entry_spn': instance.entrySpn,
};

_PlaybackBlurayStreamView _$PlaybackBlurayStreamViewFromJson(
  Map<String, dynamic> json,
) => _PlaybackBlurayStreamView(
  ref: json['ref'] as String? ?? "",
  pid: (json['pid'] as num?)?.toInt(),
  codec: json['codec'] as String?,
  language: json['language'] as String?,
  channels: (json['channels'] as num?)?.toInt(),
);

Map<String, dynamic> _$PlaybackBlurayStreamViewToJson(
  _PlaybackBlurayStreamView instance,
) => <String, dynamic>{
  'ref': instance.ref,
  'pid': instance.pid,
  'codec': instance.codec,
  'language': instance.language,
  'channels': instance.channels,
};

_PlaybackBlurayView _$PlaybackBlurayViewFromJson(
  Map<String, dynamic> json,
) => _PlaybackBlurayView(
  playlist: json['playlist'] as String? ?? "",
  clips:
      (json['clips'] as List<dynamic>?)
          ?.map(
            (e) => PlaybackBlurayClipView.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const [],
  audio:
      (json['audio'] as List<dynamic>?)
          ?.map(
            (e) => PlaybackBlurayStreamView.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const [],
  subtitles:
      (json['subtitles'] as List<dynamic>?)
          ?.map(
            (e) => PlaybackBlurayStreamView.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const [],
);

Map<String, dynamic> _$PlaybackBlurayViewToJson(_PlaybackBlurayView instance) =>
    <String, dynamic>{
      'playlist': instance.playlist,
      'clips': instance.clips,
      'audio': instance.audio,
      'subtitles': instance.subtitles,
    };

_PlaybackChapterMarkView _$PlaybackChapterMarkViewFromJson(
  Map<String, dynamic> json,
) => _PlaybackChapterMarkView(
  startMs: (json['start_ms'] as num?)?.toInt() ?? 0,
  title: json['title'] as String?,
);

Map<String, dynamic> _$PlaybackChapterMarkViewToJson(
  _PlaybackChapterMarkView instance,
) => <String, dynamic>{'start_ms': instance.startMs, 'title': instance.title};

_PlaybackClientLogPayload _$PlaybackClientLogPayloadFromJson(
  Map<String, dynamic> json,
) => _PlaybackClientLogPayload(
  event: json['event'] as String? ?? '',
  detail: json['detail'] as Map<String, dynamic>?,
);

Map<String, dynamic> _$PlaybackClientLogPayloadToJson(
  _PlaybackClientLogPayload instance,
) => <String, dynamic>{'event': instance.event, 'detail': instance.detail};

_PlaybackDecideRequest _$PlaybackDecideRequestFromJson(
  Map<String, dynamic> json,
) => _PlaybackDecideRequest(
  fileId: (json['file_id'] as num?)?.toInt(),
  mediaItemId: (json['media_item_id'] as num?)?.toInt(),
  seasonNumber: (json['season_number'] as num?)?.toInt(),
  episodeNumber: (json['episode_number'] as num?)?.toInt(),
  capability: json['capability'] == null
      ? const ClientCapabilityIn()
      : ClientCapabilityIn.fromJson(json['capability'] as Map<String, dynamic>),
  failedTiers: (json['failed_tiers'] as List<dynamic>?)
      ?.map((e) => (e as num).toInt())
      .toList(),
  audioTrack: json['audio_track'] as String?,
  subtitleTrack: json['subtitle_track'] as String?,
  burnRequested: json['burn_requested'] as bool?,
  maxHeight: (json['max_height'] as num?)?.toInt(),
  deviceId: json['device_id'] as String?,
  downlinkBps: (json['downlink_bps'] as num?)?.toInt(),
);

Map<String, dynamic> _$PlaybackDecideRequestToJson(
  _PlaybackDecideRequest instance,
) => <String, dynamic>{
  'file_id': instance.fileId,
  'media_item_id': instance.mediaItemId,
  'season_number': instance.seasonNumber,
  'episode_number': instance.episodeNumber,
  'capability': instance.capability,
  'failed_tiers': instance.failedTiers,
  'audio_track': instance.audioTrack,
  'subtitle_track': instance.subtitleTrack,
  'burn_requested': instance.burnRequested,
  'max_height': instance.maxHeight,
  'device_id': instance.deviceId,
  'downlink_bps': instance.downlinkBps,
};

_PlaybackDecisionView _$PlaybackDecisionViewFromJson(
  Map<String, dynamic> json,
) => _PlaybackDecisionView(
  outcome: json['outcome'] as String? ?? "",
  tier: (json['tier'] as num?)?.toInt(),
  fileId: (json['file_id'] as num?)?.toInt(),
  container: json['container'] as String?,
  video: json['video'] == null
      ? null
      : VideoPlanView.fromJson(json['video'] as Map<String, dynamic>),
  audio: json['audio'] == null
      ? null
      : AudioPlanView.fromJson(json['audio'] as Map<String, dynamic>),
  audioTracks:
      (json['audio_tracks'] as List<dynamic>?)
          ?.map((e) => AudioTrackView.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  subtitles:
      (json['subtitles'] as List<dynamic>?)
          ?.map((e) => SubtitlePlanView.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  degradedFrom: (json['degraded_from'] as num?)?.toInt(),
  disc: json['disc'] as String?,
  discPlaylist: json['disc_playlist'] as String?,
  costHint: json['cost_hint'] as String?,
  canSelfEnable: json['can_self_enable'] as bool?,
  settingNamespace: json['setting_namespace'] as String?,
  settingKey: json['setting_key'] as String?,
  reason: json['reason'] as String? ?? "",
  suggestion: json['suggestion'] as String?,
);

Map<String, dynamic> _$PlaybackDecisionViewToJson(
  _PlaybackDecisionView instance,
) => <String, dynamic>{
  'outcome': instance.outcome,
  'tier': instance.tier,
  'file_id': instance.fileId,
  'container': instance.container,
  'video': instance.video,
  'audio': instance.audio,
  'audio_tracks': instance.audioTracks,
  'subtitles': instance.subtitles,
  'degraded_from': instance.degradedFrom,
  'disc': instance.disc,
  'disc_playlist': instance.discPlaylist,
  'cost_hint': instance.costHint,
  'can_self_enable': instance.canSelfEnable,
  'setting_namespace': instance.settingNamespace,
  'setting_key': instance.settingKey,
  'reason': instance.reason,
  'suggestion': instance.suggestion,
};

_PlaybackDelivery _$PlaybackDeliveryFromJson(Map<String, dynamic> json) =>
    _PlaybackDelivery(
      mode: json['mode'] as String? ?? "direct",
      label: json['label'] as String? ?? "",
      target: json['target'] as String?,
      executor: json['executor'] as String?,
      reason: json['reason'] as String?,
    );

Map<String, dynamic> _$PlaybackDeliveryToJson(_PlaybackDelivery instance) =>
    <String, dynamic>{
      'mode': instance.mode,
      'label': instance.label,
      'target': instance.target,
      'executor': instance.executor,
      'reason': instance.reason,
    };

_PlaybackDiagnosticsView _$PlaybackDiagnosticsViewFromJson(
  Map<String, dynamic> json,
) => _PlaybackDiagnosticsView(
  sessionState: json['session_state'] as String? ?? "",
  sessionError: json['session_error'] as String?,
  processingMode: json['processing_mode'] as String? ?? "",
  executionLocation: json['execution_location'] as String? ?? "",
  backend: json['backend'] as String?,
  encoder: json['encoder'] as String?,
  workerId: json['worker_id'] as String?,
  workerVersion: json['worker_version'] as String?,
  workerPlatform: json['worker_platform'] as String?,
  workerArch: json['worker_arch'] as String?,
  ffmpegVersion: json['ffmpeg_version'] as String?,
  workerOnline: json['worker_online'] as bool?,
  workerLastSeenSeconds: (json['worker_last_seen_seconds'] as num?)?.toDouble(),
  jobId: json['job_id'] as String?,
  attemptId: json['attempt_id'] as String?,
  jobState: json['job_state'] as String?,
  jobOutTimeMs: (json['job_out_time_ms'] as num?)?.toInt(),
  jobSpeed: json['job_speed'] as String?,
  jobPhase: json['job_phase'] as String?,
  jobExitCode: (json['job_exit_code'] as num?)?.toInt(),
  jobError: json['job_error'] as String?,
  jobStderrTail: json['job_stderr_tail'] as String?,
  headSegment: (json['head_segment'] as num?)?.toInt(),
  highestProducedSegment: (json['highest_produced_segment'] as num?)?.toInt(),
  requestedSegment: (json['requested_segment'] as num?)?.toInt(),
  servedSegment: (json['served_segment'] as num?)?.toInt(),
  segmentWaitMs: (json['segment_wait_ms'] as num?)?.toInt(),
  segmentStatus: (json['segment_status'] as num?)?.toInt(),
  pendingSegments:
      (json['pending_segments'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList() ??
      const [],
  failedSegments:
      (json['failed_segments'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList() ??
      const [],
  historicalFailedSegments:
      (json['historical_failed_segments'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList() ??
      const [],
  recentUploads:
      (json['recent_uploads'] as List<dynamic>?)
          ?.map(
            (e) =>
                PlaybackArtifactUploadView.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const [],
  cacheBytes: (json['cache_bytes'] as num?)?.toInt() ?? 0,
  totalSegments: (json['total_segments'] as num?)?.toInt(),
  leadSeconds: (json['lead_seconds'] as num?)?.toDouble(),
  pauseReasons:
      (json['pause_reasons'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  cacheHit: json['cache_hit'] as bool? ?? false,
  cachedSegments: (json['cached_segments'] as num?)?.toInt() ?? 0,
  timeline:
      (json['timeline'] as List<dynamic>?)
          ?.map((e) => e as Map<String, dynamic>)
          .toList() ??
      const [],
);

Map<String, dynamic> _$PlaybackDiagnosticsViewToJson(
  _PlaybackDiagnosticsView instance,
) => <String, dynamic>{
  'session_state': instance.sessionState,
  'session_error': instance.sessionError,
  'processing_mode': instance.processingMode,
  'execution_location': instance.executionLocation,
  'backend': instance.backend,
  'encoder': instance.encoder,
  'worker_id': instance.workerId,
  'worker_version': instance.workerVersion,
  'worker_platform': instance.workerPlatform,
  'worker_arch': instance.workerArch,
  'ffmpeg_version': instance.ffmpegVersion,
  'worker_online': instance.workerOnline,
  'worker_last_seen_seconds': instance.workerLastSeenSeconds,
  'job_id': instance.jobId,
  'attempt_id': instance.attemptId,
  'job_state': instance.jobState,
  'job_out_time_ms': instance.jobOutTimeMs,
  'job_speed': instance.jobSpeed,
  'job_phase': instance.jobPhase,
  'job_exit_code': instance.jobExitCode,
  'job_error': instance.jobError,
  'job_stderr_tail': instance.jobStderrTail,
  'head_segment': instance.headSegment,
  'highest_produced_segment': instance.highestProducedSegment,
  'requested_segment': instance.requestedSegment,
  'served_segment': instance.servedSegment,
  'segment_wait_ms': instance.segmentWaitMs,
  'segment_status': instance.segmentStatus,
  'pending_segments': instance.pendingSegments,
  'failed_segments': instance.failedSegments,
  'historical_failed_segments': instance.historicalFailedSegments,
  'recent_uploads': instance.recentUploads,
  'cache_bytes': instance.cacheBytes,
  'total_segments': instance.totalSegments,
  'lead_seconds': instance.leadSeconds,
  'pause_reasons': instance.pauseReasons,
  'cache_hit': instance.cacheHit,
  'cached_segments': instance.cachedSegments,
  'timeline': instance.timeline,
};

_PlaybackHistoryView _$PlaybackHistoryViewFromJson(Map<String, dynamic> json) =>
    _PlaybackHistoryView(
      entries:
          (json['entries'] as List<dynamic>?)
              ?.map((e) => PlaybackLogEntry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      hiddenCount: (json['hiddenCount'] as num?)?.toInt() ?? 0,
      hasMore: json['hasMore'] as bool? ?? false,
      nextCursor: (json['nextCursor'] as num?)?.toInt(),
    );

Map<String, dynamic> _$PlaybackHistoryViewToJson(
  _PlaybackHistoryView instance,
) => <String, dynamic>{
  'entries': instance.entries,
  'hiddenCount': instance.hiddenCount,
  'hasMore': instance.hasMore,
  'nextCursor': instance.nextCursor,
};

_PlaybackItemView _$PlaybackItemViewFromJson(Map<String, dynamic> json) =>
    _PlaybackItemView(
      mediaItemId: (json['media_item_id'] as num?)?.toInt() ?? 0,
      libraryId: (json['library_id'] as num?)?.toInt() ?? 0,
      kind: json['kind'] as String? ?? "",
      title: json['title'] as String? ?? "",
      year: (json['year'] as num?)?.toInt(),
      posterUrl: json['poster_url'] as String?,
      seasons: (json['seasons'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList(),
    );

Map<String, dynamic> _$PlaybackItemViewToJson(_PlaybackItemView instance) =>
    <String, dynamic>{
      'media_item_id': instance.mediaItemId,
      'library_id': instance.libraryId,
      'kind': instance.kind,
      'title': instance.title,
      'year': instance.year,
      'poster_url': instance.posterUrl,
      'seasons': instance.seasons,
    };

_PlaybackLogEntry _$PlaybackLogEntryFromJson(Map<String, dynamic> json) =>
    _PlaybackLogEntry(
      id: (json['id'] as num?)?.toInt() ?? 0,
      memberName: json['memberName'] as String? ?? "",
      media: json['media'] == null
          ? const MediaActivityTarget()
          : MediaActivityTarget.fromJson(json['media'] as Map<String, dynamic>),
      client: json['client'] as String? ?? "",
      deviceName: json['deviceName'] as String? ?? "",
      startedAt: json['startedAt'] as String? ?? "",
      endedAt: json['endedAt'] as String?,
      watchedMs: (json['watchedMs'] as num?)?.toInt() ?? 0,
      progressPercent: (json['progressPercent'] as num?)?.toInt(),
      completed: json['completed'] as bool? ?? false,
    );

Map<String, dynamic> _$PlaybackLogEntryToJson(_PlaybackLogEntry instance) =>
    <String, dynamic>{
      'id': instance.id,
      'memberName': instance.memberName,
      'media': instance.media,
      'client': instance.client,
      'deviceName': instance.deviceName,
      'startedAt': instance.startedAt,
      'endedAt': instance.endedAt,
      'watchedMs': instance.watchedMs,
      'progressPercent': instance.progressPercent,
      'completed': instance.completed,
    };

_PlaybackMarks _$PlaybackMarksFromJson(Map<String, dynamic> json) =>
    _PlaybackMarks(
      played: json['played'] as bool? ?? false,
      isFavorite: json['isFavorite'] as bool? ?? false,
      unplayedCount: (json['unplayedCount'] as num?)?.toInt(),
    );

Map<String, dynamic> _$PlaybackMarksToJson(_PlaybackMarks instance) =>
    <String, dynamic>{
      'played': instance.played,
      'isFavorite': instance.isFavorite,
      'unplayedCount': instance.unplayedCount,
    };

_PlaybackMarksRequest _$PlaybackMarksRequestFromJson(
  Map<String, dynamic> json,
) => _PlaybackMarksRequest(
  mediaItemId: (json['media_item_id'] as num?)?.toInt() ?? 0,
  seasonNumber: (json['season_number'] as num?)?.toInt(),
  episodeNumber: (json['episode_number'] as num?)?.toInt(),
  played: json['played'] as bool?,
  favorite: json['favorite'] as bool?,
  deviceId: json['device_id'] as String?,
);

Map<String, dynamic> _$PlaybackMarksRequestToJson(
  _PlaybackMarksRequest instance,
) => <String, dynamic>{
  'media_item_id': instance.mediaItemId,
  'season_number': instance.seasonNumber,
  'episode_number': instance.episodeNumber,
  'played': instance.played,
  'favorite': instance.favorite,
  'device_id': instance.deviceId,
};

_PlaybackMetricPayload _$PlaybackMetricPayloadFromJson(
  Map<String, dynamic> json,
) => _PlaybackMetricPayload(
  libraryFileId: (json['library_file_id'] as num?)?.toInt(),
  tier: (json['tier'] as num?)?.toInt() ?? 0,
  degradedFrom: (json['degraded_from'] as num?)?.toInt(),
  engine: json['engine'] as String?,
  hwBackend: json['hw_backend'] as String?,
  ttffMs: (json['ttff_ms'] as num?)?.toInt(),
  rebufferMs: (json['rebuffer_ms'] as num?)?.toInt(),
  rebufferCount: (json['rebuffer_count'] as num?)?.toInt(),
  seekCount: (json['seek_count'] as num?)?.toInt(),
  droppedFrames: (json['dropped_frames'] as num?)?.toInt(),
  totalFrames: (json['total_frames'] as num?)?.toInt(),
  watchedMs: (json['watched_ms'] as num?)?.toInt(),
  attemptId: json['attempt_id'] as String?,
  outcome: json['outcome'] as String?,
  mediaItemId: (json['media_item_id'] as num?)?.toInt(),
  seasonNumber: (json['season_number'] as num?)?.toInt(),
  episodeNumber: (json['episode_number'] as num?)?.toInt(),
  origin: json['origin'] as String?,
  client: json['client'] as String?,
  labScenario: json['lab_scenario'] as String?,
  route: json['route'] as String?,
  networkClass: json['network_class'] as String?,
  appVersion: json['app_version'] as String?,
  firstFrameMs: (json['first_frame_ms'] as num?)?.toInt(),
  playingMs: (json['playing_ms'] as num?)?.toInt(),
  userWaitMs: (json['user_wait_ms'] as num?)?.toInt(),
  errorKind: json['error_kind'] as String?,
  errorCategory: json['error_category'] as String?,
  errorStage: json['error_stage'] as String?,
  detail: json['detail'] as Map<String, dynamic>?,
  logTail: json['log_tail'] as String?,
);

Map<String, dynamic> _$PlaybackMetricPayloadToJson(
  _PlaybackMetricPayload instance,
) => <String, dynamic>{
  'library_file_id': instance.libraryFileId,
  'tier': instance.tier,
  'degraded_from': instance.degradedFrom,
  'engine': instance.engine,
  'hw_backend': instance.hwBackend,
  'ttff_ms': instance.ttffMs,
  'rebuffer_ms': instance.rebufferMs,
  'rebuffer_count': instance.rebufferCount,
  'seek_count': instance.seekCount,
  'dropped_frames': instance.droppedFrames,
  'total_frames': instance.totalFrames,
  'watched_ms': instance.watchedMs,
  'attempt_id': instance.attemptId,
  'outcome': instance.outcome,
  'media_item_id': instance.mediaItemId,
  'season_number': instance.seasonNumber,
  'episode_number': instance.episodeNumber,
  'origin': instance.origin,
  'client': instance.client,
  'lab_scenario': instance.labScenario,
  'route': instance.route,
  'network_class': instance.networkClass,
  'app_version': instance.appVersion,
  'first_frame_ms': instance.firstFrameMs,
  'playing_ms': instance.playingMs,
  'user_wait_ms': instance.userWaitMs,
  'error_kind': instance.errorKind,
  'error_category': instance.errorCategory,
  'error_stage': instance.errorStage,
  'detail': instance.detail,
  'log_tail': instance.logTail,
};

_PlaybackPolicy _$PlaybackPolicyFromJson(Map<String, dynamic> json) =>
    _PlaybackPolicy(
      softwareTranscodeEnabled:
          json['softwareTranscodeEnabled'] as bool? ?? false,
      trickplayEnabled: json['trickplayEnabled'] as bool? ?? true,
      transcodeCacheEnabled: json['transcodeCacheEnabled'] as bool? ?? true,
      hardwareAvailable: json['hardwareAvailable'] as bool? ?? false,
      hwBackends:
          (json['hwBackends'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );

Map<String, dynamic> _$PlaybackPolicyToJson(_PlaybackPolicy instance) =>
    <String, dynamic>{
      'softwareTranscodeEnabled': instance.softwareTranscodeEnabled,
      'trickplayEnabled': instance.trickplayEnabled,
      'transcodeCacheEnabled': instance.transcodeCacheEnabled,
      'hardwareAvailable': instance.hardwareAvailable,
      'hwBackends': instance.hwBackends,
    };

_PlaybackPolicyPatchFull _$PlaybackPolicyPatchFullFromJson(
  Map<String, dynamic> json,
) => _PlaybackPolicyPatchFull(
  softwareTranscodeEnabled: json['softwareTranscodeEnabled'] as bool?,
  trickplayEnabled: json['trickplayEnabled'] as bool?,
  transcodeCacheEnabled: json['transcodeCacheEnabled'] as bool?,
);

Map<String, dynamic> _$PlaybackPolicyPatchFullToJson(
  _PlaybackPolicyPatchFull instance,
) => <String, dynamic>{
  'softwareTranscodeEnabled': instance.softwareTranscodeEnabled,
  'trickplayEnabled': instance.trickplayEnabled,
  'transcodeCacheEnabled': instance.transcodeCacheEnabled,
};

_PlaybackProgressRequest _$PlaybackProgressRequestFromJson(
  Map<String, dynamic> json,
) => _PlaybackProgressRequest(
  mediaItemId: (json['media_item_id'] as num?)?.toInt() ?? 0,
  seasonNumber: (json['season_number'] as num?)?.toInt(),
  episodeNumber: (json['episode_number'] as num?)?.toInt(),
  event: json['event'] as String?,
  positionMs: (json['position_ms'] as num?)?.toInt(),
  audioTrack: json['audio_track'] as String?,
  subtitleTrack: json['subtitle_track'] as String?,
  fileId: (json['file_id'] as num?)?.toInt(),
  deviceId: json['device_id'] as String?,
  paused: json['paused'] as bool?,
);

Map<String, dynamic> _$PlaybackProgressRequestToJson(
  _PlaybackProgressRequest instance,
) => <String, dynamic>{
  'media_item_id': instance.mediaItemId,
  'season_number': instance.seasonNumber,
  'episode_number': instance.episodeNumber,
  'event': instance.event,
  'position_ms': instance.positionMs,
  'audio_track': instance.audioTrack,
  'subtitle_track': instance.subtitleTrack,
  'file_id': instance.fileId,
  'device_id': instance.deviceId,
  'paused': instance.paused,
};

_PlaybackSegmentView _$PlaybackSegmentViewFromJson(Map<String, dynamic> json) =>
    _PlaybackSegmentView(
      type: json['type'] as String? ?? "",
      startMs: (json['start_ms'] as num?)?.toInt() ?? 0,
      endMs: (json['end_ms'] as num?)?.toInt() ?? 0,
      toEnd: json['to_end'] as bool? ?? false,
    );

Map<String, dynamic> _$PlaybackSegmentViewToJson(
  _PlaybackSegmentView instance,
) => <String, dynamic>{
  'type': instance.type,
  'start_ms': instance.startMs,
  'end_ms': instance.endMs,
  'to_end': instance.toEnd,
};

_PlaybackSessionRequest _$PlaybackSessionRequestFromJson(
  Map<String, dynamic> json,
) => _PlaybackSessionRequest(
  fileId: (json['file_id'] as num?)?.toInt(),
  mediaItemId: (json['media_item_id'] as num?)?.toInt(),
  seasonNumber: (json['season_number'] as num?)?.toInt(),
  episodeNumber: (json['episode_number'] as num?)?.toInt(),
  capability: json['capability'] == null
      ? const ClientCapabilityIn()
      : ClientCapabilityIn.fromJson(json['capability'] as Map<String, dynamic>),
  failedTiers: (json['failed_tiers'] as List<dynamic>?)
      ?.map((e) => (e as num).toInt())
      .toList(),
  audioTrack: json['audio_track'] as String?,
  subtitleTrack: json['subtitle_track'] as String?,
  burnRequested: json['burn_requested'] as bool?,
  maxHeight: (json['max_height'] as num?)?.toInt(),
  deviceId: json['device_id'] as String?,
  downlinkBps: (json['downlink_bps'] as num?)?.toInt(),
  startMs: (json['start_ms'] as num?)?.toInt(),
  attemptId: json['attempt_id'] as String?,
  client: json['client'] as String?,
);

Map<String, dynamic> _$PlaybackSessionRequestToJson(
  _PlaybackSessionRequest instance,
) => <String, dynamic>{
  'file_id': instance.fileId,
  'media_item_id': instance.mediaItemId,
  'season_number': instance.seasonNumber,
  'episode_number': instance.episodeNumber,
  'capability': instance.capability,
  'failed_tiers': instance.failedTiers,
  'audio_track': instance.audioTrack,
  'subtitle_track': instance.subtitleTrack,
  'burn_requested': instance.burnRequested,
  'max_height': instance.maxHeight,
  'device_id': instance.deviceId,
  'downlink_bps': instance.downlinkBps,
  'start_ms': instance.startMs,
  'attempt_id': instance.attemptId,
  'client': instance.client,
};

_PlaybackSessionView _$PlaybackSessionViewFromJson(Map<String, dynamic> json) =>
    _PlaybackSessionView(
      decision: json['decision'] == null
          ? const PlaybackDecisionView()
          : PlaybackDecisionView.fromJson(
              json['decision'] as Map<String, dynamic>,
            ),
      sessionId: json['session_id'] as String?,
      streamUrl: json['stream_url'] as String?,
      progressiveSegments: json['progressive_segments'] as bool? ?? false,
      startMs: (json['start_ms'] as num?)?.toInt() ?? 0,
      timeline: json['timeline'] as String? ?? "",
      subtitleUrls:
          (json['subtitle_urls'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      masterUrl: json['master_url'] as String?,
      hwBackend: json['hw_backend'] as String?,
      watch: json['watch'] == null
          ? null
          : PlaybackStateView.fromJson(json['watch'] as Map<String, dynamic>),
      source: json['source'] == null
          ? null
          : PlaybackSourceView.fromJson(json['source'] as Map<String, dynamic>),
      chapters:
          (json['chapters'] as List<dynamic>?)
              ?.map(
                (e) =>
                    PlaybackChapterMarkView.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const [],
      segments: (json['segments'] as List<dynamic>?)
          ?.map((e) => PlaybackSegmentView.fromJson(e as Map<String, dynamic>))
          .toList(),
      autoSkip: json['auto_skip'] == null
          ? null
          : PlaybackAutoSkipView.fromJson(
              json['auto_skip'] as Map<String, dynamic>,
            ),
      matroskaCues: json['matroska_cues'] == null
          ? null
          : MatroskaCuesView.fromJson(
              json['matroska_cues'] as Map<String, dynamic>,
            ),
    );

Map<String, dynamic> _$PlaybackSessionViewToJson(
  _PlaybackSessionView instance,
) => <String, dynamic>{
  'decision': instance.decision,
  'session_id': instance.sessionId,
  'stream_url': instance.streamUrl,
  'progressive_segments': instance.progressiveSegments,
  'start_ms': instance.startMs,
  'timeline': instance.timeline,
  'subtitle_urls': instance.subtitleUrls,
  'master_url': instance.masterUrl,
  'hw_backend': instance.hwBackend,
  'watch': instance.watch,
  'source': instance.source,
  'chapters': instance.chapters,
  'segments': instance.segments,
  'auto_skip': instance.autoSkip,
  'matroska_cues': instance.matroskaCues,
};

_PlaybackSourceView _$PlaybackSourceViewFromJson(Map<String, dynamic> json) =>
    _PlaybackSourceView(
      container: json['container'] as String?,
      resolution: json['resolution'] as String?,
      videoCodec: json['video_codec'] as String?,
      hdr: json['hdr'] as String?,
      bitRate: (json['bit_rate'] as num?)?.toInt(),
      frameRate: (json['frame_rate'] as num?)?.toDouble(),
      sizeBytes: (json['size_bytes'] as num?)?.toInt(),
      onDrive: json['on_drive'] as bool?,
    );

Map<String, dynamic> _$PlaybackSourceViewToJson(_PlaybackSourceView instance) =>
    <String, dynamic>{
      'container': instance.container,
      'resolution': instance.resolution,
      'video_codec': instance.videoCodec,
      'hdr': instance.hdr,
      'bit_rate': instance.bitRate,
      'frame_rate': instance.frameRate,
      'size_bytes': instance.sizeBytes,
      'on_drive': instance.onDrive,
    };

_PlaybackStateView _$PlaybackStateViewFromJson(Map<String, dynamic> json) =>
    _PlaybackStateView(
      positionMs: (json['position_ms'] as num?)?.toInt() ?? 0,
      played: json['played'] as bool? ?? false,
      playCount: (json['play_count'] as num?)?.toInt() ?? 0,
      durationMs: (json['duration_ms'] as num?)?.toInt(),
      audioTrack: json['audio_track'] as String?,
      subtitleTrack: json['subtitle_track'] as String?,
      endedByAdmin: json['ended_by_admin'] as bool? ?? false,
    );

Map<String, dynamic> _$PlaybackStateViewToJson(_PlaybackStateView instance) =>
    <String, dynamic>{
      'position_ms': instance.positionMs,
      'played': instance.played,
      'play_count': instance.playCount,
      'duration_ms': instance.durationMs,
      'audio_track': instance.audioTrack,
      'subtitle_track': instance.subtitleTrack,
      'ended_by_admin': instance.endedByAdmin,
    };

_PlaybackStatsClientRow _$PlaybackStatsClientRowFromJson(
  Map<String, dynamic> json,
) => _PlaybackStatsClientRow(
  client: json['client'] as String? ?? "",
  plays: (json['plays'] as num?)?.toInt() ?? 0,
  watchedMs: (json['watchedMs'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$PlaybackStatsClientRowToJson(
  _PlaybackStatsClientRow instance,
) => <String, dynamic>{
  'client': instance.client,
  'plays': instance.plays,
  'watchedMs': instance.watchedMs,
};

_PlaybackStatsDayRow _$PlaybackStatsDayRowFromJson(Map<String, dynamic> json) =>
    _PlaybackStatsDayRow(
      date: json['date'] as String? ?? "",
      plays: (json['plays'] as num?)?.toInt() ?? 0,
      watchedMs: (json['watchedMs'] as num?)?.toInt() ?? 0,
      completed: (json['completed'] as num?)?.toInt() ?? 0,
      members: (json['members'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$PlaybackStatsDayRowToJson(
  _PlaybackStatsDayRow instance,
) => <String, dynamic>{
  'date': instance.date,
  'plays': instance.plays,
  'watchedMs': instance.watchedMs,
  'completed': instance.completed,
  'members': instance.members,
};

_PlaybackStatsMemberRow _$PlaybackStatsMemberRowFromJson(
  Map<String, dynamic> json,
) => _PlaybackStatsMemberRow(
  memberId: (json['memberId'] as num?)?.toInt() ?? 0,
  memberName: json['memberName'] as String? ?? "",
  plays: (json['plays'] as num?)?.toInt() ?? 0,
  watchedMs: (json['watchedMs'] as num?)?.toInt() ?? 0,
  completed: (json['completed'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$PlaybackStatsMemberRowToJson(
  _PlaybackStatsMemberRow instance,
) => <String, dynamic>{
  'memberId': instance.memberId,
  'memberName': instance.memberName,
  'plays': instance.plays,
  'watchedMs': instance.watchedMs,
  'completed': instance.completed,
};

_PlaybackStatsTierRow _$PlaybackStatsTierRowFromJson(
  Map<String, dynamic> json,
) => _PlaybackStatsTierRow(
  tier: (json['tier'] as num?)?.toInt() ?? 0,
  label: json['label'] as String? ?? "",
  plays: (json['plays'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$PlaybackStatsTierRowToJson(
  _PlaybackStatsTierRow instance,
) => <String, dynamic>{
  'tier': instance.tier,
  'label': instance.label,
  'plays': instance.plays,
};

_PlaybackStatsTitleRow _$PlaybackStatsTitleRowFromJson(
  Map<String, dynamic> json,
) => _PlaybackStatsTitleRow(
  media: json['media'] == null
      ? const MediaActivityTarget()
      : MediaActivityTarget.fromJson(json['media'] as Map<String, dynamic>),
  plays: (json['plays'] as num?)?.toInt() ?? 0,
  watchedMs: (json['watchedMs'] as num?)?.toInt() ?? 0,
  members: (json['members'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$PlaybackStatsTitleRowToJson(
  _PlaybackStatsTitleRow instance,
) => <String, dynamic>{
  'media': instance.media,
  'plays': instance.plays,
  'watchedMs': instance.watchedMs,
  'members': instance.members,
};

_PlaybackStatsTotals _$PlaybackStatsTotalsFromJson(Map<String, dynamic> json) =>
    _PlaybackStatsTotals(
      plays: (json['plays'] as num?)?.toInt() ?? 0,
      watchedMs: (json['watchedMs'] as num?)?.toInt() ?? 0,
      completed: (json['completed'] as num?)?.toInt() ?? 0,
      activeMembers: (json['activeMembers'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$PlaybackStatsTotalsToJson(
  _PlaybackStatsTotals instance,
) => <String, dynamic>{
  'plays': instance.plays,
  'watchedMs': instance.watchedMs,
  'completed': instance.completed,
  'activeMembers': instance.activeMembers,
};

_PlaybackWatchStatsView _$PlaybackWatchStatsViewFromJson(
  Map<String, dynamic> json,
) => _PlaybackWatchStatsView(
  days: (json['days'] as num?)?.toInt() ?? 7,
  current: json['current'] == null
      ? const PlaybackStatsTotals()
      : PlaybackStatsTotals.fromJson(json['current'] as Map<String, dynamic>),
  previous: json['previous'] == null
      ? const PlaybackStatsTotals()
      : PlaybackStatsTotals.fromJson(json['previous'] as Map<String, dynamic>),
  previousAvailable: json['previousAvailable'] as bool? ?? false,
  byDay:
      (json['byDay'] as List<dynamic>?)
          ?.map((e) => PlaybackStatsDayRow.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  previousByDay:
      (json['previousByDay'] as List<dynamic>?)
          ?.map((e) => PlaybackStatsDayRow.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  byHour:
      (json['byHour'] as List<dynamic>?)
          ?.map(
            (e) => (e as List<dynamic>).map((e) => (e as num).toInt()).toList(),
          )
          .toList() ??
      const [],
  byMember:
      (json['byMember'] as List<dynamic>?)
          ?.map(
            (e) => PlaybackStatsMemberRow.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const [],
  byClient:
      (json['byClient'] as List<dynamic>?)
          ?.map(
            (e) => PlaybackStatsClientRow.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const [],
  byTier:
      (json['byTier'] as List<dynamic>?)
          ?.map((e) => PlaybackStatsTierRow.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  topTitles:
      (json['topTitles'] as List<dynamic>?)
          ?.map(
            (e) => PlaybackStatsTitleRow.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const [],
  hiddenTitleCount: (json['hiddenTitleCount'] as num?)?.toInt() ?? 0,
  favorites:
      (json['favorites'] as List<dynamic>?)
          ?.map(
            (e) => PlaybackStatsTitleRow.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const [],
  previousFavorites:
      (json['previousFavorites'] as List<dynamic>?)
          ?.map(
            (e) => PlaybackStatsTitleRow.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const [],
);

Map<String, dynamic> _$PlaybackWatchStatsViewToJson(
  _PlaybackWatchStatsView instance,
) => <String, dynamic>{
  'days': instance.days,
  'current': instance.current,
  'previous': instance.previous,
  'previousAvailable': instance.previousAvailable,
  'byDay': instance.byDay,
  'previousByDay': instance.previousByDay,
  'byHour': instance.byHour,
  'byMember': instance.byMember,
  'byClient': instance.byClient,
  'byTier': instance.byTier,
  'topTitles': instance.topTitles,
  'hiddenTitleCount': instance.hiddenTitleCount,
  'favorites': instance.favorites,
  'previousFavorites': instance.previousFavorites,
};

_PosterBadgePrefs _$PosterBadgePrefsFromJson(Map<String, dynamic> json) =>
    _PosterBadgePrefs(
      rating: json['rating'] as bool? ?? false,
      year: json['year'] as bool? ?? false,
      resolution: json['resolution'] as bool? ?? false,
      format: json['format'] as bool? ?? false,
      ended: json['ended'] as bool? ?? false,
      airing: json['airing'] as bool? ?? false,
      chineseSubtitle: json['chinese_subtitle'] as bool? ?? false,
      progress: json['progress'] as bool? ?? false,
      unwatched: json['unwatched'] as bool? ?? false,
      hoverOnly: json['hover_only'] as bool? ?? false,
      minRating: (json['min_rating'] as num?)?.toDouble() ?? 0.0,
    );

Map<String, dynamic> _$PosterBadgePrefsToJson(_PosterBadgePrefs instance) =>
    <String, dynamic>{
      'rating': instance.rating,
      'year': instance.year,
      'resolution': instance.resolution,
      'format': instance.format,
      'ended': instance.ended,
      'airing': instance.airing,
      'chinese_subtitle': instance.chineseSubtitle,
      'progress': instance.progress,
      'unwatched': instance.unwatched,
      'hover_only': instance.hoverOnly,
      'min_rating': instance.minRating,
    };

_PrepareView _$PrepareViewFromJson(Map<String, dynamic> json) => _PrepareView(
  status: json['status'] as String? ?? "",
  media: json['media'] == null
      ? null
      : MediaBrief.fromJson(json['media'] as Map<String, dynamic>),
  seasons:
      (json['seasons'] as List<dynamic>?)
          ?.map((e) => SeasonOverview.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  existingSubscriptionId: (json['existing_subscription_id'] as num?)?.toInt(),
  movieOwned: json['movie_owned'] as bool? ?? false,
  suggestedSeasons:
      (json['suggested_seasons'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList() ??
      const [],
  candidates:
      (json['candidates'] as List<dynamic>?)
          ?.map((e) => ResolveCandidateView.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  doubanEpisodes: json['douban_episodes'] == null
      ? null
      : DoubanEpisodesView.fromJson(
          json['douban_episodes'] as Map<String, dynamic>,
        ),
  smart: json['smart'] == null
      ? null
      : SmartPlanView.fromJson(json['smart'] as Map<String, dynamic>),
);

Map<String, dynamic> _$PrepareViewToJson(_PrepareView instance) =>
    <String, dynamic>{
      'status': instance.status,
      'media': instance.media,
      'seasons': instance.seasons,
      'existing_subscription_id': instance.existingSubscriptionId,
      'movie_owned': instance.movieOwned,
      'suggested_seasons': instance.suggestedSeasons,
      'candidates': instance.candidates,
      'douban_episodes': instance.doubanEpisodes,
      'smart': instance.smart,
    };

_ProgressView _$ProgressViewFromJson(Map<String, dynamic> json) =>
    _ProgressView(
      total: (json['total'] as num?)?.toInt() ?? 0,
      wanted: (json['wanted'] as num?)?.toInt() ?? 0,
      grabbed: (json['grabbed'] as num?)?.toInt() ?? 0,
      downloaded: (json['downloaded'] as num?)?.toInt() ?? 0,
      imported: (json['imported'] as num?)?.toInt() ?? 0,
      upgrading: (json['upgrading'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$ProgressViewToJson(_ProgressView instance) =>
    <String, dynamic>{
      'total': instance.total,
      'wanted': instance.wanted,
      'grabbed': instance.grabbed,
      'downloaded': instance.downloaded,
      'imported': instance.imported,
      'upgrading': instance.upgrading,
    };

_PushAckBody _$PushAckBodyFromJson(Map<String, dynamic> json) =>
    _PushAckBody(upTo: (json['upTo'] as num?)?.toInt() ?? 0);

Map<String, dynamic> _$PushAckBodyToJson(_PushAckBody instance) =>
    <String, dynamic>{'upTo': instance.upTo};

_PushAckView _$PushAckViewFromJson(Map<String, dynamic> json) =>
    _PushAckView(acked: (json['acked'] as num?)?.toInt() ?? 0);

Map<String, dynamic> _$PushAckViewToJson(_PushAckView instance) =>
    <String, dynamic>{'acked': instance.acked};

_PushChannelView _$PushChannelViewFromJson(Map<String, dynamic> json) =>
    _PushChannelView(
      id: json['id'] as String? ?? "",
      kind: json['kind'] as String? ?? "",
      name: json['name'] as String? ?? "",
      enabled: json['enabled'] as bool? ?? false,
      state: json['state'] as String? ?? "",
      statusText: json['status_text'] as String? ?? "",
    );

Map<String, dynamic> _$PushChannelViewToJson(_PushChannelView instance) =>
    <String, dynamic>{
      'id': instance.id,
      'kind': instance.kind,
      'name': instance.name,
      'enabled': instance.enabled,
      'state': instance.state,
      'status_text': instance.statusText,
    };

_PushChannelsView _$PushChannelsViewFromJson(Map<String, dynamic> json) =>
    _PushChannelsView(
      cloudState: json['cloud_state'] as String? ?? "disconnected",
      channels:
          (json['channels'] as List<dynamic>?)
              ?.map((e) => PushChannelView.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$PushChannelsViewToJson(_PushChannelsView instance) =>
    <String, dynamic>{
      'cloud_state': instance.cloudState,
      'channels': instance.channels,
    };

_PushEventPref _$PushEventPrefFromJson(Map<String, dynamic> json) =>
    _PushEventPref(
      key: json['key'] as String? ?? "",
      title: json['title'] as String? ?? "",
      description: json['description'] as String? ?? "",
      group: json['group'] as String? ?? "",
      enabled: json['enabled'] as bool? ?? false,
    );

Map<String, dynamic> _$PushEventPrefToJson(_PushEventPref instance) =>
    <String, dynamic>{
      'key': instance.key,
      'title': instance.title,
      'description': instance.description,
      'group': instance.group,
      'enabled': instance.enabled,
    };

_PushPreferencesBody _$PushPreferencesBodyFromJson(Map<String, dynamic> json) =>
    _PushPreferencesBody(
      events:
          (json['events'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, e as bool),
          ) ??
          const {},
    );

Map<String, dynamic> _$PushPreferencesBodyToJson(
  _PushPreferencesBody instance,
) => <String, dynamic>{'events': instance.events};

_PushRegistrationBody _$PushRegistrationBodyFromJson(
  Map<String, dynamic> json,
) => _PushRegistrationBody(
  permission: json['permission'] as String? ?? '',
  stream: json['stream'] as bool? ?? false,
  clientVersion: json['clientVersion'] as String?,
);

Map<String, dynamic> _$PushRegistrationBodyToJson(
  _PushRegistrationBody instance,
) => <String, dynamic>{
  'permission': instance.permission,
  'stream': instance.stream,
  'clientVersion': instance.clientVersion,
};

_PushRegistrationView _$PushRegistrationViewFromJson(
  Map<String, dynamic> json,
) => _PushRegistrationView(
  registered: json['registered'] as bool? ?? false,
  status: json['status'] as String? ?? "",
  statusText: json['statusText'] as String? ?? "",
  channelName: json['channelName'] as String?,
);

Map<String, dynamic> _$PushRegistrationViewToJson(
  _PushRegistrationView instance,
) => <String, dynamic>{
  'registered': instance.registered,
  'status': instance.status,
  'statusText': instance.statusText,
  'channelName': instance.channelName,
};

_PushTestResult _$PushTestResultFromJson(Map<String, dynamic> json) =>
    _PushTestResult(
      deviceId: json['deviceId'] as String? ?? "",
      deviceName: json['deviceName'] as String? ?? "",
      result: json['result'] as String? ?? "",
      message: json['message'] as String? ?? "",
    );

Map<String, dynamic> _$PushTestResultToJson(_PushTestResult instance) =>
    <String, dynamic>{
      'deviceId': instance.deviceId,
      'deviceName': instance.deviceName,
      'result': instance.result,
      'message': instance.message,
    };

_PushTestView _$PushTestViewFromJson(Map<String, dynamic> json) =>
    _PushTestView(
      sent: (json['sent'] as num?)?.toInt() ?? 0,
      results:
          (json['results'] as List<dynamic>?)
              ?.map((e) => PushTestResult.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$PushTestViewToJson(_PushTestView instance) =>
    <String, dynamic>{'sent': instance.sent, 'results': instance.results};

_RecentArrivalUnit _$RecentArrivalUnitFromJson(Map<String, dynamic> json) =>
    _RecentArrivalUnit(
      seasonNumber: (json['seasonNumber'] as num?)?.toInt() ?? 0,
      episodeNumber: (json['episodeNumber'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$RecentArrivalUnitToJson(_RecentArrivalUnit instance) =>
    <String, dynamic>{
      'seasonNumber': instance.seasonNumber,
      'episodeNumber': instance.episodeNumber,
    };

_RecentArrivalView _$RecentArrivalViewFromJson(Map<String, dynamic> json) =>
    _RecentArrivalView(
      subscriptionId: (json['subscriptionId'] as num?)?.toInt() ?? 0,
      media: json['media'] == null
          ? const MediaBrief()
          : MediaBrief.fromJson(json['media'] as Map<String, dynamic>),
      seasonNumber: (json['seasonNumber'] as num?)?.toInt() ?? 0,
      episodeNumber: (json['episodeNumber'] as num?)?.toInt() ?? 0,
      episodeName: json['episodeName'] as String?,
      stillUrl: json['stillUrl'] as String?,
      units:
          (json['units'] as List<dynamic>?)
              ?.map(
                (e) => RecentArrivalUnit.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const [],
      progressPercent: (json['progressPercent'] as num?)?.toInt(),
    );

Map<String, dynamic> _$RecentArrivalViewToJson(_RecentArrivalView instance) =>
    <String, dynamic>{
      'subscriptionId': instance.subscriptionId,
      'media': instance.media,
      'seasonNumber': instance.seasonNumber,
      'episodeNumber': instance.episodeNumber,
      'episodeName': instance.episodeName,
      'stillUrl': instance.stillUrl,
      'units': instance.units,
      'progressPercent': instance.progressPercent,
    };

_ReelByteRangeView _$ReelByteRangeViewFromJson(Map<String, dynamic> json) =>
    _ReelByteRangeView(
      offset: (json['offset'] as num?)?.toInt() ?? 0,
      length: (json['length'] as num?)?.toInt() ?? 0,
      purpose: json['purpose'] as String? ?? "",
    );

Map<String, dynamic> _$ReelByteRangeViewToJson(_ReelByteRangeView instance) =>
    <String, dynamic>{
      'offset': instance.offset,
      'length': instance.length,
      'purpose': instance.purpose,
    };

_ReelEpisodeView _$ReelEpisodeViewFromJson(Map<String, dynamic> json) =>
    _ReelEpisodeView(
      season: (json['season'] as num?)?.toInt() ?? 0,
      episode: (json['episode'] as num?)?.toInt() ?? 0,
      name: json['name'] as String?,
      overview: json['overview'] as String?,
    );

Map<String, dynamic> _$ReelEpisodeViewToJson(_ReelEpisodeView instance) =>
    <String, dynamic>{
      'season': instance.season,
      'episode': instance.episode,
      'name': instance.name,
      'overview': instance.overview,
    };

_ReelEventBatch _$ReelEventBatchFromJson(Map<String, dynamic> json) =>
    _ReelEventBatch(
      events:
          (json['events'] as List<dynamic>?)
              ?.map((e) => ReelEventView.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$ReelEventBatchToJson(_ReelEventBatch instance) =>
    <String, dynamic>{'events': instance.events};

_ReelEventResult _$ReelEventResultFromJson(Map<String, dynamic> json) =>
    _ReelEventResult(accepted: (json['accepted'] as num?)?.toInt() ?? 0);

Map<String, dynamic> _$ReelEventResultToJson(_ReelEventResult instance) =>
    <String, dynamic>{'accepted': instance.accepted};

_ReelEventView _$ReelEventViewFromJson(Map<String, dynamic> json) =>
    _ReelEventView(
      reelId: json['reelId'] as String? ?? '',
      kind: json['kind'] as String? ?? '',
      mode: json['mode'] as String? ?? "seek",
      mediaItemId: (json['mediaItemId'] as num?)?.toInt(),
      fileId: (json['fileId'] as num?)?.toInt(),
      positionMs: (json['positionMs'] as num?)?.toInt(),
      watchedMs: (json['watchedMs'] as num?)?.toInt(),
      waitMs: (json['waitMs'] as num?)?.toInt(),
      detail: json['detail'] as String?,
    );

Map<String, dynamic> _$ReelEventViewToJson(_ReelEventView instance) =>
    <String, dynamic>{
      'reelId': instance.reelId,
      'kind': instance.kind,
      'mode': instance.mode,
      'mediaItemId': instance.mediaItemId,
      'fileId': instance.fileId,
      'positionMs': instance.positionMs,
      'watchedMs': instance.watchedMs,
      'waitMs': instance.waitMs,
      'detail': instance.detail,
    };

_ReelFacetsView _$ReelFacetsViewFromJson(Map<String, dynamic> json) =>
    _ReelFacetsView(
      total: (json['total'] as num?)?.toInt() ?? 0,
      filterable: json['filterable'] as bool? ?? true,
      kinds:
          (json['kinds'] as List<dynamic>?)
              ?.map((e) => FacetValue.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      genres:
          (json['genres'] as List<dynamic>?)
              ?.map((e) => FacetValue.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      countries:
          (json['countries'] as List<dynamic>?)
              ?.map((e) => FacetValue.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      decades:
          (json['decades'] as List<dynamic>?)
              ?.map((e) => FacetValue.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      ratings:
          (json['ratings'] as List<dynamic>?)
              ?.map((e) => FacetValue.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      runtimes:
          (json['runtimes'] as List<dynamic>?)
              ?.map((e) => FacetValue.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      watch:
          (json['watch'] as List<dynamic>?)
              ?.map((e) => FacetValue.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$ReelFacetsViewToJson(_ReelFacetsView instance) =>
    <String, dynamic>{
      'total': instance.total,
      'filterable': instance.filterable,
      'kinds': instance.kinds,
      'genres': instance.genres,
      'countries': instance.countries,
      'decades': instance.decades,
      'ratings': instance.ratings,
      'runtimes': instance.runtimes,
      'watch': instance.watch,
    };

_ReelFeedView _$ReelFeedViewFromJson(Map<String, dynamic> json) =>
    _ReelFeedView(
      seed: (json['seed'] as num?)?.toInt() ?? 0,
      nextOffset: (json['nextOffset'] as num?)?.toInt() ?? 0,
      hasMore: json['hasMore'] as bool? ?? false,
      items:
          (json['items'] as List<dynamic>?)
              ?.map((e) => ReelItemView.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$ReelFeedViewToJson(_ReelFeedView instance) =>
    <String, dynamic>{
      'seed': instance.seed,
      'nextOffset': instance.nextOffset,
      'hasMore': instance.hasMore,
      'items': instance.items,
    };

_ReelItemView _$ReelItemViewFromJson(Map<String, dynamic> json) =>
    _ReelItemView(
      id: json['id'] as String? ?? "",
      title: json['title'] == null
          ? const ReelTitleView()
          : ReelTitleView.fromJson(json['title'] as Map<String, dynamic>),
      coverUrl: json['cover_url'] as String?,
      segment: json['segment'] == null
          ? const ReelSegmentView()
          : ReelSegmentView.fromJson(json['segment'] as Map<String, dynamic>),
      play: json['play'] == null
          ? const ReelPlayView()
          : ReelPlayView.fromJson(json['play'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$ReelItemViewToJson(_ReelItemView instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'cover_url': instance.coverUrl,
      'segment': instance.segment,
      'play': instance.play,
    };

_ReelPersonView _$ReelPersonViewFromJson(Map<String, dynamic> json) =>
    _ReelPersonView(
      name: json['name'] as String? ?? "",
      tmdbPersonId: (json['tmdb_person_id'] as num?)?.toInt(),
      avatarUrl: json['avatar_url'] as String?,
    );

Map<String, dynamic> _$ReelPersonViewToJson(_ReelPersonView instance) =>
    <String, dynamic>{
      'name': instance.name,
      'tmdb_person_id': instance.tmdbPersonId,
      'avatar_url': instance.avatarUrl,
    };

_ReelPlayView _$ReelPlayViewFromJson(Map<String, dynamic> json) =>
    _ReelPlayView(
      mode: json['mode'] as String? ?? "",
      streamUrl: json['stream_url'] as String?,
      clipUrl: json['clip_url'] as String?,
      clipSizeBytes: (json['clip_size_bytes'] as num?)?.toInt(),
      sizeBytes: (json['size_bytes'] as num?)?.toInt(),
      disc: json['disc'] as String?,
      audioOrdinal: (json['audio_ordinal'] as num?)?.toInt(),
      subtitle: json['subtitle'] == null
          ? null
          : ReelSubtitleView.fromJson(json['subtitle'] as Map<String, dynamic>),
      prefetch:
          (json['prefetch'] as List<dynamic>?)
              ?.map(
                (e) => ReelByteRangeView.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const [],
    );

Map<String, dynamic> _$ReelPlayViewToJson(_ReelPlayView instance) =>
    <String, dynamic>{
      'mode': instance.mode,
      'stream_url': instance.streamUrl,
      'clip_url': instance.clipUrl,
      'clip_size_bytes': instance.clipSizeBytes,
      'size_bytes': instance.sizeBytes,
      'disc': instance.disc,
      'audio_ordinal': instance.audioOrdinal,
      'subtitle': instance.subtitle,
      'prefetch': instance.prefetch,
    };

_ReelSegmentView _$ReelSegmentViewFromJson(Map<String, dynamic> json) =>
    _ReelSegmentView(
      fileId: (json['file_id'] as num?)?.toInt() ?? 0,
      startMs: (json['start_ms'] as num?)?.toInt() ?? 0,
      endMs: (json['end_ms'] as num?)?.toInt() ?? 0,
      durationMs: (json['duration_ms'] as num?)?.toInt(),
      method: json['method'] as String? ?? "",
    );

Map<String, dynamic> _$ReelSegmentViewToJson(_ReelSegmentView instance) =>
    <String, dynamic>{
      'file_id': instance.fileId,
      'start_ms': instance.startMs,
      'end_ms': instance.endMs,
      'duration_ms': instance.durationMs,
      'method': instance.method,
    };

_ReelSubtitleView _$ReelSubtitleViewFromJson(Map<String, dynamic> json) =>
    _ReelSubtitleView(
      ordinal: (json['ordinal'] as num?)?.toInt() ?? 0,
      language: json['language'] as String?,
      title: json['title'] as String?,
      codec: json['codec'] as String?,
      url: json['url'] as String?,
      format: json['format'] as String?,
    );

Map<String, dynamic> _$ReelSubtitleViewToJson(_ReelSubtitleView instance) =>
    <String, dynamic>{
      'ordinal': instance.ordinal,
      'language': instance.language,
      'title': instance.title,
      'codec': instance.codec,
      'url': instance.url,
      'format': instance.format,
    };

_ReelTitleView _$ReelTitleViewFromJson(Map<String, dynamic> json) =>
    _ReelTitleView(
      mediaItemId: (json['media_item_id'] as num?)?.toInt() ?? 0,
      libraryId: (json['library_id'] as num?)?.toInt() ?? 0,
      kind: json['kind'] as String? ?? "",
      name: json['name'] as String? ?? "",
      year: (json['year'] as num?)?.toInt(),
      rating: (json['rating'] as num?)?.toDouble(),
      runtimeMinutes: (json['runtime_minutes'] as num?)?.toInt(),
      genres:
          (json['genres'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      tagline: json['tagline'] as String?,
      overview: json['overview'] as String?,
      favorite: json['favorite'] as bool? ?? false,
      played: json['played'] as bool? ?? false,
      progressPercent: (json['progress_percent'] as num?)?.toInt(),
      directors:
          (json['directors'] as List<dynamic>?)
              ?.map((e) => ReelPersonView.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      posterUrl: json['poster_url'] as String?,
      backdropUrl: json['backdrop_url'] as String?,
      logoUrl: json['logo_url'] as String?,
      episode: json['episode'] == null
          ? null
          : ReelEpisodeView.fromJson(json['episode'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$ReelTitleViewToJson(_ReelTitleView instance) =>
    <String, dynamic>{
      'media_item_id': instance.mediaItemId,
      'library_id': instance.libraryId,
      'kind': instance.kind,
      'name': instance.name,
      'year': instance.year,
      'rating': instance.rating,
      'runtime_minutes': instance.runtimeMinutes,
      'genres': instance.genres,
      'tagline': instance.tagline,
      'overview': instance.overview,
      'favorite': instance.favorite,
      'played': instance.played,
      'progress_percent': instance.progressPercent,
      'directors': instance.directors,
      'poster_url': instance.posterUrl,
      'backdrop_url': instance.backdropUrl,
      'logo_url': instance.logoUrl,
      'episode': instance.episode,
    };

_RefreshActiveView _$RefreshActiveViewFromJson(Map<String, dynamic> json) =>
    _RefreshActiveView(
      mediaItemId: (json['media_item_id'] as num?)?.toInt() ?? 0,
      title: json['title'] as String? ?? "",
      phase: json['phase'] as String? ?? "",
    );

Map<String, dynamic> _$RefreshActiveViewToJson(_RefreshActiveView instance) =>
    <String, dynamic>{
      'media_item_id': instance.mediaItemId,
      'title': instance.title,
      'phase': instance.phase,
    };

_RegionPreset _$RegionPresetFromJson(Map<String, dynamic> json) =>
    _RegionPreset(
      key: json['key'] as String? ?? "",
      label: json['label'] as String? ?? "",
      countries:
          (json['countries'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );

Map<String, dynamic> _$RegionPresetToJson(_RegionPreset instance) =>
    <String, dynamic>{
      'key': instance.key,
      'label': instance.label,
      'countries': instance.countries,
    };

_ReidentifyGroupView _$ReidentifyGroupViewFromJson(Map<String, dynamic> json) =>
    _ReidentifyGroupView(
      key: json['key'] as String? ?? "",
      outcome: json['outcome'] == null
          ? const ReidentifyOutcomeView()
          : ReidentifyOutcomeView.fromJson(
              json['outcome'] as Map<String, dynamic>,
            ),
      fileIds:
          (json['fileIds'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [],
      fileCount: (json['fileCount'] as num?)?.toInt() ?? 0,
      totalSizeBytes: (json['totalSizeBytes'] as num?)?.toInt() ?? 0,
      sampleNames:
          (json['sampleNames'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );

Map<String, dynamic> _$ReidentifyGroupViewToJson(
  _ReidentifyGroupView instance,
) => <String, dynamic>{
  'key': instance.key,
  'outcome': instance.outcome,
  'fileIds': instance.fileIds,
  'fileCount': instance.fileCount,
  'totalSizeBytes': instance.totalSizeBytes,
  'sampleNames': instance.sampleNames,
};

_ReidentifyOutcomeView _$ReidentifyOutcomeViewFromJson(
  Map<String, dynamic> json,
) => _ReidentifyOutcomeView(
  mediaItemId: (json['mediaItemId'] as num?)?.toInt(),
  tmdbId: (json['tmdbId'] as num?)?.toInt(),
  title: json['title'] as String?,
  year: (json['year'] as num?)?.toInt(),
  posterUrl: json['posterUrl'] as String?,
  source: json['source'] as String?,
  sameAsCurrent: json['sameAsCurrent'] as bool? ?? false,
  reason: json['reason'] as String?,
  code: json['code'] as String?,
  candidates:
      (json['candidates'] as List<dynamic>?)
          ?.map(
            (e) =>
                UnidentifiedCandidateView.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const [],
);

Map<String, dynamic> _$ReidentifyOutcomeViewToJson(
  _ReidentifyOutcomeView instance,
) => <String, dynamic>{
  'mediaItemId': instance.mediaItemId,
  'tmdbId': instance.tmdbId,
  'title': instance.title,
  'year': instance.year,
  'posterUrl': instance.posterUrl,
  'source': instance.source,
  'sameAsCurrent': instance.sameAsCurrent,
  'reason': instance.reason,
  'code': instance.code,
  'candidates': instance.candidates,
};

_ReidentifyPreviewView _$ReidentifyPreviewViewFromJson(
  Map<String, dynamic> json,
) => _ReidentifyPreviewView(
  current: json['current'] == null
      ? const ReviewItemView()
      : ReviewItemView.fromJson(json['current'] as Map<String, dynamic>),
  movie: json['movie'] as bool? ?? true,
  groups:
      (json['groups'] as List<dynamic>?)
          ?.map((e) => ReidentifyGroupView.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  outcome: json['outcome'] == null
      ? const ReidentifyOutcomeView()
      : ReidentifyOutcomeView.fromJson(json['outcome'] as Map<String, dynamic>),
  skippedMissing: (json['skippedMissing'] as num?)?.toInt() ?? 0,
  pinnedIdentity: json['pinnedIdentity'] as bool? ?? false,
  unreachable: json['unreachable'] as bool? ?? false,
  searchSeed: json['searchSeed'] as String? ?? "",
);

Map<String, dynamic> _$ReidentifyPreviewViewToJson(
  _ReidentifyPreviewView instance,
) => <String, dynamic>{
  'current': instance.current,
  'movie': instance.movie,
  'groups': instance.groups,
  'outcome': instance.outcome,
  'skippedMissing': instance.skippedMissing,
  'pinnedIdentity': instance.pinnedIdentity,
  'unreachable': instance.unreachable,
  'searchSeed': instance.searchSeed,
};

_ReidentifyResultView _$ReidentifyResultViewFromJson(
  Map<String, dynamic> json,
) => _ReidentifyResultView(
  total: (json['total'] as num?)?.toInt() ?? 0,
  identified: (json['identified'] as num?)?.toInt() ?? 0,
  unidentified: (json['unidentified'] as num?)?.toInt() ?? 0,
  skippedMissing: (json['skippedMissing'] as num?)?.toInt() ?? 0,
  keptOnError: (json['keptOnError'] as num?)?.toInt() ?? 0,
  changed: json['changed'] as bool? ?? false,
  newMediaItemId: (json['newMediaItemId'] as num?)?.toInt(),
  newTitle: json['newTitle'] as String?,
  pinnedIdentity: json['pinnedIdentity'] as bool? ?? false,
  message: json['message'] as String? ?? "",
);

Map<String, dynamic> _$ReidentifyResultViewToJson(
  _ReidentifyResultView instance,
) => <String, dynamic>{
  'total': instance.total,
  'identified': instance.identified,
  'unidentified': instance.unidentified,
  'skippedMissing': instance.skippedMissing,
  'keptOnError': instance.keptOnError,
  'changed': instance.changed,
  'newMediaItemId': instance.newMediaItemId,
  'newTitle': instance.newTitle,
  'pinnedIdentity': instance.pinnedIdentity,
  'message': instance.message,
};

_RelaxSuggestionView _$RelaxSuggestionViewFromJson(Map<String, dynamic> json) =>
    _RelaxSuggestionView(
      dim: json['dim'] as String? ?? "",
      dimLabel: json['dim_label'] as String? ?? "",
      value: json['value'] as String? ?? "",
      label: json['label'] as String? ?? "",
      count: (json['count'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$RelaxSuggestionViewToJson(
  _RelaxSuggestionView instance,
) => <String, dynamic>{
  'dim': instance.dim,
  'dim_label': instance.dimLabel,
  'value': instance.value,
  'label': instance.label,
  'count': instance.count,
};

_ResolveCandidateView _$ResolveCandidateViewFromJson(
  Map<String, dynamic> json,
) => _ResolveCandidateView(
  tmdbId: (json['tmdb_id'] as num?)?.toInt() ?? 0,
  titleRef: json['title_ref'] as String? ?? "",
  title: json['title'] as String? ?? "",
  originalTitle: json['original_title'] as String? ?? "",
  year: (json['year'] as num?)?.toInt(),
  posterUrl: json['poster_url'] as String?,
);

Map<String, dynamic> _$ResolveCandidateViewToJson(
  _ResolveCandidateView instance,
) => <String, dynamic>{
  'tmdb_id': instance.tmdbId,
  'title_ref': instance.titleRef,
  'title': instance.title,
  'original_title': instance.originalTitle,
  'year': instance.year,
  'poster_url': instance.posterUrl,
};

_ResourceTimingView _$ResourceTimingViewFromJson(Map<String, dynamic> json) =>
    _ResourceTimingView(
      siteId: json['site_id'] as String? ?? "",
      torrentId: json['torrent_id'] as String? ?? "",
      publishTime: json['publish_time'] as String?,
      firstSeenAt: json['first_seen_at'] as String?,
      submittedAt: json['submitted_at'] as String? ?? "",
      publishToSeenSeconds: (json['publish_to_seen_seconds'] as num?)?.toInt(),
      seenToSubmitSeconds: (json['seen_to_submit_seconds'] as num?)?.toInt(),
      publishToSubmitSeconds: (json['publish_to_submit_seconds'] as num?)
          ?.toInt(),
      dryRun: json['dry_run'] as bool? ?? false,
    );

Map<String, dynamic> _$ResourceTimingViewToJson(_ResourceTimingView instance) =>
    <String, dynamic>{
      'site_id': instance.siteId,
      'torrent_id': instance.torrentId,
      'publish_time': instance.publishTime,
      'first_seen_at': instance.firstSeenAt,
      'submitted_at': instance.submittedAt,
      'publish_to_seen_seconds': instance.publishToSeenSeconds,
      'seen_to_submit_seconds': instance.seenToSubmitSeconds,
      'publish_to_submit_seconds': instance.publishToSubmitSeconds,
      'dry_run': instance.dryRun,
    };

_RetentionRequest _$RetentionRequestFromJson(Map<String, dynamic> json) =>
    _RetentionRequest(
      keepVersions: (json['keep_versions'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$RetentionRequestToJson(_RetentionRequest instance) =>
    <String, dynamic>{'keep_versions': instance.keepVersions};

_ReviewItemView _$ReviewItemViewFromJson(Map<String, dynamic> json) =>
    _ReviewItemView(
      mediaItemId: (json['mediaItemId'] as num?)?.toInt() ?? 0,
      tmdbId: (json['tmdbId'] as num?)?.toInt(),
      title: json['title'] as String? ?? "",
      year: (json['year'] as num?)?.toInt(),
      posterUrl: json['posterUrl'] as String?,
    );

Map<String, dynamic> _$ReviewItemViewToJson(_ReviewItemView instance) =>
    <String, dynamic>{
      'mediaItemId': instance.mediaItemId,
      'tmdbId': instance.tmdbId,
      'title': instance.title,
      'year': instance.year,
      'posterUrl': instance.posterUrl,
    };

_RollbackOptions _$RollbackOptionsFromJson(Map<String, dynamic> json) =>
    _RollbackOptions(
      targets:
          (json['targets'] as List<dynamic>?)
              ?.map((e) => RollbackTarget.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      versionsDirBytes: (json['versionsDirBytes'] as num?)?.toInt() ?? 0,
      keepVersions: (json['keepVersions'] as num?)?.toInt() ?? 3,
    );

Map<String, dynamic> _$RollbackOptionsToJson(_RollbackOptions instance) =>
    <String, dynamic>{
      'targets': instance.targets,
      'versionsDirBytes': instance.versionsDirBytes,
      'keepVersions': instance.keepVersions,
    };

_RollbackRequest _$RollbackRequestFromJson(Map<String, dynamic> json) =>
    _RollbackRequest(
      target: json['target'] as String? ?? '',
      restoreBackup: json['restore_backup'] as bool? ?? false,
    );

Map<String, dynamic> _$RollbackRequestToJson(_RollbackRequest instance) =>
    <String, dynamic>{
      'target': instance.target,
      'restore_backup': instance.restoreBackup,
    };

_RollbackTarget _$RollbackTargetFromJson(Map<String, dynamic> json) =>
    _RollbackTarget(
      kind: json['kind'] as String? ?? "version",
      version: json['version'] as String?,
      changelog: json['changelog'] as String?,
      installedAt: json['installedAt'] as String?,
      sizeBytes: (json['sizeBytes'] as num?)?.toInt(),
      schemaAction: json['schemaAction'] as String? ?? "unknown",
      backupTakenAt: json['backupTakenAt'] as String?,
    );

Map<String, dynamic> _$RollbackTargetToJson(_RollbackTarget instance) =>
    <String, dynamic>{
      'kind': instance.kind,
      'version': instance.version,
      'changelog': instance.changelog,
      'installedAt': instance.installedAt,
      'sizeBytes': instance.sizeBytes,
      'schemaAction': instance.schemaAction,
      'backupTakenAt': instance.backupTakenAt,
    };

_RoutingOptionsView _$RoutingOptionsViewFromJson(Map<String, dynamic> json) =>
    _RoutingOptionsView(
      movieGenres:
          (json['movieGenres'] as List<dynamic>?)
              ?.map((e) => GenreOption.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      tvGenres:
          (json['tvGenres'] as List<dynamic>?)
              ?.map((e) => GenreOption.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      regionPresets:
          (json['regionPresets'] as List<dynamic>?)
              ?.map((e) => RegionPreset.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      countryNames:
          (json['countryNames'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, e as String),
          ) ??
          const {},
    );

Map<String, dynamic> _$RoutingOptionsViewToJson(_RoutingOptionsView instance) =>
    <String, dynamic>{
      'movieGenres': instance.movieGenres,
      'tvGenres': instance.tvGenres,
      'regionPresets': instance.regionPresets,
      'countryNames': instance.countryNames,
    };

_RuleSetPayload _$RuleSetPayloadFromJson(Map<String, dynamic> json) =>
    _RuleSetPayload(
      name: json['name'] as String? ?? '',
      spec: json['spec'] as Map<String, dynamic>? ?? const {},
      matchRules: json['matchRules'] as String?,
    );

Map<String, dynamic> _$RuleSetPayloadToJson(_RuleSetPayload instance) =>
    <String, dynamic>{
      'name': instance.name,
      'spec': instance.spec,
      'matchRules': instance.matchRules,
    };

_RuleSetView _$RuleSetViewFromJson(Map<String, dynamic> json) => _RuleSetView(
  id: (json['id'] as num?)?.toInt() ?? 0,
  name: json['name'] as String? ?? "",
  isDefault: json['isDefault'] as bool? ?? false,
  referenceCount: (json['referenceCount'] as num?)?.toInt() ?? 0,
  spec: json['spec'] as Map<String, dynamic>?,
  matchRules:
      (json['matchRules'] as List<dynamic>?)
          ?.map((e) => e as Map<String, dynamic>)
          .toList() ??
      const [],
);

Map<String, dynamic> _$RuleSetViewToJson(_RuleSetView instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'isDefault': instance.isDefault,
      'referenceCount': instance.referenceCount,
      'spec': instance.spec,
      'matchRules': instance.matchRules,
    };

_ScanProgressView _$ScanProgressViewFromJson(Map<String, dynamic> json) =>
    _ScanProgressView(
      phase: json['phase'] as String? ?? "",
      processed: (json['processed'] as num?)?.toInt() ?? 0,
      total: (json['total'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$ScanProgressViewToJson(_ScanProgressView instance) =>
    <String, dynamic>{
      'phase': instance.phase,
      'processed': instance.processed,
      'total': instance.total,
    };

_ScheduledTask _$ScheduledTaskFromJson(Map<String, dynamic> json) =>
    _ScheduledTask(
      key: json['key'] as String? ?? "",
      title: json['title'] as String? ?? "",
      description: json['description'] as String? ?? "",
      enabled: json['enabled'] as bool? ?? false,
      triggerType: json['triggerType'] as String? ?? "interval",
      intervalSeconds: (json['intervalSeconds'] as num?)?.toInt(),
      cronExpr: json['cronExpr'] as String?,
      lastRunAt: json['lastRunAt'] as String?,
      nextRunAt: json['nextRunAt'] as String?,
    );

Map<String, dynamic> _$ScheduledTaskToJson(_ScheduledTask instance) =>
    <String, dynamic>{
      'key': instance.key,
      'title': instance.title,
      'description': instance.description,
      'enabled': instance.enabled,
      'triggerType': instance.triggerType,
      'intervalSeconds': instance.intervalSeconds,
      'cronExpr': instance.cronExpr,
      'lastRunAt': instance.lastRunAt,
      'nextRunAt': instance.nextRunAt,
    };

_ScheduledTaskUpdate _$ScheduledTaskUpdateFromJson(Map<String, dynamic> json) =>
    _ScheduledTaskUpdate(
      enabled: json['enabled'] as bool? ?? false,
      triggerType: json['trigger_type'] as String? ?? '',
      intervalSeconds: (json['interval_seconds'] as num?)?.toInt(),
      cronExpr: json['cron_expr'] as String?,
    );

Map<String, dynamic> _$ScheduledTaskUpdateToJson(
  _ScheduledTaskUpdate instance,
) => <String, dynamic>{
  'enabled': instance.enabled,
  'trigger_type': instance.triggerType,
  'interval_seconds': instance.intervalSeconds,
  'cron_expr': instance.cronExpr,
};

_ScrapeConfigView _$ScrapeConfigViewFromJson(Map<String, dynamic> json) =>
    _ScrapeConfigView(
      setting: json['setting'] == null
          ? const ScrapeSetting()
          : ScrapeSetting.fromJson(json['setting'] as Map<String, dynamic>),
      effective: json['effective'] == null
          ? const ScrapeEffectiveView()
          : ScrapeEffectiveView.fromJson(
              json['effective'] as Map<String, dynamic>,
            ),
    );

Map<String, dynamic> _$ScrapeConfigViewToJson(_ScrapeConfigView instance) =>
    <String, dynamic>{
      'setting': instance.setting,
      'effective': instance.effective,
    };

_ScrapeCountryOption _$ScrapeCountryOptionFromJson(Map<String, dynamic> json) =>
    _ScrapeCountryOption(
      code: json['code'] as String? ?? "",
      name: json['name'] as String? ?? "",
    );

Map<String, dynamic> _$ScrapeCountryOptionToJson(
  _ScrapeCountryOption instance,
) => <String, dynamic>{'code': instance.code, 'name': instance.name};

_ScrapeEffectiveView _$ScrapeEffectiveViewFromJson(Map<String, dynamic> json) =>
    _ScrapeEffectiveView(
      languagePriority:
          (json['language_priority'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      certCountryPriority:
          (json['cert_country_priority'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      posterSize: json['poster_size'] as String? ?? "",
      backdropSize: json['backdrop_size'] as String? ?? "",
      stillSize: json['still_size'] as String? ?? "",
      profileSize: json['profile_size'] as String? ?? "",
      imageQuality: json['image_quality'] as String? ?? "",
    );

Map<String, dynamic> _$ScrapeEffectiveViewToJson(
  _ScrapeEffectiveView instance,
) => <String, dynamic>{
  'language_priority': instance.languagePriority,
  'cert_country_priority': instance.certCountryPriority,
  'poster_size': instance.posterSize,
  'backdrop_size': instance.backdropSize,
  'still_size': instance.stillSize,
  'profile_size': instance.profileSize,
  'image_quality': instance.imageQuality,
};

_ScrapeFanartKeyPayload _$ScrapeFanartKeyPayloadFromJson(
  Map<String, dynamic> json,
) => _ScrapeFanartKeyPayload(key: json['key'] as String? ?? "");

Map<String, dynamic> _$ScrapeFanartKeyPayloadToJson(
  _ScrapeFanartKeyPayload instance,
) => <String, dynamic>{'key': instance.key};

_ScrapeFanartView _$ScrapeFanartViewFromJson(Map<String, dynamic> json) =>
    _ScrapeFanartView(
      configured: json['configured'] as bool? ?? false,
      keyInvalid: json['key_invalid'] as bool? ?? false,
      keyHint: json['key_hint'] as String? ?? "",
    );

Map<String, dynamic> _$ScrapeFanartViewToJson(_ScrapeFanartView instance) =>
    <String, dynamic>{
      'configured': instance.configured,
      'key_invalid': instance.keyInvalid,
      'key_hint': instance.keyHint,
    };

_ScrapeLanguageOption _$ScrapeLanguageOptionFromJson(
  Map<String, dynamic> json,
) => _ScrapeLanguageOption(
  code: json['code'] as String? ?? "",
  name: json['name'] as String? ?? "",
  englishName: json['english_name'] as String? ?? "",
);

Map<String, dynamic> _$ScrapeLanguageOptionToJson(
  _ScrapeLanguageOption instance,
) => <String, dynamic>{
  'code': instance.code,
  'name': instance.name,
  'english_name': instance.englishName,
};

_ScrapeSetting _$ScrapeSettingFromJson(Map<String, dynamic> json) =>
    _ScrapeSetting(
      languagePriority:
          (json['language_priority'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      certCountryPriority:
          (json['cert_country_priority'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      posterMode: json['poster_mode'] as String? ?? "language",
      posterLanguagePriority:
          (json['poster_language_priority'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      backdropLanguagePriority:
          (json['backdrop_language_priority'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      logoLanguagePriority: (json['logo_language_priority'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      posterMinWidth: (json['poster_min_width'] as num?)?.toInt() ?? 0,
      backdropMinWidth: (json['backdrop_min_width'] as num?)?.toInt() ?? 0,
      posterSize: json['poster_size'] as String? ?? "original",
      backdropSize: json['backdrop_size'] as String? ?? "original",
      stillSize: json['still_size'] as String? ?? "original",
      profileSize: json['profile_size'] as String? ?? "original",
      imageQuality: json['image_quality'] as String? ?? "original",
      fanartEnabled: json['fanart_enabled'] as bool?,
      posterSourceOrder: (json['poster_source_order'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      backdropSourceOrder: (json['backdrop_source_order'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      logoSourceOrder: (json['logo_source_order'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      seasonPosterSourceOrder:
          (json['season_poster_source_order'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList(),
      namingEntryDir: json['naming_entry_dir'] as String? ?? "",
      namingMovieFile: json['naming_movie_file'] as String? ?? "",
      namingSeasonDir: json['naming_season_dir'] as String? ?? "",
      namingEpisodeFile: json['naming_episode_file'] as String? ?? "",
      mirrorImages: json['mirror_images'] as bool? ?? false,
      mirrorNfo: json['mirror_nfo'] as bool? ?? false,
      mirrorEpisodeThumbs: json['mirror_episode_thumbs'] as bool? ?? false,
    );

Map<String, dynamic> _$ScrapeSettingToJson(_ScrapeSetting instance) =>
    <String, dynamic>{
      'language_priority': instance.languagePriority,
      'cert_country_priority': instance.certCountryPriority,
      'poster_mode': instance.posterMode,
      'poster_language_priority': instance.posterLanguagePriority,
      'backdrop_language_priority': instance.backdropLanguagePriority,
      'logo_language_priority': instance.logoLanguagePriority,
      'poster_min_width': instance.posterMinWidth,
      'backdrop_min_width': instance.backdropMinWidth,
      'poster_size': instance.posterSize,
      'backdrop_size': instance.backdropSize,
      'still_size': instance.stillSize,
      'profile_size': instance.profileSize,
      'image_quality': instance.imageQuality,
      'fanart_enabled': instance.fanartEnabled,
      'poster_source_order': instance.posterSourceOrder,
      'backdrop_source_order': instance.backdropSourceOrder,
      'logo_source_order': instance.logoSourceOrder,
      'season_poster_source_order': instance.seasonPosterSourceOrder,
      'naming_entry_dir': instance.namingEntryDir,
      'naming_movie_file': instance.namingMovieFile,
      'naming_season_dir': instance.namingSeasonDir,
      'naming_episode_file': instance.namingEpisodeFile,
      'mirror_images': instance.mirrorImages,
      'mirror_nfo': instance.mirrorNfo,
      'mirror_episode_thumbs': instance.mirrorEpisodeThumbs,
    };

_ScrapeStorageEstimate _$ScrapeStorageEstimateFromJson(
  Map<String, dynamic> json,
) => _ScrapeStorageEstimate(
  currentQuality: json['current_quality'] as String? ?? "",
  currentBytes: (json['current_bytes'] as num?)?.toInt() ?? 0,
  presets:
      (json['presets'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, (e as num).toInt()),
      ) ??
      const {},
);

Map<String, dynamic> _$ScrapeStorageEstimateToJson(
  _ScrapeStorageEstimate instance,
) => <String, dynamic>{
  'current_quality': instance.currentQuality,
  'current_bytes': instance.currentBytes,
  'presets': instance.presets,
};

_ScrimUiPrefs _$ScrimUiPrefsFromJson(Map<String, dynamic> json) =>
    _ScrimUiPrefs(
      blur: (json['blur'] as num?)?.toDouble() ?? 0.0,
      dark: (json['dark'] as num?)?.toDouble() ?? 0.0,
    );

Map<String, dynamic> _$ScrimUiPrefsToJson(_ScrimUiPrefs instance) =>
    <String, dynamic>{'blur': instance.blur, 'dark': instance.dark};

_SearchHistoryItem _$SearchHistoryItemFromJson(Map<String, dynamic> json) =>
    _SearchHistoryItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      keyword: json['keyword'] as String? ?? "",
      vertical: json['vertical'] as String? ?? "torrents",
      label: json['label'] as String?,
      categories:
          (json['categories'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      siteIds:
          (json['siteIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      searchCount: (json['searchCount'] as num?)?.toInt() ?? 0,
      lastSearchedAt: json['lastSearchedAt'] as String?,
      hasSnapshot: json['hasSnapshot'] as bool? ?? false,
    );

Map<String, dynamic> _$SearchHistoryItemToJson(_SearchHistoryItem instance) =>
    <String, dynamic>{
      'id': instance.id,
      'keyword': instance.keyword,
      'vertical': instance.vertical,
      'label': instance.label,
      'categories': instance.categories,
      'siteIds': instance.siteIds,
      'searchCount': instance.searchCount,
      'lastSearchedAt': instance.lastSearchedAt,
      'hasSnapshot': instance.hasSnapshot,
    };

_SearchPresetsPayload _$SearchPresetsPayloadFromJson(
  Map<String, dynamic> json,
) => _SearchPresetsPayload(
  presets:
      (json['presets'] as List<dynamic>?)
          ?.map((e) => e as Map<String, dynamic>)
          .toList() ??
      const [],
);

Map<String, dynamic> _$SearchPresetsPayloadToJson(
  _SearchPresetsPayload instance,
) => <String, dynamic>{'presets': instance.presets};

_SearchPresetsView _$SearchPresetsViewFromJson(Map<String, dynamic> json) =>
    _SearchPresetsView(
      presets:
          (json['presets'] as List<dynamic>?)
              ?.map((e) => SearchTabView.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$SearchPresetsViewToJson(_SearchPresetsView instance) =>
    <String, dynamic>{'presets': instance.presets};

_SearchTabView _$SearchTabViewFromJson(Map<String, dynamic> json) =>
    _SearchTabView(
      type: json['type'] as String? ?? "category",
      id: json['id'] as String? ?? "",
      visible: json['visible'] as bool? ?? true,
      name: json['name'] as String?,
      categories:
          (json['categories'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      siteIds:
          (json['siteIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      posterMode: json['posterMode'] as bool? ?? false,
      skipHistory: json['skipHistory'] as bool? ?? false,
    );

Map<String, dynamic> _$SearchTabViewToJson(_SearchTabView instance) =>
    <String, dynamic>{
      'type': instance.type,
      'id': instance.id,
      'visible': instance.visible,
      'name': instance.name,
      'categories': instance.categories,
      'siteIds': instance.siteIds,
      'posterMode': instance.posterMode,
      'skipHistory': instance.skipHistory,
    };

_SeasonAirScheduleView _$SeasonAirScheduleViewFromJson(
  Map<String, dynamic> json,
) => _SeasonAirScheduleView(
  today: json['today'] as String? ?? "",
  region: json['region'] as String?,
  weekdays:
      (json['weekdays'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList() ??
      const [],
  lastAirDate: json['last_air_date'] as String?,
  subscriptionId: (json['subscription_id'] as num?)?.toInt(),
  missingEpisodes:
      (json['missing_episodes'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList() ??
      const [],
  arrivals:
      (json['arrivals'] as List<dynamic>?)
          ?.map((e) => EpisodeArrivalView.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
);

Map<String, dynamic> _$SeasonAirScheduleViewToJson(
  _SeasonAirScheduleView instance,
) => <String, dynamic>{
  'today': instance.today,
  'region': instance.region,
  'weekdays': instance.weekdays,
  'last_air_date': instance.lastAirDate,
  'subscription_id': instance.subscriptionId,
  'missing_episodes': instance.missingEpisodes,
  'arrivals': instance.arrivals,
};

_SeasonEpisodesView _$SeasonEpisodesViewFromJson(Map<String, dynamic> json) =>
    _SeasonEpisodesView(
      seasonNumber: (json['season_number'] as num?)?.toInt() ?? 0,
      episodes:
          (json['episodes'] as List<dynamic>?)
              ?.map((e) => EpisodeView.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      resumeEpisode: (json['resume_episode'] as num?)?.toInt(),
      airSchedule: json['air_schedule'] == null
          ? null
          : SeasonAirScheduleView.fromJson(
              json['air_schedule'] as Map<String, dynamic>,
            ),
    );

Map<String, dynamic> _$SeasonEpisodesViewToJson(_SeasonEpisodesView instance) =>
    <String, dynamic>{
      'season_number': instance.seasonNumber,
      'episodes': instance.episodes,
      'resume_episode': instance.resumeEpisode,
      'air_schedule': instance.airSchedule,
    };

_SeasonOverview _$SeasonOverviewFromJson(Map<String, dynamic> json) =>
    _SeasonOverview(
      seasonNumber: (json['season_number'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? "",
      airDate: json['air_date'] as String?,
      episodeCount: (json['episode_count'] as num?)?.toInt(),
      airedCount: (json['aired_count'] as num?)?.toInt() ?? 0,
      ownedCount: (json['owned_count'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$SeasonOverviewToJson(_SeasonOverview instance) =>
    <String, dynamic>{
      'season_number': instance.seasonNumber,
      'name': instance.name,
      'air_date': instance.airDate,
      'episode_count': instance.episodeCount,
      'aired_count': instance.airedCount,
      'owned_count': instance.ownedCount,
    };

_SeriesPartView _$SeriesPartViewFromJson(Map<String, dynamic> json) =>
    _SeriesPartView(
      tmdbId: (json['tmdb_id'] as num?)?.toInt() ?? 0,
      title: json['title'] as String? ?? "",
      releaseDate: json['release_date'] as String?,
      posterUrl: json['poster_url'] as String?,
      mediaItemId: (json['media_item_id'] as num?)?.toInt(),
      subscribed: json['subscribed'] as bool? ?? false,
    );

Map<String, dynamic> _$SeriesPartViewToJson(_SeriesPartView instance) =>
    <String, dynamic>{
      'tmdb_id': instance.tmdbId,
      'title': instance.title,
      'release_date': instance.releaseDate,
      'poster_url': instance.posterUrl,
      'media_item_id': instance.mediaItemId,
      'subscribed': instance.subscribed,
    };

_ServerAddressItem _$ServerAddressItemFromJson(Map<String, dynamic> json) =>
    _ServerAddressItem(
      url: json['url'] as String? ?? '',
      kind: json['kind'] as String? ?? '',
      source: json['source'] as String? ?? '',
      lastSeen: json['last_seen'] as String?,
    );

Map<String, dynamic> _$ServerAddressItemToJson(_ServerAddressItem instance) =>
    <String, dynamic>{
      'url': instance.url,
      'kind': instance.kind,
      'source': instance.source,
      'last_seen': instance.lastSeen,
    };

_ServerAddressesView _$ServerAddressesViewFromJson(Map<String, dynamic> json) =>
    _ServerAddressesView(
      instanceId: json['instance_id'] as String? ?? "",
      hostKey: json['host_key'] as String? ?? "",
      addresses:
          (json['addresses'] as List<dynamic>?)
              ?.map(
                (e) => ServerAddressItem.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const [],
      lanSubnets:
          (json['lan_subnets'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );

Map<String, dynamic> _$ServerAddressesViewToJson(
  _ServerAddressesView instance,
) => <String, dynamic>{
  'instance_id': instance.instanceId,
  'host_key': instance.hostKey,
  'addresses': instance.addresses,
  'lan_subnets': instance.lanSubnets,
};

_SessionAccepted _$SessionAcceptedFromJson(Map<String, dynamic> json) =>
    _SessionAccepted(
      sessionId: json['sessionId'] as String? ?? '',
      messageId: json['messageId'] as String? ?? "",
    );

Map<String, dynamic> _$SessionAcceptedToJson(_SessionAccepted instance) =>
    <String, dynamic>{
      'sessionId': instance.sessionId,
      'messageId': instance.messageId,
    };

_SessionCapabilities _$SessionCapabilitiesFromJson(Map<String, dynamic> json) =>
    _SessionCapabilities(
      allowSubscribe: json['allow_subscribe'] as bool? ?? false,
      allowSearch: json['allow_search'] as bool? ?? false,
      allowDirectDownload: json['allow_direct_download'] as bool? ?? false,
      allowVideoDownload: json['allow_video_download'] as bool?,
    );

Map<String, dynamic> _$SessionCapabilitiesToJson(
  _SessionCapabilities instance,
) => <String, dynamic>{
  'allow_subscribe': instance.allowSubscribe,
  'allow_search': instance.allowSearch,
  'allow_direct_download': instance.allowDirectDownload,
  'allow_video_download': instance.allowVideoDownload,
};

_SessionMessage _$SessionMessageFromJson(Map<String, dynamic> json) =>
    _SessionMessage(
      role: json['role'] as String? ?? "user",
      content: json['content'],
      toolCalls: (json['toolCalls'] as List<dynamic>?)
          ?.map((e) => ToolCallInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
      toolCallId: json['toolCallId'] as String?,
      name: json['name'] as String?,
    );

Map<String, dynamic> _$SessionMessageToJson(_SessionMessage instance) =>
    <String, dynamic>{
      'role': instance.role,
      'content': instance.content,
      'toolCalls': instance.toolCalls,
      'toolCallId': instance.toolCallId,
      'name': instance.name,
    };

_SessionRename _$SessionRenameFromJson(Map<String, dynamic> json) =>
    _SessionRename(title: json['title'] as String? ?? '');

Map<String, dynamic> _$SessionRenameToJson(_SessionRename instance) =>
    <String, dynamic>{'title': instance.title};

_SessionRetry _$SessionRetryFromJson(Map<String, dynamic> json) =>
    _SessionRetry(
      messageId: json['messageId'] as String?,
      content: json['content'] as String?,
    );

Map<String, dynamic> _$SessionRetryToJson(_SessionRetry instance) =>
    <String, dynamic>{
      'messageId': instance.messageId,
      'content': instance.content,
    };

_SessionSummary _$SessionSummaryFromJson(Map<String, dynamic> json) =>
    _SessionSummary(
      id: json['id'] as String? ?? '',
      title: json['title'] as String?,
      lastPrompt: json['lastPrompt'] as String?,
      entryCount: (json['entryCount'] as num?)?.toInt() ?? 0,
      running: json['running'] as bool? ?? false,
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
    );

Map<String, dynamic> _$SessionSummaryToJson(_SessionSummary instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'lastPrompt': instance.lastPrompt,
      'entryCount': instance.entryCount,
      'running': instance.running,
      'createdAt': instance.createdAt,
      'updatedAt': instance.updatedAt,
    };

_SessionTranscript _$SessionTranscriptFromJson(Map<String, dynamic> json) =>
    _SessionTranscript(
      session: json['session'] == null
          ? const SessionSummary()
          : SessionSummary.fromJson(json['session'] as Map<String, dynamic>),
      entries:
          (json['entries'] as List<dynamic>?)
              ?.map((e) => TranscriptEntry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$SessionTranscriptToJson(_SessionTranscript instance) =>
    <String, dynamic>{'session': instance.session, 'entries': instance.entries};

_SessionView _$SessionViewFromJson(Map<String, dynamic> json) => _SessionView(
  username: json['username'] as String? ?? "",
  nickname: json['nickname'] as String? ?? "",
  avatarUrl: json['avatar_url'] as String?,
  role: json['role'] as String? ?? "",
  capabilities: json['capabilities'] == null
      ? const SessionCapabilities()
      : SessionCapabilities.fromJson(
          json['capabilities'] as Map<String, dynamic>,
        ),
  device: json['device'] == null
      ? null
      : DeviceBrief.fromJson(json['device'] as Map<String, dynamic>),
);

Map<String, dynamic> _$SessionViewToJson(_SessionView instance) =>
    <String, dynamic>{
      'username': instance.username,
      'nickname': instance.nickname,
      'avatar_url': instance.avatarUrl,
      'role': instance.role,
      'capabilities': instance.capabilities,
      'device': instance.device,
    };

_ShareCreateRequest _$ShareCreateRequestFromJson(Map<String, dynamic> json) =>
    _ShareCreateRequest(
      expiresInDays: (json['expiresInDays'] as num?)?.toInt() ?? 7,
      password: json['password'] as String?,
    );

Map<String, dynamic> _$ShareCreateRequestToJson(_ShareCreateRequest instance) =>
    <String, dynamic>{
      'expiresInDays': instance.expiresInDays,
      'password': instance.password,
    };

_SharePublic _$SharePublicFromJson(Map<String, dynamic> json) => _SharePublic(
  requiresPassword: json['requiresPassword'] as bool? ?? false,
  unlocked: json['unlocked'] as bool? ?? false,
  expiresAt: json['expiresAt'] as String?,
  mediaItemId: (json['mediaItemId'] as num?)?.toInt(),
  collectionId: (json['collectionId'] as num?)?.toInt(),
);

Map<String, dynamic> _$SharePublicToJson(_SharePublic instance) =>
    <String, dynamic>{
      'requiresPassword': instance.requiresPassword,
      'unlocked': instance.unlocked,
      'expiresAt': instance.expiresAt,
      'mediaItemId': instance.mediaItemId,
      'collectionId': instance.collectionId,
    };

_ShareRevokedView _$ShareRevokedViewFromJson(Map<String, dynamic> json) =>
    _ShareRevokedView(revoked: json['revoked'] as bool? ?? false);

Map<String, dynamic> _$ShareRevokedViewToJson(_ShareRevokedView instance) =>
    <String, dynamic>{'revoked': instance.revoked};

_ShareUnlockRequest _$ShareUnlockRequestFromJson(Map<String, dynamic> json) =>
    _ShareUnlockRequest(password: json['password'] as String? ?? '');

Map<String, dynamic> _$ShareUnlockRequestToJson(_ShareUnlockRequest instance) =>
    <String, dynamic>{'password': instance.password};

_ShareView _$ShareViewFromJson(Map<String, dynamic> json) => _ShareView(
  id: (json['id'] as num?)?.toInt() ?? 0,
  slug: json['slug'] as String? ?? "",
  url: json['url'] as String? ?? "",
  mediaItemId: (json['mediaItemId'] as num?)?.toInt(),
  collectionId: (json['collectionId'] as num?)?.toInt(),
  libraryId: (json['libraryId'] as num?)?.toInt(),
  title: json['title'] as String? ?? "",
  kind: json['kind'] as String?,
  year: (json['year'] as num?)?.toInt(),
  posterUrl: json['posterUrl'] as String?,
  itemCount: (json['itemCount'] as num?)?.toInt(),
  password: json['password'] as String?,
  expiresAt: json['expiresAt'] as String?,
  createdAt: json['createdAt'] as String?,
  viewCount: (json['viewCount'] as num?)?.toInt() ?? 0,
  lastAccessedAt: json['lastAccessedAt'] as String?,
);

Map<String, dynamic> _$ShareViewToJson(_ShareView instance) =>
    <String, dynamic>{
      'id': instance.id,
      'slug': instance.slug,
      'url': instance.url,
      'mediaItemId': instance.mediaItemId,
      'collectionId': instance.collectionId,
      'libraryId': instance.libraryId,
      'title': instance.title,
      'kind': instance.kind,
      'year': instance.year,
      'posterUrl': instance.posterUrl,
      'itemCount': instance.itemCount,
      'password': instance.password,
      'expiresAt': instance.expiresAt,
      'createdAt': instance.createdAt,
      'viewCount': instance.viewCount,
      'lastAccessedAt': instance.lastAccessedAt,
    };

_SharedCollection _$SharedCollectionFromJson(Map<String, dynamic> json) =>
    _SharedCollection(
      id: (json['id'] as num?)?.toInt(),
      name: json['name'] as String? ?? "",
      description: json['description'] as String?,
      items:
          (json['items'] as List<dynamic>?)
              ?.map(
                (e) => SharedCollectionItem.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const [],
      expiresAt: json['expiresAt'] as String?,
    );

Map<String, dynamic> _$SharedCollectionToJson(_SharedCollection instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'items': instance.items,
      'expiresAt': instance.expiresAt,
    };

_SharedCollectionItem _$SharedCollectionItemFromJson(
  Map<String, dynamic> json,
) => _SharedCollectionItem(
  mediaItemId: (json['mediaItemId'] as num?)?.toInt() ?? 0,
  title: json['title'] as String? ?? "",
  year: (json['year'] as num?)?.toInt(),
  kind: json['kind'] as String? ?? "movie",
  posterUrl: json['posterUrl'] as String?,
);

Map<String, dynamic> _$SharedCollectionItemToJson(
  _SharedCollectionItem instance,
) => <String, dynamic>{
  'mediaItemId': instance.mediaItemId,
  'title': instance.title,
  'year': instance.year,
  'kind': instance.kind,
  'posterUrl': instance.posterUrl,
};

_SharedFile _$SharedFileFromJson(Map<String, dynamic> json) => _SharedFile(
  id: (json['id'] as num?)?.toInt() ?? 0,
  sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
  container: json['container'] as String?,
  resolution: json['resolution'] as String?,
  videoCodec: json['videoCodec'] as String?,
  hdr: json['hdr'] as String?,
  seasonNumber: (json['seasonNumber'] as num?)?.toInt() ?? 0,
  episodeNumber: (json['episodeNumber'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$SharedFileToJson(_SharedFile instance) =>
    <String, dynamic>{
      'id': instance.id,
      'sizeBytes': instance.sizeBytes,
      'container': instance.container,
      'resolution': instance.resolution,
      'videoCodec': instance.videoCodec,
      'hdr': instance.hdr,
      'seasonNumber': instance.seasonNumber,
      'episodeNumber': instance.episodeNumber,
    };

_SharedItem _$SharedItemFromJson(Map<String, dynamic> json) => _SharedItem(
  mediaItemId: (json['mediaItemId'] as num?)?.toInt() ?? 0,
  kind: json['kind'] as String? ?? "movie",
  title: json['title'] as String? ?? "",
  originalTitle: json['originalTitle'] as String?,
  year: (json['year'] as num?)?.toInt(),
  posterUrl: json['posterUrl'] as String?,
  backdropUrl: json['backdropUrl'] as String?,
  primaryAspect: (json['primaryAspect'] as num?)?.toDouble() ?? 0.6667,
  localMeta: json['localMeta'] == null
      ? null
      : LocalMetaView.fromJson(json['localMeta'] as Map<String, dynamic>),
  files:
      (json['files'] as List<dynamic>?)
          ?.map((e) => SharedFile.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  seasons:
      (json['seasons'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList() ??
      const [],
  expiresAt: json['expiresAt'] as String?,
);

Map<String, dynamic> _$SharedItemToJson(_SharedItem instance) =>
    <String, dynamic>{
      'mediaItemId': instance.mediaItemId,
      'kind': instance.kind,
      'title': instance.title,
      'originalTitle': instance.originalTitle,
      'year': instance.year,
      'posterUrl': instance.posterUrl,
      'backdropUrl': instance.backdropUrl,
      'primaryAspect': instance.primaryAspect,
      'localMeta': instance.localMeta,
      'files': instance.files,
      'seasons': instance.seasons,
      'expiresAt': instance.expiresAt,
    };

_SidebarUiPrefs _$SidebarUiPrefsFromJson(Map<String, dynamic> json) =>
    _SidebarUiPrefs(
      transparency: (json['transparency'] as num?)?.toDouble() ?? 0.0,
      brightness: (json['brightness'] as num?)?.toDouble() ?? 0.0,
      depth: (json['depth'] as num?)?.toDouble() ?? 0.0,
    );

Map<String, dynamic> _$SidebarUiPrefsToJson(_SidebarUiPrefs instance) =>
    <String, dynamic>{
      'transparency': instance.transparency,
      'brightness': instance.brightness,
      'depth': instance.depth,
    };

_SiteBoostPayload _$SiteBoostPayloadFromJson(Map<String, dynamic> json) =>
    _SiteBoostPayload(
      enabled: json['enabled'] as bool? ?? false,
      budgetBytes: (json['budgetBytes'] as num?)?.toInt(),
      holdDays: (json['holdDays'] as num?)?.toInt(),
      downloaderId: (json['downloaderId'] as num?)?.toInt(),
    );

Map<String, dynamic> _$SiteBoostPayloadToJson(_SiteBoostPayload instance) =>
    <String, dynamic>{
      'enabled': instance.enabled,
      'budgetBytes': instance.budgetBytes,
      'holdDays': instance.holdDays,
      'downloaderId': instance.downloaderId,
    };

_SiteCatalogItem _$SiteCatalogItemFromJson(Map<String, dynamic> json) =>
    _SiteCatalogItem(
      siteId: json['siteId'] as String? ?? "",
      displayName: json['displayName'] as String? ?? "",
      baseUrl: json['baseUrl'] as String?,
      supportedAuthTypes:
          (json['supportedAuthTypes'] as List<dynamic>?)
              ?.map(
                (e) => AuthTypeRequirement.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const [],
    );

Map<String, dynamic> _$SiteCatalogItemToJson(_SiteCatalogItem instance) =>
    <String, dynamic>{
      'siteId': instance.siteId,
      'displayName': instance.displayName,
      'baseUrl': instance.baseUrl,
      'supportedAuthTypes': instance.supportedAuthTypes,
    };

_SiteConfigCreate _$SiteConfigCreateFromJson(Map<String, dynamic> json) =>
    _SiteConfigCreate(
      siteId: json['siteId'] as String? ?? '',
      authType: json['authType'] as String? ?? '',
      cookie: json['cookie'] as String?,
      apiKey: json['apiKey'] as String?,
      username: json['username'] as String?,
      password: json['password'] as String?,
      enabled: json['enabled'] as bool? ?? true,
    );

Map<String, dynamic> _$SiteConfigCreateToJson(_SiteConfigCreate instance) =>
    <String, dynamic>{
      'siteId': instance.siteId,
      'authType': instance.authType,
      'cookie': instance.cookie,
      'apiKey': instance.apiKey,
      'username': instance.username,
      'password': instance.password,
      'enabled': instance.enabled,
    };

_SiteConfigUpdate _$SiteConfigUpdateFromJson(Map<String, dynamic> json) =>
    _SiteConfigUpdate(
      authType: json['authType'] as String? ?? '',
      cookie: json['cookie'] as String?,
      apiKey: json['apiKey'] as String?,
      username: json['username'] as String?,
      password: json['password'] as String?,
      enabled: json['enabled'] as bool? ?? true,
    );

Map<String, dynamic> _$SiteConfigUpdateToJson(_SiteConfigUpdate instance) =>
    <String, dynamic>{
      'authType': instance.authType,
      'cookie': instance.cookie,
      'apiKey': instance.apiKey,
      'username': instance.username,
      'password': instance.password,
      'enabled': instance.enabled,
    };

_SiteEnabledPayload _$SiteEnabledPayloadFromJson(Map<String, dynamic> json) =>
    _SiteEnabledPayload(enabled: json['enabled'] as bool? ?? false);

Map<String, dynamic> _$SiteEnabledPayloadToJson(_SiteEnabledPayload instance) =>
    <String, dynamic>{'enabled': instance.enabled};

_SitePausePayload _$SitePausePayloadFromJson(Map<String, dynamic> json) =>
    _SitePausePayload(paused: json['paused'] as bool? ?? false);

Map<String, dynamic> _$SitePausePayloadToJson(_SitePausePayload instance) =>
    <String, dynamic>{'paused': instance.paused};

_SiteProfile _$SiteProfileFromJson(Map<String, dynamic> json) => _SiteProfile(
  username: json['username'] as String?,
  userClass: json['userClass'] as String?,
  uploadedBytes: (json['uploadedBytes'] as num?)?.toInt() ?? 0,
  downloadedBytes: (json['downloadedBytes'] as num?)?.toInt() ?? 0,
  ratio: (json['ratio'] as num?)?.toDouble(),
  bonus: (json['bonus'] as num?)?.toDouble(),
  seedingCount: (json['seedingCount'] as num?)?.toInt() ?? 0,
  leechingCount: (json['leechingCount'] as num?)?.toInt() ?? 0,
  fetchedAt: json['fetchedAt'] as String?,
);

Map<String, dynamic> _$SiteProfileToJson(_SiteProfile instance) =>
    <String, dynamic>{
      'username': instance.username,
      'userClass': instance.userClass,
      'uploadedBytes': instance.uploadedBytes,
      'downloadedBytes': instance.downloadedBytes,
      'ratio': instance.ratio,
      'bonus': instance.bonus,
      'seedingCount': instance.seedingCount,
      'leechingCount': instance.leechingCount,
      'fetchedAt': instance.fetchedAt,
    };

_SiteProtectedPayload _$SiteProtectedPayloadFromJson(
  Map<String, dynamic> json,
) => _SiteProtectedPayload(isProtected: json['protected'] as bool? ?? false);

Map<String, dynamic> _$SiteProtectedPayloadToJson(
  _SiteProtectedPayload instance,
) => <String, dynamic>{'protected': instance.isProtected};

_SkillView _$SkillViewFromJson(Map<String, dynamic> json) => _SkillView(
  name: json['name'] as String? ?? "",
  description: json['description'] as String?,
  scope: json['scope'] as String?,
);

Map<String, dynamic> _$SkillViewToJson(_SkillView instance) =>
    <String, dynamic>{
      'name': instance.name,
      'description': instance.description,
      'scope': instance.scope,
    };

_SmartDefaultsPayload _$SmartDefaultsPayloadFromJson(
  Map<String, dynamic> json,
) => _SmartDefaultsPayload(
  movieRevision: (json['movieRevision'] as num?)?.toInt() ?? 0,
  tvRevision: (json['tvRevision'] as num?)?.toInt() ?? 0,
  resolution: json['resolution'] as String? ?? '',
  source: json['source'] as String? ?? '',
  allowUpgrade: json['allowUpgrade'] as bool? ?? false,
  strictResolution: json['strictResolution'] as bool? ?? false,
  movieWaitSeconds: (json['movieWaitSeconds'] as num?)?.toInt() ?? 0,
  tvWaitSeconds: (json['tvWaitSeconds'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$SmartDefaultsPayloadToJson(
  _SmartDefaultsPayload instance,
) => <String, dynamic>{
  'movieRevision': instance.movieRevision,
  'tvRevision': instance.tvRevision,
  'resolution': instance.resolution,
  'source': instance.source,
  'allowUpgrade': instance.allowUpgrade,
  'strictResolution': instance.strictResolution,
  'movieWaitSeconds': instance.movieWaitSeconds,
  'tvWaitSeconds': instance.tvWaitSeconds,
};

_SmartDefaultsView _$SmartDefaultsViewFromJson(Map<String, dynamic> json) =>
    _SmartDefaultsView(
      configured: json['configured'] as bool? ?? false,
      movieRevision: (json['movieRevision'] as num?)?.toInt() ?? 0,
      tvRevision: (json['tvRevision'] as num?)?.toInt() ?? 0,
      resolution: json['resolution'] as String? ?? "2160p",
      source: json['source'] as String? ?? "web-dl",
      allowUpgrade: json['allowUpgrade'] as bool? ?? true,
      strictResolution: json['strictResolution'] as bool? ?? false,
      movieWaitSeconds: (json['movieWaitSeconds'] as num?)?.toInt() ?? 86400,
      tvWaitSeconds: (json['tvWaitSeconds'] as num?)?.toInt() ?? 10800,
    );

Map<String, dynamic> _$SmartDefaultsViewToJson(_SmartDefaultsView instance) =>
    <String, dynamic>{
      'configured': instance.configured,
      'movieRevision': instance.movieRevision,
      'tvRevision': instance.tvRevision,
      'resolution': instance.resolution,
      'source': instance.source,
      'allowUpgrade': instance.allowUpgrade,
      'strictResolution': instance.strictResolution,
      'movieWaitSeconds': instance.movieWaitSeconds,
      'tvWaitSeconds': instance.tvWaitSeconds,
    };

_SmartHabitView _$SmartHabitViewFromJson(Map<String, dynamic> json) =>
    _SmartHabitView(
      key: json['key'] as String? ?? "",
      label: json['label'] as String? ?? "",
      qualityLabel: json['qualityLabel'] as String? ?? "",
      sourceTitle: json['sourceTitle'] as String?,
    );

Map<String, dynamic> _$SmartHabitViewToJson(_SmartHabitView instance) =>
    <String, dynamic>{
      'key': instance.key,
      'label': instance.label,
      'qualityLabel': instance.qualityLabel,
      'sourceTitle': instance.sourceTitle,
    };

_SmartLanguageOptionView _$SmartLanguageOptionViewFromJson(
  Map<String, dynamic> json,
) => _SmartLanguageOptionView(
  key: json['key'] as String? ?? "",
  label: json['label'] as String? ?? "",
);

Map<String, dynamic> _$SmartLanguageOptionViewToJson(
  _SmartLanguageOptionView instance,
) => <String, dynamic>{'key': instance.key, 'label': instance.label};

_SmartLanguageView _$SmartLanguageViewFromJson(Map<String, dynamic> json) =>
    _SmartLanguageView(
      key: json['key'] as String? ?? "",
      label: json['label'] as String? ?? "",
      sourceTitle: json['sourceTitle'] as String?,
      removable: json['removable'] as bool? ?? true,
    );

Map<String, dynamic> _$SmartLanguageViewToJson(_SmartLanguageView instance) =>
    <String, dynamic>{
      'key': instance.key,
      'label': instance.label,
      'sourceTitle': instance.sourceTitle,
      'removable': instance.removable,
    };

_SmartMemoryPatch _$SmartMemoryPatchFromJson(Map<String, dynamic> json) =>
    _SmartMemoryPatch(
      revision: (json['revision'] as num?)?.toInt() ?? 0,
      language: json['language'] as String?,
      understood: json['understood'] as bool?,
      removeHabit: json['removeHabit'] as String?,
    );

Map<String, dynamic> _$SmartMemoryPatchToJson(_SmartMemoryPatch instance) =>
    <String, dynamic>{
      'revision': instance.revision,
      'language': instance.language,
      'understood': instance.understood,
      'removeHabit': instance.removeHabit,
    };

_SmartMemoryView _$SmartMemoryViewFromJson(Map<String, dynamic> json) =>
    _SmartMemoryView(
      revision: (json['revision'] as num?)?.toInt() ?? 0,
      languages:
          (json['languages'] as List<dynamic>?)
              ?.map(
                (e) => SmartLanguageView.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const [],
      addableLanguages:
          (json['addableLanguages'] as List<dynamic>?)
              ?.map(
                (e) =>
                    SmartLanguageOptionView.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const [],
      habits:
          (json['habits'] as List<dynamic>?)
              ?.map((e) => SmartHabitView.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$SmartMemoryViewToJson(_SmartMemoryView instance) =>
    <String, dynamic>{
      'revision': instance.revision,
      'languages': instance.languages,
      'addableLanguages': instance.addableLanguages,
      'habits': instance.habits,
    };

_SmartPlanView _$SmartPlanViewFromJson(
  Map<String, dynamic> json,
) => _SmartPlanView(
  configured: json['configured'] as bool? ?? false,
  profileRevision: (json['profile_revision'] as num?)?.toInt() ?? 0,
  memoryRevision: (json['memory_revision'] as num?)?.toInt() ?? 0,
  resolution: json['resolution'] as String?,
  source: json['source'] as String?,
  qualityLabel: json['quality_label'] as String?,
  qualityNote: json['quality_note'] as String?,
  qualityShadow: json['quality_shadow'] as String?,
  waitLabel: json['wait_label'] as String?,
  subtitleLanguage: json['subtitle_language'] as String?,
  subtitleLanguageLabel: json['subtitle_language_label'] as String?,
  subtitleUnderstood: json['subtitle_understood'] as bool?,
  subtitleLine: json['subtitle_line'] as String?,
  question: json['question'] == null
      ? null
      : SmartQuestionView.fromJson(json['question'] as Map<String, dynamic>),
  subtitleEditQuestion: json['subtitle_edit_question'] == null
      ? null
      : SmartQuestionView.fromJson(
          json['subtitle_edit_question'] as Map<String, dynamic>,
        ),
  scopeOptions:
      (json['scope_options'] as List<dynamic>?)
          ?.map((e) => SmartScopeOptionView.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  canEdit: json['can_edit'] as bool? ?? false,
);

Map<String, dynamic> _$SmartPlanViewToJson(_SmartPlanView instance) =>
    <String, dynamic>{
      'configured': instance.configured,
      'profile_revision': instance.profileRevision,
      'memory_revision': instance.memoryRevision,
      'resolution': instance.resolution,
      'source': instance.source,
      'quality_label': instance.qualityLabel,
      'quality_note': instance.qualityNote,
      'quality_shadow': instance.qualityShadow,
      'wait_label': instance.waitLabel,
      'subtitle_language': instance.subtitleLanguage,
      'subtitle_language_label': instance.subtitleLanguageLabel,
      'subtitle_understood': instance.subtitleUnderstood,
      'subtitle_line': instance.subtitleLine,
      'question': instance.question,
      'subtitle_edit_question': instance.subtitleEditQuestion,
      'scope_options': instance.scopeOptions,
      'can_edit': instance.canEdit,
    };

_SmartPreferences _$SmartPreferencesFromJson(Map<String, dynamic> json) =>
    _SmartPreferences(
      resolution: json['resolution'] as String? ?? "2160p",
      source: json['source'] as String? ?? "web-dl",
      waitSeconds: (json['waitSeconds'] as num?)?.toInt() ?? 7200,
      allowUpgrade: json['allowUpgrade'] as bool? ?? true,
      strictResolution: json['strictResolution'] as bool? ?? false,
    );

Map<String, dynamic> _$SmartPreferencesToJson(_SmartPreferences instance) =>
    <String, dynamic>{
      'resolution': instance.resolution,
      'source': instance.source,
      'waitSeconds': instance.waitSeconds,
      'allowUpgrade': instance.allowUpgrade,
      'strictResolution': instance.strictResolution,
    };

_SmartProfilePayload _$SmartProfilePayloadFromJson(Map<String, dynamic> json) =>
    _SmartProfilePayload(
      revision: (json['revision'] as num?)?.toInt() ?? 0,
      preferences: json['preferences'] == null
          ? const SmartPreferences()
          : SmartPreferences.fromJson(
              json['preferences'] as Map<String, dynamic>,
            ),
    );

Map<String, dynamic> _$SmartProfilePayloadToJson(
  _SmartProfilePayload instance,
) => <String, dynamic>{
  'revision': instance.revision,
  'preferences': instance.preferences,
};

_SmartProfileView _$SmartProfileViewFromJson(Map<String, dynamic> json) =>
    _SmartProfileView(
      kind: json['kind'] as String? ?? "movie",
      revision: (json['revision'] as num?)?.toInt() ?? 0,
      preferences: json['preferences'] == null
          ? null
          : SmartPreferences.fromJson(
              json['preferences'] as Map<String, dynamic>,
            ),
    );

Map<String, dynamic> _$SmartProfileViewToJson(_SmartProfileView instance) =>
    <String, dynamic>{
      'kind': instance.kind,
      'revision': instance.revision,
      'preferences': instance.preferences,
    };

_SmartQuestionView _$SmartQuestionViewFromJson(Map<String, dynamic> json) =>
    _SmartQuestionView(
      language: json['language'] as String? ?? "",
      prompt: json['prompt'] as String? ?? "",
      subtitlesLabel: json['subtitles_label'] as String? ?? "",
      understoodLabel: json['understood_label'] as String? ?? "",
    );

Map<String, dynamic> _$SmartQuestionViewToJson(_SmartQuestionView instance) =>
    <String, dynamic>{
      'language': instance.language,
      'prompt': instance.prompt,
      'subtitles_label': instance.subtitlesLabel,
      'understood_label': instance.understoodLabel,
    };

_SmartScopeOptionView _$SmartScopeOptionViewFromJson(
  Map<String, dynamic> json,
) => _SmartScopeOptionView(
  value: json['value'] as String? ?? "",
  label: json['label'] as String? ?? "",
);

Map<String, dynamic> _$SmartScopeOptionViewToJson(
  _SmartScopeOptionView instance,
) => <String, dynamic>{'value': instance.value, 'label': instance.label};

_SmartSubtitleView _$SmartSubtitleViewFromJson(Map<String, dynamic> json) =>
    _SmartSubtitleView(
      language: json['language'] as String? ?? "",
      languageLabel: json['language_label'] as String? ?? "",
      line: json['line'] as String? ?? "",
      understood: json['understood'] as bool? ?? false,
    );

Map<String, dynamic> _$SmartSubtitleViewToJson(_SmartSubtitleView instance) =>
    <String, dynamic>{
      'language': instance.language,
      'language_label': instance.languageLabel,
      'line': instance.line,
      'understood': instance.understood,
    };

_SmartWaitPayload _$SmartWaitPayloadFromJson(Map<String, dynamic> json) =>
    _SmartWaitPayload(
      version: (json['version'] as num?)?.toInt() ?? 0,
      extendSeconds: (json['extendSeconds'] as num?)?.toInt(),
      candidateKey: json['candidateKey'] as String?,
    );

Map<String, dynamic> _$SmartWaitPayloadToJson(_SmartWaitPayload instance) =>
    <String, dynamic>{
      'version': instance.version,
      'extendSeconds': instance.extendSeconds,
      'candidateKey': instance.candidateKey,
    };

_StorageDir _$StorageDirFromJson(Map<String, dynamic> json) => _StorageDir(
  key: json['key'] as String? ?? "",
  title: json['title'] as String? ?? "",
  summary: json['summary'] as String? ?? "",
  description: json['description'] as String? ?? "",
  path: json['path'] as String? ?? "",
  group: json['group'] as String? ?? "data",
  rebuildCost: json['rebuildCost'] as String? ?? "none",
  clearable: json['clearable'] as bool? ?? false,
  orphanAware: json['orphanAware'] as bool? ?? false,
  exists: json['exists'] as bool? ?? true,
);

Map<String, dynamic> _$StorageDirToJson(_StorageDir instance) =>
    <String, dynamic>{
      'key': instance.key,
      'title': instance.title,
      'summary': instance.summary,
      'description': instance.description,
      'path': instance.path,
      'group': instance.group,
      'rebuildCost': instance.rebuildCost,
      'clearable': instance.clearable,
      'orphanAware': instance.orphanAware,
      'exists': instance.exists,
    };

_StorageState _$StorageStateFromJson(Map<String, dynamic> json) =>
    _StorageState(
      usage: json['usage'] == null
          ? null
          : StorageUsage.fromJson(json['usage'] as Map<String, dynamic>),
      computing: json['computing'] as bool? ?? false,
      error: json['error'] as String?,
    );

Map<String, dynamic> _$StorageStateToJson(_StorageState instance) =>
    <String, dynamic>{
      'usage': instance.usage,
      'computing': instance.computing,
      'error': instance.error,
    };

_StorageUsage _$StorageUsageFromJson(Map<String, dynamic> json) =>
    _StorageUsage(
      dataRoot: json['dataRoot'] as String? ?? "",
      diskTotal: (json['diskTotal'] as num?)?.toInt() ?? 0,
      diskUsed: (json['diskUsed'] as num?)?.toInt() ?? 0,
      diskFree: (json['diskFree'] as num?)?.toInt() ?? 0,
      cacheBytes: (json['cacheBytes'] as num?)?.toInt() ?? 0,
      dataBytes: (json['dataBytes'] as num?)?.toInt() ?? 0,
      dirs:
          (json['dirs'] as List<dynamic>?)
              ?.map((e) => StorageDir.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      computedAt: (json['computedAt'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$StorageUsageToJson(_StorageUsage instance) =>
    <String, dynamic>{
      'dataRoot': instance.dataRoot,
      'diskTotal': instance.diskTotal,
      'diskUsed': instance.diskUsed,
      'diskFree': instance.diskFree,
      'cacheBytes': instance.cacheBytes,
      'dataBytes': instance.dataBytes,
      'dirs': instance.dirs,
      'computedAt': instance.computedAt,
    };

_SubActivityView _$SubActivityViewFromJson(Map<String, dynamic> json) =>
    _SubActivityView(
      id: (json['id'] as num?)?.toInt() ?? 0,
      type: json['type'] as String? ?? "",
      message: json['message'] as String? ?? "",
      createdAt: json['createdAt'] as String?,
    );

Map<String, dynamic> _$SubActivityViewToJson(_SubActivityView instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': instance.type,
      'message': instance.message,
      'createdAt': instance.createdAt,
    };

_SubscriptionCreateRequest _$SubscriptionCreateRequestFromJson(
  Map<String, dynamic> json,
) => _SubscriptionCreateRequest(
  titleRef: json['titleRef'] as String? ?? '',
  sourceTitleRef: json['sourceTitleRef'] as String?,
  selectedSeasons:
      (json['selectedSeasons'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList() ??
      const [],
  followFuture: json['followFuture'] as bool? ?? false,
  ruleSetId: (json['ruleSetId'] as num?)?.toInt(),
  libraryId: (json['libraryId'] as num?)?.toInt(),
  selectionMode: json['selectionMode'] as String?,
  smartProfileRevision: (json['smartProfileRevision'] as num?)?.toInt(),
  smartLanguageAnswer: json['smartLanguageAnswer'] as String?,
  smartResolution: json['smartResolution'] as String?,
  smartSource: json['smartSource'] as String?,
  smartScope: json['smartScope'] as String?,
  smartMemoryRevision: (json['smartMemoryRevision'] as num?)?.toInt(),
);

Map<String, dynamic> _$SubscriptionCreateRequestToJson(
  _SubscriptionCreateRequest instance,
) => <String, dynamic>{
  'titleRef': instance.titleRef,
  'sourceTitleRef': instance.sourceTitleRef,
  'selectedSeasons': instance.selectedSeasons,
  'followFuture': instance.followFuture,
  'ruleSetId': instance.ruleSetId,
  'libraryId': instance.libraryId,
  'selectionMode': instance.selectionMode,
  'smartProfileRevision': instance.smartProfileRevision,
  'smartLanguageAnswer': instance.smartLanguageAnswer,
  'smartResolution': instance.smartResolution,
  'smartSource': instance.smartSource,
  'smartScope': instance.smartScope,
  'smartMemoryRevision': instance.smartMemoryRevision,
};

_SubscriptionCreateView _$SubscriptionCreateViewFromJson(
  Map<String, dynamic> json,
) => _SubscriptionCreateView(
  subscription: json['subscription'] == null
      ? const SubscriptionDetailView()
      : SubscriptionDetailView.fromJson(
          json['subscription'] as Map<String, dynamic>,
        ),
  downloadRouting: json['download_routing'] == null
      ? null
      : DispatchPreviewView.fromJson(
          json['download_routing'] as Map<String, dynamic>,
        ),
);

Map<String, dynamic> _$SubscriptionCreateViewToJson(
  _SubscriptionCreateView instance,
) => <String, dynamic>{
  'subscription': instance.subscription,
  'download_routing': instance.downloadRouting,
};

_SubscriptionDetailView _$SubscriptionDetailViewFromJson(
  Map<String, dynamic> json,
) => _SubscriptionDetailView(
  id: (json['id'] as num?)?.toInt() ?? 0,
  media: json['media'] == null
      ? const MediaBrief()
      : MediaBrief.fromJson(json['media'] as Map<String, dynamic>),
  status: json['status'] as String? ?? "",
  selectedSeasons:
      (json['selected_seasons'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList() ??
      const [],
  followFuture: json['follow_future'] as bool? ?? false,
  ruleSetId: (json['rule_set_id'] as num?)?.toInt() ?? 0,
  selectionMode: json['selection_mode'] as String? ?? "",
  smartPolicy: json['smart_policy'] as Map<String, dynamic>?,
  smartStatus: json['smart_status'] as String?,
  libraryId: (json['library_id'] as num?)?.toInt(),
  progress: json['progress'] == null
      ? const ProgressView()
      : ProgressView.fromJson(json['progress'] as Map<String, dynamic>),
  seasonCollection:
      (json['season_collection'] as List<dynamic>?)
          ?.map((e) => SeasonOverview.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  episodeWindows: (json['episode_windows'] as List<dynamic>?)
      ?.map((e) => EpisodeWindowView.fromJson(e as Map<String, dynamic>))
      .toList(),
  createdAt: json['created_at'] as String? ?? "",
  updatedAt: json['updated_at'] as String? ?? "",
  wanted:
      (json['wanted'] as List<dynamic>?)
          ?.map((e) => WantedView.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  episodeSeasons: (json['episode_seasons'] as List<dynamic>?)
      ?.map((e) => EpisodeSeasonView.fromJson(e as Map<String, dynamic>))
      .toList(),
  episodeHints: (json['episode_hints'] as List<dynamic>?)
      ?.map((e) => EpisodeHintView.fromJson(e as Map<String, dynamic>))
      .toList(),
  canManage: json['can_manage'] as bool? ?? false,
  forecastPending: json['forecast_pending'] as bool? ?? false,
  smartSubtitle: json['smart_subtitle'] == null
      ? null
      : SmartSubtitleView.fromJson(
          json['smart_subtitle'] as Map<String, dynamic>,
        ),
  smartQualityNote: json['smart_quality_note'] as String?,
);

Map<String, dynamic> _$SubscriptionDetailViewToJson(
  _SubscriptionDetailView instance,
) => <String, dynamic>{
  'id': instance.id,
  'media': instance.media,
  'status': instance.status,
  'selected_seasons': instance.selectedSeasons,
  'follow_future': instance.followFuture,
  'rule_set_id': instance.ruleSetId,
  'selection_mode': instance.selectionMode,
  'smart_policy': instance.smartPolicy,
  'smart_status': instance.smartStatus,
  'library_id': instance.libraryId,
  'progress': instance.progress,
  'season_collection': instance.seasonCollection,
  'episode_windows': instance.episodeWindows,
  'created_at': instance.createdAt,
  'updated_at': instance.updatedAt,
  'wanted': instance.wanted,
  'episode_seasons': instance.episodeSeasons,
  'episode_hints': instance.episodeHints,
  'can_manage': instance.canManage,
  'forecast_pending': instance.forecastPending,
  'smart_subtitle': instance.smartSubtitle,
  'smart_quality_note': instance.smartQualityNote,
};

_SubscriptionDownloadView _$SubscriptionDownloadViewFromJson(
  Map<String, dynamic> json,
) => _SubscriptionDownloadView(
  infoHash: json['infoHash'] as String? ?? "",
  name: json['name'] as String?,
  progress: (json['progress'] as num?)?.toDouble(),
  sizeBytes: (json['sizeBytes'] as num?)?.toInt(),
  dlspeedBytes: (json['dlspeedBytes'] as num?)?.toInt(),
  etaSeconds: (json['etaSeconds'] as num?)?.toInt(),
  state: json['state'] as String? ?? "unknown",
  errorMessage: json['errorMessage'] as String?,
  downloaderName: json['downloaderName'] as String?,
  units:
      (json['units'] as List<dynamic>?)
          ?.map((e) => DownloadUnitView.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
);

Map<String, dynamic> _$SubscriptionDownloadViewToJson(
  _SubscriptionDownloadView instance,
) => <String, dynamic>{
  'infoHash': instance.infoHash,
  'name': instance.name,
  'progress': instance.progress,
  'sizeBytes': instance.sizeBytes,
  'dlspeedBytes': instance.dlspeedBytes,
  'etaSeconds': instance.etaSeconds,
  'state': instance.state,
  'errorMessage': instance.errorMessage,
  'downloaderName': instance.downloaderName,
  'units': instance.units,
};

_SubscriptionView _$SubscriptionViewFromJson(Map<String, dynamic> json) =>
    _SubscriptionView(
      id: (json['id'] as num?)?.toInt() ?? 0,
      media: json['media'] == null
          ? const MediaBrief()
          : MediaBrief.fromJson(json['media'] as Map<String, dynamic>),
      status: json['status'] as String? ?? "",
      selectedSeasons:
          (json['selectedSeasons'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [],
      followFuture: json['followFuture'] as bool? ?? false,
      ruleSetId: (json['ruleSetId'] as num?)?.toInt(),
      libraryId: (json['libraryId'] as num?)?.toInt(),
      progress: json['progress'] == null
          ? const ProgressView()
          : ProgressView.fromJson(json['progress'] as Map<String, dynamic>),
      seasonCollection:
          (json['seasonCollection'] as List<dynamic>?)
              ?.map((e) => SeasonOverview.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      episodeWindows: (json['episodeWindows'] as List<dynamic>?)
          ?.map((e) => EpisodeWindowView.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
      wanted:
          (json['wanted'] as List<dynamic>?)
              ?.map((e) => WantedView.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      canManage: json['canManage'] as bool? ?? true,
      forecastPending: json['forecastPending'] as bool? ?? false,
      selectionMode: json['selectionMode'] as String? ?? "rules",
      smartPolicy: json['smartPolicy'] as Map<String, dynamic>?,
      smartStatus: json['smartStatus'] as String?,
      smartSubtitle: json['smartSubtitle'] == null
          ? null
          : SmartSubtitleView.fromJson(
              json['smartSubtitle'] as Map<String, dynamic>,
            ),
      smartQualityNote: json['smartQualityNote'] as String?,
    );

Map<String, dynamic> _$SubscriptionViewToJson(_SubscriptionView instance) =>
    <String, dynamic>{
      'id': instance.id,
      'media': instance.media,
      'status': instance.status,
      'selectedSeasons': instance.selectedSeasons,
      'followFuture': instance.followFuture,
      'ruleSetId': instance.ruleSetId,
      'libraryId': instance.libraryId,
      'progress': instance.progress,
      'seasonCollection': instance.seasonCollection,
      'episodeWindows': instance.episodeWindows,
      'createdAt': instance.createdAt,
      'updatedAt': instance.updatedAt,
      'wanted': instance.wanted,
      'canManage': instance.canManage,
      'forecastPending': instance.forecastPending,
      'selectionMode': instance.selectionMode,
      'smartPolicy': instance.smartPolicy,
      'smartStatus': instance.smartStatus,
      'smartSubtitle': instance.smartSubtitle,
      'smartQualityNote': instance.smartQualityNote,
    };

_SubtitleGenBlockerView _$SubtitleGenBlockerViewFromJson(
  Map<String, dynamic> json,
) => _SubtitleGenBlockerView(
  code: json['code'] as String? ?? "",
  title: json['title'] as String? ?? "",
  message: json['message'] as String? ?? "",
  suggestions:
      (json['suggestions'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
);

Map<String, dynamic> _$SubtitleGenBlockerViewToJson(
  _SubtitleGenBlockerView instance,
) => <String, dynamic>{
  'code': instance.code,
  'title': instance.title,
  'message': instance.message,
  'suggestions': instance.suggestions,
};

_SubtitleGenCandidateView _$SubtitleGenCandidateViewFromJson(
  Map<String, dynamic> json,
) => _SubtitleGenCandidateView(
  kind: json['kind'] as String? ?? "",
  key: json['key'] as String? ?? "",
  language: json['language'] as String?,
  format: json['format'] as String?,
  provenance: json['provenance'] as String? ?? "original",
  excluded: json['excluded'] as String?,
  reasons:
      (json['reasons'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  selectable: json['selectable'] as bool? ?? true,
  requiresOcr: json['requiresOcr'] as bool? ?? false,
);

Map<String, dynamic> _$SubtitleGenCandidateViewToJson(
  _SubtitleGenCandidateView instance,
) => <String, dynamic>{
  'kind': instance.kind,
  'key': instance.key,
  'language': instance.language,
  'format': instance.format,
  'provenance': instance.provenance,
  'excluded': instance.excluded,
  'reasons': instance.reasons,
  'selectable': instance.selectable,
  'requiresOcr': instance.requiresOcr,
};

_SubtitleGenPreviewView _$SubtitleGenPreviewViewFromJson(
  Map<String, dynamic> json,
) => _SubtitleGenPreviewView(
  candidates:
      (json['candidates'] as List<dynamic>?)
          ?.map(
            (e) => SubtitleGenCandidateView.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const [],
  chosenKey: json['chosenKey'] as String?,
  selectedSourceKey: json['selectedSourceKey'] as String?,
  eventCount: (json['eventCount'] as num?)?.toInt() ?? 0,
  estimatedTokens: (json['estimatedTokens'] as num?)?.toInt() ?? 0,
  alreadyGenerated: json['alreadyGenerated'] as bool? ?? false,
  warnings:
      (json['warnings'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  pgsConversion: json['pgsConversion'] == null
      ? null
      : PgsConversionView.fromJson(
          json['pgsConversion'] as Map<String, dynamic>,
        ),
  blocker: json['blocker'] == null
      ? null
      : SubtitleGenBlockerView.fromJson(
          json['blocker'] as Map<String, dynamic>,
        ),
  outputFilename: json['outputFilename'] as String?,
  referenceNotice: json['referenceNotice'] as String?,
  pending: json['pending'] == null
      ? null
      : PendingView.fromJson(json['pending'] as Map<String, dynamic>),
);

Map<String, dynamic> _$SubtitleGenPreviewViewToJson(
  _SubtitleGenPreviewView instance,
) => <String, dynamic>{
  'candidates': instance.candidates,
  'chosenKey': instance.chosenKey,
  'selectedSourceKey': instance.selectedSourceKey,
  'eventCount': instance.eventCount,
  'estimatedTokens': instance.estimatedTokens,
  'alreadyGenerated': instance.alreadyGenerated,
  'warnings': instance.warnings,
  'pgsConversion': instance.pgsConversion,
  'blocker': instance.blocker,
  'outputFilename': instance.outputFilename,
  'referenceNotice': instance.referenceNotice,
  'pending': instance.pending,
};

_SubtitleGenStartPayload _$SubtitleGenStartPayloadFromJson(
  Map<String, dynamic> json,
) => _SubtitleGenStartPayload(
  targetLanguage: json['targetLanguage'] as String? ?? "chs",
  secondaryLanguage: json['secondaryLanguage'] as String?,
  sourceCandidateKey: json['sourceCandidateKey'] as String?,
  convertPgs: json['convertPgs'] as bool? ?? false,
  pgsOcrLanguage: json['pgsOcrLanguage'] as String?,
);

Map<String, dynamic> _$SubtitleGenStartPayloadToJson(
  _SubtitleGenStartPayload instance,
) => <String, dynamic>{
  'targetLanguage': instance.targetLanguage,
  'secondaryLanguage': instance.secondaryLanguage,
  'sourceCandidateKey': instance.sourceCandidateKey,
  'convertPgs': instance.convertPgs,
  'pgsOcrLanguage': instance.pgsOcrLanguage,
};

_SubtitlePlanView _$SubtitlePlanViewFromJson(Map<String, dynamic> json) =>
    _SubtitlePlanView(
      trackRef: json['track_ref'] as String? ?? "",
      kind: json['kind'] as String? ?? "",
      language: json['language'] as String?,
      isDefault: json['is_default'] as bool? ?? false,
      isAi: json['is_ai'] as bool? ?? false,
      title: json['title'] as String?,
      isForced: json['is_forced'] as bool?,
    );

Map<String, dynamic> _$SubtitlePlanViewToJson(_SubtitlePlanView instance) =>
    <String, dynamic>{
      'track_ref': instance.trackRef,
      'kind': instance.kind,
      'language': instance.language,
      'is_default': instance.isDefault,
      'is_ai': instance.isAi,
      'title': instance.title,
      'is_forced': instance.isForced,
    };

_SubtitleStreamView _$SubtitleStreamViewFromJson(Map<String, dynamic> json) =>
    _SubtitleStreamView(
      codec: json['codec'] as String?,
      language: json['language'] as String?,
      title: json['title'] as String?,
      forced: json['forced'] as bool? ?? false,
      defaultValue: json['default'] as bool? ?? false,
      externalValue: json['external'] as bool? ?? false,
      fileName: json['file_name'] as String?,
    );

Map<String, dynamic> _$SubtitleStreamViewToJson(_SubtitleStreamView instance) =>
    <String, dynamic>{
      'codec': instance.codec,
      'language': instance.language,
      'title': instance.title,
      'forced': instance.forced,
      'default': instance.defaultValue,
      'external': instance.externalValue,
      'file_name': instance.fileName,
    };

_TipRecordView _$TipRecordViewFromJson(Map<String, dynamic> json) =>
    _TipRecordView(
      tipId: json['tipId'] as String? ?? "",
      displayCount: (json['displayCount'] as num?)?.toInt() ?? 0,
      firstDisplayedAt: json['firstDisplayedAt'] as String?,
      lastDisplayedAt: json['lastDisplayedAt'] as String?,
      invalidatedAt: json['invalidatedAt'] as String?,
      invalidatedReason: json['invalidatedReason'] as String?,
    );

Map<String, dynamic> _$TipRecordViewToJson(_TipRecordView instance) =>
    <String, dynamic>{
      'tipId': instance.tipId,
      'displayCount': instance.displayCount,
      'firstDisplayedAt': instance.firstDisplayedAt,
      'lastDisplayedAt': instance.lastDisplayedAt,
      'invalidatedAt': instance.invalidatedAt,
      'invalidatedReason': instance.invalidatedReason,
    };

_TipStateView _$TipStateViewFromJson(Map<String, dynamic> json) =>
    _TipStateView(
      tips:
          (json['tips'] as List<dynamic>?)
              ?.map((e) => TipRecordView.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$TipStateViewToJson(_TipStateView instance) =>
    <String, dynamic>{'tips': instance.tips};

_TitleDetails _$TitleDetailsFromJson(Map<String, dynamic> json) =>
    _TitleDetails(
      title: json['title'] == null
          ? const DiscoveredTitle()
          : DiscoveredTitle.fromJson(json['title'] as Map<String, dynamic>),
      metadata: json['metadata'] == null
          ? const TitleMetadata()
          : TitleMetadata.fromJson(json['metadata'] as Map<String, dynamic>),
      backdropOriginalUrl: json['backdropOriginalUrl'] as String?,
      recommendations:
          (json['recommendations'] as List<dynamic>?)
              ?.map((e) => DiscoveredTitle.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      libraryLinks:
          (json['libraryLinks'] as List<dynamic>?)
              ?.map((e) => MediaLibraryLink.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      backdrops:
          (json['backdrops'] as List<dynamic>?)
              ?.map((e) => MediaImage.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      posters:
          (json['posters'] as List<dynamic>?)
              ?.map((e) => MediaImage.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      videos:
          (json['videos'] as List<dynamic>?)
              ?.map((e) => MediaVideo.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$TitleDetailsToJson(_TitleDetails instance) =>
    <String, dynamic>{
      'title': instance.title,
      'metadata': instance.metadata,
      'backdropOriginalUrl': instance.backdropOriginalUrl,
      'recommendations': instance.recommendations,
      'libraryLinks': instance.libraryLinks,
      'backdrops': instance.backdrops,
      'posters': instance.posters,
      'videos': instance.videos,
    };

_TitleMetadata _$TitleMetadataFromJson(
  Map<String, dynamic> json,
) => _TitleMetadata(
  plot: json['plot'] as String?,
  runtimeMinutes: (json['runtimeMinutes'] as num?)?.toInt(),
  genres:
      (json['genres'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  directors:
      (json['directors'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  cast:
      (json['cast'] as List<dynamic>?)
          ?.map((e) => CastMember.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  country: json['country'] as String? ?? "",
  language: json['language'] as String? ?? "",
  released: json['released'] as String? ?? "",
  network: json['network'] as String?,
);

Map<String, dynamic> _$TitleMetadataToJson(_TitleMetadata instance) =>
    <String, dynamic>{
      'plot': instance.plot,
      'runtimeMinutes': instance.runtimeMinutes,
      'genres': instance.genres,
      'directors': instance.directors,
      'cast': instance.cast,
      'country': instance.country,
      'language': instance.language,
      'released': instance.released,
      'network': instance.network,
    };

_TitlePreviewRequest _$TitlePreviewRequestFromJson(Map<String, dynamic> json) =>
    _TitlePreviewRequest(titleRef: json['titleRef'] as String? ?? '');

Map<String, dynamic> _$TitlePreviewRequestToJson(
  _TitlePreviewRequest instance,
) => <String, dynamic>{'titleRef': instance.titleRef};

_TitleSearchRequest _$TitleSearchRequestFromJson(Map<String, dynamic> json) =>
    _TitleSearchRequest(
      query: json['query'] as String? ?? '',
      provider: json['provider'] as String? ?? "all",
      saveHistory: json['saveHistory'] as bool? ?? true,
    );

Map<String, dynamic> _$TitleSearchRequestToJson(_TitleSearchRequest instance) =>
    <String, dynamic>{
      'query': instance.query,
      'provider': instance.provider,
      'saveHistory': instance.saveHistory,
    };

_TitleSearchView _$TitleSearchViewFromJson(Map<String, dynamic> json) =>
    _TitleSearchView(
      query: json['query'] as String? ?? "",
      titles:
          (json['titles'] as List<dynamic>?)
              ?.map((e) => DiscoveredTitle.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      historyId: (json['historyId'] as num?)?.toInt(),
    );

Map<String, dynamic> _$TitleSearchViewToJson(_TitleSearchView instance) =>
    <String, dynamic>{
      'query': instance.query,
      'titles': instance.titles,
      'historyId': instance.historyId,
    };

_TodayArrival _$TodayArrivalFromJson(Map<String, dynamic> json) =>
    _TodayArrival(
      subscriptionId: (json['subscriptionId'] as num?)?.toInt() ?? 0,
      mediaTitle: json['mediaTitle'] as String? ?? "",
      mediaKind: json['mediaKind'] as String? ?? "tv",
      seasonNumber: (json['seasonNumber'] as num?)?.toInt() ?? 0,
      episodeNumber: (json['episodeNumber'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? "wanted",
      airDate: json['airDate'] as String?,
      expectedDay: json['expectedDay'] as String?,
      daysAhead: (json['daysAhead'] as num?)?.toInt() ?? 0,
      estimatedReleaseToImportMinutes:
          (json['estimatedReleaseToImportMinutes'] as num?)?.toInt(),
    );

Map<String, dynamic> _$TodayArrivalToJson(
  _TodayArrival instance,
) => <String, dynamic>{
  'subscriptionId': instance.subscriptionId,
  'mediaTitle': instance.mediaTitle,
  'mediaKind': instance.mediaKind,
  'seasonNumber': instance.seasonNumber,
  'episodeNumber': instance.episodeNumber,
  'status': instance.status,
  'airDate': instance.airDate,
  'expectedDay': instance.expectedDay,
  'daysAhead': instance.daysAhead,
  'estimatedReleaseToImportMinutes': instance.estimatedReleaseToImportMinutes,
};

_TodayArrivalFull _$TodayArrivalFullFromJson(Map<String, dynamic> json) =>
    _TodayArrivalFull(
      subscriptionId: (json['subscriptionId'] as num?)?.toInt() ?? 0,
      mediaTitle: json['mediaTitle'] as String? ?? "",
      mediaKind: json['mediaKind'] as String? ?? "tv",
      seasonNumber: (json['seasonNumber'] as num?)?.toInt() ?? 0,
      episodeNumber: (json['episodeNumber'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? "wanted",
      airDate: json['airDate'] as String?,
      expectedDay: json['expectedDay'] as String?,
      daysAhead: (json['daysAhead'] as num?)?.toInt() ?? 0,
      grabbedAt: json['grabbedAt'] as String?,
      downloadedAt: json['downloadedAt'] as String?,
      infoHash: json['infoHash'] as String?,
      estimatedReleaseToImportMinutes:
          (json['estimatedReleaseToImportMinutes'] as num?)?.toInt(),
      estimatedDownloadToImportMinutes:
          (json['estimatedDownloadToImportMinutes'] as num?)?.toInt(),
      releaseForecast: json['releaseForecast'] as Map<String, dynamic>?,
      nextProbeAt: json['nextProbeAt'] as String?,
    );

Map<String, dynamic> _$TodayArrivalFullToJson(
  _TodayArrivalFull instance,
) => <String, dynamic>{
  'subscriptionId': instance.subscriptionId,
  'mediaTitle': instance.mediaTitle,
  'mediaKind': instance.mediaKind,
  'seasonNumber': instance.seasonNumber,
  'episodeNumber': instance.episodeNumber,
  'status': instance.status,
  'airDate': instance.airDate,
  'expectedDay': instance.expectedDay,
  'daysAhead': instance.daysAhead,
  'grabbedAt': instance.grabbedAt,
  'downloadedAt': instance.downloadedAt,
  'infoHash': instance.infoHash,
  'estimatedReleaseToImportMinutes': instance.estimatedReleaseToImportMinutes,
  'estimatedDownloadToImportMinutes': instance.estimatedDownloadToImportMinutes,
  'releaseForecast': instance.releaseForecast,
  'nextProbeAt': instance.nextProbeAt,
};

_ToolCallInfo _$ToolCallInfoFromJson(Map<String, dynamic> json) =>
    _ToolCallInfo(
      id: json['id'] as String? ?? "",
      name: json['name'] as String? ?? "",
      arguments: json['arguments'],
      rawArguments: json['rawArguments'] as String?,
      parseError: json['parseError'] as String?,
    );

Map<String, dynamic> _$ToolCallInfoToJson(_ToolCallInfo instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'arguments': instance.arguments,
      'rawArguments': instance.rawArguments,
      'parseError': instance.parseError,
    };

_TrackDefaultsView _$TrackDefaultsViewFromJson(Map<String, dynamic> json) =>
    _TrackDefaultsView(
      audioTrack: json['audio_track'] as String?,
      audioReason: json['audio_reason'] as String? ?? "",
      audioNote: json['audio_note'] as String? ?? "",
      subtitleTrack: json['subtitle_track'] as String?,
      subtitleReason: json['subtitle_reason'] as String? ?? "",
      subtitleNote: json['subtitle_note'] as String? ?? "",
    );

Map<String, dynamic> _$TrackDefaultsViewToJson(_TrackDefaultsView instance) =>
    <String, dynamic>{
      'audio_track': instance.audioTrack,
      'audio_reason': instance.audioReason,
      'audio_note': instance.audioNote,
      'subtitle_track': instance.subtitleTrack,
      'subtitle_reason': instance.subtitleReason,
      'subtitle_note': instance.subtitleNote,
    };

_TrackingStateRequest _$TrackingStateRequestFromJson(
  Map<String, dynamic> json,
) => _TrackingStateRequest(state: json['state'] as String? ?? '');

Map<String, dynamic> _$TrackingStateRequestToJson(
  _TrackingStateRequest instance,
) => <String, dynamic>{'state': instance.state};

_TranscriptEntry _$TranscriptEntryFromJson(Map<String, dynamic> json) =>
    _TranscriptEntry(
      messageId: json['messageId'] as String?,
      compactionId: json['compactionId'] as String?,
      handoffId: json['handoffId'] as String?,
      timestamp: json['timestamp'] as String?,
      message: json['message'] == null
          ? null
          : SessionMessage.fromJson(json['message'] as Map<String, dynamic>),
      summary: json['summary'] as String?,
      tokensBefore: (json['tokensBefore'] as num?)?.toInt(),
      tokensAfter: (json['tokensAfter'] as num?)?.toInt(),
      model: json['model'] as String?,
      sourceTitle: json['sourceTitle'] as String?,
    );

Map<String, dynamic> _$TranscriptEntryToJson(_TranscriptEntry instance) =>
    <String, dynamic>{
      'messageId': instance.messageId,
      'compactionId': instance.compactionId,
      'handoffId': instance.handoffId,
      'timestamp': instance.timestamp,
      'message': instance.message,
      'summary': instance.summary,
      'tokensBefore': instance.tokensBefore,
      'tokensAfter': instance.tokensAfter,
      'model': instance.model,
      'sourceTitle': instance.sourceTitle,
    };

_TransferMoveView _$TransferMoveViewFromJson(Map<String, dynamic> json) =>
    _TransferMoveView(
      sourcePath: json['sourcePath'] as String? ?? "",
      targetPath: json['targetPath'] as String? ?? "",
      isDir: json['isDir'] as bool? ?? false,
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
      fileCount: (json['fileCount'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$TransferMoveViewToJson(_TransferMoveView instance) =>
    <String, dynamic>{
      'sourcePath': instance.sourcePath,
      'targetPath': instance.targetPath,
      'isDir': instance.isDir,
      'sizeBytes': instance.sizeBytes,
      'fileCount': instance.fileCount,
    };

_TransferPayload _$TransferPayloadFromJson(Map<String, dynamic> json) =>
    _TransferPayload(
      targetLibraryId: (json['targetLibraryId'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$TransferPayloadToJson(_TransferPayload instance) =>
    <String, dynamic>{'targetLibraryId': instance.targetLibraryId};

_TransferPreviewView _$TransferPreviewViewFromJson(Map<String, dynamic> json) =>
    _TransferPreviewView(
      targetLibraryId: (json['targetLibraryId'] as num?)?.toInt() ?? 0,
      targetLibraryName: json['targetLibraryName'] as String? ?? "",
      targetRoot: json['targetRoot'] as String? ?? "",
      moves:
          (json['moves'] as List<dynamic>?)
              ?.map((e) => TransferMoveView.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      skips:
          (json['skips'] as List<dynamic>?)
              ?.map((e) => TransferSkipView.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      totalBytes: (json['totalBytes'] as num?)?.toInt() ?? 0,
      missingCount: (json['missingCount'] as num?)?.toInt() ?? 0,
      crossDevice: json['crossDevice'] as bool? ?? false,
      blocked:
          (json['blocked'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );

Map<String, dynamic> _$TransferPreviewViewToJson(
  _TransferPreviewView instance,
) => <String, dynamic>{
  'targetLibraryId': instance.targetLibraryId,
  'targetLibraryName': instance.targetLibraryName,
  'targetRoot': instance.targetRoot,
  'moves': instance.moves,
  'skips': instance.skips,
  'totalBytes': instance.totalBytes,
  'missingCount': instance.missingCount,
  'crossDevice': instance.crossDevice,
  'blocked': instance.blocked,
};

_TransferSkipView _$TransferSkipViewFromJson(Map<String, dynamic> json) =>
    _TransferSkipView(
      filePath: json['filePath'] as String? ?? "",
      reason: json['reason'] as String? ?? "",
    );

Map<String, dynamic> _$TransferSkipViewToJson(_TransferSkipView instance) =>
    <String, dynamic>{'filePath': instance.filePath, 'reason': instance.reason};

_TransferStartView _$TransferStartViewFromJson(Map<String, dynamic> json) =>
    _TransferStartView(
      started: json['started'] as bool? ?? false,
      message: json['message'] as String? ?? "",
      jobId: json['jobId'] as String?,
      created: json['created'] as bool? ?? false,
    );

Map<String, dynamic> _$TransferStartViewToJson(_TransferStartView instance) =>
    <String, dynamic>{
      'started': instance.started,
      'message': instance.message,
      'jobId': instance.jobId,
      'created': instance.created,
    };

_TransferStatusView _$TransferStatusViewFromJson(Map<String, dynamic> json) =>
    _TransferStatusView(
      running: json['running'] as bool? ?? false,
      mediaItemId: (json['mediaItemId'] as num?)?.toInt(),
      title: json['title'] as String?,
      targetLibraryId: (json['targetLibraryId'] as num?)?.toInt(),
      processed: (json['processed'] as num?)?.toInt() ?? 0,
      total: (json['total'] as num?)?.toInt() ?? 0,
      finishedAt: json['finishedAt'] as String?,
      targetLibraryName: json['targetLibraryName'] as String?,
      movedPaths:
          (json['movedPaths'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      filesRelocated: (json['filesRelocated'] as num?)?.toInt() ?? 0,
      bytesMoved: (json['bytesMoved'] as num?)?.toInt() ?? 0,
      removedDirs: (json['removedDirs'] as num?)?.toInt() ?? 0,
      subscriptionMoved: json['subscriptionMoved'] as bool? ?? false,
      movedItems: (json['movedItems'] as num?)?.toInt() ?? 0,
      skippedItems: (json['skippedItems'] as num?)?.toInt() ?? 0,
      failedItems: (json['failedItems'] as num?)?.toInt() ?? 0,
      skips:
          (json['skips'] as List<dynamic>?)?.map((e) => e as String).toList() ??
          const [],
      errors:
          (json['errors'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );

Map<String, dynamic> _$TransferStatusViewToJson(_TransferStatusView instance) =>
    <String, dynamic>{
      'running': instance.running,
      'mediaItemId': instance.mediaItemId,
      'title': instance.title,
      'targetLibraryId': instance.targetLibraryId,
      'processed': instance.processed,
      'total': instance.total,
      'finishedAt': instance.finishedAt,
      'targetLibraryName': instance.targetLibraryName,
      'movedPaths': instance.movedPaths,
      'filesRelocated': instance.filesRelocated,
      'bytesMoved': instance.bytesMoved,
      'removedDirs': instance.removedDirs,
      'subscriptionMoved': instance.subscriptionMoved,
      'movedItems': instance.movedItems,
      'skippedItems': instance.skippedItems,
      'failedItems': instance.failedItems,
      'skips': instance.skips,
      'errors': instance.errors,
    };

_TrickplayView _$TrickplayViewFromJson(Map<String, dynamic> json) =>
    _TrickplayView(
      ready: json['ready'] as bool? ?? false,
      intervalMs: (json['interval_ms'] as num?)?.toInt() ?? 0,
      tileWidth: (json['tile_width'] as num?)?.toInt() ?? 0,
      tileHeight: (json['tile_height'] as num?)?.toInt() ?? 0,
      columns: (json['columns'] as num?)?.toInt() ?? 0,
      rows: (json['rows'] as num?)?.toInt() ?? 0,
      count: (json['count'] as num?)?.toInt() ?? 0,
      sheets:
          (json['sheets'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );

Map<String, dynamic> _$TrickplayViewToJson(_TrickplayView instance) =>
    <String, dynamic>{
      'ready': instance.ready,
      'interval_ms': instance.intervalMs,
      'tile_width': instance.tileWidth,
      'tile_height': instance.tileHeight,
      'columns': instance.columns,
      'rows': instance.rows,
      'count': instance.count,
      'sheets': instance.sheets,
    };

_UiPreferencesSetting _$UiPreferencesSettingFromJson(
  Map<String, dynamic> json,
) => _UiPreferencesSetting(
  language: json['language'] as String? ?? "",
  theme: json['theme'] as String? ?? "",
  themeDesktop: json['theme_desktop'] as String?,
  themeMobile: json['theme_mobile'] as String?,
  sidebar: json['sidebar'] == null
      ? const SidebarUiPrefs()
      : SidebarUiPrefs.fromJson(json['sidebar'] as Map<String, dynamic>),
  scrim: json['scrim'] == null
      ? const ScrimUiPrefs()
      : ScrimUiPrefs.fromJson(json['scrim'] as Map<String, dynamic>),
  nav: json['nav'] == null
      ? const NavUiPrefs()
      : NavUiPrefs.fromJson(json['nav'] as Map<String, dynamic>),
  home: json['home'] == null
      ? const HomeUiPrefs()
      : HomeUiPrefs.fromJson(json['home'] as Map<String, dynamic>),
  posterBadges: json['poster_badges'] == null
      ? const PosterBadgePrefs()
      : PosterBadgePrefs.fromJson(
          json['poster_badges'] as Map<String, dynamic>,
        ),
);

Map<String, dynamic> _$UiPreferencesSettingToJson(
  _UiPreferencesSetting instance,
) => <String, dynamic>{
  'language': instance.language,
  'theme': instance.theme,
  'theme_desktop': instance.themeDesktop,
  'theme_mobile': instance.themeMobile,
  'sidebar': instance.sidebar,
  'scrim': instance.scrim,
  'nav': instance.nav,
  'home': instance.home,
  'poster_badges': instance.posterBadges,
};

_UnidentifiedCandidateView _$UnidentifiedCandidateViewFromJson(
  Map<String, dynamic> json,
) => _UnidentifiedCandidateView(
  tmdbId: (json['tmdbId'] as num?)?.toInt() ?? 0,
  title: json['title'] as String? ?? "",
  year: (json['year'] as num?)?.toInt(),
  episodeCount: (json['episodeCount'] as num?)?.toInt(),
  reasons:
      (json['reasons'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
);

Map<String, dynamic> _$UnidentifiedCandidateViewToJson(
  _UnidentifiedCandidateView instance,
) => <String, dynamic>{
  'tmdbId': instance.tmdbId,
  'title': instance.title,
  'year': instance.year,
  'episodeCount': instance.episodeCount,
  'reasons': instance.reasons,
};

_UpNextItem _$UpNextItemFromJson(Map<String, dynamic> json) => _UpNextItem(
  mediaItemId: (json['mediaItemId'] as num?)?.toInt() ?? 0,
  libraryId: (json['libraryId'] as num?)?.toInt() ?? 0,
  kind: json['kind'] as String? ?? "movie",
  title: json['title'] as String? ?? '',
  year: (json['year'] as num?)?.toInt(),
  posterUrl: json['posterUrl'] as String?,
  posterAspect: (json['posterAspect'] as num?)?.toDouble() ?? 0.0,
  backdropUrl: json['backdropUrl'] as String?,
  episodeStillUrl: json['episodeStillUrl'] as String?,
  seasonNumber: (json['seasonNumber'] as num?)?.toInt() ?? 0,
  episodeNumber: (json['episodeNumber'] as num?)?.toInt() ?? 0,
  episodeTitle: json['episodeTitle'] as String?,
  unwatchedAheadCount: (json['unwatchedAheadCount'] as num?)?.toInt() ?? 0,
  positionMs: (json['positionMs'] as num?)?.toInt() ?? 0,
  durationMs: (json['durationMs'] as num?)?.toInt() ?? 0,
  progressPercent: (json['progressPercent'] as num?)?.toInt() ?? 0,
  advanced: json['advanced'] as bool? ?? false,
  lastPlayedAt: json['lastPlayedAt'] as String?,
);

Map<String, dynamic> _$UpNextItemToJson(_UpNextItem instance) =>
    <String, dynamic>{
      'mediaItemId': instance.mediaItemId,
      'libraryId': instance.libraryId,
      'kind': instance.kind,
      'title': instance.title,
      'year': instance.year,
      'posterUrl': instance.posterUrl,
      'posterAspect': instance.posterAspect,
      'backdropUrl': instance.backdropUrl,
      'episodeStillUrl': instance.episodeStillUrl,
      'seasonNumber': instance.seasonNumber,
      'episodeNumber': instance.episodeNumber,
      'episodeTitle': instance.episodeTitle,
      'unwatchedAheadCount': instance.unwatchedAheadCount,
      'positionMs': instance.positionMs,
      'durationMs': instance.durationMs,
      'progressPercent': instance.progressPercent,
      'advanced': instance.advanced,
      'lastPlayedAt': instance.lastPlayedAt,
    };

_UpNextItemView _$UpNextItemViewFromJson(
  Map<String, dynamic> json,
) => _UpNextItemView(
  mediaItemId: (json['media_item_id'] as num?)?.toInt() ?? 0,
  libraryId: (json['library_id'] as num?)?.toInt() ?? 0,
  kind: json['kind'] as String? ?? "",
  title: json['title'] as String? ?? "",
  year: (json['year'] as num?)?.toInt(),
  posterUrl: json['poster_url'] as String?,
  posterAspect: (json['poster_aspect'] as num?)?.toDouble() ?? 0.0,
  backdropUrl: json['backdrop_url'] as String?,
  episodeStillUrl: json['episode_still_url'] as String?,
  episodeStillOriginalUrl: json['episode_still_original_url'] as String?,
  logoUrl: json['logo_url'] as String?,
  overview: json['overview'] as String?,
  genres: (json['genres'] as List<dynamic>?)?.map((e) => e as String).toList(),
  seasonNumber: (json['season_number'] as num?)?.toInt() ?? 0,
  episodeNumber: (json['episode_number'] as num?)?.toInt() ?? 0,
  episodeTitle: json['episode_title'] as String?,
  unwatchedAheadCount: (json['unwatched_ahead_count'] as num?)?.toInt() ?? 0,
  positionMs: (json['position_ms'] as num?)?.toInt() ?? 0,
  durationMs: (json['duration_ms'] as num?)?.toInt(),
  progressPercent: (json['progress_percent'] as num?)?.toInt(),
  advanced: json['advanced'] as bool? ?? false,
  lastPlayedAt: json['last_played_at'] as String? ?? "",
);

Map<String, dynamic> _$UpNextItemViewToJson(_UpNextItemView instance) =>
    <String, dynamic>{
      'media_item_id': instance.mediaItemId,
      'library_id': instance.libraryId,
      'kind': instance.kind,
      'title': instance.title,
      'year': instance.year,
      'poster_url': instance.posterUrl,
      'poster_aspect': instance.posterAspect,
      'backdrop_url': instance.backdropUrl,
      'episode_still_url': instance.episodeStillUrl,
      'episode_still_original_url': instance.episodeStillOriginalUrl,
      'logo_url': instance.logoUrl,
      'overview': instance.overview,
      'genres': instance.genres,
      'season_number': instance.seasonNumber,
      'episode_number': instance.episodeNumber,
      'episode_title': instance.episodeTitle,
      'unwatched_ahead_count': instance.unwatchedAheadCount,
      'position_ms': instance.positionMs,
      'duration_ms': instance.durationMs,
      'progress_percent': instance.progressPercent,
      'advanced': instance.advanced,
      'last_played_at': instance.lastPlayedAt,
    };

_UpNextView _$UpNextViewFromJson(Map<String, dynamic> json) => _UpNextView(
  items:
      (json['items'] as List<dynamic>?)
          ?.map((e) => UpNextItemView.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
);

Map<String, dynamic> _$UpNextViewToJson(_UpNextView instance) =>
    <String, dynamic>{'items': instance.items};

_UpdateCheck _$UpdateCheckFromJson(Map<String, dynamic> json) => _UpdateCheck(
  currentVersion: json['currentVersion'] as String? ?? "",
  latestVersion: json['latestVersion'] as String? ?? "",
  updateAvailable: json['updateAvailable'] as bool? ?? false,
  compatible: json['compatible'] as bool? ?? true,
  requiresRuntime: (json['requiresRuntime'] as num?)?.toInt() ?? 0,
  changelog: json['changelog'] as String? ?? "",
  publishedAt: json['publishedAt'] as String? ?? "",
  latestKnownBad: json['latestKnownBad'] as bool? ?? false,
);

Map<String, dynamic> _$UpdateCheckToJson(_UpdateCheck instance) =>
    <String, dynamic>{
      'currentVersion': instance.currentVersion,
      'latestVersion': instance.latestVersion,
      'updateAvailable': instance.updateAvailable,
      'compatible': instance.compatible,
      'requiresRuntime': instance.requiresRuntime,
      'changelog': instance.changelog,
      'publishedAt': instance.publishedAt,
      'latestKnownBad': instance.latestKnownBad,
    };

_UpdateProfileRequest _$UpdateProfileRequestFromJson(
  Map<String, dynamic> json,
) => _UpdateProfileRequest(nickname: json['nickname'] as String? ?? '');

Map<String, dynamic> _$UpdateProfileRequestToJson(
  _UpdateProfileRequest instance,
) => <String, dynamic>{'nickname': instance.nickname};

_UpdateProgress _$UpdateProgressFromJson(Map<String, dynamic> json) =>
    _UpdateProgress(
      phase: json['phase'] as String? ?? "",
      detail: json['detail'] as String? ?? "",
      percent: (json['percent'] as num?)?.toDouble(),
      error: json['error'] as String?,
      targetVersion: json['targetVersion'] as String?,
    );

Map<String, dynamic> _$UpdateProgressToJson(_UpdateProgress instance) =>
    <String, dynamic>{
      'phase': instance.phase,
      'detail': instance.detail,
      'percent': instance.percent,
      'error': instance.error,
      'targetVersion': instance.targetVersion,
    };

_UpdateStatus _$UpdateStatusFromJson(Map<String, dynamic> json) =>
    _UpdateStatus(
      currentVersion: json['currentVersion'] as String? ?? "",
      codeSource: json['codeSource'] as String? ?? "",
      overlayVersion: json['overlayVersion'] as String?,
      runtimeVersion: (json['runtimeVersion'] as num?)?.toInt(),
      canUpdate: json['canUpdate'] as bool? ?? false,
      hasPrevious: json['hasPrevious'] as bool? ?? false,
      previousVersion: json['previousVersion'] as String?,
      badVersions:
          (json['badVersions'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      modelTag: json['modelTag'] as String?,
      inactiveOverlayVersion: json['inactiveOverlayVersion'] as String?,
      inactiveOverlayReason: json['inactiveOverlayReason'] as String?,
      lastAbnormalExit: json['lastAbnormalExit'] == null
          ? null
          : LastAbnormalExit.fromJson(
              json['lastAbnormalExit'] as Map<String, dynamic>,
            ),
    );

Map<String, dynamic> _$UpdateStatusToJson(_UpdateStatus instance) =>
    <String, dynamic>{
      'currentVersion': instance.currentVersion,
      'codeSource': instance.codeSource,
      'overlayVersion': instance.overlayVersion,
      'runtimeVersion': instance.runtimeVersion,
      'canUpdate': instance.canUpdate,
      'hasPrevious': instance.hasPrevious,
      'previousVersion': instance.previousVersion,
      'badVersions': instance.badVersions,
      'modelTag': instance.modelTag,
      'inactiveOverlayVersion': instance.inactiveOverlayVersion,
      'inactiveOverlayReason': instance.inactiveOverlayReason,
      'lastAbnormalExit': instance.lastAbnormalExit,
    };

_UpgradeRunPayload _$UpgradeRunPayloadFromJson(Map<String, dynamic> json) =>
    _UpgradeRunPayload(ruleSetId: (json['ruleSetId'] as num?)?.toInt());

Map<String, dynamic> _$UpgradeRunPayloadToJson(_UpgradeRunPayload instance) =>
    <String, dynamic>{'ruleSetId': instance.ruleSetId};

_UpgradeRunView _$UpgradeRunViewFromJson(Map<String, dynamic> json) =>
    _UpgradeRunView(
      targetLabel: json['targetLabel'] as String? ?? "",
      ruleSetId: (json['ruleSetId'] as num?)?.toInt(),
      summary: json['summary'] as String? ?? "",
      counts:
          (json['counts'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, (e as num).toInt()),
          ) ??
          const {},
    );

Map<String, dynamic> _$UpgradeRunViewToJson(_UpgradeRunView instance) =>
    <String, dynamic>{
      'targetLabel': instance.targetLabel,
      'ruleSetId': instance.ruleSetId,
      'summary': instance.summary,
      'counts': instance.counts,
    };

_VideoPlanView _$VideoPlanViewFromJson(Map<String, dynamic> json) =>
    _VideoPlanView(
      action: json['action'] as String? ?? "",
      codec: json['codec'] as String?,
      height: (json['height'] as num?)?.toInt(),
      toneMap: json['tone_map'] as bool? ?? false,
      bitrateCapBps: (json['bitrate_cap_bps'] as num?)?.toInt(),
      burnSubtitle: json['burn_subtitle'] as String?,
    );

Map<String, dynamic> _$VideoPlanViewToJson(_VideoPlanView instance) =>
    <String, dynamic>{
      'action': instance.action,
      'codec': instance.codec,
      'height': instance.height,
      'tone_map': instance.toneMap,
      'bitrate_cap_bps': instance.bitrateCapBps,
      'burn_subtitle': instance.burnSubtitle,
    };

_VideoSupportIn _$VideoSupportInFromJson(Map<String, dynamic> json) =>
    _VideoSupportIn(
      codec: json['codec'] as String? ?? '',
      maxHeight: (json['max_height'] as num?)?.toInt(),
      smooth: json['smooth'] as bool?,
      powerEfficient: json['power_efficient'] as bool?,
    );

Map<String, dynamic> _$VideoSupportInToJson(_VideoSupportIn instance) =>
    <String, dynamic>{
      'codec': instance.codec,
      'max_height': instance.maxHeight,
      'smooth': instance.smooth,
      'power_efficient': instance.powerEfficient,
    };

_WantedUpgradeView _$WantedUpgradeViewFromJson(Map<String, dynamic> json) =>
    _WantedUpgradeView(
      active: json['active'] as bool? ?? false,
      currentLabel: json['current_label'] as String? ?? "",
      targetLabel: json['target_label'] as String? ?? "",
      searchAttempts: (json['search_attempts'] as num?)?.toInt() ?? 0,
      indeterminate: json['indeterminate'] as bool? ?? false,
    );

Map<String, dynamic> _$WantedUpgradeViewToJson(_WantedUpgradeView instance) =>
    <String, dynamic>{
      'active': instance.active,
      'current_label': instance.currentLabel,
      'target_label': instance.targetLabel,
      'search_attempts': instance.searchAttempts,
      'indeterminate': instance.indeterminate,
    };

_WantedView _$WantedViewFromJson(Map<String, dynamic> json) => _WantedView(
  id: (json['id'] as num?)?.toInt() ?? 0,
  seasonNumber: (json['season_number'] as num?)?.toInt() ?? 0,
  episodeNumber: (json['episode_number'] as num?)?.toInt() ?? 0,
  status: json['status'] as String? ?? "",
  airDate: json['air_date'] as String?,
  priority: (json['priority'] as num?)?.toInt() ?? 0,
  infoHash: json['info_hash'] as String?,
  nextSearchAt: json['next_search_at'] as String?,
  searchAttempts: (json['search_attempts'] as num?)?.toInt() ?? 0,
  lastSearchAt: json['last_search_at'] as String?,
  releaseForecast: json['release_forecast'] as Map<String, dynamic>?,
  resourceTiming: json['resource_timing'] == null
      ? null
      : ResourceTimingView.fromJson(
          json['resource_timing'] as Map<String, dynamic>,
        ),
  grabbedAt: json['grabbed_at'] as String?,
  downloadedAt: json['downloaded_at'] as String?,
  importedAt: json['imported_at'] as String?,
  lastRejectReason: json['last_reject_reason'] as String?,
  grabTitle: json['grab_title'] as String?,
  upgrade: json['upgrade'] == null
      ? null
      : WantedUpgradeView.fromJson(json['upgrade'] as Map<String, dynamic>),
  selectionState: json['selection_state'] as Map<String, dynamic>?,
  selectionVersion: (json['selection_version'] as num?)?.toInt() ?? 0,
  provisional: json['provisional'] as bool?,
);

Map<String, dynamic> _$WantedViewToJson(_WantedView instance) =>
    <String, dynamic>{
      'id': instance.id,
      'season_number': instance.seasonNumber,
      'episode_number': instance.episodeNumber,
      'status': instance.status,
      'air_date': instance.airDate,
      'priority': instance.priority,
      'info_hash': instance.infoHash,
      'next_search_at': instance.nextSearchAt,
      'search_attempts': instance.searchAttempts,
      'last_search_at': instance.lastSearchAt,
      'release_forecast': instance.releaseForecast,
      'resource_timing': instance.resourceTiming,
      'grabbed_at': instance.grabbedAt,
      'downloaded_at': instance.downloadedAt,
      'imported_at': instance.importedAt,
      'last_reject_reason': instance.lastRejectReason,
      'grab_title': instance.grabTitle,
      'upgrade': instance.upgrade,
      'selection_state': instance.selectionState,
      'selection_version': instance.selectionVersion,
      'provisional': instance.provisional,
    };

_WebPortPayload _$WebPortPayloadFromJson(Map<String, dynamic> json) =>
    _WebPortPayload(port: (json['port'] as num?)?.toInt());

Map<String, dynamic> _$WebPortPayloadToJson(_WebPortPayload instance) =>
    <String, dynamic>{'port': instance.port};

_WebSearchConfig _$WebSearchConfigFromJson(Map<String, dynamic> json) =>
    _WebSearchConfig(
      provider: json['provider'] as String?,
      configured: json['configured'] as bool? ?? false,
      keyHint: json['key_hint'] as String? ?? "",
      providers:
          (json['providers'] as List<dynamic>?)
              ?.map(
                (e) =>
                    WebSearchProviderOption.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const [],
    );

Map<String, dynamic> _$WebSearchConfigToJson(_WebSearchConfig instance) =>
    <String, dynamic>{
      'provider': instance.provider,
      'configured': instance.configured,
      'key_hint': instance.keyHint,
      'providers': instance.providers,
    };

_WebSearchProviderOption _$WebSearchProviderOptionFromJson(
  Map<String, dynamic> json,
) => _WebSearchProviderOption(
  id: json['id'] as String? ?? "",
  label: json['label'] as String? ?? "",
  signupUrl: json['signup_url'] as String?,
);

Map<String, dynamic> _$WebSearchProviderOptionToJson(
  _WebSearchProviderOption instance,
) => <String, dynamic>{
  'id': instance.id,
  'label': instance.label,
  'signup_url': instance.signupUrl,
};

_WebSearchSavePayload _$WebSearchSavePayloadFromJson(
  Map<String, dynamic> json,
) => _WebSearchSavePayload(
  provider: json['provider'] as String? ?? '',
  apiKey: json['api_key'] as String?,
);

Map<String, dynamic> _$WebSearchSavePayloadToJson(
  _WebSearchSavePayload instance,
) => <String, dynamic>{
  'provider': instance.provider,
  'api_key': instance.apiKey,
};

_WebSearchTestPayload _$WebSearchTestPayloadFromJson(
  Map<String, dynamic> json,
) => _WebSearchTestPayload(
  provider: json['provider'] as String?,
  apiKey: json['api_key'] as String?,
);

Map<String, dynamic> _$WebSearchTestPayloadToJson(
  _WebSearchTestPayload instance,
) => <String, dynamic>{
  'provider': instance.provider,
  'api_key': instance.apiKey,
};

_WebSearchTestResult _$WebSearchTestResultFromJson(Map<String, dynamic> json) =>
    _WebSearchTestResult(
      ok: json['ok'] as bool? ?? false,
      message: json['message'] as String? ?? "",
      sampleTitle: json['sample_title'] as String?,
    );

Map<String, dynamic> _$WebSearchTestResultToJson(
  _WebSearchTestResult instance,
) => <String, dynamic>{
  'ok': instance.ok,
  'message': instance.message,
  'sample_title': instance.sampleTitle,
};

_WebhookConfigPayload _$WebhookConfigPayloadFromJson(
  Map<String, dynamic> json,
) => _WebhookConfigPayload(
  enabled: json['enabled'] as bool? ?? false,
  endpoints:
      (json['endpoints'] as List<dynamic>?)
          ?.map(
            (e) => WebhookEndpointPayload.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const [],
);

Map<String, dynamic> _$WebhookConfigPayloadToJson(
  _WebhookConfigPayload instance,
) => <String, dynamic>{
  'enabled': instance.enabled,
  'endpoints': instance.endpoints,
};

_WebhookConfigView _$WebhookConfigViewFromJson(Map<String, dynamic> json) =>
    _WebhookConfigView(
      enabled: json['enabled'] as bool? ?? false,
      endpoints:
          (json['endpoints'] as List<dynamic>?)
              ?.map(
                (e) => WebhookEndpointView.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const [],
    );

Map<String, dynamic> _$WebhookConfigViewToJson(_WebhookConfigView instance) =>
    <String, dynamic>{
      'enabled': instance.enabled,
      'endpoints': instance.endpoints,
    };

_WebhookDeliveryView _$WebhookDeliveryViewFromJson(Map<String, dynamic> json) =>
    _WebhookDeliveryView(
      eventId: json['event_id'] as String? ?? "",
      event: json['event'] as String? ?? "",
      ok: json['ok'] as bool? ?? false,
      statusCode: (json['status_code'] as num?)?.toInt(),
      durationMs: (json['duration_ms'] as num?)?.toInt() ?? 0,
      attempts: (json['attempts'] as num?)?.toInt() ?? 0,
      error: json['error'] as String? ?? "",
      at: json['at'] as String? ?? "",
    );

Map<String, dynamic> _$WebhookDeliveryViewToJson(
  _WebhookDeliveryView instance,
) => <String, dynamic>{
  'event_id': instance.eventId,
  'event': instance.event,
  'ok': instance.ok,
  'status_code': instance.statusCode,
  'duration_ms': instance.durationMs,
  'attempts': instance.attempts,
  'error': instance.error,
  'at': instance.at,
};

_WebhookEndpointPayload _$WebhookEndpointPayloadFromJson(
  Map<String, dynamic> json,
) => _WebhookEndpointPayload(
  id: json['id'] as String? ?? "",
  name: json['name'] as String? ?? "",
  url: json['url'] as String? ?? "",
  format: json['format'] as String? ?? "movieclaw",
  enabled: json['enabled'] as bool? ?? true,
  events:
      (json['events'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  template: json['template'] as String? ?? "",
  headers:
      (json['headers'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ) ??
      const {},
  egressScope: json['egress_scope'] as String? ?? "lan",
);

Map<String, dynamic> _$WebhookEndpointPayloadToJson(
  _WebhookEndpointPayload instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'url': instance.url,
  'format': instance.format,
  'enabled': instance.enabled,
  'events': instance.events,
  'template': instance.template,
  'headers': instance.headers,
  'egress_scope': instance.egressScope,
};

_WebhookEndpointView _$WebhookEndpointViewFromJson(Map<String, dynamic> json) =>
    _WebhookEndpointView(
      id: json['id'] as String? ?? "",
      name: json['name'] as String? ?? "",
      url: json['url'] as String? ?? "",
      format: json['format'] as String? ?? "",
      enabled: json['enabled'] as bool? ?? false,
      events:
          (json['events'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      template: json['template'] as String? ?? "",
      headers:
          (json['headers'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, e as String),
          ) ??
          const {},
      egressScope: json['egress_scope'] as String? ?? "lan",
      secretMasked: json['secret_masked'] as String? ?? "",
      lastDelivery: json['last_delivery'] == null
          ? null
          : WebhookDeliveryView.fromJson(
              json['last_delivery'] as Map<String, dynamic>,
            ),
    );

Map<String, dynamic> _$WebhookEndpointViewToJson(
  _WebhookEndpointView instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'url': instance.url,
  'format': instance.format,
  'enabled': instance.enabled,
  'events': instance.events,
  'template': instance.template,
  'headers': instance.headers,
  'egress_scope': instance.egressScope,
  'secret_masked': instance.secretMasked,
  'last_delivery': instance.lastDelivery,
};
