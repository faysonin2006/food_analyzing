import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http_parser/http_parser.dart';

class ApiService {
  static const String baseUrl = 'http://10.0.2.2:8090';
  final _storage = const FlutterSecureStorage();

  static const _kAccessKey = 'jwt_token';
  static const _kRefreshKey = 'refresh_token';

  Future<void> _saveTokens(String access, String refresh) async {
    await _storage.write(key: _kAccessKey, value: access);
    await _storage.write(key: _kRefreshKey, value: refresh);
    print('✅ Токены сохранены');
  }

  Future<String?> getToken() async => _storage.read(key: _kAccessKey);

  Future<String?> _getRefreshToken() async => _storage.read(key: _kRefreshKey);

  Future<void> logout() async {
    await _storage.delete(key: _kAccessKey);
    await _storage.delete(key: _kRefreshKey);
    print('👋 Выход выполнен');
  }

  Future<bool> _refreshToken() async {
    final refresh = await _getRefreshToken();
    if (refresh == null) {
      print('❌ Нет refresh токена');
      return false;
    }

    final url = Uri.parse('$baseUrl/api/auth/refresh');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json', 'Refresh-Token': refresh},
      );
      print('🔄 Refresh: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final newAccess = data['accessToken'] ?? data['token'];
        final newRefresh = data['refreshToken'];
        if (newAccess != null && newRefresh != null) {
          await _saveTokens(newAccess, newRefresh);
          return true;
        }
      }
      return false;
    } catch (e) {
      print('❌ Ошибка refresh: $e');
      return false;
    }
  }

  Future<http.Response> _getWithAuth(Uri url) async {
    Future<http.Response> doGet() async {
      return http.get(url, headers: await _getHeaders());
    }

    var response = await doGet();
    if (response.statusCode == 401) {
      final ok = await _refreshToken();
      if (!ok) {
        await logout();
        throw Exception('Не удалось обновить токен');
      }
      response = await doGet();
    }
    return response;
  }

  Future<http.Response> _putWithAuth(Uri url, {Object? body}) async {
    Future<http.Response> doPut() async {
      return http.put(url, headers: await _getHeaders(), body: body);
    }

    var response = await doPut();
    if (response.statusCode == 403 || response.statusCode == 401) {
      final ok = await _refreshToken();
      if (!ok) {
        await logout();
        throw Exception('Не удалось обновить токен');
      }
      response = await doPut();
    }
    return response;
  }

  Future<http.Response> _postWithAuth(Uri url, {Object? body}) async {
    Future<http.Response> doPost() async {
      return http.post(url, headers: await _getHeaders(), body: body);
    }

    var response = await doPost();
    if (response.statusCode == 401) {
      final ok = await _refreshToken();
      if (!ok) {
        await logout();
        throw Exception('Не удалось обновить токен');
      }
      response = await doPost();
    }
    return response;
  }

  Future<Map<String, String>> _getHeaders({bool multipart = false}) async {
    final token = await getToken();
    return {
      if (token != null) 'Authorization': 'Bearer $token',
      if (!multipart) 'Content-Type': 'application/json',
    };
  }

  Future<http.StreamedResponse> _multipartWithAuth(
      http.MultipartRequest request) async {
    request.headers.addAll(await _getHeaders(multipart: true));

    try {
      var response = await request.send();
      if (response.statusCode == 401) {
        final ok = await _refreshToken();
        if (!ok) {
          await logout();
          throw Exception('Не удалось обновить токен');
        }
        request.headers.addAll(await _getHeaders(multipart: true));
        response = await request.send();
      }
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> login(String email, String password) async {
    final url = Uri.parse('$baseUrl/api/auth/login');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );
      print('🔑 Логин: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final access = data['accessToken'] ?? data['token'];
        final refresh = data['refreshToken'];
        if (access != null && refresh != null) {
          await _saveTokens(access, refresh);
          return true;
        }
      }
      print('❌ Логин failed: ${response.body}');
      return false;
    } catch (e) {
      print('❌ Ошибка логина: $e');
      return false;
    }
  }

  Future<bool> register(String email, String password, String role) async {
    final url = Uri.parse('$baseUrl/api/auth/register');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password, 'role': role}),
      );
      print('📝 Регистрация: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final access = data['accessToken'] ?? data['token'];
        final refresh = data['refreshToken'];
        if (access != null && refresh != null) {
          await _saveTokens(access, refresh);
        }
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Ошибка регистрации: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> getProfile() async {
    final url = Uri.parse('$baseUrl/api/profiles/me');
    try {
      final response = await _getWithAuth(url);
      print('👤 Профиль: ${response.statusCode}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      print('❌ Профиль failed: ${response.body}');
    } catch (e) {
      print('❌ Ошибка профиля: $e');
    }
    return null;
  }

  Future<bool> updateProfile(Map<String, dynamic> data) async {
    final url = Uri.parse('$baseUrl/api/profiles/me');
    try {
      final response = await _putWithAuth(url, body: jsonEncode(data));
      print('📝 Профиль обновлен: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      print('❌ Ошибка обновления профиля: $e');
      return false;
    }
  }

  Future<bool> uploadAvatar(XFile imageFile) async {
    final url = Uri.parse('$baseUrl/api/profiles/avatar');
    var request = http.MultipartRequest('POST', url);

    request.files.add(await http.MultipartFile.fromPath(
      'avatar',
      imageFile.path,
      filename: 'avatar.jpg',
      contentType: MediaType('image', 'jpeg'),
    ));

    try {
      final response = await _multipartWithAuth(request);
      print('🖼️ Аватар: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      print('❌ Ошибка аватара: $e');
      return false;
    }
  }

  Future<String?> startFoodAnalysis(XFile imageFile) async {
    final token = await getToken();
    if (token == null) {
      print('❌ Нет токена для анализа!');
      return null;
    }

    print('🚀 Запуск анализа...');
    print('📁 Файл: ${imageFile.name}, размер: ${(await File(imageFile.path).length()) / 1024} KB');

    final url = Uri.parse('$baseUrl/api/food/analyze');
    var request = http.MultipartRequest('POST', url);

    request.files.add(await http.MultipartFile.fromPath(
      'file',
      imageFile.path,
      filename: 'food.jpg',
      contentType: MediaType('image', 'jpeg'),
    ));

    try {
      final response = await _multipartWithAuth(request);
      final respStr = await response.stream.bytesToString();
      print('🚀 Анализ запущен: ${response.statusCode}');
      print('📥 Ответ: $respStr');

      if (response.statusCode == 200 || response.statusCode == 202) {
        final data = jsonDecode(respStr);
        final id = data['id']?.toString();
        if (id != null) {
          print('✅ ID анализа: $id');
          return id;
        } else {
          print('❌ Нет ID в ответе: $respStr');
        }
      } else {
        print('❌ Ошибка запуска (${response.statusCode}): $respStr');
      }
    } catch (e) {
      print('❌ Ошибка запуска анализа: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> getAnalysisResult(String analysisId) async {
    final url = Uri.parse('$baseUrl/api/food/analysis/$analysisId');
    try {
      final response = await _getWithAuth(url);
      print('📊 Анализ $analysisId: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        Map<String, dynamic> normalized = {
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
        print('✅ Нормализованный: ${normalized['dish_name']}');
        return normalized;
      } else {
        print('❌ Результат failed (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      print('❌ Ошибка результата: $e');
    }
    return null;
  }

  Future<List<dynamic>?> getAnalysisHistory({int? limit}) async {
    final url = Uri.parse('$baseUrl/api/food/history${limit != null ? '?limit=$limit' : ''}');
    try {
      final response = await _getWithAuth(url);
      print('📈 История: ${response.statusCode}');

      if (response.statusCode == 200) {
        return List<dynamic>.from(jsonDecode(response.body));
      }
    } catch (e) {
      print('❌ Ошибка истории: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> analyzeFoodSync(
      XFile imageFile, {
        Duration timeout = const Duration(seconds: 45),
      }) async {
    print('🔄 Синхронный анализ (max $timeout)...');
    final id = await startFoodAnalysis(imageFile);
    if (id == null) return null;

    final startTime = DateTime.now();
    while (DateTime.now().difference(startTime) < timeout) {
      await Future.delayed(const Duration(seconds: 2));
      final result = await getAnalysisResult(id);

      if (result != null &&
          result['status'] == 'COMPLETED' &&
          result['dish_name'] != null) {
        print('✅ Синхронный анализ завершён: ${result['dish_name']}');
        return result;
      }
    }
    print('⏰ Синхронный таймаут');
    return null;
  }
}
