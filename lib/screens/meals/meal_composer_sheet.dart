import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/atelier_ui.dart';
import '../../core/food_suggestions.dart';
import '../../core/suggestion_panel.dart';
import '../../features/product_search/models/product_search_context.dart';
import '../../features/product_search/screens/unified_product_search_screen.dart';
import '../../repositories/app_repository.dart';
import '../barcode_scanner_screen.dart';

enum MealComposerMode { manual, product }

Future<bool?> showMealComposerSheet({
  required BuildContext context,
  required AppRepository repository,
  List<Map<String, dynamic>> mealItems = const [],
  Map<String, dynamic>? initialMeal,
  MealComposerMode initialMode = MealComposerMode.manual,
  String? initialProductQuery,
  Map<String, dynamic>? initialSelectedProduct,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _MealComposerSheet(
      repository: repository,
      mealItems: mealItems,
      initialMeal: initialMeal,
      initialMode: initialMode,
      initialProductQuery: initialProductQuery,
      initialSelectedProduct: initialSelectedProduct,
    ),
  );
}

Future<bool?> showProductMealComposerFlow({
  required BuildContext context,
  required AppRepository repository,
  List<Map<String, dynamic>> mealItems = const [],
  String initialQuery = '',
}) async {
  await Future<void>.delayed(const Duration(milliseconds: 120));
  if (!context.mounted) return null;

  final selected = await Navigator.of(context).push<Map<String, dynamic>>(
    MaterialPageRoute(
      builder: (_) => UnifiedProductSearchScreen(
        context: ProductSearchContext.consumed,
        initialQuery: initialQuery,
        onProductSelected: (_) {},
      ),
    ),
  );

  if (!context.mounted || selected == null) return null;

  return showMealComposerSheet(
    context: context,
    repository: repository,
    mealItems: mealItems,
    initialMode: MealComposerMode.product,
    initialSelectedProduct: selected,
  );
}

class _MealComposerSheet extends StatefulWidget {
  const _MealComposerSheet({
    required this.repository,
    required this.mealItems,
    this.initialMeal,
    this.initialMode = MealComposerMode.manual,
    this.initialProductQuery,
    this.initialSelectedProduct,
  });

  final AppRepository repository;
  final List<Map<String, dynamic>> mealItems;
  final Map<String, dynamic>? initialMeal;
  final MealComposerMode initialMode;
  final String? initialProductQuery;
  final Map<String, dynamic>? initialSelectedProduct;

  @override
  State<_MealComposerSheet> createState() => _MealComposerSheetState();
}

class _MealComposerSheetState extends State<_MealComposerSheet> {
  final _titleCtrl = TextEditingController();
  final _caloriesCtrl = TextEditingController();
  final _proteinsCtrl = TextEditingController();
  final _fatsCtrl = TextEditingController();
  final _carbsCtrl = TextEditingController();
  final _amountEatenCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  bool _saving = false;
  List<SuggestionOption> _mealSuggestions = const [];
  Map<String, dynamic>? _selectedProduct;
  DateTime _eatenAt = DateTime.now();
  double _productGrams = 100;
  MealComposerMode _mode = MealComposerMode.manual;

  bool get _isRu => Localizations.localeOf(context).languageCode == 'ru';
  bool get _isEditing => widget.initialMeal != null;
  ThemeData get _theme => Theme.of(context);
  ColorScheme get _cs => _theme.colorScheme;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    if (widget.initialSelectedProduct != null) {
      _selectedProduct = Map<String, dynamic>.from(
        widget.initialSelectedProduct!,
      );
      _mode = MealComposerMode.product;
    }
    final initial = widget.initialMeal;
    if (initial != null) {
      _titleCtrl.text = initial['title']?.toString() ?? '';
      _caloriesCtrl.text = _fieldText(initial['calories']);
      _proteinsCtrl.text = _fieldText(initial['proteins']);
      _fatsCtrl.text = _fieldText(initial['fats']);
      _carbsCtrl.text = _fieldText(initial['carbohydrates']);
      _amountEatenCtrl.text = initial['amountEaten']?.toString() ?? '';
      _notesCtrl.text = initial['notes']?.toString() ?? '';
      _eatenAt = _parseEatenAt(initial['eatenAt']);
      _productGrams = (_asDouble(initial['eatenWeightGrams']) ?? 100)
          .clamp(1, 1000)
          .toDouble();
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _caloriesCtrl.dispose();
    _proteinsCtrl.dispose();
    _fatsCtrl.dispose();
    _carbsCtrl.dispose();
    _amountEatenCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  double? _asDouble(dynamic raw) {
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw?.toString().trim().replaceAll(',', '.') ?? '');
  }

