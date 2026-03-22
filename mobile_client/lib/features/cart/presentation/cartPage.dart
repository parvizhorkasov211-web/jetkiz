import 'package:flutter/material.dart';
import 'package:jetkiz_mobile/core/network/apiClient.dart';
import 'package:jetkiz_mobile/features/addresses/data/addressRepository.dart';
import 'package:jetkiz_mobile/features/addresses/domain/address.dart';
import 'package:jetkiz_mobile/features/addresses/presentation/addressesPage.dart';
import 'package:jetkiz_mobile/features/checkout/presentation/checkoutPage.dart';
import 'package:jetkiz_mobile/features/menu/data/financeConfigApi.dart';

import '../data/cartRepository.dart';
import '../domain/cartItem.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final CartRepository _cart = CartRepository.instance;
  final AddressRepository _addressRepository = AddressRepository.instance;

  late final FinanceConfigApi _financeConfigApi;

  int _deliveryFee = 0;
  bool _isDeliveryLoading = true;

  @override
  void initState() {
    super.initState();
    _financeConfigApi = FinanceConfigApi(ApiClient());
    _cart.addListener(_handleCartChanged);
    _addressRepository.addListener(_handleAddressChanged);
    _loadDeliveryFee();
  }

  @override
  void dispose() {
    _cart.removeListener(_handleCartChanged);
    _addressRepository.removeListener(_handleAddressChanged);
    super.dispose();
  }

  void _handleCartChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _handleAddressChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadDeliveryFee() async {
    try {
      final config = await _financeConfigApi.getFinanceConfig();
      if (!mounted) return;

      setState(() {
        _deliveryFee = config.activeDeliveryFee;
        _isDeliveryLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _deliveryFee = 0;
        _isDeliveryLoading = false;
      });
    }
  }

  Future<void> _openAddressPicker() async {
    final selected = await Navigator.of(context).push<Address>(
      MaterialPageRoute(
        builder: (_) => AddressesPage(
          selectionMode: true,
          initialSelectedAddressId: _addressRepository.selectedAddressId,
        ),
      ),
    );

    if (selected == null || !mounted) return;

    _addressRepository.setSelectedAddress(selected);
  }

  Future<void> _confirmRemove(CartItem item) async {
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Удалить товар?'),
          content: Text('Удалить "${item.title}" из корзины?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Нет'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Удалить'),
            ),
          ],
        );
      },
    );

    if (shouldRemove == true) {
      _cart.remove(item.productId);
    }
  }

  void _goToHomeTab() {
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  void _handleCheckout() {
    if (_cart.state.isEmpty) return;

    if (_addressRepository.selectedAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Сначала выберите адрес доставки'),
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const CheckoutPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = _cart.state;
    final selectedAddress = _addressRepository.selectedAddress;
    final subtotal = state.subtotal;
    final total = subtotal + _deliveryFee;

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF489F2A),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Корзина'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _CartAddressHeader(
            selectedAddress: selectedAddress,
            onTap: _openAddressPicker,
          ),
          Expanded(
            child: state.isEmpty
                ? _EmptyCart(
                    onGoHome: _goToHomeTab,
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    itemBuilder: (context, index) {
                      final item = state.items[index];
                      return _CartItemCard(
                        item: item,
                        onMinus: () => _cart.decrement(item.productId),
                        onPlus: () => _cart.increment(item.productId),
                        onRemove: () => _confirmRemove(item),
                      );
                    },
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemCount: state.items.length,
                  ),
          ),
          _CartSummary(
            subtotal: subtotal,
            deliveryFee: _deliveryFee,
            total: total,
            isLoading: _isDeliveryLoading,
            isDisabled:
                state.isEmpty || selectedAddress == null || _isDeliveryLoading,
            onCheckout: _handleCheckout,
          ),
        ],
      ),
    );
  }
}

class _CartAddressHeader extends StatelessWidget {
  const _CartAddressHeader({
    required this.selectedAddress,
    required this.onTap,
  });

  final Address? selectedAddress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasAddress = selectedAddress != null;

