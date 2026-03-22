import 'package:flutter/material.dart';
import 'package:jetkiz_mobile/core/network/apiClient.dart';
import 'package:jetkiz_mobile/features/addresses/data/addressRepository.dart';
import 'package:jetkiz_mobile/features/addresses/domain/address.dart';
import 'package:jetkiz_mobile/features/addresses/presentation/addressesPage.dart';
import 'package:jetkiz_mobile/features/categories/presentation/categoryProductsPage.dart';
import 'package:jetkiz_mobile/features/home/data/homeApi.dart';
import 'package:jetkiz_mobile/features/home/domain/homeData.dart';
import 'package:jetkiz_mobile/features/menu/presentation/restaurantMenuPage.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final HomeApi _homeApi;
  final AddressRepository _addressRepository = AddressRepository.instance;

  bool _isLoading = true;
  String? _error;
  HomeData? _homeData;

  @override
  void initState() {
    super.initState();
    _homeApi = HomeApi(ApiClient());
    _addressRepository.addListener(_handleAddressChanged);
    _load();
  }

  @override
  void dispose() {
    _addressRepository.removeListener(_handleAddressChanged);
    super.dispose();
  }

  void _handleAddressChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await _homeApi.getHomeData();

      if (!mounted) {
        return;
      }

      setState(() {
        _homeData = data;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = 'Не удалось загрузить главную страницу';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openAddresses() async {
    final selectedAddress = await Navigator.of(context).push<Address>(
      MaterialPageRoute(
        builder: (_) => AddressesPage(
          selectionMode: true,
          initialSelectedAddressId: _addressRepository.selectedAddressId,
        ),
      ),
    );

    if (selectedAddress == null || !mounted) {
      return;
    }

    _addressRepository.setSelectedAddress(selectedAddress);
  }

  void _openCategoryProducts(HomeCategoryData category) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CategoryProductsPage(category: category),
      ),
    );
  }

  void _openRestaurantMenu(HomeRestaurantData restaurant) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RestaurantMenuPage(
          restaurantId: restaurant.id,
          restaurantName: restaurant.name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = _homeData;
    final selectedAddress = _addressRepository.selectedAddress;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8F9),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _HomeErrorState(
                    message: _error!,
                    onRetry: _load,
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      children: [
                        _SearchRow(
                          onSearchTap: () {
                            // TODO: open searchPage
                          },
                          onNotificationsTap: () {
                            // TODO: open notificationsPage
                          },
                        ),
                        const SizedBox(height: 16),
                        _AddressCard(
                          selectedAddress: selectedAddress,
                          onTap: _openAddresses,
                        ),
                        const SizedBox(height: 20),
                        if (data?.promo != null && data!.promo!.isActive) ...[
                          _PromoBanner(promo: data.promo!),
                          const SizedBox(height: 20),
                        ],
                        if ((data?.categories.isNotEmpty ?? false)) ...[
                          SizedBox(
                            height: 108,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: data!.categories.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 12),
                              itemBuilder: (context, index) {
                                final category = data.categories[index];

                                return _CategoryCard(
                                  category: category,
                                  onTap: () {
                                    _openCategoryProducts(category);
                                  },
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        _RestaurantsSectionHeader(
                          onTap: () {
                            // TODO: open restaurantsPage with all restaurants
                          },
                        ),
                        const SizedBox(height: 12),
                        if (data?.pinnedRestaurants.isEmpty ?? true)
                          const _EmptyBlock(
                            text: 'Закрепленные рестораны пока не добавлены',
                          )
                        else
                          ...data!.pinnedRestaurants.map(
                            (restaurant) => Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: _PinnedRestaurantCard(
                                restaurant: restaurant,
                                onTap: () {
                                  _openRestaurantMenu(restaurant);
                                },
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
      ),
    );
  }
}

class _SearchRow extends StatelessWidget {
  const _SearchRow({
    required this.onSearchTap,
    required this.onNotificationsTap,
  });

  final VoidCallback onSearchTap;
  final VoidCallback onNotificationsTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onSearchTap,
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFDADDE2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.search, color: Color(0xFF7B7F87)),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Поиск блюд и ресторанов',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF7B7F87),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onNotificationsTap,
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFDADDE2)),
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              size: 28,
              color: Color(0xFF7B7F87),
            ),
          ),
        ),
      ],
    );
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.selectedAddress,
    required this.onTap,
  });

  final Address? selectedAddress;
  final VoidCallback onTap;

  String _buildSubtitle() {
    if (selectedAddress == null) {
      return 'Укажите адрес доставки';
    }

    return selectedAddress!.fullSubtitle;
  }

  @override
  Widget build(BuildContext context) {
    final hasAddress = selectedAddress != null;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF8F3),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasAddress ? selectedAddress!.title : 'Адрес доставки',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF14181F),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _buildSubtitle(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      color: hasAddress
                          ? const Color(0xFF4A4F57)
                          : const Color(0xFF97A0AA),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 34,
              color: Color(0xFF4A4F57),
            ),
          ],
        ),
      ),
    );
  }
}

