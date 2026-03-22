class CreateOrderItemPayload {
  const CreateOrderItemPayload({
    required this.productId,
    required this.quantity,
  });

  final String productId;
  final int quantity;

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'quantity': quantity,
    };
  }
}

class CreateOrderPayload {
  const CreateOrderPayload({
    required this.restaurantId,
    required this.addressId,
    required this.phone,
    required this.leaveAtDoor,
    required this.items,
    this.comment,
    this.promoCode,
  });

  final String restaurantId;
  final String addressId;
  final String phone;
  final bool leaveAtDoor;
  final String? comment;
  final String? promoCode;
  final List<CreateOrderItemPayload> items;

  Map<String, dynamic> toJson() {
    return {
      'restaurantId': restaurantId,
      'addressId': addressId,
      'phone': phone,
      'leaveAtDoor': leaveAtDoor,
      'comment': comment,
      'promoCode': promoCode,
      'items': items.map((item) => item.toJson()).toList(),
    };
  }
}