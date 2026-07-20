import 'dart:io';

import 'package:dio/dio.dart' as dio;
import 'package:easy_localization/easy_localization.dart'
    hide StringTranslateExtension;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../../app/data/repo/media_repository.dart';
import '../../../app/data/network/backend_api_error.dart';
import '../../../app/services/notification_service.dart';
import '../../playlists/controller/playlists_controller.dart';
import '../../playlists/data/playlist_store.dart';
import '../../playlists/domain/playlist.dart';

class DownloadTaskService extends GetxService {
  final MediaRepository _repo = Get.find<MediaRepository>();
  final GetStorage _storage = Get.find<GetStorage>();
  PlaylistStore? get _playlistStore =>
      Get.isRegistered<PlaylistStore>() ? Get.find<PlaylistStore>() : null;

  final RxBool isDownloading = false.obs;
  final RxDouble downloadProgress = (-1.0).obs;
  final RxString downloadStatus = tr('downloads.status_preparing').obs;

  Future<bool> _canDownloadWithCurrentDataPolicy() async {
    final usage = (_storage.read('dataUsage') ?? 'all').toString();
    if (usage != 'wifi_only') return true;

    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        includeLinkLocal: false,
      );

      final hasWifi = interfaces.any((iface) {
        final name = iface.name.toLowerCase();
        return name.contains('wlan') ||
            name.contains('wifi') ||
            name == 'en0' ||
            name == 'en1' ||
            name.startsWith('eth');
      });

      if (hasWifi) return true;

