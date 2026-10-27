import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:listenfy/Modules/nearby_transfer/data/transfer_cover_attachment.dart';

void main() {
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('cover-attachment-test-');
  });
  tearDown(() async {
    await directory.delete(recursive: true);
  });

  test('missing, empty, non-image and oversized covers are optional', () async {
    expect(await TransferCoverAttachment.read(null), isNull);
    expect(
      await TransferCoverAttachment.read('${directory.path}/missing'),
      isNull,
    );
    final file = File('${directory.path}/image.png');
    await file.writeAsBytes([]);
    expect(await TransferCoverAttachment.read(file.path), isNull);
    await file.writeAsBytes(List.filled(32, 0));
    expect(await TransferCoverAttachment.read(file.path), isNull);
    final handle = await file.open(mode: FileMode.write);
    await handle.truncate(TransferCoverAttachment.maxBytes + 1);
    await handle.close();
    expect(await TransferCoverAttachment.read(file.path), isNull);
  });

  test(
    'recognizes supported signatures without trusting filename extension',
    () async {
      for (final entry in <String, List<int>>{
        'png': [137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 0],
        'jpg': [255, 216, 255, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        'gif': 'GIF89a000000'.codeUnits,
        'webp': 'RIFF0000WEBP'.codeUnits,
      }.entries) {
        final file = File('${directory.path}/${entry.key}.wrong');
        await file.writeAsBytes(entry.value);
        final cover = await TransferCoverAttachment.read(file.path);
        expect(cover?.format, entry.key);
        expect(
          cover?.toJson().keys,
          unorderedEquals(['sizeBytes', 'sha256', 'format']),
        );
        expect(cover?.toJson().toString(), isNot(contains(directory.path)));
        expect(await file.readAsBytes(), entry.value);
      }
    },
  );
}
