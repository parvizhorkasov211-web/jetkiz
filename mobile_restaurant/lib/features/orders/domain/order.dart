class Order {
  final String id;
  final String customerName;
  final String status;
  final double totalPrice;
  final String createdAt;
  final int itemsCount;

  const Order({
    required this.id,
    required this.customerName,
    required this.status,
    required this.totalPrice,
    required this.createdAt,
    required this.itemsCount,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'].toString(),
      customerName: json['customerName']?.toString() ?? 'Клиент',
      status: json['status']?.toString() ?? 'NEW',
      totalPrice: (json['totalPrice'] as num?)?.toDouble() ?? 0,
      createdAt: json['createdAt']?.toString() ?? '',
      itemsCount: (json['itemsCount'] as num?)?.toInt() ?? 0,
    );
  }
}
