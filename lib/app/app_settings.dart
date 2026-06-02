import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage { spanish, aymara, english }

class AppSettings extends ChangeNotifier {
  AppSettings._(this._preferences) {
    final storedMode = _preferences.getString(_themeModeKey);
    _themeMode = storedMode == 'dark' ? ThemeMode.dark : ThemeMode.light;

    final storedIndex = _preferences.getInt(_accentColorKey) ?? 0;
    _accentColorIndex = storedIndex.clamp(0, accentColors.length - 1);

    final storedLang = _preferences.getString(_languageKey);
    _language = AppLanguage.values.firstWhere(
      (l) => l.name == storedLang,
      orElse: () => AppLanguage.spanish,
    );

    _isCollectorMode = _preferences.getBool(_collectorModeKey) ?? false;
  }

  static const _themeModeKey = 'theme_mode';
  static const _accentColorKey = 'accent_color';
  static const _languageKey = 'app_language';
  static const _collectorModeKey = 'collector_mode';

  static const List<Color> accentColors = [
    Color(0xFFE89A00), // Ámbar
    Color(0xFF1565C0), // Azul
    Color(0xFF2D936C), // Verde
  ];

  static const List<String> accentColorLabels = ['Ámbar', 'Azul', 'Verde'];

  final SharedPreferences _preferences;
  late ThemeMode _themeMode;
  late int _accentColorIndex;
  late AppLanguage _language;
  late bool _isCollectorMode;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  Color get accentColor => accentColors[_accentColorIndex];
  int get accentColorIndex => _accentColorIndex;
  AppLanguage get language => _language;
  bool get isCollectorMode => _isCollectorMode;

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

  Future<void> setAccentColor(int index) async {
    _accentColorIndex = index.clamp(0, accentColors.length - 1);
    await _preferences.setInt(_accentColorKey, _accentColorIndex);
    notifyListeners();
  }

  Future<void> setLanguage(AppLanguage language) async {
    _language = language;
    await _preferences.setString(_languageKey, language.name);
    notifyListeners();
  }

  Future<void> setCollectorMode(bool value) async {
    _isCollectorMode = value;
    await _preferences.setBool(_collectorModeKey, value);
    notifyListeners();
  }
}
