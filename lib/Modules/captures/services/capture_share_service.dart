import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../domain/capture_item.dart';

class CaptureShareService {
  const CaptureShareService();

  Future<void> shareExternal(Iterable<CaptureItem> captures) async {
    final selected = captures.take(20).toList(growable: false);
    if (selected.isEmpty) return;

    final files = <XFile>[];
    for (final capture in selected) {
      final file = File(capture.path);
      if (!await file.exists()) continue;
      files.add(
        XFile(file.path, name: p.basename(file.path), mimeType: 'image/jpeg'),
      );
    }
    if (files.isEmpty) return;

    await Share.shareXFiles(
      files,
      subject: 'Capturas de Listenfy',
      text: 'Elige Bluetooth u otra app externa para compartir estas capturas.',
    );
  }
}
