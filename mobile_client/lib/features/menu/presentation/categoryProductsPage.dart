import 'package:flutter/material.dart';
import 'package:jetkiz_mobile/core/network/apiClient.dart';
import 'package:jetkiz_mobile/features/cart/data/cartRepository.dart';
import 'package:jetkiz_mobile/features/cart/presentation/widgets/cartSummaryBar.dart';
import 'package:jetkiz_mobile/features/home/domain/homeData.dart';
import 'package:jetkiz_mobile/features/menu/data/financeConfigApi.dart';
import 'package:jetkiz_mobile/features/menu/domain/restaurantMenuData.dart';
import 'package:jetkiz_mobile/features/menu/presentation/productDetailsPage.dart';
import 'package:jetkiz_mobile/features/menu/presentation/restaurantMenuPage.dart';

// Jetkiz mobile
// Category products page.
//
// Current backend source:
// - HomePage loads GET /home-cms/public
// - this page receives already loaded HomeCategoryData
//
// Important note for future GPT:
// - current project stage does not have separately confirmed public category
//   endpoint for full screen loading
// - do not invent new API here until backend confirms route
// - category.id is UUID string
// - category.products[] comes from Home CMS category-product links
// - link.product contains actual product data
//
// Navigation:
// - opened from HomePage category tap
// - restaurant title tap -> open RestaurantMenuPage with restaurant.id
// - product card tap -> open ProductDetailsPage
// - filter tap -> local restaurant picker from already loaded category products
// - product quantity controls are connected to shared cart state
//
// UI rules:
// - restaurant title must appear once per group, not on every product card
// - products are grouped by restaurant
// - inside each restaurant group products are rendered in 2 columns
// - product image is square
// - do not render fake composition / grams text from hardcoded demo data
// - only render backend-confirmed fields
//
// Backend limitation note:
// - current GET /home-cms/public contract does NOT confirm description / composition / weight
// - because of that this page must not invent description / grams text
// - when real menu/product details contract is confirmed, add those fields from backend only
class CategoryProductsPage extends StatefulWidget {
  const CategoryProductsPage({
    super.key,
    required this.category,
  });

  final HomeCategoryData category;

  @override
  State<CategoryProductsPage> createState() => _CategoryProductsPageState();
}

class _CategoryProductsPageState extends State<CategoryProductsPage> {
  final Set<String> _favoriteProductIds = <String>{};
  String? _selectedRestaurantId;

  late final FinanceConfigApi _financeConfigApi;
  int _deliveryFee = 0;

  @override
  void initState() {
    super.initState();
    _financeConfigApi = FinanceConfigApi(ApiClient());
    _loadDeliveryFee();
  }

  Future<void> _loadDeliveryFee() async {
    try {
      final config = await _financeConfigApi.getFinanceConfig();
      if (!mounted) return;

      setState(() {
        _deliveryFee = config.activeDeliveryFee;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _deliveryFee = 0;
      });
    }
  }

  int _getQuantity(String productId) {
    return CartRepository.instance.quantityOf(productId);
  }

  void _incrementProduct(HomeCategoryProductData product) {
    CartRepository.instance.addItem(
      productId: product.id,
      restaurantId: product.restaurant.id,
      title: product.title,
      price: product.price,
      quantity: 1,
      imageUrl: product.fullImageUrl,
    );

    setState(() {});
  }

  void _decrementProduct(HomeCategoryProductData product) {
    CartRepository.instance.decrement(product.id);
    setState(() {});
  }

  void _toggleFavorite(String productId) {
    setState(() {
      if (_favoriteProductIds.contains(productId)) {
        _favoriteProductIds.remove(productId);
      } else {
        _favoriteProductIds.add(productId);
      }
    });
  }

  RestaurantMenuItem _mapHomeProductToMenuItem(
    HomeCategoryProductData product,
  ) {
    return RestaurantMenuItem(
      id: product.id,
      titleRu: product.titleRu,
      titleKk: product.titleKk,
      price: product.price,
      imageUrl: product.fullImageUrl,
      isAvailable: product.isAvailable,
      categoryId: null,
      categoryNameRu: null,
      categoryNameKk: null,
      categoryCode: null,
      categorySortOrder: null,
      weight: null,
      composition: null,
      description: null,
      isDrink: false,
      images: const <RestaurantMenuItemImage>[],
    );
  }

