import 'package:flutter/material.dart';
import 'package:jetkiz_mobile/core/network/apiClient.dart';
import 'package:jetkiz_mobile/features/auth/data/authApi.dart';
import 'package:jetkiz_mobile/features/auth/presentation/smsCodePage.dart';

/// PhoneLoginPage
///
/// Контекст для будущих сессий ChatGPT:
/// - Это первый экран auth flow Jetkiz mobile.
/// - Он открывается внутри вкладки Profile через ProfileEntryPage,
///   если клиент ещё не авторизован.
/// - Этот экран НЕ должен становиться главным экраном всего приложения.
/// - Остальное приложение должно работать без регистрации.
/// - Этот экран не должен сам логинить пользователя и не должен сохранять token.
/// - Token должен сохраняться только после успешного подтверждения SMS-кода
///   на следующем экране SmsCodePage.
///
/// Подтверждённый backend contract:
/// - POST /auth/request-code
/// - body: { phone }
/// - response: { success, phone, code, expiresAt }
///
/// Куда ставить API:
/// - API уже вынесен в lib/features/auth/data/authApi.dart
/// - UI здесь не работает с Dio напрямую
/// - используется только AuthApi + ApiClient
///
/// DEV note:
/// - Пока backend работает с фиксированным кодом 1234.
/// - Это подтверждено в auth.service.ts.
/// - После перехода на реальную SMS-отправку mobile flow останется тем же:
///   request-code -> SmsCodePage -> verify-code -> save token.
class PhoneLoginPage extends StatefulWidget {
  final VoidCallback? onAuthorized;

  const PhoneLoginPage({
    super.key,
    this.onAuthorized,
  });

  @override
  State<PhoneLoginPage> createState() => _PhoneLoginPageState();
}

class _PhoneLoginPageState extends State<PhoneLoginPage> {
  final TextEditingController _phoneController = TextEditingController();

  late final AuthApi _authApi;

  bool _isAgreementAccepted = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _authApi = AuthApi(ApiClient());
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    final digits = _extractDigits(_phoneController.text);
    return _isAgreementAccepted && digits.length == 10 && !_isSubmitting;
  }

  String _extractDigits(String value) {
    return value.replaceAll(RegExp(r'[^0-9]'), '');
  }

  void _onPhoneChanged(String value) {
    final digits = _extractDigits(value);
    final safe = digits.length > 10 ? digits.substring(0, 10) : digits;
    final formatted = _formatRuPhone(safe);

    if (formatted != value) {
      _phoneController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }

    setState(() {});
  }

  String _formatRuPhone(String digits) {
    if (digits.isEmpty) return '';

    final buffer = StringBuffer();

    for (int i = 0; i < digits.length; i++) {
      if (i == 0) buffer.write('(');
      if (i == 3) buffer.write(') ');
      if (i == 6 || i == 8) buffer.write('-');
      buffer.write(digits[i]);
    }

    return buffer.toString();
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;

    final localDigits = _extractDigits(_phoneController.text);
    final normalizedPhone = '+7$localDigits';

    setState(() {
      _isSubmitting = true;
    });

    try {
      final response = await _authApi.requestSmsCode(
        phone: normalizedPhone,
      );

      if (!mounted) return;

      if (!response.success) {
        throw Exception('Backend returned success=false');
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SmsCodePage(
            phone: normalizedPhone,
            onAuthorized: widget.onAuthorized,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Не удалось отправить код: $error'),
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

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF489F2A);
    const lightGreenBorder = Color(0xFF7DC963);
    const lightGray = Color(0xFFF2F2F2);
    const subtitleGray = Color(0xFF737373);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Image.asset(
                'assets/images//Vector.svg',
                height: 68,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) {
                  return const Text(
                    'jetkiz',
                    style: TextStyle(
                      color: primaryGreen,
                      fontSize: 42,
                      fontWeight: FontWeight.w700,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 56),
            const Text(
              'Телефон',
              style: TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.w800,
                color: Colors.black,
                height: 1.05,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              height: 58,
              decoration: BoxDecoration(
                color: lightGray,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: lightGreenBorder),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  const Text(
                    '+7',
                    style: TextStyle(
                      color: subtitleGray,
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 24,
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    color: lightGreenBorder.withValues(alpha: 0.6),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      onChanged: _onPhoneChanged,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                      ),
                      decoration: const InputDecoration(
                        hintText: '(700) 000-00-00',
                        hintStyle: TextStyle(
                          color: Color(0xFF9A9A9A),
                          fontSize: 18,
                        ),
                        border: InputBorder.none,
                        isCollapsed: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isAgreementAccepted = !_isAgreementAccepted;
                    });
                  },
                  child: Container(
                    width: 22,
                    height: 22,
                    margin: const EdgeInsets.only(top: 2),
                    decoration: BoxDecoration(
                      color: _isAgreementAccepted ? primaryGreen : Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: lightGreenBorder,
                        width: 1.4,
                      ),
                    ),
                    child: _isAgreementAccepted
                        ? const Icon(
                            Icons.check,
                            size: 16,
                            color: Colors.white,
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Настоящим я подтверждаю своё согласие с условиями Пользовательского соглашения, а также с Политикой конфиденциальности и даю согласие на сбор и обработку персональных данных.',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: _canSubmit ? _submit : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _canSubmit ? primaryGreen : const Color(0xFFE5E5E5),
                  foregroundColor: _canSubmit ? Colors.white : Colors.black45,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Отправить код',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
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
