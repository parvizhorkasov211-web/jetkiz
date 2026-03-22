import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:jetkiz_mobile/core/localization/appLocalizationScope.dart';
import 'package:jetkiz_mobile/core/network/apiClient.dart';
import 'package:jetkiz_mobile/features/addresses/presentation/addressesPage.dart';
import 'package:jetkiz_mobile/features/auth/data/authStorage.dart';
import 'package:jetkiz_mobile/features/orders/presentation/ordersPage.dart';
import 'package:jetkiz_mobile/features/profile/data/profileApi.dart';
import 'package:jetkiz_mobile/features/profile/domain/profileData.dart';
import 'package:jetkiz_mobile/features/settings/presentation/settingsPage.dart';

/// ProfilePage
///
/// Контекст для будущих сессий ChatGPT:
/// - Это экран профиля для УЖЕ авторизованного клиента.
/// - Этот экран не должен сам решать, авторизован клиент или нет.
/// - Проверка auth должна происходить уровнем выше: ProfileEntryPage.
/// - После logout нужно очищать token через AuthStorage.clear()
///   и уведомлять ProfileEntryPage через onLoggedOut().
///
/// Подтверждённые backend endpoints:
/// - GET /users/me
/// - POST /users/me/avatar
///
/// Upload avatar:
/// - фото выбирается с телефона через image_picker
/// - файл уходит в backend как multipart/form-data
/// - поле файла: "file"
///
/// Навигация:
/// - "Адрес" -> AddressesPage
/// - "История заказов" -> OrdersPage
/// - "Поддержка" -> позже SupportPage / support flow
/// - "Мои данные" -> позже EditProfilePage / profile details
/// - "Добавить карту" -> позже cards flow
/// - "Настройки" -> SettingsPage
/// - "Договор и оферта" -> позже legal page / webview
class ProfilePage extends StatefulWidget {
  final VoidCallback? onLoggedOut;

