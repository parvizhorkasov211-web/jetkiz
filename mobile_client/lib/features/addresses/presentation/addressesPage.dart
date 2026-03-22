import 'package:flutter/material.dart';
import 'package:jetkiz_mobile/core/network/apiClient.dart';
import 'package:jetkiz_mobile/features/addresses/data/addressesApi.dart';
import 'package:jetkiz_mobile/features/addresses/domain/address.dart';
import 'package:jetkiz_mobile/features/addresses/presentation/addressFormPage.dart';

class AddressesPage extends StatefulWidget {
  const AddressesPage({
    super.key,
    this.selectionMode = false,
    this.initialSelectedAddressId,
  });

  final bool selectionMode;
  final String? initialSelectedAddressId;

  @override
  State<AddressesPage> createState() => _AddressesPageState();
}

class _AddressesPageState extends State<AddressesPage> {
  static const Color _green = Color(0xFF489F2A);
  static const Color _bg = Color(0xFFF7FAF5);

  late final AddressesApi _addressesApi;

  bool _isLoading = true;
  bool _isDeleting = false;
  String? _error;
  List<Address> _addresses = [];
  String? _selectedAddressId;

  @override
  void initState() {
    super.initState();
    _addressesApi = AddressesApi(ApiClient());
    _selectedAddressId = widget.initialSelectedAddressId;
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final items = await _addressesApi.getMyAddresses();

      if (!mounted) return;

      setState(() {
        _addresses = items;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error =
            'Не удалось загрузить адреса. Проверь backend и попробуй ещё раз.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openCreateAddress() async {
    final result = await Navigator.of(context).push<Address>(
      MaterialPageRoute(
        builder: (_) => const AddressFormPage(),
      ),
    );

    if (!mounted || result == null) return;

    await _loadAddresses();

    if (widget.selectionMode && mounted) {
      setState(() {
        _selectedAddressId = result.id;
      });
      Navigator.of(context).pop(result);
    }
  }

  Future<void> _openEditAddress(Address address) async {
    final result = await Navigator.of(context).push<Address>(
      MaterialPageRoute(
        builder: (_) => AddressFormPage(initialAddress: address),
      ),
    );

    if (!mounted || result == null) return;

    await _loadAddresses();

    if (_selectedAddressId == address.id) {
      setState(() {
        _selectedAddressId = result.id;
      });
    }
  }

  Future<void> _deleteAddress(Address address) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Удалить адрес?'),
              content:
                  Text('Адрес "${address.title}" будет удалён из сохранённых.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Отмена'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Удалить'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmed || _isDeleting) return;

    setState(() {
      _isDeleting = true;
    });

    try {
      await _addressesApi.deleteAddress(address.id);

      if (!mounted) return;

      if (_selectedAddressId == address.id) {
        _selectedAddressId = null;
      }

      await _loadAddresses();
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось удалить адрес'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  void _selectAddress(Address address) {
    if (!widget.selectionMode) return;

    setState(() {
      _selectedAddressId = address.id;
    });

    Navigator.of(context).pop(address);
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.selectionMode ? 'Адрес доставки' : 'Мои адреса';

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _green,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(title),
      ),
      body: Column(
        children: [
          Container(
            color: _green,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.selectionMode
                        ? 'Выберите сохранённый адрес или добавьте новый'
                        : 'Управляйте своими адресами доставки',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.2,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _openCreateAddress,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: _green,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text(
                    'Добавить',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: RefreshIndicator(
                onRefresh: _loadAddresses,
                child: _buildBody(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 80),
          Text(
            _error!,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Center(
            child: FilledButton(
              onPressed: _loadAddresses,
              child: const Text('Повторить'),
            ),
          ),
        ],
      );
    }

    if (_addresses.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 80),
          const Icon(
            Icons.location_on_outlined,
            size: 56,
            color: Color(0xFF9CA3AF),
          ),
          const SizedBox(height: 16),
          const Text(
            'Сохранённых адресов пока нет',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Добавьте адрес сейчас, чтобы потом выбирать его одним нажатием при заказе.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: FilledButton(
              onPressed: _openCreateAddress,
              style: FilledButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Добавить адрес'),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemBuilder: (context, index) {
        final address = _addresses[index];
        final isSelected = address.id == _selectedAddressId;

        return _AddressCard(
          address: address,
          isSelected: isSelected,
          selectionMode: widget.selectionMode,
          onTap: () {
            if (widget.selectionMode) {
              _selectAddress(address);
            }
          },
          onEditTap: () => _openEditAddress(address),
          onDeleteTap: () => _deleteAddress(address),
        );
      },
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemCount: _addresses.length,
    );
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.address,
    required this.isSelected,
    required this.selectionMode,
    required this.onTap,
    required this.onEditTap,
    required this.onDeleteTap,
  });

  final Address address;
  final bool isSelected;
  final bool selectionMode;
  final VoidCallback onTap;
  final VoidCallback onEditTap;
  final VoidCallback onDeleteTap;

  @override
  Widget build(BuildContext context) {
    final borderColor =
        isSelected ? const Color(0xFF489F2A) : const Color(0xFFE5E7EB);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: selectionMode ? onTap : null,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: borderColor,
              width: isSelected ? 2 : 1,
            ),
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
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFFEAF7E4)
                      : const Color(0xFFF3F4F6),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isSelected ? Icons.check_circle : Icons.location_on_outlined,
                  color: isSelected
                      ? const Color(0xFF489F2A)
                      : const Color(0xFF6B7280),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: selectionMode ? onTap : null,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        address.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        address.address,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                      ),
                      if (address.shortDetails.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          address.shortDetails,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                      if ((address.comment ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          address.comment!.trim(),
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                children: [
                  IconButton(
                    onPressed: onEditTap,
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Редактировать',
                  ),
                  IconButton(
                    onPressed: onDeleteTap,
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Удалить',
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
