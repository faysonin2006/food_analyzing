import 'package:flutter/material.dart';

import '../core/app_feedback.dart';
import '../core/app_theme.dart';
import '../core/atelier_ui.dart';
import '../core/settings_sheet.dart';
import '../core/tr.dart';
import '../repositories/app_repository.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AppRepository _repository = AppRepository.instance;

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _acceptedTerms = false;

  bool get _isRu => Localizations.localeOf(context).languageCode == 'ru';
  String get _feedbackSource => _isRu ? 'Регистрация' : 'Register';

  void _dismissKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  Future<void> _register() async {
    if (!_acceptedTerms) {
      final text = _isRu
          ? 'Подтверди условия перед регистрацией'
          : 'Accept the terms before continuing';
      showAppFeedback(
        context,
        text,
        kind: AppFeedbackKind.error,
        source: _feedbackSource,
        preferPopup: true,
        addToInbox: false,
      );
      return;
    }

    _dismissKeyboard();
    setState(() => _isLoading = true);

    final success = await _repository.register(
      _emailController.text.trim(),
      _passwordController.text,
      'USER',
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      showAppFeedback(
        context,
        tr(context, 'register_success'),
        kind: AppFeedbackKind.success,
        source: _feedbackSource,
      );
      Navigator.pop(context);
      return;
    }

    showAppFeedback(
      context,
      tr(context, 'register_error'),
      kind: AppFeedbackKind.error,
      source: _feedbackSource,
      preferPopup: true,
      addToInbox: false,
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

  void _showUnavailableProviderMessage(String provider) {
    final message = _isRu
        ? '$provider регистрация пока не подключена'
        : '$provider sign up is not available yet';
    showAppFeedback(
      context,
      message,
      kind: AppFeedbackKind.info,
      source: _feedbackSource,
      preferPopup: true,
      addToInbox: false,
    );
  }

  void _goBack() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pushReplacementNamed('/login');
  }

  Widget _settingsButton(BuildContext context) {
    return IconButton.filledTonal(
      onPressed: () => showAppSettingsSheet(context),
      tooltip: tr(context, 'settings'),
      icon: const Icon(Icons.settings_outlined),
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
                  cs.primary.withValues(alpha: isDark ? 0.1 : 0.08),
                  theme.scaffoldBackgroundColor,
                ),
                theme.scaffoldBackgroundColor,
                Color.alphaBlend(
                  AppTheme.atelierHoney.withValues(alpha: isDark ? 0.08 : 0.1),
                  theme.scaffoldBackgroundColor,
                ),
              ],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -70,
                right: -30,
                child: _AmbientOrb(
                  size: 220,
                  color: cs.primary.withValues(alpha: isDark ? 0.12 : 0.16),
                ),
              ),
              Positioned(
                left: -50,
                bottom: 70,
                child: _AmbientOrb(
                  size: 240,
                  color: cs.tertiary.withValues(alpha: isDark ? 0.08 : 0.12),
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
                                ? 'Создай аккаунт и\nсобери свой ритм питания.'
                                : 'Create your account and\nshape your food flow.',
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
                                  _isRu
                                      ? 'СОЗДАНИЕ АККАУНТА'
                                      : 'CREATE ACCOUNT',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: cs.primary,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  _isRu
                                      ? 'Новый доступ к вашему\nпрофилю atelier.'
                                      : 'A new key to your\natelier profile.',
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(height: 0.98),
                                ),
                                const SizedBox(height: 22),
                                AtelierFieldLabel(
                                  _isRu ? 'Email' : 'Email address',
                                ),
                                TextField(
                                  controller: _emailController,
                                  onTapOutside: (_) => _dismissKeyboard(),
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(
                                    hintText: 'julianne@atelier.com',
                                    prefixIcon: Icon(
                                      Icons.mail_outline_rounded,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                AtelierFieldLabel(
                                  _isRu ? 'Пароль' : 'Password',
                                ),
                                TextField(
                                  controller: _passwordController,
                                  onTapOutside: (_) => _dismissKeyboard(),
                                  obscureText: _obscurePassword,
                                  textInputAction: TextInputAction.done,
                                  onSubmitted: (_) {
                                    if (!_isLoading) _register();
                                  },
                                  decoration: InputDecoration(
                                    hintText: '••••••••',
                                    prefixIcon: const Icon(
                                      Icons.lock_outline_rounded,
                                    ),
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
                                const SizedBox(height: 18),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: cs.surfaceContainerHighest
                                        .withValues(alpha: isDark ? 0.45 : 0.6),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: _acceptedTerms
                                          ? cs.primary.withValues(alpha: 0.35)
                                          : cs.outlineVariant.withValues(
                                              alpha: 0.45,
                                            ),
                                    ),
                                  ),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: () => setState(
                                      () => _acceptedTerms = !_acceptedTerms,
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Checkbox(
                                          value: _acceptedTerms,
                                          onChanged: (value) => setState(
                                            () =>
                                                _acceptedTerms = value ?? false,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          side: BorderSide(
                                            color: cs.outlineVariant.withValues(
                                              alpha: 0.8,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.only(
                                              top: 10,
                                            ),
                                            child: Text(
                                              _isRu
                                                  ? 'Я принимаю условия сервиса и политику конфиденциальности.'
                                                  : 'I agree to the terms of service and privacy policy.',
                                              style: theme.textTheme.bodyMedium
                                                  ?.copyWith(
                                                    color: cs.onSurfaceVariant,
                                                  ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    onPressed: _isLoading ? null : _register,
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
                                    label: Text(
                                      _isRu
                                          ? 'Создать аккаунт'
                                          : 'Create Account',
                                    ),
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
                                            ? 'ИЛИ ЗАРЕГИСТРИРОВАТЬСЯ ЧЕРЕЗ'
                                            : 'OR REGISTER WITH',
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
                          const SizedBox(height: 28),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _isRu
                                    ? 'Уже есть аккаунт?'
                                    : 'Already a member?',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: cs.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text(_isRu ? 'Войти' : 'Log in'),
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
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, left: 10, right: 10),
                  child: Row(
                    children: [
                      IconButton.filledTonal(
                        onPressed: _goBack,
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      const Spacer(),
                      _settingsButton(context),
                    ],
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
