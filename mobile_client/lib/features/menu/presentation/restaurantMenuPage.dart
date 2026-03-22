import 'package:flutter/material.dart';
import 'package:jetkiz_mobile/core/network/apiClient.dart';
import 'package:jetkiz_mobile/features/cart/data/cartRepository.dart';
import 'package:jetkiz_mobile/features/cart/presentation/widgets/cartSummaryBar.dart';
import 'package:jetkiz_mobile/features/menu/data/financeConfigApi.dart';
import 'package:jetkiz_mobile/features/menu/data/restaurantMenuApi.dart';
import 'package:jetkiz_mobile/features/menu/domain/restaurantMenuData.dart';
import 'package:jetkiz_mobile/features/menu/presentation/productDetailsPage.dart';

/// Jetkiz mobile
/// Restaurant menu screen.
///
/// Backend:
/// - GET /restaurants/:id/menu
///
/// Confirmed backend contract:
/// - top-level uses restaurant, categories, items
/// - mobile groups items locally using categoryId and categories[]
///
/// UI notes:
/// - Search filters only dishes of current restaurant menu.
/// - Category row is local tab navigation.
/// - Product card layout is aligned with CategoryProductsPage:
///   square image, title below image, price at bottom, add/stepper at bottom-right.
/// - Product image must stay inside dedicated slot and must not be squeezed.
/// - First action is add button, then [- qty +].
///
/// Future GPT notes:
/// - delivery price comes from backend finance config
/// - favorites must later be connected to backend
/// - language source should later come from profile/settings, not local state
/// - product card tap opens reusable ProductDetailsPage
class RestaurantMenuPage extends StatefulWidget {
  final String restaurantId;
  final String? restaurantName;

  const RestaurantMenuPage({
    super.key,
    required this.restaurantId,
    this.restaurantName,
  });

  @override
  State<RestaurantMenuPage> createState() => _RestaurantMenuPageState();
}

enum _MenuLanguage {
  ru,
  kk,
}

class _RestaurantMenuPageState extends State<RestaurantMenuPage> {
  late final RestaurantMenuApi _menuApi;
  late final FinanceConfigApi _financeConfigApi;
  final FocusNode _searchFocusNode = FocusNode();

  bool _isLoading = true;
  String? _error;
  RestaurantMenuData? _menuData;

  String _searchQuery = '';
  String _selectedTabId = 'all';

  final Set<String> _favoriteProductIds = <String>{};
  bool _isRestaurantFavorite = false;

  _MenuLanguage _menuLanguage = _MenuLanguage.ru;
  int _deliveryFee = 0;

