import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/app_feedback.dart';
import '../core/atelier_ui.dart';
import '../core/app_top_bar.dart';
import '../core/settings_sheet.dart';
import '../core/food_suggestions.dart';
import '../core/suggestion_panel.dart';
import '../repositories/app_repository.dart';
import '../services/api_service.dart';
import 'analytics_screen.dart';
import 'household_screen.dart';
import 'meal_history_screen.dart';
import 'pantry_screen.dart';
import 'shopping_list_screen.dart';

class OrganizerHubScreen extends StatefulWidget {
  const OrganizerHubScreen({super.key});

  @override
  State<OrganizerHubScreen> createState() => _OrganizerHubScreenState();
}

class _OrganizerHubScreenState extends State<OrganizerHubScreen> {
  final AppRepository repository = AppRepository.instance;

  bool _didScheduleInitialLoad = false;
  Map<String, dynamic>? _dailyAnalytics;
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _expiringPantry = const [];
  List<Map<String, dynamic>> _shoppingItems = const [];
  List<Map<String, dynamic>> _householdInvitations = const [];

  bool get _isRu => Localizations.localeOf(context).languageCode == 'ru';
  ThemeData get _theme => Theme.of(context);
  ColorScheme get _cs => _theme.colorScheme;
  bool get _isDark => _theme.brightness == Brightness.dark;
  String get _screenTitle => _isRu ? 'Органайзер' : 'Organizer';
  Color get _screenBackground => _theme.scaffoldBackgroundColor;
  Color get _panelBackground => _isDark
      ? Color.alphaBlend(
          _cs.surfaceContainerHighest.withValues(alpha: 0.56),
          _cs.surface,
        )
      : const Color(0xFFF6F6F7);

  String _errorText(Object error, String fallback) {
    if (error is ApiException) return error.message;
    final text = error.toString().trim();
    if (text.isEmpty) return fallback;
    return text.startsWith('Exception: ') ? text.substring(11) : text;
  }

  Future<T> _loadWithFallback<T>({
    required Future<T> future,
    required T fallback,
    required List<String> errors,
    required String fallbackMessage,
  }) async {
    try {
      return await future;
    } catch (error) {
      errors.add(_errorText(error, fallbackMessage));
      return fallback;
    }
  }

  void _showMessage(
    String message, {
    AppFeedbackKind? kind,
    bool preferPopup = false,
    bool addToInbox = true,
  }) {
    if (!mounted) return;
    showAppFeedback(
      context,
      message,
      kind: kind,
      source: _screenTitle,
      preferPopup: preferPopup,
      addToInbox: addToInbox,
    );
  }

