import 'package:flutter_test/flutter_test.dart';
import 'package:listenfy/Modules/Home/domain/home_layout_models.dart';

void main() {
  test(
    'mixed widget order survives serialization and keeps hidden sections',
    () {
      const artist = HomeCustomSection(
        id: 'artist',
        kind: HomeCustomSectionKind.artist,
        targetId: 'a',
        title: 'Artists',
        enabled: false,
      );
      const playlist = HomeCustomSection(
        id: 'playlist',
        kind: HomeCustomSectionKind.playlist,
        targetId: 'p',
        title: 'Playlists',
      );
      final entries = <Object>[
        playlist,
        HomeWidgetId.favorites,
        artist,
        HomeWidgetId.latestDownloads,
      ];
      final custom = homeCustomSectionsInEditorOrder(
        entries,
      ).map((s) => HomeCustomSection.fromJson(s.toJson())).toList();
      final restored = homeEditorEntries([
        HomeWidgetId.favorites,
        HomeWidgetId.latestDownloads,
      ], custom);
      expect(
        restored.map(
          (e) => e is HomeWidgetId ? e.key : (e as HomeCustomSection).id,
        ),
        ['playlist', 'favorites', 'artist', 'latestDownloads'],
      );
      expect(custom.last.enabled, isFalse);
      final end = homeCustomSectionsInEditorOrder([
        HomeWidgetId.favorites,
        artist,
      ]);
      expect(end.single.beforeWidget, '');
    },
  );
  for (final kind in [
    HomeCustomSectionKind.artist,
    HomeCustomSectionKind.playlist,
    HomeCustomSectionKind.collection,
  ]) {
    test('${kind.name} hides and restores without losing selections', () {
      final section = HomeCustomSection(
        id: 'custom',
        kind: kind,
        targetId: 'a|b',
        title: 'Custom',
      );
      final hidden = section.copyWith(
        enabled: false,
        beforeWidget: 'favorites',
      );
      final restored = HomeCustomSection.fromJson(hidden.toJson());
      expect(restored.enabled, isFalse);
      expect(restored.targetId, 'a|b');
      expect(restored.beforeWidget, 'favorites');
      expect(restored.copyWith(enabled: true).targetId, 'a|b');
      final removed = restored.withoutTargets(['a']);
      expect(removed.targetId, 'b');
      expect(removed.enabled, isFalse);
      expect(removed.beforeWidget, 'favorites');
      expect(section.targetId, 'a|b');
    });
  }
  test('legacy layouts remain enabled by default', () {
    final section = HomeCustomSection.fromJson({
      'id': 'old',
      'kind': 'playlist',
      'targetId': 'a',
      'title': 'Old',
    });
    expect(section.enabled, isTrue);
    expect(section.beforeWidget, isNull);
  });
}
