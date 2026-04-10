import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/network_monitor.dart';
import '../features/recipes/models/models.dart';

part 'api_service_auth.dart';
part 'api_service_profile_likes.dart';
part 'api_service_analysis.dart';
part 'api_service_recipes.dart';
part 'api_service_lifestyle.dart';

class ApiException implements Exception {
  const ApiException({
    required this.message,
    this.statusCode,
    this.error,
    this.path,
    this.validationErrors,
  });

  final String message;
  final int? statusCode;
  final String? error;
  final String? path;
  final Map<String, dynamic>? validationErrors;

  @override
  String toString() => message;
}

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
      '.92:8090';
  // static const String baseUrl =
  //     'http://172.20.10'
  //     '.7:8090';

  final _storage = const FlutterSecureStorage();

  static const _kAccessKey = 'jwt_token';
  static const _kRefreshKey = 'refresh_token';
  static const _kCacheProfileMe = 'api_cache_profile_me';
  static const _kCacheLikes = 'api_cache_likes';
  static const _kCacheHistory = 'api_cache_analysis_history';
  static const _kCacheRecipeSearchPrefix = 'api_cache_recipe_search_';
  static const _kCacheRecipeDetailsPrefix = 'api_cache_recipe_details_';
  static const _kCacheTsSuffix = '_ts';

  static const _profileCacheTtl = Duration(days: 2);
  static const _profileHotCacheTtl = Duration(seconds: 20);
  static const _likesCacheTtl = Duration(days: 2);
  static const _historyCacheTtl = Duration(days: 2);
  static const _recipeSearchCacheTtl = Duration(days: 1);
  static const _recipeDetailsCacheTtl = Duration(days: 7);

  Map<String, dynamic>? _profileMemoryCache;
  DateTime? _profileMemoryCacheAt;
  Future<Map<String, dynamic>?>? _inFlightProfileRequest;

  String _cacheHash(String value) {
    var hash = 0x811C9DC5;
    for (final code in value.codeUnits) {
      hash ^= code;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  String _cacheKeyFromPayload(String prefix, Object payload) {
    final raw = jsonEncode(payload);
    return '$prefix${_cacheHash(raw)}';
  }

  Future<void> _writeCacheString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
    await prefs.setInt(
      '$key$_kCacheTsSuffix',
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<String?> _readCacheString(String key, {Duration? maxAge}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return null;
    if (maxAge == null) return raw;
    final ts = prefs.getInt('$key$_kCacheTsSuffix');
    if (ts == null) return raw;
    final age = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(ts),
    );
    if (age > maxAge) return null;
    return raw;
  }

  Future<void> _writeCacheJson(String key, Object value) async {
    await _writeCacheString(key, jsonEncode(value));
  }

  Future<Map<String, dynamic>?> _readCacheMap(
    String key, {
    Duration? maxAge,
  }) async {
    final raw = await _readCacheString(key, maxAge: maxAge);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }

  Future<List<dynamic>?> _readCacheList(String key, {Duration? maxAge}) async {
    final raw = await _readCacheString(key, maxAge: maxAge);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) return List<dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    return int.tryParse(text);
  }

  int? _likeId(Map<String, dynamic> item) {
    return _toInt(item['recipeId'] ?? item['recipe_id'] ?? item['id']);
  }

  Future<void> _upsertProfileCache(Map<String, dynamic> patch) async {
    final cached = await _readCacheMap(_kCacheProfileMe);
    final merged = <String, dynamic>{...(cached ?? <String, dynamic>{})}
      ..addAll(patch);
    _rememberProfile(merged);
    await _writeCacheJson(_kCacheProfileMe, merged);
  }

  Map<String, dynamic>? _cloneProfileMap(Map<String, dynamic>? value) {
    if (value == null) return null;
    return Map<String, dynamic>.from(value);
  }

  Map<String, dynamic>? _readHotProfileCache() {
    final cached = _profileMemoryCache;
    final cachedAt = _profileMemoryCacheAt;
    if (cached == null || cachedAt == null) return null;
    if (DateTime.now().difference(cachedAt) > _profileHotCacheTtl) return null;
    return _cloneProfileMap(cached);
  }

  void _rememberProfile(Map<String, dynamic>? profile) {
    _profileMemoryCache = _cloneProfileMap(profile);
    _profileMemoryCacheAt = profile == null ? null : DateTime.now();
  }

  Future<void> _updateLikesCache(int recipeId, {required bool liked}) async {
    final cachedList = await _readCacheList(_kCacheLikes);
    final current = _extractLikesList(cachedList ?? const []);
    if (liked) {
      final exists = current.any((e) => _likeId(e) == recipeId);
      if (!exists) {
        current.insert(0, {
          'recipeId': recipeId,
          'createdAt': DateTime.now().toIso8601String(),
        });
      }
    } else {
      current.removeWhere((e) => _likeId(e) == recipeId);
    }
    await _writeCacheJson(_kCacheLikes, current);
  }

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
    _profileMemoryCache = null;
    _profileMemoryCacheAt = null;
    _inFlightProfileRequest = null;
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

  Future<http.Response> _patchWithAuth(Uri url, {Object? body}) async {
    Future<http.Response> doPatch() async =>
        http.patch(url, headers: await _getHeaders(), body: body);

    var response = await doPatch();
    if (response.statusCode == 401 || response.statusCode == 403) {
      final ok = await _refreshToken();
      if (ok) {
        response = await doPatch();
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

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  dynamic _decodeJsonBody(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return null;
    try {
      return jsonDecode(trimmed);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic>? _validationErrorMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  String _composeErrorMessage(
    Map<String, dynamic>? bodyMap,
    String fallbackMessage,
  ) {
    final serverMessage = bodyMap?['message']?.toString().trim() ?? '';
    final serverError = bodyMap?['error']?.toString().trim() ?? '';
    final validationErrors = _validationErrorMap(bodyMap?['validationErrors']);
    final details = <String>[];

    if (validationErrors != null) {
      for (final value in validationErrors.values) {
        if (value is List) {
          final joined = value
              .map((item) => item.toString().trim())
              .where((item) => item.isNotEmpty)
              .join(', ');
          if (joined.isNotEmpty) details.add(joined);
        } else {
          final text = value?.toString().trim() ?? '';
          if (text.isNotEmpty) details.add(text);
        }
      }
    }

    final baseMessage = serverMessage.isNotEmpty
        ? serverMessage
        : (serverError.isNotEmpty ? serverError : fallbackMessage);

    if (details.isEmpty) return baseMessage;
    final detailsText = details.join('\n');
    if (baseMessage == fallbackMessage || baseMessage == serverError) {
      return detailsText;
    }
    return '$baseMessage\n$detailsText';
  }

  ApiException _apiExceptionFromResponse(
    http.Response response, {
    required String fallbackMessage,
  }) {
    final decoded = _decodeJsonBody(response.body);
    final bodyMap = _asMap(decoded);
    return ApiException(
      message: _composeErrorMessage(bodyMap, fallbackMessage),
      statusCode: response.statusCode,
      error: bodyMap?['error']?.toString(),
      path: bodyMap?['path']?.toString(),
      validationErrors: _validationErrorMap(bodyMap?['validationErrors']),
    );
  }

  http.Response _ensureSuccess(
    http.Response response, {
    required String fallbackMessage,
    Set<int> successCodes = const {200},
  }) {
    if (!successCodes.contains(response.statusCode)) {
      throw _apiExceptionFromResponse(
        response,
        fallbackMessage: fallbackMessage,
      );
    }
    return response;
  }

  List<Map<String, dynamic>> _asMapList(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }
}
