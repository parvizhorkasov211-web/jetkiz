import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:jetkiz_mobile/core/localization/appLanguage.dart';
import 'package:jetkiz_mobile/core/localization/appLocalizationScope.dart';

/// SettingsPage
///
/// Контекст для будущих сессий ChatGPT:
/// - Это отдельный экран настроек из ProfilePage.
/// - Сейчас backend для настроек не используется.
/// - Язык меняется ГЛОБАЛЬНО на уровне всего приложения через
///   AppLocalizationScope.
/// - Переключатель языка должен быть только здесь, а не на отдельных экранах.
/// - "Безопасность" позже будет вести на договор клиента / legal flow.
/// - Уведомления пока локальный UI state без backend.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool notificationsEnabled = true;

  static const _background = Color(0xFFF5F5F5);
  static const _tileColor = Color(0xFFD9D9D9);
  static const _green = Color(0xFF489F2A);

  void _showContractSoon() {
    final strings = AppLocalizationScope.of(context).strings;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(strings.settingsContractSoon),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppLocalizationScope.of(context);
    final strings = scope.strings;
    final language = scope.language;

    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 44,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    Text(
                      strings.settingsTitle,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: SvgPicture.asset(
                  'assets/images/Vector.svg',
                  height: 40,
                ),
              ),
              const SizedBox(height: 30),
              _tile(
                child: Row(
                  children: [
                    _icon(Icons.security),
                    const SizedBox(width: 14),
                    Expanded(child: Text(strings.settingsSecurity)),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                onTap: _showContractSoon,
              ),
              const SizedBox(height: 10),
              _tile(
                child: Row(
                  children: [
                    _icon(Icons.notifications),
                    const SizedBox(width: 14),
                    Expanded(child: Text(strings.settingsNotifications)),
                    Switch(
                      value: notificationsEnabled,
                      activeColor: _green,
                      onChanged: (v) {
                        setState(() {
                          notificationsEnabled = v;
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _tile(
                child: Row(
                  children: [
                    _icon(Icons.language),
                    const SizedBox(width: 14),
                    Expanded(child: Text(strings.settingsLanguage)),
                    _languageButton(
                      label: 'Рус',
                      selected: language == AppLanguage.ru,
                      onTap: () => scope.onLanguageChanged(AppLanguage.ru),
                    ),
                    const SizedBox(width: 6),
                    _languageButton(
                      label: 'Қаз',
                      selected: language == AppLanguage.kk,
                      onTap: () => scope.onLanguageChanged(AppLanguage.kk),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tile({required Widget child, VoidCallback? onTap}) {
    return Material(
      color: _tileColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: child,
        ),
      ),
    );
  }

  Widget _icon(IconData icon) {
    return Container(
      width: 34,
      height: 34,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 18, color: _green),
    );
  }

  Widget _languageButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? _green : Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.black,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
