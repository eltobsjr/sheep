import 'package:flutter/material.dart';
import 'core/router.dart';
import 'core/theme/app_theme.dart';

class SheepApp extends StatelessWidget {
  const SheepApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Sheep',
      theme: appTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
