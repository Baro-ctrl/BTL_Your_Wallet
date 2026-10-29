
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/app_router.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final _auth = AuthService();

  bool _loading = false;
  bool _showPassword = false;

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
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ),
      );
  }

  Future<void> _loginEmail() async {
    if (_loading) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() => _loading = true);

    try {
      final result = await _auth.login(
        email: _emailController.text,
        password: _passwordController.text,
      );

      if (!mounted) return;

      if (result.user == null) {
        _showMessage('Không lấy được tài khoản Firebase.');
        return;
      }

      debugPrint(
        '[LOGIN] Email success: ${result.user!.uid}',
      );

      context.go(AppRouter.home);
    } on FirebaseAuthException catch (e) {
      debugPrint('[LOGIN] Error: ${e.code}');
      _showMessage(_auth.getErrorMessage(e));
    } catch (e) {
      debugPrint('[LOGIN] Unknown error: $e');
      _showMessage('Không thể đăng nhập: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loginApple() async {
    if (_loading) return;

    FocusScope.of(context).unfocus();
    setState(() => _loading = true);

    try {
      final result = await _auth.loginWithApple();

      if (!mounted) return;

      if (result.user != null) {
        context.go(AppRouter.home);
      } else {
        _showMessage('Không lấy được tài khoản Apple.');
      }
    } on FirebaseAuthException catch (e) {
      _showMessage(_auth.getErrorMessage(e));
    } catch (e) {
      _showMessage('Không thể đăng nhập Apple: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgotPassword() async {
    if (_loading) return;

    final email = _emailController.text.trim();

    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
        .hasMatch(email)) {
      _showMessage('Hãy nhập Email hợp lệ trước nhé.');
      return;
    }

    setState(() => _loading = true);

    try {
      await _auth.resetPassword(email);

      _showMessage(
        'Nếu Email đã đăng ký, bạn sẽ nhận được '
            'hướng dẫn đặt lại mật khẩu.',
      );
    } on FirebaseAuthException catch (e) {
      _showMessage(_auth.getErrorMessage(e));
    } catch (e) {
      _showMessage('Không gửi được yêu cầu: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Đăng nhập',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 20,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 430,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Chào mừng trở lại 👋',
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),

                    const SizedBox(height: 8),

                    const Text(
                      'Đăng nhập để tiếp tục quản lý '
                          'chi tiêu của bạn',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),

                    const SizedBox(height: 30),

                    // EMAIL
                    TextFormField(
                      controller: _emailController,
                      enabled: !_loading,
                      keyboardType:
                      TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [
                        AutofillHints.email,
                      ],
                      decoration: _inputDecoration(
                        'Email',
                        Icons.email_outlined,
                      ),
                      validator: (value) {
                        final email = value?.trim() ?? '';

                        if (email.isEmpty) {
                          return 'Vui lòng nhập Email.';
                        }

                        if (!RegExp(
                          r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                        ).hasMatch(email)) {
                          return 'Email không hợp lệ.';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // PASSWORD
                    TextFormField(
                      controller: _passwordController,
                      enabled: !_loading,
                      obscureText: !_showPassword,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [
                        AutofillHints.password,
                      ],
                      onFieldSubmitted: (_) {
                        if (!_loading) _loginEmail();
                      },
                      decoration: _inputDecoration(
                        'Mật khẩu',
                        Icons.lock_outline,
                      ).copyWith(
                        suffixIcon: IconButton(
                          tooltip: _showPassword
                              ? 'Ẩn mật khẩu'
                              : 'Hiện mật khẩu',
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
                        onPressed:
                        _loading ? null : _forgotPassword,
                        child: const Text('Quên mật khẩu?'),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // LOGIN EMAIL
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed:
                        _loading ? null : _loginEmail,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius.circular(14),
                          ),
                        ),
                        child: _loading
                            ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                            : const Text(
                          'Đăng nhập bằng Email',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    const Row(
                      children: [
                        Expanded(child: Divider()),
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 14,
                          ),
                          child: Text('Hoặc'),
                        ),
                        Expanded(child: Divider()),
                      ],
                    ),

                    const SizedBox(height: 22),

                    // APPLE
                    SizedBox(
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed:
                        _loading ? null : _loginApple,
                        icon: const Icon(
                          Icons.apple,
                          size: 25,
                        ),
                        label: const Text(
                          'Tiếp tục với Apple',
                        ),
                        style: _outlineStyle(
                          AppColors.textPrimary,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // PHONE
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
                        style: _outlineStyle(
                          AppColors.primaryDark,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    Row(
                      mainAxisAlignment:
                      MainAxisAlignment.center,
                      children: [
                        const Text('Chưa có tài khoản?'),
                        TextButton(
                          onPressed: _loading
                              ? null
                              : () => context.push(
                            AppRouter.register,
                          ),
                          child: const Text('Đăng ký'),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    const Text(
                      'Your Wallet - Quản lý chi tiêu '
                          'thông minh và an toàn.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
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

  InputDecoration _inputDecoration(
      String label,
      IconData icon,
      ) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: AppColors.border,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: AppColors.primary,
          width: 1.5,
        ),
      ),
    );
  }

  ButtonStyle _outlineStyle(Color color) {
    return OutlinedButton.styleFrom(
      backgroundColor: Colors.white,
      foregroundColor: color,
      side: const BorderSide(
        color: AppColors.border,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }
}
