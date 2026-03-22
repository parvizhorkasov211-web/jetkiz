import 'dart:async';

import 'package:flutter/material.dart';
import 'package:jetkiz_mobile/core/network/apiClient.dart';
import 'package:jetkiz_mobile/features/addresses/data/addressRepository.dart';
import 'package:jetkiz_mobile/features/addresses/domain/address.dart';
import 'package:jetkiz_mobile/features/addresses/presentation/addressesPage.dart';
import 'package:jetkiz_mobile/features/cart/data/cartRepository.dart';
import 'package:jetkiz_mobile/features/cart/domain/cartItem.dart';
import 'package:jetkiz_mobile/features/menu/data/financeConfigApi.dart';
import 'package:jetkiz_mobile/features/orders/data/orderApi.dart';
import 'package:jetkiz_mobile/features/orders/domain/createOrderPayload.dart';
import 'package:jetkiz_mobile/features/profile/data/profileApi.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  static const Color _green = Color(0xFF489F2A);
  static const Color _bg = Color(0xFFF7FAF5);

  final CartRepository _cartRepository = CartRepository.instance;
  final AddressRepository _addressRepository = AddressRepository.instance;

  late final FinanceConfigApi _financeConfigApi;
  late final ProfileApi _profileApi;
  late final OrderApi _orderApi;

  int? _selectedCardId;
  int _deliveryFee = 0;
  bool _isDeliveryLoading = true;
  bool _isSubmitting = false;
  bool _orderPlaced = false;

  final List<_CheckoutCard> _savedCards = const [
    _CheckoutCard(
      id: 1,
      maskedNumber: '**** **** **** 4242',
      type: 'Visa',
      expiry: '12/25',
    ),
    _CheckoutCard(
      id: 2,
      maskedNumber: '**** **** **** 8888',
      type: 'Mastercard',
      expiry: '08/26',
    ),
  ];

  @override
  void initState() {
    super.initState();

    final apiClient = ApiClient();
    _financeConfigApi = FinanceConfigApi(apiClient);
    _profileApi = ProfileApi(apiClient);
    _orderApi = OrderApi(apiClient);

    _selectedCardId = _savedCards.isNotEmpty ? _savedCards.first.id : null;
    _cartRepository.addListener(_handleExternalStateChanged);
    _addressRepository.addListener(_handleExternalStateChanged);
    _loadDeliveryFee();
  }

  @override
  void dispose() {
    _cartRepository.removeListener(_handleExternalStateChanged);
    _addressRepository.removeListener(_handleExternalStateChanged);
    super.dispose();
  }

  void _handleExternalStateChanged() {
    if (!mounted) return;
    setState(() {});
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

  Future<void> _changeAddress() async {
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

  Future<void> _handleConfirmOrder() async {
    final address = _addressRepository.selectedAddress;
    final cartState = _cartRepository.state;

    if (_isSubmitting || _orderPlaced) return;

    if (cartState.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Корзина пуста')),
      );
      return;
    }

    if (address == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите адрес доставки')),
      );
      return;
    }

    if (_selectedCardId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите карту для оплаты')),
      );
      return;
    }

    final restaurantId = cartState.restaurantId;
    if (restaurantId == null || restaurantId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось определить ресторан заказа')),
      );
      return;
    }

    final addressId = _addressRepository.selectedAddressId;
    if (addressId == null || addressId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось определить адрес доставки')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final profile = await _profileApi.getMe();

      final phone = profile.phone.trim();
      if (phone.isEmpty) {
        throw Exception('Phone is empty');
      }

      /// ВАЖНО:
      /// Payment provider/backend пока не подключён.
      /// Здесь временно используется client-side positive payment stub,
      /// после которого создаётся реальный заказ через POST /orders.
      ///
      /// Когда backend payment flow будет подтверждён, этот участок нужно
      /// заменить на:
      /// 1. create payment session / intent
      /// 2. confirm payment
      /// 3. create order после успешного payment result
      await Future<void>.delayed(const Duration(milliseconds: 800));

      final payload = CreateOrderPayload(
        restaurantId: restaurantId,
        addressId: addressId,
        phone: phone,
        leaveAtDoor: false,
        comment: null,
        promoCode: null,
        items: cartState.items
            .map(
              (item) => CreateOrderItemPayload(
                productId: item.productId,
                quantity: item.quantity,
              ),
            )
            .toList(),
      );

      await _orderApi.createOrder(payload);

      _cartRepository.clear();

      if (!mounted) return;

      setState(() {
        _orderPlaced = true;
      });
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось создать заказ'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _goHome() {
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    if (_orderPlaced) {
      return _CheckoutSuccessScreen(
        onGoHome: _goHome,
      );
    }

    final cartState = _cartRepository.state;
    final items = cartState.items;
    final address = _addressRepository.selectedAddress;

    final subtotal = cartState.subtotal;
    final total = subtotal + _deliveryFee;

    final isConfirmDisabled = cartState.isEmpty ||
        address == null ||
        _selectedCardId == null ||
        _isDeliveryLoading ||
        _isSubmitting;

    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        children: [
          Container(
            color: _green,
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: MediaQuery.of(context).padding.top + 8,
              bottom: 18,
            ),
            child: Row(
              children: [
                InkWell(
                  onTap: _isSubmitting
                      ? null
                      : () => Navigator.of(context).maybePop(),
                  borderRadius: BorderRadius.circular(20),
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                const Expanded(
                  child: Text(
                    'Оформление заказа',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 32),
              ],
            ),
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 140),
                children: [
                  _CheckoutSectionTitle(title: 'Адрес доставки'),
                  const SizedBox(height: 10),
                  _CheckoutAddressCard(
                    address: address,
                    onTap: _changeAddress,
                  ),
                  const SizedBox(height: 18),
                  _CheckoutSectionTitle(title: 'Ваш заказ'),
                  const SizedBox(height: 10),
                  _CheckoutItemsCard(items: items),
                  const SizedBox(height: 18),
                  _CheckoutSectionTitle(title: 'Выбор карты'),
                  const SizedBox(height: 10),
                  ..._savedCards.map(
                    (card) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _CheckoutCardTile(
                        card: card,
                        isSelected: _selectedCardId == card.id,
                        onTap: () {
                          if (_isSubmitting) return;
                          setState(() {
                            _selectedCardId = card.id;
                          });
                        },
                      ),
                    ),
                  ),
                  _AddNewCardTile(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Экран добавления карты подключим после подтверждения payment flow',
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 18),
                  _CheckoutSectionTitle(title: 'Итого'),
                  const SizedBox(height: 10),
                  _CheckoutSummaryCard(
                    subtotal: subtotal,
                    deliveryFee: _deliveryFee,
                    total: total,
                    isDeliveryLoading: _isDeliveryLoading,
                  ),
                ],
              ),
            ),
          ),
          _CheckoutBottomBar(
            total: total,
            isLoading: _isSubmitting,
            isDisabled: isConfirmDisabled,
            onConfirm: _handleConfirmOrder,
          ),
        ],
      ),
    );
  }
}

