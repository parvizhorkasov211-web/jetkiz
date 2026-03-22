import '../../../core/network/api_client.dart';
import '../domain/order.dart';

class OrdersRepository {
  final ApiClient _apiClient;

  OrdersRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  Future<List<Order>> getOrders() async {
    try {
      final response = await _apiClient.get('/restaurant/orders');

      if (response is List) {
        return response
            .map((item) => Order.fromJson(item as Map<String, dynamic>))
            .toList();
      }

      return _mockOrders();
    } catch (_) {
      return _mockOrders();
    }
  }

  List<Order> _mockOrders() {
    return const [
      Order(
        id: '101',
        customerName: 'Алишер',
        status: 'NEW',
        totalPrice: 4500,
        createdAt: '19:10',
        itemsCount: 3,
      ),
      Order(
        id: '102',
        customerName: 'Мадина',
        status: 'COOKING',
        totalPrice: 8200,
        createdAt: '19:04',
        itemsCount: 5,
      ),
      Order(
        id: '103',
        customerName: 'Руслан',
        status: 'READY',
        totalPrice: 3900,
        createdAt: '18:58',
        itemsCount: 2,
      ),
    ];
  }
}
