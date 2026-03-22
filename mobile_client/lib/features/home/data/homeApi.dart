/// Jetkiz mobile
/// Home API layer.
/// Uses only ApiClient.
/// Endpoints:
/// - GET /home-cms/public
/// - GET /restaurants/public/list
///
/// Notes for future GPT:
/// - home screen is backend-first
/// - pinned restaurants are loaded separately from restaurants/public/list
/// - categories may contain empty products[] and UI must handle that safely

import 'package:jetkiz_mobile/core/network/apiClient.dart';
import 'package:jetkiz_mobile/features/home/domain/homeData.dart';

class HomeApi {
  final ApiClient apiClient;

  const HomeApi(this.apiClient);

  Future<HomeData> getHomeData() async {
    // If your ApiClient exposes requests not through .dio,
    // replace only these 2 lines with your actual wrapper methods.
    final homeResponse = await apiClient.dio.get<Map<String, dynamic>>(
      '/home-cms/public',
    );
    final restaurantsResponse = await apiClient.dio.get<Map<String, dynamic>>(
      '/restaurants/public/list',
    );

    final homeJson = homeResponse.data ?? const <String, dynamic>{};
    final restaurantsJson =
        restaurantsResponse.data ?? const <String, dynamic>{};

    final promoJson = homeJson['promo'];
    final rawCategories = (homeJson['categories'] as List?) ?? const [];
    final rawPinned = (restaurantsJson['pinned'] as List?) ?? const [];

    return HomeData(
      promo: promoJson is Map<String, dynamic>
          ? HomePromo.fromJson(promoJson)
          : null,
      categories: rawCategories
          .whereType<Map<String, dynamic>>()
          .map(HomeCategoryData.fromJson)
          .toList(),
      pinnedRestaurants: rawPinned
          .whereType<Map<String, dynamic>>()
          .map(HomeRestaurantData.fromJson)
          .toList(),
    );
  }
}
