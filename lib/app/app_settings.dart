import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings extends ChangeNotifier {
  AppSettings._(this._preferences) {
    final storedMode = _preferences.getString(_themeModeKey);
    _themeMode = storedMode == 'dark' ? ThemeMode.dark : ThemeMode.light;
  }

  static const String _themeModeKey = 'theme_mode';

  final SharedPreferences _preferences;
  late ThemeMode _themeMode;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  static Future<AppSettings> load() async {
    final preferences = await SharedPreferences.getInstance();
    return AppSettings._(preferences);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _preferences.setString(
      _themeModeKey,
      mode == ThemeMode.dark ? 'dark' : 'light',
    );
    notifyListeners();
  }
}
