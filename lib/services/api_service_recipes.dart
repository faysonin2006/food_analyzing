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

  Future<RecipeComment> addRecipeComment({
    required int recipeId,
    required String text,
    int? parentCommentId,
  }) async {
    final trimmedText = text.trim();
    if (trimmedText.isEmpty) {
      throw const ApiException(message: 'Comment text must not be empty');
    }
    if (!NetworkMonitor.instance.isOnline) {
      throw const ApiException(
        message: 'Connect to the internet to post a comment',
      );
    }

    final url = Uri.parse(
      '${ApiService.baseUrl}/api/recipes/db/$recipeId/comments',
    );
    final response = _ensureSuccess(
      await _postWithAuth(
        url,
        body: jsonEncode({
          'text': trimmedText,
          if (parentCommentId != null) 'parentCommentId': parentCommentId,
        }),
      ),
      fallbackMessage: 'Failed to post comment',
      successCodes: const {200, 201},
    );
    final decoded = _decodeJsonBody(response.body);
    final map = _asMap(decoded);
    if (map == null) {
      throw const ApiException(message: 'Failed to parse posted comment');
    }

    final comment = RecipeComment.fromDynamic(map);
    await _appendRecipeCommentToCache(recipeId, comment);
    return comment;
  }

  Future<RecipeComment> setRecipeCommentLike({
    required int recipeId,
    required int commentId,
    required bool liked,
  }) async {
    if (!NetworkMonitor.instance.isOnline) {
      throw const ApiException(
        message: 'Connect to the internet to update comment like',
      );
    }

    final url = Uri.parse(
      '${ApiService.baseUrl}/api/recipes/db/comments/$commentId/like',
    );
    final response = liked
        ? _ensureSuccess(
            await _postWithAuth(url),
            fallbackMessage: 'Failed to like comment',
          )
        : _ensureSuccess(
            await _deleteWithAuth(url),
            fallbackMessage: 'Failed to unlike comment',
          );

    final decoded = _decodeJsonBody(response.body);
    final map = _asMap(decoded);
    if (map == null) {
      throw const ApiException(message: 'Failed to parse updated comment');
    }

    final comment = RecipeComment.fromDynamic(map);
    await _updateRecipeCommentInCache(recipeId, comment);
    return comment;
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

  Future<void> _appendRecipeCommentToCache(
    int recipeId,
    RecipeComment comment,
  ) async {
    final cacheKey = '${ApiService._kCacheRecipeDetailsPrefix}$recipeId';
    final cached = await _readCacheMap(cacheKey);
    if (cached == null) return;

    final comments = _asMapList(cached['comments'])
        .map((item) => RecipeComment.fromDynamic(item))
        .where((item) => item.body.trim().isNotEmpty)
        .toList(growable: true);
    cached['comments'] = _appendCommentToTree(
      comments,
      comment,
    ).map((item) => item.toJson()).toList();
    await _writeCacheJson(cacheKey, cached);
  }

  Future<void> _updateRecipeCommentInCache(
    int recipeId,
    RecipeComment updatedComment,
  ) async {
    final cacheKey = '${ApiService._kCacheRecipeDetailsPrefix}$recipeId';
    final cached = await _readCacheMap(cacheKey);
    if (cached == null) return;

    final comments = _asMapList(cached['comments'])
        .map((item) => RecipeComment.fromDynamic(item))
        .where((item) => item.body.trim().isNotEmpty)
        .toList(growable: false);
    cached['comments'] = _updateCommentInTree(
      comments,
      updatedComment,
    ).map((item) => item.toJson()).toList();
    await _writeCacheJson(cacheKey, cached);
  }

  List<RecipeComment> _appendCommentToTree(
    List<RecipeComment> comments,
    RecipeComment newComment,
  ) {
    if (newComment.parentCommentId == null) {
      final next =
          comments
              .where((item) => item.id != newComment.id)
              .toList(growable: true)
            ..add(newComment);
      return next;
    }

    return comments
        .map((item) {
          if (item.id != newComment.parentCommentId) {
            return item;
          }
          final replies =
              item.replies
                  .where((reply) => reply.id != newComment.id)
                  .toList(growable: true)
                ..add(newComment);
          return item.copyWith(replies: replies, replyCount: replies.length);
        })
        .toList(growable: false);
  }

  List<RecipeComment> _updateCommentInTree(
    List<RecipeComment> comments,
    RecipeComment updatedComment,
  ) {
    return comments
        .map((item) {
          if (item.id == updatedComment.id) {
            return item.copyWith(
              parentCommentId: updatedComment.parentCommentId,
              authorName: updatedComment.authorName,
              body: updatedComment.body,
              createdAt: updatedComment.createdAt,
              likeCount: updatedComment.likeCount,
              likedByMe: updatedComment.likedByMe,
              replyCount: item.replies.isNotEmpty
                  ? item.replies.length
                  : updatedComment.replyCount,
            );
          }
          if (item.replies.isEmpty) {
            return item;
          }
          final updatedReplies = _updateCommentInTree(
            item.replies,
            updatedComment,
          );
          return item.copyWith(
            replies: updatedReplies,
            replyCount: updatedReplies.length,
          );
        })
        .toList(growable: false);
  }

  String? _normalizeLangForBackend(String? lang) {
    final v = (lang ?? '').trim().toUpperCase();
    if (v == 'RU') return 'RU';
    if (v == 'EN') return 'EN';
    return null;
  }

  String? _detectRecipeSearchLang(
    String? uiLang, {
    String? title,
    String? category,
  }) {
    // Keep recipe language aligned with the current UI locale.
    // Russian interface => Russian recipes, English interface => English recipes.
    return _normalizeLangForBackend(uiLang);
  }







///ПОИСК
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
    final effectiveLang = _detectRecipeSearchLang(
      lang,
      title: normalizedTitle,
      category: normalizedCategory,
    );
    final searchTokens = <String>{
      ..._buildRecipeSearchTokens(normalizedTitle),
      ..._buildRecipeSearchTokens(normalizedCategory),
    }.toList(growable: false);

    final payload = <String, dynamic>{
      'requiredDietKeys': requiredDietKeys ?? <String>[],
      'preferredHealthKeys': <String>[],
      'allergyKeys': <String>[],
      'healthConditionKeys': <String>[],
      'page': page,
      'size': size,
      'sortBy': searchTokens.isEmpty ? 'recipe_id' : 'search_score',
      'sortDir': 'desc',
    };
    if (effectiveLang != null) {
      payload['lang'] = effectiveLang;
    }
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
        'page': page.toString(),
        'size': size.toString(),
        if ((normalizedTitle ?? '').isNotEmpty) 'title': normalizedTitle!,
        if ((normalizedCategory ?? '').isNotEmpty)
          'category': normalizedCategory!,
        if ((requiredDietKeys ?? []).isNotEmpty)
          'requiredDietKeys': requiredDietKeys!.join(','),
      };
      if (effectiveLang != null) {
        qp['lang'] = effectiveLang;
      }

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
