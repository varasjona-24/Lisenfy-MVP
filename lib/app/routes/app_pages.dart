import 'package:get/get.dart';

import 'app_routes.dart';

// Entry / Home
import 'package:listenfy/Modules/home/binding/home_binding.dart';
import 'package:listenfy/Modules/home/view/home_entry_page.dart';
import 'package:listenfy/Modules/home/view/home_page.dart';
import 'package:listenfy/Modules/home/view/section_list_page.dart';

// Player
import 'package:listenfy/Modules/player/audio/binding/audio_player_binding.dart';
import 'package:listenfy/Modules/player/audio/view/audio_player_page.dart';

// Video
import 'package:listenfy/Modules/player/Video/binding/video_player_binding.dart';
import 'package:listenfy/Modules/player/Video/view/video_player_page.dart';
import 'package:listenfy/Modules/player/Video/view/lyrics_entry_page.dart';

// Sources
import 'package:listenfy/Modules/sources/binding/sources_binding.dart';
import 'package:listenfy/Modules/sources/view/sources_page.dart';

// Downloads
import 'package:listenfy/Modules/downloads/binding/downloads_binding.dart';
import 'package:listenfy/Modules/downloads/presentation/views/downloads_page.dart';
import 'package:listenfy/Modules/downloads/binding/download_history_binding.dart';
import 'package:listenfy/Modules/downloads/presentation/views/download_history_page.dart';

// History
import 'package:listenfy/Modules/history/binding/history_binding.dart';
import 'package:listenfy/Modules/history/presentation/views/history_page.dart';

// Artists
import 'package:listenfy/Modules/artists/binding/artists_binding.dart';
import 'package:listenfy/Modules/artists/view/artists_page.dart';

// Playlists
import 'package:listenfy/Modules/playlists/binding/playlists_binding.dart';
import 'package:listenfy/Modules/playlists/view/playlists_page.dart';

// Settings
import 'package:listenfy/Modules/settings/binding/settings_binding.dart';
import 'package:listenfy/Modules/settings/view/settings_view.dart';

// Edit
import 'package:listenfy/Modules/edit/binding/edit_entity_binding.dart';
import 'package:listenfy/Modules/edit/view/edit_entity_page.dart';
import 'package:listenfy/Modules/edit/view/create_entity_page.dart';

// Queues & Details (New)
import 'package:listenfy/Modules/player/audio/view/queue_page.dart';
import 'package:listenfy/Modules/player/Video/view/video_queue_page.dart';
import 'package:listenfy/Modules/artists/view/artist_detail_page.dart';
import 'package:listenfy/Modules/playlists/view/playlist_detail_page.dart';
import 'package:listenfy/Modules/home/view/app_songs_search_page.dart';
import 'package:listenfy/Modules/sources/view/source_library_page.dart';
import 'package:listenfy/Modules/sources/view/source_theme_topic_page.dart';
import 'package:listenfy/Modules/sources/view/source_theme_topic_playlist_page.dart';
import 'package:listenfy/Modules/nearby_transfer/binding/nearby_transfer_binding.dart';
import 'package:listenfy/Modules/nearby_transfer/view/nearby_transfer_page.dart';

