part of 'api_service.dart';

extension ApiServiceAuthMethods on ApiService {
  Future<bool> login(String email, String password) async {
    final body = jsonEncode({'email': email.trim(), 'password': password});
    final endpoints = <Uri>[
      Uri.parse('${ApiService.baseUrl}/api/auth/login'),
      Uri.parse('${ApiService.baseUrl}/api/auth/sign-in'),
      Uri.parse('${ApiService.baseUrl}/api/auth/signin'),
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
          print('Login failed [$url]: ${putResp.body}');
          if (putResp.statusCode != 404 &&
              putResp.statusCode != 405 &&
              putResp.statusCode != 501) {
            return false;
          }
        }

        print('Login failed [$url]: ${postResp.body}');
        if (postResp.statusCode != 404 &&
            postResp.statusCode != 405 &&
            postResp.statusCode != 501) {
          return false;
        }
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
      Uri.parse('${ApiService.baseUrl}/api/auth/register'),
      Uri.parse('${ApiService.baseUrl}/api/auth/sign-up'),
      Uri.parse('${ApiService.baseUrl}/api/auth/signup'),
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
          print('Register failed [$url]: ${putResp.body}');
          if (putResp.statusCode != 404 &&
              putResp.statusCode != 405 &&
              putResp.statusCode != 501) {
            return false;
          }
        }

        print('Register failed [$url]: ${postResp.body}');
        if (postResp.statusCode != 404 &&
            postResp.statusCode != 405 &&
            postResp.statusCode != 501) {
          return false;
        }
      } catch (e) {
        print('Register error [$url]: $e');
      }
    }

    return false;
  }
}
