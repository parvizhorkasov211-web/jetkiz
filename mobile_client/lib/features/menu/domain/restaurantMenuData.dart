import 'package:jetkiz_mobile/core/config/appConfig.dart';

/// Jetkiz mobile
/// Restaurant menu domain models.
///
/// Backend contract confirmed from real request:
/// - GET /restaurants/:id/menu
///
/// Confirmed top-level response fields:
/// - restaurant
/// - categories
/// - items
/// - products
///
/// Important notes for future GPT sessions:
/// - Mobile menu uses `items` as source of truth.
/// - Current backend response contains `products`, but it duplicates `items`.
///   Mobile ignores `products`.
/// - Real response currently does NOT contain grouped sections.
///   Grouping is done on mobile side using item.categoryId + categories[].
/// - imageUrl and images[].url can be relative /uploads/... paths.
///   UI must use normalized full URLs from these models.
/// - restaurantId is UUID string.
/// - categoryId may be null for uncategorized items.
class RestaurantMenuData {
  final RestaurantMenuRestaurant restaurant;
  final List<RestaurantMenuCategory> categories;
  final List<RestaurantMenuItem> items;

  const RestaurantMenuData({
    required this.restaurant,
    required this.categories,
    required this.items,
  });

  factory RestaurantMenuData.fromJson(Map<String, dynamic> json) {
    return RestaurantMenuData(
      restaurant: RestaurantMenuRestaurant.fromJson(
        (json['restaurant'] as Map<String, dynamic>?) ?? const {},
      ),
      categories: ((json['categories'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(RestaurantMenuCategory.fromJson)
          .toList(),
      items: ((json['items'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(RestaurantMenuItem.fromJson)
          .toList(),
    );
  }

  List<RestaurantMenuGroup> get groupedItems {
    final categoryMeta = <String, RestaurantMenuCategory>{};

    for (final category in categories) {
      categoryMeta[category.id] = category;
    }

    final groupedMap = <String, List<RestaurantMenuItem>>{};
    final uncategorized = <RestaurantMenuItem>[];

    for (final item in items) {
      if (item.categoryId == null || item.categoryId!.trim().isEmpty) {
        uncategorized.add(item);
        continue;
      }

      groupedMap.putIfAbsent(item.categoryId!, () => <RestaurantMenuItem>[]);
      groupedMap[item.categoryId!]!.add(item);
    }

    final result = <RestaurantMenuGroup>[];

    if (uncategorized.isNotEmpty) {
      result.add(
        RestaurantMenuGroup(
          category: const RestaurantMenuCategory(
            id: 'uncategorized',
            code: 'uncategorized',
            titleRu: 'Без категории',
            titleKk: 'Санатсыз',
            sortOrder: 999999,
            iconUrl: null,
          ),
          items: uncategorized,
        ),
      );
    }

    final sortedEntries = groupedMap.entries.toList()
      ..sort((a, b) {
        final aCategory = categoryMeta[a.key];
        final bCategory = categoryMeta[b.key];

        final aOrder =
            aCategory?.sortOrder ?? a.value.first.categorySortOrder ?? 999999;
        final bOrder =
            bCategory?.sortOrder ?? b.value.first.categorySortOrder ?? 999999;

        if (aOrder != bOrder) {
          return aOrder.compareTo(bOrder);
        }

        final aTitle = aCategory?.title ?? a.value.first.categoryTitle;
        final bTitle = bCategory?.title ?? b.value.first.categoryTitle;

        return aTitle.compareTo(bTitle);
      });

    for (final entry in sortedEntries) {
      final firstItem = entry.value.first;

      final category = categoryMeta[entry.key] ??
          RestaurantMenuCategory(
            id: entry.key,
            code: firstItem.categoryCode ?? '',
            titleRu: firstItem.categoryNameRu ?? 'Без названия',
            titleKk: firstItem.categoryNameKk ??
                firstItem.categoryNameRu ??
                'Атаусыз',
            sortOrder: firstItem.categorySortOrder ?? 999999,
            iconUrl: null,
          );

      result.add(
        RestaurantMenuGroup(
          category: category,
          items: entry.value,
        ),
      );
    }

    return result;
  }
}

class RestaurantMenuRestaurant {
  final String id;
  final int? number;
  final String status;
  final String nameRu;
  final String nameKk;
  final String slug;

  const RestaurantMenuRestaurant({
    required this.id,
    required this.number,
    required this.status,
    required this.nameRu,
    required this.nameKk,
    required this.slug,
  });

  factory RestaurantMenuRestaurant.fromJson(Map<String, dynamic> json) {
    return RestaurantMenuRestaurant(
      id: (json['id'] ?? '').toString(),
      number: json['number'] is num ? (json['number'] as num).toInt() : null,
      status: (json['status'] ?? '').toString(),
      nameRu: (json['nameRu'] ?? '').toString(),
      nameKk: (json['nameKk'] ?? '').toString(),
      slug: (json['slug'] ?? '').toString(),
    );
  }

  String get displayName => nameRu.isNotEmpty ? nameRu : nameKk;
}

class RestaurantMenuCategory {
  final String id;
  final String code;
  final String titleRu;
  final String titleKk;
  final int sortOrder;
  final String? iconUrl;

  const RestaurantMenuCategory({
    required this.id,
    required this.code,
    required this.titleRu,
    required this.titleKk,
    required this.sortOrder,
    required this.iconUrl,
  });

  factory RestaurantMenuCategory.fromJson(Map<String, dynamic> json) {
    return RestaurantMenuCategory(
      id: (json['id'] ?? '').toString(),
      code: (json['code'] ?? '').toString(),
      titleRu: (json['titleRu'] ?? '').toString(),
      titleKk: (json['titleKk'] ?? '').toString(),
      sortOrder:
          json['sortOrder'] is num ? (json['sortOrder'] as num).toInt() : 0,
      iconUrl: _normalizeUrl(json['iconUrl']),
    );
  }

  String get title => titleRu.isNotEmpty ? titleRu : titleKk;
}

class RestaurantMenuItem {
  final String id;
  final String titleRu;
  final String titleKk;
  final int price;
  final String? imageUrl;
  final bool isAvailable;
  final String? categoryId;
  final String? categoryNameRu;
  final String? categoryNameKk;
  final String? categoryCode;
  final int? categorySortOrder;
  final String? weight;
  final String? composition;
  final String? description;
  final bool isDrink;
  final List<RestaurantMenuItemImage> images;

  const RestaurantMenuItem({
    required this.id,
    required this.titleRu,
    required this.titleKk,
    required this.price,
    required this.imageUrl,
    required this.isAvailable,
    required this.categoryId,
    required this.categoryNameRu,
    required this.categoryNameKk,
    required this.categoryCode,
    required this.categorySortOrder,
    required this.weight,
    required this.composition,
    required this.description,
    required this.isDrink,
    required this.images,
  });

  factory RestaurantMenuItem.fromJson(Map<String, dynamic> json) {
    return RestaurantMenuItem(
      id: (json['id'] ?? '').toString(),
      titleRu: (json['titleRu'] ?? '').toString(),
      titleKk: (json['titleKk'] ?? '').toString(),
      price: json['price'] is num ? (json['price'] as num).toInt() : 0,
      imageUrl: _normalizeUrl(json['imageUrl']),
      isAvailable: json['isAvailable'] == true,
      categoryId: _nullableString(json['categoryId']),
      categoryNameRu: _nullableString(json['categoryNameRu']),
      categoryNameKk: _nullableString(json['categoryNameKk']),
      categoryCode: _nullableString(json['categoryCode']),
      categorySortOrder: json['categorySortOrder'] is num
          ? (json['categorySortOrder'] as num).toInt()
          : null,
      weight: _nullableString(json['weight']),
      composition: _nullableString(json['composition']),
      description: _nullableString(json['description']),
      isDrink: json['isDrink'] == true,
      images: ((json['images'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(RestaurantMenuItemImage.fromJson)
          .toList(),
    );
  }

  String get title => titleRu.isNotEmpty ? titleRu : titleKk;

  String get categoryTitle {
    if ((categoryNameRu ?? '').trim().isNotEmpty) {
      return categoryNameRu!.trim();
    }

    if ((categoryNameKk ?? '').trim().isNotEmpty) {
      return categoryNameKk!.trim();
    }

    return 'Без категории';
  }

  String? get mainImageUrl {
    if (images.isNotEmpty) {
      final main = images.where((e) => e.isMain).toList();
      if (main.isNotEmpty) {
        return main.first.url;
      }
      return images.first.url;
    }

    return imageUrl;
  }

  String get compactMetaText {
    final parts = <String>[];

    if ((composition ?? '').trim().isNotEmpty) {
      parts.add(composition!.trim());
    } else if ((description ?? '').trim().isNotEmpty) {
      parts.add(description!.trim());
    }

    if ((weight ?? '').trim().isNotEmpty) {
      parts.add(weight!.trim());
    }

    return parts.join('\n');
  }
}

class RestaurantMenuItemImage {
  final String id;
  final String url;
  final bool isMain;
  final int sortOrder;

  const RestaurantMenuItemImage({
    required this.id,
    required this.url,
    required this.isMain,
    required this.sortOrder,
  });

  factory RestaurantMenuItemImage.fromJson(Map<String, dynamic> json) {
    return RestaurantMenuItemImage(
      id: (json['id'] ?? '').toString(),
      url: _normalizeUrl(json['url']) ?? '',
      isMain: json['isMain'] == true,
      sortOrder:
          json['sortOrder'] is num ? (json['sortOrder'] as num).toInt() : 0,
    );
  }
}

class RestaurantMenuGroup {
  final RestaurantMenuCategory category;
  final List<RestaurantMenuItem> items;

  const RestaurantMenuGroup({
    required this.category,
    required this.items,
  });
}

String? _nullableString(dynamic value) {
  if (value == null) return null;
  final result = value.toString().trim();
  return result.isEmpty ? null : result;
}

String? _normalizeUrl(dynamic value) {
  final raw = _nullableString(value);
  if (raw == null) return null;

  if (raw.startsWith('http://') || raw.startsWith('https://')) {
    return raw;
  }

  return '${AppConfig.baseUrl}$raw';
}
