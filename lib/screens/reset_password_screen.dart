import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/app_router.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String? oobCode;

  const ResetPasswordScreen({super.key, required this.oobCode});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();

  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  final _auth = AuthService();

  bool _checkingCode = true;
  bool _loading = false;

  bool _showPassword = false;
  bool _showConfirm = false;

  String? _email;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkResetCode();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  // ==========================================
  // KIỂM TRA MÃ FIREBASE
  // ==========================================

  Future<void> _checkResetCode() async {
    final code = widget.oobCode;

    if (code == null || code.isEmpty) {
      setState(() {
        _checkingCode = false;
        _errorMessage = 'Không tìm thấy mã khôi phục mật khẩu.';
      });
      return;
    }

    try {
      final email = await _auth.verifyResetCode(code);

      if (!mounted) return;

      setState(() {
        _email = email;
        _checkingCode = false;
        _errorMessage = null;
      });
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      setState(() {
        _checkingCode = false;
        _errorMessage = _auth.getErrorMessage(e);
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _checkingCode = false;
        _errorMessage = e.toString();
      });
    }
  }

  // ==========================================
  // ĐẶT LẠI MẬT KHẨU
  // ==========================================

  Future<void> _resetPassword() async {
    if (_loading || !_formKey.currentState!.validate()) {
      return;
    }

    final code = widget.oobCode;

    if (code == null || code.isEmpty) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() => _loading = true);

    try {
      await _auth.confirmResetPassword(
        oobCode: code,
        newPassword: _passwordController.text,
      );

      if (!mounted) return;

      context.go(AppRouter.resetPasswordSuccess);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_auth.getErrorMessage(e))));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Không thể đổi mật khẩu: $e')));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  InputDecoration _decoration(String label, {Widget? suffixIcon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: const Icon(Icons.lock_outline),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    );
  }

  // ==========================================
  // GIAO DIỆN
  // ==========================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Đặt lại mật khẩu'),
        backgroundColor: AppColors.bg,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: _buildContent(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_checkingCode) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Đang kiểm tra liên kết khôi phục...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Column(
        children: [
          const Icon(Icons.error_outline, size: 75, color: Colors.orange),
          const SizedBox(height: 20),

          const Text(
            'Không thể đặt lại mật khẩu',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 12),

          Text(_errorMessage!, textAlign: TextAlign.center),

          const SizedBox(height: 24),

          FilledButton(
            onPressed: () {
              context.go(AppRouter.forgotPassword);
            },
            child: const Text('Yêu cầu liên kết mới'),
          ),
        ],
      );
    }

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.lock_reset, size: 80, color: AppColors.primary),

          const SizedBox(height: 24),

          const Text(
            'Tạo mật khẩu mới',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),

          const SizedBox(height: 12),

          Text(
            'Tài khoản: ${_email ?? ""}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),

          const SizedBox(height: 30),

          // MẬT KHẨU MỚI
          TextFormField(
            controller: _passwordController,
            obscureText: !_showPassword,
            enabled: !_loading,
            decoration: _decoration(
              'Mật khẩu mới',
              suffixIcon: IconButton(
                onPressed: _loading
                    ? null
                    : () {
                        setState(() {
                          _showPassword = !_showPassword;
                        });
                      },
                icon: Icon(
                  _showPassword ? Icons.visibility_off : Icons.visibility,
                ),
              ),
            ),
            validator: (value) {
              if (value == null || value.length < 6) {
                return 'Mật khẩu phải có ít nhất 6 ký tự.';
              }
              return null;
            },
          ),

          const SizedBox(height: 16),

          // XÁC NHẬN MẬT KHẨU
          TextFormField(
            controller: _confirmController,
            obscureText: !_showConfirm,
            enabled: !_loading,
            decoration: _decoration(
              'Nhập lại mật khẩu mới',
              suffixIcon: IconButton(
                onPressed: _loading
                    ? null
                    : () {
                        setState(() {
                          _showConfirm = !_showConfirm;
                        });
                      },
                icon: Icon(
                  _showConfirm ? Icons.visibility_off : Icons.visibility,
                ),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Vui lòng nhập lại mật khẩu.';
              }

              if (value != _passwordController.text) {
                return 'Hai mật khẩu không khớp.';
              }

              return null;
            },
          ),

          const SizedBox(height: 24),

          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _loading ? null : _resetPassword,
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              child: _loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Đặt lại mật khẩu'),
            ),
          ),

          const SizedBox(height: 16),

          TextButton(
            onPressed: _loading ? null : () => context.go(AppRouter.login),
            child: const Text('Quay lại đăng nhập'),
          ),
        ],
      ),
    );
  }
}
