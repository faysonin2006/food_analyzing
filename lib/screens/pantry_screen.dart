import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/app_theme.dart';
import '../core/atelier_ui.dart';
import '../core/app_top_bar.dart';
import '../core/smart_food_suggestions.dart';
import '../core/smart_suggestion_ml.dart';
import '../core/smart_suggestion_panel.dart';
import '../repositories/app_repository.dart';
import '../services/api_service.dart';
import 'barcode_scanner_screen.dart';

enum _PantryListMode { all, expiring, expired }

class PantryScreen extends StatefulWidget {
  const PantryScreen({super.key});

  @override
  State<PantryScreen> createState() => _PantryScreenState();
}

class _PantryScreenState extends State<PantryScreen> {
  final AppRepository repository = AppRepository.instance;

  bool _loading = true;
  bool _didScheduleInitialLoad = false;
  _PantryListMode _mode = _PantryListMode.all;
  List<Map<String, dynamic>> _items = const [];
  List<Map<String, dynamic>> _expiring = const [];
  List<Map<String, dynamic>> _expired = const [];

  bool get _isRu => Localizations.localeOf(context).languageCode == 'ru';
  ThemeData get _theme => Theme.of(context);
  ColorScheme get _cs => _theme.colorScheme;
  bool get _isDark => _theme.brightness == Brightness.dark;
  String get _screenTitle => _isRu ? 'Кладовая' : 'Pantry';

  String _errorText(Object error, String fallback) {
    if (error is ApiException) return error.message;
    final text = error.toString().trim();
    if (text.isEmpty) return fallback;
    return text.startsWith('Exception: ') ? text.substring(11) : text;
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
    final details = errors.toSet().join('\n');
    final prefix = _isRu
        ? 'Не все разделы кладовой обновились.'
        : 'Not all pantry sections were refreshed.';
    _showMessage('$prefix\n$details');
  }

  String _formatQuantityValue(dynamic raw) {
    if (raw is int) return raw.toString();
    if (raw is double) {
      return raw == raw.roundToDouble()
          ? raw.toInt().toString()
          : raw.toStringAsFixed(raw.truncateToDouble() == raw ? 0 : 1);
    }
    if (raw is num) {
      final asDouble = raw.toDouble();
      return asDouble == asDouble.roundToDouble()
          ? raw.toInt().toString()
          : raw.toString();
    }
    final text = raw?.toString().trim() ?? '';
    return text.isEmpty ? '-' : text;
  }

  String _unitLabel(String? raw) {
    switch ((raw ?? '').trim().toUpperCase()) {
      case 'PIECE':
        return _isRu ? 'шт' : 'pcs';
      case 'GRAM':
        return _isRu ? 'г' : 'g';
      case 'KILOGRAM':
        return _isRu ? 'кг' : 'kg';
      case 'MILLILITER':
        return _isRu ? 'мл' : 'ml';
      case 'LITER':
        return _isRu ? 'л' : 'l';
      case 'PACK':
        return _isRu ? 'уп.' : 'pack';
      case 'BOTTLE':
        return _isRu ? 'бут.' : 'bottle';
      case 'CAN':
        return _isRu ? 'банка' : 'can';
      default:
        return raw?.trim() ?? '';
    }
  }

  String _statusLabel(String raw) {
    switch (raw.toUpperCase()) {
      case 'ACTIVE':
        return _isRu ? 'Активен' : 'Active';
      case 'CONSUMED':
        return _isRu ? 'Использован' : 'Consumed';
      case 'EXPIRED':
        return _isRu ? 'Просрочен' : 'Expired';
      case 'REMOVED':
        return _isRu ? 'Удален' : 'Removed';
      default:
        return raw;
    }
  }

  @override
  void initState() {
    super.initState();
  }

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

  Future<void> _load() async {
    setState(() => _loading = true);
    final errors = <String>[];
    final itemsFuture = _loadWithFallback<List<Map<String, dynamic>>>(
      future: repository.getPantryItems(),
      fallback: _items,
      errors: errors,
      fallbackMessage: _isRu
          ? 'Не удалось загрузить продукты'
          : 'Failed to load pantry items',
    );
    final expiringFuture = _loadWithFallback<List<Map<String, dynamic>>>(
      future: repository.getExpiringPantryItems(),
      fallback: _expiring,
      errors: errors,
      fallbackMessage: _isRu
          ? 'Не удалось загрузить продукты с истекающим сроком'
          : 'Failed to load expiring pantry items',
    );
    final expiredFuture = _loadWithFallback<List<Map<String, dynamic>>>(
      future: repository.getExpiredPantryItems(),
      fallback: _expired,
      errors: errors,
      fallbackMessage: _isRu
          ? 'Не удалось загрузить просроченные продукты'
          : 'Failed to load expired pantry items',
    );

    final items = await itemsFuture;
    final expiring = await expiringFuture;
    final expired = await expiredFuture;

    if (!mounted) return;
    setState(() {
      _items = items;
      _expiring = expiring;
      _expired = expired;
      _loading = false;
    });
    _showLoadWarnings(errors);
  }

  List<Map<String, dynamic>> get _visibleItems => switch (_mode) {
    _PantryListMode.all => _items,
    _PantryListMode.expiring => _expiring,
    _PantryListMode.expired => _expired,
  };

