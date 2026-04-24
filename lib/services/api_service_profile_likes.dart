part of 'api_service.dart';

extension ApiServiceProfileLikesMethods on ApiService {
  Future<Map<String, dynamic>?> getProfile({
    bool preferCache = true,
    bool allowCachedFallback = true,
  }) async {
    final hotCache = preferCache ? _readHotProfileCache() : null;
    if (hotCache != null) {
      return hotCache;
    }

    if (!NetworkMonitor.instance.isOnline) {
      if (!allowCachedFallback) return null;
      final cached = await _readCacheMap(
        ApiService._kCacheProfileMe,
        maxAge: ApiService._profileCacheTtl,
      );
      _rememberProfile(cached);
      return _cloneProfileMap(cached);
    }

    final inFlight = preferCache ? _inFlightProfileRequest : null;
    if (inFlight != null) {
      return inFlight;
    }

    final future = () async {
      final url = Uri.parse('${ApiService.baseUrl}/api/profiles/me');
      try {
        final response = await _getWithAuth(url);
        print('Profile: ${response.statusCode}');
        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic>) {
            _rememberProfile(decoded);
            await _writeCacheJson(ApiService._kCacheProfileMe, decoded);
            return _cloneProfileMap(decoded);
          }
          if (decoded is Map) {
            final map = Map<String, dynamic>.from(decoded);
            _rememberProfile(map);
            await _writeCacheJson(ApiService._kCacheProfileMe, map);
            return _cloneProfileMap(map);
          }
        }
        print('Profile failed: ${response.body}');
      } catch (e) {
        print('Profile error: $e');
      }

      if (!allowCachedFallback) {
        return null;
      }

      final cached = await _readCacheMap(
        ApiService._kCacheProfileMe,
        maxAge: ApiService._profileCacheTtl,
      );
      _rememberProfile(cached);
      return _cloneProfileMap(cached);
    }();

    if (preferCache) {
      _inFlightProfileRequest = future;
    }
    try {
      return await future;
    } finally {
      if (preferCache && identical(_inFlightProfileRequest, future)) {
        _inFlightProfileRequest = null;
      }
    }
  }

  Future<bool> updateProfile(Map<String, dynamic> data) async {
    final url = Uri.parse('${ApiService.baseUrl}/api/profiles/me');
    try {
      final response = await _putWithAuth(url, body: jsonEncode(data));
      print('Profile updated: ${response.statusCode}');
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final body = response.body.trim();
        if (body.isNotEmpty) {
          try {
            final decoded = jsonDecode(body);
            if (decoded is Map<String, dynamic>) {
              _rememberProfile(decoded);
              await _writeCacheJson(ApiService._kCacheProfileMe, decoded);
              return true;
            }
            if (decoded is Map) {
              final map = Map<String, dynamic>.from(decoded);
              _rememberProfile(map);
              await _writeCacheJson(ApiService._kCacheProfileMe, map);
              return true;
            }
          } catch (_) {
            // Fall back to local patch merge below.
          }
        }
        await _upsertProfileCache(data);
        return true;
      }
      return false;
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
      final requestRevision = _sessionRevision;
      var response = await sendOnce(url, method, fileField);
      var body = await response.stream.bytesToString();

      print('Avatar $method $url (field=$fileField): ${response.statusCode}');
      if (body.isNotEmpty) {
        print('Avatar response: $body');
      }

      if (response.statusCode == 401) {
        final refreshed = await _refreshToken();
        if (!refreshed) {
          await _logoutIfSessionUnchanged(requestRevision);
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
      (
        Uri.parse('${ApiService.baseUrl}/api/profiles/avatar'),
        'POST',
        'avatar',
      ),
      (Uri.parse('${ApiService.baseUrl}/api/profiles/avatar'), 'PUT', 'avatar'),
      (Uri.parse('${ApiService.baseUrl}/api/profiles/avatar'), 'POST', 'file'),
      (Uri.parse('${ApiService.baseUrl}/api/profiles/avatar'), 'PUT', 'file'),
      (
        Uri.parse('${ApiService.baseUrl}/api/profiles/me/avatar'),
        'POST',
        'avatar',
      ),
      (
        Uri.parse('${ApiService.baseUrl}/api/profiles/me/avatar'),
        'PUT',
        'avatar',
      ),
      (
        Uri.parse('${ApiService.baseUrl}/api/profiles/me/avatar'),
        'POST',
        'file',
      ),
      (
        Uri.parse('${ApiService.baseUrl}/api/profiles/me/avatar'),
        'PUT',
        'file',
      ),
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
      Uri.parse('${ApiService.baseUrl}/api/profiles/likes/$recipeId'),
      Uri.parse('${ApiService.baseUrl}/api/likes/$recipeId'),
    ];

    for (final url in urls) {
      try {
        final response = await _postWithAuth(url);
        if (response.statusCode == 200 || response.statusCode == 201) {
          await _updateLikesCache(recipeId, liked: true);
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
      Uri.parse('${ApiService.baseUrl}/api/profiles/likes/$recipeId'),
      Uri.parse('${ApiService.baseUrl}/api/likes/$recipeId'),
    ];

    for (final url in urls) {
      try {
        final response = await _deleteWithAuth(url);
        if (response.statusCode == 200 ||
            response.statusCode == 204 ||
            response.statusCode == 404) {
          await _updateLikesCache(recipeId, liked: false);
          return true;
        }
      } catch (e) {
        print('unlikeRecipe error [$url]: $e');
      }
    }
    return false;
  }

  Future<List<Map<String, dynamic>>> getLikedRecipes() async {
    if (!NetworkMonitor.instance.isOnline) {
      final cached = await _readCacheList(
        ApiService._kCacheLikes,
        maxAge: ApiService._likesCacheTtl,
      );
      return _extractLikesList(cached ?? const []);
    }

    final urls = <Uri>[
      Uri.parse('${ApiService.baseUrl}/api/profiles/likes'),
      Uri.parse('${ApiService.baseUrl}/api/likes'),
    ];

    for (final url in urls) {
      try {
        final response = await _getWithAuth(url);
        if (response.statusCode != 200) continue;
        final decoded = jsonDecode(response.body);
        final extracted = _extractLikesList(decoded);
        await _writeCacheJson(ApiService._kCacheLikes, extracted);
        return extracted;
      } catch (e) {
        print('getLikedRecipes error [$url]: $e');
      }
    }
    final cached = await _readCacheList(
      ApiService._kCacheLikes,
      maxAge: ApiService._likesCacheTtl,
    );
    return _extractLikesList(cached ?? const []);
  }
}
