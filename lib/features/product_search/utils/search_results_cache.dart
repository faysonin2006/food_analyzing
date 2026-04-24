/// Утилита для кэширования результатов поиска в памяти.
///
/// Хранит результаты поиска с временными метками и автоматически
/// удаляет устаревшие записи (TTL 5 минут).
class SearchResultsCache {
  /// Создает экземпляр SearchResultsCache.
  SearchResultsCache();

  final Map<String, CachedSearchResult> _cache = {};

  /// Время жизни кэшированных результатов (5 минут).
  static const Duration _ttl = Duration(minutes: 5);

  /// Получает кэшированные результаты для указанного запроса.
  ///
  /// Возвращает `null`, если результаты не найдены или истек срок их действия.
  ///
  /// [query] - поисковый запрос.
  CachedSearchResult? get(String query) {
    final cached = _cache[query];
    
    if (cached == null) {
      return null;
    }
    
    if (cached.isExpired) {
      _cache.remove(query);
      return null;
    }
    
    return cached;
  }

  /// Сохраняет результаты поиска в кэш.
  ///
  /// [query] - поисковый запрос.
  /// [results] - список результатов поиска.
  void put(String query, List<Map<String, dynamic>> results) {
    _cache[query] = CachedSearchResult(
      results: results,
      timestamp: DateTime.now(),
    );
  }

  /// Очищает весь кэш.
  void clear() {
    _cache.clear();
  }

  /// Удаляет все устаревшие записи из кэша.
  ///
  /// Полезно для периодической очистки памяти.
  void removeExpired() {
    _cache.removeWhere((_, cached) => cached.isExpired);
  }
}

/// Кэшированный результат поиска с временной меткой.
class CachedSearchResult {
  /// Создает экземпляр CachedSearchResult.
  ///
  /// [results] - список результатов поиска.
  /// [timestamp] - время создания кэша.
  CachedSearchResult({
    required this.results,
    required this.timestamp,
  });

  /// Список результатов поиска.
  final List<Map<String, dynamic>> results;

  /// Время создания кэша.
  final DateTime timestamp;

  /// Проверяет, истек ли срок действия кэша.
  ///
  /// Возвращает `true`, если прошло больше 5 минут с момента создания.
  bool get isExpired =>
      DateTime.now().difference(timestamp) > const Duration(minutes: 5);
}
