import 'smart_food_suggestions.dart';

typedef SuggestionRanker =
    Future<List<String>> Function({
      required String query,
      required List<Map<String, dynamic>> candidates,
      required int limit,
    });

class SmartSuggestionMl {
  SmartSuggestionMl._();

  static List<SmartSuggestionOption> localVisibleSuggestions({
    required List<SmartSuggestionOption> candidates,
    required String query,
    required int limit,
  }) {
    return SmartFoodSuggestions.rankSuggestions(
      candidates,
      query: query,
      limit: limit,
    );
  }

  static Future<List<SmartSuggestionOption>> rerankSuggestions({
    required String query,
    required List<SmartSuggestionOption> candidates,
    required SuggestionRanker ranker,
    int visibleLimit = 8,
    int remotePoolLimit = 24,
  }) async {
    final trimmedQuery = query.trim();
    final localPool = SmartFoodSuggestions.rankSuggestions(
      candidates,
      query: trimmedQuery,
      limit: remotePoolLimit,
    );
    if (trimmedQuery.isEmpty || localPool.isEmpty) {
      return localPool.take(visibleLimit).toList(growable: false);
    }

    final indexed = <String, SmartSuggestionOption>{};
    final payload = <Map<String, dynamic>>[];
    for (var index = 0; index < localPool.length; index++) {
      final id = index.toString();
      indexed[id] = localPool[index];
      payload.add(localPool[index].toMlPayload(id));
    }

    final rankedIds = await ranker(
      query: trimmedQuery,
      candidates: payload,
      limit: localPool.length,
    );

    if (rankedIds.isEmpty) {
      return localPool.take(visibleLimit).toList(growable: false);
    }

    final ordered = <SmartSuggestionOption>[];
    final seen = <String>{};
    for (final id in rankedIds) {
      final option = indexed[id];
      if (option == null || !seen.add(id)) continue;
      ordered.add(option);
    }
    for (var index = 0; index < localPool.length; index++) {
      final id = index.toString();
      if (!seen.add(id)) continue;
      ordered.add(localPool[index]);
    }

    return ordered.take(visibleLimit).toList(growable: false);
  }
}
