import 'cartItem.dart';

/// JETKIZ MOBILE CONTEXT:
/// CartState — агрегированное состояние корзины.
/// Пока checkout backend contract не подтвержден.
/// deliveryFee сейчас локальный dev-параметр для UI экрана корзины.
/// Когда будет подтвержден backend checkout / delivery pricing,
/// это значение нужно брать из реального backend, а не держать константой.
class CartState {
  const CartState({
    required this.items,
    required this.deliveryFee,
  });

  final List<CartItem> items;
  final int deliveryFee;

  bool get isEmpty => items.isEmpty;

  int get subtotal => items.fold(0, (sum, item) => sum + item.totalPrice);

  int get total => subtotal + deliveryFee;

  int get totalQuantity => items.fold(0, (sum, item) => sum + item.quantity);

  String? get restaurantId => items.isEmpty ? null : items.first.restaurantId;

  CartState copyWith({
    List<CartItem>? items,
    int? deliveryFee,
  }) {
    return CartState(
      items: items ?? this.items,
      deliveryFee: deliveryFee ?? this.deliveryFee,
    );
  }

  factory CartState.empty() {
    return const CartState(
      items: [],
      deliveryFee: 100,
    );
  }
}
