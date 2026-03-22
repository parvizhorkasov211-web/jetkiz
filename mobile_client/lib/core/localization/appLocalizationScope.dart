import 'package:flutter/material.dart';
import 'package:jetkiz_mobile/core/localization/appLanguage.dart';
import 'package:jetkiz_mobile/core/localization/appStrings.dart';

class AppLocalizationScope extends InheritedWidget {
  final AppLanguage language;
  final ValueChanged<AppLanguage> onLanguageChanged;

  const AppLocalizationScope({
    super.key,
    required this.language,
    required this.onLanguageChanged,
    required super.child,
  });

  static AppLocalizationScope of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AppLocalizationScope>();
    assert(scope != null, 'AppLocalizationScope not found in widget tree');
    return scope!;
  }

  AppStrings get strings => AppStrings(language);

  @override
  bool updateShouldNotify(AppLocalizationScope oldWidget) {
    return oldWidget.language != language;
  }
}
