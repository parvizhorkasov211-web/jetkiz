import 'package:jetkiz_mobile/core/network/apiClient.dart';
import 'package:jetkiz_mobile/features/menu/domain/restaurantMenuData.dart';

/// Jetkiz mobile
/// Restaurant menu API layer.
///
/// Backend:
/// - GET /restaurants/:id/menu
///
/// Notes for future GPT sessions:
/// - Use this API from presentation.
/// - Do not call Dio directly from restaurantMenuPage.
/// - Current mobile menu source of truth is items[] from backend response.
class RestaurantMenuApi {
  final ApiClient _apiClient;

  RestaurantMenuApi(this._apiClient);

  Future<RestaurantMenuData> getRestaurantMenu({
    required String restaurantId,
  }) async {
    final response = await _apiClient.dio.get(
      '/restaurants/$restaurantId/menu',
    );

    final json = Map<String, dynamic>.from(response.data as Map);
    return RestaurantMenuData.fromJson(json);
  }
}
