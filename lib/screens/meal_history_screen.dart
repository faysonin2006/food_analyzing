import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/atelier_ui.dart';
import '../core/app_top_bar.dart';
import '../core/smart_food_suggestions.dart';
import '../core/smart_suggestion_ml.dart';
import '../core/smart_suggestion_panel.dart';
import '../repositories/app_repository.dart';

class MealHistoryScreen extends StatefulWidget {
  const MealHistoryScreen({super.key, this.openComposerOnStart = false});

  final bool openComposerOnStart;

  @override
  State<MealHistoryScreen> createState() => _MealHistoryScreenState();
}

class _MealHistoryScreenState extends State<MealHistoryScreen> {
  final AppRepository repository = AppRepository.instance;
  bool _loading = true;
  List<Map<String, dynamic>> _items = const [];
  DateTime? _dateFrom;
  DateTime? _dateTo;
  bool _didOpenComposerOnStart = false;

  bool get _isRu => Localizations.localeOf(context).languageCode == 'ru';
  ThemeData get _theme => Theme.of(context);
  ColorScheme get _cs => _theme.colorScheme;

  @override
  void initState() {
    super.initState();
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openComposerIfNeeded();
    });
  }

  Future<void> _openComposerIfNeeded() async {
    if (!mounted || !widget.openComposerOnStart || _didOpenComposerOnStart) {
      return;
    }
    _didOpenComposerOnStart = true;
    await _addMeal();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final items = await repository.getMeals(
      dateFrom: _dateFrom,
      dateTo: _dateTo,
    );
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
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

  String _sourceLabel(String raw) {
    switch (raw.trim().toUpperCase()) {
      case 'MANUAL':
        return _isRu ? 'Ручная запись' : 'Manual';
      case 'AI':
      case 'ANALYSIS':
        return _isRu ? 'AI анализ' : 'AI analysis';
      default:
        return raw.trim().isEmpty ? (_isRu ? 'Запись' : 'Entry') : raw;
    }
  }

  Color _sourceColor(String raw) {
    switch (raw.trim().toUpperCase()) {
      case 'MANUAL':
        return _cs.primary;
      case 'AI':
      case 'ANALYSIS':
        return _cs.tertiary;
      default:
        return _cs.secondary;
    }
  }

  Future<void> _pickDate(bool isFrom) async {
    final base = isFrom
        ? (_dateFrom ?? DateTime.now())
        : (_dateTo ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _dateFrom = picked;
      } else {
        _dateTo = picked;
      }
    });
    await _load();
  }

  Future<void> _clearFilters() async {
    setState(() {
      _dateFrom = null;
      _dateTo = null;
    });
    await _load();
  }

  Future<void> _addMeal() async {
    final titleCtrl = TextEditingController();
    final caloriesCtrl = TextEditingController();
    final proteinsCtrl = TextEditingController();
    final fatsCtrl = TextEditingController();
    final carbsCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    var mealSuggestions = const <SmartSuggestionOption>[];
    Timer? suggestionDebounce;
    var activeSuggestionRequestId = 0;
    DateTime eatenAt = DateTime.now();

    void refreshMealSuggestions(StateSetter setSheetState) {
      final query = titleCtrl.text;
      final candidates = SmartFoodSuggestions.collectMealSuggestions(
        isRu: _isRu,
        mealItems: _items,
      );
      final local = SmartSuggestionMl.localVisibleSuggestions(
        candidates: candidates,
        query: query,
        limit: 8,
      );
      setSheetState(() => mealSuggestions = local);

      suggestionDebounce?.cancel();
      final trimmedQuery = query.trim();
      if (trimmedQuery.isEmpty || candidates.isEmpty) return;
      final requestId = ++activeSuggestionRequestId;
      suggestionDebounce = Timer(const Duration(milliseconds: 220), () async {
        final ranked = await SmartSuggestionMl.rerankSuggestions(
          query: trimmedQuery,
          candidates: candidates,
          visibleLimit: 8,
          ranker:
              ({
                required String query,
                required List<Map<String, dynamic>> candidates,
                required int limit,
              }) {
                return repository.rerankSuggestionCandidateIds(
                  query: query,
                  candidates: candidates,
                  limit: limit,
                );
              },
        );
        if (!mounted ||
            requestId != activeSuggestionRequestId ||
            titleCtrl.text.trim() != trimmedQuery) {
          return;
        }
        setSheetState(() => mealSuggestions = ranked);
      });
    }

    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => AtelierSheetFrame(
          title: _isRu ? 'Добавить прием пищи' : 'Add meal',
          subtitle: _isRu
              ? 'Сохрани ручную запись, чтобы она сразу попала в аналитику и историю.'
              : 'Save a manual entry so it appears immediately in your history and analytics.',
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
                        suggestionDebounce?.cancel();
                        activeSuggestionRequestId++;
                        FocusScope.of(context).unfocus();
                        setSheetState(() {
                          mealSuggestions = const <SmartSuggestionOption>[];
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
                          suggestionDebounce?.cancel();
                          activeSuggestionRequestId++;
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
                            mealSuggestions = const <SmartSuggestionOption>[];
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
                  title: Text(_isRu ? 'Время приема пищи' : 'Eaten at'),
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
                    final created = await repository.createMeal({
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
                    Navigator.of(context).pop(created != null);
                  },
                  child: Text(_isRu ? 'Сохранить запись' : 'Save entry'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    suggestionDebounce?.cancel();

    if (created == true) {
      await _load();
    }
  }

  Future<void> _deleteMeal(Map<String, dynamic> item) async {
    final ok = await repository.deleteMeal(item['id'].toString());
    if (ok) {
      await _load();
    }
  }

  Widget _mealCard(Map<String, dynamic> item) {
    final imageUrl = item['imageUrl']?.toString().trim() ?? '';
    final source = item['source']?.toString() ?? 'MANUAL';
    final sourceColor = _sourceColor(source);
    final notes = item['notes']?.toString().trim() ?? '';

    return AtelierSurfaceCard(
      radius: 24,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: imageUrl.isEmpty
                ? Container(
                    width: 86,
                    height: 86,
                    color: _cs.surface,
                    child: Icon(Icons.restaurant_rounded, color: sourceColor),
                  )
                : Image.network(
                    imageUrl,
                    width: 86,
                    height: 86,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      width: 86,
                      height: 86,
                      color: _cs.surface,
                      child: Icon(Icons.restaurant_rounded, color: sourceColor),
                    ),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['title']?.toString() ?? '-',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    height: 1.02,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    AtelierTagChip(
                      icon: Icons.local_fire_department_rounded,
                      foreground: _cs.primary,
                      label:
                          '${item['calories'] ?? 0} ${_isRu ? 'ккал' : 'kcal'}',
                    ),
                    AtelierTagChip(
                      icon: Icons.bookmark_rounded,
                      foreground: sourceColor,
                      label: _sourceLabel(source),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  _formatDateTime(item['eatenAt']),
                  style: TextStyle(
                    color: _cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    notes,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _cs.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                      height: 1.25,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _cs.error.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: () => _deleteMeal(item),
              icon: Icon(
                Icons.delete_outline_rounded,
                size: 18,
                color: _cs.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mealsCount = _items.length;
    final caloriesTotal = _items.fold<num>(
      0,
      (sum, item) => sum + ((item['calories'] as num?) ?? 0),
    );

    return Scaffold(
      backgroundColor: _theme.scaffoldBackgroundColor,
      appBar: AppTopBar(
        title: _isRu ? 'История приемов пищи' : 'Meal history',
        actions: [AppTopAction(icon: Icons.refresh_rounded, onPressed: _load)],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addMeal,
        icon: const Icon(Icons.add_rounded),
        label: Text(_isRu ? 'Добавить' : 'Add'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
          children: [
            AtelierHeroCard(
              eyebrow: 'The Organic Atelier',
              title: _isRu ? 'История\nприемов пищи' : 'Meal\nhistory',
              subtitle: _isRu
                  ? 'Смотри, что ты уже сохранял, и держи питание в одном ритме.'
                  : 'See what you have already logged and keep nutrition in one flow.',
              gradientColors: [
                _cs.primary.withValues(alpha: 0.14),
                AppTheme.atelierLime.withValues(alpha: 0.18),
                _cs.secondary.withValues(alpha: 0.1),
              ],
              pills: [
                AtelierStatPill(
                  icon: Icons.restaurant_rounded,
                  label: _isRu ? '$mealsCount записей' : '$mealsCount entries',
                  color: _cs.primary,
                ),
                AtelierStatPill(
                  icon: Icons.local_fire_department_rounded,
                  label: '${caloriesTotal.round()} ${_isRu ? 'ккал' : 'kcal'}',
                  color: _cs.secondary,
                ),
              ],
            ),
            const SizedBox(height: 28),
            AtelierSectionIntro(
              eyebrow: _isRu ? 'фильтры' : 'filters',
              title: _isRu ? 'Период' : 'Date range',
              subtitle: _isRu
                  ? 'Отфильтруй историю по времени, если хочешь посмотреть конкретный период.'
                  : 'Filter the log by time if you want to focus on a specific period.',
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilterChip(
                  showCheckmark: false,
                  selected: _dateFrom != null,
                  selectedColor: _cs.primary.withValues(alpha: 0.14),
                  side: BorderSide(
                    color:
                        (_dateFrom != null ? _cs.primary : _cs.outlineVariant)
                            .withValues(alpha: 0.45),
                  ),
                  label: Text(
                    _dateFrom == null
                        ? (_isRu ? 'Дата с' : 'From')
                        : _formatDateTime(
                            _dateFrom!.toIso8601String(),
                          ).split(' ').first,
                  ),
                  onSelected: (_) => _pickDate(true),
                ),
                FilterChip(
                  showCheckmark: false,
                  selected: _dateTo != null,
                  selectedColor: _cs.secondary.withValues(alpha: 0.14),
                  side: BorderSide(
                    color:
                        (_dateTo != null ? _cs.secondary : _cs.outlineVariant)
                            .withValues(alpha: 0.45),
                  ),
                  label: Text(
                    _dateTo == null
                        ? (_isRu ? 'Дата по' : 'To')
                        : _formatDateTime(
                            _dateTo!.toIso8601String(),
                          ).split(' ').first,
                  ),
                  onSelected: (_) => _pickDate(false),
                ),
                if (_dateFrom != null || _dateTo != null)
                  ActionChip(
                    backgroundColor: _cs.tertiary.withValues(alpha: 0.1),
                    side: BorderSide(
                      color: _cs.tertiary.withValues(alpha: 0.35),
                    ),
                    label: Text(_isRu ? 'Сбросить' : 'Reset'),
                    onPressed: _clearFilters,
                  ),
              ],
            ),
            const SizedBox(height: 28),
            AtelierSectionIntro(
              eyebrow: _isRu ? 'лог' : 'log',
              title: _isRu ? 'Последние записи' : 'Recent entries',
              subtitle: _isRu
                  ? 'Каждый прием пищи сохраняется как понятная карточка, а не как сухая строка.'
                  : 'Each meal is preserved as a readable card instead of a dry row.',
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_items.isEmpty)
              AtelierEmptyState(
                icon: Icons.restaurant_menu_rounded,
                title: _isRu ? 'История пока пуста' : 'History is empty',
                subtitle: _isRu
                    ? 'Добавь первый прием пищи вручную или сохрани результат AI-анализа.'
                    : 'Add the first meal manually or save an AI analysis result.',
                accent: _cs.primary,
              )
            else
              ..._items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _mealCard(item),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
