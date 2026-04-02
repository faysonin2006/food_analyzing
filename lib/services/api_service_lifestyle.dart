part of 'api_service.dart';

extension ApiServiceLifestyleMethods on ApiService {
  Future<List<Map<String, dynamic>>> getPantryItems() async {
    final url = Uri.parse('${ApiService.baseUrl}/api/pantry');
    final response = _ensureSuccess(
      await _getWithAuth(url),
      fallbackMessage: 'Failed to load pantry items',
    );
    return _asMapList(_decodeJsonBody(response.body));
  }

  Future<List<Map<String, dynamic>>> getExpiringPantryItems() async {
    final url = Uri.parse('${ApiService.baseUrl}/api/pantry/expiring-soon');
    final response = _ensureSuccess(
      await _getWithAuth(url),
      fallbackMessage: 'Failed to load expiring pantry items',
    );
    return _asMapList(_decodeJsonBody(response.body));
  }

  Future<List<Map<String, dynamic>>> getExpiredPantryItems() async {
    final url = Uri.parse('${ApiService.baseUrl}/api/pantry/expired');
    final response = _ensureSuccess(
      await _getWithAuth(url),
      fallbackMessage: 'Failed to load expired pantry items',
    );
    return _asMapList(_decodeJsonBody(response.body));
  }

  Future<Map<String, dynamic>?> getPantryItem(String pantryItemId) async {
    final url = Uri.parse('${ApiService.baseUrl}/api/pantry/$pantryItemId');
    final response = _ensureSuccess(
      await _getWithAuth(url),
      fallbackMessage: 'Failed to load pantry item',
    );
    return _asMap(_decodeJsonBody(response.body));
  }

  Future<Map<String, dynamic>?> createPantryItem(
    Map<String, dynamic> data,
  ) async {
    final url = Uri.parse('${ApiService.baseUrl}/api/pantry');
    final response = _ensureSuccess(
      await _postWithAuth(url, body: jsonEncode(data)),
      fallbackMessage: 'Failed to create pantry item',
      successCodes: const {200, 201},
    );
    return _asMap(_decodeJsonBody(response.body));
  }

  Future<Map<String, dynamic>?> updatePantryItem(
    String pantryItemId,
    Map<String, dynamic> data,
  ) async {
    final url = Uri.parse('${ApiService.baseUrl}/api/pantry/$pantryItemId');
    final response = _ensureSuccess(
      await _putWithAuth(url, body: jsonEncode(data)),
      fallbackMessage: 'Failed to update pantry item',
    );
    return _asMap(_decodeJsonBody(response.body));
  }

  Future<bool> deletePantryItem(String pantryItemId) async {
    final url = Uri.parse('${ApiService.baseUrl}/api/pantry/$pantryItemId');
    _ensureSuccess(
      await _deleteWithAuth(url),
      fallbackMessage: 'Failed to delete pantry item',
      successCodes: const {200, 204},
    );
    return true;
  }

