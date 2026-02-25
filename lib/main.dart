import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/app_scope.dart';
import 'core/app_settings.dart';
import 'core/app_theme.dart';
import 'screens/auth_gate_screen.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = AppSettings();
  await settings.load();
  runApp(MyApp(settings: settings));
}

class MyApp extends StatelessWidget {
  final AppSettings settings;
  const MyApp({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    return AppScope(
      settings: settings,
      child: AnimatedBuilder(
        animation: settings,
        builder: (_, _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            locale: settings.locale,
            supportedLocales: const [Locale('ru'), Locale('en')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            themeMode: settings.themeMode,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            initialRoute: '/auth',
            routes: {
              '/auth': (_) => const AuthGateScreen(),
              '/login': (_) => const LoginScreen(),
              '/home': (_) => const MainScreen(),
            },
          );
        },
      ),
    );
  }
}
