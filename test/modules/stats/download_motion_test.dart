import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:listenfy/Modules/downloads/service/download_task_service.dart';
import 'package:listenfy/app/data/repo/media_repository.dart';
import 'package:listenfy/app/ui/widgets/download/download_progress_banner.dart';

class _Repository implements MediaRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('$invocation');
}

class _Preferences implements GetStorage {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('$invocation');
}

void main() {
  tearDown(() => Get.reset());
  testWidgets(
    'banner smooths real progress and exits without changing the download',
    (tester) async {
      Get.put<MediaRepository>(_Repository());
      Get.put<GetStorage>(_Preferences());
      final service = Get.put(DownloadTaskService());
      service.isDownloading.value = true;
      service.downloadStatus.value = 'Downloading';
      service.downloadProgress.value = .4;
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: DownloadProgressBanner())),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        .4,
      );
      service.downloadProgress.value = .8;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 90));
      final displayed = tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value!;
      expect(displayed, inExclusiveRange(.4, .8));
      expect(service.downloadProgress.value, .8);
      await tester.pumpAndSettle();
      service.isDownloading.value = false;
      await tester.pumpAndSettle();
      expect(find.text('Downloading'), findsNothing);
      expect(service.downloadProgress.value, .8);
      expect(tester.takeException(), isNull);
    },
  );
}
