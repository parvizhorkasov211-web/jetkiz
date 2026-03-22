/// JETKIZ MOBILE CONTEXT:
/// CartItem — локальная модель корзины для mobile cart feature.
/// На текущем этапе backend endpoint корзины / checkout не подтвержден,
/// поэтому cart state хранится локально в приложении.
/// Источники данных для добавления товара в корзину:
/// - ProductDetailsPage
/// - в будущем CategoryProductsPage / RestaurantMenuPage
///
/// Важно:
/// - productId приходит из реального backend как UUID string
/// - restaurantId нужен для будущего правила "одна корзина = один ресторан"
/// - imageUrl уже должен быть полным URL или нормализован заранее моделью продукта
class CartItem {
  const CartItem({
    required this.productId,
    required this.restaurantId,
    required this.title,
    required this.price,
    required this.quantity,
    this.imageUrl,
    this.description,
    this.weight,
  });

  final String productId;
  final String restaurantId;
  final String title;
  final int price;
  final int quantity;
  final String? imageUrl;
  final String? description;
  final String? weight;

  int get totalPrice => price * quantity;

  CartItem copyWith({
    String? productId,
    String? restaurantId,
    String? title,
    int? price,
    int? quantity,
    String? imageUrl,
    String? description,
    String? weight,
  }) {
    return CartItem(
      productId: productId ?? this.productId,
      restaurantId: restaurantId ?? this.restaurantId,
      title: title ?? this.title,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      imageUrl: imageUrl ?? this.imageUrl,
      description: description ?? this.description,
      weight: weight ?? this.weight,
    );
  }
}
