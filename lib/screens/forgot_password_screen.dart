import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/app_router.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';

// ==========================================
// FORGOT PASSWORD SCREEN
// ==========================================

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();

  final _authService = AuthService();

  bool _loading = false;
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
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
  // GỬI EMAIL KHÔI PHỤC
  // ==========================================

  Future<void> _sendResetEmail() async {
    if (_loading) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _loading = true;
    });

    try {
      await _authService.resetPassword(_emailController.text.trim());

      if (!mounted) return;

      setState(() {
        _emailSent = true;
      });
    } on FirebaseAuthException catch (error) {
      _showMessage(_authService.getErrorMessage(error));
    } catch (error) {
      _showMessage('Không thể gửi yêu cầu: $error');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // ==========================================
  // KHÔI PHỤC QUA PHONE OTP
  // ==========================================

  void _resetByPhone() {
    context.push('${AppRouter.phoneLogin}?mode=reset');
  }

  // ==========================================
  // GIAO DIỆN CHÍNH
  // ==========================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,

      appBar: AppBar(
        title: const Text('Quên mật khẩu'),
        centerTitle: true,
        backgroundColor: AppColors.bg,
      ),

      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),

            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),

              child: _emailSent ? _buildSuccess() : _buildForm(),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // FORM QUÊN MẬT KHẨU
  // ==========================================

  Widget _buildForm() {
    return Form(
      key: _formKey,

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,

        children: [
          const Icon(Icons.lock_reset, size: 80, color: AppColors.primary),

          const SizedBox(height: 24),

          const Text(
            'Khôi phục mật khẩu',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),

          const SizedBox(height: 12),

          const Text(
            'Nhập Email đã đăng ký để nhận '
            'liên kết đặt lại mật khẩu.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),

          const SizedBox(height: 30),

          // ==================================
          // NHẬP EMAIL
          // ==================================
          TextFormField(
            controller: _emailController,
            enabled: !_loading,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _sendResetEmail(),

            decoration: InputDecoration(
              labelText: 'Email',
              hintText: 'example@gmail.com',
              prefixIcon: const Icon(Icons.email_outlined),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),

            validator: (value) {
              final email = value?.trim() ?? '';

              if (email.isEmpty) {
                return 'Vui lòng nhập Email.';
              }

              if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                return 'Email không hợp lệ.';
              }

              return null;
            },
          ),

          const SizedBox(height: 24),

          // ==================================
          // NÚT GỬI EMAIL
          // ==================================
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _loading ? null : _sendResetEmail,

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
                  : const Text('Gửi Email khôi phục'),
            ),
          ),

          const SizedBox(height: 24),

          const Row(
            children: [
              Expanded(child: Divider()),

              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('Hoặc'),
              ),

              Expanded(child: Divider()),
            ],
          ),

          const SizedBox(height: 20),

          // ==================================
          // KHÔI PHỤC BẰNG PHONE OTP
          // ==================================
          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: _loading ? null : _resetByPhone,
              icon: const Icon(Icons.phone_android),
              label: const Text('Khôi phục bằng số điện thoại'),
            ),
          ),

          const SizedBox(height: 20),

          // ==================================
          // QUAY VỀ LOGIN
          // ==================================
          TextButton(
            onPressed: _loading
                ? null
                : () {
                    context.go(AppRouter.login);
                  },
            child: const Text('Quay lại đăng nhập'),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // GIAO DIỆN THÔNG BÁO ĐÃ GỬI EMAIL
  // ==========================================

  Widget _buildSuccess() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,

      children: [
        const Icon(
          Icons.mark_email_read_outlined,
          size: 85,
          color: AppColors.primary,
        ),

        const SizedBox(height: 24),

        const Text(
          'Kiểm tra Email của bạn',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 16),

        Text(
          'Nếu ${_emailController.text.trim()} '
          'đã được đăng ký, bạn sẽ nhận được '
          'liên kết khôi phục mật khẩu.',
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 12),

        const Text(
          'Hãy kiểm tra cả thư mục Spam '
          'nếu chưa thấy Email.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),

        const SizedBox(height: 30),

        SizedBox(
          height: 52,
          child: FilledButton(
            onPressed: () {
              context.go(AppRouter.login);
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Về đăng nhập'),
          ),
        ),

        const SizedBox(height: 12),

        TextButton(
          onPressed: () {
            setState(() {
              _emailSent = false;
            });
          },
          child: const Text('Gửi lại Email'),
        ),
      ],
    );
  }
}