abstract class AppPages {
  static final routes = <GetPage>[
    // Entry
    GetPage(
      name: AppRoutes.entry,
      page: () => const HomeEntryPage(),
      binding: HomeBinding(),
    ),

    // Home
    GetPage(
      name: AppRoutes.home,
      page: () => const HomePage(),
      binding: HomeBinding(),
    ),
    GetPage(
      name: AppRoutes.homeSectionList,
      page: () {
        final args = Get.arguments as Map<String, dynamic>? ?? {};
        return SectionListPage(
          title: args['title'] ?? 'Sección',
          items: args['items'] ?? [],
          onItemTap: args['onItemTap'],
          onItemLongPress: args['onItemLongPress'],
          onShuffle: args['onShuffle'],
          itemHintBuilder: args['itemHintBuilder'],
        );
      },
      transition: Transition.rightToLeft,
    ),

    // Audio Player
    GetPage(
      name: AppRoutes.audioPlayer,
      page: () => const AudioPlayerPage(),
      binding: AudioPlayerBinding(),
    ),

    // Video Player
    GetPage(
      name: AppRoutes.videoPlayer,
      page: () => const VideoPlayerPage(),
      binding: VideoPlayerBinding(),
    ),
    // Lyrics Entry
    GetPage(name: AppRoutes.lyricsEntry, page: () => const LyricsEntryPage()),

    // Queues
    GetPage(name: AppRoutes.audioQueue, page: () => const QueuePage()),
    GetPage(name: AppRoutes.videoQueue, page: () => const VideoQueuePage()),

    // Search
    GetPage(name: AppRoutes.homeSearch, page: () => const AppSongsSearchPage()),

    // Sub-sources
    GetPage(
      name: AppRoutes.sourceLibrary,
      page: () => SourceLibraryPage(
        title: Get.arguments['title'] ?? '',
        themeId: Get.arguments['themeId'] ?? '',
        onlyOffline: Get.arguments['onlyOffline'] ?? false,
        origins: Get.arguments['origins'],
        forceKind: Get.arguments['forceKind'],
      ),
    ),
    GetPage(
      name: AppRoutes.sourceTheme,
      page: () => SourceThemeTopicPage(
        topicId: Get.arguments['topicId'] ?? '',
        theme: Get.arguments['theme'],
        origins: Get.arguments['origins'],
      ),
    ),
    GetPage(
      name: AppRoutes.sourcePlaylist,
      preventDuplicates: false,
      page: () => SourceThemeTopicPlaylistPage(
        playlistId: Get.arguments['playlistId'] ?? '',
        theme: Get.arguments['theme'],
        origins: Get.arguments['origins'],
      ),
    ),

    // Details
    GetPage(
      name: AppRoutes.artistDetail,
      page: () {
        final args = Get.arguments;
        final artistKey = switch (args) {
          String s => s,
          Map m => (m['artistKey'] ?? '').toString(),
          _ => '',
        };
        return ArtistDetailPage(artistKey: artistKey);
      },
    ),
    GetPage(
      name: AppRoutes.playlistDetail,
      page: () {
        final isSmart = Get.arguments?['isSmart'] ?? false;
        if (isSmart) {
          return PlaylistDetailPage.smart(
            playlistId: Get.arguments?['playlistId'] ?? '',
          );
        }
        return PlaylistDetailPage.custom(
          playlistId: Get.arguments?['playlistId'] ?? '',
        );
      },
    ),

    // Sources
    GetPage(
      name: AppRoutes.sources,
      page: () => const SourcesPage(),
      binding: SourcesBinding(),
    ),

    // Downloads
    GetPage(
      name: AppRoutes.downloads,
      page: () => const DownloadsPage(),
      binding: DownloadsBinding(),
    ),
    GetPage(
      name: AppRoutes.downloadsHistory,
      page: () => const DownloadHistoryPage(),
      binding: DownloadHistoryBinding(),
    ),

    // History
    GetPage(
      name: AppRoutes.history,
      page: () => const HistoryPage(),
      binding: HistoryBinding(),
    ),

    // Playlists
    GetPage(
      name: AppRoutes.playlists,
      page: () => const PlaylistsPage(),
      binding: PlaylistsBinding(),
    ),

    // Artists
    GetPage(
      name: AppRoutes.artists,
      page: () => const ArtistsPage(),
      binding: ArtistsBinding(),
    ),

    // Settings
    GetPage(
      name: AppRoutes.settings,
      page: () => const SettingsView(),
      binding: SettingsBinding(),
    ),

    // Edit
    GetPage(
      name: AppRoutes.editEntity,
      page: () => const EditEntityPage(),
      binding: EditEntityBinding(),
    ),
    GetPage(
      name: AppRoutes.createEntity,
      page: () => const CreateEntityPage(),
      binding: EditEntityBinding(),
    ),
    GetPage(
      name: AppRoutes.nearbyTransfer,
      page: () => const NearbyTransferPage(),
      binding: NearbyTransferBinding(),
    ),

    // Video Player
    //GetPage(
    //name: AppRoutes.videoPlayer,
    //page: () => const VideoPlayerPage(),
    //binding: VideoPlayerBinding(),
    //),
  ];
}
