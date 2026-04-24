import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_feedback.dart';
import '../core/app_top_bar.dart';
import '../core/atelier_ui.dart';
import '../repositories/app_repository.dart';
import 'barcode_scanner_screen.dart';

class ProductSearchScreen extends StatefulWidget {
  const ProductSearchScreen({super.key, this.initialQuery = ''});

  final String initialQuery;

  @override
  State<ProductSearchScreen> createState() => _ProductSearchScreenState();
}

class _ProductSearchScreenState extends State<ProductSearchScreen> {
  static const int _pageSize = 20;

  final AppRepository repository = AppRepository.instance;
  final TextEditingController _queryCtrl = TextEditingController();
  Timer? _debounce;

  bool _loading = false;
  List<Map<String, dynamic>> _items = const [];
  int _page = 1;
  bool _hasNext = false;
  String _activeQuery = '';

  bool get _isRu => Localizations.localeOf(context).languageCode == 'ru';
  ThemeData get _theme => Theme.of(context);
  ColorScheme get _cs => _theme.colorScheme;
  bool get _isDark => _theme.brightness == Brightness.dark;
  String get _screenTitle => _isRu ? 'Поиск продукта' : 'Product search';

  @override
  void initState() {
    super.initState();
    _queryCtrl.text = widget.initialQuery.trim();
    if (_queryCtrl.text.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _search(page: 1);
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _queryCtrl.dispose();
    super.dispose();
  }

  void _showMessage(
    String message, {
    AppFeedbackKind? kind,
    bool preferPopup = false,
  }) {
    if (!mounted) return;
    showAppFeedback(
      context,
      message,
      kind: kind,
      source: _screenTitle,
      preferPopup: preferPopup,
      addToInbox: false,
    );
  }

  double? _asDouble(dynamic raw) {
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

  Future<void> _search({required int page}) async {
    final query = _queryCtrl.text.trim();
    if (query.isEmpty) {
      setState(() {
        _activeQuery = '';
        _items = const [];
        _page = 1;
        _hasNext = false;
      });
      return;
    }

    setState(() => _loading = true);
    try {
      final pageData = await repository.searchProductCatalogPage(
        query: query,
        page: page,
        size: _pageSize,
      );
      if (!mounted) return;
      final items = ((pageData?['items'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      setState(() {
        _activeQuery = query;
        _items = items;
        _page = (pageData?['page'] as num?)?.toInt() ?? page;
        _hasNext = pageData?['hasNext'] == true;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showMessage(
        _isRu ? 'Не удалось загрузить продукты' : 'Failed to load products',
        kind: AppFeedbackKind.error,
        preferPopup: true,
      );
    }
  }

  Future<void> _lookupBarcode(String barcode) async {
    final normalized = barcode.trim();
    if (normalized.isEmpty) return;
    setState(() => _loading = true);
    try {
      final product = await repository.lookupProductCatalogBarcode(normalized);
      if (!mounted) return;
      setState(() => _loading = false);
      if (product == null) {
        _showMessage(
          _isRu
              ? 'Продукт по штрихкоду не найден'
              : 'No product found for this barcode',
          kind: AppFeedbackKind.info,
          preferPopup: true,
        );
        return;
      }
      Navigator.of(context).pop(product);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showMessage(
        _isRu ? 'Не удалось проверить штрихкод' : 'Failed to verify barcode',
        kind: AppFeedbackKind.error,
        preferPopup: true,
      );
    }
  }

  Future<void> _scanBarcode() async {
    final barcode = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (!mounted || barcode == null || barcode.trim().isEmpty) return;
    _queryCtrl.text = barcode.trim();
    await _lookupBarcode(barcode);
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

  Widget _productCard(Map<String, dynamic> product) {
    final meta = _productMetaLine(product);
    final calories = _productCaloriesPer100(product);
    final proteins = _productProteinPer100(product);
    final fats = _productFatPer100(product);
    final carbs = _productCarbsPer100(product);

    Widget macroTile(String label, double? value, Color color) {
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
                value == null
                    ? '--'
                    : '${_formatCompactNumber(value)} ${_isRu ? 'г' : 'g'}',
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
      onTap: () => Navigator.of(context).pop(product),
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
                      height: 156,
                      child: _productImage(
                        product,
                        width: double.infinity,
                        height: 156,
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
                      color: _cs.surface.withValues(
                        alpha: _isDark ? 0.82 : 0.92,
                      ),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.add_circle_outline_rounded,
                      color: _cs.primary,
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
    );
  }

  Widget _pagination() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _loading || _page <= 1
                ? null
                : () => _search(page: _page - 1),
            icon: const Icon(Icons.arrow_back_rounded),
            label: Text(_isRu ? 'Назад' : 'Back'),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _cs.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(
            '${_isRu ? 'Стр.' : 'Page'} $_page',
            style: TextStyle(color: _cs.onSurface, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton.icon(
            onPressed: _loading || !_hasNext
                ? null
                : () => _search(page: _page + 1),
            icon: const Icon(Icons.arrow_forward_rounded),
            label: Text(_isRu ? 'Дальше' : 'Next'),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTopBar(
        title: _screenTitle,
        actions: [
          AppTopAction(
            icon: Icons.qr_code_scanner_rounded,
            tooltip: _isRu ? 'Сканировать штрихкод' : 'Scan barcode',
            onPressed: _scanBarcode,
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        behavior: HitTestBehavior.translucent,
        child: RefreshIndicator(
          onRefresh: () => _search(page: _page),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              TextField(
                controller: _queryCtrl,
                autofocus: widget.initialQuery.trim().isEmpty,
                onTapOutside: (_) =>
                    FocusManager.instance.primaryFocus?.unfocus(),
                onChanged: (_) {
                  _debounce?.cancel();
                  _debounce = Timer(
                    const Duration(milliseconds: 320),
                    () => _search(page: 1),
                  );
                  setState(() {});
                },
                onSubmitted: (_) => _search(page: 1),
                decoration: InputDecoration(
                  hintText: _isRu
                      ? 'Название продукта или бренд'
                      : 'Product name or brand',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_queryCtrl.text.trim().isNotEmpty)
                        IconButton(
                          onPressed: () {
                            _debounce?.cancel();
                            _queryCtrl.clear();
                            setState(() {
                              _items = const [];
                              _page = 1;
                              _hasNext = false;
                              _activeQuery = '';
                            });
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                      IconButton(
                        onPressed: () => _search(page: 1),
                        icon: const Icon(Icons.arrow_forward_rounded),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              AtelierSurfaceCard(
                radius: 22,
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _isRu
                            ? 'Ищи по названию, бренду или сразу сканируй штрихкод'
                            : 'Search by product name, brand, or scan a barcode',
                        style: TextStyle(
                          color: _cs.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: _scanBarcode,
                      icon: const Icon(Icons.qr_code_scanner_rounded),
                      label: Text(_isRu ? 'Сканировать' : 'Scan'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_items.isEmpty && _activeQuery.isNotEmpty)
                AtelierSurfaceCard(
                  radius: 22,
                  padding: const EdgeInsets.all(18),
                  child: Text(
                    _isRu
                        ? 'По этому запросу пока ничего не нашлось. Попробуй бренд, более короткое название или отсканируй штрихкод.'
                        : 'No products matched this query yet. Try a shorter name, a brand, or scan the barcode.',
                    style: TextStyle(
                      color: _cs.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                )
              else if (_items.isEmpty)
                AtelierSurfaceCard(
                  radius: 22,
                  padding: const EdgeInsets.all(18),
                  child: Text(
                    _isRu
                        ? 'Начни с названия продукта или бренда. Здесь можно быстро выбрать готовый товар и добавить его в съеденное.'
                        : 'Start with a product name or a brand. You can quickly choose a packaged food here and add it to eaten meals.',
                    style: TextStyle(
                      color: _cs.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                )
              else ...[
                Text(
                  _isRu
                      ? 'Результаты для "$_activeQuery"'
                      : 'Results for "$_activeQuery"',
                  style: TextStyle(
                    color: _cs.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                ..._items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _productCard(item),
                  ),
                ),
                const SizedBox(height: 8),
                _pagination(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
