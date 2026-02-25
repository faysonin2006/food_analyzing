import 'package:flutter/material.dart';
import '../core/settings_sheet.dart';
import '../core/tr.dart';
import '../services/api_service.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _apiService = ApiService();
  bool _isLoading = false;

  bool get _isRu => Localizations.localeOf(context).languageCode == 'ru';

  void _dismissKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  Future<void> _login() async {
    _dismissKeyboard();
    setState(() => _isLoading = true);

    final success = await _apiService.login(
      _emailController.text,
      _passwordController.text,
    );

    setState(() => _isLoading = false);

    if (success && mounted) {
      Navigator.pushReplacementNamed(context, '/home');
    } else if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr(context, 'login_error'))));
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.alphaBlend(cs.primary.withValues(alpha: 0.14), cs.surface),
              cs.surface,
              Color.alphaBlend(cs.secondary.withValues(alpha: 0.1), cs.surface),
            ],
          ),
        ),
        child: GestureDetector(
          onTap: _dismissKeyboard,
          behavior: HitTestBehavior.translucent,
          child: SafeArea(
            child: Stack(
              children: [
                Center(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(20, 56, 20, 24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 78,
                                height: 78,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [cs.primary, cs.tertiary],
                                  ),
                                ),
                                child: Icon(
                                  Icons.restaurant_rounded,
                                  color: cs.onPrimary,
                                  size: 38,
                                ),
                              ),
                              const SizedBox(height: 18),
                              Text(
                                tr(context, 'login_title'),
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _isRu
                                    ? 'Анализируйте блюда и следите за питанием'
                                    : 'Analyze meals and track your nutrition',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: cs.onSurfaceVariant),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 24),
                              TextField(
                                controller: _emailController,
                                onTapOutside: (_) => _dismissKeyboard(),
                                decoration: InputDecoration(
                                  labelText: tr(context, 'email'),
                                  prefixIcon: const Icon(
                                    Icons.alternate_email_rounded,
                                  ),
                                ),
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _passwordController,
                                onTapOutside: (_) => _dismissKeyboard(),
                                decoration: InputDecoration(
                                  labelText: tr(context, 'password'),
                                  prefixIcon: const Icon(
                                    Icons.lock_outline_rounded,
                                  ),
                                ),
                                obscureText: true,
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) {
                                  if (!_isLoading) {
                                    _login();
                                  }
                                },
                              ),
                              const SizedBox(height: 18),
                              _isLoading
                                  ? const SizedBox(
                                      height: 52,
                                      child: Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    )
                                  : SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: _login,
                                        icon: const Icon(Icons.login_rounded),
                                        label: Text(tr(context, 'sign_in')),
                                      ),
                                    ),
                              const SizedBox(height: 10),
                              TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const RegisterScreen(),
                                    ),
                                  );
                                },
                                child: Text(tr(context, 'no_account')),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: IconButton.filledTonal(
                      onPressed: () => showAppSettingsSheet(context),
                      tooltip: tr(context, 'settings'),
                      icon: const Icon(Icons.settings_rounded),
                    ),
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
