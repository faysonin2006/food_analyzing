import 'package:flutter/material.dart';

import '../core/app_feedback.dart';
import '../core/app_theme.dart';
import '../core/atelier_ui.dart';
import '../core/settings_sheet.dart';
import '../core/tr.dart';
import '../repositories/app_repository.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AppRepository _repository = AppRepository.instance;

  bool _isLoading = false;
  bool _obscurePassword = true;

  bool get _isRu => Localizations.localeOf(context).languageCode == 'ru';
  String get _feedbackSource => _isRu ? 'Вход' : 'Login';

  void _dismissKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  Future<void> _login() async {
    _dismissKeyboard();
    setState(() => _isLoading = true);

    final success = await _repository.login(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      Navigator.pushReplacementNamed(context, '/home');
      return;
    }

    showAppFeedback(
      context,
      tr(context, 'login_error'),
      kind: AppFeedbackKind.error,
      source: _feedbackSource,
      preferPopup: true,
      addToInbox: false,
    );
  }

  void _showUnavailableProviderMessage(String provider) {
    final message = _isRu
        ? '$provider вход пока не подключен'
        : '$provider sign in is not available yet';
    showAppFeedback(
      context,
      message,
      kind: AppFeedbackKind.info,
      source: _feedbackSource,
      preferPopup: true,
      addToInbox: false,
    );
  }

  Widget _settingsButton(BuildContext context) {
    return IconButton.filledTonal(
      onPressed: () => showAppSettingsSheet(context),
      tooltip: tr(context, 'settings'),
      icon: const Icon(Icons.settings_outlined),
    );
  }

  Widget _authLabel(String text) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _socialButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Expanded(
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 52),
          backgroundColor: theme.colorScheme.surfaceContainerHigh.withValues(
            alpha: theme.brightness == Brightness.dark ? 0.55 : 0.7,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          side: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: GestureDetector(
        onTap: _dismissKeyboard,
        behavior: HitTestBehavior.translucent,
        child: Container(
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
          child: Stack(
            children: [
              Positioned(
                top: -80,
                left: -30,
                child: _AmbientOrb(
                  size: 220,
                  color: cs.tertiary.withValues(alpha: isDark ? 0.12 : 0.18),
                ),
              ),
              Positioned(
                right: -40,
                bottom: 90,
                child: _AmbientOrb(
                  size: 240,
                  color: cs.secondary.withValues(alpha: isDark ? 0.08 : 0.14),
                ),
              ),
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(24, 72, 24, 24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Align(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: cs.primary.withValues(
                                      alpha: isDark ? 0.22 : 0.14,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  alignment: Alignment.center,
                                  child: Icon(
                                    Icons.spa_rounded,
                                    color: cs.primary,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'The Organic Atelier',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    color: cs.primary,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 28),
                          Text(
                            _isRu
                                ? 'С возвращением в ваш\nличный кабинет.'
                                : 'Welcome back to your\ncurated kitchen.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              height: 0.95,
                            ),
                          ),
                          const SizedBox(height: 28),
                          AtelierSurfaceCard(
                            radius: 32,
                            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isRu ? 'ВХОД В АККАУНТ' : 'SIGN IN',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: cs.primary,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                // Text(
                                //   _isRu
                                //       ? 'Продолжим с того места,\nгде остановились.'
                                //       : 'Let’s pick up right\nwhere you left off.',
                                //   style: theme.textTheme.headlineSmall
                                //       ?.copyWith(height: 0.98),
                                // ),
                                const SizedBox(height: 22),
                                _authLabel(_isRu ? 'Email' : 'Email address'),
                                TextField(
                                  controller: _emailController,
                                  onTapOutside: (_) => _dismissKeyboard(),
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(
                                    hintText: 'hello@atelier.com',
                                    prefixIcon: Icon(
                                      Icons.mail_outline_rounded,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _authLabel(
                                        _isRu ? 'Пароль' : 'Password',
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: null,
                                      child: Text(
                                        _isRu ? 'Забыли пароль?' : 'Forgot?',
                                      ),
                                    ),
                                  ],
                                ),
                                TextField(
                                  controller: _passwordController,
                                  onTapOutside: (_) => _dismissKeyboard(),
                                  obscureText: _obscurePassword,
                                  textInputAction: TextInputAction.done,
                                  onSubmitted: (_) {
                                    if (!_isLoading) _login();
                                  },
                                  decoration: InputDecoration(
                                    hintText: '••••••••',
                                    suffixIcon: IconButton(
                                      onPressed: () => setState(
                                        () => _obscurePassword =
                                            !_obscurePassword,
                                      ),
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    onPressed: _isLoading ? null : _login,
                                    icon: _isLoading
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: AppTheme.atelierMint,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.arrow_forward_rounded,
                                          ),
                                    label: Text(_isRu ? 'Войти' : 'Sign In'),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Divider(
                                        color: cs.outlineVariant.withValues(
                                          alpha: 0.4,
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                      ),
                                      child: Text(
                                        _isRu
                                            ? 'ИЛИ ПРОДОЛЖИТЬ ЧЕРЕЗ'
                                            : 'OR CONNECT WITH',
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 1.0,
                                            ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Divider(
                                        color: cs.outlineVariant.withValues(
                                          alpha: 0.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                Row(
                                  children: [
                                    _socialButton(
                                      icon: Icons.g_mobiledata_rounded,
                                      label: 'Google',
                                      onTap: () =>
                                          _showUnavailableProviderMessage(
                                            'Google',
                                          ),
                                    ),
                                    const SizedBox(width: 12),
                                    _socialButton(
                                      icon: Icons.apple_rounded,
                                      label: 'Apple',
                                      onTap: () =>
                                          _showUnavailableProviderMessage(
                                            'Apple',
                                          ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 4,
                            children: [
                              Text(
                                _isRu
                                    ? 'Впервые в приложении?'
                                    : 'New to the atelier?',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: cs.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const RegisterScreen(),
                                    ),
                                  );
                                },
                                child: Text(
                                  _isRu ? 'Создать аккаунт' : 'Create Account',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8, left: 10, right: 10),
                    child: Row(
                      children: [
                        if (Navigator.canPop(context))
                          IconButton.filledTonal(
                            onPressed: () => Navigator.of(context).maybePop(),
                            icon: const Icon(Icons.arrow_back_rounded),
                          ),
                        const Spacer(),
                        _settingsButton(context),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AmbientOrb extends StatelessWidget {
  const _AmbientOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      ),
    );
  }
}
