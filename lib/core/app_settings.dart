import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings extends ChangeNotifier {
  static const _themeKey = 'app_theme_mode';
  static const _langKey = 'app_lang';

  ThemeMode _themeMode = ThemeMode.light;
  Locale _locale = const Locale('ru');

  ThemeMode get themeMode => _themeMode;
  Locale get locale => _locale;
  bool get isDark => _themeMode == ThemeMode.dark;

  String get apiLangLower => _locale.languageCode;
  String get apiLangUpper => _locale.languageCode.toUpperCase();

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    final theme = prefs.getString(_themeKey);
    final lang = prefs.getString(_langKey);

    if (theme == 'dark') {
      _themeMode = ThemeMode.dark;
    } else if (theme == 'system') {
      _themeMode = ThemeMode.system;
    } else {
      _themeMode = ThemeMode.light;
    }

    _locale = lang == 'en' ? const Locale('en') : const Locale('ru');
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _themeKey,
      mode == ThemeMode.dark
          ? 'dark'
          : mode == ThemeMode.system
          ? 'system'
          : 'light',
    );
    notifyListeners();
  }

  Future<void> toggleDark(bool value) async {
    await setThemeMode(value ? ThemeMode.dark : ThemeMode.light);
  }

  Future<void> setLocale(Locale locale) async {
    _locale = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_langKey, locale.languageCode);
    notifyListeners();
  }
}
