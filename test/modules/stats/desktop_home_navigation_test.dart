import 'dart:convert';
import 'dart:io';
import 'package:easy_localization/src/localization.dart';
import 'package:easy_localization/src/translations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:listenfy/app/ui/widgets/navigation/app_bottom_nav.dart';
import 'package:listenfy/app/ui/widgets/navigation/app_top_bar.dart';
import 'package:listenfy/app/ui/widgets/navigation/app_navigation_scaffold.dart';
import 'package:listenfy/app/routes/app_routes.dart';

void main() {
  setUpAll(
    () => Localization.load(
      const Locale('en'),
      translations: Translations(
        jsonDecode(File('assets/translations/en.json').readAsStringSync())
            as Map<String, dynamic>,
      ),
    ),
  );

  for (final size in [const Size(1440, 900), const Size(900, 600)]) {
    testWidgets(
      'shared desktop sidebar preserves page actions and destinations at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        int? selected;
        var opensWeekly = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: AppNavigationScaffold(
              navigationIndex: 4,
              onNavigate: (index) => selected = index,
              appBar: AppBar(
                title: const Text('Wrapped'),
                actions: [
                  TextButton.icon(
                    onPressed: () => opensWeekly++,
                    icon: const Icon(Icons.calendar_view_week_rounded),
                    label: const Text('Weekly recap'),
                  ),
                ],
              ),
              body: const SizedBox.expand(key: ValueKey('page-content')),
              bottomNavigationBar: AppBottomNav(currentIndex: 4, onTap: (_) {}),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(BottomNavigationBar), findsNothing);
        expect(find.text('Wrapped'), findsOneWidget);
        final content = tester.getRect(
          find.byKey(const ValueKey('page-content')),
        );
        expect(content.left, AppBottomNav.sidebarWidth(size.width));
        expect(content.right, size.width);
        final rail = find.byWidgetPredicate(
          (widget) => widget is AppBottomNav && widget.vertical,
        );
        final tiles = find.descendant(of: rail, matching: find.byType(Tooltip));
        final labels = tester
            .widgetList<Tooltip>(tiles)
            .map((widget) => widget.message)
            .whereType<String>()
            .toSet()
            .toList();
        for (var index = 0; index < 6; index++) {
          final target = find.byTooltip(labels[index]).first;
          await tester.ensureVisible(target);
          await tester.tap(target);
          expect(selected, index);
        }
        final weekly = find.text('Weekly recap');
        await tester.ensureVisible(weekly);
        await tester.tap(weekly);
        expect(opensWeekly, 1);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant({TargetPlatform.macOS}),
    );
  }

  testWidgets(
    'shared shell retains both bars on mobile',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AppNavigationScaffold(
            navigationIndex: 1,
            appBar: const AppTopBar(title: Text('Playlists')),
            body: const Text('Content'),
            bottomNavigationBar: AppBottomNav(currentIndex: 1, onTap: (_) {}),
          ),
        ),
      );
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byType(BottomNavigationBar), findsOneWidget);
      expect(find.byType(AppBottomNav), findsOneWidget);
    },
    variant: TargetPlatformVariant({TargetPlatform.android}),
  );

  testWidgets(
    'desktop detail keeps its back button and toolbar actions',
    (tester) async {
      var edits = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AppNavigationScaffold(
                      navigationIndex: 1,
                      appBar: AppTopBar(
                        title: const Text('Playlist detail'),
                        leading: const BackButton(),
                        extraActions: [
                          IconButton(
                            tooltip: 'Edit playlist',
                            onPressed: () => edits++,
                            icon: const Icon(Icons.edit),
                          ),
                        ],
                      ),
                      body: const Text('Tracks'),
                    ),
                  ),
                ),
                child: const Text('Open detail'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open detail'));
      await tester.pumpAndSettle();
      expect(find.byType(BackButton), findsOneWidget);
      final edit = find.byTooltip('Edit playlist').first;
      await tester.ensureVisible(edit);
      await tester.tap(edit);
      expect(edits, 1);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Open detail'), findsOneWidget);
      expect(find.text('Tracks'), findsNothing);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({TargetPlatform.macOS}),
  );

  test('mini player reserves sidebar space on module and special routes', () {
    for (final route in [
      AppRoutes.home,
      AppRoutes.playlists,
      AppRoutes.artists,
      AppRoutes.downloads,
      AppRoutes.downloadsHistory,
      AppRoutes.listeningStats,
      AppRoutes.history,
      AppRoutes.sourceLibrary,
      AppRoutes.sourceTheme,
      AppRoutes.sourcePlaylist,
      AppRoutes.atlas,
      '/WeeklyCollagePage',
    ]) {
      expect(AppNavigationScaffold.hasSidebar(route), isTrue, reason: route);
    }
    expect(AppNavigationScaffold.hasSidebar(AppRoutes.audioPlayer), isFalse);
    expect(AppNavigationScaffold.hasSidebar(AppRoutes.editEntity), isFalse);
  });

  for (final compact in [false, true]) {
    testWidgets(
      'sidebar preserves every destination and toolbar callback: compact=$compact',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 1800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        int? destination;
        final actions = <String>[];
        final topBar = AppTopBar(
          title: const Text('Listenfy'),
          onSearch: () => actions.add('library'),
          onToggleMode: () => actions.add('mode'),
          onLocalConnect: () => actions.add('connect'),
          onSettings: () => actions.add('settings'),
          extraActions: [
            IconButton(
              tooltip: 'Edit home',
              icon: const Icon(Icons.edit),
              onPressed: () => actions.add('edit'),
            ),
          ],
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => SizedBox(
                  width: compact ? 76 : 264,
                  child: AppBottomNav(
                    vertical: true,
                    compact: compact,
                    currentIndex: 0,
                    onTap: (index) => destination = index,
                    tools: topBar.buildSidebarActions(
                      context,
                      compact: compact,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(BottomNavigationBar), findsNothing);
        expect(find.byType(AppBar), findsNothing);
        final tooltips = tester
            .widgetList<Tooltip>(find.byType(Tooltip))
            .map((item) => item.message)
            .whereType<String>()
            .toList();
        final labels = tooltips.toSet().toList();
        expect(labels.length, 11);
        for (var index = 0; index < 6; index++) {
          await tester.tap(find.byTooltip(labels[index]).first);
          expect(destination, index);
        }
        for (final label in labels.skip(6)) {
          await tester.tap(find.byTooltip(label).first);
        }
        expect(actions, ['library', 'mode', 'edit', 'connect', 'settings']);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('default navigation retains the mobile bottom bar', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: AppBottomNav(currentIndex: 0, onTap: (_) {}),
        ),
      ),
    );
    expect(find.byType(BottomNavigationBar), findsOneWidget);
  });
}
