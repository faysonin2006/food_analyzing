import 'product_item.dart';

/// Модель результата поиска продуктов
class ProductSearchResult {
  const ProductSearchResult({
    required this.items,
    required this.page,
    required this.hasNext,
    required this.total,
  });

  final List<ProductItem> items;
  final int page;
  final bool hasNext;
  final int total;

  factory ProductSearchResult.fromJson(Map<String, dynamic> json) {
    return ProductSearchResult(
      items: (json['items'] as List?)
              ?.map((item) => ProductItem.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      page: json['page'] as int? ?? 1,
      hasNext: json['hasNext'] as bool? ?? false,
      total: json['total'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'items': items.map((item) => item.toJson()).toList(),
      'page': page,
      'hasNext': hasNext,
      'total': total,
    };
  }
}