    return Container(
      color: const Color(0xFF489F2A),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.location_on_outlined,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: hasAddress
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              selectedAddress!.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              selectedAddress!.fullSubtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                height: 1.2,
                              ),
                            ),
                          ],
                        )
                      : const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Адрес доставки',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Укажите адрес доставки',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CartItemCard extends StatelessWidget {
  const _CartItemCard({
    required this.item,
    required this.onMinus,
    required this.onPlus,
    required this.onRemove,
  });

  final CartItem item;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: 92,
                height: 92,
                child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                    ? Image.network(
                        item.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _imageFallback(),
                      )
                    : _imageFallback(),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: SizedBox(
                height: 92,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 6),
                    if ((item.description ?? '').isNotEmpty ||
                        (item.weight ?? '').isNotEmpty)
                      Text(
                        [
                          if ((item.description ?? '').isNotEmpty)
                            item.description!,
                          if ((item.weight ?? '').isNotEmpty) item.weight!,
                        ].join(' • '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    const Spacer(),
                    Row(
                      children: [
                        _QuantityButton(
                          icon: Icons.remove,
                          onTap: onMinus,
                          filled: false,
                        ),
                        SizedBox(
                          width: 34,
                          child: Text(
                            '${item.quantity}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        _QuantityButton(
                          icon: Icons.add,
                          onTap: onPlus,
                          filled: true,
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: onRemove,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFEE2E2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.delete_outline,
                              size: 18,
                              color: Color(0xFFEF4444),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${item.totalPrice} ₸',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imageFallback() {
    return Container(
      color: const Color(0xFFF3F4F6),
      child: const Center(
        child: Icon(
          Icons.fastfood_rounded,
          color: Color(0xFF9CA3AF),
          size: 28,
        ),
      ),
    );
  }
}

class _QuantityButton extends StatelessWidget {
  const _QuantityButton({
    required this.icon,
    required this.onTap,
    required this.filled,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: filled ? const Color(0xFF489F2A) : Colors.white,
          shape: BoxShape.circle,
          border: filled ? null : Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x11000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          icon,
          size: 18,
          color: filled ? Colors.white : const Color(0xFF489F2A),
        ),
      ),
    );
  }
}

class _CartSummary extends StatelessWidget {
  const _CartSummary({
    required this.subtotal,
    required this.deliveryFee,
    required this.total,
    required this.isLoading,
    required this.isDisabled,
    required this.onCheckout,
  });

  final int subtotal;
  final int deliveryFee;
  final int total;
  final bool isLoading;
  final bool isDisabled;
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context) {
    final deliveryValue = isLoading ? '...' : '$deliveryFee ₸';
    final totalValue = isLoading ? '...' : '$total ₸';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 18,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SummaryRow(label: 'Сумма', value: '$subtotal ₸'),
            const SizedBox(height: 10),
            _SummaryRow(label: 'Доставка', value: deliveryValue),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            _SummaryRow(
              label: 'Итого',
              value: totalValue,
              isTotal: true,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isDisabled ? null : onCheckout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF489F2A),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFFBFC7BC),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Оформить заказ',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
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

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.isTotal = false,
  });

  final String label;
  final String value;
  final bool isTotal;

  @override
  Widget build(BuildContext context) {
    final textStyle = isTotal
        ? const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF111827),
          )
        : const TextStyle(
            fontSize: 14,
            color: Color(0xFF6B7280),
          );

    final valueStyle = isTotal
        ? const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Color(0xFF111827),
          )
        : const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111827),
          );

    return Row(
      children: [
        Text(label, style: textStyle),
        const Spacer(),
        Text(value, style: valueStyle),
      ],
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart({
    required this.onGoHome,
  });

  final VoidCallback onGoHome;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(
                color: Color(0xFFF3F4F6),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shopping_bag_outlined,
                size: 44,
                color: Color(0xFFB0B7C3),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Корзина пуста',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Добавьте блюда из меню',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: onGoHome,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF489F2A),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
              ),
              child: const Text('На главную'),
            ),
          ],
        ),
      ),
    );
  }
}
