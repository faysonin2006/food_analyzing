import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import '../screens/recipe_models.dart';

class RecipeSearchPageResult {
  final List<RecipeSummary> items;
  final bool hasNext;
  final int page;
  final int? totalPages;

  const RecipeSearchPageResult({
    required this.items,
    required this.hasNext,
    required this.page,
    this.totalPages,
  });
}

class _RecipeRawPageResult {
  final List<Map<String, dynamic>> items;
  final bool? hasNext;
  final int? totalPages;

  const _RecipeRawPageResult({
    required this.items,
    this.hasNext,
    this.totalPages,
  });
}

class _RecipePageMeta {
  final bool? hasNext;
  final int? totalPages;

  const _RecipePageMeta({this.hasNext, this.totalPages});
}

class ApiService {
  static const String baseUrl =
      'http://192.168.10'
      '.119:8090';
  // static const String baseUrl =
  //     'http://172.20.10'
  //     '.7:8090';

  final _storage = const FlutterSecureStorage();

  static const _kAccessKey = 'jwt_token';
  static const _kRefreshKey = 'refresh_token';

  Future<void> _saveTokens(String access, [String? refresh]) async {
    await _storage.write(key: _kAccessKey, value: access);
    if (refresh != null && refresh.isNotEmpty) {
      await _storage.write(key: _kRefreshKey, value: refresh);
    }
    print('Tokens saved');
  }

  Future<String?> getToken() async => _storage.read(key: _kAccessKey);

  Future<String?> _getRefreshToken() async => _storage.read(key: _kRefreshKey);

  Future<void> logout() async {
    await _storage.delete(key: _kAccessKey);
    await _storage.delete(key: _kRefreshKey);
    print('Logout completed');
  }

  Map<String, dynamic> _extractAuthMap(dynamic decoded) {
    if (decoded is Map<String, dynamic>) {
      final data = decoded['data'];
      if (data is Map) return Map<String, dynamic>.from(data);
      return decoded;
    }
    return <String, dynamic>{};
  }

  Future<bool> _saveTokensFromAuthResponse(
    http.Response response, {
    bool allowSuccessWithoutTokens = false,
  }) async {
    if (response.statusCode != 200 && response.statusCode != 201) return false;

    try {
      final map = _extractAuthMap(jsonDecode(response.body));
      final access =
          (map['accessToken'] ??
                  map['token'] ??
                  map['jwt'] ??
                  map['access_token'])
              ?.toString();
      final refresh =
          (map['refreshToken'] ?? map['refresh'] ?? map['refresh_token'])
              ?.toString();

      if (access != null && access.isNotEmpty) {
        await _saveTokens(access, refresh);
        return true;
      }

      return allowSuccessWithoutTokens;
    } catch (e) {
      print('Auth response parse error: $e');
      return false;
    }
  }

  Future<bool> _refreshToken() async {
    final refresh = await _getRefreshToken();
    if (refresh == null || refresh.isEmpty) {
      print('No refresh token');
      return false;
    }

    final url = Uri.parse('$baseUrl/api/auth/refresh');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json', 'Refresh-Token': refresh},
      );
      print('Refresh: ${response.statusCode}');