class _PromoBanner extends StatelessWidget {
  const _PromoBanner({required this.promo});

  final HomePromo promo;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 170,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        image: promo.fullImageUrl != null
            ? DecorationImage(
                image: NetworkImage(promo.fullImageUrl!),
                fit: BoxFit.cover,
              )
            : null,
        color: const Color(0xFF1F2328),
      ),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                colors: [
                  Colors.black.withValues(alpha: 0.34),
                  Colors.black.withValues(alpha: 0.14),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Align(
              alignment: Alignment.topLeft,
              child: Text(
                promo.title.isNotEmpty ? promo.title : 'Акция дня',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1.05,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RestaurantsSectionHeader extends StatelessWidget {
  const _RestaurantsSectionHeader({
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: Color(0xFF4FAF43),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.menu_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'Рестораны',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF14181F),
            ),
          ),
          const SizedBox(width: 2),
          const Icon(
            Icons.chevron_right_rounded,
            color: Color(0xFF6E7480),
            size: 30,
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.onTap,
  });

  final HomeCategoryData category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        width: 126,
        decoration: BoxDecoration(
          color: const Color(0xFFEAF8F3),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
              ),
              child: Container(
                width: double.infinity,
                height: 74,
                color: const Color(0xFFEAF8F3),
                child: category.fullImageUrl != null &&
                        category.fullImageUrl!.trim().isNotEmpty
                    ? Image.network(
                        category.fullImageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) {
                          return Container(
                            color: const Color(0xFFEAF8F3),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.fastfood_rounded,
                              size: 42,
                              color: Color(0xFF489F2A),
                            ),
                          );
                        },
                      )
                    : Container(
                        color: const Color(0xFFEAF8F3),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.fastfood_rounded,
                          size: 42,
                          color: Color(0xFF489F2A),
                        ),
                      ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    category.titleRu,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PinnedRestaurantCard extends StatelessWidget {
  const _PinnedRestaurantCard({
    required this.restaurant,
    required this.onTap,
  });

  final HomeRestaurantData restaurant;
  final VoidCallback onTap;

  String _buildSubtitle() {
    if (restaurant.workingHours?.trim().isNotEmpty == true) {
      return restaurant.workingHours!.trim();
    }

    if (restaurant.address?.trim().isNotEmpty == true) {
      return restaurant.address!.trim();
    }

    return 'Доставка 30-35 мин';
  }

  @override
  Widget build(BuildContext context) {
    final ratingText = restaurant.ratingAvg == 0
        ? '0,0'
        : restaurant.ratingAvg.toStringAsFixed(1).replaceAll('.', ',');

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: SizedBox(
        height: 150,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: Container(
                height: 113,
                decoration: BoxDecoration(
                  color: const Color(0xFF7DC963),
                  borderRadius: BorderRadius.circular(15),
                  image: restaurant.fullCoverImageUrl != null
                      ? DecorationImage(
                          image: NetworkImage(restaurant.fullCoverImageUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFDFD),
                  border: Border.all(
                    color: const Color(0xFF489F2A),
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(19),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      ratingText,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(
                      Icons.favorite_border_rounded,
                      size: 28,
                      color: Colors.black,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 0,
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  color: const Color(0xFFFCFFFB),
                  border: Border.all(
                    color: const Color(0xFF489F2A),
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        restaurant.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF010101),
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        _buildSubtitle(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: Colors.black.withValues(alpha: 0.46),
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyBlock extends StatelessWidget {
  const _EmptyBlock({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF7B7F87),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _HomeErrorState extends StatelessWidget {
  const _HomeErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
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