  const ProfilePage({
    super.key,
    this.onLoggedOut,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const _green = Color(0xFF489F2A);

  late final ProfileApi _profileApi;
  final ImagePicker _imagePicker = ImagePicker();
  final ApiClient _apiClient = ApiClient();

  ProfileData? _profile;
  bool _isLoading = true;
  bool _isUploadingAvatar = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _profileApi = ProfileApi(_apiClient);
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final profile = await _profileApi.getMe();

      if (!mounted) return;

      setState(() {
        _profile = profile;
      });
    } catch (_) {
      if (!mounted) return;

      final strings = AppLocalizationScope.of(context).strings;

      setState(() {
        _errorText = strings.profileLoadError;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    if (_isUploadingAvatar) return;

    final strings = AppLocalizationScope.of(context).strings;

    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1600,
      );

      if (picked == null) return;

      setState(() {
        _isUploadingAvatar = true;
      });

      final updatedProfile = await _profileApi.uploadMyAvatar(
        File(picked.path),
      );

      if (!mounted) return;

      setState(() {
        _profile = updatedProfile;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(strings.avatarUpdated),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(strings.avatarUploadFailed(error.toString())),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingAvatar = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    final strings = AppLocalizationScope.of(context).strings;
    final authStorage = AuthStorage();

    await authStorage.clear();
    _apiClient.clearAccessToken();
    widget.onLoggedOut?.call();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(strings.loggedOutMessage),
      ),
    );
  }

  void _showComingSoon(String title) {
    final strings = AppLocalizationScope.of(context).strings;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(strings.comingSoon(title)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizationScope.of(context).strings;

    const backgroundColor = Color(0xFFF9F9F9);
    const menuColor = Color(0xFFDEDEDE);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadProfile,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
            children: [
              const SizedBox(height: 8),
              SizedBox(
                height: 40,
                child: Center(
                  child: Text(
                    strings.profileTitle,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: _green,
                    ),
                  ),
                )
              else if (_errorText != null)
                _ProfileErrorCard(
                  message: _errorText!,
                  retryText: strings.retry,
                  onRetry: _loadProfile,
                )
              else ...[
                _ProfileHeaderCard(
                  profile: _profile,
                  defaultName: strings.profileDefaultName,
                  defaultSubtitle: strings.profileDefaultSubtitle,
                  avatarHint: strings.profileAvatarHint,
                  isUploadingAvatar: _isUploadingAvatar,
                  onAvatarTap: _pickAndUploadAvatar,
                ),
                const SizedBox(height: 36),
                _ProfileMenuTile(
                  backgroundColor: menuColor,
                  icon: Icons.badge_outlined,
                  title: strings.profileMyData,
                  onTap: () => _showComingSoon(strings.profileMyData),
                ),
                const SizedBox(height: 10),
                _ProfileMenuTile(
                  backgroundColor: menuColor,
                  icon: Icons.credit_card_outlined,
                  title: strings.profileAddCard,
                  onTap: () => _showComingSoon(strings.profileAddCard),
                ),
                const SizedBox(height: 10),
                _ProfileMenuTile(
                  backgroundColor: menuColor,
                  icon: Icons.settings_outlined,
                  title: strings.profileSettings,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SettingsPage(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                _ProfileMenuTile(
                  backgroundColor: menuColor,
                  icon: Icons.location_on_outlined,
                  title: strings.profileAddress,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AddressesPage(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                _ProfileMenuTile(
                  backgroundColor: menuColor,
                  icon: Icons.receipt_long_outlined,
                  title: strings.profileOrdersHistory,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const OrdersPage(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                _ProfileMenuTile(
                  backgroundColor: menuColor,
                  icon: Icons.support_agent_outlined,
                  title: strings.profileSupport,
                  onTap: () => _showComingSoon(strings.profileSupport),
                ),
                const SizedBox(height: 10),
                _ProfileMenuTile(
                  backgroundColor: menuColor,
                  icon: Icons.description_outlined,
                  title: strings.profileOffer,
                  onTap: () => _showComingSoon(strings.profileOffer),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout_rounded),
                    label: Text(strings.logout),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _green,
                      side: const BorderSide(color: _green),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileHeaderCard extends StatelessWidget {
  final ProfileData? profile;
  final String defaultName;
  final String defaultSubtitle;
  final String avatarHint;
  final bool isUploadingAvatar;
  final VoidCallback onAvatarTap;

  const _ProfileHeaderCard({
    required this.profile,
    required this.defaultName,
    required this.defaultSubtitle,
    required this.avatarHint,
    required this.isUploadingAvatar,
    required this.onAvatarTap,
  });

  @override
  Widget build(BuildContext context) {
    final avatarUrl = profile?.resolvedAvatarUrl;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: onAvatarTap,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircleAvatar(
                  radius: 34,
                  backgroundColor: const Color(0xFFEDEDED),
                  backgroundImage:
                      avatarUrl != null ? NetworkImage(avatarUrl) : null,
                  child: avatarUrl == null
                      ? const Icon(
                          Icons.person_rounded,
                          size: 34,
                          color: Colors.black87,
                        )
                      : null,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: const Color(0xFF489F2A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white,
                        width: 2,
                      ),
                    ),
                    child: isUploadingAvatar
                        ? const Padding(
                            padding: EdgeInsets.all(5),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.camera_alt_rounded,
                            size: 12,
                            color: Colors.white,
                          ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            profile?.displayTitle ?? defaultName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            profile?.displaySubtitle ?? defaultSubtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            avatarHint,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.black45,
              fontSize: 11,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileErrorCard extends StatelessWidget {
  final String message;
  final String retryText;
  final Future<void> Function() onRetry;

  const _ProfileErrorCard({
    required this.message,
    required this.retryText,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => onRetry(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF489F2A),
              foregroundColor: Colors.white,
            ),
            child: Text(retryText),
          ),
        ],
      ),
    );
  }
}

class _ProfileMenuTile extends StatelessWidget {
  final Color backgroundColor;
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _ProfileMenuTile({
    required this.backgroundColor,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          height: 43,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 15,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Colors.black54,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
