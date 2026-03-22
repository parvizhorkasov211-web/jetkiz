import 'package:flutter/material.dart';
import 'package:jetkiz_mobile/core/localization/appLocalizationScope.dart';

/// OrdersPage
///
/// Контекст для будущих сессий ChatGPT:
/// - Это экран заказов клиента.
/// - На текущем этапе реализовано empty state, когда заказов еще нет.
/// - Когда backend заказов будет подтвержден и появится flow списка заказов,
///   этот экран нужно расширить до двух состояний:
///   1) empty state
///   2) orders list state
/// - Язык не переключается локально на этом экране.
/// - Все тексты берутся из глобального AppLocalizationScope.
class OrdersPage extends StatelessWidget {
  const OrdersPage({super.key});

  static const _backgroundColor = Color(0xFFF8F8F8);
  static const _green = Color(0xFF489F2A);
  static const _cardColor = Color(0xFFE7E7E7);

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizationScope.of(context).strings;

    return Scaffold(
      backgroundColor: _backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            children: [
              SizedBox(
                height: 44,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.black,
                          size: 24,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        splashRadius: 22,
                      ),
                    ),
                    Center(
                      child: Text(
                        strings.ordersTitle,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                width: 170,
                height: 170,
                decoration: BoxDecoration(
                  color: _cardColor,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  size: 76,
                  color: _green,
                ),
              ),
              const SizedBox(height: 26),
              Text(
                strings.ordersEmptyTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                strings.ordersEmptySubtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  height: 1.35,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: Text(strings.goHome),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
