/*
  Временный стартовый экран Jetkiz.

  Это не финальный главный экран.
  Экран нужен для проверки, что новый чистый Flutter-клиент запущен правильно.

  После получения реальных backend endpoint этот экран будет заменён
  на первый рабочий экран приложения.
*/

import 'package:flutter/material.dart';
import 'package:jetkiz_mobile/core/config/appConfig.dart';

class StartPage extends StatelessWidget {
  const StartPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Jetkiz')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Новый клиент Jetkiz запущен',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Следующий этап — подключение реального backend endpoint и создание первого рабочего экрана.',
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              const _InfoBlock(
                title: 'App',
                value: AppConfig.appName,
              ),
              const SizedBox(height: 12),
              const _InfoBlock(
                title: 'Backend',
                value: AppConfig.baseUrl,
              ),
              const SizedBox(height: 12),
              const _InfoBlock(
                title: 'Android rule',
                value: 'adb reverse tcp:3001 tcp:3001',
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // TODO(JETKIZ): Здесь будет переход на первый реальный экран.
                    // Например:
                    // Navigator.push(... RestaurantsPage());
                  },
                  child: const Text('Продолжить разработку'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  final String title;
  final String value;

  const _InfoBlock({
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE7E7E7)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.labelLarge),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
