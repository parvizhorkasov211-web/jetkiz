import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:jetkiz_mobile/core/config/appConfig.dart';
import 'package:jetkiz_mobile/features/auth/data/authStorage.dart';

class ApiClient {
  ApiClient._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.baseUrl,
        connectTimeout: AppConfig.connectTimeout,
        receiveTimeout: AppConfig.receiveTimeout,
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = _accessToken ?? await _authStorage.getAccessToken();

          if (token != null && token.trim().isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          } else {
            options.headers.remove('Authorization');
          }

          if (kDebugMode) {
            debugPrint('*** Request ***');
            debugPrint('uri: ${options.uri}');
            debugPrint('method: ${options.method}');
            debugPrint('headers: ${options.headers}');
            debugPrint('data: ${options.data}');
          }

          handler.next(options);
        },
        onResponse: (response, handler) {
          if (kDebugMode) {
            debugPrint('*** Response ***');
            debugPrint('uri: ${response.requestOptions.uri}');
            debugPrint('statusCode: ${response.statusCode}');
            debugPrint('data: ${response.data}');
          }

          handler.next(response);
        },
        onError: (error, handler) async {
          if (kDebugMode) {
            debugPrint('*** DioException ***');
            debugPrint('uri: ${error.requestOptions.uri}');
            debugPrint('statusCode: ${error.response?.statusCode}');
            debugPrint('data: ${error.response?.data}');
            debugPrint('message: ${error.message}');
          }

          final requestOptions = error.requestOptions;
          final isUnauthorized = error.response?.statusCode == 401;
          final skipRefresh =
              requestOptions.headers['x-skip-auth-refresh'] == 'true';
          final alreadyRetried = requestOptions.extra['retried'] == true;

          if (isUnauthorized && !skipRefresh && !alreadyRetried) {
            final refreshed = await _tryRefreshToken();

            if (refreshed) {
              final retryHeaders = Map<String, dynamic>.from(
                requestOptions.headers,
              )..remove('x-skip-auth-refresh');

              final retryOptions = Options(
                method: requestOptions.method,
                headers: retryHeaders,
                responseType: requestOptions.responseType,
                contentType: requestOptions.contentType,
                sendTimeout: requestOptions.sendTimeout,
                receiveTimeout: requestOptions.receiveTimeout,
                extra: {
                  ...requestOptions.extra,
                  'retried': true,
                },
              );

              try {
                final response = await _dio.request(
                  requestOptions.path,
                  data: requestOptions.data,
                  queryParameters: requestOptions.queryParameters,
                  options: retryOptions,
                );

                return handler.resolve(response);
              } catch (_) {
                await clearTokens();
              }
            } else {
              await clearTokens();
            }
          }

          handler.next(error);
        },
      ),
    );
  }

  static final ApiClient _instance = ApiClient._internal();

  factory ApiClient() => _instance;

  late final Dio _dio;
  final AuthStorage _authStorage = AuthStorage();

  String? _accessToken;
  String? _refreshToken;
  bool _isInitialized = false;
  Future<bool>? _refreshFuture;

  Dio get dio => _dio;

  Future<void> init() async {
    if (_isInitialized) return;

    _accessToken = await _authStorage.getAccessToken();
    _refreshToken = await _authStorage.getRefreshToken();
    _isInitialized = true;
  }

  Future<void> setAccessToken(String token) async {
    _accessToken = token;
    await _authStorage.saveAccessToken(token);
  }

  Future<void> setRefreshToken(String token) async {
    _refreshToken = token;
    await _authStorage.saveRefreshToken(token);
  }

  Future<void> setTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    await _authStorage.saveAccessToken(accessToken);
    await _authStorage.saveRefreshToken(refreshToken);
  }

  Future<void> loadTokensFromStorage() async {
    _accessToken = await _authStorage.getAccessToken();
    _refreshToken = await _authStorage.getRefreshToken();
  }

  Future<String?> getAccessToken() async {
    if (_accessToken != null && _accessToken!.trim().isNotEmpty) {
      return _accessToken;
    }

    _accessToken = await _authStorage.getAccessToken();
    return _accessToken;
  }

  Future<String?> getRefreshToken() async {
    if (_refreshToken != null && _refreshToken!.trim().isNotEmpty) {
      return _refreshToken;
    }

    _refreshToken = await _authStorage.getRefreshToken();
    return _refreshToken;
  }

  Future<void> clearTokens() async {
    _accessToken = null;
    _refreshToken = null;
    await _authStorage.clear();
  }

  Future<void> clearAccessToken() async {
    await clearTokens();
  }

  Future<bool> _tryRefreshToken() async {
    if (_refreshFuture != null) {
      return _refreshFuture!;
    }

    _refreshFuture = _performRefreshToken();
    final result = await _refreshFuture!;
    _refreshFuture = null;
    return result;
  }

  Future<bool> _performRefreshToken() async {
    final refreshToken = _refreshToken ?? await _authStorage.getRefreshToken();

    if (refreshToken == null || refreshToken.trim().isEmpty) {
      return false;
    }

    try {
      final response = await _dio.post(
        '/auth/refresh',
        data: {
          'refreshToken': refreshToken,
        },
        options: Options(
          headers: const {
            'x-skip-auth-refresh': 'true',
          },
        ),
      );

      final data = Map<String, dynamic>.from(response.data as Map);

      final newAccessToken = data['accessToken']?.toString() ?? '';
      final newRefreshToken = data['refreshToken']?.toString() ?? refreshToken;

      if (newAccessToken.isEmpty) {
        return false;
      }

      await setTokens(
        accessToken: newAccessToken,
        refreshToken: newRefreshToken,
      );

      return true;
    } catch (_) {
      return false;
    }
  }
}