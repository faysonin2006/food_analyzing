part of 'api_service.dart';

extension ApiServiceRecipesMethods on ApiService {
  Future<List<RecipeSummary>> searchRecipesUnified({
    String? diet,
    String? title,
    String? category,
    String lang = 'ru',
    int page = 1,
    int size = 20,
  }) async {
    final pageResult = await searchRecipesPage(
      lang: lang,
      page: page,
      size: size,
      title: title,
      category: category,
      diet: diet,
    );
    return pageResult.items;
  }

  Future<RecipeSearchPageResult> searchRecipesPage({
    String? diet,
    String? title,
    String? category,
    String lang = 'ru',
    int page = 1,
    int size = 20,
  }) async {
    final dbRaw = await _searchDbRecipesPageRaw(
      lang: lang,
      title: title,
      category: category,
      requiredDietKeys: _dietListForDb(diet),
      page: page,
      size: size,
    );

    final items = dbRaw.items
        .map(RecipeSummary.fromDb)
        .where((e) => e.id > 0 && e.title.trim().isNotEmpty)
        .toList();

    final hasNext = dbRaw.hasNext ?? items.isNotEmpty;
    return RecipeSearchPageResult(
      items: items,
      hasNext: hasNext,
      page: page < 1 ? 1 : page,
      totalPages: dbRaw.totalPages,
    );
  }

