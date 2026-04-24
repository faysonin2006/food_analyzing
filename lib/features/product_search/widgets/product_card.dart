import 'package:flutter/material.dart';
import '../models/product_item.dart';

/// Виджет карточки продукта для отображения в результатах поиска
class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    required this.onTap,
  });

  final ProductItem product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Semantics(
      label: _buildSemanticLabel(),
      button: true,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Изображение продукта (88x88px, скругленное)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: _buildProductImage(),
                ),
                const SizedBox(width: 12),
                // Информация о продукте
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Название и иконка добавления
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Название продукта
                                Text(
                                  product.productName,
                                  style: theme.textTheme.titleMedium,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                // Бренд
                                if (product.brandName != null &&
                                    product.brandName!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      product.brandName!,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          // Иконка добавления в правом верхнем углу
                          IconButton(
                            icon: Icon(
                              Icons.add_circle_outline,
                              color: colorScheme.primary,
                            ),
                            onPressed: onTap,
                            tooltip: 'Добавить продукт',
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Калорийность и макронутриенты
                      _buildNutritionInfo(theme, colorScheme),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Строит изображение продукта
  Widget _buildProductImage() {
    if (product.imageUrl != null && product.imageUrl!.isNotEmpty) {
      return Image.network(
        product.imageUrl!,
        width: 88,
        height: 88,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholderImage(),
      );
    }
    return _buildPlaceholderImage();
  }

  /// Строит placeholder для изображения
  Widget _buildPlaceholderImage() {
    return Container(
      width: 88,
      height: 88,
      color: Colors.grey[200],
      child: Icon(
        Icons.fastfood_outlined,
        size: 40,
        color: Colors.grey[400],
      ),
    );
  }

  /// Строит информацию о питательной ценности
  Widget _buildNutritionInfo(ThemeData theme, ColorScheme colorScheme) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        // Калорийность
        if (product.caloriesKcal100g != null)
          _buildNutritionChip(
            label: '${product.caloriesKcal100g!.toStringAsFixed(0)} ккал',
            theme: theme,
            colorScheme: colorScheme,
          ),
        // Белки
        if (product.proteins100g != null)
          _buildNutritionChip(
            label: 'Б: ${product.proteins100g!.toStringAsFixed(1)}г',
            theme: theme,
            colorScheme: colorScheme,
          ),
        // Жиры
        if (product.fats100g != null)
          _buildNutritionChip(
            label: 'Ж: ${product.fats100g!.toStringAsFixed(1)}г',
            theme: theme,
            colorScheme: colorScheme,
          ),
        // Углеводы
        if (product.carbohydrates100g != null)
          _buildNutritionChip(
            label: 'У: ${product.carbohydrates100g!.toStringAsFixed(1)}г',
            theme: theme,
            colorScheme: colorScheme,
          ),
      ],
    );
  }

  /// Строит компактную плитку с информацией о макронутриенте
  Widget _buildNutritionChip({
    required String label,
    required ThemeData theme,
    required ColorScheme colorScheme,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
      ),
    );
  }

  /// Строит семантическую метку для программ чтения с экрана
  String _buildSemanticLabel() {
    final buffer = StringBuffer();
    buffer.write('Продукт: ${product.productName}');

    if (product.brandName != null && product.brandName!.isNotEmpty) {
      buffer.write(', бренд: ${product.brandName}');
    }

    if (product.caloriesKcal100g != null) {
      buffer.write(
        ', калорийность: ${product.caloriesKcal100g!.toStringAsFixed(0)} килокалорий на 100 грамм',
      );
    }

    if (product.proteins100g != null) {
      buffer.write(', белки: ${product.proteins100g!.toStringAsFixed(1)} грамм');
    }

    if (product.fats100g != null) {
      buffer.write(', жиры: ${product.fats100g!.toStringAsFixed(1)} грамм');
    }

    if (product.carbohydrates100g != null) {
      buffer.write(
        ', углеводы: ${product.carbohydrates100g!.toStringAsFixed(1)} грамм',
      );
    }

    return buffer.toString();
  }
}
