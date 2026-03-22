import 'package:jetkiz_mobile/core/network/apiClient.dart';
import 'package:dio/dio.dart';

class AuthApi {
  final ApiClient _apiClient;

  AuthApi(this._apiClient);

  Future<RequestSmsCodeResponse> requestSmsCode({
    required String phone,
  }) async {
    final response = await _apiClient.dio.post(
      '/auth/request-code',
      data: {
        'phone': phone,
      },
    );

    final data = Map<String, dynamic>.from(response.data as Map);

    return RequestSmsCodeResponse.fromJson(data);
  }

  Future<VerifySmsCodeResponse> verifySmsCode({
    required String phone,
    required String code,
  }) async {
    final response = await _apiClient.dio.post(
      '/auth/verify-code',
      data: {
        'phone': phone,
        'code': code,
      },
    );

    final data = Map<String, dynamic>.from(response.data as Map);

    return VerifySmsCodeResponse.fromJson(data);
  }

  Future<RefreshTokenResponse> refreshToken({
    required String refreshToken,
  }) async {
    final response = await _apiClient.dio.post(
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

    return RefreshTokenResponse.fromJson(data);
  }
}

class RequestSmsCodeResponse {
  final bool success;
  final String phone;
  final String? code;
  final DateTime? expiresAt;

  const RequestSmsCodeResponse({
    required this.success,
    required this.phone,
    required this.code,
    required this.expiresAt,
  });

  factory RequestSmsCodeResponse.fromJson(Map<String, dynamic> json) {
    return RequestSmsCodeResponse(
      success: json['success'] == true,
      phone: json['phone']?.toString() ?? '',
      code: json['code']?.toString(),
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'].toString())
          : null,
    );
  }
}

class VerifySmsCodeResponse {
  final String accessToken;
  final String refreshToken;

  const VerifySmsCodeResponse({
    required this.accessToken,
    required this.refreshToken,
  });

  factory VerifySmsCodeResponse.fromJson(Map<String, dynamic> json) {
    return VerifySmsCodeResponse(
      accessToken: json['accessToken']?.toString() ?? '',
      refreshToken: json['refreshToken']?.toString() ?? '',
    );
  }
}

class RefreshTokenResponse {
  final String accessToken;
  final String refreshToken;

  const RefreshTokenResponse({
    required this.accessToken,
    required this.refreshToken,
  });

  factory RefreshTokenResponse.fromJson(Map<String, dynamic> json) {
    return RefreshTokenResponse(
      accessToken: json['accessToken']?.toString() ?? '',
      refreshToken: json['refreshToken']?.toString() ?? '',
    );
  }
}
