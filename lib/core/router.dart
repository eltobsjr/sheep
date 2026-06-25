import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/browse/browse_screen.dart';
import '../features/browse/search_screen.dart';
import '../features/downloads/downloads_screen.dart';
import '../features/library/library_screen.dart';
import '../features/manga_detail/manga_detail_screen.dart';
import '../features/reader/reader_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/source_credentials/source_credentials_screen.dart';
import 'widgets/scaffold_with_nav_bar.dart';

// Used by app.dart to show dialogs from outside the widget tree.
final rootNavigatorKey = GlobalKey<NavigatorState>();

final router = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/library',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) =>
          ScaffoldWithNavBar(navigationShell: shell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/library',
            builder: (context, state) => const LibraryScreen(),
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/browse',
            builder: (context, state) => const BrowseScreen(),
            routes: [
              GoRoute(
                path: 'search',
                builder: (context, state) => const SearchScreen(),
              ),
            ],
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/downloads',
            builder: (context, state) => const DownloadsScreen(),
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
        ]),
      ],
    ),
    GoRoute(
      path: '/manga/:mangaId',
      builder: (context, state) => MangaDetailScreen(
        mangaId: state.pathParameters['mangaId']!,
      ),
    ),
    GoRoute(
      path: '/reader/:mangaId/:chapterId',
      builder: (context, state) => ReaderScreen(
        chapterId: state.pathParameters['chapterId']!,
        mangaId: state.pathParameters['mangaId']!,
      ),
    ),
    GoRoute(
      path: '/source-credentials/:sourceId',
      builder: (context, state) => SourceCredentialsScreen(
        sourceId: state.pathParameters['sourceId']!,
      ),
    ),
  ],
);