  void _openProductDetails(HomeCategoryProductData product) {
    final mapped = _mapHomeProductToMenuItem(product);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductDetailsPage(
          product: mapped,
          restaurantName: product.restaurant.name,
          restaurantId: product.restaurant.id,
        ),
      ),
    );
  }

  List<HomeCategoryProductData> _getValidProducts() {
    return widget.category.products
        .where((link) => link.product != null)
        .map((link) => link.product!)
        .toList();
  }

  List<_RestaurantGroup> _buildRestaurantGroups() {
    final validProducts = _getValidProducts();
    final Map<String, List<HomeCategoryProductData>> grouped =
        <String, List<HomeCategoryProductData>>{};
    final Map<String, HomeCategoryProductRestaurant> restaurantsById =
        <String, HomeCategoryProductRestaurant>{};

    for (final product in validProducts) {
      if (_selectedRestaurantId != null &&
          product.restaurant.id != _selectedRestaurantId) {
        continue;
      }

      grouped.putIfAbsent(
        product.restaurant.id,
        () => <HomeCategoryProductData>[],
      );
      grouped[product.restaurant.id]!.add(product);
      restaurantsById[product.restaurant.id] = product.restaurant;
    }

    final List<_RestaurantGroup> groups = <_RestaurantGroup>[];

    for (final entry in grouped.entries) {
      final restaurant = restaurantsById[entry.key];
      if (restaurant == null) {
        continue;
      }

      groups.add(
        _RestaurantGroup(
          restaurant: restaurant,
          products: entry.value,
        ),
      );
    }

    return groups;
  }

  Future<void> _openRestaurantPicker() async {
    final validProducts = _getValidProducts();
    final Map<String, HomeCategoryProductRestaurant> uniqueRestaurants =
        <String, HomeCategoryProductRestaurant>{};

    for (final product in validProducts) {
      uniqueRestaurants[product.restaurant.id] = product.restaurant;
    }

    final restaurants = uniqueRestaurants.values.toList();

    final selectedId = await showModalBottomSheet<String?>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Выбрать ресторан',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 14),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Все рестораны',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  trailing: _selectedRestaurantId == null
                      ? const Icon(
                          Icons.check_rounded,
                          color: Color(0xFF489F2A),
                        )
                      : null,
                  onTap: () => Navigator.of(context).pop(null),
                ),
                ...restaurants.map(
                  (restaurant) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      restaurant.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    trailing: _selectedRestaurantId == restaurant.id
                        ? const Icon(
                            Icons.check_rounded,
                            color: Color(0xFF489F2A),
                          )
                        : null,
                    onTap: () => Navigator.of(context).pop(restaurant.id),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _selectedRestaurantId = selectedId;
    });
  }

  int get _basketItemsCount {
    return CartRepository.instance.totalQuantity;
  }

  int get _basketTotal {
    return CartRepository.instance.subtotal;
  }

  @override
  Widget build(BuildContext context) {
    final groups = _buildRestaurantGroups();
    final hasBasket = _basketItemsCount > 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: SafeArea(
        child: groups.isEmpty
            ? _EmptyCategoryState(
                categoryTitle: widget.category.title,
                onFilterTap: _openRestaurantPicker,
              )
            : Column(
                children: [
                  _CategoryHeader(
                    title: widget.category.title,
                    onBackTap: () => Navigator.of(context).pop(),
                    onFilterTap: _openRestaurantPicker,
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: EdgeInsets.fromLTRB(
                        15,
                        8,
                        15,
                        hasBasket ? 190 : 24,
                      ),
                      itemCount: groups.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 18),
                      itemBuilder: (context, index) {
                        final group = groups[index];

                        return _RestaurantSection(
                          group: group,
                          favoriteProductIds: _favoriteProductIds,
                          getQuantity: _getQuantity,
                          onRestaurantTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => RestaurantMenuPage(
                                  restaurantId: group.restaurant.id,
                                  restaurantName: group.restaurant.name,
                                ),
                              ),
                            );
                          },
                          onProductTap: _openProductDetails,
                          onFavoriteTap: _toggleFavorite,
                          onAddTap: (productId) {
                            final product = group.products.firstWhere(
                              (item) => item.id == productId,
                            );
                            _incrementProduct(product);
                          },
                          onIncrementTap: (productId) {
                            final product = group.products.firstWhere(
                              (item) => item.id == productId,
                            );
                            _incrementProduct(product);
                          },
                          onDecrementTap: (productId) {
                            final product = group.products.firstWhere(
                              (item) => item.id == productId,
                            );
                            _decrementProduct(product);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
      bottomNavigationBar: hasBasket
          ? CartSummaryBar(
              itemsCount: _basketItemsCount,
              itemsTotal: _basketTotal,
              deliveryFee: _deliveryFee,
              onNextTap: () {
                Navigator.of(context).pushNamed('/cart');
              },
            )
          : null,
    );
  }
}

class _RestaurantGroup {
  const _RestaurantGroup({
    required this.restaurant,
    required this.products,
  });

  final HomeCategoryProductRestaurant restaurant;
  final List<HomeCategoryProductData> products;
}

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({
    required this.title,
    required this.onBackTap,
    required this.onFilterTap,
  });

  final String title;
  final VoidCallback onBackTap;
  final VoidCallback onFilterTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: onBackTap,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    Icons.arrow_back_rounded,
                    size: 30,
                    color: Colors.black,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text(
                'jetkiz',
                style: TextStyle(
                  color: Color(0xFF489F2A),
                  fontSize: 16,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: onFilterTap,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Row(
                    children: [
                      Text(
                        'Выбрать по ресторану',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 10,
                          fontWeight: FontWeight.w400,
                          height: 1.2,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.tune_rounded,
                        size: 18,
                        color: Colors.black,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RestaurantSection extends StatelessWidget {
  const _RestaurantSection({
    required this.group,
    required this.favoriteProductIds,
    required this.getQuantity,
    required this.onRestaurantTap,
    required this.onProductTap,
    required this.onFavoriteTap,
    required this.onAddTap,
    required this.onIncrementTap,
    required this.onDecrementTap,
  });

  final _RestaurantGroup group;
  final Set<String> favoriteProductIds;
  final int Function(String productId) getQuantity;
  final VoidCallback onRestaurantTap;
  final void Function(HomeCategoryProductData product) onProductTap;
  final void Function(String productId) onFavoriteTap;
  final void Function(String productId) onAddTap;
  final void Function(String productId) onIncrementTap;
  final void Function(String productId) onDecrementTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onRestaurantTap,
          child: Text(
            group.restaurant.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              height: 1.0,
            ),
          ),
        ),
        const SizedBox(height: 10),
        GridView.builder(
          itemCount: group.products.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: 0.72,
          ),
          itemBuilder: (context, index) {
            final product = group.products[index];

            return _CategoryProductCard(
              product: product,
              quantity: getQuantity(product.id),
              isFavorite: favoriteProductIds.contains(product.id),
              onProductTap: () => onProductTap(product),
              onFavoriteTap: () => onFavoriteTap(product.id),
              onAddTap: () => onAddTap(product.id),
              onIncrementTap: () => onIncrementTap(product.id),
              onDecrementTap: () => onDecrementTap(product.id),
            );
          },
        ),
      ],
    );
  }
}

