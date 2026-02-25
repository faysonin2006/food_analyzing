import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_top_bar.dart';
import '../core/app_scope.dart';
import '../core/settings_sheet.dart';
import '../core/tr.dart';
import '../services/api_service.dart';

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
  static const Color _accentOrange = Color(0xFFF1A62B);
  static const Color _accentOrangeDeep = Color(0xFFD8881E);

  final apiService = ApiService();
  final ImagePicker _picker = ImagePicker();

  Map<String, dynamic>? _profile;
  File? _selectedImage;
  bool _isAnalyzing = false;
  Map<String, dynamic>? _analysisResult;
  bool _isHistoryLoading = false;
  List<Map<String, dynamic>> _analysisHistory = [];

  final List<String> _selectedQuestionIds = [];

  static const int _maxSelectedQuestions = 5;
  static const int _analysisHistoryLimit = 10;
  static const String _analysisHistoryCachePrefix = 'analysis_history_cache_v1';
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
  Color get _screenBackground =>
      _isDarkTheme ? _theme.scaffoldBackgroundColor : const Color(0xFFF4D9B1);
  Color get _panelBackground => _isDarkTheme
      ? Color.alphaBlend(
          _cs.surfaceContainerHighest.withValues(alpha: 0.56),
          _cs.surface,
        )
      : const Color(0xFFF6F6F7);

  @override
  void initState() {
    super.initState();
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

  Future<void> _openQuestionsPicker() async {
    var localQuery = '';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final filtered = _filterQuestionPresets(localQuery);
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.88,
              minChildSize: 0.55,
              maxChildSize: 0.95,
              builder: (context, scrollController) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            tr(context, 'analysis_questions_title'),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _blendWithSurface(
                              _cs.primary,
                              _isDarkTheme ? 0.3 : 0.12,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${_selectedQuestionIds.length}/$_maxSelectedQuestions',
                            style: TextStyle(
                              color: _cs.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      onChanged: (value) =>
                          setSheetState(() => localQuery = value),
                      decoration: InputDecoration(
                        hintText: tr(context, 'analysis_questions_search_hint'),
                        prefixIcon: const Icon(Icons.search_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Text(
                                tr(context, 'analysis_questions_no_matches'),
                                style: TextStyle(color: _cs.onSurfaceVariant),
                              ),
                            )
                          : ListView.separated(
                              controller: scrollController,
                              itemCount: filtered.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 4),
                              itemBuilder: (_, index) {
                                final item = filtered[index];
                                final selected = _selectedQuestionIds.contains(
                                  item.id,
                                );
                                return CheckboxListTile(
                                  value: selected,
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  title: Text(item.text(_isRu)),
                                  onChanged: (value) {
                                    if (value == null) return;
                                    _toggleQuestionSelection(item.id, value);
                                    setSheetState(() {});
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
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

  Color _historyStatusColor(String raw, ColorScheme cs) {
    final upper = raw.toUpperCase();
    if (upper == 'COMPLETED' || upper == 'SUCCESS') return cs.secondary;
    if (upper == 'FAILED' || upper == 'ERROR') return cs.error;
    return cs.primary;
  }

  String _historyDishName(Map<String, dynamic> item) {
    return (item['dishName'] ??
                item['dish_name'] ??
                item['title'] ??
                item['name'] ??
                item['detectedDish'])
            ?.toString() ??
        tr(context, 'unknown_dish');
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

  String _historyIdentity(Map<String, dynamic> item) {
    final id =
        (item['analysisId'] ?? item['analysis_id'] ?? item['id'])
            ?.toString()
            .trim() ??
        '';
    if (id.isNotEmpty) return 'id:$id';
    return 'raw:${jsonEncode(item)}';
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

      final merged = _mergeHistoryItems(cached, _analysisHistory);
      if (!mounted) return;
      setState(() => _analysisHistory = merged);
    } catch (_) {}
  }

  Future<void> _saveCachedAnalysisHistory(
    List<Map<String, dynamic>> history,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_historyCacheKey(), jsonEncode(history));
    } catch (_) {}
  }

  Future<void> _upsertHistoryItem(Map<String, dynamic> source) async {
    final item = Map<String, dynamic>.from(source);
    item.putIfAbsent('createdAt', () => DateTime.now().toIso8601String());

    final merged = _mergeHistoryItems([item], _analysisHistory);
    if (!mounted) return;

    setState(() => _analysisHistory = merged);
    await _saveCachedAnalysisHistory(merged);
  }

  Future<void> _loadAnalysisHistory({bool showLoader = true}) async {
    if (showLoader && mounted) {
      setState(() => _isHistoryLoading = true);
    }

    final remote = await apiService.getAnalysisHistory(
      limit: _analysisHistoryLimit,
    );
    if (!mounted) return;

    if (remote != null) {
      final normalized = remote
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      final merged = _mergeHistoryItems(normalized, _analysisHistory);
      setState(() {
        _analysisHistory = merged;
        _isHistoryLoading = false;
      });
      await _saveCachedAnalysisHistory(merged);
      return;
    }

    if (mounted) {
      setState(() => _isHistoryLoading = false);
    }
  }

  Future<void> _loadProfile() async {
    final profile = await apiService.getProfile();
    if (!mounted || profile == null) return;
    setState(() => _profile = profile);
    await _loadCachedAnalysisHistory();
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

    final analysisId = await apiService.startFoodAnalysis(
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

      final result = await apiService.getAnalysisResult(analysisId);
      if (result != null) {
        final status = result['status']?.toString() ?? 'UNKNOWN';

        if (status == 'COMPLETED' &&
            result['dish_name'] != null &&
            result['dish_name'].toString().isNotEmpty &&
            result['calories'] != null) {
          if (!mounted) return;

          setState(() => _analysisResult = result);
          final historyItem = Map<String, dynamic>.from(result)
            ..putIfAbsent('imagePath', () => selectedImagePath)
            ..putIfAbsent('photo', () => selectedImagePath)
            ..putIfAbsent('photo_url', () => selectedImagePath)
            ..putIfAbsent('analysisId', () => analysisId)
            ..putIfAbsent('status', () => status)
            ..putIfAbsent('createdAt', () => DateTime.now().toIso8601String());

          await _upsertHistoryItem(historyItem);
          if (!mounted) return;

          final cal = _historyCalories(historyItem)?.round().toString() ?? '-';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '✅ ${result['dish_name']} | $cal ${tr(context, 'kcal')}',
              ),
              backgroundColor: _cs.secondary,
              duration: const Duration(seconds: 3),
            ),
          );
          return;
        }

        if (status == 'FAILED') {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(tr(context, 'analysis_failed'))),
            );
          }
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

  Widget _buildImagePickerCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: _selectedImage != null
                  ? ClipRRect(
                      key: const ValueKey('selected_image'),
                      borderRadius: BorderRadius.circular(18),
                      child: Image.file(
                        _selectedImage!,
                        width: double.infinity,
                        height: 220,
                        fit: BoxFit.cover,
                      ),
                    )
                  : Container(
                      key: const ValueKey('placeholder'),
                      width: double.infinity,
                      height: 220,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            _blendWithSurface(_accentOrange, 0.22),
                            _blendWithSurface(_accentOrangeDeep, 0.14),
                          ],
                        ),
                        border: Border.all(
                          color: _cs.outlineVariant.withValues(alpha: 0.6),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.restaurant_menu_rounded,
                            size: 58,
                            color: _accentOrangeDeep,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            tr(context, 'photo_not_selected'),
                            style: TextStyle(
                              color: _cs.onSurfaceVariant.withValues(
                                alpha: 0.85,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.photo_library_rounded),
                    label: Text(tr(context, 'gallery')),
                    onPressed: () => _pickAnalysisImage(ImageSource.gallery),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.camera_alt_rounded),
                    label: Text(tr(context, 'camera')),
                    onPressed: () => _pickAnalysisImage(ImageSource.camera),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr(context, 'analysis_questions_core_title'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            ..._coreQuestionPresets.map((item) {
              final selected = _selectedQuestionIds.contains(item.id);
              return CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: selected,
                activeColor: _accentOrange,
                checkColor: Colors.white,
                title: Text(item.text(_isRu)),
                onChanged: (v) {
                  if (v == null) return;
                  _toggleQuestionSelection(item.id, v);
                },
              );
            }),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _selectedQuestionIds
                  .map(
                    (id) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _blendWithSurface(_accentOrange, 0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _questionTextById(id),
                        style: TextStyle(
                          color: _cs.onSurface,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: _openQuestionsPicker,
                icon: const Icon(Icons.tune_rounded),
                label: Text(tr(context, 'analysis_questions_open_search')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyzeButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: _accentOrange,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _cs.surfaceContainerHighest,
          disabledForegroundColor: _cs.onSurfaceVariant,
        ),
        onPressed: (_selectedImage == null || _isAnalyzing)
            ? null
            : _analyzeFood,
        child: Text(
          _isAnalyzing
              ? tr(context, 'analyzing')
              : tr(context, 'start_analysis'),
        ),
      ),
    );
  }

  Widget _buildNutrientCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _blendWithSurface(_accentOrange, 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: _accentOrangeDeep),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$label: $value',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _cs.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard() {
    final result = _analysisResult;
    if (result == null) return const SizedBox.shrink();
    final cs = _cs;

    final dishName = (result['dish_name'] ?? tr(context, 'unknown_dish'))
        .toString();
    final calories = result['calories']?.toString() ?? '-';
    final protein = result['protein']?.toString() ?? '-';
    final fats = result['fats']?.toString() ?? '-';
    final carbs = result['carbs']?.toString() ?? '-';
    final extraInfo = (result['extra_info'] ?? '').toString().trim();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle_rounded, color: cs.secondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    dishName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _buildNutrientCard(
              tr(context, 'calories'),
              '$calories ${tr(context, 'kcal')}',
              Icons.local_fire_department_rounded,
            ),
            const SizedBox(height: 8),
            _buildNutrientCard(
              tr(context, 'protein'),
              protein,
              Icons.fitness_center_rounded,
            ),
            const SizedBox(height: 8),
            _buildNutrientCard(
              tr(context, 'fats'),
              fats,
              Icons.opacity_rounded,
            ),
            const SizedBox(height: 8),
            _buildNutrientCard(
              tr(context, 'carbs'),
              carbs,
              Icons.grain_rounded,
            ),
            if (extraInfo.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(extraInfo, style: TextStyle(color: cs.onSurfaceVariant)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryPhoto(Map<String, dynamic> item, {double size = 72}) {
    final photoValue =
        item['photo'] ??
        item['photo_url'] ??
        item['imagePath'] ??
        item['image_path'] ??
        item['image_url'];

    final path = photoValue?.toString().trim() ?? '';
    if (path.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: _blendWithSurface(_accentOrange, 0.12),
        ),
        child: Icon(Icons.photo_rounded, color: _accentOrangeDeep),
      );
    }

    if (path.startsWith('http://') || path.startsWith('https://')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          path,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(
            width: size,
            height: size,
            color: _blendWithSurface(_accentOrange, 0.12),
            child: Icon(Icons.broken_image_rounded, color: _accentOrangeDeep),
          ),
        ),
      );
    }

    final file = File(path);
    if (!file.existsSync()) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: _blendWithSurface(_accentOrange, 0.12),
        ),
        child: Icon(
          Icons.image_not_supported_rounded,
          color: _accentOrangeDeep,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.file(file, width: size, height: size, fit: BoxFit.cover),
    );
  }

  Widget _buildHistoryItemCard(Map<String, dynamic> item) {
    final cs = _cs;
    final dish = _historyDishName(item);
    final date = _formatHistoryDate(_historyDate(item));
    final statusRaw = _historyStatusRaw(item);
    final statusLabel = _historyStatusLabel(statusRaw);
    final statusColor = _historyStatusColor(statusRaw, cs);
    final calories = _historyCalories(item);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _openHistoryDetails(item),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: _blendWithSurface(_accentOrange, 0.06),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
        ),
        child: Row(
          children: [
            _buildHistoryPhoto(item),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dish,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 14,
                        color: cs.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          date,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      if (calories != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _blendWithSurface(
                              cs.tertiary,
                              _isDarkTheme ? 0.26 : 0.12,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${calories.round()} ${tr(context, 'kcal')}',
                            style: TextStyle(
                              color: cs.tertiary,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  void _openHistoryDetails(Map<String, dynamic> item) {
    final dish = _historyDishName(item);
    final calories = _historyCalories(item);
    final protein = item['protein']?.toString() ?? '-';
    final fats = item['fats']?.toString() ?? '-';
    final carbs = item['carbs']?.toString() ?? '-';
    final extraInfo = (item['extra_info'] ?? item['extraInfo'] ?? '')
        .toString()
        .trim();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.9,
        minChildSize: 0.6,
        maxChildSize: 0.95,
        builder: (_, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Text(
              dish,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Center(child: _buildHistoryPhoto(item, size: 220)),
            const SizedBox(height: 16),
            _buildNutrientCard(
              tr(context, 'calories'),
              calories == null
                  ? '-'
                  : '${calories.round()} ${tr(context, 'kcal')}',
              Icons.local_fire_department_rounded,
            ),
            const SizedBox(height: 8),
            _buildNutrientCard(
              tr(context, 'protein'),
              protein,
              Icons.fitness_center_rounded,
            ),
            const SizedBox(height: 8),
            _buildNutrientCard(
              tr(context, 'fats'),
              fats,
              Icons.opacity_rounded,
            ),
            const SizedBox(height: 8),
            _buildNutrientCard(
              tr(context, 'carbs'),
              carbs,
              Icons.grain_rounded,
            ),
            if (extraInfo.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _blendWithSurface(_accentOrange, 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(extraInfo),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisHistoryCard() {
    final cs = _cs;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history_rounded, color: _accentOrangeDeep),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tr(context, 'analysis_history_title'),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_isHistoryLoading)
              const Center(child: CircularProgressIndicator())
            else if (_analysisHistory.isEmpty)
              Text(
                tr(context, 'analysis_history_empty'),
                style: TextStyle(color: cs.onSurfaceVariant),
              )
            else
              Column(
                children: _analysisHistory
                    .map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _buildHistoryItemCard(item),
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
    );
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
          AppTopAction(
            icon: Icons.logout_rounded,
            tooltip: tr(context, 'logout'),
            destructive: true,
            onPressed: () async {
              await apiService.logout();
              if (!context.mounted) return;
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAnalyzeScreen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
          child: Container(
            decoration: BoxDecoration(
              color: _panelBackground,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(34),
                bottom: Radius.circular(34),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: _isDarkTheme ? 0.24 : 0.06,
                  ),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(34),
                bottom: Radius.circular(34),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                child: Column(
                  children: [
                    _buildImagePickerCard(),
                    const SizedBox(height: 24),
                    _buildQuestionsCard(),
                    const SizedBox(height: 24),
                    _buildAnalyzeButton(),
                    const SizedBox(height: 24),
                    if (_analysisResult != null) _buildResultCard(),
                    const SizedBox(height: 24),
                    _buildAnalysisHistoryCard(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
