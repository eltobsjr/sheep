import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>(
  (_) => throw UnimplementedError(),
);

class Settings {
  const Settings({
    this.readingMode = 'paginated',
    this.direction = 'rtl',
    this.keepScreenOn = true,
    this.wifiOnly = true,
    this.imageQuality = 'high',
    this.theme = 'light',
  });

  final String readingMode;
  final String direction;
  final bool keepScreenOn;
  final bool wifiOnly;
  final String imageQuality;
  final String theme;

  Settings copyWith({
    String? readingMode,
    String? direction,
    bool? keepScreenOn,
    bool? wifiOnly,
    String? imageQuality,
    String? theme,
  }) =>
      Settings(
        readingMode: readingMode ?? this.readingMode,
        direction: direction ?? this.direction,
        keepScreenOn: keepScreenOn ?? this.keepScreenOn,
        wifiOnly: wifiOnly ?? this.wifiOnly,
        imageQuality: imageQuality ?? this.imageQuality,
        theme: theme ?? this.theme,
      );
}

class SettingsNotifier extends Notifier<Settings> {
  static const _kMode = 'reading_mode';
  static const _kDir = 'direction';
  static const _kScreen = 'keep_screen_on';
  static const _kWifi = 'wifi_only';
  static const _kQuality = 'image_quality';
  static const _kTheme = 'theme';

  @override
  Settings build() {
    final p = ref.read(sharedPreferencesProvider);
    return Settings(
      readingMode: p.getString(_kMode) ?? 'paginated',
      direction: p.getString(_kDir) ?? 'rtl',
      keepScreenOn: p.getBool(_kScreen) ?? true,
      wifiOnly: p.getBool(_kWifi) ?? true,
      imageQuality: p.getString(_kQuality) ?? 'high',
      theme: p.getString(_kTheme) ?? 'light',
    );
  }

  SharedPreferences get _p => ref.read(sharedPreferencesProvider);

  void setReadingMode(String v) {
    _p.setString(_kMode, v);
    state = state.copyWith(readingMode: v);
  }

  void setDirection(String v) {
    _p.setString(_kDir, v);
    state = state.copyWith(direction: v);
  }

  void setKeepScreenOn(bool v) {
    _p.setBool(_kScreen, v);
    state = state.copyWith(keepScreenOn: v);
  }

  void setWifiOnly(bool v) {
    _p.setBool(_kWifi, v);
    state = state.copyWith(wifiOnly: v);
  }

  void setImageQuality(String v) {
    _p.setString(_kQuality, v);
    state = state.copyWith(imageQuality: v);
  }

  void setTheme(String v) {
    _p.setString(_kTheme, v);
    state = state.copyWith(theme: v);
  }
}

final settingsProvider =
    NotifierProvider<SettingsNotifier, Settings>(SettingsNotifier.new);