  Future<Map<String, dynamic>?> uploadPantryItemImage(
    String pantryItemId,
    XFile imageFile,
  ) async {
    final ext = imageFile.path.split('.').last.toLowerCase();
    final filename = ext.isNotEmpty ? 'pantry.$ext' : 'pantry.jpg';
    final mediaType = switch (ext) {
      'png' => MediaType('image', 'png'),
      'webp' => MediaType('image', 'webp'),
      'heic' => MediaType('image', 'heic'),
      _ => MediaType('image', 'jpeg'),
    };
    final url = Uri.parse(
      '${ApiService.baseUrl}/api/pantry/$pantryItemId/image',
    );

    Future<http.StreamedResponse> sendOnce() async {
      final request = http.MultipartRequest('POST', url);
      request.headers.addAll(await _getHeaders(multipart: true));
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          imageFile.path,
          filename: filename,
          contentType: mediaType,
        ),
      );
      return request.send();
    }

    try {
      var response = await sendOnce();
      if (response.statusCode == 401 || response.statusCode == 403) {
        final refreshed = await _refreshToken();
        if (refreshed) {
          response = await sendOnce();
        } else {
          await logout();
          return null;
        }
      }

      final body = await response.stream.bytesToString();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return _asMap(jsonDecode(body));
      }
    } catch (e) {
      print('uploadPantryItemImage error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> lookupPantryBarcode(String barcode) async {
    final url = Uri.parse('${ApiService.baseUrl}/api/pantry/barcode/$barcode');
    Map<String, dynamic>? backendLookup;
    try {
      final response = await _getWithAuth(url);
      if (response.statusCode != 404) {
        _ensureSuccess(
          response,
          fallbackMessage: 'Failed to lookup pantry barcode',
        );
        backendLookup = _asMap(_decodeJsonBody(response.body));
      }
    } on ApiException catch (error) {
      if (error.statusCode == 400) {
        rethrow;
      }
    } catch (_) {
      // Public barcode lookup can still continue via Open Food Facts.
    }

    if (!_needsPantryBarcodeEnrichment(backendLookup)) {
      return backendLookup;
    }

    final externalLookup = await _lookupPantryBarcodeFromOpenFoodFacts(barcode);
    if (backendLookup == null) return externalLookup;
    if (externalLookup == null) return backendLookup;
    return _mergePantryBarcodeLookups(
      primary: backendLookup,
      fallback: externalLookup,
    );
  }

  bool _needsPantryBarcodeEnrichment(Map<String, dynamic>? lookup) {
    if (lookup == null) return true;
    return !_hasNonBlankText(lookup['name']) ||
        !_hasNonBlankText(lookup['category']) ||
        lookup['suggestedQuantity'] == null ||
        !_hasNonBlankText(lookup['suggestedUnit']) ||
        !_hasNonBlankText(lookup['imageUrl']);
  }

  Future<Map<String, dynamic>?> _lookupPantryBarcodeFromOpenFoodFacts(
    String barcode,
  ) async {
    final requests = <Uri>[
      Uri.https('world.openfoodfacts.org', '/api/v2/product/$barcode.json', {
        'fields':
            'code,product_name,brands,categories,categories_tags,image_front_url,product_quantity,product_quantity_unit,quantity,expiration_date',
        'lc': 'en',
      }),
      Uri.https('world.openfoodfacts.org', '/api/v0/product/$barcode.json'),
    ];

    for (final uri in requests) {
      try {
        final response = await http
            .get(uri, headers: const {'User-Agent': 'FoodAnalyzing/1.0'})
            .timeout(const Duration(seconds: 6));
        if (response.statusCode == 404) return null;
        if (response.statusCode < 200 || response.statusCode >= 300) {
          continue;
        }

        final decoded = _asMap(_decodeJsonBody(response.body));
        if (decoded == null) {
          continue;
        }
        final status = _asInt(decoded['status']);
        if (status != 1) {
          continue;
        }

        final product = _asMap(decoded['product']);
        if (product == null) {
          continue;
        }

        final name = _asTrimmedString(product['product_name']);
        if (name == null) {
          continue;
        }

        final quantity = _resolveOpenFoodFactsQuantity(product);
        return {
          'barcode':
              _asTrimmedString(product['code']) ??
              _asTrimmedString(decoded['code']) ??
              barcode,
          'name': name,
          if (_asTrimmedString(product['brands']) != null)
            'brand': _asTrimmedString(product['brands']),
          'category': _resolveOpenFoodFactsCategory(product) ?? 'Other',
          if (_asTrimmedString(product['image_front_url']) != null)
            'imageUrl': _asTrimmedString(product['image_front_url']),
          if (quantity.$1 != null) 'suggestedQuantity': quantity.$1,
          if (quantity.$2 != null) 'suggestedUnit': quantity.$2,
          if (_asTrimmedString(product['quantity']) != null)
            'rawQuantity': _asTrimmedString(product['quantity']),
          if (_resolveOpenFoodFactsExpirationDate(product['expiration_date']) !=
              null)
            'expiresAt': _resolveOpenFoodFactsExpirationDate(
              product['expiration_date'],
            ),
          'source': 'OPEN_FOOD_FACTS_DIRECT',
          'fieldSources': {
            'name': 'OPEN_FOOD_FACTS',
            if (_asTrimmedString(product['brands']) != null)
              'brand': 'OPEN_FOOD_FACTS',
            'category': 'OPEN_FOOD_FACTS',
            if (_asTrimmedString(product['image_front_url']) != null)
              'imageUrl': 'OPEN_FOOD_FACTS',
            if (quantity.$1 != null) 'suggestedQuantity': 'OPEN_FOOD_FACTS',
            if (quantity.$2 != null) 'suggestedUnit': 'OPEN_FOOD_FACTS',
            if (_asTrimmedString(product['quantity']) != null)
              'rawQuantity': 'OPEN_FOOD_FACTS',
            if (_resolveOpenFoodFactsExpirationDate(
                  product['expiration_date'],
                ) !=
                null)
              'expiresAt': 'OPEN_FOOD_FACTS',
          },
        };
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  Map<String, dynamic> _mergePantryBarcodeLookups({
    required Map<String, dynamic> primary,
    required Map<String, dynamic> fallback,
  }) {
    return {
      'barcode':
          _asTrimmedString(primary['barcode']) ??
          _asTrimmedString(fallback['barcode']),
      'name':
          _asTrimmedString(primary['name']) ??
          _asTrimmedString(fallback['name']),
      'brand':
          _asTrimmedString(primary['brand']) ??
          _asTrimmedString(fallback['brand']),
      'category':
          _asTrimmedString(primary['category']) ??
          _asTrimmedString(fallback['category']),
      'suggestedQuantity':
          primary['suggestedQuantity'] ?? fallback['suggestedQuantity'],
      'suggestedUnit':
          _asTrimmedString(primary['suggestedUnit']) ??
          _asTrimmedString(fallback['suggestedUnit']),
      'rawQuantity':
          _asTrimmedString(primary['rawQuantity']) ??
          _asTrimmedString(fallback['rawQuantity']),
      'expiresAt':
          _asTrimmedString(primary['expiresAt']) ??
          _asTrimmedString(fallback['expiresAt']),
      'source':
          _asTrimmedString(primary['source']) ??
          _asTrimmedString(fallback['source']) ??
          'OPEN_FOOD_FACTS_DIRECT',
      if (_mergeFieldSources(primary, fallback).isNotEmpty)
        'fieldSources': _mergeFieldSources(primary, fallback),
      if (primary.containsKey('imageUrl') || fallback.containsKey('imageUrl'))
        'imageUrl':
            _asTrimmedString(primary['imageUrl']) ??
            _asTrimmedString(fallback['imageUrl']),
    }..removeWhere((key, value) => value == null);
  }

  Map<String, dynamic> _mergeFieldSources(
    Map<String, dynamic> primary,
    Map<String, dynamic> fallback,
  ) {
    final primarySources = _asMap(primary['fieldSources']) ?? const {};
    final fallbackSources = _asMap(fallback['fieldSources']) ?? const {};
    const fields = <String>[
      'name',
      'brand',
      'category',
      'imageUrl',
      'suggestedQuantity',
      'suggestedUnit',
      'rawQuantity',
      'expiresAt',
    ];
    final merged = <String, dynamic>{};
    for (final field in fields) {
      if (_hasNonBlankText(primary[field]) || primary[field] != null) {
        final source =
            _asTrimmedString(primarySources[field]) ??
            _asTrimmedString(primary['source']);
        if (source != null) merged[field] = source;
        continue;
      }
      if (_hasNonBlankText(fallback[field]) || fallback[field] != null) {
        final source =
            _asTrimmedString(fallbackSources[field]) ??
            _asTrimmedString(fallback['source']);
        if (source != null) merged[field] = source;
      }
    }
    return merged;
  }

  (num?, String?) _resolveOpenFoodFactsQuantity(Map<String, dynamic> product) {
    final directQuantity = _asNum(product['product_quantity']);
    final directMapped = _mapOpenFoodFactsQuantityAndUnit(
      directQuantity,
      product['product_quantity_unit'],
    );
    if (directMapped.$1 != null &&
        directMapped.$1! > 0 &&
        directMapped.$2 != null) {
      return directMapped;
    }

    final rawQuantity = _asTrimmedString(product['quantity']);
    if (rawQuantity == null) return (null, null);
    final match = RegExp(
      r'(\d+(?:[.,]\d+)?)\s*([A-Za-zА-Яа-я]+)',
    ).firstMatch(rawQuantity.toLowerCase());
    if (match == null) return (null, null);
    final amount = num.tryParse(match.group(1)!.replaceAll(',', '.'));
    final mapped = _mapOpenFoodFactsQuantityAndUnit(amount, match.group(2));
    if (mapped.$1 == null || mapped.$1! <= 0 || mapped.$2 == null) {
      return (null, null);
    }
    return mapped;
  }

  String? _resolveOpenFoodFactsCategory(Map<String, dynamic> product) {
    final categories = _asTrimmedString(product['categories']);
    if (categories != null) {
      final first = categories
          .split(',')
          .map((item) => item.trim())
          .firstWhere((item) => item.isNotEmpty, orElse: () => '');
      if (first.isNotEmpty) return first;
    }

    final tags = product['categories_tags'];
    if (tags is List) {
      for (final raw in tags) {
        final tag = _asTrimmedString(raw);
        if (tag == null || !tag.startsWith('en:')) continue;
        final words = tag
            .substring(3)
            .replaceAll('-', ' ')
            .split(RegExp(r'\s+'))
            .where((item) => item.isNotEmpty)
            .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
            .toList();
        if (words.isNotEmpty) return words.join(' ');
      }
    }

    return null;
  }

  String? _resolveOpenFoodFactsExpirationDate(dynamic rawValue) {
    final text = _asTrimmedString(rawValue);
    if (text == null) return null;

    DateTime? tryParseParts(int year, int month, int day) {
      try {
        return DateTime(year, month, day);
      } catch (_) {
        return null;
      }
    }

    final directParsers = <DateTime? Function()>[
      () => DateTime.tryParse(text),
      () {
        if (!RegExp(r'^\d{8}$').hasMatch(text)) return null;
        final year = int.parse(text.substring(0, 4));
        final month = int.parse(text.substring(4, 6));
        final day = int.parse(text.substring(6, 8));
        return tryParseParts(year, month, day);
      },
      () {
        final match = RegExp(
          r'^(\d{4})[./](\d{1,2})[./](\d{1,2})$',
        ).firstMatch(text);
        if (match == null) return null;
        return tryParseParts(
          int.parse(match.group(1)!),
          int.parse(match.group(2)!),
          int.parse(match.group(3)!),
        );
      },
      () {
        final match = RegExp(
          r'^(\d{1,2})[.-](\d{1,2})[.-](\d{4})$',
        ).firstMatch(text);
        if (match == null) return null;
        final first = int.parse(match.group(1)!);
        final second = int.parse(match.group(2)!);
        final year = int.parse(match.group(3)!);
        if (first > 12 && second <= 12) {
          return tryParseParts(year, second, first);
        }
        if (second > 12 && first <= 12) {
          return tryParseParts(year, first, second);
        }
        return null;
      },
    ];

    for (final parser in directParsers) {
      final parsed = parser();
      if (parsed == null) continue;
      final normalized = DateTime(parsed.year, parsed.month, parsed.day);
      final y = normalized.year.toString().padLeft(4, '0');
      final m = normalized.month.toString().padLeft(2, '0');
      final d = normalized.day.toString().padLeft(2, '0');
      return '$y-$m-$d';
    }
    return null;
  }

  (num?, String?) _mapOpenFoodFactsQuantityAndUnit(
    num? amount,
    dynamic rawUnit,
  ) {
    if (amount == null) return (null, null);
    final unit = _asTrimmedString(rawUnit)?.toLowerCase();
    return switch (unit) {
      'g' || 'gram' || 'grams' => (amount, 'GRAM'),
      'kg' || 'kilogram' || 'kilograms' => (amount, 'KILOGRAM'),
      'ml' || 'milliliter' || 'milliliters' => (amount, 'MILLILITER'),
      'cl' || 'centiliter' || 'centiliters' => (amount * 10, 'MILLILITER'),
      'dl' || 'deciliter' || 'deciliters' => (amount * 100, 'MILLILITER'),
      'l' || 'liter' || 'liters' || 'litre' || 'litres' => (amount, 'LITER'),
      'pc' ||
      'pcs' ||
      'piece' ||
      'pieces' ||
      'unit' ||
      'units' => (amount, 'PIECE'),
      'pack' || 'packs' => (amount, 'PACK'),
      'bottle' || 'bottles' => (amount, 'BOTTLE'),
      'can' || 'cans' => (amount, 'CAN'),
      _ => (null, null),
    };
  }

  String? _asTrimmedString(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  bool _hasNonBlankText(dynamic value) => _asTrimmedString(value) != null;

  int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString().trim());
  }

  num? _asNum(dynamic value) {
    if (value == null) return null;
    if (value is num) return value;
    return num.tryParse(value.toString().trim().replaceAll(',', '.'));
  }

  Future<List<Map<String, dynamic>>> getMeals({
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    final query = <String, String>{};
    if (dateFrom != null) query['dateFrom'] = _formatDateOnly(dateFrom);
    if (dateTo != null) query['dateTo'] = _formatDateOnly(dateTo);
    final url = Uri.parse(
      '${ApiService.baseUrl}/api/meals',
    ).replace(queryParameters: query.isEmpty ? null : query);
    try {
      final response = await _getWithAuth(url);
      if (response.statusCode == 200) {
        return _asMapList(jsonDecode(response.body));
      }
    } catch (e) {
      print('getMeals error: $e');
    }
    return const [];
  }

  Future<Map<String, dynamic>?> createMeal(Map<String, dynamic> data) async {
    final url = Uri.parse('${ApiService.baseUrl}/api/meals');
    try {
      final response = await _postWithAuth(url, body: jsonEncode(data));
      if (response.statusCode == 200 || response.statusCode == 201) {
        return _asMap(jsonDecode(response.body));
      }
    } catch (e) {
      print('createMeal error: $e');
    }
    return null;
  }

  Future<bool> deleteMeal(String mealEntryId) async {
    final url = Uri.parse('${ApiService.baseUrl}/api/meals/$mealEntryId');
    try {
      final response = await _deleteWithAuth(url);
      return response.statusCode == 204 || response.statusCode == 200;
    } catch (e) {
      print('deleteMeal error: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> saveFoodAnalysis(
    String analysisId, {
    required Map<String, dynamic> data,
  }) async {
    final url = Uri.parse(
      '${ApiService.baseUrl}/api/food/analyze/$analysisId/save',
    );
    try {
      final response = await _postWithAuth(url, body: jsonEncode(data));
      if (response.statusCode == 200) {
        return _asMap(jsonDecode(response.body));
      }
    } catch (e) {
      print('saveFoodAnalysis error: $e');
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getShoppingItems() async {
    final url = Uri.parse('${ApiService.baseUrl}/api/shopping-lists/items');
    try {
      final response = await _getWithAuth(url);
      if (response.statusCode == 200) {
        return _asMapList(jsonDecode(response.body));
      }
    } catch (e) {
      print('getShoppingItems error: $e');
    }
    return const [];
  }

  Future<Map<String, dynamic>?> createShoppingItem(
    Map<String, dynamic> data,
  ) async {
    final url = Uri.parse('${ApiService.baseUrl}/api/shopping-lists/items');
    try {
      final response = await _postWithAuth(url, body: jsonEncode(data));
      if (response.statusCode == 200 || response.statusCode == 201) {
        return _asMap(jsonDecode(response.body));
      }
    } catch (e) {
      print('createShoppingItem error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> toggleShoppingItem(String itemId) async {
    final url = Uri.parse(
      '${ApiService.baseUrl}/api/shopping-lists/items/$itemId/check',
    );
    try {
      final response = await _patchWithAuth(url);
      if (response.statusCode == 200) {
        return _asMap(jsonDecode(response.body));
      }
    } catch (e) {
      print('toggleShoppingItem error: $e');
    }
    return null;
  }

  Future<bool> deleteShoppingItem(String itemId) async {
    final url = Uri.parse(
      '${ApiService.baseUrl}/api/shopping-lists/items/$itemId',
    );
    try {
      final response = await _deleteWithAuth(url);
      return response.statusCode == 204 || response.statusCode == 200;
    } catch (e) {
      print('deleteShoppingItem error: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> getDailyAnalytics({DateTime? date}) async {
    final url = Uri.parse('${ApiService.baseUrl}/api/analytics/daily').replace(
      queryParameters: date == null ? null : {'date': _formatDateOnly(date)},
    );
    try {
      final response = await _getWithAuth(url);
      if (response.statusCode == 200) {
        return _asMap(jsonDecode(response.body));
      }
    } catch (e) {
      print('getDailyAnalytics error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> getWeeklyAnalytics({
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    final query = <String, String>{};
    if (dateFrom != null) query['dateFrom'] = _formatDateOnly(dateFrom);
    if (dateTo != null) query['dateTo'] = _formatDateOnly(dateTo);
    final url = Uri.parse(
      '${ApiService.baseUrl}/api/analytics/weekly',
    ).replace(queryParameters: query.isEmpty ? null : query);
    try {
      final response = await _getWithAuth(url);
      if (response.statusCode == 200) {
        return _asMap(jsonDecode(response.body));
      }
    } catch (e) {
      print('getWeeklyAnalytics error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> getMacroSummary({
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    final query = <String, String>{};
    if (dateFrom != null) query['dateFrom'] = _formatDateOnly(dateFrom);
    if (dateTo != null) query['dateTo'] = _formatDateOnly(dateTo);
    final url = Uri.parse(
      '${ApiService.baseUrl}/api/analytics/macros',
    ).replace(queryParameters: query.isEmpty ? null : query);
    try {
      final response = await _getWithAuth(url);
      if (response.statusCode == 200) {
        return _asMap(jsonDecode(response.body));
      }
    } catch (e) {
      print('getMacroSummary error: $e');
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getRecommendedRecipes({
    int size = 6,
    String sortBy = 'match',
    String lang = 'ru',
  }) async {
    final url = Uri.parse('${ApiService.baseUrl}/api/recipes/recommendations');
    final payload = {
      'size': size,
      'sortBy': sortBy,
      'lang': _normalizeLangForBackend(lang),
    };
    final response = _ensureSuccess(
      await _postWithAuth(url, body: jsonEncode(payload)),
      fallbackMessage: 'Failed to load pantry recommendations',
    );
    final decoded = _decodeJsonBody(response.body);
    final map = _asMap(decoded);
    if (map == null) return const [];
    return _asMapList(map['recipes']);
  }

  Future<Map<String, dynamic>?> addMissingIngredientsToShoppingList(
    int recipeId,
  ) async {
    final url = Uri.parse(
      '${ApiService.baseUrl}/api/recipes/$recipeId/shopping-list',
    );
    try {
      final response = await _postWithAuth(url);
      if (response.statusCode == 200) {
        return _asMap(jsonDecode(response.body));
      }
    } catch (e) {
      print('addMissingIngredientsToShoppingList error: $e');
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getHouseholds() async {
    final url = Uri.parse('${ApiService.baseUrl}/api/households/me');
    final response = _ensureSuccess(
      await _getWithAuth(url),
      fallbackMessage: 'Failed to load households',
    );
    return _asMapList(_decodeJsonBody(response.body));
  }

  Future<Map<String, dynamic>?> createHousehold(String name) async {
    final url = Uri.parse('${ApiService.baseUrl}/api/households');
    final response = _ensureSuccess(
      await _postWithAuth(url, body: jsonEncode({'name': name.trim()})),
      fallbackMessage: 'Failed to create household',
      successCodes: const {200, 201},
    );
    return _asMap(_decodeJsonBody(response.body));
  }

  Future<Map<String, dynamic>?> getHouseholdDetail(String householdId) async {
    final url = Uri.parse('${ApiService.baseUrl}/api/households/$householdId');
    final response = _ensureSuccess(
      await _getWithAuth(url),
      fallbackMessage: 'Failed to load household details',
    );
    return _asMap(_decodeJsonBody(response.body));
  }

  Future<List<Map<String, dynamic>>> getMyHouseholdInvitations() async {
    final url = Uri.parse(
      '${ApiService.baseUrl}/api/households/invitations/me',
    );
    final response = _ensureSuccess(
      await _getWithAuth(url),
      fallbackMessage: 'Failed to load household invitations',
    );
    return _asMapList(_decodeJsonBody(response.body));
  }

  Future<Map<String, dynamic>?> createHouseholdInvitation(
    String householdId,
    String email,
  ) async {
    final url = Uri.parse(
      '${ApiService.baseUrl}/api/households/$householdId/invitations',
    );
    final response = _ensureSuccess(
      await _postWithAuth(url, body: jsonEncode({'email': email.trim()})),
      fallbackMessage: 'Failed to send household invitation',
      successCodes: const {200, 201},
    );
    return _asMap(_decodeJsonBody(response.body));
  }

  Future<Map<String, dynamic>?> acceptHouseholdInvitation(
    String invitationId,
  ) async {
    final url = Uri.parse(
      '${ApiService.baseUrl}/api/households/invitations/$invitationId/accept',
    );
    final response = _ensureSuccess(
      await _postWithAuth(url),
      fallbackMessage: 'Failed to accept household invitation',
    );
    return _asMap(_decodeJsonBody(response.body));
  }

  Future<Map<String, dynamic>?> declineHouseholdInvitation(
    String invitationId,
  ) async {
    final url = Uri.parse(
      '${ApiService.baseUrl}/api/households/invitations/$invitationId/decline',
    );
    final response = _ensureSuccess(
      await _postWithAuth(url),
      fallbackMessage: 'Failed to decline household invitation',
    );
    return _asMap(_decodeJsonBody(response.body));
  }

  Future<List<Map<String, dynamic>>> getHouseholdShoppingItems(
    String householdId,
  ) async {
    final url = Uri.parse(
      '${ApiService.baseUrl}/api/households/$householdId/shopping-items',
    );
    final response = _ensureSuccess(
      await _getWithAuth(url),
      fallbackMessage: 'Failed to load household shopping items',
    );
    return _asMapList(_decodeJsonBody(response.body));
  }

  Future<Map<String, dynamic>?> createHouseholdShoppingItem(
    String householdId,
    Map<String, dynamic> data,
  ) async {
    final url = Uri.parse(
      '${ApiService.baseUrl}/api/households/$householdId/shopping-items',
    );
    final response = _ensureSuccess(
      await _postWithAuth(url, body: jsonEncode(data)),
      fallbackMessage: 'Failed to add household shopping item',
      successCodes: const {200, 201},
    );
    return _asMap(_decodeJsonBody(response.body));
  }

  Future<Map<String, dynamic>?> toggleHouseholdShoppingItem(
    String householdId,
    String itemId,
  ) async {
    final url = Uri.parse(
      '${ApiService.baseUrl}/api/households/$householdId/shopping-items/$itemId/check',
    );
    final response = _ensureSuccess(
      await _patchWithAuth(url),
      fallbackMessage: 'Failed to update household shopping item',
    );
    return _asMap(_decodeJsonBody(response.body));
  }

  Future<bool> deleteHouseholdShoppingItem(
    String householdId,
    String itemId,
  ) async {
    final url = Uri.parse(
      '${ApiService.baseUrl}/api/households/$householdId/shopping-items/$itemId',
    );
    _ensureSuccess(
      await _deleteWithAuth(url),
      fallbackMessage: 'Failed to delete household shopping item',
      successCodes: const {200, 204},
    );
    return true;
  }

  Future<List<Map<String, dynamic>>> getHouseholdMessages(
    String householdId,
  ) async {
    final url = Uri.parse(
      '${ApiService.baseUrl}/api/households/$householdId/messages',
    );
    final response = _ensureSuccess(
      await _getWithAuth(url),
      fallbackMessage: 'Failed to load household messages',
    );
    return _asMapList(_decodeJsonBody(response.body));
  }

  Future<Map<String, dynamic>?> createHouseholdMessage(
    String householdId,
    String message,
  ) async {
    final url = Uri.parse(
      '${ApiService.baseUrl}/api/households/$householdId/messages',
    );
    final response = _ensureSuccess(
      await _postWithAuth(url, body: jsonEncode({'message': message.trim()})),
      fallbackMessage: 'Failed to send household message',
      successCodes: const {200, 201},
    );
    return _asMap(_decodeJsonBody(response.body));
  }

  String _formatDateOnly(DateTime value) {
    final y = value.year.toString().padLeft(4, '0');
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
