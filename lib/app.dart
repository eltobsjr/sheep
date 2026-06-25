import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router.dart';
import 'core/theme/app_theme.dart';
import 'data/settings/settings_repository.dart';

class SheepApp extends ConsumerWidget {
  const SheepApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    return MaterialApp.router(
      title: 'Sheep',
      theme: appTheme,
      darkTheme: darkTheme,
      themeMode:
          settings.theme == 'dark' ? ThemeMode.dark : ThemeMode.light,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
