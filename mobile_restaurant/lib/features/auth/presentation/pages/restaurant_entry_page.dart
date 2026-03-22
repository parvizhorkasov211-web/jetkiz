import 'package:flutter/material.dart';

import '../../../orders/presentation/pages/restaurant_orders_page.dart';
import '../../data/auth_api.dart';
import '../../data/auth_storage.dart';
import 'restaurant_auth_page.dart';

class RestaurantEntryPage extends StatefulWidget {
  const RestaurantEntryPage({super.key});

  @override
  State<RestaurantEntryPage> createState() => _RestaurantEntryPageState();
}

class _RestaurantEntryPageState extends State<RestaurantEntryPage> {
  final AuthStorage _storage = AuthStorage();
  final AuthApi _authApi = AuthApi();

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final hasSession = await _storage.hasSession();

    if (!hasSession) {
      _openLogin();
      return;
    }

    try {
      await _authApi.getMe();
      _openOrders();
    } catch (_) {
      await _storage.clearTokens();
      _openLogin();
    }
  }

  void _openLogin() {
  if (!mounted) return;
  Navigator.of(context).pushReplacement(
    MaterialPageRoute(
      builder: (_) => const RestaurantAuthPage(),
    ),
  );
}

  void _openOrders() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const RestaurantOrdersPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0B0B0C),
      body: Center(
        child: CircularProgressIndicator(
          color: Color(0xFF489F2A),
        ),
      ),
    );
  }
}
