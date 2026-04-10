import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_preferences.dart';

class AppSettings extends ChangeNotifier {
  static const _themeKey = 'app_theme_mode';
  static const _langKey = 'app_lang';
  static const _pantryReminderEnabledKey = 'notif_pantry_enabled';
  static const _pantryReminderHourKey = 'notif_pantry_hour';
  static const _pantryReminderMinuteKey = 'notif_pantry_minute';
  static const _mealRemindersEnabledKey = 'notif_meals_enabled';
  static const _breakfastReminderHourKey = 'notif_breakfast_hour';
  static const _breakfastReminderMinuteKey = 'notif_breakfast_minute';
  static const _lunchReminderHourKey = 'notif_lunch_hour';
  static const _lunchReminderMinuteKey = 'notif_lunch_minute';
  static const _dinnerReminderHourKey = 'notif_dinner_hour';
  static const _dinnerReminderMinuteKey = 'notif_dinner_minute';
  static const _weeklySummaryEnabledKey = 'notif_weekly_enabled';
  static const _weeklySummaryWeekdayKey = 'notif_weekly_weekday';
  static const _weeklySummaryHourKey = 'notif_weekly_hour';
  static const _weeklySummaryMinuteKey = 'notif_weekly_minute';

  ThemeMode _themeMode = ThemeMode.light;
  Locale _locale = const Locale('ru');
  bool _pantryReminderEnabled = false;
  TimeOfDay _pantryReminderTime = const TimeOfDay(hour: 9, minute: 0);
  bool _mealRemindersEnabled = false;
  TimeOfDay _breakfastReminderTime = const TimeOfDay(hour: 8, minute: 30);
  TimeOfDay _lunchReminderTime = const TimeOfDay(hour: 13, minute: 0);
  TimeOfDay _dinnerReminderTime = const TimeOfDay(hour: 19, minute: 0);
  bool _weeklySummaryEnabled = false;
  int _weeklySummaryWeekday = DateTime.sunday;
  TimeOfDay _weeklySummaryTime = const TimeOfDay(hour: 19, minute: 30);

  ThemeMode get themeMode => _themeMode;
  Locale get locale => _locale;
  bool get isDark => _themeMode == ThemeMode.dark;
  bool get pantryReminderEnabled => _pantryReminderEnabled;
  TimeOfDay get pantryReminderTime => _pantryReminderTime;
  bool get mealRemindersEnabled => _mealRemindersEnabled;
  TimeOfDay get breakfastReminderTime => _breakfastReminderTime;
  TimeOfDay get lunchReminderTime => _lunchReminderTime;
  TimeOfDay get dinnerReminderTime => _dinnerReminderTime;
  bool get weeklySummaryEnabled => _weeklySummaryEnabled;
  int get weeklySummaryWeekday => _weeklySummaryWeekday;
  TimeOfDay get weeklySummaryTime => _weeklySummaryTime;

  String get apiLangLower => _locale.languageCode;
  String get apiLangUpper => _locale.languageCode.toUpperCase();

  NotificationPreferences get notificationPreferences =>
      NotificationPreferences(
        localeCode: _locale.languageCode,
        pantryReminderEnabled: _pantryReminderEnabled,
        pantryReminderTime: _pantryReminderTime,
        mealRemindersEnabled: _mealRemindersEnabled,
        breakfastReminderTime: _breakfastReminderTime,
        lunchReminderTime: _lunchReminderTime,
        dinnerReminderTime: _dinnerReminderTime,
        weeklySummaryEnabled: _weeklySummaryEnabled,
        weeklySummaryWeekday: _weeklySummaryWeekday,
        weeklySummaryTime: _weeklySummaryTime,
      );

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
    _pantryReminderEnabled = prefs.getBool(_pantryReminderEnabledKey) ?? false;
    _pantryReminderTime = _readTime(
      prefs,
      hourKey: _pantryReminderHourKey,
      minuteKey: _pantryReminderMinuteKey,
      fallback: const TimeOfDay(hour: 9, minute: 0),
    );
    _mealRemindersEnabled = prefs.getBool(_mealRemindersEnabledKey) ?? false;
    _breakfastReminderTime = _readTime(
      prefs,
      hourKey: _breakfastReminderHourKey,
      minuteKey: _breakfastReminderMinuteKey,
      fallback: const TimeOfDay(hour: 8, minute: 30),
    );
    _lunchReminderTime = _readTime(
      prefs,
      hourKey: _lunchReminderHourKey,
      minuteKey: _lunchReminderMinuteKey,
      fallback: const TimeOfDay(hour: 13, minute: 0),
    );
    _dinnerReminderTime = _readTime(
      prefs,
      hourKey: _dinnerReminderHourKey,
      minuteKey: _dinnerReminderMinuteKey,
      fallback: const TimeOfDay(hour: 19, minute: 0),
    );
    _weeklySummaryEnabled = prefs.getBool(_weeklySummaryEnabledKey) ?? false;
    _weeklySummaryWeekday =
        prefs.getInt(_weeklySummaryWeekdayKey) ?? DateTime.sunday;
    _weeklySummaryTime = _readTime(
      prefs,
      hourKey: _weeklySummaryHourKey,
      minuteKey: _weeklySummaryMinuteKey,
      fallback: const TimeOfDay(hour: 19, minute: 30),
    );
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