      Get.snackbar(
        tr('imports.wifi_only_title'),
        tr('imports.wifi_only_body'),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange,
      );
      if (Get.isRegistered<NotificationService>()) {
        await Get.find<NotificationService>().showImportFailure(
          tr('downloads.wifi_waiting'),
        );
      }
      return false;
    } catch (_) {
      return true;
    }
  }

  Future<bool> downloadFromUrl({
    String? mediaId,
    required String url,
    required String kind,
    String? quality,
    List<String>? selectedPlaylistUrls,
  }) async {
    final normalizedUrl = url.trim();
    if (normalizedUrl.isEmpty) {
      Get.snackbar(
        'Imports',
        tr('imports.empty_url'),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
      );
      return false;
    }

    if (isDownloading.value) {
      Get.snackbar(
        'Imports',
        tr('imports.downloading_in_progress'),
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }

    final allowedByPolicy = await _canDownloadWithCurrentDataPolicy();
    if (!allowedByPolicy) return false;

    final format = kind == 'video' ? 'mp4' : 'mp3';
    final resolvedQuality =
        (quality ?? _storage.read('downloadQuality') ?? 'high')
            .toString()
            .trim()
            .toLowerCase();

    try {
      isDownloading.value = true;
      downloadProgress.value = -1;
      downloadStatus.value = tr('downloads.status_preparing');

      if (_isLikelyYoutubePlaylistUrl(normalizedUrl)) {
        return await _downloadPlaylistFromUrl(
          url: normalizedUrl,
          kind: kind,
          format: format,
          quality: resolvedQuality,
          selectedUrls: selectedPlaylistUrls,
        );
      }

      final ok = await _repo
          .requestAndFetchMedia(
            mediaId: mediaId?.trim().isEmpty == true ? null : mediaId,
            url: normalizedUrl,
            kind: kind,
            format: format,
            quality: resolvedQuality,
            onProgress: (received, total) {
              if (total > 0) {
                downloadProgress.value = received / total;
              } else {
                downloadProgress.value = -1;
              }
              downloadStatus.value = tr('downloads.status_downloading');
            },
          )
          .timeout(const Duration(minutes: 5), onTimeout: () => false);

      if (ok) {
        downloadStatus.value = tr('downloads.status_saving');
        Get.snackbar(
          'Imports',
          tr('imports.completed'),
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
        );
        if (Get.isRegistered<NotificationService>()) {
          await Get.find<NotificationService>().showImportSuccess();
        }
      } else {
        Get.snackbar(
          'Imports',
          tr('imports.failed'),
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange,
        );
        if (Get.isRegistered<NotificationService>()) {
          await Get.find<NotificationService>().showImportFailure(
            tr('downloads.web_slow'),
          );
        }
      }
      return ok;
    } catch (e) {
      String msg = 'Error inesperado';
      var title = 'Imports';
      Color color = Colors.red;
      IconData? icon;
      _BackendErrorPresentation? backendPresentation;
      var shouldShowLegacyFailureNotification = true;

      if (e is BackendApiException) {
        final presentation = _backendErrorPresentation(e);
        backendPresentation = presentation;
        shouldShowLegacyFailureNotification = e.normalizedCode.isEmpty;
        title = presentation.title;
        msg = presentation.message;
        color = presentation.color;
        icon = presentation.icon;
      } else if (e is dio.DioException) {
        switch (e.type) {
          case dio.DioExceptionType.receiveTimeout:
            msg = tr('imports.receive_timeout');
            break;
          case dio.DioExceptionType.connectionTimeout:
          case dio.DioExceptionType.sendTimeout:
            msg = tr('imports.send_timeout');
            break;
          default:
            msg = e.message ?? tr('imports.network_error');
        }
      } else {
        msg = e.toString();
      }

      Get.snackbar(
        title,
        msg,
        snackPosition: SnackPosition.BOTTOM,
        titleText: backendPresentation != null ? const SizedBox.shrink() : null,
        messageText: backendPresentation != null
            ? _BackendErrorSnackContent(presentation: backendPresentation)
            : null,
        backgroundColor: backendPresentation != null
            ? Colors.transparent
            : color,
        boxShadows: backendPresentation != null ? const [] : null,
        borderRadius: backendPresentation != null ? 0 : null,
        padding: backendPresentation != null
            ? EdgeInsets.zero
            : const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 16),
        duration: backendPresentation != null
            ? const Duration(seconds: 6)
            : const Duration(seconds: 4),
        isDismissible: true,
        dismissDirection: DismissDirection.horizontal,
        icon: backendPresentation == null && icon != null
            ? Icon(icon, color: Colors.white)
            : null,
        shouldIconPulse: false,
        colorText: backendPresentation != null ? null : Colors.white,
      );
      if (shouldShowLegacyFailureNotification &&
          Get.isRegistered<NotificationService>()) {
        await Get.find<NotificationService>().showImportFailure(msg);
      }

      debugPrint('downloadFromUrl error: $e');
      return false;
    } finally {
      isDownloading.value = false;
      downloadProgress.value = -1;
    }
  }

  Future<bool> _downloadPlaylistFromUrl({
    required String url,
    required String kind,
    required String format,
    required String quality,
    List<String>? selectedUrls,
  }) async {
    final result = await _repo
        .importPlaylistFromUrl(
          url: url,
          kind: kind,
          format: format,
          quality: quality,
          maxItems: selectedUrls?.isNotEmpty == true ? 100 : 50,
          selectedUrls: selectedUrls,
          onItemProgress: (current, total, title) {
            downloadProgress.value = total > 0 ? current / total : -1;
            downloadStatus.value = tr(
              'downloads.status_importing_playlist_item',
              args: [current.toString(), total.toString()],
            );
          },
          onFileProgress: (received, total) {
            if (total <= 0) return;
            downloadStatus.value = tr('downloads.status_downloading');
          },
        )
        .timeout(const Duration(minutes: 50));

    if (result == null || result.itemIds.isEmpty) {
      Get.snackbar(
        tr('imports.playlist_title'),
        tr('imports.playlist_failed'),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange,
      );
      return false;
    }

    final store = _playlistStore;
    if (store != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final itemAddedAt = <String, int>{
        for (final id in result.itemIds) id: now,
      };
      await store.upsert(
        Playlist(
          id: result.playlistId,
          name: result.name,
          itemIds: result.itemIds,
          createdAt: now,
          updatedAt: now,
          itemAddedAt: itemAddedAt,
          coverUrl: result.coverUrl,
        ),
      );
      if (Get.isRegistered<PlaylistsController>()) {
        await Get.find<PlaylistsController>().load();
      }
    }

    downloadStatus.value = tr('downloads.status_saving');
    Get.snackbar(
      tr('imports.playlist_title'),
      tr(
        'imports.playlist_completed',
        args: [
          result.imported.toString(),
          result.total.toString(),
          result.failed.toString(),
        ],
      ),
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.green,
    );
    if (Get.isRegistered<NotificationService>()) {
      await Get.find<NotificationService>().showImportSuccess();
    }
    return true;
  }

  bool _isLikelyYoutubePlaylistUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    final host = uri.host.toLowerCase();
    if (!host.contains('youtube.com') && host != 'youtu.be') return false;
    final list = uri.queryParameters['list']?.trim() ?? '';
    if (list.isEmpty) return false;
    return list.length > 8;
  }

  _BackendErrorPresentation _backendErrorPresentation(
    BackendApiException error,
  ) {
    final code = error.normalizedCode;
    final title = error.localizedTitle(
      fallback: tr('notifications.imports.failure_title'),
    );
    final message = error.localizedMessage();

    if (code == 'MEDIA_COOKIES_REQUIRED') {
      return _BackendErrorPresentation(
        title: title,
        message: message,
        color: Colors.deepOrange,
        icon: Icons.cookie_outlined,
        code: code,
        retryable: error.retryable,
        retryAfterSeconds: error.retryAfterSeconds,
      );
    }

    if (code == 'MEDIA_PROTECTED_CONTENT') {
      return _BackendErrorPresentation(
        title: title,
        message: message,
        color: Colors.red.shade700,
        icon: Icons.lock_outline,
        code: code,
        retryable: error.retryable,
        retryAfterSeconds: error.retryAfterSeconds,
      );
    }

    if (code == 'MEDIA_INVALID_URL' ||
        code == 'VALIDATION_ERROR' ||
        code == 'MEDIA_FORMAT_UNAVAILABLE' ||
        code == 'KARAOKE_UNSUPPORTED_AUDIO_FORMAT' ||
        code == 'KARAOKE_AUDIO_EXTENSION_MISMATCH' ||
        code == 'KARAOKE_INVALID_AUDIO_BYTES') {
      return _BackendErrorPresentation(
        title: title,
        message: message,
        color: Colors.red.shade600,
        icon: Icons.error_outline,
        code: code,
        retryable: error.retryable,
        retryAfterSeconds: error.retryAfterSeconds,
      );
    }

    if (error.retryable ||
        code == 'MEDIA_DOWNLOAD_TIMEOUT' ||
        code == 'KARAOKE_BACKEND_BUSY' ||
        code == 'KARAOKE_PROCESS_TIMEOUT' ||
        code == 'KARAOKE_OUTPUT_NOT_READY') {
      return _BackendErrorPresentation(
        title: title,
        message: message,
        color: Colors.orange.shade800,
        icon: Icons.schedule_outlined,
        code: code,
        retryable: error.retryable,
        retryAfterSeconds: error.retryAfterSeconds,
      );
    }

    if (code == 'MEDIA_VARIANT_EXPIRED' ||
        code == 'MEDIA_FILE_NOT_FOUND' ||
        code == 'KARAOKE_SESSION_EXPIRED' ||
        code == 'KARAOKE_OUTPUT_EXPIRED') {
      return _BackendErrorPresentation(
        title: title,
        message: message,
        color: Colors.orange.shade700,
        icon: Icons.hourglass_empty_outlined,
        code: code,
        retryable: error.retryable,
        retryAfterSeconds: error.retryAfterSeconds,
      );
    }

    return _BackendErrorPresentation(
      title: title,
      message: message,
      color: Colors.red,
      icon: Icons.warning_amber_outlined,
      code: code,
      retryable: error.retryable,
      retryAfterSeconds: error.retryAfterSeconds,
    );
  }
}

