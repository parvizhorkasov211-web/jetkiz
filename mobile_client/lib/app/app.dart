/*
  Корневой widget приложения Jetkiz.

  Здесь хранится верхнеуровневая конфигурация MaterialApp.
  Навигация приложения управляется отсюда.

  Текущий главный экран приложения:
  - MainNavigationPage

  Контекст для будущих сессий ChatGPT:
  - Старый временный StartPage больше не используется как home.
  - RestaurantsPage больше не является стартовым экраном приложения.
  - Главная страница теперь собирается из backend-first данных:
      GET /home-cms/public
      GET /restaurants/public/list
  - На home используются:
      promo
      categories
      pinned restaurants
  - Вкладка Profile не открывает ProfilePage напрямую.
  - Вместо этого Profile tab открывает ProfileEntryPage:
      если клиент авторизован -> ProfilePage
      если клиент не авторизован -> PhoneLoginPage
  - Язык приложения сейчас переключается глобально через SettingsPage.
  - Текущий язык хранится на уровне JetkizApp и доступен через
    AppLocalizationScope во всех экранах.
  - CartPage встроен в нижнюю навигацию как отдельная вкладка.
  - Именованный route '/cart' не должен открывать отдельный standalone CartPage.
  - Route '/cart' должен открывать MainNavigationPage сразу с выбранной вкладкой корзины.
*/

import 'package:flutter/material.dart';
import 'package:jetkiz_mobile/core/config/appConfig.dart';
import 'package:jetkiz_mobile/core/localization/appLanguage.dart';
import 'package:jetkiz_mobile/core/localization/appLocalizationScope.dart';
import 'package:jetkiz_mobile/features/auth/presentation/profileEntryPage.dart';
import 'package:jetkiz_mobile/features/cart/presentation/cartPage.dart';
import 'package:jetkiz_mobile/features/favorites/presentation/favoritesPage.dart';
import 'package:jetkiz_mobile/features/home/presentation/homePage.dart';

class JetkizApp extends StatefulWidget {
  const JetkizApp({super.key});

  @override
  State<JetkizApp> createState() => _JetkizAppState();
}

class _JetkizAppState extends State<JetkizApp> {
  AppLanguage _language = AppLanguage.ru;

  void _setLanguage(AppLanguage language) {
    if (_language == language) return;

    setState(() {
      _language = language;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppLocalizationScope(
      language: _language,
      onLanguageChanged: _setLanguage,
      child: MaterialApp(
        title: AppConfig.appName,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: Colors.white,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFFF7A00),
          ),
          appBarTheme: const AppBarTheme(
            centerTitle: false,
            elevation: 0,
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
          ),
        ),
        routes: {
          '/cart': (_) => const MainNavigationPage(initialIndex: 2),
        },
        home: const MainNavigationPage(),
      ),
    );
  }
}

class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({
    super.key,
    this.initialIndex = 0,
  });

  /// JETKIZ MOBILE CONTEXT:
  /// initialIndex нужен для навигации в конкретную вкладку из других экранов.
  /// Например:
  /// - ProductDetailsPage -> pushNamed('/cart') -> открывается MainNavigationPage(index: 2)
  /// Это позволяет не создавать второй отдельный CartPage вне нижней навигации.
  final int initialIndex;

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  late int _currentIndex;

  late final List<Widget> _pages = [
    const HomePage(),
    const FavoritesPage(),
    const CartPage(),
    ProfileEntryPage(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  @override
  void didUpdateWidget(covariant MainNavigationPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.initialIndex != widget.initialIndex) {
      _currentIndex = widget.initialIndex;
    }
  }

  void _onItemTapped(int index) {
    if (_currentIndex == index) return;

    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizationScope.of(context).strings;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onItemTapped,
        backgroundColor: Colors.white,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: strings.navHome,
          ),
          NavigationDestination(
            icon: const Icon(Icons.favorite_border),
            selectedIcon: const Icon(Icons.favorite),
            label: strings.navFavorites,
          ),
          NavigationDestination(
            icon: const Icon(Icons.shopping_cart_outlined),
            selectedIcon: const Icon(Icons.shopping_cart),
            label: strings.navCart,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: strings.navProfile,
          ),
        ],
      ),
    );
  }
}
