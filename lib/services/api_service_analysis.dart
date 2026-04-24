part of 'api_service.dart';

extension ApiServiceAnalysisMethods on ApiService {
  Map<String, dynamic> _normalizeAnalysisHistoryItem(
    Map<String, dynamic> data,
  ) {
    return <String, dynamic>{
      'id': data['id'],
      'analysisId': data['analysisId'] ?? data['analysis_id'] ?? data['id'],
      'status': data['status'],
      'dishName': data['dishName'] ?? data['dish_name'],
      'calories': data['calories'],
      'protein': data['protein'],
      'fats': data['fats'],
      'carbs': data['carbs'],
      'extraInfo': data['extraInfo'] ?? data['extra_info'],
      'image_url': data['imageUrl'] ?? data['image_url'],
      'saved_meal_id': data['savedMealId'] ?? data['saved_meal_id'],
      'saved_at': data['savedAt'] ?? data['saved_at'],
      'createdAt': data['createdAt'] ?? data['created_at'],
      'errorMessage': data['errorMessage'] ?? data['error_message'],
      'estimatedWeightGrams':
          data['estimatedWeightGrams'] ?? data['estimated_weight_grams'],
      'foodDetected':
          data['foodDetected'] ??
          data['food_detected'] ??
          data['isFood'] ??
          data['is_food'],
      'healthScore': data['healthScore'] ?? data['health_score'],
    };
  }

  Future<String?> startFoodAnalysis(
    XFile imageFile, {
    String extraQuestions = '',
  }) async {
    final requestRevision = _sessionRevision;
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

    final url = Uri.parse('${ApiService.baseUrl}/api/food/analyze');

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
        } else {
          await _logoutIfSessionUnchanged(requestRevision);
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
    final url = Uri.parse(
      '${ApiService.baseUrl}/api/food/analysis/$analysisId',
    );
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
          'saved_meal_id': data['savedMealId'] ?? data['saved_meal_id'],
          'saved_at': data['savedAt'] ?? data['saved_at'],
          'error_message': data['errorMessage'] ?? data['error_message'],
          'estimatedWeightGrams':
              data['estimatedWeightGrams'] ?? data['estimated_weight_grams'],
          'foodDetected':
              data['foodDetected'] ??
              data['food_detected'] ??
              data['isFood'] ??
              data['is_food'],
          'health_score': data['healthScore'] ?? data['health_score'],
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
    if (!NetworkMonitor.instance.isOnline) {
      return _readCacheList(
        ApiService._kCacheHistory,
        maxAge: ApiService._historyCacheTtl,
      );
    }

    final url = Uri.parse(
      '${ApiService.baseUrl}/api/food/history${limit != null ? '?limit=$limit' : ''}',
    );
    try {
      final response = await _getWithAuth(url);
      print('History: ${response.statusCode}');
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          final list = decoded
              .whereType<Map>()
              .map(
                (item) => _normalizeAnalysisHistoryItem(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList();
          await _writeCacheJson(ApiService._kCacheHistory, list);
          return list;
        }
        if (decoded is Map<String, dynamic>) {
          final candidate =
              decoded['data'] ??
              decoded['content'] ??
              decoded['items'] ??
              decoded['results'];
          if (candidate is List) {
            final list = candidate
                .whereType<Map>()
                .map(
                  (item) => _normalizeAnalysisHistoryItem(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList();
            await _writeCacheJson(ApiService._kCacheHistory, list);
            return list;
          }
        }
        print('Unexpected history format: ${response.body}');
      }
    } catch (e) {
      print('History error: $e');
    }
    return _readCacheList(
      ApiService._kCacheHistory,
      maxAge: ApiService._historyCacheTtl,
    );
  }

  Future<bool> deleteAnalysisHistoryItem(String analysisId) async {
    final url = Uri.parse('${ApiService.baseUrl}/api/food/history/$analysisId');
    try {
      final response = await _deleteWithAuth(url);
      print(
        'Delete analysis $analysisId: ${response.statusCode} ${response.body}',
      );
      if (response.statusCode == 200 ||
          response.statusCode == 204 ||
          response.statusCode == 404 ||
          response.statusCode == 410) {
        final cached = await _readCacheList(
          ApiService._kCacheHistory,
          maxAge: const Duration(days: 365),
        );
        if (cached != null) {
          final updated = cached
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .where((item) {
                final id =
                    (item['analysisId'] ?? item['analysis_id'] ?? item['id'])
                        ?.toString()
                        .trim() ??
                    '';
                return id != analysisId;
              })
              .toList();
          await _writeCacheJson(ApiService._kCacheHistory, updated);
        }
        return true;
      }
      print(
        'Delete analysis failed (${response.statusCode}): ${response.body}',
      );
    } catch (e) {
      print('Delete analysis history error: $e');
    }
    return false;
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
}
