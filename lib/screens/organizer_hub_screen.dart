import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/app_feedback.dart';
import '../core/atelier_ui.dart';
import '../core/app_top_bar.dart';
import '../core/settings_sheet.dart';
import '../core/live_refresh.dart';
import '../repositories/app_repository.dart';
import '../services/api_service.dart';
import 'household_screen.dart';
import 'meal_history_screen.dart';
import 'meals/meal_composer_sheet.dart';
import 'pantry_screen.dart';
import 'shopping_list_screen.dart';

class OrganizerHubScreen extends StatefulWidget {
  const OrganizerHubScreen({super.key, this.isActive = false});

  final bool isActive;

  @override
  State<OrganizerHubScreen> createState() => _OrganizerHubScreenState();
}

class _OrganizerHubScreenState extends State<OrganizerHubScreen>
    with LiveRefreshState<OrganizerHubScreen> {
  final AppRepository repository = AppRepository.instance;

  bool _didScheduleInitialLoad = false;
  bool _pendingMealRefresh = false;
  DateTime? _lastAutoRefreshAt;
  String? _loadedDayKey;
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

  String _todayKey() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
  }

  bool get _routeIsCurrent {
    final route = ModalRoute.of(context);
    return route?.isCurrent ?? true;
  }

  @override
  Duration get liveRefreshInterval => const Duration(minutes: 1);

  @override
  bool get enableLiveRefresh => widget.isActive && _routeIsCurrent;

  @override
  Future<void> performLiveRefresh() async {
    if (_loadedDayKey != _todayKey()) {
      await _load();
    }
  }

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
    bool addToInbox = false,
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
  void initState() {
    super.initState();
    repository.mealSignal.addListener(_handleMealSignal);
  }

  @override
  void dispose() {
    repository.mealSignal.removeListener(_handleMealSignal);
    super.dispose();
  }

  void _handleMealSignal() {
    _pendingMealRefresh = true;
    final payload = repository.latestMealSignalPayload;
    if (_loadedDayKey != null && _loadedDayKey != _todayKey()) {
      _pendingMealRefresh = false;
      _lastAutoRefreshAt = DateTime.now();
      if (mounted && widget.isActive) {
        _load();
      }
      return;
    }
    if (payload != null) {
      _applyMealSignalPayload(payload);
    }
    if (!mounted || !widget.isActive) return;
    _pendingMealRefresh = false;
    _lastAutoRefreshAt = DateTime.now();
    if (payload == null) {
      _load();
      return;
    }
    Future<void>.delayed(const Duration(milliseconds: 450), () {
      if (!mounted || !widget.isActive) return;
      _load();
    });
  }

  DateTime? _parseSignalDate(dynamic raw) {
    final parsed = DateTime.tryParse(raw?.toString() ?? '');
    return parsed?.toLocal();
  }

  double _signalDouble(Map<String, dynamic> payload, List<String> keys) {
    for (final key in keys) {
      final value = payload[key];
      if (value is num) return value.toDouble();
      final parsed = double.tryParse(
        value?.toString().trim().replaceAll(',', '.') ?? '',
      );
      if (parsed != null) return parsed;
    }
    return 0;
  }

  int _signalInt(Map<String, dynamic> payload, List<String> keys) {
    for (final key in keys) {
      final value = payload[key];
      if (value is int) return value;
      if (value is num) return value.round();
      final parsed = int.tryParse(value?.toString().trim() ?? '');
      if (parsed != null) return parsed;
    }
    return 0;
  }

  void _applyMealSignalPayload(Map<String, dynamic> payload) {
    if (_dailyAnalytics == null) return;
    final eatenAt = _parseSignalDate(
      payload['eatenAt'] ?? payload['createdAt'] ?? payload['created_at'],
    );
    final now = DateTime.now();
    if (eatenAt == null ||
        eatenAt.year != now.year ||
        eatenAt.month != now.month ||
        eatenAt.day != now.day) {
      return;
    }

    final calories = _signalInt(payload, ['calories']);
    final proteins = _signalDouble(payload, ['proteins', 'protein']);
    final fats = _signalDouble(payload, ['fats', 'fat']);
    final carbs = _signalDouble(payload, ['carbohydrates', 'carbs', 'carb']);

    setState(() {
      final next = Map<String, dynamic>.from(_dailyAnalytics!);
      next['totalCalories'] = _readInt(next['totalCalories']) + calories;
      next['mealsCount'] = _readInt(next['mealsCount']) + 1;
      next['proteins'] =
          _readDouble(next['proteins'] ?? next['totalProteins'], 0) + proteins;
      next['totalProteins'] =
          _readDouble(next['totalProteins'] ?? next['proteins'], 0) + proteins;
      next['fats'] = _readDouble(next['fats'] ?? next['totalFats'], 0) + fats;
      next['totalFats'] =
          _readDouble(next['totalFats'] ?? next['fats'], 0) + fats;
      next['carbohydrates'] =
          _readDouble(next['carbohydrates'] ?? next['totalCarbohydrates'], 0) +
          carbs;
      next['totalCarbohydrates'] =
          _readDouble(next['totalCarbohydrates'] ?? next['carbohydrates'], 0) +
          carbs;
      _dailyAnalytics = next;
    });
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

  @override
  void didUpdateWidget(covariant OrganizerHubScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isActive || oldWidget.isActive) return;

    if (_loadedDayKey != null && _loadedDayKey != _todayKey()) {
      _pendingMealRefresh = false;
      _lastAutoRefreshAt = DateTime.now();
      _load();
      return;
    }

    final now = DateTime.now();
    final canRefresh =
        _lastAutoRefreshAt == null ||
        now.difference(_lastAutoRefreshAt!) > const Duration(seconds: 2);
    if (!_pendingMealRefresh && !canRefresh) return;

    _pendingMealRefresh = false;
    _lastAutoRefreshAt = now;
    _load();
  }

  Future<void> _load() async {
    final errors = <String>[];
    final requestedDay = DateTime.now();

    final dailyFuture = _loadWithFallback<Map<String, dynamic>?>(
      future: repository.getDailyAnalytics(date: requestedDay),
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
      _dailyAnalytics = daily ?? _dailyAnalytics;
      _profile = profile ?? _profile;
      _expiringPantry = expiring;
      _shoppingItems = shopping;
      _householdInvitations = invitations;
      _loadedDayKey =
          _dailyAnalytics?['date']?.toString().trim().isNotEmpty == true
          ? _dailyAnalytics!['date'].toString().trim()
          : _todayKey();
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

  Future<void> _addMealQuick() async {
    final currentContext = context;
    final mode = await _showAddMealOptions();
    if (!mounted || !currentContext.mounted || mode == null) return;

    bool? created;
    if (mode == MealComposerMode.product) {
      created = await showProductMealComposerFlow(
        context: currentContext,
        repository: repository,
      );
    } else {
      created = await showMealComposerSheet(
        context: currentContext,
        repository: repository,
        initialMode: mode,
      );
    }
    if (created == true) {
      await _load();
    }
  }

  Future<MealComposerMode?> _showAddMealOptions() async {
    final isRu = Localizations.localeOf(context).languageCode == 'ru';
    return showModalBottomSheet<MealComposerMode>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => AtelierSheetFrame(
        title: isRu ? 'Добавить прием пищи' : 'Add meal',
        subtitle: isRu
            ? 'Выбери способ: вручную или найти в базе продуктов.'
            : 'Choose: manual entry or search in product database.',
        onClose: () => Navigator.of(context).pop(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AtelierSurfaceCard(
              radius: 24,
              padding: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(Icons.edit_note_rounded),
                title: Text(isRu ? 'Добавить вручную' : 'Add manually'),
                subtitle: Text(
                  isRu
                      ? 'Заполни данные о блюде самостоятельно.'
                      : 'Fill in the meal details yourself.',
                ),
                onTap: () {
                  Navigator.of(context).pop(MealComposerMode.manual);
                },
              ),
            ),
            const SizedBox(height: 10),
            AtelierSurfaceCard(
              radius: 24,
              padding: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(Icons.search_rounded),
                title: Text(
                  isRu ? 'Найти в базе продуктов' : 'Search product database',
                ),
                subtitle: Text(
                  isRu
                      ? 'Поиск среди тысяч продуктов.'
                      : 'Search among thousands of products.',
                ),
                onTap: () {
                  Navigator.of(context).pop(MealComposerMode.product);
                },
              ),
            ),
          ],
        ),
      ),
    );
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

  String? _profileGoalType() {
    final raw = (_profile?['goalType'] ?? _profile?['goal_type'])
        ?.toString()
        .trim();
    if (raw == null || raw.isEmpty) return null;
    return raw.toUpperCase();
  }

  String? _profileActivityLevel() {
    final raw = (_profile?['activityLevel'] ?? _profile?['activity_level'])
        ?.toString()
        .trim();
    if (raw == null || raw.isEmpty) return null;
    return raw.toUpperCase();
  }

  double _round1(double value) => (value * 10).roundToDouble() / 10.0;

  double _profileWeight() {
    return _readDouble(_profile?['weight'], 0);
  }

  double _activityProteinBonus() {
    switch (_profileActivityLevel()) {
      case 'LIGHTLY_ACTIVE':
        return 0.1;
      case 'MODERATELY_ACTIVE':
        return 0.2;
      case 'VERY_ACTIVE':
        return 0.3;
      case 'EXTRA_ACTIVE':
        return 0.35;
      case 'SEDENTARY':
      default:
        return 0.0;
    }
  }

  double _preferredProteinPerKg() {
    final base = switch (_profileGoalType()) {
      'LOSE_WEIGHT' => 1.9,
      'GAIN_MUSCLE' => 1.8,
      'MAINTAIN_WEIGHT' => 1.6,
      _ => 1.6,
    };
    return base + _activityProteinBonus();
  }

  double _minimumProteinPerKg() {
    final base = switch (_profileGoalType()) {
      'LOSE_WEIGHT' => 1.6,
      'GAIN_MUSCLE' => 1.6,
      'MAINTAIN_WEIGHT' => 1.3,
      _ => 1.3,
    };
    return base + _activityProteinBonus() * 0.5;
  }

  double _preferredFatPerKg() {
    return switch (_profileGoalType()) {
      'LOSE_WEIGHT' => 0.8,
      'GAIN_MUSCLE' => 0.8,
      'MAINTAIN_WEIGHT' => 0.9,
      _ => 0.85,
    };
  }

  double _minimumFatPerKg() {
    return switch (_profileGoalType()) {
      'LOSE_WEIGHT' => 0.6,
      'GAIN_MUSCLE' => 0.6,
      'MAINTAIN_WEIGHT' => 0.7,
      _ => 0.65,
    };
  }

  double _minimumCarbsPerKg() {
    final base = switch (_profileActivityLevel()) {
      'LIGHTLY_ACTIVE' => 2.0,
      'MODERATELY_ACTIVE' => 2.5,
      'VERY_ACTIVE' => 3.0,
      'EXTRA_ACTIVE' => 3.5,
      _ => 1.5,
    };
    return switch (_profileGoalType()) {
      'LOSE_WEIGHT' => math.max(1.2, base - 0.5),
      'GAIN_MUSCLE' => base + 0.5,
      'MAINTAIN_WEIGHT' => base,
      _ => base,
    };
  }

  ({double protein, double fats, double carbs}) _fallbackMacroTargets() {
    final targetCalories = _dailyTargetCalories();
    final weight = _profileWeight();
    if (targetCalories <= 0 || weight <= 0) {
      return (protein: 0.0, fats: 0.0, carbs: 0.0);
    }

    double proteins = _round1(weight * _preferredProteinPerKg());
    final minimumProteins = _round1(weight * _minimumProteinPerKg());
    double fats = _round1(weight * _preferredFatPerKg());
    final minimumFats = _round1(weight * _minimumFatPerKg());
    final minimumCarbs = _round1(weight * _minimumCarbsPerKg());

    var availableCarbCalories = targetCalories - proteins * 4.0 - fats * 9.0;
    if (availableCarbCalories < minimumCarbs * 4.0) {
      final adjustedFats =
          (targetCalories - proteins * 4.0 - minimumCarbs * 4.0) / 9.0;
      fats = _round1(math.max(minimumFats, adjustedFats));
      availableCarbCalories = targetCalories - proteins * 4.0 - fats * 9.0;
    }

    if (availableCarbCalories < 0 && proteins > minimumProteins) {
      final adjustedProteins = (targetCalories - fats * 9.0) / 4.0;
      proteins = _round1(math.max(minimumProteins, adjustedProteins));
      availableCarbCalories = targetCalories - proteins * 4.0 - fats * 9.0;
    }

    final carbs = _round1(math.max(0.0, availableCarbCalories / 4.0));
    return (protein: proteins, fats: fats, carbs: carbs);
  }

  double? _dailyTargetMacro({
    required String analyticsKey,
    required double fallbackValue,
  }) {
    final analyticsTarget = _readDouble(
      _dailyAnalytics?[analyticsKey] ??
          _dailyAnalytics?[_toSnakeCase(analyticsKey)],
      0,
    );
    if (analyticsTarget > 0) return analyticsTarget;
    return fallbackValue > 0 ? fallbackValue : null;
  }

  String _toSnakeCase(String value) {
    final buffer = StringBuffer();
    for (var i = 0; i < value.length; i++) {
      final char = value[i];
      final isUpper = char.toUpperCase() == char && char.toLowerCase() != char;
      if (isUpper && i > 0) buffer.write('_');
      buffer.write(char.toLowerCase());
    }
    return buffer.toString();
  }

  String _formatMacroProgressText(double consumed, double? target) {
    final consumedText = consumed.round().toString();
    if (target == null || target <= 0) {
      return '$consumedText ${_isRu ? 'г' : 'g'}';
    }
    final targetText = target.round().toString();
    return '$consumedText / $targetText ${_isRu ? 'г' : 'g'}';
  }

  Widget _buildOverview() {
    final dailyCalories = _readInt(_dailyAnalytics?['totalCalories']);
    final meals = _readInt(_dailyAnalytics?['mealsCount']);
    final expiring = _readInt(_dailyAnalytics?['expiringSoonCount']);
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
    final fallbackTargets = _fallbackMacroTargets();
    final targetProtein = _dailyTargetMacro(
      analyticsKey: 'targetProteins',
      fallbackValue: fallbackTargets.protein,
    );
    final targetFats = _dailyTargetMacro(
      analyticsKey: 'targetFats',
      fallbackValue: fallbackTargets.fats,
    );
    final targetCarbs = _dailyTargetMacro(
      analyticsKey: 'targetCarbohydrates',
      fallbackValue: fallbackTargets.carbs,
    );

    Widget macroCard({
      required String label,
      required double consumed,
      required double? target,
      required Color accent,
    }) {
      final progress = target == null || target <= 0
          ? 0.0
          : (consumed / target).clamp(0.0, 1.0);
      final isOverTarget = target != null && target > 0 && consumed > target;
      return Expanded(
        child: Container(
          constraints: const BoxConstraints(minHeight: 104),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: _isDark ? 0.18 : 0.1),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: accent.withValues(alpha: 0.16)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: isOverTarget ? _cs.error : accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: SizedBox(
                      height: 16,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          label,
                          style: TextStyle(
                            color: _cs.onSurfaceVariant,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            height: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  _formatMacroProgressText(consumed, target),
                  style: TextStyle(
                    color: isOverTarget ? _cs.error : accent,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 6,
                  value: progress,
                  backgroundColor: accent.withValues(alpha: 0.12),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isOverTarget ? _cs.error : accent,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 14,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    target == null || target <= 0
                        ? (_isRu ? 'без цели' : 'no target')
                        : isOverTarget
                        ? (_isRu ? 'выше цели' : 'over target')
                        : (_isRu ? 'сегодня' : 'for today'),
                    style: TextStyle(
                      color: _cs.onSurfaceVariant,
                      fontSize: 10.6,
                      fontWeight: FontWeight.w700,
                      height: 1.0,
                    ),
                  ),
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
            Row(
              children: [
                macroCard(
                  label: _isRu ? 'Белки' : 'Protein',
                  consumed: protein,
                  target: targetProtein,
                  accent: _cs.secondary,
                ),
                const SizedBox(width: 8),
                macroCard(
                  label: _isRu ? 'Жиры' : 'Fats',
                  consumed: fats,
                  target: targetFats,
                  accent: _cs.tertiary,
                ),
                const SizedBox(width: 8),
                macroCard(
                  label: _isRu ? 'Углеводы' : 'Carbs',
                  consumed: carbs,
                  target: targetCarbs,
                  accent: _cs.primary,
                ),
              ],
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

    return heroCard();
  }

  Widget _buildSectionIntro({
    required String eyebrow,
    required String title,
    String? subtitle,
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
        if (subtitle != null && subtitle.trim().isNotEmpty) ...[
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
            ),
            const SizedBox(height: 16),
            _buildQuickRibbon(),
            const SizedBox(height: 32),
            _buildSectionIntro(
              eyebrow: _isRu ? 'органайзер' : 'organizer',
              title: _isRu ? 'Сводка по дому' : 'Home Summary',
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
                width: 132,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        isRu ? 'Сегодня' : 'Today',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
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
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
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
