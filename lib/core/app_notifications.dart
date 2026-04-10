import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'app_feedback.dart';
import 'notification_preferences.dart';

class AppNotifications {
  AppNotifications._();

  static final AppNotifications instance = AppNotifications._();

  static const _channelId = 'wellbeing_reminders';
  static const _channelName = 'Wellbeing reminders';
  static const _channelDescription =
      'Pantry, meals, and weekly nutrition reminders';

  static const _pantryId = 4101;
  static const _breakfastId = 4201;
  static const _lunchId = 4202;
  static const _dinnerId = 4203;
  static const _weeklySummaryId = 4301;
  static const _historyKeyPrefix = 'notif_history_last_';
  static const _historyMigrationKey = 'notif_history_migrated_v2';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    try {
      final timezoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneName));
    } catch (_) {
      // Fall back to package default if timezone lookup fails.
    }

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      defaultPresentAlert: true,
      defaultPresentBadge: true,
      defaultPresentSound: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _plugin.initialize(settings);
    _initialized = true;
  }

  Future<bool> requestPermissions() async {
    await initialize();

    var granted = true;

    if (Platform.isIOS) {
      final iosImplementation = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      final iosGranted = await iosImplementation?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      granted = granted && (iosGranted ?? false);
    }

    if (Platform.isMacOS) {
      final macImplementation = _plugin
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >();
      final macGranted = await macImplementation?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      granted = granted && (macGranted ?? false);
    }

    if (Platform.isAndroid) {
      final androidImplementation = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final androidGranted = await androidImplementation
          ?.requestNotificationsPermission();
      granted = granted && (androidGranted ?? true);
    }

    return granted;
  }

  Future<void> applySettings(NotificationPreferences preferences) async {
    await initialize();
    await _cancelManagedNotifications();

    if (!preferences.hasEnabledNotifications) return;

    if (preferences.pantryReminderEnabled) {
      await _scheduleDaily(
        id: _pantryId,
        time: preferences.pantryReminderTime,
        title: _localized(preferences.localeCode).pantryTitle,
        body: _localized(preferences.localeCode).pantryBody,
      );
    }

    if (preferences.mealRemindersEnabled) {
      final copy = _localized(preferences.localeCode);
      await _scheduleDaily(
        id: _breakfastId,
        time: preferences.breakfastReminderTime,
        title: copy.breakfastTitle,
        body: copy.breakfastBody,
      );
      await _scheduleDaily(
        id: _lunchId,
        time: preferences.lunchReminderTime,
        title: copy.lunchTitle,
        body: copy.lunchBody,
      );
      await _scheduleDaily(
        id: _dinnerId,
        time: preferences.dinnerReminderTime,
        title: copy.dinnerTitle,
        body: copy.dinnerBody,
      );
    }

    if (preferences.weeklySummaryEnabled) {
      final copy = _localized(preferences.localeCode);
      await _scheduleWeekly(
        id: _weeklySummaryId,
        weekday: preferences.weeklySummaryWeekday,
        time: preferences.weeklySummaryTime,
        title: copy.weeklyTitle,
        body: copy.weeklyBody,
      );
    }
  }

  Future<void> syncReminderInbox(NotificationPreferences preferences) async {
    await initialize();
    final prefs = await SharedPreferences.getInstance();
    final now = tz.TZDateTime.now(tz.local);
    final copy = _localized(preferences.localeCode);

    final reminders = <_ReminderSchedule>[
      if (preferences.pantryReminderEnabled)
        _ReminderSchedule.daily(
          storageKey: '$_historyKeyPrefix$_pantryId',
          time: preferences.pantryReminderTime,
          title: copy.pantryTitle,
          body: copy.pantryBody,
        ),
      if (preferences.mealRemindersEnabled) ...[
        _ReminderSchedule.daily(
          storageKey: '$_historyKeyPrefix$_breakfastId',
          time: preferences.breakfastReminderTime,
          title: copy.breakfastTitle,
          body: copy.breakfastBody,
        ),
        _ReminderSchedule.daily(
          storageKey: '$_historyKeyPrefix$_lunchId',
          time: preferences.lunchReminderTime,
          title: copy.lunchTitle,
          body: copy.lunchBody,
        ),
        _ReminderSchedule.daily(
          storageKey: '$_historyKeyPrefix$_dinnerId',
          time: preferences.dinnerReminderTime,
          title: copy.dinnerTitle,
          body: copy.dinnerBody,
        ),
      ],
      if (preferences.weeklySummaryEnabled)
        _ReminderSchedule.weekly(
          storageKey: '$_historyKeyPrefix$_weeklySummaryId',
          weekday: preferences.weeklySummaryWeekday,
          time: preferences.weeklySummaryTime,
          title: copy.weeklyTitle,
          body: copy.weeklyBody,
        ),
    ];

    final shouldResetSyntheticHistory =
        prefs.getBool(_historyMigrationKey) != true;
    if (shouldResetSyntheticHistory) {
      final knownSources = <String>{
        ..._allReminderTitlesForLocale('ru'),
        ..._allReminderTitlesForLocale('en'),
      };
      await AppFeedbackCenter.instance.removeEntriesWhere(
        (entry) => knownSources.contains(entry.source),
      );
      for (final reminder in reminders) {
        await prefs.setString(reminder.storageKey, now.toIso8601String());
      }
      await prefs.setBool(_historyMigrationKey, true);
    }

    for (final reminder in reminders) {
      final lastTrackedRaw = prefs.getString(reminder.storageKey);
      if (lastTrackedRaw == null || lastTrackedRaw.trim().isEmpty) {
        await prefs.setString(reminder.storageKey, now.toIso8601String());
        continue;
      }

      final lastTracked =
          DateTime.tryParse(lastTrackedRaw)?.toLocal() ?? now.toLocal();
      final occurrences = reminder.occurrencesBetween(
        startExclusive: lastTracked,
        endInclusive: now,
      );
      if (occurrences.isEmpty) continue;

      for (final occurrence in occurrences) {
        await AppFeedbackCenter.instance.recordInboxEntry(
          source: reminder.title,
          message: reminder.body,
          createdAt: occurrence,
        );
      }

      await prefs.setString(
        reminder.storageKey,
        occurrences.last.toIso8601String(),
      );
    }
  }

  Set<String> _allReminderTitlesForLocale(String localeCode) {
    final copy = _localized(localeCode);
    return {
      copy.pantryTitle,
      copy.breakfastTitle,
      copy.lunchTitle,
      copy.dinnerTitle,
      copy.weeklyTitle,
    };
  }

  Future<void> _cancelManagedNotifications() async {
    for (final id in const [
      _pantryId,
      _breakfastId,
      _lunchId,
      _dinnerId,
      _weeklySummaryId,
    ]) {
      await _plugin.cancel(id);
    }
  }

  Future<void> _scheduleDaily({
    required int id,
    required TimeOfDay time,
    required String title,
    required String body,
  }) {
    final scheduledAt = _nextInstanceOfTime(time.hour, time.minute);
    return _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduledAt,
      _details(),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'wellbeing-reminder',
    );
  }

  Future<void> _scheduleWeekly({
    required int id,
    required int weekday,
    required TimeOfDay time,
    required String title,
    required String body,
  }) {
    final scheduledAt = _nextInstanceOfWeekdayAndTime(
      weekday,
      time.hour,
      time.minute,
    );
    return _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduledAt,
      _details(),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      payload: 'wellbeing-reminder',
    );
  }

  NotificationDetails _details() {
    const android = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
    );
    const darwin = DarwinNotificationDetails();
    return const NotificationDetails(
      android: android,
      iOS: darwin,
      macOS: darwin,
    );
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledAt = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!scheduledAt.isAfter(now)) {
      scheduledAt = scheduledAt.add(const Duration(days: 1));
    }
    return scheduledAt;
  }

  tz.TZDateTime _nextInstanceOfWeekdayAndTime(
    int weekday,
    int hour,
    int minute,
  ) {
    var scheduledAt = _nextInstanceOfTime(hour, minute);
    while (scheduledAt.weekday != weekday) {
      scheduledAt = scheduledAt.add(const Duration(days: 1));
    }
    return scheduledAt;
  }

  _NotificationCopy _localized(String localeCode) {
    if (localeCode.toLowerCase() == 'ru') {
      return const _NotificationCopy(
        pantryTitle: 'Проверь pantry',
        pantryBody:
            'Загляни в запасы: продукты могут скоро закончиться или испортиться.',
        breakfastTitle: 'Пора записать завтрак',
        breakfastBody: 'Сохрани приём пищи, чтобы аналитика оставалась точной.',
        lunchTitle: 'Не забудь про обед',
        lunchBody:
            'Добавь приём пищи в дневник и держи прогресс под контролем.',
        dinnerTitle: 'Проверь дневник питания',
        dinnerBody: 'Запиши ужин, чтобы дневная сводка была полной.',
        weeklyTitle: 'Итоги недели готовы',
        weeklyBody: 'Открой аналитику и посмотри прогресс по калориям и БЖУ.',
      );
    }

    return const _NotificationCopy(
      pantryTitle: 'Check your pantry',
      pantryBody:
          'Review your stored items before something expires or runs out.',
      breakfastTitle: 'Log your breakfast',
      breakfastBody: 'Save the meal so your nutrition analytics stay accurate.',
      lunchTitle: 'Time to log lunch',
      lunchBody: 'Add today’s meal entry and keep your progress visible.',
      dinnerTitle: 'Update your food diary',
      dinnerBody:
          'Record dinner so your daily nutrition summary stays complete.',
      weeklyTitle: 'Your weekly summary is ready',
      weeklyBody: 'Open analytics to review calories and macro progress.',
    );
  }
}

