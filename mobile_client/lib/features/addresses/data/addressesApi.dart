import 'package:dio/dio.dart';
import 'package:jetkiz_mobile/core/network/apiClient.dart';
import 'package:jetkiz_mobile/features/addresses/domain/address.dart';

/// Jetkiz mobile context:
/// API layer for saved client addresses.
///
/// Endpoints:
/// - GET /addresses/my
/// - POST /addresses
/// - PUT /addresses/:id
/// - DELETE /addresses/:id
///
/// Important:
/// - Do not call Dio directly from UI.
/// - All requests for addresses must go through this API layer.
/// - When auth becomes enabled, token injection must stay centralized in ApiClient.
class AddressesApi {
  AddressesApi(this._apiClient);

  final ApiClient _apiClient;

  Future<List<Address>> getMyAddresses() async {
    final response = await _client.get('/addresses/my');
    final data = response.data;

    if (data is! List) {
      throw Exception('Invalid addresses response: expected list');
    }

    return data
        .whereType<Map<String, dynamic>>()
        .map(Address.fromJson)
        .toList();
  }

  Future<Address> createAddress(SaveAddressPayload payload) async {
    final response = await _client.post(
      '/addresses',
      data: payload.toJson(),
    );

    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw Exception('Invalid create address response');
    }

    return Address.fromJson(data);
  }

  Future<Address> updateAddress(
      String addressId, SaveAddressPayload payload) async {
    final response = await _client.put(
      '/addresses/$addressId',
      data: payload.toJson(),
    );

    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw Exception('Invalid update address response');
    }

    return Address.fromJson(data);
  }

  Future<void> deleteAddress(String addressId) async {
    await _client.delete('/addresses/$addressId');
  }

  Dio get _client {
    // If your ApiClient exposes dio via another property name, replace only this getter.
    return _apiClient.dio;
  }
}

class SaveAddressPayload {
  const SaveAddressPayload({
    required this.title,
    required this.address,
    this.floor,
    this.door,
    this.comment,
  });

  final String title;
  final String address;
  final String? floor;
  final String? door;
  final String? comment;

  Map<String, dynamic> toJson() {
    return {
      'title': title.trim(),
      'address': address.trim(),
      'floor': _normalizeOptional(floor),
      'door': _normalizeOptional(door),
      'comment': _normalizeOptional(comment),
    };
  }

  static String? _normalizeOptional(String? value) {
    final text = value?.trim() ?? '';
    return text.isEmpty ? null : text;
  }
}