  String _titleForMode(_PantryListMode mode) => switch (mode) {
    _PantryListMode.all => _isRu ? 'Все' : 'All',
    _PantryListMode.expiring => _isRu ? 'Скоро истекает' : 'Expiring soon',
    _PantryListMode.expired => _isRu ? 'Просрочено' : 'Expired',
  };

  String _formatDate(dynamic raw) {
    final text = raw?.toString().trim() ?? '';
    if (text.isEmpty) return _isRu ? 'Не указано' : 'Not set';
    return text.split('T').first;
  }

  String _quantityLabel(Map<String, dynamic> item) {
    final quantity = _formatQuantityValue(item['quantity']);
    final unit = _unitLabel(item['unit']?.toString());
    return unit.isEmpty ? quantity : '$quantity $unit';
  }

  Color _statusColor(String raw) {
    switch (raw.toUpperCase()) {
      case 'ACTIVE':
        return _cs.primary;
      case 'CONSUMED':
        return _cs.secondary;
      case 'EXPIRED':
        return _cs.error;
      case 'REMOVED':
        return _cs.outline;
      default:
        return _cs.tertiary;
    }
  }

  Future<void> _showCreateOptions() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => AtelierSheetFrame(
        title: _isRu ? 'Добавить в кладовую' : 'Add to pantry',
        subtitle: _isRu
            ? 'Выбери быстрый способ: вручную или через сканирование штрихкода.'
            : 'Choose the faster route: manual entry or barcode scanning.',
        onClose: () => Navigator.of(context).pop(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AtelierSurfaceCard(
              radius: 24,
              padding: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(Icons.add_box_outlined),
                title: Text(_isRu ? 'Добавить вручную' : 'Add manually'),
                subtitle: Text(
                  _isRu
                      ? 'Заполни карточку продукта самостоятельно.'
                      : 'Fill in the pantry item card yourself.',
                ),
                onTap: () async {
                  Navigator.of(context).pop();
                  await _openEditor();
                },
              ),
            ),
            const SizedBox(height: 10),
            AtelierSurfaceCard(
              radius: 24,
              padding: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(Icons.qr_code_scanner_rounded),
                title: Text(_isRu ? 'Сканировать штрихкод' : 'Scan barcode'),
                subtitle: Text(
                  _isRu
                      ? 'Найдем продукт и предзаполним данные.'
                      : 'We will look up the product and prefill the details.',
                ),
                onTap: () async {
                  Navigator.of(context).pop();
                  await _scanBarcodeAndOpenEditor();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _scanBarcodeAndOpenEditor() async {
    final barcode = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (!mounted || barcode == null || barcode.trim().isEmpty) return;
    final normalizedBarcode = barcode.trim();
    try {
      final lookup = await repository.lookupPantryBarcode(normalizedBarcode);
      if (!mounted) return;
      if (lookup == null) {
        _showMessage(
          _isRu
              ? 'Товар не найден, заполни данные вручную'
              : 'Product not found, continue filling it manually',
        );
        await _openEditor(prefill: {'barcode': normalizedBarcode});
        return;
      }
      await _openEditor(
        prefill: _buildBarcodePrefill(lookup, normalizedBarcode),
      );
    } catch (error) {
      if (!mounted) return;
      _showMessage(
        _errorText(
          error,
          _isRu
              ? 'Не удалось проверить штрихкод, заполни товар вручную'
              : 'Failed to verify barcode, continue manually',
        ),
      );
      await _openEditor(prefill: {'barcode': normalizedBarcode});
    }
  }

  Map<String, dynamic> _buildBarcodePrefill(
    Map<String, dynamic> lookup,
    String normalizedBarcode,
  ) {
    final prefill = Map<String, dynamic>.from(lookup);
    prefill['barcode'] = (lookup['barcode']?.toString().trim() ?? '').isEmpty
        ? normalizedBarcode
        : lookup['barcode'];

    final imageUrl =
        lookup['imageUrl']?.toString().trim() ??
        lookup['image_front_url']?.toString().trim() ??
        '';
    if (imageUrl.isNotEmpty) {
      prefill['imageUrl'] = imageUrl;
    }

    final expiresAt = lookup['expiresAt'] ?? lookup['expirationDate'];
    if (expiresAt != null && expiresAt.toString().trim().isNotEmpty) {
      prefill['expiresAt'] = expiresAt;
    }

    final fieldSources = lookup['fieldSources'];
    if (fieldSources is Map) {
      prefill['fieldSources'] = Map<String, dynamic>.from(fieldSources);
    }
    prefill['rememberBarcode'] = true;

    return prefill;
  }

  Future<void> _openEditor({
    Map<String, dynamic>? prefill,
    Map<String, dynamic>? existingItem,
  }) async {
    final isEditing = existingItem != null;
    final value = await showModalBottomSheet<_PantryEditorValue>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _PantryEditorSheet(
        initialData: existingItem ?? prefill,
        isEditing: isEditing,
        suggestionItems: [..._items, ..._expiring, ..._expired],
      ),
    );
    if (value == null) return;

    final payload = value.toRequestMap();
    Map<String, dynamic>? result;
    try {
      if (isEditing) {
        result = await repository.updatePantryItem(
          existingItem['id'].toString(),
          payload,
        );
      } else {
        result = await repository.createPantryItem(payload);
      }
    } catch (error) {
      _showMessage(
        _errorText(
          error,
          _isRu ? 'Не удалось сохранить продукт' : 'Failed to save pantry item',
        ),
      );
      return;
    }

    if (result == null) {
      _showMessage(
        _isRu ? 'Не удалось сохранить продукт' : 'Failed to save pantry item',
      );
      return;
    }

    var imageUploaded = true;
    if (value.imageFile != null) {
      final uploaded = await repository.uploadPantryItemImage(
        result['id'].toString(),
        value.imageFile!,
      );
      if (uploaded != null) {
        result = uploaded;
      } else {
        imageUploaded = false;
      }
    }

    if (!mounted) return;
    _showMessage(
      imageUploaded
          ? (isEditing
                ? (_isRu ? 'Продукт обновлен' : 'Pantry item updated')
                : (_isRu ? 'Продукт добавлен' : 'Pantry item added'))
          : (_isRu
                ? 'Продукт сохранен, но изображение не загрузилось'
                : 'Pantry item saved, but the image upload failed'),
    );
    await _load();
  }

  Future<void> _openEditFlow(Map<String, dynamic> item) async {
    try {
      final full = await repository.getPantryItem(item['id'].toString());
      if (!mounted) return;
      await _openEditor(existingItem: full ?? item);
    } catch (error) {
      _showMessage(
        _errorText(
          error,
          _isRu
              ? 'Не удалось открыть продукт для редактирования'
              : 'Failed to open pantry item for editing',
        ),
      );
    }
  }

  Future<void> _markConsumed(Map<String, dynamic> item) async {
    try {
      final fullItem = await repository.getPantryItem(item['id'].toString());
      final source = Map<String, dynamic>.from(fullItem ?? item);
      final purchasedAt = source['purchasedAt']?.toString().trim();
      final name = source['name']?.toString().trim() ?? '';
      final category = source['category']?.toString().trim() ?? '';
      final unit = source['unit']?.toString().trim() ?? '';
      final quantity = source['quantity'];

      if (name.isEmpty ||
          category.isEmpty ||
          unit.isEmpty ||
          purchasedAt == null ||
          purchasedAt.isEmpty ||
          quantity == null) {
        _showMessage(
          _isRu
              ? 'Не удалось подготовить продукт к обновлению статуса'
              : 'Failed to prepare pantry item for status update',
        );
        return;
      }

      final payload =
          <String, dynamic>{
            'name': name,
            'brand': source['brand']?.toString().trim().isEmpty ?? true
                ? null
                : source['brand']?.toString().trim(),
            'category': category,
            'quantity': quantity,
            'unit': unit,
            'purchasedAt': purchasedAt,
            'openedAt': source['openedAt']?.toString(),
            'expiresAt': source['expiresAt']?.toString(),
            'status': 'CONSUMED',
            'imageUrl': source['imageUrl']?.toString().trim().isEmpty ?? true
                ? null
                : source['imageUrl']?.toString().trim(),
            'barcode': source['barcode']?.toString().trim().isEmpty ?? true
                ? null
                : source['barcode']?.toString().trim(),
          }..removeWhere(
            (key, value) =>
                value == null || (value is String && value.trim().isEmpty),
          );

      final updated = await repository.updatePantryItem(
        item['id'].toString(),
        payload,
      );
      if (!mounted) return;
      if (updated != null) {
        _showMessage(
          _isRu ? 'Отмечено как использованное' : 'Marked as consumed',
        );
        await _load();
      }
    } catch (error) {
      _showMessage(
        _errorText(
          error,
          _isRu
              ? 'Не удалось обновить статус продукта'
              : 'Failed to update pantry item status',
        ),
      );
    }
  }

  Future<void> _deleteItem(Map<String, dynamic> item) async {
    try {
      final ok = await repository.deletePantryItem(item['id'].toString());
      if (!mounted) return;
      if (ok) {
        _showMessage(_isRu ? 'Продукт удален' : 'Pantry item removed');
        await _load();
      }
    } catch (error) {
      _showMessage(
        _errorText(
          error,
          _isRu ? 'Не удалось удалить продукт' : 'Failed to delete pantry item',
        ),
      );
    }
  }

  Widget _buildImage(Map<String, dynamic> item) {
    final imageUrl = item['imageUrl']?.toString().trim() ?? '';
    if (imageUrl.isEmpty) {
      return Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Color.alphaBlend(
            _cs.primary.withValues(alpha: _isDark ? 0.24 : 0.12),
            _cs.surface,
          ),
        ),
        child: Icon(Icons.inventory_2_rounded, color: _cs.primary),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Image.network(
        imageUrl,
        width: 72,
        height: 72,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: Color.alphaBlend(
              _cs.primary.withValues(alpha: _isDark ? 0.24 : 0.12),
              _cs.surface,
            ),
          ),
          child: Icon(Icons.broken_image_outlined, color: _cs.primary),
        ),
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    final status = item['status']?.toString() ?? 'UNKNOWN';
    final statusColor = _statusColor(status);
    final expiresAt = item['expiresAt'];
    final brand = item['brand']?.toString().trim() ?? '';
    final category = item['category']?.toString().trim() ?? '';

    return InkWell(
      onTap: () => _openEditFlow(item),
      borderRadius: BorderRadius.circular(22),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            _cs.surfaceContainerHighest.withValues(
              alpha: _isDark ? 0.42 : 0.72,
            ),
            _cs.surface,
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _cs.outlineVariant.withValues(alpha: 0.55)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildImage(item),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['name']?.toString() ?? '-',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (brand.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(brand, style: TextStyle(color: _cs.onSurfaceVariant)),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _InfoChip(
                        icon: Icons.scale_rounded,
                        text: _quantityLabel(item),
                        color: _cs.primary,
                      ),
                      if (category.isNotEmpty)
                        _InfoChip(
                          icon: Icons.category_rounded,
                          text: category,
                          color: _cs.tertiary,
                        ),
                      if (expiresAt != null)
                        _InfoChip(
                          icon: Icons.event_busy_rounded,
                          text:
                              '${_isRu ? 'Срок' : 'Expires'}: ${_formatDate(expiresAt)}',
                          color: status == 'EXPIRED'
                              ? _cs.error
                              : _cs.secondary,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _statusLabel(status),
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'consume') {
                  _markConsumed(item);
                } else if (value == 'delete') {
                  _deleteItem(item);
                }
              },
              itemBuilder: (context) => [
                if ((item['status']?.toString() ?? '') == 'ACTIVE')
                  PopupMenuItem(
                    value: 'consume',
                    child: Text(
                      _isRu ? 'Отметить использованным' : 'Mark consumed',
                    ),
                  ),
                PopupMenuItem(
                  value: 'delete',
                  child: Text(_isRu ? 'Удалить' : 'Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _items.where((item) {
      final status = (item['status']?.toString() ?? '').toUpperCase();
      return status.isEmpty || status == 'ACTIVE';
    }).length;

    return Scaffold(
      backgroundColor: _theme.scaffoldBackgroundColor,
      appBar: AppTopBar(
        title: _screenTitle,
        actions: [
          AppTopAction(icon: Icons.refresh_rounded, onPressed: _load),
          AppTopAction(
            icon: Icons.qr_code_scanner_rounded,
            onPressed: _scanBarcodeAndOpenEditor,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateOptions,
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
              title: _isRu ? 'Домашняя\nкладовая' : 'Home\npantry',
              subtitle: _isRu
                  ? 'Следи за остатками, сроками и быстро веди продуктовый контур.'
                  : 'Track quantities, expiry dates, and keep your food flow organized.',
              gradientColors: [
                _cs.primary.withValues(alpha: 0.16),
                AppTheme.atelierLime.withValues(alpha: 0.18),
                _cs.tertiary.withValues(alpha: 0.08),
              ],
              pills: [
                AtelierStatPill(
                  icon: Icons.inventory_2_rounded,
                  label: _isRu
                      ? '$activeCount активных'
                      : '$activeCount active',
                  color: _cs.primary,
                ),
                AtelierStatPill(
                  icon: Icons.warning_amber_rounded,
                  label: _isRu
                      ? '${_expiring.length} скоро истекает'
                      : '${_expiring.length} expiring',
                  color: _cs.tertiary,
                ),
                AtelierStatPill(
                  icon: Icons.error_outline_rounded,
                  label: _isRu
                      ? '${_expired.length} просрочено'
                      : '${_expired.length} expired',
                  color: _cs.error,
                ),
              ],
            ),
            const SizedBox(height: 28),
            AtelierSectionIntro(
              eyebrow: _isRu ? 'режимы' : 'modes',
              title: _isRu ? 'Фильтр кладовой' : 'Pantry view',
              subtitle: _isRu
                  ? 'Переключайся между всеми товарами, истекающими и просроченными.'
                  : 'Switch between all items, expiring products, and expired ones.',
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _PantryListMode.values.map((mode) {
                  final selected = _mode == mode;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(_titleForMode(mode)),
                      selected: selected,
                      onSelected: (_) => setState(() => _mode = mode),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 28),
            AtelierSectionIntro(
              eyebrow: _isRu ? 'запасы' : 'inventory',
              title: _titleForMode(_mode),
              subtitle: _isRu
                  ? 'Каждый продукт читается как карточка с понятным статусом и сроком.'
                  : 'Each item reads like a clear card with visible status and expiry.',
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_visibleItems.isEmpty)
              AtelierEmptyState(
                icon: _mode == _PantryListMode.expired
                    ? Icons.sentiment_satisfied_alt_rounded
                    : Icons.inventory_2_rounded,
                title: _mode == _PantryListMode.all
                    ? (_isRu ? 'Кладовая пока пуста' : 'Pantry is empty')
                    : (_isRu ? 'Здесь пока пусто' : 'Nothing here yet'),
                subtitle: _mode == _PantryListMode.all
                    ? (_isRu
                          ? 'Добавь первый продукт вручную или через штрихкод.'
                          : 'Add the first product manually or by barcode.')
                    : (_isRu
                          ? 'В выбранном разделе пока нет продуктов.'
                          : 'There are no products in this selected section yet.'),
                accent: _cs.primary,
              )
            else
              ..._visibleItems.map(_buildItemCard),
          ],
        ),
      ),
    );
  }
}

class _PantryEditorValue {
  const _PantryEditorValue({
    required this.name,
    required this.brand,
    required this.category,
    required this.quantity,
    required this.unit,
    required this.purchasedAt,
    required this.openedAt,
    required this.expiresAt,
    required this.status,
    required this.barcode,
    required this.rememberBarcode,
    required this.remoteImageUrl,
    required this.imageFile,
  });

  final String name;
  final String brand;
  final String category;
  final String quantity;
  final String unit;
  final DateTime purchasedAt;
  final DateTime? openedAt;
  final DateTime? expiresAt;
  final String? status;
  final String barcode;
  final bool rememberBarcode;
  final String remoteImageUrl;
  final XFile? imageFile;

  Map<String, dynamic> toRequestMap() {
    String formatDate(DateTime date) =>
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    return {
      'name': name.trim(),
      'brand': brand.trim().isEmpty ? null : brand.trim(),
      'category': category.trim(),
      'quantity': double.tryParse(quantity.trim().replaceAll(',', '.')) ?? 1,
      'unit': unit,
      'purchasedAt': formatDate(purchasedAt),
      'openedAt': openedAt == null ? null : formatDate(openedAt!),
      'expiresAt': expiresAt == null ? null : formatDate(expiresAt!),
      'status': status,
      'imageUrl': remoteImageUrl.trim().isEmpty ? null : remoteImageUrl.trim(),
      'barcode': barcode.trim().isEmpty ? null : barcode.trim(),
      'rememberBarcode': rememberBarcode && barcode.trim().isNotEmpty,
    }..removeWhere((key, value) => value == null);
  }
}

class _PantryEditorSheet extends StatefulWidget {
  const _PantryEditorSheet({
    required this.initialData,
    required this.isEditing,
    required this.suggestionItems,
  });

  final Map<String, dynamic>? initialData;
  final bool isEditing;
  final List<Map<String, dynamic>> suggestionItems;

  @override
  State<_PantryEditorSheet> createState() => _PantryEditorSheetState();
}

class _PantryEditorSheetState extends State<_PantryEditorSheet> {
  final AppRepository _repository = AppRepository.instance;
  final _picker = ImagePicker();
  late final TextEditingController _nameController;
  late final TextEditingController _brandController;
  late final TextEditingController _categoryController;
  late final TextEditingController _quantityController;
  late final TextEditingController _barcodeController;

  late DateTime _purchasedAt;
  DateTime? _openedAt;
  DateTime? _expiresAt;
  late String _unit;
  String? _status;
  late String _remoteImageUrl;
  late Map<String, String> _fieldSources;
  bool _rememberBarcode = false;
  XFile? _imageFile;
  List<SmartSuggestionOption> _nameSuggestions = const [];
  List<SmartSuggestionOption> _categorySuggestions = const [];
  Timer? _nameSuggestionDebounce;
  int _activeNameSuggestionRequestId = 0;

  bool get _isRu => Localizations.localeOf(context).languageCode == 'ru';
  String _unitLabel(String raw) {
    switch (raw.trim().toUpperCase()) {
      case 'PIECE':
        return _isRu ? 'Штуки' : 'Pieces';
      case 'GRAM':
        return _isRu ? 'Граммы' : 'Grams';
      case 'KILOGRAM':
        return _isRu ? 'Килограммы' : 'Kilograms';
      case 'MILLILITER':
        return _isRu ? 'Миллилитры' : 'Milliliters';
      case 'LITER':
        return _isRu ? 'Литры' : 'Liters';
      case 'PACK':
        return _isRu ? 'Упаковки' : 'Packs';
      case 'BOTTLE':
        return _isRu ? 'Бутылки' : 'Bottles';
      case 'CAN':
        return _isRu ? 'Банки' : 'Cans';
      default:
        return raw;
    }
  }

  String _statusLabel(String raw) {
    switch (raw.trim().toUpperCase()) {
      case 'ACTIVE':
        return _isRu ? 'Активен' : 'Active';
      case 'CONSUMED':
        return _isRu ? 'Использован' : 'Consumed';
      case 'EXPIRED':
        return _isRu ? 'Просрочен' : 'Expired';
      case 'REMOVED':
        return _isRu ? 'Удален' : 'Removed';
      default:
        return raw;
    }
  }

  static const List<String> _units = [
    'PIECE',
    'GRAM',
    'KILOGRAM',
    'MILLILITER',
    'LITER',
    'PACK',
    'BOTTLE',
    'CAN',
  ];

  static const List<String> _statuses = [
    'ACTIVE',
    'CONSUMED',
    'EXPIRED',
    'REMOVED',
  ];

  @override
  void initState() {
    super.initState();
    final data = widget.initialData ?? const <String, dynamic>{};
    _nameController = TextEditingController(
      text: data['name']?.toString() ?? '',
    );
    _brandController = TextEditingController(
      text: data['brand']?.toString() ?? '',
    );
    _categoryController = TextEditingController(
      text: data['category']?.toString() ?? 'Other',
    );
    _quantityController = TextEditingController(
      text:
          data['quantity']?.toString() ??
          data['suggestedQuantity']?.toString() ??
          '1',
    );
    _barcodeController = TextEditingController(
      text: data['barcode']?.toString() ?? '',
    );
    _barcodeController.addListener(_handleBarcodeChanged);
    _purchasedAt = _parseDate(data['purchasedAt']) ?? DateTime.now();
    _openedAt = _parseDate(data['openedAt']);
    _expiresAt = _parseDate(data['expiresAt']);
    _unit =
        data['unit']?.toString() ??
        data['suggestedUnit']?.toString() ??
        'PIECE';
    _status = widget.isEditing ? data['status']?.toString() ?? 'ACTIVE' : null;
    _remoteImageUrl = data['imageUrl']?.toString() ?? '';
    _fieldSources = _extractFieldSources(data['fieldSources']);
    _rememberBarcode =
        data['rememberBarcode'] == true ||
        (_fieldSources.isNotEmpty && _barcodeController.text.trim().isNotEmpty);
  }

  @override
  void dispose() {
    _nameSuggestionDebounce?.cancel();
    _barcodeController.removeListener(_handleBarcodeChanged);
    _nameController.dispose();
    _brandController.dispose();
    _categoryController.dispose();
    _quantityController.dispose();
    _barcodeController.dispose();
    super.dispose();
  }

  void _handleBarcodeChanged() {
    final hasBarcode = _barcodeController.text.trim().isNotEmpty;
    if (!mounted) return;
    if (!hasBarcode && _rememberBarcode) {
      setState(() => _rememberBarcode = false);
      return;
    }
    setState(() {});
  }

  void _refreshNameSuggestions() {
    final query = _nameController.text;
    final candidates = SmartFoodSuggestions.collectProductSuggestions(
      isRu: _isRu,
      pantryItems: widget.suggestionItems,
    );
    setState(() {
      _nameSuggestions = SmartSuggestionMl.localVisibleSuggestions(
        candidates: candidates,
        query: query,
        limit: 6,
      );
    });

    _nameSuggestionDebounce?.cancel();
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty || candidates.isEmpty) {
      return;
    }

    final requestId = ++_activeNameSuggestionRequestId;
    _nameSuggestionDebounce = Timer(
      const Duration(milliseconds: 220),
      () async {
        final ranked = await SmartSuggestionMl.rerankSuggestions(
          query: trimmedQuery,
          candidates: candidates,
          visibleLimit: 6,
          ranker:
              ({
                required String query,
                required List<Map<String, dynamic>> candidates,
                required int limit,
              }) {
                return _repository.rerankSuggestionCandidateIds(
                  query: query,
                  candidates: candidates,
                  limit: limit,
                );
              },
        );
        if (!mounted ||
            requestId != _activeNameSuggestionRequestId ||
            _nameController.text.trim() != trimmedQuery) {
          return;
        }
        setState(() => _nameSuggestions = ranked);
      },
    );
  }

  void _refreshCategorySuggestions() {
    setState(() {
      _categorySuggestions = SmartFoodSuggestions.buildCategorySuggestions(
        query: _categoryController.text,
        isRu: _isRu,
        pantryItems: widget.suggestionItems,
        limit: 6,
      );
    });
  }

  void _applyNameSuggestion(SmartSuggestionOption option) {
    _nameSuggestionDebounce?.cancel();
    _activeNameSuggestionRequestId++;
    _nameController.text = option.primaryText;
    _nameController.selection = TextSelection.collapsed(
      offset: _nameController.text.length,
    );
    if ((option.brand ?? '').trim().isNotEmpty &&
        _brandController.text.trim().isEmpty) {
      _brandController.text = option.brand!.trim();
    }
    if ((option.category ?? '').trim().isNotEmpty) {
      _categoryController.text = option.category!.trim();
    }
    if ((option.quantity ?? '').trim().isNotEmpty &&
        (_quantityController.text.trim().isEmpty ||
            _quantityController.text.trim() == '1')) {
      _quantityController.text = option.quantity!.trim();
    }
    if ((option.pantryUnit ?? '').trim().isNotEmpty) {
      _unit = option.pantryUnit!.trim();
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _nameSuggestions = const <SmartSuggestionOption>[];
      _categorySuggestions = const <SmartSuggestionOption>[];
    });
  }

  void _applyCategorySuggestion(SmartSuggestionOption option) {
    _categoryController.text = option.primaryText;
    _categoryController.selection = TextSelection.collapsed(
      offset: _categoryController.text.length,
    );
    FocusScope.of(context).unfocus();
    setState(() {
      _categorySuggestions = const <SmartSuggestionOption>[];
    });
  }

  DateTime? _parseDate(dynamic raw) {
    final text = raw?.toString().trim() ?? '';
    if (text.isEmpty) return null;
    return DateTime.tryParse(text);
  }

  Map<String, String> _extractFieldSources(dynamic raw) {
    if (raw is! Map) return <String, String>{};
    final result = <String, String>{};
    raw.forEach((key, value) {
      final k = key.toString().trim();
      final v = value?.toString().trim() ?? '';
      if (k.isEmpty || v.isEmpty) return;
      result[k] = v;
    });
    return result;
  }

  Future<void> _pickDate({
    required DateTime initial,
    required ValueChanged<DateTime?> onChanged,
  }) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 10),
    );
    onChanged(picked);
  }

  Future<void> _pickImage(ImageSource source) async {
    final image = await _picker.pickImage(source: source, imageQuality: 85);
    if (image == null) return;
    setState(() => _imageFile = image);
  }

  String _formatDate(DateTime? date) {
    if (date == null) return _isRu ? 'Не выбрано' : 'Not selected';
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  void _showValidationMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _sourceLabel(String raw) {
    final source = raw.trim().toUpperCase();
    if (source.contains('USER_BARCODE_CACHE')) {
      return _isRu ? 'Из вашей базы barcode' : 'From your barcode cache';
    }
    if (source.contains('OPEN_FOOD_FACTS')) {
      return 'Open Food Facts';
    }
    return _isRu ? 'Автозаполнение' : 'Auto-filled';
  }

  Color _sourceColor(String raw) {
    final source = raw.trim().toUpperCase();
    if (source.contains('USER_BARCODE_CACHE')) {
      return const Color(0xFF1E8E5A);
    }
    if (source.contains('OPEN_FOOD_FACTS')) {
      return Theme.of(context).colorScheme.primary;
    }
    return Theme.of(context).colorScheme.secondary;
  }

  IconData _sourceIcon(String raw) {
    final source = raw.trim().toUpperCase();
    if (source.contains('USER_BARCODE_CACHE')) {
      return Icons.bookmark_added_rounded;
    }
    if (source.contains('OPEN_FOOD_FACTS')) {
      return Icons.travel_explore_rounded;
    }
    return Icons.auto_awesome_rounded;
  }

  Widget _buildFieldSourceChips(List<String> fields) {
    final uniqueSources = <String>{};
    for (final field in fields) {
      final source = _fieldSources[field];
      if (source != null && source.trim().isNotEmpty) {
        uniqueSources.add(source.trim());
      }
    }
    if (uniqueSources.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: uniqueSources.map((source) {
          final color = _sourceColor(source);
          return _InfoChip(
            icon: _sourceIcon(source),
            text: _sourceLabel(source),
            color: color,
          );
        }).toList(),
      ),
    );
  }

  Widget _imagePreview() {
    if (_imageFile != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.file(
          File(_imageFile!.path),
          width: double.infinity,
          height: 180,
          fit: BoxFit.cover,
        ),
      );
    }
    if (_remoteImageUrl.trim().isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.network(
          _remoteImageUrl.trim(),
          width: double.infinity,
          height: 180,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _emptyImage(),
        ),
      );
    }
    return _emptyImage();
  }

  Widget _emptyImage() {
    return Container(
      width: double.infinity,
      height: 180,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Icon(
        Icons.photo_rounded,
        size: 42,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  void _submit() {
    if (_nameController.text.trim().isEmpty ||
        _categoryController.text.trim().isEmpty ||
        _quantityController.text.trim().isEmpty) {
      _showValidationMessage(
        _isRu ? 'Заполни обязательные поля' : 'Fill in the required fields',
      );
      return;
    }

    final quantity = double.tryParse(
      _quantityController.text.trim().replaceAll(',', '.'),
    );
    if (quantity == null || quantity <= 0) {
      _showValidationMessage(
        _isRu
            ? 'Количество должно быть больше нуля'
            : 'Quantity must be greater than zero',
      );
      return;
    }

    final purchasedAt = _dateOnly(_purchasedAt);
    final openedAt = _openedAt == null ? null : _dateOnly(_openedAt!);
    final expiresAt = _expiresAt == null ? null : _dateOnly(_expiresAt!);

    if (openedAt != null && openedAt.isBefore(purchasedAt)) {
      _showValidationMessage(
        _isRu
            ? 'Дата открытия не может быть раньше даты покупки'
            : 'Opened date cannot be earlier than purchased date',
      );
      return;
    }

    if (expiresAt != null && expiresAt.isBefore(purchasedAt)) {
      _showValidationMessage(
        _isRu
            ? 'Срок годности не может быть раньше даты покупки'
            : 'Expiration date cannot be earlier than purchased date',
      );
      return;
    }

    Navigator.of(context).pop(
      _PantryEditorValue(
        name: _nameController.text,
        brand: _brandController.text,
        category: _categoryController.text,
        quantity: _quantityController.text,
        unit: _unit,
        purchasedAt: _purchasedAt,
        openedAt: _openedAt,
        expiresAt: _expiresAt,
        status: _status,
        barcode: _barcodeController.text,
        rememberBarcode: _rememberBarcode,
        remoteImageUrl: _remoteImageUrl,
        imageFile: _imageFile,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AtelierSheetFrame(
      title: widget.isEditing
          ? (_isRu ? 'Редактировать продукт' : 'Edit pantry item')
          : (_isRu ? 'Новый продукт' : 'New pantry item'),
      subtitle: _isRu
          ? 'Собери аккуратную карточку продукта для кладовой и рекомендаций.'
          : 'Build a clean pantry item card for storage and recipe recommendations.',
      onClose: () => Navigator.of(context).pop(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _imagePreview(),
          _buildFieldSourceChips(const ['imageUrl']),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(_isRu ? 'Галерея' : 'Gallery'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: Text(_isRu ? 'Камера' : 'Camera'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AtelierFieldLabel(_isRu ? 'Название' : 'Name'),
          TextFieldTapRegion(
            child: Column(
              children: [
                TextField(
                  controller: _nameController,
                  onTap: _refreshNameSuggestions,
                  onChanged: (_) => _refreshNameSuggestions(),
                  onTapOutside: (_) {
                    _nameSuggestionDebounce?.cancel();
                    _activeNameSuggestionRequestId++;
                    FocusScope.of(context).unfocus();
                    setState(
                      () => _nameSuggestions = const <SmartSuggestionOption>[],
                    );
                  },
                  decoration: InputDecoration(
                    hintText: _isRu
                        ? 'Например, греческий йогурт'
                        : 'For example, Greek yogurt',
                  ),
                ),
                if (_nameSuggestions.isNotEmpty)
                  AtelierSuggestionPanel(
                    suggestions: _nameSuggestions,
                    isRu: _isRu,
                    onSelected: _applyNameSuggestion,
                  ),
              ],
            ),
          ),
          _buildFieldSourceChips(const ['name']),
          const SizedBox(height: 12),
          AtelierFieldLabel(_isRu ? 'Бренд' : 'Brand'),
          TextField(
            controller: _brandController,
            decoration: InputDecoration(
              hintText: _isRu ? 'Например, Ферма BIO' : 'For example, Bio Farm',
            ),
          ),
          _buildFieldSourceChips(const ['brand']),
          const SizedBox(height: 12),
          AtelierFieldLabel(_isRu ? 'Категория' : 'Category'),
          TextFieldTapRegion(
            child: Column(
              children: [
                TextField(
                  controller: _categoryController,
                  onTap: _refreshCategorySuggestions,
                  onChanged: (_) => _refreshCategorySuggestions(),
                  onTapOutside: (_) {
                    FocusScope.of(context).unfocus();
                    setState(
                      () => _categorySuggestions =
                          const <SmartSuggestionOption>[],
                    );
                  },
                  decoration: InputDecoration(
                    hintText: _isRu
                        ? 'Например, молочное'
                        : 'For example, dairy',
                  ),
                ),
                if (_categorySuggestions.isNotEmpty)
                  AtelierSuggestionPanel(
                    suggestions: _categorySuggestions,
                    isRu: _isRu,
                    onSelected: _applyCategorySuggestion,
                  ),
              ],
            ),
          ),
          _buildFieldSourceChips(const ['category']),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AtelierFieldLabel(_isRu ? 'Количество' : 'Quantity'),
                    TextField(
                      controller: _quantityController,
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
                    DropdownButtonFormField<String>(
                      initialValue: _unit,
                      items: _units
                          .map(
                            (unit) => DropdownMenuItem(
                              value: unit,
                              child: Text(_unitLabel(unit)),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _unit = value ?? _unit),
                      decoration: const InputDecoration(),
                    ),
                  ],
                ),
              ),
            ],
          ),
          _buildFieldSourceChips(const ['suggestedQuantity', 'suggestedUnit']),
          const SizedBox(height: 12),
          AtelierFieldLabel(_isRu ? 'Штрихкод' : 'Barcode'),
          TextField(
            controller: _barcodeController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: '4601234567890'),
          ),
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value:
                _rememberBarcode && _barcodeController.text.trim().isNotEmpty,
            onChanged: _barcodeController.text.trim().isEmpty
                ? null
                : (value) => setState(() => _rememberBarcode = value),
            title: Text(
              _isRu
                  ? 'Запомнить товар по штрихкоду'
                  : 'Remember this product by barcode',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              _barcodeController.text.trim().isEmpty
                  ? (_isRu ? 'Сначала укажи штрихкод' : 'Add a barcode first')
                  : (_isRu
                        ? 'Сохраним этот товар в вашу отдельную barcode-базу для следующих сканов.'
                        : 'Save this product into your personal barcode cache for future scans.'),
            ),
          ),
          const SizedBox(height: 14),
          AtelierSurfaceCard(
            radius: 24,
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_isRu ? 'Дата покупки' : 'Purchased at'),
                  subtitle: Text(_formatDate(_purchasedAt)),
                  trailing: const Icon(Icons.calendar_month_rounded),
                  onTap: () => _pickDate(
                    initial: _purchasedAt,
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _purchasedAt = value);
                    },
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_isRu ? 'Открыт' : 'Opened at'),
                  subtitle: Text(_formatDate(_openedAt)),
                  trailing: const Icon(Icons.calendar_month_rounded),
                  onTap: () => _pickDate(
                    initial: _openedAt ?? _purchasedAt,
                    onChanged: (value) => setState(() => _openedAt = value),
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_isRu ? 'Срок годности' : 'Expires at'),
                  subtitle: Text(_formatDate(_expiresAt)),
                  trailing: const Icon(Icons.calendar_month_rounded),
                  onTap: () => _pickDate(
                    initial: _expiresAt ?? _purchasedAt,
                    onChanged: (value) => setState(() => _expiresAt = value),
                  ),
                ),
              ],
            ),
          ),
          _buildFieldSourceChips(const ['expiresAt']),
          if (widget.isEditing) ...[
            const SizedBox(height: 12),
            AtelierFieldLabel(_isRu ? 'Статус' : 'Status'),
            DropdownButtonFormField<String>(
              initialValue: _status,
              items: _statuses
                  .map(
                    (status) => DropdownMenuItem(
                      value: status,
                      child: Text(_statusLabel(status)),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _status = value),
              decoration: const InputDecoration(),
            ),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.save_rounded),
              label: Text(_isRu ? 'Сохранить' : 'Save'),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
