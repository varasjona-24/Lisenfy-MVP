import 'dart:io';

import 'package:dio/dio.dart' as dio;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../../app/data/repo/media_repository.dart';
import '../../../app/services/notification_service.dart';

class DownloadTaskService extends GetxService {
  final MediaRepository _repo = Get.find<MediaRepository>();
  final GetStorage _storage = Get.find<GetStorage>();

  final RxBool isDownloading = false.obs;
  final RxDouble downloadProgress = (-1.0).obs;
  final RxString downloadStatus = 'Preparando descarga...'.obs;

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
        'Descargas bloqueadas',
        'Tienes activado "Solo Wi-Fi". Conéctate a una red Wi-Fi para descargar.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange,
      );
      if (Get.isRegistered<NotificationService>()) {
        await Get.find<NotificationService>().showImportFailure(
          'La importación está esperando una conexión Wi-Fi.',
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
  }) async {
    final normalizedUrl = url.trim();
    if (normalizedUrl.isEmpty) {
      Get.snackbar(
        'Imports',
        'Por favor ingresa una URL válida',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
      );
      return false;
    }

    if (isDownloading.value) {
      Get.snackbar(
        'Imports',
        'Ya hay una importación en progreso',
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
      downloadStatus.value = 'Preparando descarga...';

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
              downloadStatus.value = 'Descargando...';
            },
          )
          .timeout(const Duration(minutes: 5), onTimeout: () => false);

      if (ok) {
        downloadStatus.value = 'Guardando en la librería...';
        Get.snackbar(
          'Imports',
          'Importación completada ✅',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
        );
        if (Get.isRegistered<NotificationService>()) {
          await Get.find<NotificationService>().showImportSuccess();
        }
      } else {
        Get.snackbar(
          'Imports',
          'Falló la importación. La web puede ser lenta o no compatible.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange,
        );
        if (Get.isRegistered<NotificationService>()) {
          await Get.find<NotificationService>().showImportFailure(
            'La web tardó demasiado o no es compatible.',
          );
        }
      }
      return ok;
    } catch (e) {
      String msg = 'Error inesperado';

      if (e is dio.DioException) {
        switch (e.type) {
          case dio.DioExceptionType.receiveTimeout:
            msg =
                'El servidor tardó demasiado en responder. Intenta nuevamente.';
            break;
          case dio.DioExceptionType.connectionTimeout:
          case dio.DioExceptionType.sendTimeout:
            msg = 'No se pudo conectar con el servidor.';
            break;
          default:
            msg = e.message ?? 'Error de red';
        }
      } else {
        msg = e.toString();
      }

      Get.snackbar(
        'Imports',
        msg,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
      );
      if (Get.isRegistered<NotificationService>()) {
        await Get.find<NotificationService>().showImportFailure(msg);
      }

      debugPrint('downloadFromUrl error: $e');
      return false;
    } finally {
      isDownloading.value = false;
      downloadProgress.value = -1;
    }
  }
}
