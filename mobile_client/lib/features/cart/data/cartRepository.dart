import 'package:flutter/foundation.dart';

import '../domain/cartItem.dart';
import '../domain/cartState.dart';

/// JETKIZ MOBILE CONTEXT:
/// CartRepository — временный shared cart state для всего приложения.
/// Это НЕ backend корзина.
/// На текущем этапе:
/// - Add to cart работает локально
/// - CartPage читает state отсюда
/// - Checkout button пока не отправляет заказ в backend
///
/// В будущем:
/// - сюда можно добавить persistence
/// - сюда же можно подключить checkout / order flow
/// - при подтверждении backend контракта логика должна остаться централизованной
class CartRepository extends ChangeNotifier {
  CartRepository._();

  static final CartRepository instance = CartRepository._();

  CartState _state = CartState.empty();

  CartState get state => _state;

  List<CartItem> get items => _state.items;

  bool get isEmpty => _state.isEmpty;

  int get subtotal => _state.subtotal;

  int get total => _state.total;

  int get deliveryFee => _state.deliveryFee;

  int get totalQuantity => _state.totalQuantity;

  String? get restaurantId => _state.restaurantId;

  void addItem({
    required String productId,
    required String restaurantId,
    required String title,
    required int price,
    required int quantity,
    String? imageUrl,
    String? description,
    String? weight,
  }) {
    if (quantity <= 0) return;

    var nextItems = List<CartItem>.from(_state.items);

    final existingIndex =
        nextItems.indexWhere((item) => item.productId == productId);

    if (existingIndex >= 0) {
      final existing = nextItems[existingIndex];
      nextItems[existingIndex] = existing.copyWith(
        quantity: existing.quantity + quantity,
      );
    } else {
      nextItems.add(
        CartItem(
          productId: productId,
          restaurantId: restaurantId,
          title: title,
          price: price,
          quantity: quantity,
          imageUrl: imageUrl,
          description: description,
          weight: weight,
        ),
      );
    }

    _state = _state.copyWith(items: nextItems);
    notifyListeners();
  }

  void increment(String productId) {
    final nextItems = _state.items.map((item) {
      if (item.productId != productId) return item;
      return item.copyWith(quantity: item.quantity + 1);
    }).toList();

    _state = _state.copyWith(items: nextItems);
    notifyListeners();
  }

  void decrement(String productId) {
    final nextItems = _state.items
        .map((item) {
          if (item.productId != productId) return item;
          return item.copyWith(quantity: item.quantity - 1);
        })
        .where((item) => item.quantity > 0)
        .toList();

    _state = _state.copyWith(items: nextItems);
    notifyListeners();
  }

  void remove(String productId) {
    _state = _state.copyWith(
      items: _state.items.where((item) => item.productId != productId).toList(),
    );
    notifyListeners();
  }

  int quantityOf(String productId) {
    final match = _state.items.cast<CartItem?>().firstWhere(
          (item) => item?.productId == productId,
          orElse: () => null,
        );
    return match?.quantity ?? 0;
  }

  void clear() {
    _state = CartState.empty();
    notifyListeners();
  }
}
