import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/app_feedback.dart';
import '../../../core/app_top_bar.dart';
import '../../../repositories/app_repository.dart';
import '../../../screens/barcode_scanner_screen.dart';
import '../models/product_item.dart';
import '../models/product_search_context.dart';
import '../utils/search_debouncer.dart';
import '../utils/search_results_cache.dart';
import '../widgets/search_results_list.dart';

/// Унифицированный полноэкранный интерфейс поиска продуктов.
///
/// Используется во всех разделах приложения: съеденные продукты,
/// кладовая, покупки и семья.
class UnifiedProductSearchScreen extends StatefulWidget {
  const UnifiedProductSearchScreen({
    super.key,
    required this.context,
    this.initialQuery = '',
    this.onProductSelected,
  });

  /// Контекст раздела, в котором используется поиск
  final ProductSearchContext context;

  /// Начальный поисковый запрос
  final String initialQuery;

  /// Callback, вызываемый при выборе продукта
  final Function(Map<String, dynamic> product)? onProductSelected;

  @override
  State<UnifiedProductSearchScreen> createState() =>
      _UnifiedProductSearchScreenState();
}

class _UnifiedProductSearchScreenState
    extends State<UnifiedProductSearchScreen> {
  // Зависимости
  final AppRepository _repository = AppRepository.instance;
  late final SearchDebouncer _debouncer;
  late final SearchResultsCache _cache;

  // Контроллеры
  late final TextEditingController _searchController;

  // Состояние
  bool _isLoading = false;
  List<ProductItem> _searchResults = [];
  int _searchRequestId = 0;

  @override
  void initState() {
    super.initState();

    // Инициализация утилит
    _debouncer = SearchDebouncer(delay: const Duration(milliseconds: 300));
    _cache = SearchResultsCache();

    // Инициализация контроллера поиска
    _searchController = TextEditingController(text: widget.initialQuery);

    // Выполнить начальный поиск если есть запрос
    if (widget.initialQuery.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _performSearch(widget.initialQuery);
      });
    }

    // Подключить TextField к SearchDebouncer
    _searchController.addListener(_onSearchTextChanged);
  }

  @override
  void dispose() {
    _debouncer.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Обработчик изменения текста в поле поиска
  void _onSearchTextChanged() {
    final query = _searchController.text.trim();

    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isLoading = false;
      });
      return;
    }

    // Использовать debounce для отложенного поиска
    _debouncer(() {
      _performSearch(query);
    });
  }

  /// Выполнить поиск продуктов
  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isLoading = false;
      });
      return;
    }

    // Проверить кэш перед выполнением API-запроса
    final cached = _cache.get(query);
    if (cached != null) {
      setState(() {
        _searchResults = cached.results
            .map((json) => ProductItem.fromJson(json))
            .toList();
        _isLoading = false;
      });
      return;
    }

    // Увеличить ID запроса для отмены предыдущих запросов
    final requestId = ++_searchRequestId;

    setState(() {
      _isLoading = true;
    });

    try {
      // Выполнить API-запрос
      final results = await _repository.searchProductCatalog(
        query: query,
        size: 20,
      );

      // Проверить, что это все еще актуальный запрос
      if (!mounted || requestId != _searchRequestId) return;

      // Преобразовать результаты в ProductItem
      final items = results.map((json) => ProductItem.fromJson(json)).toList();

      // Сохранить результаты в кэш
      _cache.put(query, results);

      setState(() {
        _searchResults = items;
        _isLoading = false;
      });
    } catch (e) {
      // Проверить, что это все еще актуальный запрос
      if (!mounted || requestId != _searchRequestId) return;

      setState(() {
        _searchResults = [];
        _isLoading = false;
      });

      // Показать сообщение об ошибке
      _showErrorMessage('Не удалось загрузить результаты поиска');
    }
  }

  /// Обработчик выбора продукта
  void _onProductSelected(ProductItem product) {
    // Вызвать callback если предоставлен
    if (widget.onProductSelected != null) {
      widget.onProductSelected!(product.toJson());
    }

    // Закрыть экран поиска после выбора
    Navigator.of(context).pop(product.toJson());
  }

  /// Обработчик нажатия на кнопку сканирования
  Future<void> _onScanButtonPressed() async {
    final barcode = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const BarcodeScannerScreen(),
      ),
    );

    if (!mounted || barcode == null || barcode.trim().isEmpty) return;

    // Выполнить поиск по штрихкоду
    setState(() {
      _isLoading = true;
    });

    try {
      final product = await _repository.lookupProductCatalogBarcode(
        barcode.trim(),
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      if (product == null) {
        _showErrorMessage('Продукт по штрихкоду не найден');
        return;
      }

      // Выбрать найденный продукт
      _onProductSelected(ProductItem.fromJson(product));
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showErrorMessage('Не удалось проверить штрихкод');
    }
  }

  /// Показать сообщение об ошибке
  void _showErrorMessage(String message) {
    if (!mounted) return;

    showAppFeedback(
      context,
      message,
      kind: AppFeedbackKind.error,
      source: 'Поиск продуктов',
      preferPopup: true,
      addToInbox: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isRu = Localizations.localeOf(context).languageCode == 'ru';
    
    return Scaffold(
      appBar: AppTopBar(
        title: isRu ? 'Поиск продуктов' : 'Product search',
        actions: [
          AppTopAction(
            icon: Icons.qr_code_scanner_rounded,
            onPressed: _onScanButtonPressed,
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
            // Поле поиска
            Padding(
              padding: const EdgeInsets.all(16),
              child: Semantics(
                label: isRu ? 'Поиск продуктов' : 'Product search',
                child: TextField(
                  controller: _searchController,
                  autofocus: false,
                  decoration: InputDecoration(
                    hintText: isRu 
                        ? 'Введите название продукта' 
                        : 'Enter product name',
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) {
                    final query = _searchController.text.trim();
                    if (query.isNotEmpty) {
                      _performSearch(query);
                    }
                  },
                ),
              ),
            ),

            // Список результатов поиска
            Expanded(
              child: SearchResultsList(
                items: _searchResults,
                onItemTap: _onProductSelected,
                isLoading: _isLoading,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