  Future<RecipeDetails?> getRecipeDetails({
    required int recipeId,
    RecipeSummary? seedSummary,
  }) async {
    final cacheKey = '${ApiService._kCacheRecipeDetailsPrefix}$recipeId';

    Future<RecipeDetails?> readFromCache() async {
      final cached = await _readCacheMap(
        cacheKey,
        maxAge: ApiService._recipeDetailsCacheTtl,
      );
      if (cached == null) return null;
      return _mergeSeedIntoDetails(RecipeDetails.fromDb(cached), seedSummary);
    }

    if (!NetworkMonitor.instance.isOnline) {
      return readFromCache();
    }

    try {
      final candidates = [
        Uri.parse('${ApiService.baseUrl}/api/recipes/db/$recipeId'),
        Uri.parse('${ApiService.baseUrl}/api/recipes/db/search/$recipeId'),
      ];

      for (final url in candidates) {
        final response = await _getWithAuth(url);
        if (response.statusCode != 200) continue;

        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          await _writeCacheJson(cacheKey, data);
          return _mergeSeedIntoDetails(RecipeDetails.fromDb(data), seedSummary);
        }
        if (data is Map) {
          final map = Map<String, dynamic>.from(data);
          await _writeCacheJson(cacheKey, map);
          return _mergeSeedIntoDetails(RecipeDetails.fromDb(map), seedSummary);
        }
      }

      return readFromCache();
    } catch (e) {
      print('getRecipeDetails error: $e');
      return readFromCache();
    }
  }

  Future<List<String>> rerankSuggestionCandidateIds({
    required String query,
    required List<Map<String, dynamic>> candidates,
    int limit = 8,
  }) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty || candidates.isEmpty) {
      return const <String>[];
    }

    if (!NetworkMonitor.instance.isOnline) {
      return const <String>[];
    }

    final payload = <String, dynamic>{
      'query': normalizedQuery,
      'limit': limit,
      'candidates': candidates,
    };

    try {
      final url = Uri.parse(
        '${ApiService.baseUrl}/api/recipes/db/suggestions/rerank',
      );
      final response = await _postWithAuth(url, body: jsonEncode(payload));
      if (response.statusCode != 200) {
        return const <String>[];
      }

      final decoded = jsonDecode(response.body);
      final items = decoded is Map<String, dynamic> ? decoded['items'] : null;
      if (items is! List) {
        return const <String>[];
      }

      return items
          .whereType<Map>()
          .map((entry) => entry['id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList(growable: false);
    } catch (error) {
      print('rerankSuggestionCandidateIds error: $error');
      return const <String>[];
    }
  }

  RecipeDetails _mergeSeedIntoDetails(RecipeDetails base, RecipeSummary? seed) {
    if (seed == null) return base;

    final title = base.title.trim().isEmpty ? seed.title : base.title;
    final image = (base.image ?? '').trim().isEmpty ? seed.image : base.image;
    final category = (base.category ?? '').trim().isEmpty
        ? seed.category
        : base.category;
    final times = _isTimesEmpty(base.times) && seed.readyInMinutes != null
        ? RecipeTimes(totalTime: '${seed.readyInMinutes} min')
        : base.times;
    final nutritions = base.nutritions.isEmpty
        ? _seedNutritions(seed)
        : base.nutritions;

    return base.copyWith(
      title: title,
      image: image,
      category: category,
      times: times,
      nutritions: nutritions,
    );
  }

  bool _isTimesEmpty(RecipeTimes t) {
    final prep = (t.prepTime ?? '').trim();
    final cook = (t.cookTime ?? '').trim();
    final total = (t.totalTime ?? '').trim();
    return prep.isEmpty && cook.isEmpty && total.isEmpty;
  }

  List<NutritionItem> _seedNutritions(RecipeSummary s) {
    final out = <NutritionItem>[];
    if (s.calories != null) {
      out.add(
        NutritionItem(
          nutrient: 'Calories',
          amount: s.calories!.toStringAsFixed(0),
          unit: ' kcal',
        ),
      );
    }
    if (s.protein != null) {
      out.add(
        NutritionItem(
          nutrient: 'Protein',
          amount: s.protein!.toStringAsFixed(1),
          unit: ' g',
        ),
      );
    }
    if (s.fat != null) {
      out.add(
        NutritionItem(
          nutrient: 'Fats',
          amount: s.fat!.toStringAsFixed(1),
          unit: ' g',
        ),
      );
    }
    if (s.carbs != null) {
      out.add(
        NutritionItem(
          nutrient: 'Carbs',
          amount: s.carbs!.toStringAsFixed(1),
          unit: ' g',
        ),
      );
    }
    return out;
  }

  String _normalizeLangForBackend(String lang) {
    final v = lang.trim().toUpperCase();
    return v == 'RU' ? 'RU' : 'EN';
  }

  Future<_RecipeRawPageResult> _searchDbRecipesPageRaw({
    required String lang,
    String? title,
    String? category,
    List<String>? requiredDietKeys,
    int page = 1,
    int size = 20,
  }) async {
    final normalizedTitle = title?.trim();
    final normalizedCategory = category?.trim();
    final searchTokens = <String>{
      ..._buildRecipeSearchTokens(normalizedTitle),
      ..._buildRecipeSearchTokens(normalizedCategory),
    }.toList(growable: false);

    final payload = <String, dynamic>{
      'lang': _normalizeLangForBackend(lang),
      'requiredDietKeys': requiredDietKeys ?? <String>[],
      'preferredHealthKeys': <String>[],
      'allergyKeys': <String>[],
      'healthConditionKeys': <String>[],
      'page': page,
      'size': size,
      'sortBy': searchTokens.isEmpty ? 'recipe_id' : 'search_score',
      'sortDir': 'desc',
    };
    if (normalizedTitle != null && normalizedTitle.isNotEmpty) {
      payload['title'] = normalizedTitle;
    }
    if (normalizedCategory != null && normalizedCategory.isNotEmpty) {
      payload['category'] = normalizedCategory;
    }
    if (searchTokens.isNotEmpty) {
      payload['includeIngredients'] = searchTokens;
    }
    final cacheKey = _cacheKeyFromPayload(
      ApiService._kCacheRecipeSearchPrefix,
      payload,
    );

    _RecipeRawPageResult mapToResult(dynamic decoded) {
      final items = _extractRecipeList(decoded);
      final meta = _extractPageMeta(
        decoded,
        requestedPage: page,
        requestedSize: size,
      );
      return _RecipeRawPageResult(
        items: items,
        hasNext: meta.hasNext,
        totalPages: meta.totalPages,
      );
    }

    Future<_RecipeRawPageResult?> readFromCache() async {
      final cached = await _readCacheString(
        cacheKey,
        maxAge: ApiService._recipeSearchCacheTtl,
      );
      if (cached == null) return null;
      try {
        final decoded = jsonDecode(cached);
        return mapToResult(decoded);
      } catch (_) {
        return null;
      }
    }

    if (!NetworkMonitor.instance.isOnline) {
      return await readFromCache() ?? const _RecipeRawPageResult(items: []);
    }

    try {
      final postUrl = Uri.parse('${ApiService.baseUrl}/api/recipes/db/search');
      final postResponse = await _postWithAuth(
        postUrl,
        body: jsonEncode(payload),
      );

      if (postResponse.statusCode == 200) {
        await _writeCacheString(cacheKey, postResponse.body);
        return mapToResult(jsonDecode(postResponse.body));
      }

      final qp = <String, String>{
        'lang': _normalizeLangForBackend(lang),
        'page': page.toString(),
        'size': size.toString(),
        if ((normalizedTitle ?? '').isNotEmpty) 'title': normalizedTitle!,
        if ((normalizedCategory ?? '').isNotEmpty)
          'category': normalizedCategory!,
        if ((requiredDietKeys ?? []).isNotEmpty)
          'requiredDietKeys': requiredDietKeys!.join(','),
      };

      final getUrl = Uri.parse(
        '${ApiService.baseUrl}/api/recipes/db/search',
      ).replace(queryParameters: qp);
      final getResponse = await _getWithAuth(getUrl);
      if (getResponse.statusCode == 200) {
        await _writeCacheString(cacheKey, getResponse.body);
        return mapToResult(jsonDecode(getResponse.body));
      }
    } catch (e) {
      print('_searchDbRecipesPageRaw error: $e');
    }

    final cached = await readFromCache();
    if (cached != null) return cached;
    return const _RecipeRawPageResult(items: []);
  }

  _RecipePageMeta _extractPageMeta(
    dynamic decoded, {
    required int requestedPage,
    required int requestedSize,
  }) {
    if (decoded is! Map<String, dynamic>) {
      return const _RecipePageMeta();
    }

    int? toInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value.toString().trim());
    }

    bool? toBool(dynamic value) {
      if (value == null) return null;
      if (value is bool) return value;
      final v = value.toString().trim().toLowerCase();
      if (v == 'true' || v == '1') return true;
      if (v == 'false' || v == '0') return false;
      return null;
    }

    final totalPages =
        toInt(decoded['totalPages']) ??
        toInt(decoded['pages']) ??
        toInt(decoded['pageCount']);

    bool? hasNext = toBool(decoded['hasNext']);

    if (hasNext == null) {
      final last = toBool(decoded['last']);
      if (last != null) hasNext = !last;
    }

    final topLevelNumber = toInt(decoded['number']);
    if (hasNext == null &&
        topLevelNumber != null &&
        totalPages != null &&
        totalPages > 0) {
      final oneBasedPage = topLevelNumber + 1;
      hasNext = oneBasedPage < totalPages;
    }

    final totalElements =
        toInt(decoded['totalElements']) ??
        toInt(decoded['totalCount']) ??
        toInt(decoded['total_count']);
    if (hasNext == null && totalElements != null && requestedSize > 0) {
      hasNext = requestedPage * requestedSize < totalElements;
    }

    final pageMap = decoded['pageable'];
    if (hasNext == null && pageMap is Map) {
      final map = Map<String, dynamic>.from(pageMap);
      final zeroBasedPage = toInt(map['pageNumber']);
      final nestedSize = toInt(map['pageSize']) ?? requestedSize;
      if (totalElements != null && zeroBasedPage != null && nestedSize > 0) {
        final oneBasedPage = zeroBasedPage + 1;
        hasNext = oneBasedPage * nestedSize < totalElements;
      }
    }

    return _RecipePageMeta(hasNext: hasNext, totalPages: totalPages);
  }

  List<Map<String, dynamic>> _extractRecipeList(dynamic decoded) {
    if (decoded is List) {
      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    if (decoded is Map<String, dynamic>) {
      for (final key in ['content', 'results', 'data', 'items', 'recipes']) {
        final v = decoded[key];
        if (v is List) {
          return v
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
        if (v is Map<String, dynamic>) {
          final nested = _extractRecipeList(v);
          if (nested.isNotEmpty) return nested;
        }
      }

      for (final v in decoded.values) {
        if (v is List) {
          final list = v
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          if (list.isNotEmpty) return list;
        }
        if (v is Map<String, dynamic>) {
          final nested = _extractRecipeList(v);
          if (nested.isNotEmpty) return nested;
        }
      }

      return [decoded];
    }

    return [];
  }

  String? _dietToDbConstraint(String? diet) {
    if (diet == null || diet.trim().isEmpty) return null;

    switch (diet.trim().toLowerCase()) {
      case 'vegan':
        return 'VEGAN';
      case 'vegetarian':
        return 'VEGETARIAN';
      case 'gluten free':
        return 'GLUTEN_FREE';
      case 'ketogenic':
        return 'KETO';
      case 'paleo':
        return 'PALEO';
      default:
        return null;
    }
  }

  List<String> _dietListForDb(String? diet) {
    final v = _dietToDbConstraint(diet);
    return v == null ? <String>[] : <String>[v];
  }

  List<String> _buildRecipeSearchTokens(String? raw) {
    final text = raw?.trim() ?? '';
    if (text.isEmpty) return const <String>[];
    final seen = <String>{};
    final tokens = <String>[];
    for (final part
        in text
            .toLowerCase()
            .replaceAll(RegExp(r'[^\p{L}\p{Nd}\s]', unicode: true), ' ')
            .split(RegExp(r'\s+'))) {
      final token = part.trim();
      if (token.length < 3 || !seen.add(token)) continue;
      tokens.add(token);
    }
    return tokens;
  }
}
