import 'package:flutter/material.dart';
import '../models/product_item.dart';
import 'product_card.dart';

/// Виджет списка результатов поиска продуктов
class SearchResultsList extends StatelessWidget {
  const SearchResultsList({
    super.key,
    required this.items,
    required this.onItemTap,
    required this.isLoading,
  });

  final List<ProductItem> items;
  final Function(ProductItem item) onItemTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    // Показываем индикатор загрузки
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    // Показываем EmptyStateView если нет результатов
    if (items.isEmpty) {
      return const _EmptyStateView();
    }

    // Отображаем список результатов
    return ListView.builder(
      itemCount: items.length,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemBuilder: (context, index) {
        final product = items[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ProductCard(
            product: product,
            onTap: () => onItemTap(product),
          ),
        );
      },
    );
  }
}

/// Виджет пустого состояния когда нет результатов поиска
class _EmptyStateView extends StatelessWidget {
  const _EmptyStateView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Иконка
            Icon(
              Icons.search_off_rounded,
              size: 80,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24),
            // Заголовок
            Text(
              'Продукты не найдены',
              style: theme.textTheme.titleLarge?.copyWith(
                color: colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            // Подсказка
            Text(
              'Попробуйте изменить запрос, отсканировать штрихкод или создать свой продукт',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
