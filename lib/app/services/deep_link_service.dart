import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../Modules/nearby_transfer/controller/nearby_transfer_controller.dart';
import '../../Modules/downloads/controller/downloads_controller.dart';
import '../routes/app_routes.dart';
import '../utils/listenfy_deep_link.dart';
import '../../Modules/nearby_transfer/data/lan_transfer_transport.dart';

class DeepLinkService extends GetxService {
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;
  bool _started = false;

  Future<void> start() async {
    if (_started) return;
    _started = true;

    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) {
        _handleUri(initial);
      }
    } catch (_) {}

    _sub = _appLinks.uriLinkStream.listen(
      _handleUri,
      onError: (_) {},
      cancelOnError: false,
    );
  }

  void _handleUri(Uri uri) {
    final target = ListenfyDeepLink.parseUri(uri);
    switch (target) {
      case ListenfyDeepLinkTarget.openLocalImport:
        _openLocalImportFlow();
        return;
      case ListenfyDeepLinkTarget.nearbyInvite:
        _openNearbyInviteFlow(uri);
        return;
      case ListenfyDeepLinkTarget.lanInvite:
        try {
          LanTransferTransport.validateInvite(uri);
        } catch (_) {
          return;
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (Get.currentRoute == AppRoutes.nearbyTransfer &&
              Get.isRegistered<NearbyTransferController>()) {
            unawaited(
              Get.find<NearbyTransferController>().receiveLanInvite(uri),
            );
          } else {
            Get.toNamed(
              AppRoutes.nearbyTransfer,
              arguments: {'inviteUri': uri.toString()},
            );
          }
        });
        return;
      case ListenfyDeepLinkTarget.nearbyTransfer:
        _openNearbyTransferFlow();
        return;
      case ListenfyDeepLinkTarget.unknown:
        return;
    }
  }

  void _openLocalImportFlow() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Get.currentRoute == AppRoutes.downloads &&
          Get.isRegistered<DownloadsController>()) {
        Get.find<DownloadsController>().requestOpenLocalImport();
        return;
      }
      Get.toNamed(AppRoutes.downloads, arguments: {'openLocalImport': true});
    });
  }

  void _openNearbyTransferFlow() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Get.currentRoute != AppRoutes.nearbyTransfer) {
        Get.toNamed(AppRoutes.nearbyTransfer);
      }
    });
  }

  void _openNearbyInviteFlow(Uri uri) {
    final invite = ListenfyDeepLink.parseNearbyInviteUri(uri);
    if (invite == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Get.currentRoute == AppRoutes.nearbyTransfer &&
          Get.isRegistered<NearbyTransferController>()) {
        Get.find<NearbyTransferController>().startReceiveFromInvite(invite);
        return;
      }

      Get.toNamed(
        AppRoutes.nearbyTransfer,
        arguments: {'inviteUri': uri.toString()},
      );
    });
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }
}
