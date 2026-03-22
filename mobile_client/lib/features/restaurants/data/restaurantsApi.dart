/*
  Restaurants API for Jetkiz mobile.

  Контекст для будущих сессий ChatGPT:
  - Использует реальный backend endpoint:
      GET /restaurants/public/list
  - Этот endpoint предназначен именно для клиентского приложения.
  - Не использовать GET /restaurants для мобильного клиента,
    потому что это admin list.
  - Ответ backend:
      {
        "pinned": [ ... ],
        "items": [ ... ]
      }
  - На главный экран сейчас загружаем обычный список items.
  - pinned сохранён для будущего отдельного блока "Популярное / Закреплённое".
*/

import 'package:jetkiz_mobile/core/network/apiClient.dart';
import 'package:jetkiz_mobile/features/restaurants/domain/restaurant.dart';

class RestaurantsApi {
  RestaurantsApi(this._apiClient);

  final ApiClient _apiClient;

  Future<RestaurantsResponse> getPublicRestaurants() async {
    final response = await _apiClient.dio.get('/restaurants/public/list');

    final data = response.data as Map<String, dynamic>? ?? <String, dynamic>{};

    final pinnedJson = (data['pinned'] as List<dynamic>? ?? const []);
    final itemsJson = (data['items'] as List<dynamic>? ?? const []);

    final pinned = pinnedJson
        .map((item) => Restaurant.fromJson(item as Map<String, dynamic>))
        .toList();

    final items = itemsJson
        .map((item) => Restaurant.fromJson(item as Map<String, dynamic>))
        .toList();

    return RestaurantsResponse(
      pinned: pinned,
      items: items,
    );
  }
}

class RestaurantsResponse {
  const RestaurantsResponse({
    required this.pinned,
    required this.items,
  });

  final List<Restaurant> pinned;
  final List<Restaurant> items;
}
