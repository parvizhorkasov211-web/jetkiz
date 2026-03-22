import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../../features/auth/data/auth_storage.dart';

class ApiClient {
  ApiClient._internal();

  static final ApiClient instance = ApiClient._internal();
  factory ApiClient() => instance;

  final http.Client _http = http.Client();
  final AuthStorage _storage = AuthStorage();

  Future<dynamic> get(String path, {bool authRequired = true}) async {
    return _send(
      method: 'GET',
      path: path,
      authRequired: authRequired,
    );
  }

  Future<dynamic> post(
    String path,
    Map<String, dynamic> body, {
    bool authRequired = true,
  }) async {
    return _send(
      method: 'POST',
      path: path,
      body: body,
      authRequired: authRequired,
    );
  }

  Future<dynamic> patch(
    String path,
    Map<String, dynamic> body, {
    bool authRequired = true,
  }) async {
    return _send(
      method: 'PATCH',
      path: path,
      body: body,
      authRequired: authRequired,
    );
  }

  Future<dynamic> put(
    String path,
    Map<String, dynamic> body, {
    bool authRequired = true,
  }) async {
    return _send(
      method: 'PUT',
      path: path,
      body: body,
      authRequired: authRequired,
    );
  }

  Future<dynamic> delete(
    String path, {
    bool authRequired = true,
  }) async {
    return _send(
      method: 'DELETE',
      path: path,
      authRequired: authRequired,
    );
  }

  Future<dynamic> _send({
    required String method,
    required String path,
    Map<String, dynamic>? body,
    required bool authRequired,
    bool isRetryAfterRefresh = false,
  }) async {
    final uri = Uri.parse('${AppConfig.baseUrl}$path');

    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };

    if (authRequired) {
      final accessToken = await _storage.getAccessToken();
      if (accessToken != null && accessToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $accessToken';
      }
    }

    late http.Response response;

    try {
      switch (method) {
        case 'GET':
          response = await _http.get(uri, headers: headers);
          break;
        case 'POST':
          response = await _http.post(
            uri,
            headers: headers,
            body: body == null ? null : jsonEncode(body),
          );
          break;
        case 'PATCH':
          response = await _http.patch(
            uri,
            headers: headers,
            body: body == null ? null : jsonEncode(body),
          );
          break;
        case 'PUT':
          response = await _http.put(
            uri,
            headers: headers,
            body: body == null ? null : jsonEncode(body),
          );
          break;
        case 'DELETE':
          response = await _http.delete(uri, headers: headers);
          break;
        default:
          throw Exception('Unsupported method: $method');
      }
    } on SocketException {
      throw Exception('Нет соединения с сервером');
    } catch (_) {
      rethrow;
    }

    if (response.statusCode == 401 && authRequired && !isRetryAfterRefresh) {
      final refreshed = await _tryRefresh();
      if (refreshed) {
        return _send(
          method: method,
          path: path,
          body: body,
          authRequired: authRequired,
          isRetryAfterRefresh: true,
        );
      }
    }

    return _handleResponse(response);
  }

  Future<bool> _tryRefresh() async {
    final refreshToken = await _storage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      await _storage.clearTokens();
      return false;
    }

    final uri = Uri.parse('${AppConfig.baseUrl}/auth/refresh');

    try {
      final response = await _http.post(
        uri,
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'refreshToken': refreshToken,
        }),
      );

      final data = _decodeBody(response.body);

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          data is Map<String, dynamic>) {
        final accessToken = data['accessToken']?.toString();
        final newRefreshToken = data['refreshToken']?.toString();

        if (accessToken != null &&
            accessToken.isNotEmpty &&
            newRefreshToken != null &&
            newRefreshToken.isNotEmpty) {
          await _storage.saveTokens(accessToken, newRefreshToken);
          return true;
        }
      }
    } catch (_) {
      // ignore
    }

    await _storage.clearTokens();
    return false;
  }

  dynamic _handleResponse(http.Response response) {
    final decoded = _decodeBody(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    if (decoded is Map<String, dynamic>) {
      final message = decoded['message']?.toString();
      if (message != null && message.isNotEmpty) {
        throw Exception(message);
      }
    }

    throw Exception('HTTP ${response.statusCode}');
  }

  dynamic _decodeBody(String body) {
    if (body.isEmpty) return null;
    try {
      return jsonDecode(body);
    } catch (_) {
      return body;
    }
  }
}
