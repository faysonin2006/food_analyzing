part of 'api_service.dart';

extension ApiServiceAuthMethods on ApiService {
  Future<bool> login(String email, String password) async {
    final body = jsonEncode({'email': email.trim(), 'password': password});
    final endpoints = <Uri>[
      Uri.parse('${ApiService.baseUrl}/api/auth/login'),
      Uri.parse('${ApiService.baseUrl}/api/auth/sign-in'),
      Uri.parse('${ApiService.baseUrl}/api/auth/signin'),
    ];

    for (var attempt = 0; attempt < 2; attempt++) {
      var sawTransientFailure = false;

      for (final url in endpoints) {
        try {
          final postResp = await http
              .post(
                url,
                headers: {'Content-Type': 'application/json'},
                body: body,
              )
              .timeout(const Duration(seconds: 15));
          print('Login POST $url: ${postResp.statusCode}');
          if (await _saveTokensFromAuthResponse(postResp)) return true;

          if (postResp.statusCode == 405) {
            final putResp = await http
                .put(
                  url,
                  headers: {'Content-Type': 'application/json'},
                  body: body,
                )
                .timeout(const Duration(seconds: 15));
            print('Login PUT $url: ${putResp.statusCode}');
            if (await _saveTokensFromAuthResponse(putResp)) return true;
            print('Login failed [$url]: ${putResp.body}');
            if (putResp.statusCode >= 500) {
              sawTransientFailure = true;
              continue;
            }
            if (putResp.statusCode != 404 &&
                putResp.statusCode != 405 &&
                putResp.statusCode != 501) {
              return false;
            }
          }

          print('Login failed [$url]: ${postResp.body}');
          if (postResp.statusCode >= 500) {
            sawTransientFailure = true;
            continue;
          }
          if (postResp.statusCode != 404 &&
              postResp.statusCode != 405 &&
              postResp.statusCode != 501) {
            return false;
          }
        } on SocketException catch (e) {
          sawTransientFailure = true;
          print('Login socket error [$url]: $e');
        } on TimeoutException catch (e) {
          sawTransientFailure = true;
          print('Login timeout [$url]: $e');
        } catch (e) {
          print('Login error [$url]: $e');
        }
      }

      if (!sawTransientFailure || attempt == 1) break;
      await Future.delayed(const Duration(milliseconds: 350));
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
