import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'atelier_ui.dart';
import 'app_scope.dart';
import 'notification_preferences.dart';
import 'settings_sheet.dart';
import 'tr.dart';

enum AppFeedbackKind { info, success, error }

Future<void> showAppFeedback(
  BuildContext context,
  String message, {
  AppFeedbackKind? kind,
  String? source,
  bool preferPopup = false,
  bool addToInbox = false,
}) {
  return AppFeedbackCenter.instance.show(
    context,
    message,
    kind: kind,
    source: source,
    preferPopup: preferPopup,
    addToInbox: addToInbox,
  );
}

@immutable
class AppFeedbackEntry {
  const AppFeedbackEntry({
    required this.id,
    required this.message,
    required this.kind,
    required this.createdAt,
    required this.isRead,
    this.source,
  });

  final String id;
  final String message;
  final AppFeedbackKind kind;
  final DateTime createdAt;
  final bool isRead;
  final String? source;

  AppFeedbackEntry copyWith({
    String? id,
    String? message,
    AppFeedbackKind? kind,
    DateTime? createdAt,
    bool? isRead,
    String? source,
  }) {
    return AppFeedbackEntry(
      id: id ?? this.id,
      message: message ?? this.message,
      kind: kind ?? this.kind,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      source: source ?? this.source,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'message': message,
      'kind': kind.name,
      'createdAt': createdAt.toIso8601String(),
      'isRead': isRead,
      'source': source,
    };
  }

  factory AppFeedbackEntry.fromMap(Map<String, dynamic> map) {
    return AppFeedbackEntry(
      id: map['id']?.toString() ?? DateTime.now().toIso8601String(),
      message: map['message']?.toString() ?? '',
      kind: AppFeedbackKind.values.firstWhere(
        (value) => value.name == map['kind'],
        orElse: () => AppFeedbackKind.info,
      ),
      createdAt:
          DateTime.tryParse(map['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      isRead: map['isRead'] == true,
      source: map['source']?.toString(),
    );
  }
}

class AppFeedbackCenter extends ChangeNotifier {
  AppFeedbackCenter._();

  static final AppFeedbackCenter instance = AppFeedbackCenter._();

  static const _prefsKey = 'app_feedback_entries_v1';
  static const _maxEntries = 40;
  static const _entryDedupWindow = Duration(seconds: 20);
  static const _popupDedupWindow = Duration(seconds: 4);

  bool _initialized = false;
  List<AppFeedbackEntry> _entries = const [];
  DateTime? _lastPopupAt;
  String? _lastPopupKey;

  List<AppFeedbackEntry> get entries => List.unmodifiable(_entries);
  int get unreadCount => _entries.where((entry) => !entry.isRead).length;

  Future<void> initialize() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _entries =
              decoded
                  .whereType<Map>()
                  .map(
                    (map) => AppFeedbackEntry.fromMap(
                      Map<String, dynamic>.from(map),
                    ),
                  )
                  .toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        }
      } catch (_) {}
    }
    _initialized = true;
  }

  Future<void> show(
    BuildContext context,
    String message, {
    AppFeedbackKind? kind,
    String? source,
    bool preferPopup = false,
    bool addToInbox = false,
  }) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    await initialize();
    final normalized = _normalizeMessage(message);
    if (normalized.isEmpty) return;

    final resolvedKind = kind ?? _inferKind(normalized);
    final popupKey = '${resolvedKind.name}|${normalized.split('\n').first}';

    if (addToInbox) {
      await _record(message: normalized, kind: resolvedKind, source: source);
    }

    if (!_shouldShowPopup(
      popupKey: popupKey,
      kind: resolvedKind,
      preferPopup: preferPopup,
    )) {
      return;
    }

    if (messenger == null) return;

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(_popupMessage(normalized)),
          behavior: SnackBarBehavior.floating,
          duration: Duration(
            seconds: resolvedKind == AppFeedbackKind.error ? 4 : 2,
          ),
        ),
      );
  }

  Future<void> recordInboxEntry({
    required String message,
    AppFeedbackKind kind = AppFeedbackKind.info,
    String? source,
    DateTime? createdAt,
    bool isRead = false,
  }) async {
    await initialize();
    final normalized = _normalizeMessage(message);
    if (normalized.isEmpty) return;
    await _record(
      message: normalized,
      kind: kind,
      source: source,
      createdAt: createdAt,
      isRead: isRead,
    );
  }

  Future<void> markAllRead() async {
    await initialize();
    if (_entries.every((entry) => entry.isRead)) return;
    _entries = [for (final entry in _entries) entry.copyWith(isRead: true)];
    await _persist();
    notifyListeners();
  }

  Future<void> clear() async {
    await initialize();
    _entries = const [];
    await _persist();
    notifyListeners();
  }

  Future<void> removeEntriesWhere(
    bool Function(AppFeedbackEntry entry) predicate,
  ) async {
    await initialize();
    final updated = _entries.where((entry) => !predicate(entry)).toList();
    if (updated.length == _entries.length) return;
    _entries = updated;
    await _persist();
    notifyListeners();
  }

  Future<void> _record({
    required String message,
    required AppFeedbackKind kind,
    String? source,
    DateTime? createdAt,
    bool isRead = false,
  }) async {
    final timestamp = createdAt ?? DateTime.now();
    final existingIndex = _entries.indexWhere((entry) {
      final samePayload =
          entry.message == message &&
          entry.kind == kind &&
          entry.source == source;
      if (!samePayload) return false;
      return timestamp.difference(entry.createdAt).abs() <= _entryDedupWindow;
    });

    if (existingIndex >= 0) {
      final existing = _entries[existingIndex];
      final updated = existing.copyWith(createdAt: timestamp, isRead: isRead);
      _entries = [
        updated,
        ..._entries.where((entry) => entry.id != existing.id),
      ];
    } else {
      final entry = AppFeedbackEntry(
        id: timestamp.microsecondsSinceEpoch.toString(),
        message: message,
        kind: kind,
        createdAt: timestamp,
        isRead: isRead,
        source: source,
      );
      _entries = [entry, ..._entries].take(_maxEntries).toList();
    }

    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode(_entries.map((entry) => entry.toMap()).toList()),
    );
  }

  bool _shouldShowPopup({
    required String popupKey,
    required AppFeedbackKind kind,
    required bool preferPopup,
  }) {
    final now = DateTime.now();
    final shouldPopup = preferPopup;
    if (!shouldPopup) return false;
    if (_lastPopupKey == popupKey &&
        _lastPopupAt != null &&
        now.difference(_lastPopupAt!) <= _popupDedupWindow) {
      return false;
    }
    _lastPopupKey = popupKey;
    _lastPopupAt = now;
    return true;
  }

  String _normalizeMessage(String message) {
    return message
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .join('\n')
        .trim();
  }

  String _popupMessage(String fullMessage) {
    final firstLine = fullMessage.split('\n').first.trim();
    if (firstLine.length <= 110) return firstLine;
    return '${firstLine.substring(0, 107)}...';
  }

  AppFeedbackKind _inferKind(String message) {
    final lower = message.toLowerCase();
    const errorHints = [
      'ошибка',
      'не удалось',
      'доступ запрещен',
      'нет доступа',
      'не все',
      'недоступ',
      'failed',
      'error',
      'unable',
      'forbidden',
      'unauthorized',
      'denied',
      'timeout',
      'not all',
    ];
    for (final hint in errorHints) {
      if (lower.contains(hint)) return AppFeedbackKind.error;
    }

    const successHints = [
      'успеш',
      'сохран',
      'создан',
      'добавлен',
      'удален',
      'обновлен',
      'saved',
      'created',
      'added',
      'removed',
      'updated',
    ];
    for (final hint in successHints) {
      if (lower.contains(hint)) return AppFeedbackKind.success;
    }

    return AppFeedbackKind.info;
  }
}

