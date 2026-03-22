/// Jetkiz mobile
/// Home screen backend contract.
/// Uses:
/// - GET /home-cms/public
/// - GET /restaurants/public/list
///
/// Notes for future GPT:
/// - promo comes from Home CMS
/// - categories are home sections configured in admin
/// - each category may contain products[]
/// - pinned restaurants come from restaurants/public/list -> pinned
/// - image urls can be relative (/uploads/...) and must be resolved with AppConfig.baseUrl

import 'package:jetkiz_mobile/core/config/appConfig.dart';

class HomePromo {
  final String titleRu;
  final String titleKk;
  final String? imageUrl;
  final bool isActive;

  const HomePromo({
    required this.titleRu,
    required this.titleKk,
    required this.imageUrl,
    required this.isActive,
  });

  factory HomePromo.fromJson(Map<String, dynamic> json) {
    return HomePromo(
      titleRu: (json['titleRu'] ?? '').toString(),
      titleKk: (json['titleKk'] ?? '').toString(),
      imageUrl: json['imageUrl']?.toString(),
      isActive: json['isActive'] == true,
    );
  }

  String get title => titleRu.isNotEmpty ? titleRu : titleKk;

  String? get fullImageUrl {
    final value = imageUrl;
    if (value == null || value.isEmpty) return null;
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    return '${AppConfig.baseUrl}$value';
  }
}

class HomeCategoryProductRestaurant {
  final String id;
  final String nameRu;
  final String nameKk;

  const HomeCategoryProductRestaurant({
    required this.id,
    required this.nameRu,
    required this.nameKk,
  });

  factory HomeCategoryProductRestaurant.fromJson(Map<String, dynamic> json) {
    return HomeCategoryProductRestaurant(
      id: (json['id'] ?? '').toString(),
      nameRu: (json['nameRu'] ?? '').toString(),
      nameKk: (json['nameKk'] ?? '').toString(),
    );
  }

  String get name => nameRu.isNotEmpty ? nameRu : nameKk;
}

class HomeCategoryProductData {
  final String id;
  final String titleRu;
  final String titleKk;
  final int price;
  final String? imageUrl;
  final bool isAvailable;
  final String restaurantId;
  final HomeCategoryProductRestaurant restaurant;

  const HomeCategoryProductData({
    required this.id,
    required this.titleRu,
    required this.titleKk,
    required this.price,
    required this.imageUrl,
    required this.isAvailable,
    required this.restaurantId,
    required this.restaurant,
  });

  factory HomeCategoryProductData.fromJson(Map<String, dynamic> json) {
    return HomeCategoryProductData(
      id: (json['id'] ?? '').toString(),
      titleRu: (json['titleRu'] ?? '').toString(),
      titleKk: (json['titleKk'] ?? '').toString(),
      price: (json['price'] as num?)?.toInt() ?? 0,
      imageUrl: json['imageUrl']?.toString(),
      isAvailable: json['isAvailable'] == true,
      restaurantId: (json['restaurantId'] ?? '').toString(),
      restaurant: HomeCategoryProductRestaurant.fromJson(
        (json['restaurant'] as Map<String, dynamic>?) ?? const {},
      ),
    );
  }

  String get title => titleRu.isNotEmpty ? titleRu : titleKk;

  String? get fullImageUrl {
    final value = imageUrl;
    if (value == null || value.isEmpty) return null;
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    return '${AppConfig.baseUrl}$value';
  }
}

class HomeCategoryProductLink {
  final String id;
  final String productId;
  final int sortOrder;
  final bool isActive;
  final HomeCategoryProductData? product;

  const HomeCategoryProductLink({
    required this.id,
    required this.productId,
    required this.sortOrder,
    required this.isActive,
    required this.product,
  });

  factory HomeCategoryProductLink.fromJson(Map<String, dynamic> json) {
    return HomeCategoryProductLink(
      id: (json['id'] ?? '').toString(),
      productId: (json['productId'] ?? '').toString(),
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      isActive: json['isActive'] == true,
      product: json['product'] is Map<String, dynamic>
          ? HomeCategoryProductData.fromJson(
              json['product'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}

class HomeCategoryData {
  final String id;
  final String titleRu;
  final String titleKk;
  final String? imageUrl;
  final int sortOrder;
  final bool isActive;
  final List<HomeCategoryProductLink> products;

  const HomeCategoryData({
    required this.id,
    required this.titleRu,
    required this.titleKk,
    required this.imageUrl,
    required this.sortOrder,
    required this.isActive,
    required this.products,
  });

  factory HomeCategoryData.fromJson(Map<String, dynamic> json) {
    final rawProducts = (json['products'] as List?) ?? const [];

    return HomeCategoryData(
      id: (json['id'] ?? '').toString(),
      titleRu: (json['titleRu'] ?? '').toString(),
      titleKk: (json['titleKk'] ?? '').toString(),
      imageUrl: json['imageUrl']?.toString(),
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      isActive: json['isActive'] == true,
      products: rawProducts
          .whereType<Map<String, dynamic>>()
          .map(HomeCategoryProductLink.fromJson)
          .toList(),
    );
  }

  String get title => titleRu.isNotEmpty ? titleRu : titleKk;

  String? get fullImageUrl {
    final value = imageUrl;
    if (value == null || value.isEmpty) return null;
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    return '${AppConfig.baseUrl}$value';
  }
}

class HomeRestaurantData {
  final String id;
  final int number;
  final String slug;
  final String nameRu;
  final String nameKk;
  final String? phone;
  final String? address;
  final String? workingHours;
  final String? coverImageUrl;
  final double ratingAvg;
  final int ratingCount;
  final String status;
  final bool isInApp;
  final bool isPinned;
  final int sortOrder;
  final bool useRandom;

  const HomeRestaurantData({
    required this.id,
    required this.number,
    required this.slug,
    required this.nameRu,
    required this.nameKk,
    required this.phone,
    required this.address,
    required this.workingHours,
    required this.coverImageUrl,
    required this.ratingAvg,
    required this.ratingCount,
    required this.status,
    required this.isInApp,
    required this.isPinned,
    required this.sortOrder,
    required this.useRandom,
  });

  factory HomeRestaurantData.fromJson(Map<String, dynamic> json) {
    return HomeRestaurantData(
      id: (json['id'] ?? '').toString(),
      number: (json['number'] as num?)?.toInt() ?? 0,
      slug: (json['slug'] ?? '').toString(),
      nameRu: (json['nameRu'] ?? '').toString(),
      nameKk: (json['nameKk'] ?? '').toString(),
      phone: json['phone']?.toString(),
      address: json['address']?.toString(),
      workingHours: json['workingHours']?.toString(),
      coverImageUrl: json['coverImageUrl']?.toString(),
      ratingAvg: (json['ratingAvg'] as num?)?.toDouble() ?? 0,
      ratingCount: (json['ratingCount'] as num?)?.toInt() ?? 0,
      status: (json['status'] ?? '').toString(),
      isInApp: json['isInApp'] == true,
      isPinned: json['isPinned'] == true,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      useRandom: json['useRandom'] == true,
    );
  }

  String get name => nameRu.isNotEmpty ? nameRu : nameKk;

  String? get fullCoverImageUrl {
    final value = coverImageUrl;
    if (value == null || value.isEmpty) return null;
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    return '${AppConfig.baseUrl}$value';
  }
}

class HomeData {
  final HomePromo? promo;
  final List<HomeCategoryData> categories;
  final List<HomeRestaurantData> pinnedRestaurants;

  const HomeData({
    required this.promo,
    required this.categories,
    required this.pinnedRestaurants,
  });
}
