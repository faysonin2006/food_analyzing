import 'package:flutter/material.dart';

import '../models/product_search_context.dart';
import 'unified_product_search_screen.dart';

/// Пример использования UnifiedProductSearchScreen
///
/// Этот файл демонстрирует, как использовать унифицированный
/// интерфейс поиска продуктов в различных разделах приложения.
class UnifiedProductSearchScreenExample extends StatelessWidget {
  const UnifiedProductSearchScreenExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Примеры использования поиска'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Пример 1: Поиск для съеденных продуктов
          _ExampleCard(
            title: 'Съеденные продукты',
            description: 'Открыть поиск для добавления съеденного продукта',
            onTap: () => _openSearch(
              context,
              ProductSearchContext.consumed,
              'Поиск съеденного продукта',
            ),
          ),
          const SizedBox(height: 12),

          // Пример 2: Поиск для кладовой
          _ExampleCard(
            title: 'Кладовая',
            description: 'Открыть поиск для добавления продукта в кладовую',
            onTap: () => _openSearch(
              context,
              ProductSearchContext.pantry,
              'Поиск продукта для кладовой',
            ),
          ),
          const SizedBox(height: 12),

          // Пример 3: Поиск для покупок
          _ExampleCard(
            title: 'Покупки',
            description: 'Открыть поиск для добавления продукта в список покупок',
            onTap: () => _openSearch(
              context,
              ProductSearchContext.shopping,
              'Поиск продукта для покупок',
            ),
          ),
          const SizedBox(height: 12),

          // Пример 4: Поиск для семьи
          _ExampleCard(
            title: 'Семья',
            description: 'Открыть поиск для отправки продукта семье',
            onTap: () => _openSearch(
              context,
              ProductSearchContext.family,
              'Поиск продукта для семьи',
            ),
          ),
          const SizedBox(height: 12),

          // Пример 5: Поиск с начальным запросом
          _ExampleCard(
            title: 'Поиск с начальным запросом',
            description: 'Открыть поиск с предзаполненным запросом "молоко"',
            onTap: () => _openSearchWithQuery(
              context,
              ProductSearchContext.consumed,
              'молоко',
            ),
          ),
        ],
      ),
    );
  }

  /// Открыть экран поиска продуктов
  Future<void> _openSearch(
    BuildContext context,
    ProductSearchContext searchContext,
    String title,
  ) async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => UnifiedProductSearchScreen(
          context: searchContext,
          onProductSelected: (product) {
            // Обработка выбора продукта
            debugPrint('Выбран продукт: ${product['productName']}');
          },
        ),
      ),
    );

    if (result != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Выбран продукт: ${result['productName']}'),
        ),
      );
    }
  }

  /// Открыть экран поиска с начальным запросом
  Future<void> _openSearchWithQuery(
    BuildContext context,
    ProductSearchContext searchContext,
    String initialQuery,
  ) async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => UnifiedProductSearchScreen(
          context: searchContext,
          initialQuery: initialQuery,
          onProductSelected: (product) {
            debugPrint('Выбран продукт: ${product['productName']}');
          },
        ),
      ),
    );

    if (result != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Выбран продукт: ${result['productName']}'),
        ),
      );
    }
  }
}

/// Карточка примера использования
class _ExampleCard extends StatelessWidget {
  const _ExampleCard({
    required this.title,
    required this.description,
    required this.onTap,
  });

  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
