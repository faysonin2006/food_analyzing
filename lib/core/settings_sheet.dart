import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'app_notifications.dart';
import 'app_scope.dart';
import 'tr.dart';

Future<void> showAppSettingsSheet(BuildContext context) {
  final settings = AppScope.settingsOf(context);

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (sheetContext) {
      return AnimatedBuilder(
        animation: settings,
        builder: (_, _) {
          final mediaQuery = MediaQuery.of(sheetContext);
          return ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: mediaQuery.size.height * 0.88,
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                16 + mediaQuery.viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          tr(sheetContext, 'settings'),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        tooltip: MaterialLocalizations.of(
                          sheetContext,
                        ).closeButtonTooltip,
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: settings.isDark,
                    onChanged: settings.toggleDark,
                    title: Text(tr(sheetContext, 'theme_dark')),
                  ),
                  ListTile(
                    title: Text(tr(sheetContext, 'language')),
                    subtitle: Text(
                      settings.locale.languageCode == 'ru'
                          ? tr(sheetContext, 'lang_ru')
                          : tr(sheetContext, 'lang_en'),
                    ),
                    trailing: DropdownButton<String>(
                      value: settings.locale.languageCode,
                      items: [
                        DropdownMenuItem(
                          value: 'ru',
                          child: Text(tr(sheetContext, 'lang_ru')),
                        ),
                        DropdownMenuItem(
                          value: 'en',
                          child: Text(tr(sheetContext, 'lang_en')),
                        ),
                      ],
                      onChanged: (v) async {
                        if (v == null) return;
                        await settings.setLocale(Locale(v));
                        await AppNotifications.instance.applySettings(
                          settings.notificationPreferences,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      tr(sheetContext, 'notifications'),
                      style: Theme.of(sheetContext).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    value: settings.pantryReminderEnabled,
                    onChanged: (value) async {
                      if (value &&
                          !await _requestNotificationsPermission(
                            sheetContext,
                          )) {
                        return;
                      }
                      await settings.setPantryReminderEnabled(value);
                      await AppNotifications.instance.applySettings(
                        settings.notificationPreferences,
                      );
                    },
                    title: Text(tr(sheetContext, 'pantry_reminder')),
                    subtitle: Text(
                      tr(sheetContext, 'pantry_reminder_subtitle'),
                    ),
                  ),
                  if (settings.pantryReminderEnabled)
                    ListTile(
                      contentPadding: const EdgeInsets.only(left: 16, right: 4),
                      title: Text(tr(sheetContext, 'reminder_time')),
                      subtitle: Text(
                        _formatTime(sheetContext, settings.pantryReminderTime),
                      ),
                      trailing: const Icon(Icons.schedule_rounded),
                      onTap: () async {
                        final picked = await _pickTime(
                          sheetContext,
                          settings.pantryReminderTime,
                        );
                        if (picked == null) return;
                        await settings.setPantryReminderTime(picked);
                        await AppNotifications.instance.applySettings(
                          settings.notificationPreferences,
                        );
                      },
                    ),
                  const Divider(height: 24),
                  SwitchListTile(
                    value: settings.mealRemindersEnabled,
                    onChanged: (value) async {
                      if (value &&
                          !await _requestNotificationsPermission(
                            sheetContext,
                          )) {
                        return;
                      }
                      await settings.setMealRemindersEnabled(value);
                      await AppNotifications.instance.applySettings(
                        settings.notificationPreferences,
                      );
                    },
                    title: Text(tr(sheetContext, 'meal_reminders')),
                    subtitle: Text(tr(sheetContext, 'meal_reminders_subtitle')),
                  ),
                  if (settings.mealRemindersEnabled) ...[
                    _timeTile(
                      context: sheetContext,
                      title: tr(sheetContext, 'breakfast_reminder'),
                      value: settings.breakfastReminderTime,
                      onPicked: (picked) async {
                        await settings.setBreakfastReminderTime(picked);
                        await AppNotifications.instance.applySettings(
                          settings.notificationPreferences,
                        );
                      },
                    ),
                    _timeTile(
                      context: sheetContext,
                      title: tr(sheetContext, 'lunch_reminder'),
                      value: settings.lunchReminderTime,
                      onPicked: (picked) async {
                        await settings.setLunchReminderTime(picked);
                        await AppNotifications.instance.applySettings(
                          settings.notificationPreferences,
                        );
                      },
                    ),
                    _timeTile(
                      context: sheetContext,
                      title: tr(sheetContext, 'dinner_reminder'),
                      value: settings.dinnerReminderTime,
                      onPicked: (picked) async {
                        await settings.setDinnerReminderTime(picked);
                        await AppNotifications.instance.applySettings(
                          settings.notificationPreferences,
                        );
                      },
                    ),
                  ],
                  const Divider(height: 24),
                  SwitchListTile(
                    value: settings.weeklySummaryEnabled,
                    onChanged: (value) async {
                      if (value &&
                          !await _requestNotificationsPermission(
                            sheetContext,
                          )) {
                        return;
                      }
                      await settings.setWeeklySummaryEnabled(value);
                      await AppNotifications.instance.applySettings(
                        settings.notificationPreferences,
                      );
                    },
                    title: Text(tr(sheetContext, 'weekly_summary')),
                    subtitle: Text(tr(sheetContext, 'weekly_summary_subtitle')),
                  ),
                  if (settings.weeklySummaryEnabled) ...[
                    ListTile(
                      contentPadding: const EdgeInsets.only(left: 16, right: 4),
                      title: Text(tr(sheetContext, 'weekly_summary_day')),
                      subtitle: Text(
                        _weekdayLabel(
                          sheetContext,
                          settings.weeklySummaryWeekday,
                        ),
                      ),
                      trailing: SizedBox(
                        width: 150,
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            isExpanded: true,
                            value: settings.weeklySummaryWeekday,
                            items: List.generate(7, (index) {
                              final weekday = DateTime.monday + index;
                              return DropdownMenuItem(
                                value: weekday,
                                child: Text(
                                  _weekdayLabel(sheetContext, weekday),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }),
                            onChanged: (value) async {
                              if (value == null) return;
                              await settings.setWeeklySummaryWeekday(value);
                              await AppNotifications.instance.applySettings(
                                settings.notificationPreferences,
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    _timeTile(
                      context: sheetContext,
                      title: tr(sheetContext, 'reminder_time'),
                      value: settings.weeklySummaryTime,
                      onPicked: (picked) async {
                        await settings.setWeeklySummaryTime(picked);
                        await AppNotifications.instance.applySettings(
                          settings.notificationPreferences,
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

Widget _timeTile({
  required BuildContext context,
  required String title,
  required TimeOfDay value,
  required Future<void> Function(TimeOfDay picked) onPicked,
}) {
  return ListTile(
    contentPadding: const EdgeInsets.only(left: 16, right: 4),
    title: Text(title),
    subtitle: Text(_formatTime(context, value)),
    trailing: const Icon(Icons.schedule_rounded),
    onTap: () async {
      final picked = await _pickTime(context, value);
      if (picked == null) return;
      await onPicked(picked);
    },
  );
}

Future<TimeOfDay?> _pickTime(BuildContext context, TimeOfDay initialValue) {
  return showTimePicker(context: context, initialTime: initialValue);
}

String _formatTime(BuildContext context, TimeOfDay value) {
  return MaterialLocalizations.of(context).formatTimeOfDay(value);
}

String _weekdayLabel(BuildContext context, int weekday) {
  switch (weekday) {
    case DateTime.monday:
      return tr(context, 'weekday_mon');
    case DateTime.tuesday:
      return tr(context, 'weekday_tue');
    case DateTime.wednesday:
      return tr(context, 'weekday_wed');
    case DateTime.thursday:
      return tr(context, 'weekday_thu');
    case DateTime.friday:
      return tr(context, 'weekday_fri');
    case DateTime.saturday:
      return tr(context, 'weekday_sat');
    default:
      return tr(context, 'weekday_sun');
  }
}

Future<bool> _requestNotificationsPermission(BuildContext context) async {
  final granted = await AppNotifications.instance.requestPermissions();
  if (granted || !context.mounted) return granted;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(tr(context, 'notifications_permission_denied')),
      action: SnackBarAction(
        label: tr(context, 'open_settings'),
        onPressed: openAppSettings,
      ),
    ),
  );
  return false;
}
