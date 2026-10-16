import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:listenfy/app/models/media_item.dart';
import 'package:listenfy/app/controllers/media_actions_controller.dart';
import 'package:listenfy/Modules/stats/domain/entities/listening_stats_entities.dart';

void main() {
  test('import date survives replacement, deletion and JSON round trip', () {
    final original = MediaItem.fromJson({
      'id': 'song',
      'title': 'Song',
      'variants': [
        {
          'kind': 'audio',
          'format': 'mp3',
          'fileName': 'song.mp3',
          'localPath': '/song.mp3',
          'createdAt': 100,
        },
      ],
    });
    final persisted = MediaItem.fromJson(original.toJson());
    final empty = persisted.copyWith(variants: []);
    expect(empty.originalImportAt, 100);
    expect(MediaItem.fromJson(empty.toJson()).importedAt, 100);
    expect(original.copyWith(variants: []).originalImportAt, 100);
  });
  test(
    'later local variants do not change original import or import periods',
    () {
      MediaItem media(List<int> dates) => MediaItem.fromJson({
        'id': 'song',
        'title': 'Song',
        'variants': [
          for (final date in dates)
            {
              'kind': 'audio',
              'format': 'mp3',
              'fileName': '$date.mp3',
              'localPath': '/$date.mp3',
              'createdAt': date,
            },
          {
            'kind': 'audio',
            'format': 'mp3',
            'fileName': 'remote.mp3',
            'createdAt': 1,
          },
        ],
      });
      final original = DateTime(2026, 4, 4).millisecondsSinceEpoch;
      final later = DateTime(2026, 10, 8).millisecondsSinceEpoch;
      final before = ImportStats.fromItems([
        media([original]),
      ]);
      final afterItem = media([0, later, original]);
      final after = ImportStats.fromItems([afterItem]);
      expect(afterItem.originalImportAt, original);
      expect(after.latestImportAt, before.latestImportAt);
      expect(after.monthCounts, before.monthCounts);
      expect(after.topWeek.count, before.topWeek.count);
      expect(after.totalFiles, 3);
    },
  );
  testWidgets('favorite action responds to text, icon and empty row area', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaActionRow(
            icon: Icons.favorite_border_rounded,
            label: 'Favorite',
            onTap: () => taps++,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Favorite'));
    await tester.tap(find.byIcon(Icons.favorite_border_rounded));
    final rect = tester.getRect(find.byType(GestureDetector));
    await tester.tapAt(Offset(rect.right - 80, rect.center.dy));
    expect(taps, 3);
  });
}
