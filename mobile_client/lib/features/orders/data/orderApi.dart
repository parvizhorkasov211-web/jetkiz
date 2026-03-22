import 'package:jetkiz_mobile/core/network/apiClient.dart';
import 'package:jetkiz_mobile/features/orders/domain/createOrderPayload.dart';

class OrderApi {
  OrderApi(this._apiClient);

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> createOrder(CreateOrderPayload payload) async {
    final response = await _apiClient.dio.post(
      '/orders',
      data: payload.toJson(),
    );

    return _asMap(response.data);
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

    throw Exception('Invalid create order response format');
  }
}
