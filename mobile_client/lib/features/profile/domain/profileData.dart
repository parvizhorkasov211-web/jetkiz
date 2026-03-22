import 'package:equatable/equatable.dart';
import 'package:jetkiz_mobile/core/config/appConfig.dart';

/// ProfileData
///
/// Контекст для будущих сессий ChatGPT:
/// - Модель построена на подтверждённом backend contract:
///   GET /users/me
/// - Подтверждённые поля:
///   id, phone, firstName, lastName, email, avatarUrl, name, createdAt
/// - avatarUrl может быть null или относительным путём /uploads/...
/// - Для UI полный URL нужно брать через resolvedAvatarUrl.
class ProfileData extends Equatable {
  final String id;
  final String phone;
  final String? firstName;
  final String? lastName;
  final String? email;
  final String? avatarUrl;
  final String? name;
  final DateTime createdAt;

  const ProfileData({
    required this.id,
    required this.phone,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.avatarUrl,
    required this.name,
    required this.createdAt,
  });

  factory ProfileData.fromJson(Map<String, dynamic> json) {
    return ProfileData(
      id: json['id'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      firstName: json['firstName'] as String?,
      lastName: json['lastName'] as String?,
      email: json['email'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      name: json['name'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  String? get resolvedAvatarUrl {
    if (avatarUrl == null || avatarUrl!.trim().isEmpty) {
      return null;
    }

    final raw = avatarUrl!.trim();

    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return raw;
    }

    return '${AppConfig.baseUrl}$raw';
  }

  String get displayTitle {
    final trimmedName = name?.trim();
    if (trimmedName != null && trimmedName.isNotEmpty) {
      return trimmedName;
    }

    return 'Клиент Jetkiz';
  }

  String get displaySubtitle {
    return phone.trim().isEmpty ? 'Профиль клиента' : phone;
  }

  ProfileData copyWith({
    String? id,
    String? phone,
    String? firstName,
    String? lastName,
    String? email,
    String? avatarUrl,
    String? name,
    DateTime? createdAt,
  }) {
    return ProfileData(
      id: id ?? this.id,
      phone: phone ?? this.phone,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        phone,
        firstName,
        lastName,
        email,
        avatarUrl,
        name,
        createdAt,
      ];
}
