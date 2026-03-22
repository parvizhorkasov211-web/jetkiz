import 'package:flutter/material.dart';

import '../../data/auth_api.dart';
import 'restaurant_sms_page.dart';

enum RestaurantAuthTab { login, register }

class RestaurantAuthPage extends StatefulWidget {
  const RestaurantAuthPage({super.key});

  @override
  State<RestaurantAuthPage> createState() => _RestaurantAuthPageState();
}

class _RestaurantAuthPageState extends State<RestaurantAuthPage> {
  final AuthApi _authApi = AuthApi();

  RestaurantAuthTab _tab = RestaurantAuthTab.login;
  bool _isLoading = false;

  final TextEditingController _loginPhoneController = TextEditingController();
  final TextEditingController _registerPhoneController =
      TextEditingController();
  final TextEditingController _nameRuController = TextEditingController();
  final TextEditingController _nameKzController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _openTimeController =
      TextEditingController(text: '09:00');
  final TextEditingController _closeTimeController =
      TextEditingController(text: '22:00');

  @override
  void dispose() {
    _loginPhoneController.dispose();
    _registerPhoneController.dispose();
    _nameRuController.dispose();
    _nameKzController.dispose();
    _addressController.dispose();
    _openTimeController.dispose();
    _closeTimeController.dispose();
    super.dispose();
  }

  String _formatPhone(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');

    String normalized = digits;
    if (normalized.startsWith('8')) {
      normalized = '7${normalized.substring(1)}';
    }
    if (!normalized.startsWith('7') && normalized.isNotEmpty) {
      normalized = '7$normalized';
    }
    if (normalized.length > 11) {
      normalized = normalized.substring(0, 11);
    }

    final buffer = StringBuffer('+7');
    if (normalized.length > 1) {
      buffer.write(
        ' (${normalized.substring(1, normalized.length >= 4 ? 4 : normalized.length)}',
      );
    }
    if (normalized.length >= 4) {
      buffer.write(')');
    }
    if (normalized.length >= 5) {
      buffer.write(
        ' ${normalized.substring(4, normalized.length >= 7 ? 7 : normalized.length)}',
      );
    }
    if (normalized.length >= 8) {
      buffer.write(
        '-${normalized.substring(7, normalized.length >= 9 ? 9 : normalized.length)}',
      );
    }
    if (normalized.length >= 10) {
      buffer.write(
        '-${normalized.substring(9, normalized.length >= 11 ? 11 : normalized.length)}',
      );
    }

    return buffer.toString();
  }

