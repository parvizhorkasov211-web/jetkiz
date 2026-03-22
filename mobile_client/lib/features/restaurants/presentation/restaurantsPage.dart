/*
  RestaurantsPage

  Первый реальный экран Jetkiz mobile.

  Контекст для будущих сессий ChatGPT:
  - Экран подключён к реальному backend endpoint:
      GET /restaurants/public/list
  - Используется backend-first подход.
  - Экран показывает client restaurants list.
  - pinned рестораны уже приходят отдельно, но на первом шаге
    список items показывается основным списком.
  - При нажатии на карточку в будущем должен открываться экран ресторана
    или меню ресторана с передачей restaurant.id (UUID string).
  - Для Android development используется:
      adb reverse tcp:3001 tcp:3001
*/

import 'package:flutter/material.dart';
import 'package:jetkiz_mobile/core/network/apiClient.dart';
import 'package:jetkiz_mobile/features/restaurants/data/restaurantsApi.dart';
import 'package:jetkiz_mobile/features/restaurants/domain/restaurant.dart';

class RestaurantsPage extends StatefulWidget {
  const RestaurantsPage({super.key});

  @override
  State<RestaurantsPage> createState() => _RestaurantsPageState();
}

class _RestaurantsPageState extends State<RestaurantsPage> {
  late final RestaurantsApi _restaurantsApi;

  bool _isLoading = true;
  String? _errorText;
  List<Restaurant> _restaurants = const [];
  List<Restaurant> _pinnedRestaurants = const [];

  @override
  void initState() {
    super.initState();
    _restaurantsApi = RestaurantsApi(ApiClient());
    _loadRestaurants();
  }

  Future<void> _loadRestaurants() async {
    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final response = await _restaurantsApi.getPublicRestaurants();

      if (!mounted) return;

      setState(() {
        _restaurants = response.items;
        _pinnedRestaurants = response.pinned;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorText = 'Не удалось загрузить рестораны';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPinned = _pinnedRestaurants.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Рестораны'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadRestaurants,
        child: Builder(
          builder: (context) {
            if (_isLoading) {
              return const _PageLoader();
            }

            if (_errorText != null) {
              return _PageError(
                text: _errorText!,
                onRetry: _loadRestaurants,
              );
            }

            if (_restaurants.isEmpty) {
              return const _PageEmpty(
                text: 'Список ресторанов пока пуст',
              );
            }

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                if (hasPinned) ...[
                  const _SectionTitle(title: 'Закреплённые'),
                  const SizedBox(height: 12),
                  ..._pinnedRestaurants.map(
                    (restaurant) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: RestaurantCard(
                        restaurant: restaurant,
                        onTap: () {
                          // TODO(JETKIZ): Открыть экран ресторана / меню ресторана.
                          // Передавать:
                          // - restaurant.id (UUID)
                          // - restaurant.displayName
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const _SectionTitle(title: 'Все рестораны'),
                  const SizedBox(height: 12),
                ],
                ..._restaurants.map(
                  (restaurant) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: RestaurantCard(
                      restaurant: restaurant,
                      onTap: () {
                        // TODO(JETKIZ): Открыть экран ресторана / меню ресторана.
                        // Передавать:
                        // - restaurant.id (UUID)
                        // - restaurant.displayName
                      },
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class RestaurantCard extends StatelessWidget {
  const RestaurantCard({
    super.key,
    required this.restaurant,
    required this.onTap,
  });

  final Restaurant restaurant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final imageUrl = restaurant.fullCoverImageUrl;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFEAEAEA)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _RestaurantImage(imageUrl: imageUrl),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      restaurant.displayName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if ((restaurant.address ?? '').trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          restaurant.address!,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF666666),
                          ),
                        ),
                      ),
                    Row(
                      children: [
                        _InfoChip(
                          text: restaurant.isOpen ? 'Открыто' : 'Закрыто',
                        ),
                        const SizedBox(width: 8),
                        _InfoChip(
                          text:
                              'Рейтинг ${restaurant.ratingAvg.toStringAsFixed(1)}',
                        ),
                      ],
                    ),
                    if ((restaurant.workingHours ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Часы работы: ${restaurant.workingHours}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF777777),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RestaurantImage extends StatelessWidget {
  const _RestaurantImage({
    required this.imageUrl,
  });

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return Container(
        height: 180,
        width: double.infinity,
        decoration: const BoxDecoration(
          color: Color(0xFFF4F4F4),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        alignment: Alignment.center,
        child: const Icon(
          Icons.restaurant,
          size: 40,
          color: Color(0xFF9E9E9E),
        ),
      );
    }

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Image.network(
        imageUrl!,
        height: 180,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            height: 180,
            width: double.infinity,
            color: const Color(0xFFF4F4F4),
            alignment: Alignment.center,
            child: const Icon(
              Icons.broken_image_outlined,
              size: 40,
              color: Color(0xFF9E9E9E),
            ),
          );
        },
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F6F6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
  });

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _PageLoader extends StatelessWidget {
  const _PageLoader();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: const [
        SizedBox(height: 220),
        Center(
          child: CircularProgressIndicator(),
        ),
      ],
    );
  }
}

class _PageError extends StatelessWidget {
  const _PageError({
    required this.text,
    required this.onRetry,
  });

  final String text;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 180),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                Text(
                  text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: onRetry,
                  child: const Text('Повторить'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PageEmpty extends StatelessWidget {
  const _PageEmpty({
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 180),
        Center(
          child: Text(
            text,
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ],
    );
  }
}
