/*
  JETKIZ MOBILE

  Новый Flutter-клиент Jetkiz создаётся с нуля.
  Старый мобильный код удалён и больше не используется.

  Backend:
  - локально на компьютере разработчика
  - базовый адрес для mobile: http://127.0.0.1:3001
  - Android устройство подключается через:
    adb reverse tcp:3001 tcp:3001

  Важно:
  - backend-first подход
  - нельзя придумывать endpoint и JSON
  - каждый экран строится только после проверки реального backend ответа
*/

import 'package:flutter/widgets.dart';
import 'package:jetkiz_mobile/core/network/apiClient.dart';
import 'app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiClient().init();
  runApp(const JetkizApp());
}