  String _normalizePhone(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('8')) {
      return '7${digits.substring(1)}';
    }
    if (digits.startsWith('7')) {
      return digits;
    }
    return '7$digits';
  }

  bool _isValidPhone(String value) {
    return _normalizePhone(value).length == 11;
  }

  void _onPhoneChanged(TextEditingController controller, String raw) {
    final formatted = _formatPhone(raw);
    controller.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  Future<void> _pickTime(TextEditingController controller) async {
    final parts = controller.text.split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts.first) ?? 9,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
    );

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF489F2A),
              surface: Color(0xFF121826),
              onPrimary: Colors.white,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final hour = picked.hour.toString().padLeft(2, '0');
      final minute = picked.minute.toString().padLeft(2, '0');
      controller.text = '$hour:$minute';
      setState(() {});
    }
  }

  Future<void> _submitLogin() async {
    final phone = _loginPhoneController.text.trim();

    if (!_isValidPhone(phone)) {
      _showError('Введите корректный номер телефона');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final normalizedPhone = _normalizePhone(phone);

      await _authApi.requestCode(phone: normalizedPhone);

      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RestaurantSmsPage(
            phone: normalizedPhone,
            isNewUser: false,
          ),
        ),
      );
    } catch (_) {
      _showError('Не удалось отправить код');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _submitRegister() async {
    final phone = _registerPhoneController.text.trim();
    final nameRu = _nameRuController.text.trim();
    final nameKz = _nameKzController.text.trim();
    final address = _addressController.text.trim();
    final openTime = _openTimeController.text.trim();
    final closeTime = _closeTimeController.text.trim();

    if (!_isValidPhone(phone)) {
      _showError('Введите корректный номер телефона');
      return;
    }

    if (nameRu.isEmpty || nameKz.isEmpty || address.isEmpty) {
      _showError('Заполните все обязательные поля');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final normalizedPhone = _normalizePhone(phone);

      await _authApi.requestCode(phone: normalizedPhone);

      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RestaurantSmsPage(
            phone: normalizedPhone,
            isNewUser: true,
            registerData: {
              'nameRu': nameRu,
              'nameKz': nameKz,
              'address': address,
              'openTime': openTime,
              'closeTime': closeTime,
            },
          ),
        ),
      );
    } catch (_) {
      _showError('Не удалось отправить код');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFFB3261E),
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const backgroundTop = Color(0xFF0E1A2C);
    const backgroundBottom = Color(0xFF08101C);
    const panelColor = Color(0xFF121B2C);
    const borderColor = Color(0xFF22324A);
    const green = Color(0xFF489F2A);
    const textMuted = Color(0xFF95A0B3);

    return Scaffold(
      backgroundColor: const Color(0xFF09111C),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              backgroundTop,
              Color(0xFF0B1524),
              backgroundBottom,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        color: green,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'jetkiz',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontStyle: FontStyle.italic,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Jetkiz',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Панель управления рестораном',
                      style: TextStyle(
                        color: textMuted,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: panelColor.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _AuthTabButton(
                              title: 'Вход',
                              isActive: _tab == RestaurantAuthTab.login,
                              onTap: () {
                                setState(() {
                                  _tab = RestaurantAuthTab.login;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _AuthTabButton(
                              title: 'Регистрация',
                              isActive: _tab == RestaurantAuthTab.register,
                              onTap: () {
                                setState(() {
                                  _tab = RestaurantAuthTab.register;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: panelColor.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: borderColor),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x22000000),
                            blurRadius: 18,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: _tab == RestaurantAuthTab.login
                            ? _buildLoginForm()
                            : _buildRegisterForm(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Column(
      key: const ValueKey('login_form'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'С возвращением!',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Войдите в свой аккаунт',
          style: TextStyle(
            color: Color(0xFF95A0B3),
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 22),
        const _FieldLabel('Номер телефона'),
        const SizedBox(height: 8),
        _DarkTextField(
          controller: _loginPhoneController,
          hintText: '+7 (___) ___-__-__',
          keyboardType: TextInputType.phone,
          prefixIcon: Icons.phone_outlined,
          onChanged: (value) => _onPhoneChanged(_loginPhoneController, value),
        ),
        const SizedBox(height: 18),
        _GreenButton(
          text: _isLoading ? 'Загрузка...' : 'Получить код',
          onPressed: _isLoading ? null : _submitLogin,
        ),
      ],
    );
  }

  Widget _buildRegisterForm() {
    return Column(
      key: const ValueKey('register_form'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Новый ресторан',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Создайте аккаунт',
          style: TextStyle(
            color: Color(0xFF95A0B3),
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 18),
        const _FieldLabel('Номер телефона'),
        const SizedBox(height: 8),
        _DarkTextField(
          controller: _registerPhoneController,
          hintText: '+7 (___) ___-__-__',
          keyboardType: TextInputType.phone,
          prefixIcon: Icons.phone_outlined,
          onChanged: (value) =>
              _onPhoneChanged(_registerPhoneController, value),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _FieldLabel('Название (RU)'),
                  const SizedBox(height: 8),
                  _DarkTextField(
                    controller: _nameRuController,
                    hintText: 'Название',
                    prefixIcon: Icons.storefront_outlined,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _FieldLabel('Название (KZ)'),
                  const SizedBox(height: 8),
                  _DarkTextField(
                    controller: _nameKzController,
                    hintText: 'Атауы',
                    prefixIcon: Icons.storefront_outlined,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const _FieldLabel('Адрес'),
        const SizedBox(height: 8),
        _DarkTextField(
          controller: _addressController,
          hintText: 'г. Щучинск, ул...',
          prefixIcon: Icons.location_on_outlined,
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _FieldLabel('Открытие'),
                  const SizedBox(height: 8),
                  _TimeField(
                    controller: _openTimeController,
                    onTap: () => _pickTime(_openTimeController),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _FieldLabel('Закрытие'),
                  const SizedBox(height: 8),
                  _TimeField(
                    controller: _closeTimeController,
                    onTap: () => _pickTime(_closeTimeController),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _GreenButton(
          text: _isLoading ? 'Загрузка...' : 'Зарегистрироваться',
          onPressed: _isLoading ? null : _submitRegister,
        ),
      ],
    );
  }
}

class _AuthTabButton extends StatelessWidget {
  final String title;
  final bool isActive;
  final VoidCallback onTap;

  const _AuthTabButton({
    required this.title,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 46,
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF489F2A) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          style: TextStyle(
            color: isActive ? Colors.white : const Color(0xFF95A0B3),
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _DarkTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData prefixIcon;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  const _DarkTextField({
    required this.controller,
    required this.hintText,
    required this.prefixIcon,
    this.keyboardType,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: const Color(0xFF101827),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A3950)),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hintText,
          hintStyle: const TextStyle(
            color: Color(0xFF6F7D91),
            fontSize: 14,
          ),
          prefixIcon: Icon(
            prefixIcon,
            color: const Color(0xFF8E9AAF),
            size: 20,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }
}

class _TimeField extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onTap;

  const _TimeField({
    required this.controller,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF101827),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF2A3950)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.access_time_outlined,
              color: Color(0xFF8E9AAF),
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                controller.text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down,
              color: Color(0xFF8E9AAF),
            ),
          ],
        ),
      ),
    );
  }
}

class _GreenButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;

  const _GreenButton({
    required this.text,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF489F2A),
          disabledBackgroundColor: const Color(0xFF489F2A).withValues(alpha: 0.6),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}