  String _fieldText(dynamic raw) {
    final value = _asDouble(raw);
    if (value == null) return '';
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(1);
  }

  DateTime _parseEatenAt(dynamic raw) {
    final parsed = DateTime.tryParse(raw?.toString() ?? '');
    return parsed ?? DateTime.now();
  }

  String _formatDateTime(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    final hh = date.hour.toString().padLeft(2, '0');
    final mm = date.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  String _formatCompactNumber(num? value) {
    if (value == null) return '-';
    final normalized = value.toDouble();
    final formatted = normalized == normalized.roundToDouble()
        ? normalized.toInt().toString()
        : normalized.toStringAsFixed(1);
    return _isRu ? formatted.replaceAll('.', ',') : formatted;
  }

  String _gramsLabel(num value) => _isRu
      ? '${_formatCompactNumber(value)} г'
      : '${_formatCompactNumber(value)} g';

  void _refreshMealSuggestions() {
    final query = _titleCtrl.text;
    final candidates = FoodSuggestions.collectMealSuggestions(
      isRu: _isRu,
      mealItems: widget.mealItems,
    );
    final local = FoodSuggestions.rankSuggestions(
      candidates,
      query: query,
      limit: 8,
    );
    if (!mounted) return;
    setState(() => _mealSuggestions = local);
  }

  Future<void> _openLargeProductSearch() async {
    final selected = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => UnifiedProductSearchScreen(
          context: ProductSearchContext.consumed,
          initialQuery: '',
          onProductSelected: (product) {
            // Product will be returned via Navigator.pop
          },
        ),
      ),
    );
    if (!mounted) return;

    // Если продукт не выбран и это первый раз (продукт еще не был выбран ранее)
    // то закрываем весь sheet
    if (selected == null && _selectedProduct == null) {
      Navigator.of(context).pop();
      return;
    }

