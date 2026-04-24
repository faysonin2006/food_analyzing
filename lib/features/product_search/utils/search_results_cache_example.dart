import 'search_results_cache.dart';

/// Пример использования SearchResultsCache.
///
/// Демонстрирует основные сценарии работы с кэшем результатов поиска.
void main() {
  // Создание экземпляра кэша
  final cache = SearchResultsCache();

  // Пример 1: Сохранение результатов поиска
  print('=== Пример 1: Сохранение результатов ===');
  final query1 = 'яблоко';
  final results1 = [
    {
      'id': '1',
      'productName': 'Яблоко Гренни Смит',
      'caloriesKcal100g': 52.0,
    },
    {
      'id': '2',
      'productName': 'Яблоко Фуджи',
      'caloriesKcal100g': 63.0,
    },
  ];

  cache.put(query1, results1);
  print('Сохранено ${results1.length} результатов для запроса "$query1"');

  // Пример 2: Получение кэшированных результатов
  print('\n=== Пример 2: Получение кэшированных результатов ===');
  final cached = cache.get(query1);
  if (cached != null) {
    print('Найдено ${cached.results.length} кэшированных результатов');
    print('Время создания кэша: ${cached.timestamp}');
    print('Кэш истек: ${cached.isExpired}');
  }

  // Пример 3: Проверка отсутствующего запроса
  print('\n=== Пример 3: Проверка отсутствующего запроса ===');
  final notFound = cache.get('несуществующий запрос');
  print('Результат для несуществующего запроса: $notFound');

  // Пример 4: Сохранение нескольких запросов
  print('\n=== Пример 4: Сохранение нескольких запросов ===');
  cache.put('банан', [
    {'id': '3', 'productName': 'Банан', 'caloriesKcal100g': 89.0}
  ]);
  cache.put('апельсин', [
    {'id': '4', 'productName': 'Апельсин', 'caloriesKcal100g': 47.0}
  ]);
  print('Сохранено несколько запросов в кэш');

  // Пример 5: Перезапись существующего запроса
  print('\n=== Пример 5: Перезапись существующего запроса ===');
  final newResults = [
    {
      'id': '5',
      'productName': 'Яблоко Голден',
      'caloriesKcal100g': 57.0,
    },
  ];
  cache.put(query1, newResults);
  final updated = cache.get(query1);
  print('Обновлено результатов: ${updated?.results.length}');

  // Пример 6: Удаление устаревших записей
  print('\n=== Пример 6: Удаление устаревших записей ===');
  cache.removeExpired();
  print('Устаревшие записи удалены');

  // Пример 7: Очистка всего кэша
  print('\n=== Пример 7: Очистка всего кэша ===');
  cache.clear();
  print('Кэш полностью очищен');
  print('Результат после очистки: ${cache.get(query1)}');

  // Пример 8: Использование в реальном сценарии поиска
  print('\n=== Пример 8: Реальный сценарий поиска ===');
  final searchCache = SearchResultsCache();

  // Функция имитации поиска в базе данных
  Future<List<Map<String, dynamic>>> searchDatabase(String query) async {
    print('  Выполняется поиск в базе данных для "$query"...');
    await Future.delayed(const Duration(milliseconds: 100));
    return [
      {'id': '1', 'productName': 'Результат для $query'}
    ];
  }

  // Функция поиска с кэшированием
  Future<List<Map<String, dynamic>>> searchWithCache(String query) async {
    // Проверяем кэш
    final cached = searchCache.get(query);
    if (cached != null && !cached.isExpired) {
      print('  ✓ Результаты получены из кэша');
      return cached.results;
    }

    // Выполняем поиск в базе данных
    final results = await searchDatabase(query);

    // Сохраняем в кэш
    searchCache.put(query, results);
    print('  ✓ Результаты сохранены в кэш');

    return results;
  }

  // Первый поиск (из базы данных)
  searchWithCache('молоко').then((results) {
    print('  Получено результатов: ${results.length}');

    // Второй поиск того же запроса (из кэша)
    return searchWithCache('молоко');
  }).then((results) {
    print('  Получено результатов: ${results.length}');
  });
}
