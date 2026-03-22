import '../../../core/network/api_client.dart';

class AuthApi {
  final ApiClient _client = ApiClient.instance;

  Future<void> requestCode({
    required String phone,
  }) async {
    await _client.post(
      '/auth/request-code',
      {
        'phone': phone,
      },
      authRequired: false,
    );
  }

  Future<Map<String, dynamic>> verifyCode({
    required String phone,
    required String code,
  }) async {
    final response = await _client.post(
      '/auth/verify-code',
      {
        'phone': phone,
        'code': code,
      },
      authRequired: false,
    );

    if (response is! Map<String, dynamic>) {
      throw Exception('Некорректный ответ verify-code');
    }

    return response;
  }

  Future<Map<String, dynamic>> getMe() async {
    final response = await _client.get('/users/me');

    if (response is! Map<String, dynamic>) {
      throw Exception('Некорректный ответ users/me');
    }

    return response;
  }
}