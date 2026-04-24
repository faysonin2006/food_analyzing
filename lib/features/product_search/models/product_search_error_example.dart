// ignore_for_file: avoid_print

import 'product_search_error.dart';

/// Примеры использования ProductSearchError и ProductSearchException
void main() {
  print('=== Примеры использования ProductSearchError и ProductSearchException ===\n');

  // Пример 1: Ошибка сети
  print('Пример 1: Ошибка сети');
  try {
    throw const ProductSearchException(
      error: ProductSearchError.networkError,
      message: 'Не удалось подключиться к серверу',
      details: 'Timeout after 30 seconds',
    );
  } catch (e) {
    print('Поймано исключение: $e\n');
  }

  // Пример 2: Пустые результаты
  print('Пример 2: Пустые результаты');
  try {
    throw const ProductSearchException(
      error: ProductSearchError.emptyResults,
      message: 'По вашему запросу ничего не найдено',
    );
  } catch (e) {
    print('Поймано исключение: $e\n');
  }

  // Пример 3: Невалидный запрос
  print('Пример 3: Невалидный запрос');
  try {
    throw const ProductSearchException(
      error: ProductSearchError.invalidQuery,
      message: 'Запрос слишком короткий',
      details: 'Минимальная длина: 3 символа',
    );
  } catch (e) {
    print('Поймано исключение: $e\n');
  }

  // Пример 4: Штрихкод не найден
  print('Пример 4: Штрихкод не найден');
  try {
    throw const ProductSearchException(
      error: ProductSearchError.barcodeNotFound,
      message: 'Продукт с таким штрихкодом не найден',
      details: 'Barcode: 1234567890123',
    );
  } catch (e) {
    print('Поймано исключение: $e\n');
  }

  // Пример 5: Ошибка сканера
  print('Пример 5: Ошибка сканера');
  try {
    throw const ProductSearchException(
      error: ProductSearchError.scannerError,
      message: 'Не удалось инициализировать сканер штрихкода',
      details: 'Camera permission denied',
    );
  } catch (e) {
    print('Поймано исключение: $e\n');
  }

  // Пример 6: Ошибка кэша
  print('Пример 6: Ошибка кэша');
  try {
    throw const ProductSearchException(
      error: ProductSearchError.cacheError,
      message: 'Не удалось сохранить результаты в кэш',
      details: 'Cache is full',
    );
  } catch (e) {
    print('Поймано исключение: $e\n');
  }

  // Пример 7: Обработка разных типов ошибок
  print('Пример 7: Обработка разных типов ошибок');
  final exception = const ProductSearchException(
    error: ProductSearchError.networkError,
    message: 'Ошибка сети',
  );

  switch (exception.error) {
    case ProductSearchError.networkError:
      print('Обработка ошибки сети: ${exception.message}');
      break;
    case ProductSearchError.emptyResults:
      print('Обработка пустых результатов: ${exception.message}');
      break;
    case ProductSearchError.invalidQuery:
      print('Обработка невалидного запроса: ${exception.message}');
      break;
    case ProductSearchError.barcodeNotFound:
      print('Обработка отсутствующего штрихкода: ${exception.message}');
      break;
    case ProductSearchError.scannerError:
      print('Обработка ошибки сканера: ${exception.message}');
      break;
    case ProductSearchError.cacheError:
      print('Обработка ошибки кэша: ${exception.message}');
      break;
  }
}
