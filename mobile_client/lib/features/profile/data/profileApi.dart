import 'dart:io';

import 'package:dio/dio.dart';
import 'package:jetkiz_mobile/core/network/apiClient.dart';
import 'package:jetkiz_mobile/features/profile/domain/profileData.dart';

/// ProfileApi
///
/// ВАЖНО:
/// - Токен НЕ передаётся вручную
/// - Он уже установлен в ApiClient
class ProfileApi {
  final ApiClient _apiClient;

  ProfileApi(this._apiClient);

  Future<ProfileData> getMe() async {
    final response = await _apiClient.dio.get('/users/me');

    return ProfileData.fromJson(_asMap(response.data));
  }

  Future<ProfileData> uploadMyAvatar(File file) async {
    final fileName = file.path.split(Platform.pathSeparator).last;

    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        file.path,
        filename: fileName,
      ),
    });

    final response = await _apiClient.dio.post(
      '/users/me/avatar',
      data: formData,
      options: Options(
        contentType: 'multipart/form-data',
      ),
    );

    final data = _asMap(response.data);
    final avatarUrl = data['avatarUrl'] as String?;

    final current = await getMe();
    return current.copyWith(avatarUrl: avatarUrl);
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return value.map(
        (key, val) => MapEntry(key.toString(), val),
      );
    }

    throw Exception('Invalid profile response format');
  }
}
