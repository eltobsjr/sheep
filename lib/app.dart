import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/tokens.dart';
import 'core/widgets/webview_bypass_sheet.dart';
import 'data/settings/settings_repository.dart';
import 'data/sources/auth_service.dart';
import 'data/sources/cloudflare_bypass.dart';
import 'data/sources/http_manga_source.dart';
import 'data/sources/source_registry.dart';

class SheepApp extends ConsumerStatefulWidget {
  const SheepApp({super.key});

  @override
  ConsumerState<SheepApp> createState() => _SheepAppState();
}

class _SheepAppState extends ConsumerState<SheepApp> {
  StreamSubscription<CloudflareException>? _cfSub;
  StreamSubscription<AuthExpiredException>? _authSub;

  @override
  void initState() {
    super.initState();
    _cfSub = CloudflareBypassService.instance.challenges.listen(_onCFChallenge);
    _authSub = AuthService.instance.sessionExpired.listen(_onSessionExpired);
  }

  @override
  void dispose() {
    _cfSub?.cancel();
    _authSub?.cancel();
    super.dispose();
  }

  void _onCFChallenge(CloudflareException ex) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = rootNavigatorKey.currentContext;
      if (ctx == null) return;

      final source = sourceById(ex.sourceId);
      if (source is! HttpMangaSource) return;

      showModalBottomSheet<void>(
        context: ctx,
        isScrollControlled: true,
        backgroundColor: paper,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusCard)),
        ),
        builder: (_) => WebViewBypassSheet(
          url: ex.url,
          sourceId: ex.sourceId,
          cookieJar: source.cookieJar,
        ),
      );
    });
  }

  void _onSessionExpired(AuthExpiredException ex) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = rootNavigatorKey.currentContext;
      if (ctx == null) return;
      showDialog<void>(
        context: ctx,
        builder: (_) => _SessionExpiredDialog(
          sourceId: ex.sourceId,
          sourceName: ex.sourceName,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    return MaterialApp.router(
      title: 'Sheep',
      theme: appTheme,
      darkTheme: darkTheme,
      themeMode: settings.theme == 'dark'
          ? ThemeMode.dark
          : settings.theme == 'system'
              ? ThemeMode.system
              : ThemeMode.light,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}

class _SessionExpiredDialog extends StatelessWidget {
  const _SessionExpiredDialog({
    required this.sourceId,
    required this.sourceName,
  });

  final String sourceId;
  final String sourceName;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: paper,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusCard),
        side: const BorderSide(color: wool),
      ),
      title: const Text(
        'Session expired',
        style: TextStyle(
          fontFamily: fontDisplay,
          fontWeight: FontWeight.w700,
          fontSize: 18,
          color: ink,
        ),
      ),
      content: Text(
        'Your login for $sourceName has expired. Sign in again to continue reading.',
        style: const TextStyle(
          fontFamily: fontMono,
          fontSize: 13,
          color: slate,
        ),
      ),
      actions: [
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              'Later',
              style: TextStyle(
                fontFamily: fontMono,
                fontSize: 13,
                color: slate,
              ),
            ),
          ),
        ),
        GestureDetector(
          onTap: () {
            Navigator.of(context).pop();
            router.push('/source-credentials/$sourceId');
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: ink,
              borderRadius: BorderRadius.circular(radiusCard),
            ),
            child: const Text(
              'Sign in',
              style: TextStyle(
                fontFamily: fontMono,
                fontSize: 13,
                color: paper,
              ),
            ),
          ),
        ),
      ],
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    );
  }
}