  Future<void> setPantryReminderEnabled(bool value) async {
    _pantryReminderEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pantryReminderEnabledKey, value);
    notifyListeners();
  }

  Future<void> setPantryReminderTime(TimeOfDay value) async {
    _pantryReminderTime = value;
    final prefs = await SharedPreferences.getInstance();
    await _writeTime(
      prefs,
      hourKey: _pantryReminderHourKey,
      minuteKey: _pantryReminderMinuteKey,
      value: value,
    );
    notifyListeners();
  }

  Future<void> setMealRemindersEnabled(bool value) async {
    _mealRemindersEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_mealRemindersEnabledKey, value);
    notifyListeners();
  }

  Future<void> setBreakfastReminderTime(TimeOfDay value) async {
    _breakfastReminderTime = value;
    final prefs = await SharedPreferences.getInstance();
    await _writeTime(
      prefs,
      hourKey: _breakfastReminderHourKey,
      minuteKey: _breakfastReminderMinuteKey,
      value: value,
    );
    notifyListeners();
  }

  Future<void> setLunchReminderTime(TimeOfDay value) async {
    _lunchReminderTime = value;
    final prefs = await SharedPreferences.getInstance();
    await _writeTime(
      prefs,
      hourKey: _lunchReminderHourKey,
      minuteKey: _lunchReminderMinuteKey,
      value: value,
    );
    notifyListeners();
  }

  Future<void> setDinnerReminderTime(TimeOfDay value) async {
    _dinnerReminderTime = value;
    final prefs = await SharedPreferences.getInstance();
    await _writeTime(
      prefs,
      hourKey: _dinnerReminderHourKey,
      minuteKey: _dinnerReminderMinuteKey,
      value: value,
    );
    notifyListeners();
  }

  Future<void> setWeeklySummaryEnabled(bool value) async {
    _weeklySummaryEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_weeklySummaryEnabledKey, value);
    notifyListeners();
  }

  Future<void> setWeeklySummaryWeekday(int value) async {
    _weeklySummaryWeekday = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_weeklySummaryWeekdayKey, value);
    notifyListeners();
  }

  Future<void> setWeeklySummaryTime(TimeOfDay value) async {
    _weeklySummaryTime = value;
    final prefs = await SharedPreferences.getInstance();
    await _writeTime(
      prefs,
      hourKey: _weeklySummaryHourKey,
      minuteKey: _weeklySummaryMinuteKey,
      value: value,
    );
    notifyListeners();
  }

  TimeOfDay _readTime(
    SharedPreferences prefs, {
    required String hourKey,
    required String minuteKey,
    required TimeOfDay fallback,
  }) {
    final hour = prefs.getInt(hourKey);
    final minute = prefs.getInt(minuteKey);
    if (hour == null || minute == null) return fallback;
    return TimeOfDay(hour: hour, minute: minute);
  }

  Future<void> _writeTime(
    SharedPreferences prefs, {
    required String hourKey,
    required String minuteKey,
    required TimeOfDay value,
  }) async {
    await prefs.setInt(hourKey, value.hour);
    await prefs.setInt(minuteKey, value.minute);
  }
}
