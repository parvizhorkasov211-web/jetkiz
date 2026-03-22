/// AuthSession
///
/// Контекст для будущих сессий ChatGPT:
/// - Это базовая auth-модель mobile клиента Jetkiz.
/// - Источник истины для авторизации: наличие accessToken.
/// - Если accessToken пустой или null -> пользователь считается неавторизованным.
/// - После реальной SMS-авторизации backend должен вернуть токен клиента.
/// - Этот токен потом используется:
///   - для Profile
///   - для Addresses
///   - для Orders
///   - для Checkout
/// - userId нельзя выдумывать на mobile. Его должен определять backend.
///
/// В будущем сюда можно добавить:
/// - refreshToken
/// - phone
/// - userId
/// - expiresAt
class AuthSession {
  final String? accessToken;

  const AuthSession({
    required this.accessToken,
  });

  bool get isAuthorized => accessToken != null && accessToken!.isNotEmpty;
}