class _NotificationCopy {
  final String pantryTitle;
  final String pantryBody;
  final String breakfastTitle;
  final String breakfastBody;
  final String lunchTitle;
  final String lunchBody;
  final String dinnerTitle;
  final String dinnerBody;
  final String weeklyTitle;
  final String weeklyBody;

  const _NotificationCopy({
    required this.pantryTitle,
    required this.pantryBody,
    required this.breakfastTitle,
    required this.breakfastBody,
    required this.lunchTitle,
    required this.lunchBody,
    required this.dinnerTitle,
    required this.dinnerBody,
    required this.weeklyTitle,
    required this.weeklyBody,
  });
}

class _ReminderSchedule {
  const _ReminderSchedule._({
    required this.storageKey,
    required this.title,
    required this.body,
    required this.hour,
    required this.minute,
    this.weekday,
  });

  factory _ReminderSchedule.daily({
    required String storageKey,
    required TimeOfDay time,
    required String title,
    required String body,
  }) {
    return _ReminderSchedule._(
      storageKey: storageKey,
      title: title,
      body: body,
      hour: time.hour,
      minute: time.minute,
    );
  }

  factory _ReminderSchedule.weekly({
    required String storageKey,
    required int weekday,
    required TimeOfDay time,
    required String title,
    required String body,
  }) {
    return _ReminderSchedule._(
      storageKey: storageKey,
      title: title,
      body: body,
      hour: time.hour,
      minute: time.minute,
      weekday: weekday,
    );
  }