  @override
  void initState() {
    super.initState();
    _menuApi = RestaurantMenuApi(ApiClient());
    _financeConfigApi = FinanceConfigApi(ApiClient());
    _load();
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _menuApi.getRestaurantMenu(
          restaurantId: widget.restaurantId,
        ),
        _financeConfigApi.getFinanceConfig(),
      ]);

      final data = results[0] as RestaurantMenuData;
      final financeConfig = results[1] as FinanceConfigData;

      setState(() {
        _menuData = data;
        _selectedTabId = 'all';
        _deliveryFee = financeConfig.activeDeliveryFee;
      });
    } catch (e) {
      setState(() {
        _error = 'Не удалось загрузить меню ресторана';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _allTabTitle() {
    switch (_menuLanguage) {
      case _MenuLanguage.ru:
        return 'Все';
      case _MenuLanguage.kk:
        return 'Барлығы';
    }
  }

  String _searchHint() {
    switch (_menuLanguage) {
      case _MenuLanguage.ru:
        return 'Поиск блюд и напитков';
      case _MenuLanguage.kk:
        return 'Тағамдар мен сусындарды іздеу';
    }
  }

  String _basketItemsLabel() {
    switch (_menuLanguage) {
      case _MenuLanguage.ru:
        return 'В корзине';
      case _MenuLanguage.kk:
        return 'Себетте';
    }
  }

  String _deliveryLabel() {
    switch (_menuLanguage) {
      case _MenuLanguage.ru:
        return 'Доставка';
      case _MenuLanguage.kk:
        return 'Жеткізу';
    }
  }

  String _nextButtonLabel() {
    switch (_menuLanguage) {
      case _MenuLanguage.ru:
        return 'Далее';
      case _MenuLanguage.kk:
        return 'Әрі қарай';
    }
  }

  List<RestaurantMenuGroup> get _allGroups {
    return _menuData?.groupedItems ?? const <RestaurantMenuGroup>[];
  }

  List<RestaurantMenuGroup> get _visibleGroups {
    final groups = _allGroups;

    final filteredByTab = _selectedTabId == 'all'
        ? groups
        : groups.where((group) => group.category.id == _selectedTabId).toList();

    if (_searchQuery.trim().isEmpty) {
      return filteredByTab;
    }

    final query = _searchQuery.trim().toLowerCase();
    final result = <RestaurantMenuGroup>[];

    for (final group in filteredByTab) {
      final items = group.items.where((item) {
        final haystack = [
          item.titleRu,
          item.titleKk,
          item.composition,
          item.description,
          item.weight,
          item.categoryNameRu,
          item.categoryNameKk,
        ].whereType<String>().join(' ').toLowerCase();

        return haystack.contains(query);
      }).toList();

      if (items.isNotEmpty) {
        result.add(
          RestaurantMenuGroup(
            category: group.category,
            items: items,
          ),
        );
      }
    }

    return result;
  }

  int _getQuantity(String productId) {
    return CartRepository.instance.quantityOf(productId);
  }

  void _addFirst(RestaurantMenuItem item) {
    CartRepository.instance.addItem(
      productId: item.id,
      restaurantId: widget.restaurantId,
      title: item.title,
      price: item.price,
      quantity: 1,
      imageUrl: item.mainImageUrl,
      description: item.description,
      weight: item.weight,
    );

    setState(() {});
  }

  void _increment(RestaurantMenuItem item) {
    CartRepository.instance.addItem(
      productId: item.id,
      restaurantId: widget.restaurantId,
      title: item.title,
      price: item.price,
      quantity: 1,
      imageUrl: item.mainImageUrl,
      description: item.description,
      weight: item.weight,
    );

    setState(() {});
  }

  void _decrement(RestaurantMenuItem item) {
    CartRepository.instance.decrement(item.id);
    setState(() {});
  }

  void _toggleRestaurantFavorite() {
    setState(() {
      _isRestaurantFavorite = !_isRestaurantFavorite;
    });
  }

  void _toggleProductFavorite(String productId) {
    setState(() {
      if (_favoriteProductIds.contains(productId)) {
        _favoriteProductIds.remove(productId);
      } else {
        _favoriteProductIds.add(productId);
      }
    });
  }

  void _openProductDetails(RestaurantMenuItem item) {
    final restaurantName =
        _menuData?.restaurant.displayName ?? widget.restaurantName;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductDetailsPage(
          product: item,
          restaurantName: restaurantName,
          restaurantId: widget.restaurantId,
        ),
      ),
    );
  }

  int get _basketItemsCount {
    return CartRepository.instance.totalQuantity;
  }

  int get _basketTotal {
    return CartRepository.instance.subtotal;
  }

  @override
  Widget build(BuildContext context) {
    final menuData = _menuData;
    final groups = _visibleGroups;
    final hasBasket = _basketItemsCount > 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _RestaurantMenuErrorState(
                    message: _error!,
                    onRetry: _load,
                  )
                : menuData == null
                    ? _RestaurantMenuErrorState(
                        message: 'Меню ресторана не найдено',
                        onRetry: _load,
                      )
                    : Column(
                        children: [
                          _MenuTopSection(
                            restaurantName:
                                menuData.restaurant.displayName.isNotEmpty
                                    ? menuData.restaurant.displayName
                                    : (widget.restaurantName ?? 'Меню'),
                            searchHint: _searchHint(),
                            groups: _allGroups,
                            selectedTabId: _selectedTabId,
                            allTabTitle: _allTabTitle(),
                            isRestaurantFavorite: _isRestaurantFavorite,
                            searchFocusNode: _searchFocusNode,
                            onBackTap: () {
                              Navigator.of(context).maybePop();
                            },
                            onFavoriteTap: _toggleRestaurantFavorite,
                            onSearchChanged: (value) {
                              setState(() {
                                _searchQuery = value;
                              });
                            },
                            onSearchTap: () {
                              _searchFocusNode.requestFocus();
                            },
                            onTabSelected: (tabId) {
                              setState(() {
                                _selectedTabId = tabId;
                              });
                            },
                          ),
                          Expanded(
                            child: groups.isEmpty
                                ? const _MenuEmptyState()
                                : ScrollConfiguration(
                                    behavior: const _SmoothScrollBehavior(),
                                    child: ListView.builder(
                                      physics: const BouncingScrollPhysics(
                                        parent: AlwaysScrollableScrollPhysics(),
                                      ),
                                      keyboardDismissBehavior:
                                          ScrollViewKeyboardDismissBehavior
                                              .onDrag,
                                      cacheExtent: 1200,
                                      padding: EdgeInsets.fromLTRB(
                                        16,
                                        8,
                                        16,
                                        hasBasket ? 190 : 32,
                                      ),
                                      itemCount: groups.length,
                                      itemBuilder: (context, groupIndex) {
                                        final group = groups[groupIndex];

                                        return Padding(
                                          padding: EdgeInsets.only(
                                            bottom:
                                                groupIndex == groups.length - 1
                                                    ? 0
                                                    : 18,
                                          ),
                                          child: _MenuCategorySection(
                                            title: group.category.title,
                                            showTitle: _selectedTabId == 'all',
                                            items: group.items,
                                            favoriteProductIds:
                                                _favoriteProductIds,
                                            getQuantity: _getQuantity,
                                            onProductTap: _openProductDetails,
                                            onFavoriteTap:
                                                _toggleProductFavorite,
                                            onAddFirst: (productId) {
                                              final item =
                                                  group.items.firstWhere(
                                                (x) => x.id == productId,
                                              );
                                              _addFirst(item);
                                            },
                                            onAdd: (productId) {
                                              final item =
                                                  group.items.firstWhere(
                                                (x) => x.id == productId,
                                              );
                                              _increment(item);
                                            },
                                            onRemove: (productId) {
                                              final item =
                                                  group.items.firstWhere(
                                                (x) => x.id == productId,
                                              );
                                              _decrement(item);
                                            },
                                          ),
                                        );
                                      },
                                    ),
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
              deliveryLabel: _deliveryLabel(),
              basketLabelPrefix: _basketItemsLabel(),
              nextButtonLabel: _nextButtonLabel(),
              onNextTap: () {
                Navigator.of(context).pushNamed('/cart');
              },
            )
          : null,
    );
  }
}

class _MenuTopSection extends StatelessWidget {
  const _MenuTopSection({
    required this.restaurantName,
    required this.searchHint,
    required this.groups,
    required this.selectedTabId,
    required this.allTabTitle,
    required this.isRestaurantFavorite,
    required this.searchFocusNode,
    required this.onBackTap,
    required this.onFavoriteTap,
    required this.onSearchChanged,
    required this.onSearchTap,
    required this.onTabSelected,
  });

  final String restaurantName;
  final String searchHint;
  final List<RestaurantMenuGroup> groups;
  final String selectedTabId;
  final String allTabTitle;
  final bool isRestaurantFavorite;
  final FocusNode searchFocusNode;
  final VoidCallback onBackTap;
  final VoidCallback onFavoriteTap;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchTap;
  final ValueChanged<String> onTabSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      child: Column(
        children: [
          SizedBox(
            height: 40,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: onBackTap,
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.black,
                    ),
                  ),
                ),
                const Center(
                  child: Text(
                    'Меню',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: onSearchTap,
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: const Color(0xFFB3B1B1),
                ),
              ),
              child: TextField(
                focusNode: searchFocusNode,
                onChanged: onSearchChanged,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Color(0xFF737373),
                  ),
                  hintText: searchHint,
                  hintStyle: const TextStyle(
                    color: Color(0xFF737373),
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  restaurantName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
              ),
              IconButton(
                onPressed: onFavoriteTap,
                icon: Icon(
                  isRestaurantFavorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: isRestaurantFavorite ? Colors.red : Colors.black,
                  size: 24,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          SizedBox(
            height: 26,
            child: ScrollConfiguration(
              behavior: const _SmoothScrollBehavior(),
              child: ListView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                scrollDirection: Axis.horizontal,
                children: [
                  _MenuCategoryTab(
                    title: allTabTitle,
                    isSelected: selectedTabId == 'all',
                    onTap: () => onTabSelected('all'),
                  ),
                  const SizedBox(width: 10),
                  ...groups.expand((group) {
                    return [
                      _MenuCategoryTab(
                        title: group.category.title,
                        isSelected: selectedTabId == group.category.id,
                        onTap: () => onTabSelected(group.category.id),
                      ),
                      const SizedBox(width: 10),
                    ];
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuCategoryTab extends StatelessWidget {
  const _MenuCategoryTab({
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? Colors.black : const Color(0xFF9E9E9E);
    final fontWeight = isSelected ? FontWeight.w700 : FontWeight.w400;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Text(
          title,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: fontWeight,
          ),
        ),
      ),
    );
  }
}

class _MenuCategorySection extends StatelessWidget {
  const _MenuCategorySection({
    required this.title,
    required this.showTitle,
    required this.items,
    required this.favoriteProductIds,
    required this.getQuantity,
    required this.onProductTap,
    required this.onFavoriteTap,
    required this.onAddFirst,
    required this.onAdd,
    required this.onRemove,
  });

  final String title;
  final bool showTitle;
  final List<RestaurantMenuItem> items;
  final Set<String> favoriteProductIds;
  final int Function(String productId) getQuantity;
  final void Function(RestaurantMenuItem item) onProductTap;
  final void Function(String productId) onFavoriteTap;
  final void Function(String productId) onAddFirst;
  final void Function(String productId) onAdd;
  final void Function(String productId) onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTitle) ...[
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 12),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Colors.black,
                height: 1.0,
              ),
            ),
          ),
        ],
        GridView.builder(
          itemCount: items.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: 0.72,
          ),
          itemBuilder: (context, index) {
            final item = items[index];

            return _MenuProductCard(
              item: item,
              quantity: getQuantity(item.id),
              isFavorite: favoriteProductIds.contains(item.id),
              onTap: () => onProductTap(item),
              onFavoriteTap: () => onFavoriteTap(item.id),
              onAddFirst: () => onAddFirst(item.id),
              onAdd: () => onAdd(item.id),
              onRemove: () => onRemove(item.id),
            );
          },
        ),
      ],
    );
  }
}