      if (response.statusCode == 200) {
        final map = _extractAuthMap(jsonDecode(response.body));
        final newAccess =
            (map['accessToken'] ??
                    map['token'] ??
                    map['jwt'] ??
                    map['access_token'])
                ?.toString();
        final newRefresh =
            (map['refreshToken'] ?? map['refresh'] ?? map['refresh_token'])
                ?.toString();

        if (newAccess != null && newAccess.isNotEmpty) {
          await _saveTokens(newAccess, newRefresh);
          return true;
        }
      }
      return false;
    } catch (e) {
      print('Refresh error: $e');
      return false;
    }
  }

  Future<Map<String, String>> _getHeaders({bool multipart = false}) async {
    final token = await getToken();
    return {
      if (token != null) 'Authorization': 'Bearer $token',
      if (!multipart) 'Content-Type': 'application/json',
    };
  }

  Future<http.Response> _getWithAuth(Uri url) async {
    Future<http.Response> doGet() async =>
        http.get(url, headers: await _getHeaders());

    var response = await doGet();
    if (response.statusCode == 401 || response.statusCode == 403) {
      final ok = await _refreshToken();
      if (ok) {
        response = await doGet();
      } else if (response.statusCode == 401) {
        await logout();
        throw Exception('Failed to refresh token');
      }
    }
    return response;
  }

  Future<http.Response> _putWithAuth(Uri url, {Object? body}) async {
    Future<http.Response> doPut() async =>
        http.put(url, headers: await _getHeaders(), body: body);

    var response = await doPut();
    if (response.statusCode == 401 || response.statusCode == 403) {
      final ok = await _refreshToken();
      if (ok) {
        response = await doPut();
      } else if (response.statusCode == 401) {
        await logout();
        throw Exception('Failed to refresh token');
      }
    }
    return response;
  }

  Future<http.Response> _postWithAuth(Uri url, {Object? body}) async {
    Future<http.Response> doPost() async =>
        http.post(url, headers: await _getHeaders(), body: body);

    var response = await doPost();
    if (response.statusCode == 401 || response.statusCode == 403) {
      final ok = await _refreshToken();
      if (ok) {
        response = await doPost();
      } else if (response.statusCode == 401) {
        await logout();
        throw Exception('Failed to refresh token');
      }
    }
    return response;
  }

  Future<http.Response> _deleteWithAuth(Uri url) async {
    Future<http.Response> doDelete() async =>
        http.delete(url, headers: await _getHeaders());

    var response = await doDelete();
    if (response.statusCode == 401 || response.statusCode == 403) {
      final ok = await _refreshToken();
      if (ok) {
        response = await doDelete();
      } else if (response.statusCode == 401) {
        await logout();
        throw Exception('Failed to refresh token');
      }
    }
    return response;
  }

  Future<bool> login(String email, String password) async {
    final body = jsonEncode({'email': email.trim(), 'password': password});
    final endpoints = <Uri>[
      Uri.parse('$baseUrl/api/auth/login'),
      Uri.parse('$baseUrl/api/auth/sign-in'),
      Uri.parse('$baseUrl/api/auth/signin'),
    ];

    for (final url in endpoints) {
      try {
        final postResp = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: body,
        );
        print('Login POST $url: ${postResp.statusCode}');
        if (await _saveTokensFromAuthResponse(postResp)) return true;

        if (postResp.statusCode == 405) {
          final putResp = await http.put(
            url,
            headers: {'Content-Type': 'application/json'},
            body: body,
          );
          print('Login PUT $url: ${putResp.statusCode}');
          if (await _saveTokensFromAuthResponse(putResp)) return true;
        }

        print('Login failed [$url]: ${postResp.body}');
      } catch (e) {
        print('Login error [$url]: $e');
      }
    }

    return false;
  }

  Future<bool> register(String email, String password, String role) async {
    final body = jsonEncode({
      'email': email.trim(),
      'password': password,
      'role': role.trim(),
    });

    final endpoints = <Uri>[
      Uri.parse('$baseUrl/api/auth/register'),
      Uri.parse('$baseUrl/api/auth/sign-up'),
      Uri.parse('$baseUrl/api/auth/signup'),
    ];

    for (final url in endpoints) {
      try {
        final postResp = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: body,
        );
        print('Register POST $url: ${postResp.statusCode}');
        if (await _saveTokensFromAuthResponse(
          postResp,
          allowSuccessWithoutTokens: true,
        )) {
          return true;
        }

        if (postResp.statusCode == 405) {
          final putResp = await http.put(
            url,
            headers: {'Content-Type': 'application/json'},
            body: body,
          );
          print('Register PUT $url: ${putResp.statusCode}');
          if (await _saveTokensFromAuthResponse(
            putResp,
            allowSuccessWithoutTokens: true,
          )) {
            return true;
          }
        }

        print('Register failed [$url]: ${postResp.body}');
      } catch (e) {
        print('Register error [$url]: $e');
      }
    }

    return false;
  }

  Future<Map<String, dynamic>?> getProfile() async {
    final url = Uri.parse('$baseUrl/api/profiles/me');
    try {
      final response = await _getWithAuth(url);
      print('Profile: ${response.statusCode}');
      if (response.statusCode == 200) return jsonDecode(response.body);
      print('Profile failed: ${response.body}');
    } catch (e) {
      print('Profile error: $e');
    }
    return null;
  }

  Future<bool> updateProfile(Map<String, dynamic> data) async {
    final url = Uri.parse('$baseUrl/api/profiles/me');
    try {
      final response = await _putWithAuth(url, body: jsonEncode(data));
      print('Profile updated: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      print('Profile update error: $e');
      return false;
    }
  }

  Future<bool> uploadAvatar(XFile imageFile) async {
    final ext = imageFile.path.split('.').last.toLowerCase();
    final filename = ext.isNotEmpty ? 'avatar.$ext' : 'avatar.jpg';
    final mediaType = switch (ext) {
      'png' => MediaType('image', 'png'),
      'webp' => MediaType('image', 'webp'),
      'heic' => MediaType('image', 'heic'),
      _ => MediaType('image', 'jpeg'),
    };

    Future<http.StreamedResponse> sendOnce(
      Uri url,
      String method,
      String fileField,
    ) async {
      final request = http.MultipartRequest(method, url);
      request.headers.addAll(await _getHeaders(multipart: true));
      request.files.add(
        await http.MultipartFile.fromPath(
          fileField,
          imageFile.path,
          filename: filename,
          contentType: mediaType,
        ),
      );
      return request.send();
    }

    Future<bool> tryUpload(Uri url, String method, String fileField) async {
      var response = await sendOnce(url, method, fileField);
      var body = await response.stream.bytesToString();

      print('Avatar $method $url (field=$fileField): ${response.statusCode}');
      if (body.isNotEmpty) {
        print('Avatar response: $body');
      }

      if (response.statusCode == 401) {
        final refreshed = await _refreshToken();
        if (!refreshed) {
          await logout();
          return false;
        }
        response = await sendOnce(url, method, fileField);
        body = await response.stream.bytesToString();
        print(
          'Avatar retry $method $url (field=$fileField): ${response.statusCode}',
        );
        if (body.isNotEmpty) {
          print('Avatar retry response: $body');
        }
      }

      return response.statusCode >= 200 && response.statusCode < 300;
    }

    final targets = <(Uri url, String method, String field)>[
      (Uri.parse('$baseUrl/api/profiles/avatar'), 'POST', 'avatar'),
      (Uri.parse('$baseUrl/api/profiles/avatar'), 'PUT', 'avatar'),
      (Uri.parse('$baseUrl/api/profiles/avatar'), 'POST', 'file'),
      (Uri.parse('$baseUrl/api/profiles/avatar'), 'PUT', 'file'),
      (Uri.parse('$baseUrl/api/profiles/me/avatar'), 'POST', 'avatar'),
      (Uri.parse('$baseUrl/api/profiles/me/avatar'), 'PUT', 'avatar'),
      (Uri.parse('$baseUrl/api/profiles/me/avatar'), 'POST', 'file'),
      (Uri.parse('$baseUrl/api/profiles/me/avatar'), 'PUT', 'file'),
    ];

    try {
      for (final target in targets) {
        final ok = await tryUpload(target.$1, target.$2, target.$3);
        if (ok) return true;
      }
      return false;
    } catch (e) {
      print('Avatar error: $e');
      return false;
    }
  }

  Future<bool> likeRecipe(int recipeId) async {
    final urls = <Uri>[
      Uri.parse('$baseUrl/api/profiles/likes/$recipeId'),
      Uri.parse('$baseUrl/api/likes/$recipeId'),
    ];

    for (final url in urls) {
      try {
        final response = await _postWithAuth(url);
        if (response.statusCode == 200 || response.statusCode == 201) {
          return true;
        }
      } catch (e) {
        print('likeRecipe error [$url]: $e');
      }
    }
    return false;
  }

  Future<bool> unlikeRecipe(int recipeId) async {
    final urls = <Uri>[
      Uri.parse('$baseUrl/api/profiles/likes/$recipeId'),
      Uri.parse('$baseUrl/api/likes/$recipeId'),
    ];

    for (final url in urls) {
      try {
        final response = await _deleteWithAuth(url);
        if (response.statusCode == 200 ||
            response.statusCode == 204 ||
            response.statusCode == 404) {
          return true;
        }
      } catch (e) {
        print('unlikeRecipe error [$url]: $e');
      }
    }
    return false;
  }

  Future<List<Map<String, dynamic>>> getLikedRecipes() async {
    final urls = <Uri>[
      Uri.parse('$baseUrl/api/profiles/likes'),
      Uri.parse('$baseUrl/api/likes'),
    ];

    for (final url in urls) {
      try {
        final response = await _getWithAuth(url);
        if (response.statusCode != 200) continue;
        final decoded = jsonDecode(response.body);
        final extracted = _extractLikesList(decoded);
        if (extracted.isNotEmpty) return extracted;
      } catch (e) {
        print('getLikedRecipes error [$url]: $e');
      }
    }
    return const [];
  }

  Future<String?> startFoodAnalysis(
    XFile imageFile, {
    String extraQuestions = '',
  }) async {
    var token = await getToken();
    if (token == null || token.isEmpty) {
      final refreshed = await _refreshToken();
      if (refreshed) {
        token = await getToken();
      }
    }
    if (token == null) {
      print('No token for analysis');
      return null;
    }

    print('Starting analysis...');
    print(
      'File: ${imageFile.name}, size: ${(await File(imageFile.path).length()) / 1024} KB',
    );

    final url = Uri.parse('$baseUrl/api/food/analyze');

    try {
      Future<http.StreamedResponse> sendOnce() async {
        final request = http.MultipartRequest('POST', url);
        request.headers.addAll(await _getHeaders(multipart: true));
        request.files.add(
          await http.MultipartFile.fromPath(
            'file',
            imageFile.path,
            filename: 'food.jpg',
            contentType: MediaType('image', 'jpeg'),
          ),
        );
        request.fields['extraQuestions'] = extraQuestions.trim();
        return request.send();
      }

      var response = await sendOnce();
      if (response.statusCode == 401 || response.statusCode == 403) {
        final refreshed = await _refreshToken();
        if (refreshed) {
          response = await sendOnce();
        } else if (response.statusCode == 401) {
          await logout();
          print('Failed to refresh token before analysis start');
          return null;
        }
      }

      final respStr = await response.stream.bytesToString();
      print('Analysis started: ${response.statusCode}');
      print('Response: $respStr');

      if (response.statusCode == 200 || response.statusCode == 202) {
        final data = jsonDecode(respStr);
        final id = data['id']?.toString();
        if (id != null) {
          print('Analysis ID: $id');
          return id;
        }
        print('No analysis ID in response: $respStr');
      } else {
        print('Analysis start failed (${response.statusCode}): $respStr');
      }
    } catch (e) {
      print('Analysis start error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> getAnalysisResult(String analysisId) async {
    final url = Uri.parse('$baseUrl/api/food/analysis/$analysisId');
    try {
      final response = await _getWithAuth(url);
      print('Analysis $analysisId: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final normalized = <String, dynamic>{
          'id': data['id'],
          'status': data['status'],
          'dish_name': data['dishName'] ?? data['dish_name'],
          'calories': data['calories'],
          'protein': data['protein'],
          'fats': data['fats'],
          'carbs': data['carbs'],
          'extra_info': data['extraInfo'] ?? data['extra_info'],
          'image_url': data['imageUrl'] ?? data['image_url'],
        };
        print('Normalized dish: ${normalized['dish_name']}');
        return normalized;
      }

      print('Result failed (${response.statusCode}): ${response.body}');
    } catch (e) {
      print('Result error: $e');
    }
    return null;
  }

  Future<List<dynamic>?> getAnalysisHistory({int? limit}) async {
    final url = Uri.parse(
      '$baseUrl/api/food/history${limit != null ? '?limit=$limit' : ''}',
    );
    try {
      final response = await _getWithAuth(url);
      print('History: ${response.statusCode}');
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          return List<dynamic>.from(decoded);
        }
        if (decoded is Map<String, dynamic>) {
          final candidate =
              decoded['data'] ??
              decoded['content'] ??
              decoded['items'] ??
              decoded['results'];
          if (candidate is List) {
            return List<dynamic>.from(candidate);
          }
        }
        print('Unexpected history format: ${response.body}');
      }
    } catch (e) {
      print('History error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> analyzeFoodSync(
    XFile imageFile, {
    Duration timeout = const Duration(seconds: 45),
  }) async {
    print('Synchronous analysis (max $timeout)...');
    final id = await startFoodAnalysis(imageFile);
    if (id == null) return null;

    final startTime = DateTime.now();
    while (DateTime.now().difference(startTime) < timeout) {
      await Future.delayed(const Duration(seconds: 2));
      final result = await getAnalysisResult(id);

      if (result != null &&
          result['status'] == 'COMPLETED' &&
          result['dish_name'] != null) {
        print('Synchronous analysis completed: ${result['dish_name']}');
        return result;
      }
    }

    print('Synchronous analysis timeout');
    return null;
  }

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
    try {
      final candidates = [
        Uri.parse('$baseUrl/api/recipes/db/$recipeId'),
        Uri.parse('$baseUrl/api/recipes/db/search/$recipeId'),
      ];

      for (final url in candidates) {
        final response = await _getWithAuth(url);
        if (response.statusCode != 200) continue;

        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          return _mergeSeedIntoDetails(RecipeDetails.fromDb(data), seedSummary);
        }
      }

      return null;
    } catch (e) {
      print('getRecipeDetails error: $e');
      return null;
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
    final payload = <String, dynamic>{
      'lang': _normalizeLangForBackend(lang),
      'requiredDietKeys': requiredDietKeys ?? <String>[],
      'preferredHealthKeys': <String>[],
      'allergyKeys': <String>[],
      'healthConditionKeys': <String>[],
      'page': page,
      'size': size,
      'sortBy': 'recipe_id',
      'sortDir': 'desc',
    };
    final normalizedTitle = title?.trim();
    if (normalizedTitle != null && normalizedTitle.isNotEmpty) {
      payload['title'] = normalizedTitle;
    }
    final normalizedCategory = category?.trim();
    if (normalizedCategory != null && normalizedCategory.isNotEmpty) {
      payload['category'] = normalizedCategory;
    }

    try {
      final postUrl = Uri.parse('$baseUrl/api/recipes/db/search');
      final postResponse = await _postWithAuth(
        postUrl,
        body: jsonEncode(payload),
      );

      if (postResponse.statusCode == 200) {
        final decoded = jsonDecode(postResponse.body);
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
        '$baseUrl/api/recipes/db/search',
      ).replace(queryParameters: qp);
      final getResponse = await _getWithAuth(getUrl);
      if (getResponse.statusCode == 200) {
        final decoded = jsonDecode(getResponse.body);
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
    } catch (e) {
      print('_searchDbRecipesPageRaw error: $e');
    }

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

  List<Map<String, dynamic>> _extractLikesList(dynamic decoded) {
    Map<String, dynamic> asMap(dynamic value) {
      if (value is Map<String, dynamic>) return value;
      if (value is Map) return Map<String, dynamic>.from(value);
      return {'recipeId': value};
    }

    bool hasRecipeId(Map<String, dynamic> map) {
      return map.containsKey('recipeId') ||
          map.containsKey('recipe_id') ||
          map.containsKey('id');
    }

    if (decoded is List) {
      return decoded.map(asMap).where(hasRecipeId).toList();
    }

    if (decoded is Map<String, dynamic>) {
      for (final key in ['content', 'results', 'data', 'items', 'likes']) {
        final value = decoded[key];
        if (value is List) {
          return value.map(asMap).where(hasRecipeId).toList();
        }
      }

      if (hasRecipeId(decoded)) return [decoded];
    }

    return const [];
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
}
