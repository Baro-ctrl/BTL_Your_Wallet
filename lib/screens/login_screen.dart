import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/app_router.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final _authService = AuthService();

  bool _loading = false;
  bool _showPassword = false;

  bool get _showApple => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // ==========================================
  // ĐĂNG NHẬP EMAIL
  // ==========================================

  Future<void> _login() async {
    if (_loading || !_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() => _loading = true);

    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final user = credential.user;

      if (user == null) {
        throw StateError('Không tìm thấy tài khoản.');
      }

      await _authService.prepareUserData(user);

      if (!mounted) return;

      context.go(AppRouter.home);
    } on FirebaseAuthException catch (error) {
      _showMessage(_authService.getErrorMessage(error));
    } catch (error) {
      _showMessage('Đăng nhập thất bại: $error');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  // ==========================================
  // ĐĂNG NHẬP GOOGLE / APPLE
  // ==========================================

  Future<void> _socialLogin({required bool apple}) async {
    if (_loading) return;

    setState(() => _loading = true);

    try {
      final result = apple
          ? await _authService.loginWithApple()
          : await _authService.loginWithGoogle();

      if (!mounted) return;

      if (result.user != null) {
        context.go(AppRouter.home);
      }
    } on FirebaseAuthException catch (error) {
      _showMessage(_authService.getErrorMessage(error));
    } catch (error) {
      _showMessage('Đăng nhập thất bại: $error');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  // ==========================================
  // INPUT DECORATION
  // ==========================================

  InputDecoration _decoration(
    BuildContext context,
    String label,
    IconData icon, {
    Widget? suffixIcon,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: scheme.primary),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: scheme.surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    );
  }

  // ==========================================
  // GIAO DIỆN
  // ==========================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Đăng nhập')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Icon(
                        Icons.account_balance_wallet,
                        size: 78,
                        color: scheme.primary,
                      ),
                    ),

                    const SizedBox(height: 20),

                    Text(
                      'Chào mừng quay trở lại!',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Text(
                      'Đăng nhập để tiếp tục quản lý chi tiêu.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),

                    const SizedBox(height: 30),

                    // EMAIL
                    TextFormField(
                      controller: _emailController,
                      enabled: !_loading,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: _decoration(
                        context,
                        'Email',
                        Icons.email_outlined,
                      ),
                      validator: (value) {
                        final email = value?.trim() ?? '';

                        if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                            .hasMatch(email)) {
                          return 'Email không hợp lệ.';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // MẬT KHẨU
                    TextFormField(
                      controller: _passwordController,
                      enabled: !_loading,
                      obscureText: !_showPassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _login(),
                      decoration: _decoration(
                        context,
                        'Mật khẩu',
                        Icons.lock_outline,
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              _showPassword = !_showPassword;
                            });
                          },
                          icon: Icon(
                            _showPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Vui lòng nhập mật khẩu.';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 8),

                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _loading
                            ? null
                            : () => context.push(AppRouter.forgotPassword),
                        child: const Text('Quên mật khẩu?'),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ĐĂNG NHẬP
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed: _loading ? null : _login,
                        child: _loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Đăng nhập'),
                      ),
                    ),

                    const SizedBox(height: 24),

                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'Hoặc',
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // GOOGLE
                    SizedBox(
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: _loading
                            ? null
                            : () => _socialLogin(apple: false),
                        icon: const Icon(Icons.g_mobiledata, size: 28),
                        label: const Text('Tiếp tục với Google'),
                      ),
                    ),

                    // APPLE - IOS
                    if (_showApple) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 52,
                        child: OutlinedButton.icon(
                          onPressed: _loading
                              ? null
                              : () => _socialLogin(apple: true),
                          icon: const Icon(Icons.apple),
                          label: const Text('Tiếp tục với Apple'),
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),

                    // PHONE
                    SizedBox(
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: _loading
                            ? null
                            : () => context.push(AppRouter.phoneLogin),
                        icon: const Icon(Icons.phone_android),
                        label: const Text('Đăng nhập bằng số điện thoại'),
                      ),
                    ),

                    const SizedBox(height: 24),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Chưa có tài khoản?'),
                        TextButton(
                          onPressed: _loading
                              ? null
                              : () => context.go(AppRouter.register),
                          child: const Text('Đăng ký'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
