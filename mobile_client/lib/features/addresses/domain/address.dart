/// Jetkiz mobile context:
/// Address — сохранённый адрес клиента.
///
/// Backend contract confirmed:
/// - GET /addresses/my
/// - POST /addresses
/// - PUT /addresses/:id
/// - DELETE /addresses/:id
///
/// Address belongs to current authenticated user.
/// In checkout flow order must use addressId of selected saved address.
///
/// Confirmed backend fields:
/// - id: UUID string
/// - userId: UUID string
/// - title: string
/// - address: string
/// - floor: string | null
/// - door: string | null
/// - comment: string | null
/// - createdAt: ISO string
/// - updatedAt: ISO string
class Address {
  const Address({
    required this.id,
    required this.userId,
    required this.title,
    required this.address,
    required this.floor,
    required this.door,
    required this.comment,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String title;
  final String address;
  final String? floor;
  final String? door;
  final String? comment;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Address.fromJson(Map<String, dynamic> json) {
    return Address(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      address: json['address'] as String? ?? '',
      floor: _readNullableString(json['floor']),
      door: _readNullableString(json['door']),
      comment: _readNullableString(json['comment']),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  String get shortDetails {
    final parts = <String>[
      if ((floor ?? '').trim().isNotEmpty) 'Этаж $floor',
      if ((door ?? '').trim().isNotEmpty) 'Кв./офис $door',
    ];

    return parts.join(' • ');
  }

  String get fullSubtitle {
    final parts = <String>[
      address,
      if ((floor ?? '').trim().isNotEmpty) 'Этаж $floor',
      if ((door ?? '').trim().isNotEmpty) 'Кв./офис $door',
      if ((comment ?? '').trim().isNotEmpty) comment!.trim(),
    ];

    return parts.join(' • ');
  }

  Address copyWith({
    String? id,
    String? userId,
    String? title,
    String? address,
    String? floor,
    String? door,
    String? comment,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Address(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      address: address ?? this.address,
      floor: floor ?? this.floor,
      door: door ?? this.door,
      comment: comment ?? this.comment,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'address': address,
      'floor': floor,
      'door': door,
      'comment': comment,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  static String? _readNullableString(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }
}