class _MenuProductCard extends StatelessWidget {
  const _MenuProductCard({
    required this.item,
    required this.quantity,
    required this.isFavorite,
    required this.onTap,
    required this.onFavoriteTap,
    required this.onAddFirst,
    required this.onAdd,
    required this.onRemove,
  });

  final RestaurantMenuItem item;
  final int quantity;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onFavoriteTap;
  final VoidCallback onAddFirst;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final isAvailable = item.isAvailable;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
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
                  _MenuProductImage(item: item),
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
                  if (!isAvailable)
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xB3000000),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Недоступно',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Text(
                  item.title,
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
                      '${item.price}₸',
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
                  if (!isAvailable)
                    const SizedBox.shrink()
                  else if (quantity > 0)
                    _MenuQuantityControl(
                      quantity: quantity,
                      onAdd: onAdd,
                      onRemove: onRemove,
                    )
                  else
                    _CompactAddButton(
                      onTap: onAddFirst,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuProductImage extends StatelessWidget {
  const _MenuProductImage({
    required this.item,
  });

  final RestaurantMenuItem item;

  @override
  Widget build(BuildContext context) {
    final imageUrl = item.mainImageUrl;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 1,
        child: imageUrl != null && imageUrl.isNotEmpty
            ? Image.network(
                imageUrl,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) {
                  return const _MenuImagePlaceholder();
                },
              )
            : const _MenuImagePlaceholder(),
      ),
    );
  }
}

