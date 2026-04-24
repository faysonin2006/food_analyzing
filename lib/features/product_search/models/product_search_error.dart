/// Типы ошибок, которые могут возникнуть при поиске продуктов
enum ProductSearchError {
  /// Ошибка сети при выполнении запроса
  networkError,
  
  /// Поиск не вернул результатов
  emptyResults,
  
  /// Невалидный поисковый запрос
  invalidQuery,
  
  /// Продукт не найден по штрихкоду
  barcodeNotFound,
  
  /// Ошибка при работе со сканером штрихкода
  scannerError,
  
  /// Ошибка при работе с кэшем
  cacheError,
}

/// Исключение, возникающее при ошибках поиска продуктов
class ProductSearchException implements Exception {
  const ProductSearchException({
    required this.error,
    required this.message,
    this.details,
  });

  /// Тип ошибки
  final ProductSearchError error;
  
  /// Сообщение об ошибке
  final String message;
  
  /// Дополнительные детали ошибки (опционально)
  final String? details;

  @override
  String toString() => 'ProductSearchException: $message${details != null ? ' ($details)' : ''}';
}
