/*
  Restaurant domain model for Jetkiz mobile.

  Контекст для будущих сессий ChatGPT:
  - Модель построена по реальному backend ответу:
      GET /restaurants/public/list
  - Ответ backend имеет структуру:
      {
        "pinned": [ ...restaurants ],
        "items": [ ...restaurants ]
      }
  - restaurant.id приходит как UUID string
  - coverImageUrl приходит как относительный путь, например:
      /uploads/restaurants/1773049462082-991858577.jpg
  - Для отображения изображения на клиенте нужен полный URL:
      http://127.0.0.1:3001 + coverImageUrl
  - address может быть null
  - workingHours может быть null
  - ratingAvg может быть int или double, поэтому приводим к double
*/

import 'package:equatable/equatable.dart';
import 'package:jetkiz_mobile/core/config/appConfig.dart';

class Restaurant extends Equatable {
  const Restaurant({
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
    required this.restaurantCommissionPctOverride,
    required this.isPinned,
    required this.sortOrder,
    required this.useRandom,
  });

  final String id;
  final int number;
  final String slug;
  final String nameRu;
  final String nameKk;
  final String phone;
  final String? address;
  final String? workingHours;
  final String? coverImageUrl;
  final double ratingAvg;
  final int ratingCount;
  final String status;
  final bool isInApp;
  final num? restaurantCommissionPctOverride;
  final bool isPinned;
  final int sortOrder;
  final bool useRandom;

  bool get isOpen => status.toUpperCase() == 'OPEN';

  String get displayName => nameRu.trim().isNotEmpty ? nameRu : nameKk;

  String? get fullCoverImageUrl {
    if (coverImageUrl == null || coverImageUrl!.isEmpty) {
      return null;
    }

    if (coverImageUrl!.startsWith('http://') ||
        coverImageUrl!.startsWith('https://')) {
      return coverImageUrl;
    }

    return '${AppConfig.baseUrl}${coverImageUrl!}';
  }

  factory Restaurant.fromJson(Map<String, dynamic> json) {
    return Restaurant(
      id: json['id'] as String? ?? '',
      number: (json['number'] as num?)?.toInt() ?? 0,
      slug: json['slug'] as String? ?? '',
      nameRu: json['nameRu'] as String? ?? '',
      nameKk: json['nameKk'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      address: json['address'] as String?,
      workingHours: json['workingHours'] as String?,
      coverImageUrl: json['coverImageUrl'] as String?,
      ratingAvg: (json['ratingAvg'] as num?)?.toDouble() ?? 0,
      ratingCount: (json['ratingCount'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? '',
      isInApp: json['isInApp'] as bool? ?? false,
      restaurantCommissionPctOverride:
          json['restaurantCommissionPctOverride'] as num?,
      isPinned: json['isPinned'] as bool? ?? false,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      useRandom: json['useRandom'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [
        id,
        number,
        slug,
        nameRu,
        nameKk,
        phone,
        address,
        workingHours,
        coverImageUrl,
        ratingAvg,
        ratingCount,
        status,
        isInApp,
        restaurantCommissionPctOverride,
        isPinned,
        sortOrder,
        useRandom,
      ];
}
