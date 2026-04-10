import 'package:flutter/material.dart';

@immutable
class NotificationPreferences {
  final String localeCode;
  final bool pantryReminderEnabled;
  final TimeOfDay pantryReminderTime;
  final bool mealRemindersEnabled;
  final TimeOfDay breakfastReminderTime;
  final TimeOfDay lunchReminderTime;
  final TimeOfDay dinnerReminderTime;
  final bool weeklySummaryEnabled;
  final int weeklySummaryWeekday;
  final TimeOfDay weeklySummaryTime;

  const NotificationPreferences({
    required this.localeCode,
    required this.pantryReminderEnabled,
    required this.pantryReminderTime,
    required this.mealRemindersEnabled,
    required this.breakfastReminderTime,
    required this.lunchReminderTime,
    required this.dinnerReminderTime,
    required this.weeklySummaryEnabled,
    required this.weeklySummaryWeekday,
    required this.weeklySummaryTime,
  });

  bool get hasEnabledNotifications =>
      pantryReminderEnabled || mealRemindersEnabled || weeklySummaryEnabled;
}