  final String storageKey;
  final String title;
  final String body;
  final int hour;
  final int minute;
  final int? weekday;

  List<DateTime> occurrencesBetween({
    required DateTime startExclusive,
    required DateTime endInclusive,
  }) {
    if (!endInclusive.isAfter(startExclusive)) return const [];

    if (weekday == null) {
      return _dailyOccurrencesBetween(
        startExclusive: startExclusive,
        endInclusive: endInclusive,
      );
    }

    return _weeklyOccurrencesBetween(
      startExclusive: startExclusive,
      endInclusive: endInclusive,
    );
  }

  List<DateTime> _dailyOccurrencesBetween({
    required DateTime startExclusive,
    required DateTime endInclusive,
  }) {
    var occurrence = tz.TZDateTime(
      tz.local,
      startExclusive.year,
      startExclusive.month,
      startExclusive.day,
      hour,
      minute,
    );
    if (!occurrence.isAfter(startExclusive)) {
      occurrence = occurrence.add(const Duration(days: 1));
    }

    final result = <DateTime>[];
    while (!occurrence.isAfter(endInclusive)) {
      result.add(occurrence.toLocal());
      occurrence = occurrence.add(const Duration(days: 1));
    }
    return result;
  }

  List<DateTime> _weeklyOccurrencesBetween({
    required DateTime startExclusive,
    required DateTime endInclusive,
  }) {
    var occurrence = tz.TZDateTime(
      tz.local,
      startExclusive.year,
      startExclusive.month,
      startExclusive.day,
      hour,
      minute,
    );
    while (occurrence.weekday != weekday ||
        !occurrence.isAfter(startExclusive)) {
      occurrence = occurrence.add(const Duration(days: 1));
    }

    final result = <DateTime>[];
    while (!occurrence.isAfter(endInclusive)) {
      result.add(occurrence.toLocal());
      occurrence = occurrence.add(const Duration(days: 7));
    }
    return result;
  }
}