class _MenuImagePlaceholder extends StatelessWidget {
  const _MenuImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF4F4F4),
      alignment: Alignment.center,
      child: const Icon(
        Icons.image_outlined,
        size: 42,
        color: Colors.black54,
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

class _MenuQuantityControl extends StatelessWidget {
  const _MenuQuantityControl({
    required this.quantity,
    required this.onAdd,
    required this.onRemove,
  });

  final int quantity;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 36,
      decoration: BoxDecoration(
        color: const Color(0xFF489F2A),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          InkWell(
            onTap: onRemove,
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
            onTap: onAdd,
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

class _MenuEmptyState extends StatelessWidget {
  const _MenuEmptyState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
      children: const [
        Icon(
          Icons.lunch_dining_outlined,
          size: 48,
          color: Color(0xFF9E9E9E),
        ),
        SizedBox(height: 12),
        Text(
          'По выбранному фильтру нет блюд',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF444444),
          ),
        ),
      ],
    );
  }
}

class _RestaurantMenuErrorState extends StatelessWidget {
  const _RestaurantMenuErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 120),
        const Icon(
          Icons.cloud_off_rounded,
          size: 52,
          color: Color(0xFF97A0AA),
        ),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF14181F),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: FilledButton(
            onPressed: onRetry,
            child: const Text('Повторить'),
          ),
        ),
      ],
    );
  }
}

class _SmoothScrollBehavior extends ScrollBehavior {
  const _SmoothScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(
      parent: AlwaysScrollableScrollPhysics(),
    );
  }
}
