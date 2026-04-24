import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/tr.dart';
import '../repositories/app_repository.dart';

class AuthGateScreen extends StatefulWidget {
  const AuthGateScreen({super.key});

  @override
  State<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends State<AuthGateScreen> {
  final AppRepository _repository = AppRepository.instance;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final hasSession = await _repository.hasActiveSession();
    if (!mounted) return;

    if (!hasSession) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }
    Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.alphaBlend(
                cs.tertiary.withValues(alpha: isDark ? 0.16 : 0.12),
                theme.scaffoldBackgroundColor,
              ),
              theme.scaffoldBackgroundColor,
              Color.alphaBlend(
                AppTheme.atelierLime.withValues(alpha: isDark ? 0.1 : 0.12),
                theme.scaffoldBackgroundColor,
              ),
            ],
          ),
        ),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.05),
                  blurRadius: 28,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'The Organic Atelier',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: cs.primary,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.8,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  tr(context, 'loading'),
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
