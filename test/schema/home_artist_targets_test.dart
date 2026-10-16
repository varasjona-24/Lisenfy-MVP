import 'package:flutter_test/flutter_test.dart';
import 'package:listenfy/Modules/Home/domain/home_artist_targets.dart';
import 'package:listenfy/Modules/Home/domain/home_layout_models.dart';

void main() {
  HomeArtistChoice artist(String id, String name) =>
      HomeArtistChoice(key: id, name: name, count: 1);
  test('restored name shortcuts resolve to stable IDs', () {
    expect(
      resolveHomeArtistTargets('Huey Dunbar|artist-honey', [
        artist('artist-huey', 'Huey Dunbar'),
        artist('artist-honey', "L’Arc"),
      ]),
      {'artist-huey', 'artist-honey'},
    );
  });
  test('homonyms are never assigned by name, explicit ID remains valid', () {
    final choices = [
      artist('artist-korea', 'Lisa'),
      artist('artist-japan', 'Lisa'),
    ];
    expect(resolveHomeArtistTargets('Lisa', choices), isEmpty);
    expect(resolveHomeArtistTargets('artist-japan', choices), {'artist-japan'});
  });
  test(
    'legacy shortcut removal uses the same stable identity as rendering',
    () {
      final choices = [
        artist('artist-huey', 'Huey Dunbar'),
        artist('artist-honey', 'Arc'),
      ];
      expect(resolveHomeArtistTargets('Huey Dunbar|artist-honey', choices), {
        'artist-huey',
        'artist-honey',
      });
      expect(
        removeHomeArtistTargets('Huey Dunbar|artist-honey', [
          'artist-huey',
        ], choices),
        'artist-honey',
      );
      expect(
        removeHomeArtistTargets('Huey Dunbar|artist-honey', [
          'artist-honey',
        ], choices),
        'Huey Dunbar',
      );
    },
  );
}
