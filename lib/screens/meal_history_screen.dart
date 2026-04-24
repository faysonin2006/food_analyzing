import 'package:flutter/material.dart';

import '../core/atelier_ui.dart';
import '../core/app_top_bar.dart';
import '../repositories/app_repository.dart';
import 'meals/meal_composer_sheet.dart';

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
      case 'IMPORTED':
        return _isRu ? 'Продукт' : 'Product';
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
      case 'IMPORTED':
        return _cs.secondary;
      case 'AI':
      case 'ANALYSIS':
        return _cs.tertiary;
      default:
        return _cs.secondary;
    }
  }

  double? _toDouble(dynamic raw) {
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw?.toString().trim().replaceAll(',', '.') ?? '');
  }

  String _formatCompactNumber(num? value) {
    if (value == null) return '-';
    final normalized = value.toDouble();
    final formatted = normalized == normalized.roundToDouble()
        ? normalized.toInt().toString()
        : normalized.toStringAsFixed(1);
    return _isRu ? formatted.replaceAll('.', ',') : formatted;
  }

  String? _portionBreakdownLabel(Map<String, dynamic> item) {
    final mode = item['amountMode']?.toString().trim().toUpperCase() ?? '';
    if (mode == 'GRAMS' || mode == 'PERCENT') {
      final eatenWeight = _toDouble(item['eatenWeightGrams']);
      final totalWeight = _toDouble(item['totalWeightGrams']);
      final ratio = _toDouble(item['eatenRatio']);
      if (eatenWeight == null ||
          eatenWeight <= 0 ||
          totalWeight == null ||
          totalWeight <= 0) {
        return null;
      }
      if ((totalWeight - 100).abs() < 0.01) {
        if ((eatenWeight - totalWeight).abs() < 0.01) return null;
        return _isRu
            ? '${_formatCompactNumber(eatenWeight)} г съедено'
            : '${_formatCompactNumber(eatenWeight)} g eaten';
      }
      if ((eatenWeight - totalWeight).abs() < 0.01) return null;
      final ratioSuffix = mode == 'PERCENT' && ratio != null && ratio > 0
          ? (_isRu
                ? ' • ${(ratio * 100).round()}%'
                : ' • ${(ratio * 100).round()}%')
          : '';
      return _isRu
          ? '${_formatCompactNumber(eatenWeight)} г из ${_formatCompactNumber(totalWeight)} г$ratioSuffix'
          : '${_formatCompactNumber(eatenWeight)} g of ${_formatCompactNumber(totalWeight)} g$ratioSuffix';
    }
    return null;
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

  String _formatDateOnly(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _periodLabel() {
    if (_dateFrom == null && _dateTo == null) {
      return _isRu ? 'Весь период' : 'All time';
    }
    if (_dateFrom != null && _dateTo != null) {
      return '${_formatDateOnly(_dateFrom!)} - ${_formatDateOnly(_dateTo!)}';
    }
    if (_dateFrom != null) {
      return _isRu
          ? 'С ${_formatDateOnly(_dateFrom!)}'
          : 'From ${_formatDateOnly(_dateFrom!)}';
    }
    return _isRu
        ? 'До ${_formatDateOnly(_dateTo!)}'
        : 'Until ${_formatDateOnly(_dateTo!)}';
  }

  Future<void> _addMeal() async {
    final currentContext = context;
    final mode = await _showAddMealOptions();
    if (!mounted || !currentContext.mounted || mode == null) return;

    bool? created;
    if (mode == MealComposerMode.product) {
      created = await showProductMealComposerFlow(
        context: currentContext,
        repository: repository,
        mealItems: _items,
      );
    } else {
      created = await showMealComposerSheet(
        context: currentContext,
        repository: repository,
        mealItems: _items,
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

  Future<void> _openMealComposer({Map<String, dynamic>? initialMeal}) async {
    final created = await showMealComposerSheet(
      context: context,
      repository: repository,
      mealItems: _items,
      initialMeal: initialMeal,
    );
    if (created == true) {
      await _load();
    }
  }

  Future<void> _editMeal(Map<String, dynamic> item) async {
    final id = item['id']?.toString().trim() ?? '';
    if (id.isEmpty) return;
    final fullMeal = await repository.getMealById(id);
    if (!mounted || fullMeal == null) return;
    await _openMealComposer(initialMeal: fullMeal);
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
    final amountEaten = item['amountEaten']?.toString().trim() ?? '';
    final notes = item['notes']?.toString().trim() ?? '';
    final eatenCalories = _toDouble(item['calories']);
    final fullPortionCalories = _toDouble(item['fullPortionCalories']);
    final portionBreakdown = _portionBreakdownLabel(item);
    final totalWeight = _toDouble(item['totalWeightGrams']);
    final usesPerHundredBaseline =
        totalWeight != null && (totalWeight - 100).abs() < 0.01;
    final showPortionSplit =
        fullPortionCalories != null &&
        eatenCalories != null &&
        (fullPortionCalories.round() != eatenCalories.round() ||
            portionBreakdown != null);

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
                    if (amountEaten.isNotEmpty)
                      AtelierTagChip(
                        icon: Icons.restaurant_rounded,
                        foreground: _cs.secondary,
                        label: amountEaten,
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
                if (showPortionSplit) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _cs.surfaceContainerHighest.withValues(
                        alpha: 0.42,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: _cs.outlineVariant.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                usesPerHundredBaseline
                                    ? (_isRu ? 'На 100 г' : 'Per 100 g')
                                    : (_isRu
                                          ? 'Полная порция'
                                          : 'Full portion'),
                                style: TextStyle(
                                  color: _cs.onSurfaceVariant,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_formatCompactNumber(fullPortionCalories)} ${_isRu ? 'ккал' : 'kcal'}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 34,
                          color: _cs.outlineVariant.withValues(alpha: 0.45),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isRu ? 'Съедено' : 'Eaten',
                                style: TextStyle(
                                  color: _cs.onSurfaceVariant,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_formatCompactNumber(eatenCalories)} ${_isRu ? 'ккал' : 'kcal'}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              if (portionBreakdown != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  portionBreakdown,
                                  style: TextStyle(
                                    color: _cs.onSurfaceVariant,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
          Column(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _cs.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: () => _editMeal(item),
                  icon: Icon(Icons.edit_outlined, size: 18, color: _cs.primary),
                ),
              ),
              const SizedBox(height: 10),
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
        actions: const [],
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
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
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
            const SizedBox(height: 16),
            AtelierSurfaceCard(
              radius: 24,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isRu ? 'Период' : 'Date range',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _periodLabel(),
                    style: TextStyle(
                      color: _cs.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
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
                              (_dateFrom != null
                                      ? _cs.primary
                                      : _cs.outlineVariant)
                                  .withValues(alpha: 0.45),
                        ),
                        label: Text(
                          _dateFrom == null
                              ? (_isRu ? 'Дата с' : 'From')
                              : _formatDateOnly(_dateFrom!),
                        ),
                        onSelected: (_) => _pickDate(true),
                      ),
                      FilterChip(
                        showCheckmark: false,
                        selected: _dateTo != null,
                        selectedColor: _cs.secondary.withValues(alpha: 0.14),
                        side: BorderSide(
                          color:
                              (_dateTo != null
                                      ? _cs.secondary
                                      : _cs.outlineVariant)
                                  .withValues(alpha: 0.45),
                        ),
                        label: Text(
                          _dateTo == null
                              ? (_isRu ? 'Дата по' : 'To')
                              : _formatDateOnly(_dateTo!),
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
                ],
              ),
            ),
            const SizedBox(height: 28),
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
                    ? 'Добавь первый прием пищи вручную, выбери продукт из каталога или сохрани результат AI-анализа.'
                    : 'Add your first meal manually, choose a product from the catalog, or save an AI analysis result.',
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
