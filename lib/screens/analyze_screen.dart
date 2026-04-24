import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_feedback.dart';
import '../core/atelier_ui.dart';
import '../core/app_top_bar.dart';
import '../core/app_scope.dart';
import '../core/app_theme.dart';
import '../core/settings_sheet.dart';
import '../core/tr.dart';
import '../repositories/app_repository.dart';
part "analyze/analyze_ui.dart";

class AnalyzeScreen extends StatefulWidget {
  const AnalyzeScreen({super.key, this.isActive = false});

  final bool isActive;

  @override
  State<AnalyzeScreen> createState() => _AnalyzeScreenState();
}

class _QuestionPreset {
  const _QuestionPreset({
    required this.id,
    required this.ru,
    required this.en,
    this.keywords = const <String>[],
  });

  final String id;
  final String ru;
  final String en;
  final List<String> keywords;

  String text(bool isRu) => isRu ? ru : en;

  bool matches(String query) {
    if (query.trim().isEmpty) return true;
    final q = query.toLowerCase();
    return ru.toLowerCase().contains(q) ||
        en.toLowerCase().contains(q) ||
        keywords.any((k) => k.toLowerCase().contains(q));
  }
}

class _AnalyzeScreenState extends State<AnalyzeScreen>
    with AutomaticKeepAliveClientMixin {
  static const Color _accentOrange = AppTheme.atelierGreen;
  static const Color _accentOrangeDeep = Color(0xFF0F5418);
  static const String _analysisBasisPer100g = 'PER_100G';
  static const String _analysisBasisFullPortion = 'FULL_PORTION';

  final AppRepository repository = AppRepository.instance;
  final ImagePicker _picker = ImagePicker();

  Map<String, dynamic>? _profile;
  File? _selectedImage;
  bool _isAnalyzing = false;
  Map<String, dynamic>? _analysisResult;
  bool _isSavingMeal = false;
  bool _isHistoryLoading = false;
  List<Map<String, dynamic>> _analysisHistory = [];
  Set<String> _deletedHistoryIds = <String>{};
  DateTime? _lastAutoRefreshAt;
  String _selectedAnalysisBasis = _analysisBasisPer100g;

  final List<String> _selectedQuestionIds = [];

  static const int _maxSelectedQuestions = 5;
  static const int _analysisHistoryLimit = 10;
  static const String _analysisHistoryCachePrefix = 'analysis_history_cache_v1';
  static const String _analysisHistoryDeletedCachePrefix =
      'analysis_history_deleted_v1';
  static const List<String> _coreQuestionIds = [
    'calorie_balance',
    'macro_distribution',
    'portion_recommendation',
    'sugar_level',
    'salt_level',
  ];

  String get _feedbackSource => _isRu ? 'Анализ' : 'Analyze';

  void _showFeedback(
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
      source: _feedbackSource,
      preferPopup: preferPopup,
      addToInbox: addToInbox,
    );
  }

  static const List<_QuestionPreset> _questionPresets = [
    _QuestionPreset(
      id: 'calorie_balance',
      ru: 'Сколько калорий в порции и как это влияет на мою цель?',
      en: 'How many calories are in this serving and how does it affect my goal?',
      keywords: ['ккал', 'калории', 'calories', 'goal'],
    ),
    _QuestionPreset(
      id: 'macro_distribution',
      ru: 'Подходит ли распределение БЖУ для снижения веса?',
      en: 'Is this protein-fat-carb balance good for weight loss?',
      keywords: ['бжу', 'protein', 'fat', 'carb', 'макро'],
    ),
    _QuestionPreset(
      id: 'sugar_level',
      ru: 'Много ли здесь сахара и есть ли риск резкого скачка глюкозы?',
      en: 'Is sugar high here and can it spike blood glucose?',
      keywords: ['сахар', 'glucose', 'glycemic', 'гликемия'],
    ),
    _QuestionPreset(
      id: 'salt_level',
      ru: 'Оцени уровень соли и риск для давления.',
      en: 'Evaluate salt level and blood pressure risk.',
      keywords: ['salt', 'sodium', 'соль', 'давление'],
    ),
    _QuestionPreset(
      id: 'portion_recommendation',
      ru: 'Какая оптимальная порция для меня?',
      en: 'What serving size is optimal for me?',
      keywords: ['portion', 'порция', 'serving'],
    ),
    _QuestionPreset(
      id: 'meal_time',
      ru: 'Подходит ли это блюдо на ужин?',
      en: 'Is this meal suitable for dinner?',
      keywords: ['ужин', 'dinner', 'meal time', 'time'],
    ),
    _QuestionPreset(
      id: 'preworkout',
      ru: 'Подходит ли блюдо перед тренировкой?',
      en: 'Is this dish good before workout?',
      keywords: ['тренировка', 'workout', 'preworkout'],
    ),
    _QuestionPreset(
      id: 'postworkout',
      ru: 'Подходит ли блюдо после тренировки для восстановления?',
      en: 'Is this dish good post-workout for recovery?',
      keywords: ['postworkout', 'recovery', 'восстановление'],
    ),
    _QuestionPreset(
      id: 'protein_enough',
      ru: 'Достаточно ли белка для набора/сохранения мышц?',
      en: 'Is protein enough for muscle gain or retention?',
      keywords: ['protein', 'белок', 'muscle', 'мышцы'],
    ),
    _QuestionPreset(
      id: 'fiber_enough',
      ru: 'Хватает ли клетчатки в этом блюде?',
      en: 'Does this meal have enough fiber?',
      keywords: ['fiber', 'клетчатка', 'digestion'],
    ),
    _QuestionPreset(
      id: 'healthy_swap',
      ru: 'Какие более полезные замены ингредиентов ты рекомендуешь?',
      en: 'What healthier ingredient swaps do you suggest?',
      keywords: ['swap', 'замена', 'healthier'],
    ),
    _QuestionPreset(
      id: 'allergy_risk',
      ru: 'Есть ли риск для моих аллергий?',
      en: 'Is there an allergy risk for my profile?',
      keywords: ['allergy', 'аллергия', 'risk'],
    ),
    _QuestionPreset(
      id: 'diabetes_safe',
      ru: 'Насколько это безопасно при диабете?',
      en: 'How safe is this meal for diabetes?',
      keywords: ['diabetes', 'диабет', 'glucose'],
    ),
    _QuestionPreset(
      id: 'cholesterol_risk',
      ru: 'Есть ли риск по холестерину?',
      en: 'Is there a cholesterol risk?',
      keywords: ['cholesterol', 'холестерин', 'ldl'],
    ),
  ];

  @override
  bool get wantKeepAlive => true;

  bool get _isRu => AppScope.settingsOf(context).locale.languageCode == 'ru';
  ThemeData get _theme => Theme.of(context);
  ColorScheme get _cs => _theme.colorScheme;
  bool get _isDarkTheme => _theme.brightness == Brightness.dark;
  Color get _screenBackground => _theme.scaffoldBackgroundColor;
  Color get _panelBackground => _isDarkTheme
      ? Color.alphaBlend(
          _cs.surfaceContainerHighest.withValues(alpha: 0.56),
          _cs.surface,
        )
      : const Color(0xFFF6F6F7);

  @override
  void didUpdateWidget(covariant AnalyzeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isActive || oldWidget.isActive) return;

    final now = DateTime.now();
    final canRefresh =
        _lastAutoRefreshAt == null ||
        now.difference(_lastAutoRefreshAt!) > const Duration(seconds: 2);
    if (!canRefresh) return;

    _lastAutoRefreshAt = now;
    _refreshAnalyzeScreen();
  }

  @override
  void initState() {
    super.initState();
    _bootstrapAnalyzeScreen();
  }

  Color _blendWithSurface(Color color, [double opacity = 0.12]) {
    return Color.alphaBlend(color.withValues(alpha: opacity), _panelBackground);
  }

  _QuestionPreset? _questionById(String id) {
    for (final item in _questionPresets) {
      if (item.id == id) return item;
    }
    return null;
  }

  String _questionTextById(String id, {bool? forceRu}) {
    final preset = _questionById(id);
    if (preset == null) return id;
    final useRu = forceRu ?? _isRu;
    return preset.text(useRu);
  }

  List<_QuestionPreset> get _visibleQuestionPresets {
    final visibleIds = <String>[];

    for (final id in _selectedQuestionIds) {
      if (!visibleIds.contains(id) && _questionById(id) != null) {
        visibleIds.add(id);
      }
      if (visibleIds.length >= _maxSelectedQuestions) break;
    }

    for (final id in _coreQuestionIds) {
      if (visibleIds.length >= _maxSelectedQuestions) break;
      if (!visibleIds.contains(id) && _questionById(id) != null) {
        visibleIds.add(id);
      }
    }

    return visibleIds
        .map(_questionById)
        .whereType<_QuestionPreset>()
        .toList(growable: false);
  }

  List<_QuestionPreset> _filterQuestionPresets(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return _questionPresets;
    return _questionPresets.where((item) => item.matches(q)).toList();
  }

  String _normalizeAnalysisBasis(String? raw) {
    final value = raw?.trim().toUpperCase() ?? '';
    if (value == _analysisBasisFullPortion) {
      return _analysisBasisFullPortion;
    }
    return _analysisBasisPer100g;
  }

  String _analysisBasisOf(Map<String, dynamic> item) {
    return _normalizeAnalysisBasis(
      item['analysisBasis']?.toString() ?? item['analysis_basis']?.toString(),
    );
  }

  String _analysisBasisShortLabel(String basis) {
    return basis == _analysisBasisFullPortion
        ? (_isRu ? 'полная порция' : 'full portion')
        : (_isRu ? 'на 100 г' : 'per 100 g');
  }

  String _analysisBasisHeadline(String basis) {
    return basis == _analysisBasisFullPortion
        ? (_isRu
              ? 'Оценка полной порции • Сейчас'
              : 'Full portion estimate • Just now')
        : (_isRu
              ? 'Оценка на 100 г • Сейчас'
              : 'Estimate per 100 g • Just now');
  }

  double? _analysisEstimatedWeightGrams(Map<String, dynamic> item) {
    final raw =
        item['estimatedWeightGrams'] ??
        item['estimated_weight_grams'] ??
        item['estimatedPortionWeight'] ??
        item['estimated_portion_weight'];
    if (raw is num) return raw.toDouble();
    if (raw == null) return null;
    return double.tryParse(raw.toString());
  }

  String _analysisEstimatedWeightCaption(Map<String, dynamic> item) {
    final grams = _analysisEstimatedWeightGrams(item);
    if (grams == null || grams <= 0) return '';
    final weightText = _isRu
        ? '≈ ${_formatCompactValue(grams)} г'
        : '~${_formatCompactValue(grams)} g';
    return _isRu
        ? '$weightText • вес примерный'
        : '$weightText • approximate weight';
  }

  String _analysisBasisInstruction() {
    return 'ANALYSIS_BASIS=$_selectedAnalysisBasis';
  }

  void _setAnalysisBasis(String basis) {
    if (!mounted) return;
    setState(() {
      _selectedAnalysisBasis = _normalizeAnalysisBasis(basis);
    });
  }

  String _buildExtraQuestionsPayload() {
    final lines = <String>[_analysisBasisInstruction()];
    lines.addAll(_selectedQuestionIds.map(_questionTextById));
    return lines.join('\n');
  }

  void _toggleQuestionSelection(String id, bool selected) {
    if (selected) {
      if (_selectedQuestionIds.contains(id)) return;
      if (_selectedQuestionIds.length >= _maxSelectedQuestions) {
        _showFeedback(
          tr(context, 'analysis_questions_limit_error'),
          kind: AppFeedbackKind.error,
          preferPopup: true,
          addToInbox: false,
        );
        return;
      }
      setState(() => _selectedQuestionIds.add(id));
      return;
    }
    setState(() => _selectedQuestionIds.remove(id));
  }

  DateTime? _tryParseDate(dynamic value) {
    if (value == null) return null;
    if (value is int) {
      if (value > 1000000000000) {
        return DateTime.fromMillisecondsSinceEpoch(value).toLocal();
      }
      if (value > 1000000000) {
        return DateTime.fromMillisecondsSinceEpoch(value * 1000).toLocal();
      }
    }
    if (value is num) {
      final epoch = value.toInt();
      if (epoch > 1000000000000) {
        return DateTime.fromMillisecondsSinceEpoch(epoch).toLocal();
      }
      if (epoch > 1000000000) {
        return DateTime.fromMillisecondsSinceEpoch(epoch * 1000).toLocal();
      }
    }
    return DateTime.tryParse(value.toString())?.toLocal();
  }

  DateTime _historyDate(Map<String, dynamic> item) {
    final raw =
        item['createdAt'] ??
        item['created_at'] ??
        item['analyzedAt'] ??
        item['analyzed_at'] ??
        item['updatedAt'] ??
        item['updated_at'];
    return _tryParseDate(raw) ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _formatHistoryDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    final h = date.hour.toString().padLeft(2, '0');
    final min = date.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $h:$min';
  }

  String _historyStatusRaw(Map<String, dynamic> item) {
    return (item['status'] ?? item['analysisStatus'] ?? item['analysis_status'])
            ?.toString() ??
        '';
  }

  String _historyStatusLabel(String raw) {
    final upper = raw.toUpperCase();
    if (upper == 'COMPLETED' || upper == 'SUCCESS') {
      return _isRu ? 'Готово' : 'Completed';
    }
    if (upper == 'FAILED' || upper == 'ERROR') {
      return _isRu ? 'Ошибка' : 'Failed';
    }
    if (upper == 'IN_PROGRESS' || upper == 'PROCESSING' || upper == 'PENDING') {
      return _isRu ? 'В процессе' : 'In progress';
    }
    return raw.isEmpty ? tr(context, 'unknown') : raw;
  }

  String _historyStatusLabelForItem(Map<String, dynamic> item) {
    if (_analysisLooksLikeNotFood(item)) {
      return _isRu ? 'Не еда' : 'Not food';
    }
    return _historyStatusLabel(_historyStatusRaw(item));
  }

  Color _historyStatusColor(String raw, ColorScheme cs) {
    final upper = raw.toUpperCase();
    if (upper == 'COMPLETED' || upper == 'SUCCESS') return cs.secondary;
    if (upper == 'FAILED' || upper == 'ERROR') return cs.error;
    return cs.primary;
  }

  String _rawHistoryDishName(Map<String, dynamic> item) {
    return (item['dishName'] ??
                item['dish_name'] ??
                item['title'] ??
                item['name'] ??
                item['detectedDish'])
            ?.toString()
            .trim() ??
        '';
  }

  String _historyDishName(Map<String, dynamic> item) {
    final raw = _rawHistoryDishName(item);
    if (raw.isNotEmpty) return raw;
    if (_analysisLooksLikeNotFood(item)) {
      return _isRu ? 'Это не еда' : 'This is not food';
    }
    final error = _analysisErrorMessage(item);
    if (error.isNotEmpty) return error;
    return tr(context, 'unknown_dish');
  }

  double? _historyCalories(Map<String, dynamic> item) {
    final raw =
        item['calories'] ??
        item['kcal'] ??
        item['estimatedCalories'] ??
        item['estimated_calories'];
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw?.toString() ?? '');
  }

  double? _readAnalysisMacro(Map<String, dynamic> item, String key) {
    final raw = item[key];
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw?.toString().trim().replaceAll(',', '.') ?? '');
  }

  String _formatAnalysisMacro(dynamic raw) {
    final value = raw is num
        ? raw.toDouble()
        : double.tryParse(raw?.toString().trim().replaceAll(',', '.') ?? '');
    if (value == null) return '-';
    final formatted = value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(1);
    return _isRu ? formatted.replaceAll('.', ',') : formatted;
  }

  String _formatCompactValue(num? value) {
    if (value == null) return '--';
    final normalized = value.toDouble();
    final formatted = normalized == normalized.roundToDouble()
        ? normalized.toInt().toString()
        : normalized.toStringAsFixed(1);
    return _isRu ? formatted.replaceAll('.', ',') : formatted;
  }

  bool? _readBool(dynamic value) {
    if (value is bool) return value;
    final text = value?.toString().trim().toLowerCase() ?? '';
    if (text.isEmpty) return null;
    if (text == 'true' || text == '1' || text == 'yes') return true;
    if (text == 'false' || text == '0' || text == 'no') return false;
    return null;
  }

  String _analysisIdOf(Map<String, dynamic> item) {
    return (item['analysisId'] ?? item['analysis_id'] ?? item['id'])
            ?.toString()
            .trim() ??
        '';
  }

  String _analysisExtraInfo(Map<String, dynamic> item) {
    return (item['extraInfo'] ?? item['extra_info'] ?? '').toString().trim();
  }

  String _analysisErrorMessage(Map<String, dynamic> item) {
    return (item['errorMessage'] ?? item['error_message'] ?? '')
        .toString()
        .trim();
  }

  int? _analysisHealthScore(Map<String, dynamic> item) {
    final raw = item['healthScore'] ?? item['health_score'];
    final value = raw is num
        ? raw.toInt()
        : int.tryParse(raw?.toString() ?? '');
    if (value == null) return null;
    return value.clamp(0, 100);
  }

  bool _analysisIsFailed(Map<String, dynamic> item) {
    final status = _historyStatusRaw(item).toUpperCase();
    return status == 'FAILED' || status == 'ERROR';
  }

  bool _analysisLooksLikeNotFood(Map<String, dynamic> item) {
    final combined = <String>[
      _rawHistoryDishName(item),
      _analysisErrorMessage(item),
      _analysisExtraInfo(item),
    ].join(' ').toLowerCase();
    return combined.contains('не еда') ||
        combined.contains('еда не обнаружена') ||
        combined.contains('not food') ||
        combined.contains('food not detected');
  }

  bool _analysisFoodDetected(Map<String, dynamic> item) {
    final explicit = _readBool(
      item['foodDetected'] ??
          item['food_detected'] ??
          item['isFood'] ??
          item['is_food'],
    );
    if (explicit != null) return explicit;
    if (_analysisLooksLikeNotFood(item)) return false;
    return !_analysisIsFailed(item) && _historyCalories(item) != null;
  }

  bool _analysisCanBeSaved(Map<String, dynamic> item) {
    return _historyStatusRaw(item).toUpperCase() == 'COMPLETED' &&
        _analysisFoodDetected(item) &&
        _historyCalories(item) != null;
  }

  String _historyCacheOwner() {
    final ownerRaw =
        _profile?['id'] ??
        _profile?['userId'] ??
        _profile?['user_id'] ??
        _profile?['email'] ??
        _profile?['username'] ??
        _profile?['name'];
    final owner = ownerRaw?.toString().trim().toLowerCase() ?? '';
    if (owner.isEmpty) return 'default';
    return owner.replaceAll(RegExp(r'[^a-z0-9@._-]'), '_');
  }

  bool get _canUseHistoryCache {
    final ownerRaw =
        _profile?['id'] ??
        _profile?['userId'] ??
        _profile?['user_id'] ??
        _profile?['email'] ??
        _profile?['username'];
    final owner = ownerRaw?.toString().trim() ?? '';
    return owner.isNotEmpty;
  }

  String _historyCacheKey() =>
      '${_analysisHistoryCachePrefix}_${_historyCacheOwner()}';

  String _deletedHistoryCacheKey() =>
      '${_analysisHistoryDeletedCachePrefix}_${_historyCacheOwner()}';

  String _historyIdentity(Map<String, dynamic> item) {
    final id =
        (item['analysisId'] ?? item['analysis_id'] ?? item['id'])
            ?.toString()
            .trim() ??
        '';
    if (id.isNotEmpty) return 'id:$id';
    return 'raw:${jsonEncode(item)}';
  }

  bool _isBlankHistoryValue(Object? value) {
    if (value == null) return true;
    if (value is String) return value.trim().isEmpty;
    return false;
  }

  String? _historyLocalImageCandidate(Map<String, dynamic> item) {
    const keys = <String>['imagePath', 'image_path', 'photo'];
    for (final key in keys) {
      final raw = item[key]?.toString().trim() ?? '';
      if (raw.isEmpty ||
          raw.startsWith('http://') ||
          raw.startsWith('https://')) {
        continue;
      }
      if (File(raw).existsSync()) return raw;
    }
    return null;
  }

  Map<String, dynamic> _mergeHistoryEntry(
    Map<String, dynamic> preferred,
    Map<String, dynamic> fallback,
  ) {
    final merged = Map<String, dynamic>.from(preferred);
    fallback.forEach((key, value) {
      if (_isBlankHistoryValue(merged[key]) && !_isBlankHistoryValue(value)) {
        merged[key] = value;
      }
    });

    final preferredLocal = _historyLocalImageCandidate(preferred);
    if (preferredLocal == null) {
      final fallbackLocal = _historyLocalImageCandidate(fallback);
      if (fallbackLocal != null) {
        merged['imagePath'] ??= fallbackLocal;
        merged['image_path'] ??= fallbackLocal;
        merged['photo'] ??= fallbackLocal;
      }
    }
    return merged;
  }

  Future<String?> _persistAnalysisHistoryImage(
    String sourcePath, {
    required String analysisId,
  }) async {
    final rawPath = sourcePath.trim();
    final rawId = analysisId.trim();
    if (rawPath.isEmpty || rawId.isEmpty) return null;

    final source = File(rawPath);
    if (!await source.exists()) return null;

    final docsDir = await getApplicationDocumentsDirectory();
    final historyDir = Directory('${docsDir.path}/analysis_history_images');
    if (!await historyDir.exists()) {
      await historyDir.create(recursive: true);
    }

    final extIndex = rawPath.lastIndexOf('.');
    final extension = extIndex >= 0 && extIndex < rawPath.length - 1
        ? rawPath.substring(extIndex)
        : '.jpg';
    final safeId = rawId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final target = File('${historyDir.path}/analysis_$safeId$extension');
    await source.copy(target.path);
    return target.path;
  }

  List<Map<String, dynamic>> _filterDeletedHistoryItems(
    List<Map<String, dynamic>> items, {
    Set<String>? deletedIds,
  }) {
    final hiddenIds = deletedIds ?? _deletedHistoryIds;
    if (hiddenIds.isEmpty) {
      return items.map((item) => Map<String, dynamic>.from(item)).toList();
    }

    return items
        .where((item) {
          final id = _analysisIdOf(item);
          return id.isEmpty || !hiddenIds.contains(id);
        })
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  List<Map<String, dynamic>> _mergeHistoryItems(
    List<Map<String, dynamic>> incoming,
    List<Map<String, dynamic>> current,
  ) {
    final merged = <String, Map<String, dynamic>>{};
    final ordered = <Map<String, dynamic>>[
      ...incoming.map((e) => Map<String, dynamic>.from(e)),
      ...current.map((e) => Map<String, dynamic>.from(e)),
    ];

    for (final item in ordered) {
      final key = _historyIdentity(item);
      final existing = merged[key];
      if (existing == null) {
        merged[key] = item;
        continue;
      }
      merged[key] = _mergeHistoryEntry(existing, item);
    }

    return merged.values.take(_analysisHistoryLimit).toList();
  }

  List<Map<String, dynamic>> _mergeRemoteHistoryItems(
    List<Map<String, dynamic>> remote,
    List<Map<String, dynamic>> current,
  ) {
    final currentByIdentity = <String, Map<String, dynamic>>{
      for (final item in current)
        _historyIdentity(item): Map<String, dynamic>.from(item),
    };

    return remote
        .map((item) {
          final normalized = Map<String, dynamic>.from(item);
          final existing = currentByIdentity[_historyIdentity(normalized)];
          if (existing == null) return normalized;
          return _mergeHistoryEntry(normalized, existing);
        })
        .take(_analysisHistoryLimit)
        .toList();
  }

  Future<void> _loadCachedAnalysisHistory() async {
    if (!_canUseHistoryCache) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_historyCacheKey());
      if (raw == null || raw.trim().isEmpty) return;

      final decoded = jsonDecode(raw);
      if (decoded is! List) return;

      final cached = decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      final merged = _mergeHistoryItems(
        _filterDeletedHistoryItems(cached),
        _analysisHistory,
      );
      if (!mounted) return;
      setState(() => _analysisHistory = merged);
    } catch (_) {}
  }

  Future<void> _loadDeletedHistoryIds() async {
    if (!_canUseHistoryCache) {
      if (mounted && _deletedHistoryIds.isNotEmpty) {
        setState(() => _deletedHistoryIds = <String>{});
      } else {
        _deletedHistoryIds = <String>{};
      }
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_deletedHistoryCacheKey()) ?? const [];
      final ids = raw
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toSet();

      if (!mounted) {
        _deletedHistoryIds = ids;
        return;
      }

      final filteredHistory = _filterDeletedHistoryItems(
        _analysisHistory,
        deletedIds: ids,
      );
      setState(() {
        _deletedHistoryIds = ids;
        _analysisHistory = filteredHistory;
      });
    } catch (_) {}
  }

  Future<void> _saveCachedAnalysisHistory(
    List<Map<String, dynamic>> history,
  ) async {
    if (!_canUseHistoryCache) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final filtered = _filterDeletedHistoryItems(history);
      await prefs.setString(_historyCacheKey(), jsonEncode(filtered));
    } catch (_) {}
  }

  Future<void> _saveDeletedHistoryIds() async {
    if (!_canUseHistoryCache) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _deletedHistoryCacheKey(),
        _deletedHistoryIds.toList()..sort(),
      );
    } catch (_) {}
  }

  Future<void> _persistCurrentHistoryIfPossible() async {
    if (!_canUseHistoryCache || _analysisHistory.isEmpty) return;
    await _saveCachedAnalysisHistory(_analysisHistory);
  }

  Future<void> _rememberDeletedHistoryId(String analysisId) async {
    final id = analysisId.trim();
    if (id.isEmpty || _deletedHistoryIds.contains(id)) return;

    if (mounted) {
      setState(() => _deletedHistoryIds = {..._deletedHistoryIds, id});
    } else {
      _deletedHistoryIds = {..._deletedHistoryIds, id};
    }
    await _saveDeletedHistoryIds();
  }

  Future<void> _syncDeletedHistoryIds() async {
    if (_deletedHistoryIds.isEmpty) return;

    for (final analysisId in _deletedHistoryIds.toList()) {
      await repository.deleteAnalysisHistoryItem(analysisId);
    }
  }

  Future<void> _upsertHistoryItem(Map<String, dynamic> source) async {
    final item = Map<String, dynamic>.from(source);
    item.putIfAbsent('createdAt', () => DateTime.now().toIso8601String());
    final analysisId = _analysisIdOf(item);
    if (analysisId.isNotEmpty && _deletedHistoryIds.contains(analysisId)) {
      return;
    }

    final merged = _mergeHistoryItems([item], _analysisHistory);
    final filtered = _filterDeletedHistoryItems(merged);
    if (!mounted) return;

    setState(() => _analysisHistory = filtered);
    await _saveCachedAnalysisHistory(filtered);
  }

  Future<void> _deleteHistoryItem(Map<String, dynamic> source) async {
    final analysisId =
        (source['analysisId'] ?? source['analysis_id'] ?? source['id'])
            ?.toString()
            .trim() ??
        '';
    final removeKey = _historyIdentity(source);
    final updated = _analysisHistory
        .where((item) {
          if (analysisId.isNotEmpty) {
            return _analysisIdOf(item) != analysisId;
          }
          return _historyIdentity(item) != removeKey;
        })
        .map((item) => Map<String, dynamic>.from(item))
        .toList();

    if (updated.length == _analysisHistory.length && analysisId.isEmpty) return;
    if (analysisId.isNotEmpty) {
      await _rememberDeletedHistoryId(analysisId);
    }
    if (!mounted) return;

    final isCurrentResult =
        analysisId.isNotEmpty &&
        _analysisIdOf(_analysisResult ?? const {}) == analysisId;
    setState(() {
      _analysisHistory = updated;
      if (isCurrentResult) {
        _analysisResult = null;
      }
    });
    await _saveCachedAnalysisHistory(updated);
    if (!mounted) return;

    if (analysisId.isEmpty) {
      _showFeedback(
        tr(context, 'history_item_deleted'),
        kind: AppFeedbackKind.success,
      );
      return;
    }

    final deleted = await repository.deleteAnalysisHistoryItem(analysisId);
    if (!mounted) return;
    if (deleted) {
      _showFeedback(
        tr(context, 'history_item_deleted'),
        kind: AppFeedbackKind.success,
      );
      await _loadAnalysisHistory(showLoader: false);
      return;
    }

    _showFeedback(
      tr(context, 'history_item_delete_pending'),
      kind: AppFeedbackKind.info,
    );
  }

  Future<void> _loadAnalysisHistory({bool showLoader = true}) async {
    if (showLoader && mounted) {
      setState(() => _isHistoryLoading = true);
    }
    final remote = await repository.getAnalysisHistory(
      limit: _analysisHistoryLimit,
    );
    if (!mounted) return;

    if (remote != null) {
      final incoming = remote
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      final merged = _mergeRemoteHistoryItems(
        _filterDeletedHistoryItems(incoming),
        _analysisHistory,
      );
      setState(() {
        _analysisHistory = merged;
        _isHistoryLoading = false;
      });
      await _saveCachedAnalysisHistory(merged);
      _syncDeletedHistoryIds();
      return;
    }

    await _loadCachedAnalysisHistory();
    if (mounted) setState(() => _isHistoryLoading = false);
  }

  Future<void> _loadProfile() async {
    final profile = await repository.getProfile();
    if (!mounted) return;
    if (profile != null) {
      setState(() => _profile = profile);
      await _persistCurrentHistoryIfPossible();
    }
  }

  Future<void> _bootstrapAnalyzeScreen() async {
    await _loadProfile();
    await _loadDeletedHistoryIds();
    await _loadCachedAnalysisHistory();
    await _loadAnalysisHistory(showLoader: false);
  }

  Future<void> _refreshAnalyzeScreen() async {
    await _loadProfile();
    await _loadDeletedHistoryIds();
    await _loadAnalysisHistory();
  }

  ///Разрешение на камеру
  Future<XFile?> _pickImageFile(ImageSource source) async {
    PermissionStatus status;
    if (source == ImageSource.camera) {
      status = await Permission.camera.request();
    } else {
      status = await Permission.photos.request();
      if (!status.isGranted && Platform.isAndroid) {
        status = await Permission.storage.request();
      }
    }

    if (!status.isGranted) {
      if (mounted) {
        _showFeedback(
          tr(context, 'permission_denied'),
          kind: AppFeedbackKind.error,
          preferPopup: true,
          addToInbox: false,
        );
      }
      return null;
    }

    return _picker.pickImage(source: source, imageQuality: 85);
  }

  ///Получение фото анализа
  Future<void> _pickAnalysisImage(ImageSource source) async {
    final image = await _pickImageFile(source);
    if (image == null || !mounted) return;

    setState(() {
      _selectedImage = File(image.path);
      _analysisResult = null;
    });
  }

  Future<void> _analyzeFood() async {
    if (_selectedImage == null) return;
    final extraQuestions = _buildExtraQuestionsPayload();
    final selectedImagePath = _selectedImage!.path;

    setState(() {
      _isAnalyzing = true;
      _analysisResult = null;
    });

    final analysisId = await repository.startFoodAnalysis(
      XFile(selectedImagePath),
      extraQuestions: extraQuestions,
    );

    if (analysisId == null || !mounted) {
      setState(() => _isAnalyzing = false);
      return;
    }

    await _pollAnalysisResult(analysisId, selectedImagePath);
    if (mounted) {
      setState(() => _isAnalyzing = false);
    }
  }

  Future<void> _pollAnalysisResult(
    String analysisId,
    String selectedImagePath,
  ) async {
    int attempts = 0;
    const maxAttempts = 30;

    while (attempts < maxAttempts) {
      await Future.delayed(const Duration(seconds: 2));

      final result = await repository.getAnalysisResult(analysisId);
      if (result != null) {
        final status = result['status']?.toString() ?? 'UNKNOWN';
        final persistedImagePath = await _persistAnalysisHistoryImage(
          selectedImagePath,
          analysisId: analysisId,
        );
        final historyItem = Map<String, dynamic>.from(result)
          ..putIfAbsent(
            'imagePath',
            () => persistedImagePath ?? selectedImagePath,
          )
          ..putIfAbsent(
            'image_path',
            () => persistedImagePath ?? selectedImagePath,
          )
          ..putIfAbsent('photo', () => persistedImagePath ?? selectedImagePath)
          ..putIfAbsent('analysisId', () => analysisId)
          ..putIfAbsent('status', () => status)
          ..putIfAbsent('createdAt', () => DateTime.now().toIso8601String())
          ..putIfAbsent('analysisBasis', () => _selectedAnalysisBasis)
          ..putIfAbsent('analysis_basis', () => _selectedAnalysisBasis);

        if (status == 'COMPLETED' && _analysisFoodDetected(result)) {
          if (!mounted) return;

          final resolvedBasis = _normalizeAnalysisBasis(
            result['analysisBasis']?.toString() ??
                result['analysis_basis']?.toString() ??
                _selectedAnalysisBasis,
          );
          setState(() {
            _analysisResult = {
              ...result,
              'analysisBasis': resolvedBasis,
              'analysis_basis': resolvedBasis,
            };
          });
          await _upsertHistoryItem(historyItem);
          if (!mounted) return;

          final cal = _historyCalories(historyItem)?.round().toString() ?? '-';
          _showFeedback(
            '${result['dish_name']} | $cal ${tr(context, 'kcal')}',
            kind: AppFeedbackKind.success,
          );
          return;
        }

        if (status == 'FAILED') {
          await _upsertHistoryItem(historyItem);
          if (mounted) {
            final message = _analysisErrorMessage(result);
            _showFeedback(
              message.isEmpty ? tr(context, 'analysis_failed') : message,
              kind: AppFeedbackKind.error,
              preferPopup: true,
            );
          }
          await _loadAnalysisHistory(showLoader: false);
          return;
        }
      }

      attempts++;
    }

    if (mounted) {
      _showFeedback(
        tr(context, 'analysis_timeout'),
        kind: AppFeedbackKind.error,
        preferPopup: true,
      );
    }
  }

  Future<void> _applySavedMealState(
    Map<String, dynamic> analysis,
    Map<String, dynamic> saved,
  ) async {
    final mealId = (saved['mealEntryId'] ?? saved['meal_entry_id'])
        ?.toString()
        .trim();
    final savedAt = (saved['savedAt'] ?? saved['saved_at'])?.toString();
    final analysisId = _analysisIdOf(analysis);
    final updated = Map<String, dynamic>.from(analysis);

    if (mealId != null && mealId.isNotEmpty) {
      updated['saved_meal_id'] = mealId;
      updated['savedMealId'] = mealId;
    }
    if (savedAt != null && savedAt.isNotEmpty) {
      updated['saved_at'] = savedAt;
      updated['savedAt'] = savedAt;
    }

    if (!mounted) return;
    setState(() {
      if (analysisId.isNotEmpty &&
          _analysisIdOf(_analysisResult ?? const {}) == analysisId) {
        _analysisResult = {...?_analysisResult, ...updated};
      }
    });
    await _upsertHistoryItem(updated);
  }

  Future<void> _saveAnalysisItemAsMeal(Map<String, dynamic> analysis) async {
    final analysisId = _analysisIdOf(analysis);
    if (analysisId.isEmpty || _isSavingMeal || !_analysisCanBeSaved(analysis)) {
      return;
    }

    final totalCalories = _historyCalories(analysis);
    final totalProteins = _readAnalysisMacro(analysis, 'protein');
    final totalFats = _readAnalysisMacro(analysis, 'fats');
    final totalCarbs = _readAnalysisMacro(analysis, 'carbs');
    final analysisBasis = _analysisBasisOf(analysis);
    final isPer100gBasis = analysisBasis == _analysisBasisPer100g;
    final estimatedFullPortionWeight = _analysisEstimatedWeightGrams(analysis);
    final titleCtrl = TextEditingController(text: _historyDishName(analysis));
    DateTime eatenAt = DateTime.now();
    double fullPortionWeight = 250;
    double eatenPercent = 100;

    double normalizeWeight(double raw) {
      final rounded = (raw / 5).round() * 5;
      return rounded.clamp(25, 5000).toDouble();
    }

    double normalizePercent(double raw) => raw.clamp(1, 100).roundToDouble();

    fullPortionWeight = normalizeWeight(
      isPer100gBasis ? 250 : (estimatedFullPortionWeight ?? 250),
    );

    double consumedWeightGrams() {
      final raw = fullPortionWeight * (eatenPercent / 100.0);
      if (raw <= 0) return 0;
      return raw.round().clamp(1, 5000).toDouble();
    }

    double maxWeightSliderValue() {
      final roundedUp = ((fullPortionWeight / 100).ceil() * 100).toDouble();
      return (roundedUp < 1000 ? 1000.0 : roundedUp)
          .clamp(1000.0, 5000.0)
          .toDouble();
    }

    double nutritionScale() => consumedWeightGrams() / 100.0;
    double portionRatio() => eatenPercent / 100.0;

    double? scaledMacro(double? sourceValue) {
      if (sourceValue == null) return null;
      if (isPer100gBasis) {
        return sourceValue * nutritionScale();
      }
      return sourceValue * portionRatio();
    }

    int? savedCalories() {
      if (totalCalories == null) return null;
      final value = isPer100gBasis
          ? totalCalories * nutritionScale()
          : totalCalories * portionRatio();
      return value.round();
    }

    int? fullPortionCalories() {
      if (totalCalories == null) return null;
      if (isPer100gBasis) {
        return (totalCalories * (fullPortionWeight / 100.0)).round();
      }
      return totalCalories.round();
    }

    double? fullPortionMacro(double? sourceValue) {
      if (sourceValue == null) return null;
      if (isPer100gBasis) {
        return sourceValue * (fullPortionWeight / 100.0);
      }
      return sourceValue;
    }

    String eatenAmountLabel() {
      final gramsText = _isRu
          ? '${_formatCompactValue(consumedWeightGrams())} г'
          : '${_formatCompactValue(consumedWeightGrams())} g';
      return '${eatenPercent.round()}% • $gramsText';
    }

    Widget buildFieldLabel(String text) {
      return Padding(
        padding: const EdgeInsets.only(left: 2, bottom: 10),
        child: Text(
          text,
          style: TextStyle(
            color: _cs.onSurface,
            fontSize: 16.5,
            fontWeight: FontWeight.w800,
            height: 1.0,
          ),
        ),
      );
    }

    Widget buildSectionCard({
      required IconData icon,
      required String title,
      required String subtitle,
      required Color accent,
      required Widget child,
    }) {
      return AtelierSurfaceCard(
        radius: 24,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AtelierIconBadge(icon: icon, accent: accent, size: 38),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: _cs.onSurface,
                          fontSize: 16.5,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: _cs.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      );
    }

    Widget buildPresetChip({
      required String label,
      required bool selected,
      required VoidCallback onTap,
    }) {
      return ChoiceChip(
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
        selected: selected,
        onSelected: (_) => onTap(),
      );
    }

    Widget buildNutritionPreview({
      required String title,
      required Color accent,
      required String calories,
      required String proteins,
      required String fats,
      required String carbs,
    }) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _blendWithSurface(accent, 0.08),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: accent.withValues(alpha: 0.14)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: _cs.onSurface,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$calories ${tr(context, 'kcal')}',
              style: TextStyle(
                color: accent,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                height: 0.95,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                AtelierTagChip(
                  label:
                      '${tr(context, 'protein')}: $proteins ${tr(context, 'grams')}',
                  foreground: _cs.primary,
                ),
                AtelierTagChip(
                  label:
                      '${tr(context, 'fats')}: $fats ${tr(context, 'grams')}',
                  foreground: _cs.tertiary,
                ),
                AtelierTagChip(
                  label:
                      '${tr(context, 'carbs')}: $carbs ${tr(context, 'grams')}',
                  foreground: _cs.secondary,
                ),
              ],
            ),
          ],
        ),
      );
    }

    final payload = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: true,
      enableDrag: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AtelierSheetHeader(
                    title: _isRu ? 'Сохранить как прием пищи' : 'Save as meal',
                    subtitle: _isRu
                        ? 'Сначала выбери вес всей порции, потом задай процент съеденного. Остальное приложение посчитает само.'
                        : 'First choose the full portion weight, then set the eaten percentage. The app will calculate the rest for you.',
                    onClose: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(height: 18),
                  buildFieldLabel(_isRu ? 'Название' : 'Title'),
                  TextField(
                    controller: titleCtrl,
                    onTapOutside: (_) =>
                        FocusManager.instance.primaryFocus?.unfocus(),
                    decoration: InputDecoration(
                      hintText: _isRu
                          ? 'Например, овсянка с ягодами'
                          : 'For example, oatmeal with berries',
                    ),
                  ),
                  const SizedBox(height: 16),
                  buildSectionCard(
                    icon: Icons.scale_rounded,
                    title: _isRu ? 'Вся порция' : 'Full portion',
                    subtitle: isPer100gBasis
                        ? (_isRu
                              ? 'Выбери примерный вес всей тарелки или упаковки, чтобы видеть граммы.'
                              : 'Choose the approximate full plate or package weight to keep the grams preview accurate.')
                        : (estimatedFullPortionWeight != null
                              ? (_isRu
                                    ? 'AI уже оценил порцию примерно в ${_formatCompactValue(estimatedFullPortionWeight)} г. Вес примерный, его можно поправить.'
                                    : 'AI already estimated the portion at about ${_formatCompactValue(estimatedFullPortionWeight)} g. This weight is approximate and can be adjusted.')
                              : (_isRu
                                    ? 'AI оценил полную порцию, но вес всё равно примерный. При необходимости подправь его.'
                                    : 'AI estimated the full portion, but the weight is still approximate. Adjust it if needed.')),
                    accent: _cs.primary,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: _blendWithSurface(_cs.primary, 0.12),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Text(
                                _isRu
                                    ? '${_formatCompactValue(fullPortionWeight)} г'
                                    : '${_formatCompactValue(fullPortionWeight)} g',
                                style: TextStyle(
                                  color: _cs.primary,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  height: 1.0,
                                ),
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: () {
                                setSheetState(() {
                                  fullPortionWeight = normalizeWeight(
                                    fullPortionWeight - 25,
                                  );
                                });
                              },
                              style: IconButton.styleFrom(
                                backgroundColor: _panelBackground,
                                foregroundColor: _cs.onSurface,
                              ),
                              icon: const Icon(Icons.remove_rounded),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: () {
                                setSheetState(() {
                                  fullPortionWeight = normalizeWeight(
                                    fullPortionWeight + 25,
                                  );
                                });
                              },
                              style: IconButton.styleFrom(
                                backgroundColor: _cs.primary,
                                foregroundColor: Colors.white,
                              ),
                              icon: const Icon(Icons.add_rounded),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            OutlinedButton(
                              onPressed: () {
                                setSheetState(() {
                                  fullPortionWeight = normalizeWeight(
                                    fullPortionWeight - 5,
                                  );
                                });
                              },
                              child: Text(_isRu ? '-5 г' : '-5 g'),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 8,
                                  thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 10,
                                  ),
                                  overlayShape: const RoundSliderOverlayShape(
                                    overlayRadius: 18,
                                  ),
                                  activeTrackColor: _cs.primary,
                                  inactiveTrackColor:
                                      _cs.surfaceContainerHighest,
                                  thumbColor: _cs.primary,
                                  overlayColor: _cs.primary.withValues(
                                    alpha: 0.12,
                                  ),
                                ),
                                child: Slider(
                                  value: fullPortionWeight.clamp(
                                    25,
                                    maxWeightSliderValue(),
                                  ),
                                  min: 25,
                                  max: maxWeightSliderValue(),
                                  onChanged: (raw) {
                                    setSheetState(() {
                                      fullPortionWeight = normalizeWeight(raw);
                                    });
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            OutlinedButton(
                              onPressed: () {
                                setSheetState(() {
                                  fullPortionWeight = normalizeWeight(
                                    fullPortionWeight + 5,
                                  );
                                });
                              },
                              child: Text(_isRu ? '+5 г' : '+5 g'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [150, 200, 250, 300, 400, 500].map((grams) {
                            return buildPresetChip(
                              label: _isRu ? '$grams г' : '$grams g',
                              selected: fullPortionWeight == grams,
                              onTap: () {
                                setSheetState(() {
                                  fullPortionWeight = grams.toDouble();
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  buildSectionCard(
                    icon: Icons.pie_chart_rounded,
                    title: _isRu ? 'Съедено' : 'Eaten',
                    subtitle: _isRu
                        ? 'Укажи долю съеденного, а ниже сразу увидишь граммы'
                        : 'Set the eaten share and see the grams below instantly',
                    accent: _AnalyzeScreenState._accentOrange,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: _blendWithSurface(
                                  _AnalyzeScreenState._accentOrange,
                                  0.12,
                                ),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Text(
                                '${eatenPercent.round()}%',
                                style: TextStyle(
                                  color: _AnalyzeScreenState._accentOrangeDeep,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  height: 1.0,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _isRu
                                        ? '≈ ${_formatCompactValue(consumedWeightGrams())} г'
                                        : '≈ ${_formatCompactValue(consumedWeightGrams())} g',
                                    style: TextStyle(
                                      color: _cs.onSurface,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      height: 1.0,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _isRu
                                        ? '${_formatCompactValue(savedCalories())} ккал сохранится'
                                        : '${_formatCompactValue(savedCalories())} kcal will be saved',
                                    style: TextStyle(
                                      color: _cs.onSurfaceVariant,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                setSheetState(() {
                                  eatenPercent = normalizePercent(
                                    eatenPercent - 1,
                                  );
                                });
                              },
                              style: IconButton.styleFrom(
                                backgroundColor: _panelBackground,
                                foregroundColor: _cs.onSurface,
                              ),
                              icon: const Icon(Icons.remove_rounded),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: () {
                                setSheetState(() {
                                  eatenPercent = normalizePercent(
                                    eatenPercent + 1,
                                  );
                                });
                              },
                              style: IconButton.styleFrom(
                                backgroundColor:
                                    _AnalyzeScreenState._accentOrange,
                                foregroundColor: Colors.white,
                              ),
                              icon: const Icon(Icons.add_rounded),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 10,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 12,
                            ),
                            overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 22,
                            ),
                            activeTrackColor: _AnalyzeScreenState._accentOrange,
                            inactiveTrackColor: _cs.surfaceContainerHighest,
                            thumbColor: _AnalyzeScreenState._accentOrangeDeep,
                            overlayColor: _AnalyzeScreenState._accentOrange
                                .withValues(alpha: 0.14),
                          ),
                          child: Slider(
                            value: eatenPercent,
                            min: 1,
                            max: 100,
                            divisions: 99,
                            onChanged: (raw) {
                              setSheetState(() {
                                eatenPercent = normalizePercent(raw);
                              });
                            },
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              '1%',
                              style: TextStyle(
                                color: _cs.onSurfaceVariant,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              _isRu ? 'доля съеденного' : 'eaten share',
                              style: TextStyle(
                                color: _cs.onSurfaceVariant,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '100%',
                              style: TextStyle(
                                color: _cs.onSurfaceVariant,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [25, 50, 75, 100].map((percent) {
                            return buildPresetChip(
                              label: '$percent%',
                              selected: eatenPercent == percent,
                              onTap: () {
                                setSheetState(() {
                                  eatenPercent = percent.toDouble();
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: buildNutritionPreview(
                          title: _isRu ? 'Вся порция' : 'Full portion',
                          accent: _cs.primary,
                          calories: _formatCompactValue(fullPortionCalories()),
                          proteins: _formatCompactValue(
                            fullPortionMacro(totalProteins),
                          ),
                          fats: _formatCompactValue(
                            fullPortionMacro(totalFats),
                          ),
                          carbs: _formatCompactValue(
                            fullPortionMacro(totalCarbs),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: buildNutritionPreview(
                          title: _isRu ? 'Сохранится' : 'Will be saved',
                          accent: _AnalyzeScreenState._accentOrange,
                          calories: _formatCompactValue(savedCalories()),
                          proteins: _formatCompactValue(
                            scaledMacro(totalProteins),
                          ),
                          fats: _formatCompactValue(scaledMacro(totalFats)),
                          carbs: _formatCompactValue(scaledMacro(totalCarbs)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      isPer100gBasis
                          ? (_isRu
                                ? 'Основа расчёта: AI-оценка на 100 г.'
                                : 'Calculation base: AI estimate per 100 g.')
                          : (_isRu
                                ? 'Основа расчёта: AI-оценка полной порции. Вес примерный.'
                                : 'Calculation base: AI estimate for the full portion. Weight is approximate.'),
                      style: TextStyle(
                        color: _cs.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  buildFieldLabel(_isRu ? 'Когда съедено' : 'Eaten at'),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    tileColor: _panelBackground,
                    title: Text(
                      _isRu ? 'Дата и время' : 'Date and time',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    subtitle: Text(_formatHistoryDate(eatenAt)),
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
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                          child: Text(_isRu ? 'Отмена' : 'Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            Navigator.of(context).pop({
                              'title': titleCtrl.text.trim().isEmpty
                                  ? _historyDishName(analysis)
                                  : titleCtrl.text.trim(),
                              'calories': savedCalories(),
                              'proteins': scaledMacro(totalProteins),
                              'fats': scaledMacro(totalFats),
                              'carbohydrates': scaledMacro(totalCarbs),
                              'eatenAt': eatenAt.toIso8601String(),
                              'amountEaten': eatenAmountLabel(),
                              'amountMode': 'PERCENT',
                              'eatenRatio': eatenPercent / 100.0,
                              'totalWeightGrams': fullPortionWeight,
                              'eatenWeightGrams': consumedWeightGrams(),
                              'packageFractionNumerator': null,
                              'packageFractionDenominator': null,
                              'fullPortionCalories': fullPortionCalories(),
                              'fullPortionProteins': fullPortionMacro(
                                totalProteins,
                              ),
                              'fullPortionFats': fullPortionMacro(totalFats),
                              'fullPortionCarbohydrates': fullPortionMacro(
                                totalCarbs,
                              ),
                              'notes': null,
                            });
                          },
                          child: Text(_isRu ? 'Сохранить' : 'Save'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (payload == null) return;

    setState(() => _isSavingMeal = true);
    final saved = await repository.saveFoodAnalysis(analysisId, data: payload);
    if (!mounted) return;
    setState(() => _isSavingMeal = false);
    if (saved != null) {
      await _applySavedMealState(analysis, saved);
    }
    if (!mounted) return;
    _showFeedback(
      saved != null
          ? (_isRu ? 'Прием пищи сохранен' : 'Meal saved')
          : (_isRu ? 'Не удалось сохранить прием пищи' : 'Failed to save meal'),
      kind: saved != null ? AppFeedbackKind.success : AppFeedbackKind.error,
      preferPopup: saved == null,
    );
  }

  Future<void> _saveAnalysisAsMeal() async {
    if (_analysisResult == null) return;

    // Сразу сохраняем по анализу без диалога выбора
    await _saveAnalysisItemAsMeal(_analysisResult!);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: _screenBackground,
      appBar: AppTopBar(
        title: tr(context, 'tab_analyze'),
        actions: [
          AppTopAction(
            icon: Icons.settings_rounded,
            tooltip: tr(context, 'settings'),
            onPressed: () => showAppSettingsSheet(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAnalyzeScreen,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
          children: [
            _buildImagePickerCard(),
            const SizedBox(height: 24),
            _buildAnalyzeButton(),
            const SizedBox(height: 24),
            _buildQuestionsCard(),
            const SizedBox(height: 24),
            if (_analysisResult != null) _buildResultCard(),
            if (_analysisResult != null) const SizedBox(height: 24),
            _buildAnalysisHistoryCard(),
          ],
        ),
      ),
    );
  }
}
