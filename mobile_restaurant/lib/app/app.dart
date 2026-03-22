import 'package:flutter/material.dart';
import '../features/auth/presentation/pages/restaurant_entry_page.dart';

class JetkizRestaurantApp extends StatelessWidget {
  const JetkizRestaurantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Jetkiz Restaurant',
      themeMode: ThemeMode.dark,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B0B0C),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF489F2A),
          secondary: Color(0xFF489F2A),
          surface: Color(0xFF151517),
        ),
      ),
      home: const RestaurantEntryPage(),
    );
  }
}