class _CategoryProductCard extends StatelessWidget {
  const _CategoryProductCard({
    required this.product,
    required this.quantity,
    required this.isFavorite,
    required this.onProductTap,
    required this.onFavoriteTap,
    required this.onAddTap,
    required this.onIncrementTap,
    required this.onDecrementTap,
  });

  final HomeCategoryProductData product;
  final int quantity;
  final bool isFavorite;
  final VoidCallback onProductTap;
  final VoidCallback onFavoriteTap;
  final VoidCallback onAddTap;
  final VoidCallback onIncrementTap;
  final VoidCallback onDecrementTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onProductTap,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFD9D9D9),
            borderRadius: BorderRadius.circular(18),
          ),
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  _ProductImage(imageUrl: product.fullImageUrl),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Material(
                      color: Colors.white,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: onFavoriteTap,
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Icon(
                            isFavorite
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color: Colors.black,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Text(
                  product.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      '${product.price}₸',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        height: 1.0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  quantity > 0
                      ? _QuantityStepper(
                          quantity: quantity,
                          onIncrementTap: onIncrementTap,
                          onDecrementTap: onDecrementTap,
                        )
                      : _CompactAddButton(onTap: onAddTap),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({
    required this.imageUrl,
  });

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 1,
        child: imageUrl != null && imageUrl!.trim().isNotEmpty
            ? Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) {
                  return const _ProductImagePlaceholder();
                },
              )
            : const _ProductImagePlaceholder(),
      ),
    );
  }
}

class _ProductImagePlaceholder extends StatelessWidget {
  const _ProductImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      alignment: Alignment.center,
      child: const Icon(
        Icons.fastfood_rounded,
        size: 38,
        color: Color(0xFFB5B5B5),
      ),
    );
  }
}

class _CompactAddButton extends StatelessWidget {
  const _CompactAddButton({
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: 74,
        height: 36,
        decoration: ShapeDecoration(
          color: const Color(0xFF489F2A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        alignment: Alignment.center,
        child: const Icon(
          Icons.add_rounded,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
    required this.quantity,
    required this.onIncrementTap,
    required this.onDecrementTap,
  });

  final int quantity;
  final VoidCallback onIncrementTap;
  final VoidCallback onDecrementTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 36,
      decoration: ShapeDecoration(
        color: const Color(0xFF489F2A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          InkWell(
            onTap: onDecrementTap,
            child: const SizedBox(
              width: 20,
              child: Center(
                child: Icon(
                  Icons.remove_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                '$quantity',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                ),
              ),
            ),
          ),
          InkWell(
            onTap: onIncrementTap,
            child: const SizedBox(
              width: 20,
              child: Center(
                child: Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCategoryState extends StatelessWidget {
  const _EmptyCategoryState({
    required this.categoryTitle,
    required this.onFilterTap,
  });

  final String categoryTitle;
  final VoidCallback onFilterTap;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _CategoryHeader(
          title: categoryTitle,
          onBackTap: () => Navigator.of(context).pop(),
          onFilterTap: onFilterTap,
        ),
        const SizedBox(height: 120),
        const Icon(
          Icons.fastfood_rounded,
          size: 40,
          color: Color(0xFF8B8B8B),
        ),
        const SizedBox(height: 16),
        const Text(
          'В этой категории пока нет товаров',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: Colors.black,
          ),
        ),
      ],
    );
  }
}
