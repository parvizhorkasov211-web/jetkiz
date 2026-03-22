import 'package:flutter/material.dart';
import 'package:jetkiz_mobile/features/addresses/domain/address.dart';

/// Shared selected address state for the whole app.
///
/// Current scope:
/// - HomePage
/// - CartPage
/// - future CheckoutPage
///
/// Later this can be persisted to local storage if needed.
class AddressRepository extends ChangeNotifier {
  AddressRepository._();

  static final AddressRepository instance = AddressRepository._();

  Address? _selectedAddress;

  Address? get selectedAddress => _selectedAddress;

  String? get selectedAddressId => _selectedAddress?.id;

  bool get hasSelectedAddress => _selectedAddress != null;

  void setSelectedAddress(Address address) {
    _selectedAddress = address;
    notifyListeners();
  }

  void clearSelectedAddress() {
    _selectedAddress = null;
    notifyListeners();
  }
}
