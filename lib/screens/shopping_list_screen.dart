import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_feedback.dart';
import '../core/live_refresh.dart';
import '../core/atelier_ui.dart';
import '../core/app_top_bar.dart';
import '../core/food_suggestions.dart';
import '../core/suggestion_panel.dart';
import '../features/product_search/models/product_search_context.dart';
import '../features/product_search/screens/unified_product_search_screen.dart';
import '../repositories/app_repository.dart';

class ShoppingListScreen extends StatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen>
    with LiveRefreshState<ShoppingListScreen> {
  final AppRepository repository = AppRepository.instance;
  final ScrollController _scrollController = ScrollController();
  GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  bool _loading = true;
  bool _isFetching = false;
  List<Map<String, dynamic>> _items = const [];
  Set<String> _busyItemIds = <String>{};
  bool _bulkDeletingDone = false;
  static const _listAnimationDuration = Duration(milliseconds: 220);
  String _lastItemsSignature = '';

  bool get _isRu => Localizations.localeOf(context).languageCode == 'ru';
  ThemeData get _theme => Theme.of(context);
  ColorScheme get _cs => _theme.colorScheme;
  String get _feedbackSource => _isRu ? 'Список покупок' : 'Shopping list';

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

  @override
  Duration get liveRefreshInterval => const Duration(seconds: 8);

  @override
  bool get enableLiveRefresh => ModalRoute.of(context)?.isCurrent ?? true;

  @override
  Future<void> performLiveRefresh() =>
      _load(preserveOffset: true, silent: true);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load({bool preserveOffset = false, bool silent = false}) async {
    if (_isFetching) return;
    _isFetching = true;
    final offset = preserveOffset && _scrollController.hasClients
        ? _scrollController.offset
        : 0.0;
    if (!silent) {
      setState(() => _loading = true);
    }
    try {
      final items = await repository.getShoppingItems();
      final sortedItems = _sortedItems(items);
      final nextSignature = liveRefreshSignature(sortedItems);

      if (!mounted) return;
      final hasChanged = nextSignature != _lastItemsSignature;
      if (hasChanged || !silent || _loading) {
        setState(() {
          _items = sortedItems;
          _listKey = GlobalKey<AnimatedListState>();
          _loading = false;
        });
        if (preserveOffset) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!_scrollController.hasClients) return;
            final maxOffset = _scrollController.position.maxScrollExtent;
            _scrollController.jumpTo(offset.clamp(0.0, maxOffset));
          });
        }
      }
      _lastItemsSignature = nextSignature;
    } catch (error) {
      if (!mounted) return;
      if (!silent) {
        setState(() => _loading = false);
        _showFeedback(
          _isRu
              ? 'Не удалось загрузить список покупок.'
              : 'Failed to load shopping list.',
          kind: AppFeedbackKind.error,
          preferPopup: true,
        );
      }
    } finally {
      _isFetching = false;
    }
  }

  String _itemId(Map<String, dynamic> item) => item['id']?.toString() ?? '';

  bool _isChecked(Map<String, dynamic> item) => item['checked'] == true;

  List<Map<String, dynamic>> _sortedItems(List<Map<String, dynamic>> items) {
    final active = <Map<String, dynamic>>[];
    final done = <Map<String, dynamic>>[];

    for (final item in items) {
      final copy = Map<String, dynamic>.from(item);
      if (_isChecked(copy)) {
        done.add(copy);
      } else {
        active.add(copy);
      }
    }

    return [...active, ...done];
  }

  Map<String, dynamic> _mergeShoppingItem(
    Map<String, dynamic> current,
    Map<String, dynamic> incoming,
  ) {
    return <String, dynamic>{...current, ...incoming};
  }

  void _setItemBusy(String itemId, bool isBusy) {
    if (itemId.isEmpty || !mounted) return;
    setState(() {
      if (isBusy) {
        _busyItemIds = {..._busyItemIds, itemId};
      } else {
        final next = {..._busyItemIds};
        next.remove(itemId);
        _busyItemIds = next;
      }
    });
  }

  int _indexOfItemById(String itemId) {
    return _items.indexWhere((entry) => _itemId(entry) == itemId);
  }

  int _targetIndexForToggledItem(Map<String, dynamic> item) {
    if (_isChecked(item)) {
      return _items.length;
    }
    return 0;
  }

  Widget _buildAnimatedItem(
    Map<String, dynamic> item,
    Animation<double> animation,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    return SizeTransition(
      sizeFactor: curved,
      axisAlignment: -1,
      child: FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.04),
            end: Offset.zero,
          ).animate(curved),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _shoppingCard(item),
          ),
        ),
      ),
    );
  }

  Future<void> _addItem() async {
    // Показать выбор способа добавления
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => AtelierSheetFrame(
        title: _isRu ? 'Добавить покупку' : 'Add shopping item',
        subtitle: _isRu
            ? 'Выбери способ добавления продукта в список покупок.'
            : 'Choose how to add a product to your shopping list.',
        onClose: () => Navigator.of(context).pop(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AtelierSurfaceCard(
              radius: 24,
              padding: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(Icons.edit_rounded),
                title: Text(_isRu ? 'Добавить вручную' : 'Add manually'),
                subtitle: Text(
                  _isRu
                      ? 'Введи название и количество самостоятельно.'
                      : 'Enter name and quantity yourself.',
                ),
                onTap: () => Navigator.of(context).pop('manual'),
              ),
            ),
            const SizedBox(height: 10),
            AtelierSurfaceCard(
              radius: 24,
              padding: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(Icons.search_rounded),
                title: Text(_isRu ? 'Найти в базе продуктов' : 'Search product database'),
                subtitle: Text(
                  _isRu
                      ? 'Поиск среди тысяч продуктов.'
                      : 'Search among thousands of products.',
                ),
                onTap: () => Navigator.of(context).pop('search'),
              ),
            ),
          ],
        ),
      ),
    );

    if (!mounted || choice == null) return;

    if (choice == 'search') {
      await _addItemFromProductSearch();
    } else {
      await _addItemManually();
    }
  }

  Future<void> _addItemFromProductSearch() async {
    final selected = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => UnifiedProductSearchScreen(
          context: ProductSearchContext.shopping,
          initialQuery: '',
          onProductSelected: (product) {
            // Product will be returned via Navigator.pop
          },
        ),
      ),
    );
    if (!mounted || selected == null) return;

    // Создать элемент списка покупок из выбранного продукта
    final name = selected['productName']?.toString().trim() ?? '';
    if (name.isEmpty) return;

    final result = await repository.createShoppingItem({
      'name': name,
      'quantity': 1.0,
      'unit': null,
    });

    if (!mounted) return;
    if (result != null) {
      await HapticFeedback.lightImpact();
      setState(() {
        _items = [result, ..._items];
      });
      _listKey.currentState?.insertItem(0, duration: _listAnimationDuration);
    }
  }

  Future<void> _addItemManually() async {
    final nameCtrl = TextEditingController();
    final quantityCtrl = TextEditingController(text: '1');
    final unitCtrl = TextEditingController();
    final itemSuggestionsSource = List<Map<String, dynamic>>.from(_items);
    var creatingItem = false;
    var nameSuggestions = const <SuggestionOption>[];

    void refreshNameSuggestions(StateSetter setSheetState) {
      final query = nameCtrl.text;
      final candidates = FoodSuggestions.collectProductSuggestions(
        isRu: _isRu,
        shoppingItems: itemSuggestionsSource,
      );
      final local = FoodSuggestions.rankSuggestions(
        candidates,
        query: query,
        limit: 6,
      );
      setSheetState(() => nameSuggestions = local);
    }

    final created = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => AtelierSheetFrame(
          title: _isRu ? 'Новая покупка' : 'New shopping item',
          subtitle: _isRu
              ? 'Добавь продукт, чтобы он сразу попал в твой список покупок.'
              : 'Add an item so it drops straight into your personal shopping flow.',
          onClose: () => Navigator.of(context).pop(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AtelierFieldLabel(_isRu ? 'Название' : 'Name'),
              TextFieldTapRegion(
                child: Column(
                  children: [
                    TextField(
                      controller: nameCtrl,
                      onTap: () => refreshNameSuggestions(setSheetState),
                      onChanged: (_) => refreshNameSuggestions(setSheetState),
                      onTapOutside: (_) {
                        FocusScope.of(context).unfocus();
                        setSheetState(() {
                          nameSuggestions = const <SuggestionOption>[];
                        });
                      },
                      decoration: InputDecoration(
                        hintText: _isRu
                            ? 'Например, авокадо'
                            : 'For example, avocado',
                      ),
                    ),
                    if (nameSuggestions.isNotEmpty)
                      AtelierSuggestionPanel(
                        suggestions: nameSuggestions,
                        isRu: _isRu,
                        onSelected: (option) {
                          nameCtrl.text = option.primaryText;
                          nameCtrl.selection = TextSelection.collapsed(
                            offset: nameCtrl.text.length,
                          );
                          if (unitCtrl.text.trim().isEmpty &&
                              (option.shoppingUnit ?? '').trim().isNotEmpty) {
                            unitCtrl.text = option.shoppingUnit!.trim();
                          }
                          if ((quantityCtrl.text.trim().isEmpty ||
                                  quantityCtrl.text.trim() == '1') &&
                              (option.quantity ?? '').trim().isNotEmpty) {
                            quantityCtrl.text = option.quantity!.trim();
                          }
                          FocusScope.of(context).unfocus();
                          setSheetState(() {
                            nameSuggestions = const <SuggestionOption>[];
                          });
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AtelierFieldLabel(_isRu ? 'Количество' : 'Quantity'),
                        TextField(
                          controller: quantityCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(hintText: '1'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AtelierFieldLabel(_isRu ? 'Единица' : 'Unit'),
                        TextField(
                          controller: unitCtrl,
                          decoration: InputDecoration(
                            hintText: _isRu ? 'шт / кг / мл' : 'pcs / kg / ml',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: creatingItem
                      ? null
                      : () async {
                          if (nameCtrl.text.trim().isEmpty) return;
                          setSheetState(() => creatingItem = true);
                          final result = await repository.createShoppingItem({
                            'name': nameCtrl.text.trim(),
                            'quantity':
                                double.tryParse(
                                  quantityCtrl.text.trim().replaceAll(',', '.'),
                                ) ??
                                1,
                            'unit': unitCtrl.text.trim().isEmpty
                                ? null
                                : unitCtrl.text.trim(),
                          });
                          if (!context.mounted) return;
                          setSheetState(() => creatingItem = false);
                          Navigator.of(context).pop(result);
                        },
                  child: creatingItem
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: _cs.onPrimary,
                          ),
                        )
                      : Text(_isRu ? 'Добавить в список' : 'Add to shopping'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (created != null) {
      await HapticFeedback.lightImpact();
      setState(() {
        _items = [created, ..._items];
      });
      _listKey.currentState?.insertItem(0, duration: _listAnimationDuration);
      return;
    }
  }

  Future<void> _toggleItem(Map<String, dynamic> item) async {
    final itemId = _itemId(item);
    if (itemId.isEmpty || _busyItemIds.contains(itemId)) return;
    await HapticFeedback.selectionClick();

    final index = _indexOfItemById(itemId);
    if (index < 0) return;

    final previous = Map<String, dynamic>.from(_items[index]);
    final optimistic = Map<String, dynamic>.from(previous)
      ..['checked'] = !(previous['checked'] == true);

    _setItemBusy(itemId, true);
    setState(() {
      _items = List<Map<String, dynamic>>.from(_items)..removeAt(index);
    });
    _listKey.currentState?.removeItem(
      index,
      (context, animation) => _buildAnimatedItem(optimistic, animation),
      duration: _listAnimationDuration,
    );

    await Future<void>.delayed(const Duration(milliseconds: 90));
    if (!mounted) return;

    final targetIndex = _targetIndexForToggledItem(
      optimistic,
    ).clamp(0, _items.length);
    setState(() {
      _items = List<Map<String, dynamic>>.from(_items)
        ..insert(targetIndex, optimistic);
    });
    _listKey.currentState?.insertItem(
      targetIndex,
      duration: _listAnimationDuration,
    );

    final updated = await repository.toggleShoppingItem(itemId);
    if (!mounted) return;

    final currentIndex = _indexOfItemById(itemId);
    if (updated != null) {
      if (currentIndex >= 0) {
        setState(() {
          _items = List<Map<String, dynamic>>.from(_items)
            ..[currentIndex] = _mergeShoppingItem(optimistic, updated);
        });
      }
    } else {
      if (currentIndex >= 0) {
        final failedItem = Map<String, dynamic>.from(_items[currentIndex]);
        setState(() {
          _items = List<Map<String, dynamic>>.from(_items)
            ..removeAt(currentIndex);
        });
        _listKey.currentState?.removeItem(
          currentIndex,
          (context, animation) => _buildAnimatedItem(failedItem, animation),
          duration: _listAnimationDuration,
        );
        await Future<void>.delayed(const Duration(milliseconds: 90));
        if (!mounted) return;
        final restoreIndex = index.clamp(0, _items.length);
        setState(() {
          _items = List<Map<String, dynamic>>.from(_items)
            ..insert(restoreIndex, previous);
        });
        _listKey.currentState?.insertItem(
          restoreIndex,
          duration: _listAnimationDuration,
        );
      }

      _showFeedback(
        _isRu
            ? 'Не удалось удалить позицию.'
            : 'Failed to delete shopping item.',
        kind: AppFeedbackKind.error,
        preferPopup: true,
      );
    }
    _setItemBusy(itemId, false);
  }

  Future<void> _deleteItem(Map<String, dynamic> item) async {
    final itemId = _itemId(item);
    if (itemId.isEmpty || _busyItemIds.contains(itemId)) return;
    await HapticFeedback.mediumImpact();

    final index = _indexOfItemById(itemId);
    if (index < 0) return;

    final removed = Map<String, dynamic>.from(_items[index]);
    _setItemBusy(itemId, true);
    setState(() {
      _items = List<Map<String, dynamic>>.from(_items)..removeAt(index);
    });
    _listKey.currentState?.removeItem(
      index,
      (context, animation) => _buildAnimatedItem(removed, animation),
      duration: _listAnimationDuration,
    );

    final ok = await repository.deleteShoppingItem(itemId);
    if (!mounted) return;

    if (!ok) {
      final restoreIndex = index.clamp(0, _items.length);
      setState(() {
        _items = List<Map<String, dynamic>>.from(_items)
          ..insert(restoreIndex, removed);
      });
      _listKey.currentState?.insertItem(
        restoreIndex,
        duration: _listAnimationDuration,
      );
      _showFeedback(
        _isRu
            ? 'Не удалось обновить позицию.'
            : 'Failed to update shopping item.',
        kind: AppFeedbackKind.error,
        preferPopup: true,
      );
    }
    _setItemBusy(itemId, false);
  }

  Future<void> _deleteCheckedItems() async {
    if (_bulkDeletingDone) return;
    final doneItems = _items
        .where((item) => item['checked'] == true)
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    if (doneItems.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AtelierDialogFrame(
        title: _isRu ? 'Удалить купленное?' : 'Delete purchased items?',
        subtitle: _isRu
            ? 'Все отмеченные как купленные позиции будут удалены из списка.'
            : 'All checked items will be removed from the list.',
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(_isRu ? 'Отмена' : 'Cancel'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(_isRu ? 'Удалить' : 'Delete'),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    await HapticFeedback.mediumImpact();
    setState(() => _bulkDeletingDone = true);

    for (var index = _items.length - 1; index >= 0; index--) {
      final current = _items[index];
      if (!_isChecked(current)) continue;
      final removed = Map<String, dynamic>.from(current);
      setState(() {
        _items = List<Map<String, dynamic>>.from(_items)..removeAt(index);
      });
      _listKey.currentState?.removeItem(
        index,
        (context, animation) => _buildAnimatedItem(removed, animation),
        duration: _listAnimationDuration,
      );
    }

    final results = await Future.wait(
      doneItems.map((item) => repository.deleteShoppingItem(_itemId(item))),
    );
    if (!mounted) return;

    final failedCount = results.where((ok) => !ok).length;
    setState(() => _bulkDeletingDone = false);

    if (failedCount > 0) {
      await _load(preserveOffset: true);
      if (!mounted) return;
      _showFeedback(
        _isRu
            ? 'Часть купленных позиций не удалось удалить.'
            : 'Some purchased items could not be deleted.',
        kind: AppFeedbackKind.error,
        preferPopup: true,
      );
      return;
    }

    _showFeedback(
      _isRu ? 'Купленные позиции удалены' : 'Purchased items removed',
      kind: AppFeedbackKind.success,
    );
  }

  Widget _shoppingCard(Map<String, dynamic> item) {
    final itemId = _itemId(item);
    final isBusy = _busyItemIds.contains(itemId) || _bulkDeletingDone;
    final checked = item['checked'] == true;
    final quantity = item['quantity']?.toString() ?? '';
    final unit = item['unit']?.toString() ?? '';
    final meta = [quantity, unit].where((e) => e.isNotEmpty).join(' ');

    return AtelierSurfaceCard(
      radius: 24,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: isBusy ? null : () => _toggleItem(item),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: checked
                    ? _cs.primary.withValues(alpha: 0.14)
                    : _cs.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: checked ? _cs.primary : _cs.outlineVariant,
                ),
              ),
              alignment: Alignment.center,
              child: isBusy
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.1,
                        color: checked ? _cs.primary : _cs.onSurfaceVariant,
                      ),
                    )
                  : Icon(
                      checked ? Icons.check_rounded : Icons.add_rounded,
                      color: checked ? _cs.primary : _cs.onSurfaceVariant,
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['name']?.toString() ?? '-',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    decoration: checked
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (meta.isNotEmpty)
                      AtelierStatPill(
                        icon: Icons.scale_rounded,
                        label: meta,
                        color: _cs.primary,
                      ),
                    AtelierStatPill(
                      icon: checked
                          ? Icons.task_alt_rounded
                          : Icons.shopping_bag_rounded,
                      label: checked
                          ? (_isRu ? 'Куплено' : 'Done')
                          : (_isRu ? 'В списке' : 'Queued'),
                      color: checked ? _cs.secondary : _cs.tertiary,
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: isBusy ? null : () => _deleteItem(item),
            icon: isBusy
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.1,
                      color: _cs.error,
                    ),
                  )
                : Icon(Icons.delete_outline_rounded, color: _cs.error),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _items.where((item) => item['checked'] != true).length;
    final doneCount = _items.where((item) => item['checked'] == true).length;

    return Scaffold(
      backgroundColor: _theme.scaffoldBackgroundColor,
      appBar: AppTopBar(
        title: _isRu ? 'Список покупок' : 'Shopping list',
        actions: const [],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addItem,
        icon: const Icon(Icons.add_rounded),
        label: Text(_isRu ? 'Добавить' : 'Add'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                AtelierStatPill(
                  icon: Icons.shopping_bag_rounded,
                  label: _isRu
                      ? '$activeCount активных'
                      : '$activeCount active',
                  color: _cs.primary,
                ),
                AtelierStatPill(
                  icon: Icons.task_alt_rounded,
                  label: _isRu ? '$doneCount куплено' : '$doneCount done',
                  color: _cs.secondary,
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (doneCount > 0) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonalIcon(
                  onPressed: _bulkDeletingDone ? null : _deleteCheckedItems,
                  icon: Icon(
                    _bulkDeletingDone
                        ? Icons.hourglass_top_rounded
                        : Icons.delete_sweep_rounded,
                  ),
                  label: Text(
                    _isRu ? 'Удалить купленное' : 'Clear purchased items',
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_items.isEmpty)
              AtelierEmptyState(
                icon: Icons.shopping_basket_rounded,
                title: _isRu ? 'Покупок пока нет' : 'No shopping items yet',
                subtitle: _isRu
                    ? 'Добавь первую позицию и начни собирать аккуратный список покупок.'
                    : 'Add the first item and start building a clean shopping flow.',
                accent: _cs.primary,
              )
            else
              AnimatedList(
                key: _listKey,
                initialItemCount: _items.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemBuilder: (context, index, animation) =>
                    _buildAnimatedItem(_items[index], animation),
              ),
          ],
        ),
      ),
    );
  }
}
