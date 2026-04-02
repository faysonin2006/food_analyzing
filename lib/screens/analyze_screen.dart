import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/atelier_ui.dart';
import '../core/app_top_bar.dart';
import '../core/app_scope.dart';
import '../core/app_theme.dart';
import '../core/settings_sheet.dart';
import '../core/tr.dart';
import '../repositories/app_repository.dart';
part "analyze/analyze_ui.dart";

class AnalyzeScreen extends StatefulWidget {
  const AnalyzeScreen({super.key});

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

  final AppRepository repository = AppRepository.instance;
  final ImagePicker _picker = ImagePicker();

  Map<String, dynamic>? _profile;
  File? _selectedImage;
  bool _isAnalyzing = false;
  Map<String, dynamic>? _analysisResult;
  String? _savedMealId;
  bool _isSavingMeal = false;
  bool _isHistoryLoading = false;
  List<Map<String, dynamic>> _analysisHistory = [];
  Set<String> _deletedHistoryIds = <String>{};

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
  void initState() {
    super.initState();
    _loadDeletedHistoryIds();
    _loadProfile();
    _loadCachedAnalysisHistory();
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

  List<_QuestionPreset> get _coreQuestionPresets {
    final result = <_QuestionPreset>[];
    for (final id in _coreQuestionIds) {
      final preset = _questionById(id);
      if (preset != null) result.add(preset);
    }
    return result;
  }

  List<_QuestionPreset> _filterQuestionPresets(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return _questionPresets;
    return _questionPresets.where((item) => item.matches(q)).toList();
  }

  String _buildExtraQuestionsPayload() {
    if (_selectedQuestionIds.isEmpty) return '';
    return _selectedQuestionIds.map(_questionTextById).join('\n');
  }

  void _toggleQuestionSelection(String id, bool selected) {
    if (selected) {
      if (_selectedQuestionIds.contains(id)) return;
      if (_selectedQuestionIds.length >= _maxSelectedQuestions) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr(context, 'analysis_questions_limit_error')),
          ),
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

  String? _analysisSavedMealIdOf(Map<String, dynamic> item) {
    final raw =
        item['savedMealId'] ??
        item['saved_meal_id'] ??
        item['mealEntryId'] ??
        item['meal_entry_id'];
    final value = raw?.toString().trim() ?? '';
    return value.isEmpty ? null : value;
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

  bool _analysisAlreadySaved(Map<String, dynamic> item) {
    return (_analysisSavedMealIdOf(item)?.isNotEmpty ?? false) ||
        (_analysisIdOf(item).isNotEmpty &&
            _analysisIdOf(_analysisResult ?? const {}) == _analysisIdOf(item) &&
            (_savedMealId?.isNotEmpty ?? false));
  }

  bool _analysisCanBeSaved(Map<String, dynamic> item) {
    return _historyStatusRaw(item).toUpperCase() == 'COMPLETED' &&
        _analysisFoodDetected(item) &&
        _historyCalories(item) != null &&
        !_analysisAlreadySaved(item);
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
      merged.putIfAbsent(key, () => item);
    }

    return merged.values.take(_analysisHistoryLimit).toList();
  }

  Future<void> _loadCachedAnalysisHistory() async {
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
    try {
      final prefs = await SharedPreferences.getInstance();
      final filtered = _filterDeletedHistoryItems(history);
      await prefs.setString(_historyCacheKey(), jsonEncode(filtered));
    } catch (_) {}
  }

  Future<void> _saveDeletedHistoryIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _deletedHistoryCacheKey(),
        _deletedHistoryIds.toList()..sort(),
      );
    } catch (_) {}
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
        _savedMealId = null;
      }
    });
    await _saveCachedAnalysisHistory(updated);
    if (!mounted) return;

    if (analysisId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(context, 'history_item_deleted'))),
      );
      return;
    }

    final deleted = await repository.deleteAnalysisHistoryItem(analysisId);
    if (!mounted) return;
    if (deleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(context, 'history_item_deleted'))),
      );
      await _loadAnalysisHistory(showLoader: false);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr(context, 'history_item_delete_pending'))),
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
      final merged = _mergeHistoryItems(
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
    if (!mounted || profile == null) return;
    setState(() => _profile = profile);
    await _loadDeletedHistoryIds();
    await _loadAnalysisHistory(showLoader: false);
  }

  Future<void> _refreshAnalyzeScreen() async {
    await _loadProfile();
    await _loadAnalysisHistory();
  }

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr(context, 'permission_denied'))),
        );
      }
      return null;
    }

    return _picker.pickImage(source: source, imageQuality: 85);
  }

  Future<void> _pickAnalysisImage(ImageSource source) async {
    final image = await _pickImageFile(source);
    if (image == null || !mounted) return;

    setState(() {
      _selectedImage = File(image.path);
      _analysisResult = null;
      _savedMealId = null;
    });
  }

  Future<void> _analyzeFood() async {
    if (_selectedImage == null) return;
    final extraQuestions = _buildExtraQuestionsPayload();
    final selectedImagePath = _selectedImage!.path;

    setState(() {
      _isAnalyzing = true;
      _analysisResult = null;
      _savedMealId = null;
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
        final historyItem = Map<String, dynamic>.from(result)
          ..putIfAbsent('imagePath', () => selectedImagePath)
          ..putIfAbsent('photo', () => selectedImagePath)
          ..putIfAbsent('photo_url', () => selectedImagePath)
          ..putIfAbsent('analysisId', () => analysisId)
          ..putIfAbsent('status', () => status)
          ..putIfAbsent('createdAt', () => DateTime.now().toIso8601String());

        if (status == 'COMPLETED' && _analysisFoodDetected(result)) {
          if (!mounted) return;

          setState(() => _analysisResult = result);
          _savedMealId = result['saved_meal_id']?.toString();
          await _upsertHistoryItem(historyItem);
          if (!mounted) return;

          final cal = _historyCalories(historyItem)?.round().toString() ?? '-';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${result['dish_name']} | $cal ${tr(context, 'kcal')}',
              ),
              backgroundColor: _cs.secondary,
              duration: const Duration(seconds: 3),
            ),
          );
          return;
        }

        if (status == 'FAILED') {
          await _upsertHistoryItem(historyItem);
          if (mounted) {
            final message = _analysisErrorMessage(result);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  message.isEmpty ? tr(context, 'analysis_failed') : message,
                ),
              ),
            );
          }
          await _loadAnalysisHistory(showLoader: false);
          return;
        }
      }

      attempts++;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr(context, 'analysis_timeout')),
          backgroundColor: _cs.tertiary,
        ),
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
        _savedMealId = mealId;
      }
    });
    await _upsertHistoryItem(updated);
  }

  Future<void> _saveAnalysisItemAsMeal(Map<String, dynamic> analysis) async {
    final analysisId = _analysisIdOf(analysis);
    if (analysisId.isEmpty || _isSavingMeal || !_analysisCanBeSaved(analysis)) {
      return;
    }

    final titleCtrl = TextEditingController(text: _historyDishName(analysis));
    final caloriesCtrl = TextEditingController(
      text: (analysis['calories'] ?? '').toString(),
    );
    final proteinsCtrl = TextEditingController(
      text: (analysis['protein'] ?? '').toString(),
    );
    final fatsCtrl = TextEditingController(
      text: (analysis['fats'] ?? '').toString(),
    );
    final carbsCtrl = TextEditingController(
      text: (analysis['carbs'] ?? '').toString(),
    );
    final notesCtrl = TextEditingController();
    DateTime eatenAt = DateTime.now();

    final payload = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _isRu ? 'Сохранить как прием пищи' : 'Save as meal',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: titleCtrl,
                  decoration: InputDecoration(
                    labelText: _isRu ? 'Название' : 'Title',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: caloriesCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: _isRu ? 'Калории' : 'Calories',
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: proteinsCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(labelText: 'Protein'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: fatsCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(labelText: 'Fats'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: carbsCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(labelText: 'Carbs'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_isRu ? 'Когда съедено' : 'Eaten at'),
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
                TextField(
                  controller: notesCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: _isRu ? 'Заметки' : 'Notes',
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(context).pop({
                        'title': titleCtrl.text.trim(),
                        'calories': int.tryParse(caloriesCtrl.text.trim()),
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
                        'notes': notesCtrl.text.trim().isEmpty
                            ? null
                            : notesCtrl.text.trim(),
                      });
                    },
                    child: Text(_isRu ? 'Сохранить' : 'Save'),
                  ),
                ),
              ],
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved != null
              ? (_isRu ? 'Прием пищи сохранен' : 'Meal saved')
              : (_isRu
                    ? 'Не удалось сохранить прием пищи'
                    : 'Failed to save meal'),
        ),
      ),
    );
  }

  Future<void> _saveAnalysisAsMeal() async {
    if (_analysisResult == null) return;
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
            icon: Icons.refresh_rounded,
            onPressed: _refreshAnalyzeScreen,
          ),
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
            _buildQuestionsCard(),
            const SizedBox(height: 24),
            _buildAnalyzeButton(),
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
