import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'app.dart';
import 'data/db/app_database.dart';
import 'data/db/database_provider.dart';
import 'data/download/download_worker.dart';
import 'data/notifications/notification_service.dart';
import 'data/settings/settings_repository.dart';
import 'data/sources/http_manga_source.dart';
import 'data/sources/source_auth.dart';
import 'data/sources/source_registry.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Workmanager().initialize(callbackDispatcher);
  final notif = NotificationService.instance;
  await notif.init();
  await notif.requestPermission();
  final prefs = await SharedPreferences.getInstance();

  // Persist CF cookies across restarts — one subdirectory per source.
  final appDir = await getApplicationSupportDirectory();
  HttpMangaSource.cookieBaseDir = '${appDir.path}/cookies';

  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  final db = container.read(databaseProvider);
  await db.resetStuckDownloads();

  // Restore source sessions in background — doesn't block runApp.
  unawaited(_autoRestoreSessions(db));

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const SheepApp(),
    ),
  );
}

// For every SourceAuth source that has stored credentials, attempt to restore
// the session (load token from DB, verify with the API, re-login if expired).
Future<void> _autoRestoreSessions(AppDatabase db) async {
  for (final source in allSources.whereType<HttpMangaSource>()) {
    final auth = source is SourceAuth ? source as SourceAuth : null;
    if (auth == null) continue;
    final creds = await db.getCredentials(source.id);
    if (creds == null) continue;
    try {
      await auth.restore(
        source.client,
        username: creds.username,
        password: creds.password,
        extraJson: creds.extraJson,
      );
    } catch (_) {
      // Silent — user will be prompted on next 401 via AuthService.
    }
  }
}
