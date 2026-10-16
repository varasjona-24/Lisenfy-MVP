import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Play Store has no remote media import entry points', () {
    final repository = File(
      'lib/app/data/repo/media_repository.dart',
    ).readAsStringSync();
    for (final marker in [
      'requestAndFetchMedia',
      'importPlaylistFromUrl',
      'resolvePlaylistFromUrl',
      '/media/download',
      '/media/playlist/import',
    ]) {
      expect(repository, isNot(contains(marker)), reason: marker);
    }
    final pill = File(
      'lib/Modules/downloads/presentation/widgets/downloads_pill.dart',
    ).readAsStringSync();
    expect(pill, isNot(contains('_ImportUrlDialog')));
    expect(pill, contains('showLocalImportDialog'));
    expect(pill, contains('ListenfyDeepLinkTarget.nearbyInvite'));
  });

  test('remote downloader settings and cookie administration are absent', () {
    final settings = File(
      'lib/Modules/settings/controller/settings_controller.dart',
    ).readAsStringSync();
    expect(settings, isNot(contains('ytdlp')));
    expect(settings, isNot(contains('uploadYtDlpCookies')));
    final playback = File(
      'lib/Modules/settings/controller/playback_settings_controller.dart',
    ).readAsStringSync();
    expect(playback, isNot(contains('downloadQuality')));
    expect(playback, isNot(contains('dataUsage')));
  });

  test(
    'both languages describe local imports and omit online import controls',
    () {
      for (final locale in ['en', 'es']) {
        final data =
            jsonDecode(
                  File('assets/translations/$locale.json').readAsStringSync(),
                )
                as Map<String, dynamic>;
        final downloads = data['downloads'] as Map<String, dynamic>;
        expect(downloads, contains('local_import_title'));
        expect(downloads, contains('scan_qr_title'));
        expect(downloads, isNot(contains('url_import_title')));
        expect(downloads, isNot(contains('quality_title')));
      }
    },
  );
}
