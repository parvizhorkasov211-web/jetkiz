import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/order.dart';

class OrderCard extends StatelessWidget {
  final Order order;

  const OrderCard({super.key, required this.order});

  Color _statusColor(String status) {
    switch (status) {
      case 'NEW':
        return AppColors.statusNew;
      case 'COOKING':
        return AppColors.statusCooking;
      case 'READY':
        return AppColors.statusReady;
      case 'DELIVERED':
        return AppColors.statusDelivered;
      default:
        return AppColors.statusDelivered;
    }
  }

  String _statusText(String status) {
    switch (status) {
      case 'NEW':
        return 'Новый';
      case 'COOKING':
        return 'Готовится';
      case 'READY':
        return 'Готов';
      case 'DELIVERED':
        return 'Доставлен';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(order.status);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            blurRadius: 14,
            offset: Offset(0, 6),
            color: Color(0x14000000),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Заказ #${order.id}',
                  style: AppTextStyles.titleLarge,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _statusText(order.status),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(order.customerName, style: AppTextStyles.bodyLarge),
          const SizedBox(height: 6),
          Text(
            '${order.itemsCount} поз. • ${order.createdAt}',
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: 12),
          Text(
            '${order.totalPrice.toStringAsFixed(0)} ₸',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
