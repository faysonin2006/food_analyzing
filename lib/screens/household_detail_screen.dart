import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_feedback.dart';
import '../core/live_refresh.dart';
import '../core/app_theme.dart';
import '../core/atelier_ui.dart';
import '../core/app_top_bar.dart';
import '../features/product_search/models/product_search_context.dart';
import '../features/product_search/screens/unified_product_search_screen.dart';
import '../repositories/app_repository.dart';
import '../services/api_service.dart';

class HouseholdDetailScreen extends StatefulWidget {
  const HouseholdDetailScreen({
    super.key,
    required this.householdId,
    required this.initialName,
  });

  final String householdId;
  final String initialName;

  @override
  State<HouseholdDetailScreen> createState() => _HouseholdDetailScreenState();
}

class _HouseholdDetailScreenState extends State<HouseholdDetailScreen>
    with LiveRefreshState<HouseholdDetailScreen> {
  final AppRepository repository = AppRepository.instance;
  final TextEditingController _messageController = TextEditingController();
  final RegExp _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  bool _loading = true;
  bool _isFetching = false;
  bool _didScheduleInitialLoad = false;
  Map<String, dynamic>? _detail;
  List<Map<String, dynamic>> _shoppingItems = const [];
  List<Map<String, dynamic>> _messages = const [];
  String _lastSnapshotSignature = '';

  bool get _isRu => Localizations.localeOf(context).languageCode == 'ru';
  ThemeData get _theme => Theme.of(context);
  ColorScheme get _cs => _theme.colorScheme;
  String get _screenTitle => _isRu ? 'Семья' : 'Household';

  String _errorText(Object error, String fallback) {
    if (error is ApiException) return error.message;
    final text = error.toString().trim();
    if (text.isEmpty) return fallback;
    return text.startsWith('Exception: ') ? text.substring(11) : text;
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

  void _showLoadWarnings(List<String> errors) {
    if (!mounted || errors.isEmpty) return;
    final prefix = _isRu
        ? 'Не все данные семьи обновились.'
        : 'Not all household data was refreshed.';
    _showMessage('$prefix\n${errors.toSet().join('\n')}');
  }

  String _roleLabel(String raw) {
    switch (raw.trim().toUpperCase()) {
      case 'OWNER':
        return _isRu ? 'Владелец' : 'Owner';
      case 'ADMIN':
        return _isRu ? 'Администратор' : 'Admin';
      case 'MEMBER':
        return _isRu ? 'Участник' : 'Member';
      default:
        return raw;
    }
  }

  @override
  Duration get liveRefreshInterval => const Duration(seconds: 5);

  @override
  bool get enableLiveRefresh => ModalRoute.of(context)?.isCurrent ?? true;

  @override
  Future<void> performLiveRefresh() => _load(silent: true);

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
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (_isFetching) return;
    _isFetching = true;
    if (!silent) {
      setState(() => _loading = true);
    }
    final errors = <String>[];
    try {
      final detailFuture = _loadWithFallback<Map<String, dynamic>?>(
        future: repository.getHouseholdDetail(widget.householdId),
        fallback: _detail,
        errors: errors,
        fallbackMessage: _isRu
            ? 'Не удалось загрузить сведения о семье'
            : 'Failed to load household details',
      );
      final shoppingFuture = _loadWithFallback<List<Map<String, dynamic>>>(
        future: repository.getHouseholdShoppingItems(widget.householdId),
        fallback: _shoppingItems,
        errors: errors,
        fallbackMessage: _isRu
            ? 'Не удалось загрузить общий список покупок'
            : 'Failed to load shared shopping items',
      );
      final messagesFuture = _loadWithFallback<List<Map<String, dynamic>>>(
        future: repository.getHouseholdMessages(widget.householdId),
        fallback: _messages,
        errors: errors,
        fallbackMessage: _isRu
            ? 'Не удалось загрузить сообщения семьи'
            : 'Failed to load household messages',
      );

      final detail = await detailFuture;
      final shoppingItems = await shoppingFuture;
      final messages = await messagesFuture;
      final nextSignature = liveRefreshSignature(<String, Object?>{
        'detail': detail,
        'shoppingItems': shoppingItems,
        'messages': messages,
      });

      if (!mounted) return;
      final hasChanged = nextSignature != _lastSnapshotSignature;
      if (hasChanged || !silent || _loading) {
        setState(() {
          _detail = detail;
          _shoppingItems = shoppingItems;
          _messages = messages;
          _loading = false;
        });
      }
      _lastSnapshotSignature = nextSignature;
      if (!silent) {
        _showLoadWarnings(errors);
      }
    } finally {
      _isFetching = false;
    }
  }

  Future<void> _inviteMember() async {
    final ctrl = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => AtelierDialogFrame(
        title: _isRu ? 'Пригласить участника' : 'Invite member',
        subtitle: _isRu
            ? 'Добавь email, чтобы пригласить нового участника в household.'
            : 'Add an email address to invite a new member into this household.',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AtelierFieldLabel('Email'),
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(hintText: 'email@example.com'),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(_isRu ? 'Отмена' : 'Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () async {
                      final email = ctrl.text.trim();
                      if (!_emailPattern.hasMatch(email)) {
                        showAppFeedback(
                          context,
                          _isRu
                              ? 'Введи корректный email'
                              : 'Enter a valid email address',
                          kind: AppFeedbackKind.error,
                          source: _screenTitle,
                          preferPopup: true,
                          addToInbox: false,
                        );
                        return;
                      }

                      try {
                        final result = await repository
                            .createHouseholdInvitation(
                              widget.householdId,
                              email,
                            );
                        if (!context.mounted) return;
                        Navigator.of(context).pop(result != null);
                      } catch (error) {
                        if (!context.mounted) return;
                        showAppFeedback(
                          context,
                          _errorText(
                            error,
                            _isRu
                                ? 'Не удалось отправить приглашение'
                                : 'Failed to send invitation',
                          ),
                          kind: AppFeedbackKind.error,
                          source: _screenTitle,
                          preferPopup: true,
                        );
                      }
                    },
                    child: Text(_isRu ? 'Отправить' : 'Send'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (created == true) {
      await _load();
    }
  }

  Future<void> _addShoppingItem() async {
    // Показать выбор способа добавления
    final choice = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AtelierSheetFrame(
        title: _isRu ? 'Добавить покупку' : 'Add shopping item',
        subtitle: _isRu
            ? 'Выбери способ добавления продукта в общий список покупок.'
            : 'Choose how to add a product to the shared shopping list.',
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
      await _addShoppingItemFromProductSearch();
    } else {
      await _addShoppingItemManually();
    }
  }

  Future<void> _addShoppingItemFromProductSearch() async {
    final selected = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => UnifiedProductSearchScreen(
          context: ProductSearchContext.family,
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

    try {
      final result = await repository.createHouseholdShoppingItem(
        widget.householdId,
        {
          'name': name,
          'quantity': 1.0,
          'unit': null,
          'note': null,
        },
      );
      if (!mounted) return;
      if (result != null) {
        await _load();
      }
    } catch (error) {
      if (!mounted) return;
      showAppFeedback(
        context,
        _errorText(
          error,
          _isRu
              ? 'Не удалось добавить покупку'
              : 'Failed to add shopping item',
        ),
        kind: AppFeedbackKind.error,
        source: _screenTitle,
        preferPopup: true,
      );
    }
  }

  Future<void> _addShoppingItemManually() async {
    final nameCtrl = TextEditingController();
    final quantityCtrl = TextEditingController(text: '1');
    final unitCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AtelierSheetFrame(
        title: _isRu ? 'Что нужно купить?' : 'What should be bought?',
        subtitle: _isRu
            ? 'Добавь позицию в общий household shopping list.'
            : 'Add a new item to the shared household shopping list.',
        onClose: () => Navigator.of(context).pop(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AtelierFieldLabel(_isRu ? 'Название' : 'Name'),
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                hintText: _isRu ? 'Например, йогурт' : 'For example, yogurt',
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
            const SizedBox(height: 14),
            AtelierFieldLabel(_isRu ? 'Заметка' : 'Note'),
            TextField(
              controller: noteCtrl,
              decoration: InputDecoration(
                hintText: _isRu
                    ? 'Например, для ужина в пятницу'
                    : 'For example, for Friday dinner',
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  final name = nameCtrl.text.trim();
                  final quantity = double.tryParse(
                    quantityCtrl.text.trim().replaceAll(',', '.'),
                  );

                  if (name.isEmpty) {
                    showAppFeedback(
                      context,
                      _isRu ? 'Введи название товара' : 'Enter an item name',
                      kind: AppFeedbackKind.error,
                      source: _screenTitle,
                      preferPopup: true,
                      addToInbox: false,
                    );
                    return;
                  }

                  if (quantity == null || quantity <= 0) {
                    showAppFeedback(
                      context,
                      _isRu
                          ? 'Количество должно быть больше нуля'
                          : 'Quantity must be greater than zero',
                      kind: AppFeedbackKind.error,
                      source: _screenTitle,
                      preferPopup: true,
                      addToInbox: false,
                    );
                    return;
                  }

                  try {
                    final result = await repository
                        .createHouseholdShoppingItem(widget.householdId, {
                          'name': name,
                          'quantity': quantity,
                          'unit': unitCtrl.text.trim().isEmpty
                              ? null
                              : unitCtrl.text.trim(),
                          'note': noteCtrl.text.trim().isEmpty
                              ? null
                              : noteCtrl.text.trim(),
                        });
                    if (!context.mounted) return;
                    Navigator.of(context).pop(result != null);
                  } catch (error) {
                    if (!context.mounted) return;
                    showAppFeedback(
                      context,
                      _errorText(
                        error,
                        _isRu
                            ? 'Не удалось добавить покупку'
                            : 'Failed to add shopping item',
                      ),
                      kind: AppFeedbackKind.error,
                      source: _screenTitle,
                      preferPopup: true,
                    );
                  }
                },
                child: Text(_isRu ? 'Добавить' : 'Add'),
              ),
            ),
          ],
        ),
      ),
    );
    if (created == true) {
      await _load();
    }
  }

  Future<void> _toggleShoppingItem(Map<String, dynamic> item) async {
    try {
      final updated = await repository.toggleHouseholdShoppingItem(
        widget.householdId,
        item['id'].toString(),
      );
      if (updated != null) {
        await _load();
      }
    } catch (error) {
      _showMessage(
        _errorText(
          error,
          _isRu
              ? 'Не удалось обновить покупку'
              : 'Failed to update shopping item',
        ),
      );
    }
  }

  Future<void> _deleteShoppingItem(Map<String, dynamic> item) async {
    try {
      final ok = await repository.deleteHouseholdShoppingItem(
        widget.householdId,
        item['id'].toString(),
      );
      if (ok) {
        await _load();
      }
    } catch (error) {
      _showMessage(
        _errorText(
          error,
          _isRu
              ? 'Не удалось удалить покупку'
              : 'Failed to delete shopping item',
        ),
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    try {
      final created = await repository.createHouseholdMessage(
        widget.householdId,
        text,
      );
      if (created != null) {
        _messageController.clear();
        await _load();
      }
    } catch (error) {
      _showMessage(
        _errorText(
          error,
          _isRu ? 'Не удалось отправить сообщение' : 'Failed to send message',
        ),
      );
    }
  }

  String _shoppingMeta(Map<String, dynamic> item) {
    final parts = <String>[];
    final quantity = item['quantity']?.toString().trim() ?? '';
    final unit = item['unit']?.toString().trim() ?? '';
    if (quantity.isNotEmpty) {
      parts.add(unit.isEmpty ? quantity : '$quantity $unit');
    }
    final note = item['note']?.toString().trim() ?? '';
    if (note.isNotEmpty) {
      parts.add(note);
    }
    final addedBy = item['addedByName']?.toString().trim() ?? '';
    if (addedBy.isNotEmpty) {
      parts.add(addedBy);
    }
    return parts.join(' • ');
  }

  String _messageTime(dynamic raw) {
    final text = raw?.toString().trim() ?? '';
    if (text.isEmpty) return '';
    return _formatDateTime(text);
  }

  String _formatDateTime(String raw) {
    final date = DateTime.tryParse(raw);
    if (date == null) return raw;
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    final hh = date.hour.toString().padLeft(2, '0');
    final mm = date.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final householdName = _detail?['name']?.toString().trim().isNotEmpty == true
        ? _detail!['name'].toString()
        : widget.initialName;
    final members = (_detail?['members'] as List?)?.cast<dynamic>() ?? const [];

    return Scaffold(
      backgroundColor: _theme.scaffoldBackgroundColor,
      appBar: AppTopBar(
        title: householdName,
        actions: [
          AppTopAction(
            icon: Icons.person_add_alt_1_rounded,
            onPressed: _inviteMember,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addShoppingItem,
        icon: const Icon(Icons.add_shopping_cart_rounded),
        label: Text(_isRu ? 'Добавить покупку' : 'Add shopping item'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
          children: [
            AtelierHeroCard(
              eyebrow: 'The Organic Atelier',
              title: householdName,
              subtitle: _isRu
                  ? 'Общее пространство для семьи: участники, покупки и сообщения в одном месте.'
                  : 'A shared home space for members, shopping, and messages in one place.',
              gradientColors: [
                _cs.primary.withValues(alpha: 0.14),
                AppTheme.atelierLime.withValues(alpha: 0.16),
                AppTheme.atelierHoney.withValues(alpha: 0.08),
              ],
              pills: [
                AtelierStatPill(
                  icon: Icons.groups_rounded,
                  label: _isRu
                      ? '${members.length} участников'
                      : '${members.length} members',
                  color: _cs.primary,
                ),
                AtelierStatPill(
                  icon: Icons.shopping_cart_rounded,
                  label: _isRu
                      ? '${_shoppingItems.length} покупок'
                      : '${_shoppingItems.length} items',
                  color: _cs.secondary,
                ),
                AtelierStatPill(
                  icon: Icons.forum_rounded,
                  label: _isRu
                      ? '${_messages.length} сообщений'
                      : '${_messages.length} messages',
                  color: _cs.tertiary,
                ),
              ],
            ),
            const SizedBox(height: 28),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              AtelierSectionIntro(
                eyebrow: _isRu ? 'участники' : 'members',
                title: _isRu ? 'Состав семьи' : 'Members',
                subtitle: _isRu
                    ? 'Все участники household с ролями и доступом.'
                    : 'Everyone inside this household, including roles and access.',
              ),
              const SizedBox(height: 16),
              if (members.isEmpty)
                AtelierEmptyState(
                  icon: Icons.groups_rounded,
                  title: _isRu ? 'Участников пока нет' : 'No members yet',
                  subtitle: _isRu
                      ? 'Пригласи первого участника, чтобы разделить shopping и сообщения.'
                      : 'Invite the first member to share shopping and messages.',
                  accent: _cs.primary,
                )
              else
                AtelierSurfaceCard(
                  radius: 24,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: members.map((member) {
                      final map = Map<String, dynamic>.from(member as Map);
                      final label =
                          map['displayName']?.toString() ??
                          map['email']?.toString() ??
                          '-';
                      final role = map['role']?.toString() ?? 'MEMBER';
                      return AtelierTagChip(
                        label: '$label • ${_roleLabel(role)}',
                        foreground: role == 'OWNER'
                            ? _cs.tertiary
                            : role == 'ADMIN'
                            ? _cs.secondary
                            : _cs.primary,
                        icon: Icons.person_rounded,
                      );
                    }).toList(),
                  ),
                ),
              const SizedBox(height: 28),
              AtelierSectionIntro(
                eyebrow: _isRu ? 'покупки' : 'shopping',
                title: _isRu ? 'Общий список покупок' : 'Shared shopping',
                subtitle: _isRu
                    ? 'Добавляйте покупки вместе и отмечайте то, что уже куплено.'
                    : 'Add items together and mark what has already been bought.',
              ),
              const SizedBox(height: 16),
              if (_shoppingItems.isEmpty)
                AtelierEmptyState(
                  icon: Icons.shopping_cart_outlined,
                  title: _isRu
                      ? 'Список пока пуст'
                      : 'Shared shopping is empty',
                  subtitle: _isRu
                      ? 'Добавь первую покупку в общее пространство.'
                      : 'Add the first shared shopping item for this household.',
                  accent: _cs.secondary,
                )
              else
                ..._shoppingItems.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: AtelierSurfaceCard(
                      radius: 24,
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InkWell(
                            onTap: () => _toggleShoppingItem(item),
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: item['checked'] == true
                                    ? _cs.primary.withValues(alpha: 0.14)
                                    : _cs.surface,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: item['checked'] == true
                                      ? _cs.primary
                                      : _cs.outlineVariant,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                item['checked'] == true
                                    ? Icons.check_rounded
                                    : Icons.shopping_bag_rounded,
                                color: item['checked'] == true
                                    ? _cs.primary
                                    : _cs.onSurfaceVariant,
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
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    if ((item['quantity']?.toString().trim() ??
                                            '')
                                        .isNotEmpty)
                                      AtelierTagChip(
                                        label:
                                            '${item['quantity']?.toString().trim() ?? ''} ${item['unit']?.toString().trim() ?? ''}'
                                                .trim(),
                                        foreground: _cs.secondary,
                                        icon: Icons.scale_rounded,
                                      ),
                                    AtelierTagChip(
                                      label: item['checked'] == true
                                          ? (_isRu ? 'Куплено' : 'Checked')
                                          : (_isRu ? 'В работе' : 'Open'),
                                      foreground: item['checked'] == true
                                          ? _cs.primary
                                          : _cs.tertiary,
                                      icon: item['checked'] == true
                                          ? Icons.task_alt_rounded
                                          : Icons.pending_actions_rounded,
                                    ),
                                  ],
                                ),
                                if (_shoppingMeta(item).isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    _shoppingMeta(item),
                                    style: TextStyle(
                                      color: _cs.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
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
                              onPressed: () => _deleteShoppingItem(item),
                              icon: Icon(
                                Icons.delete_outline_rounded,
                                size: 18,
                                color: _cs.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 28),
              AtelierSectionIntro(
                eyebrow: _isRu ? 'чат' : 'messages',
                title: _isRu ? 'Сообщения семьи' : 'Household messages',
                subtitle: _isRu
                    ? 'Короткие сообщения по покупкам и домашним делам.'
                    : 'Short notes around shopping and home coordination.',
              ),
              const SizedBox(height: 16),
              AtelierSurfaceCard(
                radius: 24,
                child: Column(
                  children: [
                    if (_messages.isEmpty)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _isRu ? 'Пока без сообщений.' : 'No messages yet.',
                          style: TextStyle(
                            color: _cs.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else
                      ..._messages.map((msg) {
                        final messageTime = _messageTime(
                          msg['createdAt'] ?? msg['sentAt'],
                        );
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: _cs.surface,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: _cs.outlineVariant.withValues(
                                    alpha: 0.35,
                                  ),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          msg['authorName']?.toString() ?? '-',
                                          style: TextStyle(
                                            color: _cs.primary,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                      if (messageTime.isNotEmpty)
                                        Text(
                                          messageTime,
                                          style: TextStyle(
                                            color: _cs.onSurfaceVariant,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    msg['message']?.toString() ?? '',
                                    style: TextStyle(
                                      color: _cs.onSurface,
                                      fontWeight: FontWeight.w600,
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.forum_outlined),
                              hintText: _isRu
                                  ? 'Написать сообщение'
                                  : 'Write a message',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        FilledButton.icon(
                          onPressed: _sendMessage,
                          icon: const Icon(Icons.send_rounded),
                          label: Text(_isRu ? 'Отправить' : 'Send'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
