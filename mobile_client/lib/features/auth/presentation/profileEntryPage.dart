import 'package:flutter/material.dart';
import 'package:jetkiz_mobile/core/network/apiClient.dart';
import 'package:jetkiz_mobile/features/auth/data/authStorage.dart';
import 'package:jetkiz_mobile/features/auth/presentation/phoneLoginPage.dart';
import 'package:jetkiz_mobile/features/profile/presentation/profilePage.dart';

/// ProfileEntryPage
///
/// Контекст для будущих сессий ChatGPT:
/// - Это auth gate для вкладки Profile.
/// - Экран не хранит токен сам, а только проверяет его наличие через AuthStorage.
/// - Если token есть -> открывается ProfilePage.
/// - Если token нет -> открывается PhoneLoginPage.
/// - После logout или успешной авторизации gate должен обновиться.
///
/// Важно:
/// - ApiClient в проекте должен быть единым shared singleton.
/// - При новом запуске приложения токен из AuthStorage нужно восстановить
///   в ApiClient до открытия ProfilePage.
class ProfileEntryPage extends StatefulWidget {
  const ProfileEntryPage({super.key});

  @override
  State<ProfileEntryPage> createState() => _ProfileEntryPageState();
}

class _ProfileEntryPageState extends State<ProfileEntryPage> {
  final AuthStorage _authStorage = AuthStorage();
  final ApiClient _apiClient = ApiClient();

  late Future<bool> _sessionFuture;

  @override
  void initState() {
    super.initState();
    _sessionFuture = _restoreSession();
  }

  Future<bool> _restoreSession() async {
    final token = await _authStorage.getAccessToken();
    final hasToken = token != null && token.trim().isNotEmpty;

    if (hasToken) {
      _apiClient.setAccessToken(token);
    } else {
      _apiClient.clearAccessToken();
    }

    return hasToken;
  }

  Future<void> refreshAuthState() async {
    setState(() {
      _sessionFuture = _restoreSession();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _sessionFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final hasToken = snapshot.data ?? false;

        if (hasToken) {
          return ProfilePage(
            onLoggedOut: refreshAuthState,
          );
        }

        return PhoneLoginPage(
          onAuthorized: refreshAuthState,
        );
      },
    );
  }
}
