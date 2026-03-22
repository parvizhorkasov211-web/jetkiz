import 'package:flutter/material.dart';

/// Jetkiz mobile
/// Shared bottom cart summary bar.
///
/// Current stage:
/// - reusable on category page and restaurant menu page
/// - delivery fee is passed from screen state
/// - onNextTap opens cart flow
class CartSummaryBar extends StatelessWidget {
  const CartSummaryBar({
    super.key,
    required this.itemsCount,
    required this.itemsTotal,
    required this.deliveryFee,
    required this.onNextTap,
    this.deliveryLabel = 'Доставка',
    this.basketLabelPrefix = 'В корзине',
    this.nextButtonLabel = 'Далее',
  });

  final int itemsCount;
  final int itemsTotal;
  final int deliveryFee;
  final VoidCallback onNextTap;

  final String deliveryLabel;
  final String basketLabelPrefix;
  final String nextButtonLabel;

  int get grandTotal => itemsTotal + deliveryFee;

  String _formatPrice(int value) {
    return '$value ₸';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 168,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 18,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          deliveryLabel,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 18,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '$basketLabelPrefix ($itemsCount)',
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 18,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatPrice(deliveryFee),
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _formatPrice(itemsTotal),
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 53,
                child: ElevatedButton(
                  onPressed: onNextTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF489F2A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        nextButtonLabel,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _formatPrice(grandTotal),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
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
