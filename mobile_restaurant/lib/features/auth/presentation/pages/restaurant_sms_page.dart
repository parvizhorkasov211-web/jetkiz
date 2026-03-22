import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../orders/presentation/pages/restaurant_orders_page.dart';
import '../../data/auth_api.dart';
import '../../data/auth_storage.dart';

class RestaurantSmsPage extends StatefulWidget {
  final String phone;
  final bool isNewUser;
  final Map<String, dynamic>? registerData;

  const RestaurantSmsPage({
    super.key,
    required this.phone,
    this.isNewUser = false,
    this.registerData,
  });

  @override
  State<RestaurantSmsPage> createState() => _RestaurantSmsPageState();
}

class _RestaurantSmsPageState extends State<RestaurantSmsPage> {
  final AuthApi _authApi = AuthApi();
  final AuthStorage _storage = AuthStorage();

  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;

  Timer? _timer;
  int _secondsLeft = 60;
  bool _canResend = false;
  bool _isVerifying = false;
  bool _isResending = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(4, (_) => TextEditingController());
    _focusNodes = List.generate(4, (_) => FocusNode());
    _startTimer();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNodes.first.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();

    setState(() {
      _secondsLeft = 60;
      _canResend = false;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() {
          _secondsLeft = 0;
          _canResend = true;
        });
      } else {
        setState(() {
          _secondsLeft--;
        });
      }
    });
  }

  String get _code => _controllers.map((e) => e.text).join();

  void _clearCode() {
    for (final c in _controllers) {
      c.clear();
    }
  }

  Future<void> _submit() async {
    if (_code.length != 4) {
      setState(() {
        _errorText = 'Введите 4-значный код';
      });
      return;
    }

    setState(() {
      _errorText = null;
      _isVerifying = true;
    });

    try {
      final response = await _authApi.verifyCode(
        phone: widget.phone,
        code: _code,
      );

      final accessToken = response['accessToken']?.toString();
      final refreshToken = response['refreshToken']?.toString();

      if (accessToken == null ||
          accessToken.isEmpty ||
          refreshToken == null ||
          refreshToken.isEmpty) {
        throw Exception('Токены не пришли с сервера');
      }

      await _storage.saveTokens(accessToken, refreshToken);

      if (widget.isNewUser) {
        final registerData = widget.registerData ?? {};
        debugPrint('New restaurant registration data: $registerData');
      }

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const RestaurantOrdersPage(),
        ),
        (route) => false,
      );
    } catch (e) {
      _clearCode();

      setState(() {
        _errorText = e.toString().replaceFirst('Exception: ', '');
      });

      if (mounted) {
        _focusNodes.first.requestFocus();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isVerifying = false;
        });
      }
    }
  }

  Future<void> _resend() async {
    if (!_canResend || _isResending) return;

    setState(() {
      _errorText = null;
      _isResending = true;
    });

    try {
      await _authApi.requestCode(phone: widget.phone);
      _clearCode();
      _startTimer();

      if (mounted) {
        _focusNodes.first.requestFocus();
      }
    } catch (e) {
      setState(() {
        _errorText = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
        });
      }
    }
  }

  void _onChanged(int index, String value) {
    if (value.isEmpty) {
      setState(() {
        _errorText = null;
      });
      return;
    }

    final digit = value.replaceAll(RegExp(r'\D'), '');
    if (digit.isEmpty) {
      _controllers[index].clear();
      return;
    }

    _controllers[index].text = digit.characters.last;
    _controllers[index].selection = const TextSelection.collapsed(offset: 1);

    setState(() {
      _errorText = null;
    });

    if (index < 3) {
      _focusNodes[index + 1].requestFocus();
    } else {
      _focusNodes[index].unfocus();
      if (_code.length == 4) {
        _submit();
      }
    }
  }

  void _onKeyPressed(int index, KeyEvent event) {
    if (event is! KeyDownEvent) return;

    if (event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _focusNodes[index - 1].requestFocus();
      _controllers[index - 1].selection = TextSelection.collapsed(
        offset: _controllers[index - 1].text.length,
      );
    }
  }

  Future<void> _handlePaste() async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text ?? '';
    final digits = text.replaceAll(RegExp(r'\D'), '').split('').take(4).toList();

    if (digits.isEmpty) return;

    for (int i = 0; i < 4; i++) {
      _controllers[i].text = i < digits.length ? digits[i] : '';
    }

    final focusIndex = digits.length >= 4 ? 3 : digits.length - 1;
    if (focusIndex >= 0) {
      _focusNodes[focusIndex].requestFocus();
    }

    setState(() {
      _errorText = null;
    });

    if (digits.length == 4) {
      _submit();
    }
  }

  Widget _buildCodeBox(int index) {
    return SizedBox(
      width: 64,
      child: KeyboardListener(
        focusNode: FocusNode(skipTraversal: true),
        onKeyEvent: (event) => _onKeyPressed(index, event),
        child: TextField(
          controller: _controllers[index],
          focusNode: _focusNodes[index],
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w700,
          ),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(1),
          ],
          onChanged: (value) => _onChanged(index, value),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF1F1F23),
            counterText: '',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: Color(0xFF2B2B31)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(
                color: _errorText != null
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF2B2B31),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(
                color: Color(0xFF489F2A),
                width: 1.5,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isNewUser ? 'Подтвердите регистрацию' : 'Введите код';
    final subtitle = widget.isNewUser
        ? 'Мы отправили код для регистрации на номер\n${widget.phone}'
        : 'Мы отправили код на номер\n${widget.phone}';

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0C),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    color: Colors.white,
                  ),
                ],
              ),
              const Spacer(),
              Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  color: const Color(0xFF489F2A),
                  borderRadius: BorderRadius.circular(24),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.shield_outlined,
                  color: Colors.white,
                  size: 48,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(4, _buildCodeBox),
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _handlePaste,
                  child: const Text(
                    'Вставить код',
                    style: TextStyle(
                      color: Color(0xFF489F2A),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              if (_errorText != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      _errorText!,
                      style: const TextStyle(
                        color: Color(0xFFEF4444),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isVerifying ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF489F2A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    elevation: 0,
                  ),
                  child: _isVerifying
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          widget.isNewUser
                              ? 'Подтвердить регистрацию'
                              : 'Подтвердить',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 18),
              _canResend
                  ? TextButton(
                      onPressed: _isResending ? null : _resend,
                      child: _isResending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF489F2A),
                              ),
                            )
                          : const Text(
                              'Отправить код повторно',
                              style: TextStyle(
                                color: Color(0xFF489F2A),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    )
                  : Text(
                      'Повторная отправка через $_secondsLeft сек',
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 13,
                      ),
                    ),
              const SizedBox(height: 16),
              const Text(
                'Тестовый код backend: 1234',
                style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 12,
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}