class _CheckoutSectionTitle extends StatelessWidget {
  const _CheckoutSectionTitle({
    required this.title,
  });

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w800,
        color: Color(0xFF111827),
      ),
    );
  }
}

class _CheckoutAddressCard extends StatelessWidget {
  const _CheckoutAddressCard({
    required this.address,
    required this.onTap,
  });

  final Address? address;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasAddress = address != null;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0F000000),
                blurRadius: 14,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: Color(0xFFEAF7E4),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.location_on_outlined,
                  color: Color(0xFF489F2A),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: hasAddress
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            address!.title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            address!.fullSubtitle,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF6B7280),
                              height: 1.3,
                            ),
                          ),
                        ],
                      )
                    : const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Адрес не выбран',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF111827),
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Нажмите, чтобы выбрать адрес доставки',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF6B7280),
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                size: 24,
                color: Color(0xFF489F2A),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckoutItemsCard extends StatelessWidget {
  const _CheckoutItemsCard({
    required this.items,
  });

  final List<CartItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: const Text(
          'Корзина пуста',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF6B7280),
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            _CheckoutItemRow(item: items[i]),
            if (i != items.length - 1)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1),
              ),
          ],
        ],
      ),
    );
  }
}

class _CheckoutItemRow extends StatelessWidget {
  const _CheckoutItemRow({
    required this.item,
  });