Future<void> showAppInboxSheet(BuildContext context) async {
  await AppFeedbackCenter.instance.initialize();
  await AppFeedbackCenter.instance.markAllRead();

  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) {
      final settings = AppScope.settingsOf(sheetContext);
      return StatefulBuilder(
        builder: (sheetContext, setSheetState) => AnimatedBuilder(
          animation: AppFeedbackCenter.instance,
          builder: (_, _) {
            final entries = AppFeedbackCenter.instance.entries;
            final reminders = _buildReminderRows(
              sheetContext,
              settings.notificationPreferences,
            );
            final groupedEntries = _groupInboxEntries(sheetContext, entries);

            return ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(sheetContext).size.height * 0.94,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AtelierSheetHeader(
                      title: tr(sheetContext, 'notifications'),
                      subtitle: tr(
                        sheetContext,
                        'notifications_inbox_subtitle',
                      ),
                      trailing: TextButton(
                        onPressed: entries.isEmpty
                            ? null
                            : () => AppFeedbackCenter.instance.clear(),
                        child: Text(tr(sheetContext, 'clear_history')),
                      ),
                      onClose: () => Navigator.of(sheetContext).maybePop(),
                    ),
                    if (reminders.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _InboxBlock(
                        title:
                            '${tr(sheetContext, 'reminders_section')} • ${reminders.length}',
                        child: Column(
                          children: [
                            ...reminders,
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.of(sheetContext).pop();
                                  showAppSettingsSheet(context);
                                },
                                icon: const Icon(Icons.tune_rounded),
                                label: Text(
                                  tr(sheetContext, 'manage_reminders'),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    _InboxSectionTitle(
                      text: tr(sheetContext, 'history_section'),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: entries.isEmpty
                          ? _EmptyInboxCard(
                              message: tr(
                                sheetContext,
                                'notifications_empty_history',
                              ),
                            )
                          : ListView.separated(
                              itemCount: groupedEntries.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final group = groupedEntries[index];
                                return _InboxBlock(
                                  title: group.label,
                                  child: Column(
                                    children: [
                                      for (
                                        var i = 0;
                                        i < group.entries.length;
                                        i++
                                      ) ...[
                                        _FeedbackEntryCard(
                                          entry: group.entries[i],
                                        ),
                                        if (i != group.entries.length - 1)
                                          const SizedBox(height: 8),
                                      ],
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    },
  );
}

List<Widget> _buildReminderRows(
  BuildContext context,
  NotificationPreferences preferences,
) {
  if (!preferences.hasEnabledNotifications) return const [];

  final rows = <Widget>[];
  if (preferences.pantryReminderEnabled) {
    rows.add(
      _ReminderRow(
        icon: Icons.kitchen_rounded,
        title: tr(context, 'pantry_reminder'),
        subtitle: _formatTime(context, preferences.pantryReminderTime),
      ),
    );
  }
  if (preferences.mealRemindersEnabled) {
    rows.add(
      _ReminderRow(
        icon: Icons.wb_sunny_outlined,
        title: tr(context, 'breakfast_reminder'),
        subtitle: _formatTime(context, preferences.breakfastReminderTime),
      ),
    );
    rows.add(
      _ReminderRow(
        icon: Icons.lunch_dining_rounded,
        title: tr(context, 'lunch_reminder'),
        subtitle: _formatTime(context, preferences.lunchReminderTime),
      ),
    );
    rows.add(
      _ReminderRow(
        icon: Icons.nightlight_round,
        title: tr(context, 'dinner_reminder'),
        subtitle: _formatTime(context, preferences.dinnerReminderTime),
      ),
    );
  }
  if (preferences.weeklySummaryEnabled) {
    rows.add(
      _ReminderRow(
        icon: Icons.insights_rounded,
        title: tr(context, 'weekly_summary'),
        subtitle:
            '${_weekdayLabel(context, preferences.weeklySummaryWeekday)} • ${_formatTime(context, preferences.weeklySummaryTime)}',
      ),
    );
  }
  return rows;
}

List<_InboxHistoryGroup> _groupInboxEntries(
  BuildContext context,
  List<AppFeedbackEntry> entries,
) {
  final isRu = Localizations.localeOf(context).languageCode == 'ru';
  final now = DateTime.now();
  final grouped = <String, List<AppFeedbackEntry>>{};

  String bucketLabel(DateTime value) {
    final day = DateTime(value.year, value.month, value.day);
    final today = DateTime(now.year, now.month, now.day);
    final delta = today.difference(day).inDays;
    if (delta == 0) return isRu ? 'Сегодня' : 'Today';
    if (delta == 1) return isRu ? 'Вчера' : 'Yesterday';
    final dd = value.day.toString().padLeft(2, '0');
    final mm = value.month.toString().padLeft(2, '0');
    final yyyy = value.year.toString();
    return isRu ? '$dd.$mm.$yyyy' : '$yyyy-$mm-$dd';
  }

  for (final entry in entries) {
    final label = bucketLabel(entry.createdAt);
    grouped.putIfAbsent(label, () => <AppFeedbackEntry>[]).add(entry);
  }

  return grouped.entries
      .map(
        (entry) => _InboxHistoryGroup(label: entry.key, entries: entry.value),
      )
      .toList(growable: false);
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

class _InboxSectionTitle extends StatelessWidget {
  const _InboxSectionTitle({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
    );
  }
}

class _InboxBlock extends StatelessWidget {
  const _InboxBlock({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _EmptyInboxCard extends StatelessWidget {
  const _EmptyInboxCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Text(
        message,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
      ),
    );
  }
}

class _ReminderRow extends StatelessWidget {
  const _ReminderRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: cs.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedbackEntryCard extends StatelessWidget {
  const _FeedbackEntryCard({required this.entry});

  final AppFeedbackEntry entry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (icon, color) = switch (entry.kind) {
      AppFeedbackKind.error => (Icons.error_outline_rounded, cs.error),
      AppFeedbackKind.success => (
        Icons.check_circle_outline_rounded,
        cs.primary,
      ),
      AppFeedbackKind.info => (Icons.info_outline_rounded, cs.secondary),
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (entry.source != null && entry.source!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest.withValues(
                            alpha: 0.55,
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          entry.source!,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                    Text(
                      _formatEntryDate(context, entry.createdAt),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            entry.message,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(height: 1.3),
          ),
        ],
      ),
    );
  }
}

class _InboxHistoryGroup {
  const _InboxHistoryGroup({required this.label, required this.entries});

  final String label;
  final List<AppFeedbackEntry> entries;
}

String _formatEntryDate(BuildContext context, DateTime value) {
  final now = DateTime.now();
  final isSameDay =
      now.year == value.year &&
      now.month == value.month &&
      now.day == value.day;
  final time = MaterialLocalizations.of(
    context,
  ).formatTimeOfDay(TimeOfDay.fromDateTime(value));
  if (isSameDay) return time;
  return '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')} $time';
}
