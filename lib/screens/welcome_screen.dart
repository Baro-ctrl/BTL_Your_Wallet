
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/app_router.dart';
import '../services/auth_service.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() =>
      _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _auth = AuthService();

  bool _loading = false;

  bool get _showApple {
    return !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // ==========================================
  // GOOGLE / APPLE LOGIN
  // ==========================================

  Future<void> _socialLogin({
    required bool apple,
  }) async {
    if (_loading) return;

    setState(() {
      _loading = true;
    });

    try {
      final result = apple
          ? await _auth.loginWithApple()
          : await _auth.loginWithGoogle();

      if (!mounted) return;

      if (result.user != null) {
        context.go(AppRouter.home);
      }
    } on FirebaseAuthException catch (error) {
      _showError(
        _auth.getErrorMessage(error),
      );
    } catch (error) {
      _showError(
        'Không thể đăng nhập: $error',
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // ==========================================
  // BUILD
  // ==========================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 30,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 430,
              ),
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.stretch,
                children: [
                  // ==========================
                  // LOGO
                  // ==========================

                  Center(
                    child: Container(
                      width: 108,
                      height: 108,
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius:
                        BorderRadius.circular(28),
                      ),
                      child: Icon(
                        Icons.account_balance_wallet_rounded,
                        size: 62,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  Text(
                    'Your Wallet',
                    textAlign: TextAlign.center,
                    style:
                    theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: scheme.primary,
                    ),
                  ),

                  const SizedBox(height: 12),

                  Text(
                    'Quản lý chi tiêu thông minh',
                    textAlign: TextAlign.center,
                    style:
                    theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'Theo dõi thu chi, quản lý ví '
                        'và xây dựng thói quen tài chính '
                        'tốt hơn mỗi ngày.',
                    textAlign: TextAlign.center,
                    style:
                    theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),

                  const SizedBox(height: 42),

                  // ==========================
                  // LOGIN
                  // ==========================

                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      onPressed: _loading
                          ? null
                          : () => context.go(AppRouter.login),
                      child: const Text('Đăng nhập'),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ==========================
                  // REGISTER
                  // ==========================

                  SizedBox(
                    height: 52,
                    child: OutlinedButton(
                      onPressed: _loading
                          ? null
                          : () => context.go(AppRouter.register),
                      child: const Text('Đăng ký'),
                    ),
                  ),

                  const SizedBox(height: 28),

                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                        ),
                        child: Text(
                          'Hoặc tiếp tục với',
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ==========================
                  // GOOGLE
                  // ==========================

                  SizedBox(
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: _loading
                          ? null
                          : () => _socialLogin(apple: false),
                      icon: const Icon(
                        Icons.g_mobiledata,
                        size: 30,
                      ),
                      label: const Text(
                        'Tiếp tục với Google',
                      ),
                    ),
                  ),

                  // ==========================
                  // APPLE - IOS ONLY
                  // ==========================

                  if (_showApple) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: _loading
                            ? null
                            : () => _socialLogin(
                          apple: true,
                        ),
                        icon: const Icon(Icons.apple),
                        label: const Text(
                          'Tiếp tục với Apple',
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),

                  // ==========================
                  // PHONE
                  // ==========================

                  SizedBox(
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: _loading
                          ? null
                          : () => context.push(
                        AppRouter.phoneLogin,
                      ),
                      icon: const Icon(
                        Icons.phone_android,
                      ),
                      label: const Text(
                        'Tiếp tục với số điện thoại',
                      ),
                    ),
                  ),

                  if (_loading) ...[
                    const SizedBox(height: 20),
                    const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ],

                  const SizedBox(height: 35),

                  Text(
                    'Your Wallet • Quản lý tài chính cá nhân',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
