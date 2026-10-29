import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/src/localization.dart';
import 'package:easy_localization/src/translations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:listenfy/Modules/sources/domain/source_origin.dart';
import 'package:listenfy/Modules/world_mode/domain/entities/country_station_entity.dart';
import 'package:listenfy/Modules/world_mode/domain/entities/station_seed_entity.dart';
import 'package:listenfy/Modules/world_mode/domain/entities/world_station_type.dart';
import 'package:listenfy/Modules/world_mode/presentation/widgets/country_station_card.dart';
import 'package:listenfy/app/models/media_item.dart';

void main() {
  setUpAll(() {
    Localization.load(
      const Locale('en'),
      translations: Translations(
        jsonDecode(File('assets/translations/en.json').readAsStringSync())
            as Map<String, dynamic>,
      ),
    );
  });
  for (final type in [
    WorldStationType.essentials,
    WorldStationType.discovery,
  ]) {
    for (final desktop in [false, true]) {
      testWidgets(
        'station card preserves actions: ${type.name}, desktop: $desktop',
        (tester) async {
          tester.view.physicalSize = const Size(420, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          var plays = 0;
          var continues = 0;
          MediaItem? selected;
          const track = MediaItem(
            id: 'song',
            publicId: 'song',
            title: 'Song',
            subtitle: 'Artist',
            source: MediaSource.local,
            origin: SourceOrigin.device,
            variants: [],
          );
          final station = CountryStationEntity(
            stationId: 'region_radio_1',
            countryCode: 'region',
            type: type,
            title: 'Region Radio',
            subtitle: '30 tracks · ${type.name}',
            tracks: const [track],
            generatedAtMs: 0,
            ttlSec: 3600,
            seed: StationSeedEntity(
              countryCode: 'region',
              stationType: type,
              generatedAtMs: 0,
            ),
          );
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: CountryStationCard(
                    station: station,
                    desktop: desktop,
                    onPlay: () => plays++,
                    onContinue: () => continues++,
                    onTrackTap: (item) => selected = item,
                  ),
                ),
              ),
            ),
          );
          expect(find.text('Region Radio'), findsOneWidget);
          expect(find.text(station.subtitle), findsNothing);
          expect(find.text('Local library'), findsNothing);
          expect(find.byIcon(Icons.memory_rounded), findsNothing);
          expect(find.byIcon(Icons.queue_music_rounded), findsNothing);
          expect(find.text('Song'), findsOneWidget);
          await tester.tap(find.byType(FilledButton));
          await tester.tap(find.byType(OutlinedButton));
          await tester.tap(find.text('Song'));
          expect(plays, 1);
          expect(continues, 1);
          expect(selected, same(track));
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
