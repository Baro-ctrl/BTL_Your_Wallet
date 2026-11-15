import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/app_router.dart';
import '../services/auth_service.dart';
import '../services/phone_otp_service.dart';
import '../theme/app_colors.dart';

// ==========================================
// RESET PASSWORD SUCCESS SCREEN
// ==========================================

class ResetPasswordSuccessScreen extends StatefulWidget {
  const ResetPasswordSuccessScreen({super.key});

  @override
  State<ResetPasswordSuccessScreen> createState() =>
      _ResetPasswordSuccessScreenState();
}

class _ResetPasswordSuccessScreenState
    extends State<ResetPasswordSuccessScreen> {
  bool _loading = false;

  // ==========================================
  // VỀ MÀN ĐĂNG NHẬP
  // ==========================================

  Future<void> _backToLogin() async {
    if (_loading) return;

    setState(() {
      _loading = true;
    });

    try {
      // Xóa trạng thái OTP-reset.
      PhoneOtpService().clearResetSession();

      // Đăng xuất khỏi tài khoản hiện tại.
      await AuthService().logout();

      if (!mounted) return;

      // Quay về Login.
      context.go(AppRouter.login);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Không thể đăng xuất: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // ==========================================
  // GIAO DIỆN
  // ==========================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,

      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),

            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),

              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,

                children: [
                  const Icon(
                    Icons.check_circle,
                    size: 100,
                    color: AppColors.primary,
                  ),

                  const SizedBox(height: 24),

                  const Text(
                    'Đổi mật khẩu thành công!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),

                  const SizedBox(height: 14),

                  const Text(
                    'Mật khẩu của bạn đã được '
                    'cập nhật thành công.\n'
                    'Hãy sử dụng mật khẩu mới '
                    'để đăng nhập.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),

                  const SizedBox(height: 32),

                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      onPressed: _loading ? null : _backToLogin,

                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                      ),

                      child: _loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Về đăng nhập'),
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