    // Если продукт выбран, обновляем состояние
    if (selected != null) {
      FocusScope.of(context).unfocus();
      setState(() {
        _selectedProduct = selected;
        _mode = MealComposerMode.product;
      });
    }
  }

  Future<void> _scanBarcodeAndSelectProduct() async {
    final barcode = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (!mounted || barcode == null || barcode.trim().isEmpty) return;

    try {
      final product = await widget.repository.lookupProductCatalogBarcode(
        barcode.trim(),
      );
      if (!mounted) return;

      if (product != null) {
        setState(() {
          _selectedProduct = product;
          _mode = MealComposerMode.product;
        });
      } else {
        // Продукт не найден, открываем поиск
        _openLargeProductSearch();
      }
    } catch (e) {
      if (!mounted) return;
      // При ошибке открываем поиск
      _openLargeProductSearch();
    }
  }

  String _productDisplayTitle(Map<String, dynamic> product) {
    final name = product['productName']?.toString().trim() ?? '';
    final brand = product['brandName']?.toString().trim() ?? '';
    if (brand.isEmpty) return name;
    if (name.toLowerCase().contains(brand.toLowerCase())) {
      return name;
    }
    return '$name · $brand';
  }

  String _productMetaLine(Map<String, dynamic> product) {
    final quantity = product['quantity']?.toString().trim() ?? '';
    final serving = product['servingSize']?.toString().trim() ?? '';
    final country = product['countriesText']?.toString().trim() ?? '';
    final parts = <String>[
      if (quantity.isNotEmpty) quantity,
      if (serving.isNotEmpty && serving != quantity) serving,
      if (country.isNotEmpty) country,
    ];
    return parts.join(' • ');
  }

  double? _productCaloriesPer100(Map<String, dynamic> product) =>
      _asDouble(product['caloriesKcal100g']);
  double? _productProteinPer100(Map<String, dynamic> product) =>
      _asDouble(product['proteins100g']);
  double? _productFatPer100(Map<String, dynamic> product) =>
      _asDouble(product['fats100g']);
  double? _productCarbsPer100(Map<String, dynamic> product) =>
      _asDouble(product['carbohydrates100g']);

  int? _scaledCalories(Map<String, dynamic> product) {
    final calories = _productCaloriesPer100(product);
    if (calories == null) return null;
    return (calories * _productGrams / 100.0).round();
  }

  double? _scaledMacro(double? per100) {
    if (per100 == null) return null;
    return per100 * _productGrams / 100.0;
  }

  Future<void> _pickEatenAt() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _eatenAt,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_eatenAt),
    );
    if (time == null) return;
    setState(() {
      _eatenAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _saveManualMeal() async {
    if (_saving) return;
    if (_titleCtrl.text.trim().isEmpty || _caloriesCtrl.text.trim().isEmpty) {
      return;
    }
    setState(() => _saving = true);
    final payload = {
      'title': _titleCtrl.text.trim(),
      'calories':
          double.tryParse(
            _caloriesCtrl.text.trim().replaceAll(',', '.'),
          )?.round() ??
          0,
      'proteins': double.tryParse(
        _proteinsCtrl.text.trim().replaceAll(',', '.'),
      ),
      'fats': double.tryParse(_fatsCtrl.text.trim().replaceAll(',', '.')),
      'carbohydrates': double.tryParse(
        _carbsCtrl.text.trim().replaceAll(',', '.'),
      ),
      'eatenAt': _eatenAt.toIso8601String(),
      'source':
          widget.initialMeal?['source']?.toString().trim().isNotEmpty == true
          ? widget.initialMeal!['source']
          : 'MANUAL',
      'amountEaten': _amountEatenCtrl.text.trim().isEmpty
          ? null
          : _amountEatenCtrl.text.trim(),
      'amountMode': widget.initialMeal?['amountMode'],
      'eatenRatio': widget.initialMeal?['eatenRatio'],
      'totalWeightGrams': widget.initialMeal?['totalWeightGrams'],
      'eatenWeightGrams': widget.initialMeal?['eatenWeightGrams'],
      'packageFractionNumerator':
          widget.initialMeal?['packageFractionNumerator'],
      'packageFractionDenominator':
          widget.initialMeal?['packageFractionDenominator'],
      'fullPortionCalories': widget.initialMeal?['fullPortionCalories'],
      'fullPortionProteins': widget.initialMeal?['fullPortionProteins'],
      'fullPortionFats': widget.initialMeal?['fullPortionFats'],
      'fullPortionCarbohydrates':
          widget.initialMeal?['fullPortionCarbohydrates'],
      'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      'imageUrl': widget.initialMeal?['imageUrl'],
    };

    final created = _isEditing
        ? await widget.repository.updateMeal(
            widget.initialMeal!['id'].toString(),
            payload,
          )
        : await widget.repository.createMeal(payload);
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.of(context).pop(created != null);
  }

  Future<void> _saveProductMeal() async {
    if (_saving || _selectedProduct == null) return;
    setState(() => _saving = true);
    final product = _selectedProduct!;
    final payload = {
      'title': _productDisplayTitle(product),
      'calories': _scaledCalories(product) ?? 0,
      'proteins': _scaledMacro(_productProteinPer100(product)),
      'fats': _scaledMacro(_productFatPer100(product)),
      'carbohydrates': _scaledMacro(_productCarbsPer100(product)),
      'eatenAt': _eatenAt.toIso8601String(),
      'source': 'IMPORTED',
      'amountEaten': _gramsLabel(_productGrams),
      'amountMode': 'GRAMS',
      'eatenRatio': _productGrams / 100.0,
      'totalWeightGrams': 100.0,
      'eatenWeightGrams': _productGrams,
      'fullPortionCalories': _productCaloriesPer100(product)?.round(),
      'fullPortionProteins': _productProteinPer100(product),
      'fullPortionFats': _productFatPer100(product),
      'fullPortionCarbohydrates': _productCarbsPer100(product),
      'notes': null,
      'imageUrl': product['imageUrl']?.toString().trim().isEmpty == true
          ? null
          : product['imageUrl'],
    };

    final created = _isEditing
        ? await widget.repository.updateMeal(
            widget.initialMeal!['id'].toString(),
            payload,
          )
        : await widget.repository.createMeal(payload);
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.of(context).pop(created != null);
  }

  Widget _nutritionChip({
    required String label,
    required String value,
    required Color color,
  }) {
    return AtelierTagChip(
      foreground: color,
      label: '$label $value',
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    );
  }

  Widget _productImage(
    Map<String, dynamic> product, {
    double width = 88,
    double height = 88,
  }) {
    final imageUrl = product['imageUrl']?.toString().trim() ?? '';
    if (imageUrl.isEmpty) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: _cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(22),
        ),
        alignment: Alignment.center,
        child: Icon(Icons.shopping_bag_rounded, color: _cs.primary, size: 32),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Image.network(
        imageUrl,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: _cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(22),
          ),
          alignment: Alignment.center,
          child: Icon(Icons.shopping_bag_rounded, color: _cs.primary, size: 32),
        ),
      ),
    );
  }

  Widget _productResultCard(
    Map<String, dynamic> product, {
    required bool selected,
    required VoidCallback onTap,
  }) {
    final meta = _productMetaLine(product);
    final calories = _productCaloriesPer100(product);
    final proteins = _productProteinPer100(product);
    final fats = _productFatPer100(product);
    final carbs = _productCarbsPer100(product);
    Widget macroTile(String label, double? value, Color color) {
      if (value == null) {
        return Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              '$label --',
              style: TextStyle(
                color: _cs.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      }
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: _cs.onSurfaceVariant,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_formatCompactNumber(value)} ${_isRu ? 'г' : 'g'}',
                style: TextStyle(
                  color: _cs.onSurface,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected
                ? _cs.primary.withValues(alpha: 0.34)
                : Colors.transparent,
            width: 1.4,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: _cs.primary.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ]
              : const [],
        ),
        child: AtelierSurfaceCard(
          radius: 24,
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: SizedBox(
                        width: double.infinity,
                        height: 136,
                        child: _productImage(
                          product,
                          width: double.infinity,
                          height: 136,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 24,
                    right: 24,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _cs.surface.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: _cs.outlineVariant.withValues(alpha: 0.24),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        selected
                            ? Icons.check_circle_rounded
                            : Icons.add_circle_outline_rounded,
                        color: selected ? _cs.primary : _cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _productDisplayTitle(product),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _cs.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        height: 1.12,
                      ),
                    ),
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        meta,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _cs.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (calories != null)
                          _nutritionChip(
                            label: _isRu ? 'ккал / 100 г' : 'kcal / 100 g',
                            value: _formatCompactNumber(calories),
                            color: _cs.primary,
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        macroTile(
                          _isRu ? 'Белки' : 'Protein',
                          proteins,
                          _cs.primary,
                        ),
                        const SizedBox(width: 8),
                        macroTile(_isRu ? 'Жиры' : 'Fats', fats, _cs.tertiary),
                        const SizedBox(width: 8),
                        macroTile(
                          _isRu ? 'Углеводы' : 'Carbs',
                          carbs,
                          _cs.secondary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _productModeBody() {
    final selectedProduct = _selectedProduct;

    if (selectedProduct == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AtelierSurfaceCard(
            radius: 24,
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isRu ? 'Сначала выбери продукт' : 'Choose a product first',
                  style: TextStyle(
                    color: _cs.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isRu
                      ? 'Открой базу продуктов или сканируй штрихкод, а потом мы сразу покажем карточку и расчёт по граммам.'
                      : 'Open the product database or scan a barcode, then we will show the product card and gram-based nutrition.',
                  style: TextStyle(
                    color: _cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _openLargeProductSearch,
                    icon: const Icon(Icons.search_rounded),
                    label: Text(
                      _isRu
                          ? 'Открыть базу продуктов'
                          : 'Open product database',
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _scanBarcodeAndSelectProduct,
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    label: Text(
                      _isRu ? 'Сканировать штрихкод' : 'Scan barcode',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: AtelierFieldLabel(
                _isRu ? 'Выбранный продукт' : 'Selected product',
              ),
            ),
            TextButton.icon(
              onPressed: _openLargeProductSearch,
              icon: const Icon(Icons.swap_horiz_rounded, size: 18),
              label: Text(_isRu ? 'Изменить' : 'Change'),
            ),
          ],
        ),
        _productResultCard(
          selectedProduct,
          selected: true,
          onTap: _openLargeProductSearch,
        ),
        const SizedBox(height: 14),
        AtelierFieldLabel(_isRu ? 'Сколько съедено' : 'Amount eaten'),
        AtelierSurfaceCard(
          radius: 24,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: _cs.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      _gramsLabel(_productGrams),
                      style: TextStyle(
                        color: _cs.primary,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => setState(
                      () => _productGrams = (_productGrams - 10).clamp(1, 1000),
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: _cs.surfaceContainerHighest,
                      foregroundColor: _cs.onSurface,
                    ),
                    icon: const Icon(Icons.remove_rounded),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => setState(
                      () => _productGrams = (_productGrams + 10).clamp(1, 1000),
                    ),
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
                    onPressed: () => setState(
                      () => _productGrams = (_productGrams - 1).clamp(1, 1000),
                    ),
                    child: Text(_isRu ? '-1 г' : '-1 g'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () => setState(
                      () => _productGrams = (_productGrams + 1).clamp(1, 1000),
                    ),
                    child: Text(_isRu ? '+1 г' : '+1 g'),
                  ),
                  const Spacer(),
                  Text(
                    _isRu ? 'На основе 100 г' : 'Based on 100 g',
                    style: TextStyle(
                      color: _cs.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 8,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 10,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 18,
                  ),
                ),
                child: Slider(
                  value: _productGrams.clamp(1, 1000),
                  min: 1,
                  max: 1000,
                  onChanged: (raw) {
                    setState(() => _productGrams = raw.roundToDouble());
                  },
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [30, 50, 100, 150, 200, 250, 300].map((grams) {
                  final selected = _productGrams.round() == grams;
                  return ChoiceChip(
                    label: Text(_isRu ? '$grams г' : '$grams g'),
                    selected: selected,
                    onSelected: (_) =>
                        setState(() => _productGrams = grams.toDouble()),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        AtelierFieldLabel(_isRu ? 'Сохранится' : 'Will be saved'),
        AtelierSurfaceCard(
          radius: 24,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_scaledCalories(selectedProduct) ?? 0} ${_isRu ? 'ккал' : 'kcal'}',
                style: TextStyle(
                  color: _cs.primary,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _nutritionChip(
                    label: _isRu ? 'Белки' : 'Protein',
                    value:
                        '${_formatCompactNumber(_scaledMacro(_productProteinPer100(selectedProduct)))} ${_isRu ? 'г' : 'g'}',
                    color: _cs.primary,
                  ),
                  _nutritionChip(
                    label: _isRu ? 'Жиры' : 'Fats',
                    value:
                        '${_formatCompactNumber(_scaledMacro(_productFatPer100(selectedProduct)))} ${_isRu ? 'г' : 'g'}',
                    color: _cs.tertiary,
                  ),
                  _nutritionChip(
                    label: _isRu ? 'Углеводы' : 'Carbs',
                    value:
                        '${_formatCompactNumber(_scaledMacro(_productCarbsPer100(selectedProduct)))} ${_isRu ? 'г' : 'g'}',
                    color: _cs.secondary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _manualModeBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AtelierFieldLabel(_isRu ? 'Название' : 'Title'),
        TextFieldTapRegion(
          child: Column(
            children: [
              TextField(
                controller: _titleCtrl,
                onTap: _refreshMealSuggestions,
                onChanged: (_) => _refreshMealSuggestions(),
                onTapOutside: (_) {
                  FocusScope.of(context).unfocus();
                  setState(() => _mealSuggestions = const []);
                },
                decoration: InputDecoration(
                  hintText: _isRu
                      ? 'Например, овсянка'
                      : 'For example, oatmeal',
                ),
              ),
              if (_mealSuggestions.isNotEmpty)
                AtelierSuggestionPanel(
                  suggestions: _mealSuggestions,
                  isRu: _isRu,
                  onSelected: (option) {
                    _titleCtrl.text = option.primaryText;
                    _titleCtrl.selection = TextSelection.collapsed(
                      offset: _titleCtrl.text.length,
                    );
                    if (option.calories != null) {
                      _caloriesCtrl.text = option.calories!.toString();
                    }
                    if (option.protein != null) {
                      _proteinsCtrl.text = option.protein!.toStringAsFixed(
                        option.protein! >= 10 ? 0 : 1,
                      );
                    }
                    if (option.fat != null) {
                      _fatsCtrl.text = option.fat!.toStringAsFixed(
                        option.fat! >= 10 ? 0 : 1,
                      );
                    }
                    if (option.carbs != null) {
                      _carbsCtrl.text = option.carbs!.toStringAsFixed(
                        option.carbs! >= 10 ? 0 : 1,
                      );
                    }
                    FocusScope.of(context).unfocus();
                    setState(() => _mealSuggestions = const []);
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        AtelierFieldLabel(_isRu ? 'Калории' : 'Calories'),
        TextField(
          controller: _caloriesCtrl,
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
                    controller: _proteinsCtrl,
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
                    controller: _fatsCtrl,
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
                    controller: _carbsCtrl,
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
        AtelierFieldLabel(_isRu ? 'Сколько съедено' : 'Amount eaten'),
        TextField(
          controller: _amountEatenCtrl,
          decoration: InputDecoration(
            hintText: _isRu
                ? 'Например, 250 г или 1 порция'
                : 'For example, 250 g or 1 serving',
          ),
        ),
        const SizedBox(height: 14),
        AtelierFieldLabel(_isRu ? 'Заметки' : 'Notes'),
        TextField(
          controller: _notesCtrl,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: _isRu
                ? 'Состав, настроение, комментарии'
                : 'Ingredients, context, or notes',
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AtelierSheetFrame(
      title: _isEditing
          ? (_isRu ? 'Редактировать прием пищи' : 'Edit meal')
          : (_mode == MealComposerMode.product
                ? (_isRu ? 'Добавить продукт' : 'Add product')
                : (_isRu ? 'Добавить прием пищи' : 'Add meal')),
      subtitle: _mode == MealComposerMode.product
          ? (_isRu
                ? 'Укажи граммы и сохрани без ручного ввода КБЖУ.'
                : 'Set the grams and save without typing macros manually.')
          : (_isEditing
                ? (_isRu
                      ? 'Исправь запись, и аналитика пересчитается сразу.'
                      : 'Update the entry and your analytics will refresh immediately.')
                : (_isRu
                      ? 'Заполни данные о блюде.'
                      : 'Fill in the meal details.')),
      onClose: () => Navigator.of(context).pop(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Убираем переключатель режимов - режим выбирается до открытия sheet
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: _mode == MealComposerMode.product
                ? _productModeBody()
                : _manualModeBody(),
          ),
          const SizedBox(height: 14),
          AtelierSurfaceCard(
            radius: 22,
            padding: const EdgeInsets.all(14),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_isRu ? 'Время приема пищи' : 'Eaten at'),
              subtitle: Text(_formatDateTime(_eatenAt)),
              trailing: const Icon(Icons.schedule_rounded),
              onTap: _pickEatenAt,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving
                  ? null
                  : _mode == MealComposerMode.product
                  ? _saveProductMeal
                  : _saveManualMeal,
              child: Text(
                _saving
                    ? (_isRu ? 'Сохранение...' : 'Saving...')
                    : _isEditing
                    ? (_isRu ? 'Сохранить изменения' : 'Save changes')
                    : (_isRu ? 'Сохранить запись' : 'Save entry'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
