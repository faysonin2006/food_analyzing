import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/app_feedback.dart';
import 'core/network_monitor.dart';
import 'core/app_notifications.dart';
import 'core/app_scope.dart';
import 'core/app_settings.dart';
import 'core/app_theme.dart';
import 'screens/auth_gate_screen.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'repositories/app_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = AppSettings();
  await settings.load();
  await AppNotifications.instance.initialize();
  await AppNotifications.instance.applySettings(
    settings.notificationPreferences,
  );
  await AppFeedbackCenter.instance.initialize();
  await AppNotifications.instance.syncReminderInbox(
    settings.notificationPreferences,
  );
  NetworkMonitor.instance.start();
  runApp(MyApp(settings: settings));
}

class MyApp extends StatefulWidget {
  final AppSettings settings;
  const MyApp({super.key, required this.settings});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final AppRepository _repository = AppRepository.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _repository.authSignal.addListener(_handleAuthSignal);
  }

  @override
  void dispose() {
    _repository.authSignal.removeListener(_handleAuthSignal);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    AppNotifications.instance.syncReminderInbox(
      widget.settings.notificationPreferences,
    );
  }

  Future<void> _handleAuthSignal() async {
    final token = await _repository.getToken();
    if (!mounted || (token != null && token.isNotEmpty)) return;

    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;
    navigator.pushNamedAndRemoveUntil('/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      settings: widget.settings,
      child: AnimatedBuilder(
        animation: widget.settings,
        builder: (_, _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            navigatorKey: _navigatorKey,
            locale: widget.settings.locale,
            supportedLocales: const [Locale('ru'), Locale('en')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            themeMode: widget.settings.themeMode,
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