class _BackendErrorPresentation {
  const _BackendErrorPresentation({
    required this.title,
    required this.message,
    required this.color,
    required this.icon,
    required this.code,
    required this.retryable,
    this.retryAfterSeconds,
  });

  final String title;
  final String message;
  final Color color;
  final IconData icon;
  final String code;
  final bool retryable;
  final int? retryAfterSeconds;
}

class _BackendErrorSnackContent extends StatelessWidget {
  const _BackendErrorSnackContent({required this.presentation});

  final _BackendErrorPresentation presentation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final retryText = presentation.retryAfterSeconds != null
        ? tr(
            'backend_errors.retry_in',
            args: [presentation.retryAfterSeconds.toString()],
          )
        : presentation.retryable
        ? tr('backend_errors.retryable_hint')
        : '';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF16171C).withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: presentation.color.withValues(alpha: 0.22),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  presentation.icon,
                  color: presentation.color,
                  size: 25,
                ),
              ),
              Container(
                width: 2,
                height: 54,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: presentation.color.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      presentation.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        height: 1.12,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      presentation.message,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.72),
                        height: 1.22,
                      ),
                    ),
                    if (retryText.isNotEmpty) ...[
                      const SizedBox(height: 9),
                      Row(
                        children: [
                          Icon(
                            Icons.refresh_rounded,
                            color: presentation.color,
                            size: 15,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              retryText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: presentation.color,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