  void _showLoadWarnings(List<String> errors) {
    if (!mounted || errors.isEmpty) return;
    final details = errors.toSet().join('\n');
    final prefix = _isRu
        ? 'Не все блоки органайзера обновились.'
        : 'Not every organizer section was refreshed.';
    _showMessage('$prefix\n$details');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didScheduleInitialLoad) return;
    _didScheduleInitialLoad = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _load();
    });
  }

  Future<void> _load() async {
    final errors = <String>[];

    final dailyFuture = _loadWithFallback<Map<String, dynamic>?>(
      future: repository.getDailyAnalytics(),
      fallback: _dailyAnalytics,
      errors: errors,
      fallbackMessage: _isRu
          ? 'Не удалось загрузить аналитику за день'
          : 'Failed to load daily analytics',
    );
    final profileFuture = _loadWithFallback<Map<String, dynamic>?>(
      future: repository.getProfile(),
      fallback: _profile,
      errors: errors,
      fallbackMessage: _isRu
          ? 'Не удалось загрузить профиль'
          : 'Failed to load profile',
    );
    final expiringFuture = _loadWithFallback<List<Map<String, dynamic>>>(
      future: repository.getExpiringPantryItems(),
      fallback: _expiringPantry,
      errors: errors,
      fallbackMessage: _isRu
          ? 'Не удалось загрузить продукты с истекающим сроком'
          : 'Failed to load expiring pantry items',
    );
    final shoppingFuture = _loadWithFallback<List<Map<String, dynamic>>>(
      future: repository.getShoppingItems(),
      fallback: _shoppingItems,
      errors: errors,
      fallbackMessage: _isRu
          ? 'Не удалось загрузить список покупок'
          : 'Failed to load shopping list',
    );
    final invitationsFuture = _loadWithFallback<List<Map<String, dynamic>>>(
      future: repository.getMyHouseholdInvitations(),
      fallback: _householdInvitations,
      errors: errors,
      fallbackMessage: _isRu
          ? 'Не удалось загрузить приглашения в семью'
          : 'Failed to load household invitations',
    );

    final daily = await dailyFuture;
    final profile = await profileFuture;
    final expiring = await expiringFuture;
    final shopping = await shoppingFuture;
    final invitations = await invitationsFuture;

    if (!mounted) return;
    setState(() {
      _dailyAnalytics = daily;
      _profile = profile;
      _expiringPantry = expiring;
      _shoppingItems = shopping;
      _householdInvitations = invitations;
    });
    _showLoadWarnings(errors);
  }

  void _openScreen(Widget screen) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => screen)).then((_) => _load());
  }

  void _openMealHistory({bool openComposer = false}) {
    _openScreen(MealHistoryScreen(openComposerOnStart: openComposer));
  }

  String _formatDateTime(dynamic raw) {
    final date = DateTime.tryParse(raw?.toString() ?? '');
    if (date == null) return '-';
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    final hh = date.hour.toString().padLeft(2, '0');
    final mm = date.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  Future<void> _addMealQuick() async {
    final titleCtrl = TextEditingController();
    final caloriesCtrl = TextEditingController();
    final proteinsCtrl = TextEditingController();
    final fatsCtrl = TextEditingController();
    final carbsCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    var mealSuggestions = const <SuggestionOption>[];
    DateTime eatenAt = DateTime.now();

    void refreshMealSuggestions(StateSetter setSheetState) {
      final query = titleCtrl.text;
      final candidates = FoodSuggestions.collectMealSuggestions(isRu: _isRu);
      final local = FoodSuggestions.rankSuggestions(
        candidates,
        query: query,
        limit: 8,
      );
      setSheetState(() => mealSuggestions = local);
    }

    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => AtelierSheetFrame(
          title: _isRu ? 'Добавить приём пищи' : 'Add meal',
          subtitle: _isRu
              ? 'Сохрани съеденное сразу из органайзера, без перехода в историю.'
              : 'Save what you ate directly from organizer without opening history.',
          onClose: () => Navigator.of(context).pop(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AtelierFieldLabel(_isRu ? 'Название' : 'Title'),
              TextFieldTapRegion(
                child: Column(
                  children: [
                    TextField(
                      controller: titleCtrl,
                      onTap: () => refreshMealSuggestions(setSheetState),
                      onChanged: (_) => refreshMealSuggestions(setSheetState),
                      onTapOutside: (_) {
                        FocusScope.of(context).unfocus();
                        setSheetState(() {
                          mealSuggestions = const <SuggestionOption>[];
                        });
                      },
                      decoration: InputDecoration(
                        hintText: _isRu
                            ? 'Например, овсянка'
                            : 'For example, oatmeal',
                      ),
                    ),
                    if (mealSuggestions.isNotEmpty)
                      AtelierSuggestionPanel(
                        suggestions: mealSuggestions,
                        isRu: _isRu,
                        onSelected: (option) {
                          titleCtrl.text = option.primaryText;
                          titleCtrl.selection = TextSelection.collapsed(
                            offset: titleCtrl.text.length,
                          );
                          if (option.calories != null) {
                            caloriesCtrl.text = option.calories!.toString();
                          }
                          if (option.protein != null) {
                            proteinsCtrl.text = option.protein!.toStringAsFixed(
                              option.protein! >= 10 ? 0 : 1,
                            );
                          }
                          if (option.fat != null) {
                            fatsCtrl.text = option.fat!.toStringAsFixed(
                              option.fat! >= 10 ? 0 : 1,
                            );
                          }
                          if (option.carbs != null) {
                            carbsCtrl.text = option.carbs!.toStringAsFixed(
                              option.carbs! >= 10 ? 0 : 1,
                            );
                          }
                          FocusScope.of(context).unfocus();
                          setSheetState(() {
                            mealSuggestions = const <SuggestionOption>[];
                          });
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              AtelierFieldLabel(_isRu ? 'Калории' : 'Calories'),
              TextField(
                controller: caloriesCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(hintText: '420'),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AtelierFieldLabel(_isRu ? 'Белки' : 'Protein'),
                        TextField(
                          controller: proteinsCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(hintText: '18'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AtelierFieldLabel(_isRu ? 'Жиры' : 'Fats'),
                        TextField(
                          controller: fatsCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(hintText: '12'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AtelierFieldLabel(_isRu ? 'Углеводы' : 'Carbs'),
                        TextField(
                          controller: carbsCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(hintText: '48'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              AtelierSurfaceCard(
                radius: 22,
                padding: const EdgeInsets.all(14),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_isRu ? 'Время приёма пищи' : 'Eaten at'),
                  subtitle: Text(_formatDateTime(eatenAt.toIso8601String())),
                  trailing: const Icon(Icons.schedule_rounded),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: eatenAt,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date == null || !context.mounted) return;
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(eatenAt),
                    );
                    if (time == null) return;
                    setSheetState(() {
                      eatenAt = DateTime(
                        date.year,
                        date.month,
                        date.day,
                        time.hour,
                        time.minute,
                      );
                    });
                  },
                ),
              ),
              const SizedBox(height: 14),
              AtelierFieldLabel(_isRu ? 'Заметки' : 'Notes'),
              TextField(
                controller: notesCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: _isRu
                      ? 'Состав, настроение, комментарии'
                      : 'Ingredients, context, or notes',
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    if (titleCtrl.text.trim().isEmpty ||
                        caloriesCtrl.text.trim().isEmpty) {
                      return;
                    }
                    final meal = await repository.createMeal({
                      'title': titleCtrl.text.trim(),
                      'calories': int.tryParse(caloriesCtrl.text.trim()) ?? 0,
                      'proteins': double.tryParse(
                        proteinsCtrl.text.trim().replaceAll(',', '.'),
                      ),
                      'fats': double.tryParse(
                        fatsCtrl.text.trim().replaceAll(',', '.'),
                      ),
                      'carbohydrates': double.tryParse(
                        carbsCtrl.text.trim().replaceAll(',', '.'),
                      ),
                      'eatenAt': eatenAt.toIso8601String(),
                      'source': 'MANUAL',
                      'notes': notesCtrl.text.trim().isEmpty
                          ? null
                          : notesCtrl.text.trim(),
                    });
                    if (!context.mounted) return;
                    Navigator.of(context).pop(meal != null);
                  },
                  child: Text(_isRu ? 'Сохранить запись' : 'Save entry'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (created == true) {
      await _load();
    }
  }

  String _formatQuantityValue(dynamic raw) {
    if (raw is int) return raw.toString();
    if (raw is double) {
      return raw == raw.roundToDouble()
          ? raw.toInt().toString()
          : raw.toStringAsFixed(raw.truncateToDouble() == raw ? 0 : 1);
    }
    if (raw is num) {
      final asDouble = raw.toDouble();
      return asDouble == asDouble.roundToDouble()
          ? raw.toInt().toString()
          : raw.toString();
    }
    final text = raw?.toString().trim() ?? '';
    return text.isEmpty ? '-' : text;
  }

  String _unitLabel(String? raw) {
    switch ((raw ?? '').trim().toUpperCase()) {
      case 'PIECE':
        return _isRu ? 'шт' : 'pcs';
      case 'GRAM':
        return _isRu ? 'г' : 'g';
      case 'KILOGRAM':
        return _isRu ? 'кг' : 'kg';
      case 'MILLILITER':
        return _isRu ? 'мл' : 'ml';
      case 'LITER':
        return _isRu ? 'л' : 'l';
      case 'PACK':
        return _isRu ? 'уп.' : 'pack';
      case 'BOTTLE':
        return _isRu ? 'бут.' : 'bottle';
      case 'CAN':
        return _isRu ? 'банка' : 'can';
      default:
        return raw?.trim() ?? '';
    }
  }

  String _formatQuantity(Map<String, dynamic> item) {
    final quantity = _formatQuantityValue(item['quantity']);
    final unit = _unitLabel(item['unit']?.toString());
    return unit.isEmpty ? quantity : '$quantity $unit';
  }

  String _formatDate(dynamic raw) {
    final text = raw?.toString().trim() ?? '';
    if (text.isEmpty) return _isRu ? 'не указано' : 'not set';
    return text.split('T').first;
  }

  // ignore: unused_element
  Widget _summaryChip({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _overviewStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cs.surface.withValues(alpha: _isDark ? 0.28 : 0.62),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _cs.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _signalCard({
    required String eyebrow,
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(28),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            accent.withValues(alpha: _isDark ? 0.18 : 0.08),
            _panelBackground,
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: accent.withValues(alpha: 0.14)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: accent),
            ),
            const SizedBox(height: 22),
            Text(
              eyebrow.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: accent,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  height: 0.95,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                height: 1.28,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _spaceCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            color.withValues(alpha: _isDark ? 0.22 : 0.1),
            _panelBackground,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withValues(alpha: 0.16)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 26),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Text(
                subtitle,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  height: 1.24,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _readInt(dynamic value, [int fallback = 0]) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  double _readDouble(dynamic value, [double fallback = 0]) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  int _dailyTargetCalories() {
    final analyticsTarget = _readInt(
      _dailyAnalytics?['targetCalories'] ??
          _dailyAnalytics?['target_calories'] ??
          _dailyAnalytics?['goalCalories'] ??
          _dailyAnalytics?['goal_calories'],
      0,
    );
    if (analyticsTarget > 0) return analyticsTarget;

    final profileTarget = _readInt(
      _profile?['targetCaloriesPerDay'] ??
          _profile?['target_calories_per_day'] ??
          _profile?['targetCalories'] ??
          _profile?['dailyCalories'],
      0,
    );
    if (profileTarget > 0) return profileTarget;

    return 2200;
  }

  Widget _buildOverview() {
    final dailyCalories = _readInt(_dailyAnalytics?['totalCalories']);
    final meals = _readInt(_dailyAnalytics?['mealsCount']);
    final expiring = _readInt(_dailyAnalytics?['expiringSoonCount']);
    final shopping = _shoppingItems.length;
    final invites = _householdInvitations.length;
    final targetCalories = _dailyTargetCalories();
    final hasTarget = targetCalories > 0;
    final isOverTarget = hasTarget && dailyCalories > targetCalories;
    final calorieAccent = isOverTarget ? _cs.error : _cs.primary;
    final progress = targetCalories <= 0
        ? 0.0
        : (dailyCalories / targetCalories).clamp(0.0, 1.0);
    final protein = _readDouble(
      _dailyAnalytics?['proteins'] ?? _dailyAnalytics?['totalProteins'],
      0,
    );
    final carbs = _readDouble(
      _dailyAnalytics?['carbohydrates'] ??
          _dailyAnalytics?['totalCarbohydrates'],
      0,
    );
    final fats = _readDouble(
      _dailyAnalytics?['fats'] ?? _dailyAnalytics?['totalFats'],
      0,
    );

    Widget macroCard({
      required String label,
      required String value,
      required Color accent,
    }) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: _isDark ? 0.18 : 0.1),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: accent.withValues(alpha: 0.16)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _cs.onSurfaceVariant,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: accent,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget summaryCard({
      required IconData icon,
      required String label,
      required String value,
      required Color accent,
    }) {
      return Expanded(
        child: Container(
          constraints: const BoxConstraints(minHeight: 82),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: _isDark ? 0.16 : 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: accent.withValues(alpha: 0.14)),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: _isDark ? 0.16 : 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 18, color: accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _cs.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.fade,
                      softWrap: true,
                      style: TextStyle(
                        color: _cs.onSurfaceVariant,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget heroCard() {
      return Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            _cs.surfaceContainerHighest.withValues(
              alpha: _isDark ? 0.28 : 0.84,
            ),
            _cs.surface,
          ),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: _cs.outlineVariant.withValues(alpha: 0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: _OrganizerCalorieRing(
                isRu: _isRu,
                progress: progress,
                calories: dailyCalories,
                targetCalories: targetCalories,
                accent: calorieAccent,
                isDark: _isDark,
              ),
            ),
            if (isOverTarget) ...[
              const SizedBox(height: 14),
              Center(
                child: AtelierTagChip(
                  label: _isRu ? 'выше цели' : 'over target',
                  foreground: _cs.error,
                  icon: Icons.priority_high_rounded,
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: Row(
                children: [
                  macroCard(
                    label: _isRu ? 'Углеводы' : 'Carbs',
                    value: '${carbs.round()} ${_isRu ? 'г' : 'g'}',
                    accent: _cs.primary,
                  ),
                  const SizedBox(width: 12),
                  macroCard(
                    label: _isRu ? 'Белки' : 'Protein',
                    value: '${protein.round()} ${_isRu ? 'г' : 'g'}',
                    accent: _cs.secondary,
                  ),
                  const SizedBox(width: 12),
                  macroCard(
                    label: _isRu ? 'Жиры' : 'Fats',
                    value: '${fats.round()} ${_isRu ? 'г' : 'g'}',
                    accent: _cs.tertiary,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                summaryCard(
                  icon: Icons.restaurant_rounded,
                  label: _isRu ? 'Приёмов пищи' : 'Meals',
                  value: '$meals',
                  accent: _cs.secondary,
                ),
                const SizedBox(width: 12),
                summaryCard(
                  icon: Icons.inventory_2_rounded,
                  label: _isRu ? 'Скоро испортится' : 'Expiring soon',
                  value: '$expiring',
                  accent: _cs.tertiary,
                ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _addMealQuick,
                icon: const Icon(Icons.add_rounded),
                label: Text(_isRu ? 'Добавить съеденное' : 'Add meal'),
              ),
            ),
          ],
        ),
      );
    }

    final spotlightCard = Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: _cs.primary,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.verified_rounded, color: _cs.onPrimary, size: 36),
          const SizedBox(height: 18),
          Text(
            _isRu ? 'Пульс дома' : 'House Pulse',
            style: TextStyle(
              color: _cs.onPrimary.withValues(alpha: 0.84),
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isRu
                ? 'Очередь на\nпополнение под контролем'
                : 'Restock Queue\nunder control',
            style: TextStyle(
              color: _cs.onPrimary,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              height: 0.98,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _isRu
                ? 'Активных покупок: $shopping. Семейных обновлений: $invites. Можно перейти в аналитику или сразу в список.'
                : 'Active shopping items: $shopping. Household updates: $invites. Jump into analytics or go straight to the list.',
            style: TextStyle(
              color: _cs.onPrimary.withValues(alpha: 0.82),
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _cs.primaryContainer,
                    foregroundColor: _cs.onPrimaryContainer,
                  ),
                  onPressed: () => _openScreen(const AnalyticsScreen()),
                  child: Text(_isRu ? 'Открыть аналитику' : 'View Insights'),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 920) {
          return Column(
            children: [heroCard(), const SizedBox(height: 18), spotlightCard],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 8, child: heroCard()),
            const SizedBox(width: 18),
            Expanded(flex: 4, child: spotlightCard),
          ],
        );
      },
    );
  }

  Widget _buildSectionIntro({
    required String eyebrow,
    required String title,
    required String subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow.toUpperCase(),
          style: TextStyle(
            color: _cs.primary,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w900,
            height: 0.98,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: TextStyle(
            color: _cs.onSurfaceVariant.withValues(alpha: 0.9),
            fontWeight: FontWeight.w600,
            height: 1.3,
          ),
        ),
      ],
    );
  }

  Widget _hubPanel({
    required IconData icon,
    required String title,
    Widget? trailing,
    required Widget child,
    Color? tint,
  }) {
    final accent = tint ?? _cs.primary;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          _cs.surfaceContainerHighest.withValues(alpha: _isDark ? 0.28 : 0.82),
          _cs.surface,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _cs.outlineVariant.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AtelierIconBadge(icon: icon, accent: accent),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  bool _shoppingItemDone(Map<String, dynamic> item) {
    final completed = item['completed'] ?? item['isCompleted'] ?? item['done'];
    if (completed is bool) return completed;
    final status = (item['status'] ?? item['state'] ?? '')
        .toString()
        .toUpperCase();
    return status == 'DONE' || status == 'COMPLETED' || status == 'BOUGHT';
  }

  Widget _buildSpaces() {
    final pantryPanel = _hubPanel(
      icon: Icons.inventory_2_rounded,
      title: _isRu ? 'Сигналы кладовой' : 'Pantry Alerts',
      tint: _cs.tertiary,
      trailing: AtelierTagChip(
        label: _isRu ? 'Приоритет' : 'Priority',
        foreground: _cs.tertiary,
      ),
      child: Column(
        children: _expiringPantry.isEmpty
            ? [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _cs.tertiary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _isRu
                        ? 'Срочных продуктов нет. Кладовая под контролем.'
                        : 'No urgent pantry items. Your inventory is under control.',
                    style: TextStyle(
                      color: _cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ),
              ]
            : _expiringPantry.take(3).map((item) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => _openScreen(const PantryScreen()),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _cs.surface.withValues(
                          alpha: _isDark ? 0.24 : 0.82,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          AtelierIconBadge(
                            icon: Icons.eco_rounded,
                            accent: _cs.tertiary,
                            size: 40,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['name']?.toString() ?? '-',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_formatQuantity(item)} • ${_isRu ? 'до' : 'until'} ${_formatDate(item['expiresAt'])}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: _cs.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.add_shopping_cart_rounded,
                            color: _cs.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
      ),
    );

    final shoppingPanel = _hubPanel(
      icon: Icons.shopping_cart_rounded,
      title: _isRu ? 'Покупки' : 'Shopping Preview',
      tint: _cs.primary,
      trailing: TextButton(
        onPressed: () => _openScreen(const ShoppingListScreen()),
        child: Text(_isRu ? 'Открыть' : 'Edit'),
      ),
      child: Column(
        children: [
          ..._shoppingItems.take(4).map((item) {
            final done = _shoppingItemDone(item);
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: done ? _cs.primary : Colors.transparent,
                      border: Border.all(
                        color: done
                            ? _cs.primary
                            : _cs.primary.withValues(alpha: 0.32),
                        width: 2,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: done
                        ? Icon(
                            Icons.check_rounded,
                            size: 14,
                            color: _cs.onPrimary,
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item['name']?.toString() ?? '-',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        decoration: done ? TextDecoration.lineThrough : null,
                        color: done ? _cs.onSurfaceVariant : _cs.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          if (_shoppingItems.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _cs.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _isRu
                    ? 'Список покупок пока пуст. Его можно собрать из кладовой или рецептов.'
                    : 'Your shopping list is empty. Build it from pantry or recipes.',
                style: TextStyle(
                  color: _cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: () => _openScreen(const ShoppingListScreen()),
              icon: const Icon(Icons.receipt_long_rounded),
              label: Text(_isRu ? 'Открыть покупки' : 'Open Shopping'),
            ),
          ),
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 980) {
          return Column(
            children: [pantryPanel, const SizedBox(height: 16), shoppingPanel],
          );
        }

        final width = (constraints.maxWidth - 16) / 2;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            SizedBox(width: width, child: pantryPanel),
            SizedBox(width: width, child: shoppingPanel),
          ],
        );
      },
    );
  }

  Widget _buildQuickRibbon() {
    final actions = [
      (
        _isRu ? 'Кладовая' : 'Pantry',
        Icons.inventory_2_rounded,
        _cs.primary,
        () => _openScreen(const PantryScreen()),
      ),
      (
        _isRu ? 'Съедено' : 'Meals',
        Icons.menu_book_rounded,
        const Color(0xFF2F7A53),
        _openMealHistory,
      ),
      (
        _isRu ? 'Покупки' : 'Shopping',
        Icons.shopping_cart_rounded,
        _cs.tertiary,
        () => _openScreen(const ShoppingListScreen()),
      ),
      (
        _isRu ? 'Семья' : 'Household',
        Icons.groups_rounded,
        const Color(0xFF4A7A43),
        () => _openScreen(const HouseholdScreen()),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 14.0;
        final width = (constraints.maxWidth - spacing) / 2;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: actions.map((entry) {
            final label = entry.$1;
            final icon = entry.$2;
            final color = entry.$3;
            final onTap = entry.$4;
            return SizedBox(
              width: width,
              child: _spaceCard(
                icon: icon,
                title: label,
                subtitle: _isRu ? 'Быстрый вход в раздел' : 'Quick access lane',
                color: color,
                onTap: onTap,
              ),
            );
          }).toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _screenBackground,
      appBar: AppTopBar(
        title: _isRu ? 'Органайзер' : 'Organizer',
        actions: [
          AppTopAction(
            icon: Icons.add_rounded,
            onPressed: _addMealQuick,
            tooltip: _isRu ? 'Добавить съеденное' : 'Add meal',
          ),
          AppTopAction(
            icon: Icons.settings_rounded,
            onPressed: () => showAppSettingsSheet(context),
            tooltip: _isRu ? 'Настройки' : 'Settings',
          ),
          AppTopAction(
            icon: Icons.refresh_rounded,
            onPressed: _load,
            tooltip: _isRu ? 'Обновить' : 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
          children: [
            _buildOverview(),
            const SizedBox(height: 28),
            _buildSectionIntro(
              eyebrow: _isRu ? 'быстрые действия' : 'quick actions',
              title: _isRu ? 'Основные разделы' : 'Primary lanes',
              subtitle: _isRu
                  ? 'Открой нужную зону без лишних переходов: кладовую, покупки, анализ или семейный раздел.'
                  : 'Jump into the right zone without friction: pantry, shopping, analyze, and household.',
            ),
            const SizedBox(height: 16),
            _buildQuickRibbon(),
            const SizedBox(height: 32),
            _buildSectionIntro(
              eyebrow: _isRu ? 'органайзер' : 'organizer',
              title: _isRu ? 'Сводка по дому' : 'Home Summary',
              subtitle: _isRu
                  ? 'Панель с тревожными продуктами и покупками без лишних блоков.'
                  : 'A compact view of urgent pantry items and shopping.',
            ),
            const SizedBox(height: 16),
            _buildSpaces(),
          ],
        ),
      ),
    );
  }
}

class _OrganizerCalorieRing extends StatelessWidget {
  const _OrganizerCalorieRing({
    required this.isRu,
    required this.progress,
    required this.calories,
    required this.targetCalories,
    required this.accent,
    required this.isDark,
  });

  final bool isRu;
  final double progress;
  final int calories;
  final int targetCalories;
  final Color accent;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final actualProgress = targetCalories > 0 ? calories / targetCalories : 0.0;
    final progressLabel = targetCalories > 0
        ? '${(actualProgress * 100).round()}%'
        : (isRu ? 'без цели' : 'no goal');

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: progress),
      duration: const Duration(milliseconds: 950),
      curve: Curves.easeOutCubic,
      builder: (context, animatedProgress, _) {
        return SizedBox(
          width: 232,
          height: 232,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 232,
                height: 232,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      accent.withValues(alpha: isDark ? 0.2 : 0.14),
                      cs.surface.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
              CustomPaint(
                size: const Size.square(232),
                painter: _OrganizerCalorieRingPainter(
                  progress: animatedProgress,
                  accent: accent,
                  track: cs.surfaceContainerHighest,
                  shadow: accent.withValues(alpha: isDark ? 0.28 : 0.18),
                ),
              ),
              Container(
                width: 164,
                height: 164,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.alphaBlend(
                        cs.surfaceContainerHighest.withValues(
                          alpha: isDark ? 0.48 : 0.82,
                        ),
                        cs.surface,
                      ),
                      Color.alphaBlend(
                        accent.withValues(alpha: isDark ? 0.12 : 0.08),
                        cs.surface,
                      ),
                    ],
                  ),
                  border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.16),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.18 : 0.05,
                      ),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 18,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Color.alphaBlend(
                      accent.withValues(alpha: isDark ? 0.22 : 0.12),
                      cs.surface,
                    ),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: accent.withValues(alpha: isDark ? 0.22 : 0.16),
                    ),
                  ),
                  child: Text(
                    progressLabel,
                    style: TextStyle(
                      color: accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 118,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isRu ? 'Сегодня' : 'Today',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 42,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '$calories',
                          style: TextStyle(
                            color: accent,
                            fontSize: 40,
                            fontWeight: FontWeight.w900,
                            height: 0.9,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      targetCalories > 0
                          ? (isRu
                                ? 'из $targetCalories ккал'
                                : 'of $targetCalories kcal')
                          : (isRu ? 'ккал за день' : 'daily kcal'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OrganizerCalorieRingPainter extends CustomPainter {
  const _OrganizerCalorieRingPainter({
    required this.progress,
    required this.accent,
    required this.track,
    required this.shadow,
  });

  final double progress;
  final Color accent;
  final Color track;
  final Color shadow;

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 16.0;
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    final glowPaint = Paint()
      ..color = shadow
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth + 3
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

    final progressPaint = Paint()
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: math.pi * 1.5,
        colors: [
          accent.withValues(alpha: 0.48),
          accent,
          accent.withValues(alpha: 0.78),
        ],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    canvas.drawArc(rect, 0, math.pi * 2, false, trackPaint);
    if (progress <= 0) return;

    final sweep = math.pi * 2 * progress;
    canvas.drawArc(rect, -math.pi / 2, sweep, false, glowPaint);
    canvas.drawArc(rect, -math.pi / 2, sweep, false, progressPaint);

    final endAngle = -math.pi / 2 + sweep;
    final endPoint = Offset(
      center.dx + radius * math.cos(endAngle),
      center.dy + radius * math.sin(endAngle),
    );
    canvas.drawCircle(endPoint, 9, Paint()..color = accent);
    canvas.drawCircle(
      endPoint,
      4,
      Paint()..color = Colors.white.withValues(alpha: 0.92),
    );
  }

  @override
  bool shouldRepaint(covariant _OrganizerCalorieRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.accent != accent ||
        oldDelegate.track != track ||
        oldDelegate.shadow != shadow;
  }
}
