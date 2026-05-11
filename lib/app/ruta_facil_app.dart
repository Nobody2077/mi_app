import 'package:flutter/material.dart';

import '../features/auth/presentation/login_page.dart';
import 'app_settings.dart';
import 'app_theme.dart';

class RutaFacilApp extends StatelessWidget {
  const RutaFacilApp({required this.settings, super.key});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) {
        return AppSettingsScope(
          settings: settings,
          child: MaterialApp(
            title: 'Ruta Facil El Alto',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: settings.themeMode,
            home: const LoginPage(),
          ),
        );
      },
    );
  }
}

class AppSettingsScope extends InheritedNotifier<AppSettings> {
  const AppSettingsScope({
    required AppSettings settings,
    required super.child,
    super.key,
  }) : super(notifier: settings);

  static AppSettings of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<AppSettingsScope>();
    assert(scope != null, 'AppSettingsScope not found');
    return scope!.notifier!;
  }

  static AppSettings? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<AppSettingsScope>()
        ?.notifier;
  }
}
