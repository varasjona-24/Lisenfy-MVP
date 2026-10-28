import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../Modules/Home/Controller/home_controller.dart';
import '../../../controllers/navigation_controller.dart';
import '../../../routes/app_routes.dart';
import '../../../services/audio_service.dart';
import '../branding/listenfy_logo.dart';
import 'app_bottom_nav.dart';
import 'app_top_bar.dart';

/// Shared desktop navigation around the existing page content and callbacks.
class AppNavigationScaffold extends StatelessWidget {
  const AppNavigationScaffold({
    super.key,
    required this.navigationIndex,
    this.appBar,
    this.body,
    this.backgroundColor,
    this.bottomNavigationBar,
    this.extendBody = false,
    this.onNavigate,
  });

  final int navigationIndex;
  final PreferredSizeWidget? appBar;
  final Widget? body;
  final Color? backgroundColor;
  final Widget? bottomNavigationBar;
  final bool extendBody;
  final ValueChanged<int>? onNavigate;

  static bool hasSidebar(String route) => const {
    AppRoutes.home,
    AppRoutes.playlists,
    AppRoutes.playlistDetail,
    AppRoutes.artists,
    AppRoutes.artistDetail,
    AppRoutes.downloads,
    AppRoutes.downloadsHistory,
    AppRoutes.history,
    AppRoutes.listeningStats,
    AppRoutes.sources,
    AppRoutes.sourceLibrary,
    AppRoutes.sourceTheme,
    AppRoutes.sourcePlaylist,
    AppRoutes.atlas,
    AppRoutes.worldMode,
    '/WeeklyCollagePage',
  }.contains(route);

  void _navigate(int index) {
    if (onNavigate != null) {
      onNavigate!(index);
      return;
    }
    if (Get.isRegistered<HomeController>()) {
      final home = Get.find<HomeController>();
      switch (index) {
        case 0:
          home.enterHome();
        case 1:
          home.goToPlaylists();
        case 2:
          home.goToArtists();
        case 3:
          home.goToAtlas();
        case 4:
          home.goToDownloads();
        case 5:
          home.goToSources();
      }
      return;
    }
    final route = [
      AppRoutes.home,
      AppRoutes.playlists,
      AppRoutes.artists,
      AppRoutes.atlas,
      AppRoutes.downloads,
      AppRoutes.sources,
    ][index];
    if (Get.currentRoute != route) Get.toNamed(route);
  }

  Widget _pageBody() {
    if (!Get.isRegistered<AudioService>() ||
        !Get.isRegistered<NavigationController>()) {
      return body ?? const SizedBox.shrink();
    }
    return Obx(() {
      final audio = Get.find<AudioService>();
      final nav = Get.find<NavigationController>();
      final visible =
          audio.currentItem.value != null &&
          !audio.miniPlayerDismissed.value &&
          (audio.state.value != PlaybackState.stopped || audio.keepLastItem) &&
          !nav.isVideoContext.value &&
          !nav.isEditing.value;
      return Padding(
        padding: EdgeInsets.only(bottom: visible ? 112 : 0),
        child: body,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!AppBottomNav.desktopSidebarEnabled) {
      return Scaffold(
        appBar: appBar,
        body: body,
        backgroundColor: backgroundColor,
        bottomNavigationBar: bottomNavigationBar,
        extendBody: extendBody,
      );
    }
    final scheme = Theme.of(context).colorScheme;
    final width = AppBottomNav.sidebarWidth(MediaQuery.sizeOf(context).width);
    final compact = width < 100;
    final original = appBar;
    final toolbar = original is AppTopBar
        ? original
        : AppTopBar(
            title: original is AppBar
                ? original.title ?? const SizedBox.shrink()
                : const SizedBox.shrink(),
            extraActions: original is AppBar
                ? original.actions ?? const []
                : const [],
          );
    // Keep page titles and back navigation; toolbar actions live in the rail.
    final PreferredSizeWidget? pageHeader;
    if (original is AppTopBar) {
      pageHeader = original.leading == null
          ? null
          : AppBar(
              title: original.title,
              leading: original.leading,
              backgroundColor: scheme.surface,
              surfaceTintColor: scheme.surface,
            );
    } else if (original is AppBar) {
      pageHeader = AppBar(
        title: original.title,
        leading: original.leading,
        automaticallyImplyLeading: original.automaticallyImplyLeading,
        bottom: original.bottom,
        centerTitle: false,
        backgroundColor: scheme.surface,
        surfaceTintColor: scheme.surface,
      );
    } else {
      pageHeader = original;
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: width,
          child: AppBottomNav(
            vertical: true,
            compact: compact,
            currentIndex: navigationIndex,
            onTap: _navigate,
            header: ListenfyLogo(
              size: 28,
              showText: !compact,
              color: scheme.primary,
            ),
            tools: toolbar.buildSidebarActions(context, compact: compact),
          ),
        ),
        Expanded(
          child: Scaffold(
            appBar: pageHeader,
            body: _pageBody(),
            backgroundColor: backgroundColor,
            extendBody: extendBody,
          ),
        ),
      ],
    );
  }
}
