import 'dart:async';
import 'package:flutter/material.dart';

enum OrderStatus {
  newOrder,
  accepted,
  cooking,
  ready,
  delivering,
  completed,
  cancelled,
}

class RestaurantOrder {
  final String id;
  final String customerName;
  final int total;
  final DateTime createdAt;
  OrderStatus status;

  RestaurantOrder({
    required this.id,
    required this.customerName,
    required this.total,
    required this.createdAt,
    required this.status,
  });
}

class RestaurantOrdersPage extends StatefulWidget {
  const RestaurantOrdersPage({super.key});

  @override
  State<RestaurantOrdersPage> createState() =>
      _RestaurantOrdersPageState();
}

class _RestaurantOrdersPageState extends State<RestaurantOrdersPage>
    with TickerProviderStateMixin {
  List<RestaurantOrder> orders = [];
  Timer? _timer;
  String filter = 'all';

  @override
  void initState() {
    super.initState();

    // mock data (заменим потом backend)
    orders = [
      RestaurantOrder(
        id: "1234",
        customerName: "Алексей Петров",
        total: 1100,
        createdAt: DateTime.now().subtract(const Duration(minutes: 25)),
        status: OrderStatus.cooking,
      ),
      RestaurantOrder(
        id: "1235",
        customerName: "Мария Иванова",
        total: 930,
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
        status: OrderStatus.newOrder,
      ),
      RestaurantOrder(
        id: "1236",
        customerName: "Дмитрий Козлов",
        total: 990,
        createdAt: DateTime.now().subtract(const Duration(minutes: 40)),
        status: OrderStatus.ready,
      ),
    ];

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  bool isOverdue(RestaurantOrder order) {
    return DateTime.now().difference(order.createdAt).inMinutes > 20;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1220),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildFilters(),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: orders.length,
                itemBuilder: (_, i) => _OrderCard(
                  order: orders[i],
                  isOverdue: isOverdue(orders[i]),
                  onAction: () {
                    setState(() {
                      orders[i].status = OrderStatus.ready;
                    });
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.green,
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("jetkiz", style: TextStyle(color: Colors.white)),
          Icon(Icons.notifications, color: Colors.white),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    final filters = ["all", "new", "cooking", "ready"];

    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        itemBuilder: (_, i) {
          final f = filters[i];
          final selected = f == filter;

          return GestureDetector(
            onTap: () => setState(() => filter = f),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? Colors.green : Colors.white10,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                f,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _OrderCard extends StatefulWidget {
  final RestaurantOrder order;
  final bool isOverdue;
  final VoidCallback onAction;

  const _OrderCard({
    required this.order,
    required this.isOverdue,
    required this.onAction,
  });

  @override
  State<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<_OrderCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _blinkController;

  @override
  void initState() {
    super.initState();

    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _blinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;

    return AnimatedBuilder(
      animation: _blinkController,
      builder: (_, child) {
        final opacity =
            widget.isOverdue ? _blinkController.value : 1.0;

        return Opacity(
          opacity: opacity,
          child: child,
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(order),
            const SizedBox(height: 8),
            Text(order.customerName,
                style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 8),
            Text("Итого: ${order.total} ₸",
                style: const TextStyle(color: Colors.green)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: widget.onAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
              ),
              child: const Text("Действие"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(RestaurantOrder order) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text("Заказ #${order.id}",
            style: const TextStyle(color: Colors.white)),
        _statusBadge(order.status),
      ],
    );
  }

  Widget _statusBadge(OrderStatus status) {
    Color color;

    switch (status) {
      case OrderStatus.newOrder:
        color = Colors.orange;
        break;
      case OrderStatus.cooking:
        color = Colors.blue;
        break;
      case OrderStatus.ready:
        color = Colors.green;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.name,
        style: const TextStyle(color: Colors.white),
      ),
    );
  }
}