import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/app_router.dart';
import '../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  final _authService = AuthService();

  bool _loading = false;
  bool _acceptTerms = false;
  bool _showPassword = false;
  bool _showConfirm = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // ==========================================
  // ĐĂNG KÝ
  // ==========================================

  Future<void> _register() async {
    if (_loading || !_formKey.currentState!.validate()) {
      return;
    }

    if (!_acceptTerms) {
      _showMessage('Vui lòng đồng ý với điều khoản sử dụng.');
      return;
    }

    setState(() => _loading = true);

    try {
      await _authService.register(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      context.go(AppRouter.home);
    } on FirebaseAuthException catch (error) {
      _showMessage(_authService.getErrorMessage(error));
    } catch (error) {
      _showMessage('Đăng ký thất bại: $error');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Đăng ký')),
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
                    Text(
                      'Tạo tài khoản mới',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'Bắt đầu quản lý tài chính của bạn.',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),

                    const SizedBox(height: 28),

                    // HỌ TÊN
                    TextFormField(
                      controller: _nameController,
                      enabled: !_loading,
                      decoration: _decoration(
                        context,
                        'Họ và tên',
                        Icons.person_outline,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Vui lòng nhập họ tên.';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // EMAIL
                    TextFormField(
                      controller: _emailController,
                      enabled: !_loading,
                      keyboardType: TextInputType.emailAddress,
                      decoration: _decoration(
                        context,
                        'Email',
                        Icons.email_outlined,
                      ),
                      validator: (value) {
                        if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                            .hasMatch(value?.trim() ?? '')) {
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
                        if (value == null || value.length < 6) {
                          return 'Mật khẩu cần ít nhất 6 ký tự.';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // NHẬP LẠI MẬT KHẨU
                    TextFormField(
                      controller: _confirmController,
                      enabled: !_loading,
                      obscureText: !_showConfirm,
                      decoration: _decoration(
                        context,
                        'Nhập lại mật khẩu',
                        Icons.lock_reset_outlined,
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              _showConfirm = !_showConfirm;
                            });
                          },
                          icon: Icon(
                            _showConfirm
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value != _passwordController.text) {
                          return 'Mật khẩu không khớp.';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // ĐIỀU KHOẢN
                    CheckboxListTile(
                      value: _acceptTerms,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: _loading
                          ? null
                          : (value) {
                              setState(() {
                                _acceptTerms = value ?? false;
                              });
                            },
                      title: const Text(
                        'Tôi đồng ý với Điều khoản sử dụng '
                        'và Chính sách bảo mật.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // TẠO TÀI KHOẢN
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed: _loading ? null : _register,
                        child: _loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Tạo tài khoản'),
                      ),
                    ),

                    const SizedBox(height: 20),

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

                    // ĐĂNG KÝ BẰNG PHONE
                    SizedBox(
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: _loading
                            ? null
                            : () => context.push(AppRouter.phoneLogin),
                        icon: const Icon(Icons.phone_android),
                        label: const Text('Đăng ký bằng số điện thoại'),
                      ),
                    ),

                    const SizedBox(height: 24),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Đã có tài khoản?'),
                        TextButton(
                          onPressed: _loading
                              ? null
                              : () => context.go(AppRouter.login),
                          child: const Text('Đăng nhập'),
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
