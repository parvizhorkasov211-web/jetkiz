/*
  Центральная конфигурация приложения Jetkiz.

  Важно для будущих сессий:
  - разработка идёт на физическом Android устройстве
  - не использовать адрес эмулятора 10.0.2.2
  - backend доступен через adb reverse и 127.0.0.1:3001
*/

class AppConfig {
  static const String appName = 'Jetkiz';
  static const String baseUrl = 'http://127.0.0.1:3000';

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);
}