  final CartItem item;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            item.title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${item.totalPrice} ₸',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${item.quantity} × ${item.price} ₸',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CheckoutCardTile extends StatelessWidget {
  const _CheckoutCardTile({
    required this.card,
    required this.isSelected,
    required this.onTap,
  });

  final _CheckoutCard card;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF489F2A);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFF2FAEE) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected ? green : const Color(0xFFE5E7EB),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isSelected ? green : const Color(0xFFF3F4F6),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.credit_card_rounded,
                  color: isSelected ? Colors.white : const Color(0xFF6B7280),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.type,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${card.maskedNumber} • ${card.expiry}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? green : Colors.transparent,
                  border: Border.all(
                    color: isSelected ? green : const Color(0xFFD1D5DB),
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? const Center(
                        child: SizedBox(
                          width: 8,
                          height: 8,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddNewCardTile extends StatelessWidget {
  const _AddNewCardTile({
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFFD1D5DB),
              style: BorderStyle.solid,
            ),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_rounded,
                color: Color(0xFF6B7280),
              ),
              SizedBox(width: 8),
              Text(
                'Добавить новую карту',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckoutSummaryCard extends StatelessWidget {
  const _CheckoutSummaryCard({
    required this.subtotal,
    required this.deliveryFee,
    required this.total,
    required this.isDeliveryLoading,
  });

  final int subtotal;
  final int deliveryFee;
  final int total;
  final bool isDeliveryLoading;

  @override
  Widget build(BuildContext context) {
    final deliveryText = isDeliveryLoading ? '...' : '$deliveryFee ₸';
    final totalText = isDeliveryLoading ? '...' : '$total ₸';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          _CheckoutSummaryRow(
            label: 'Стоимость товаров',
            value: '$subtotal ₸',
          ),
          const SizedBox(height: 10),
          _CheckoutSummaryRow(
            label: 'Доставка',
            value: deliveryText,
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          _CheckoutSummaryRow(
            label: 'К оплате',
            value: totalText,
            isTotal: true,
          ),
        ],
      ),
    );
  }
}

class _CheckoutSummaryRow extends StatelessWidget {
  const _CheckoutSummaryRow({
    required this.label,
    required this.value,
    this.isTotal = false,
  });

  final String label;
  final String value;
  final bool isTotal;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.w800 : FontWeight.w500,
            color: isTotal ? const Color(0xFF111827) : const Color(0xFF6B7280),
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 18 : 14,
            fontWeight: isTotal ? FontWeight.w900 : FontWeight.w700,
            color: isTotal ? const Color(0xFF489F2A) : const Color(0xFF111827),
          ),
        ),
      ],
    );
  }
}

class _CheckoutBottomBar extends StatelessWidget {
  const _CheckoutBottomBar({
    required this.total,
    required this.isLoading,
    required this.isDisabled,
    required this.onConfirm,
  });

  final int total;
  final bool isLoading;
  final bool isDisabled;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
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
        child: SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: isDisabled ? null : onConfirm,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF489F2A),
              disabledBackgroundColor: const Color(0xFFBFC7BC),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Подтвердить заказ',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$total ₸',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
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

class _CheckoutSuccessScreen extends StatefulWidget {
  const _CheckoutSuccessScreen({
    required this.onGoHome,
  });

  final VoidCallback onGoHome;

  @override
  State<_CheckoutSuccessScreen> createState() => _CheckoutSuccessScreenState();
}

class _CheckoutSuccessScreenState extends State<_CheckoutSuccessScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(
      const Duration(seconds: 3),
      widget.onGoHome,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF5),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 110,
                height: 110,
                decoration: const BoxDecoration(
                  color: Color(0xFFEAF7E4),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  size: 70,
                  color: Color(0xFF489F2A),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Заказ оформлен',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Ожидайте звонка от ресторана для подтверждения',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: widget.onGoHome,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF489F2A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'На главную',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckoutCard {
  const _CheckoutCard({
    required this.id,
    required this.maskedNumber,
    required this.type,
    required this.expiry,
  });

  final int id;
  final String maskedNumber;
  final String type;
  final String expiry;
}
