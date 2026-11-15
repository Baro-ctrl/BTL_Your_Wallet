import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/app_router.dart';
import '../services/auth_service.dart';
import '../services/phone_otp_service.dart';
import '../theme/app_colors.dart';

// ==========================================
// PHONE RESET PASSWORD SCREEN
// ==========================================

class PhoneResetPasswordScreen extends StatefulWidget {
  const PhoneResetPasswordScreen({super.key});

  @override
  State<PhoneResetPasswordScreen> createState() =>
      _PhoneResetPasswordScreenState();
}

class _PhoneResetPasswordScreenState extends State<PhoneResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();

  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  final _phoneService = PhoneOtpService();
  final _authService = AuthService();

  bool _loading = false;
  bool _showPassword = false;
  bool _showConfirm = false;

  // ==========================================
  // DISPOSE
  // ==========================================

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  // ==========================================
  // THÔNG BÁO
  // ==========================================

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  // ==========================================
  // ĐỔI MẬT KHẨU
  // ==========================================

  Future<void> _submit() async {
    if (_loading) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_phoneService.canResetPassword) {
      _showMessage(
        'Phiên xác minh OTP không hợp lệ '
        'hoặc đã hết hạn. Vui lòng xác minh lại.',
      );

      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _loading = true;
    });

    try {
      await _phoneService.updatePasswordAfterOtp(_passwordController.text);

      if (!mounted) return;

      // Chỉ mở Success khi Firebase
      // cập nhật mật khẩu thành công.
      context.go(AppRouter.resetPasswordSuccess);
    } on FirebaseAuthException catch (error) {
      _showMessage(_authService.getErrorMessage(error));
    } catch (error) {
      _showMessage('Không thể đổi mật khẩu: $error');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // ==========================================
  // INPUT DECORATION
  // ==========================================

  InputDecoration _decoration(String label, {Widget? suffixIcon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: const Icon(Icons.lock_outline),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
    );
  }

  // ==========================================
  // BUILD
  // ==========================================

  @override
  Widget build(BuildContext context) {
    final verified = _phoneService.canResetPassword;

    return Scaffold(
      backgroundColor: AppColors.bg,

      appBar: AppBar(
        title: const Text('Đặt lại mật khẩu'),
        centerTitle: true,
        backgroundColor: AppColors.bg,
      ),

      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),

            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),

              child: verified ? _buildResetForm() : _buildExpiredSession(),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // PHIÊN XÁC MINH KHÔNG HỢP LỆ
  // ==========================================

  Widget _buildExpiredSession() {
    return Column(
      children: [
        const Icon(Icons.error_outline, size: 80, color: Colors.orange),

        const SizedBox(height: 24),

        const Text(
          'Chưa xác minh OTP',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 12),

        const Text(
          'Phiên xác minh không hợp lệ hoặc '
          'đã hết hạn. Bạn cần xác minh lại '
          'số điện thoại trước khi đổi mật khẩu.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary),
        ),

        const SizedBox(height: 28),

        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: () {
              context.go('${AppRouter.phoneLogin}?mode=reset');
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Xác minh OTP lại'),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // FORM MẬT KHẨU MỚI
  // ==========================================

  Widget _buildResetForm() {
    return Form(
      key: _formKey,

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,

        children: [
          const Icon(
            Icons.verified_user_outlined,
            size: 80,
            color: AppColors.primary,
          ),

          const SizedBox(height: 24),

          const Text(
            'Tạo mật khẩu mới',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),

          const SizedBox(height: 12),

          const Text(
            'Số điện thoại đã được xác minh. '
            'Hãy nhập mật khẩu mới cho tài khoản.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),

          const SizedBox(height: 30),

          // ==================================
          // MẬT KHẨU MỚI
          // ==================================
          TextFormField(
            controller: _passwordController,
            enabled: !_loading,
            obscureText: !_showPassword,
            textInputAction: TextInputAction.next,

            decoration: _decoration(
              'Mật khẩu mới',
              suffixIcon: IconButton(
                tooltip: _showPassword ? 'Ẩn mật khẩu' : 'Hiện mật khẩu',
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
              if (value == null || value.isEmpty) {
                return 'Vui lòng nhập mật khẩu mới.';
              }

              if (value.length < 6) {
                return 'Mật khẩu cần ít nhất 6 ký tự.';
              }

              return null;
            },
          ),

          const SizedBox(height: 16),

          // ==================================
          // NHẬP LẠI MẬT KHẨU
          // ==================================
          TextFormField(
            controller: _confirmController,
            enabled: !_loading,
            obscureText: !_showConfirm,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submit(),

            decoration: _decoration(
              'Nhập lại mật khẩu mới',
              suffixIcon: IconButton(
                tooltip: _showConfirm ? 'Ẩn mật khẩu' : 'Hiện mật khẩu',
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

          const SizedBox(height: 28),

          // ==================================
          // NÚT ĐỔI MẬT KHẨU
          // ==================================
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _loading ? null : _submit,

              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),

              child: _loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Đổi mật khẩu'),
            ),
          ),

          const SizedBox(height: 16),

          // ==================================
          // HỦY KHÔI PHỤC
          // ==================================
          TextButton(
            onPressed: _loading
                ? null
                : () {
                    _phoneService.clearResetSession();

                    context.go(AppRouter.forgotPassword);
                  },
            child: const Text('Hủy khôi phục'),
          ),
        ],
      ),
    );
  }
}
