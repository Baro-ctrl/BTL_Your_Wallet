import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../app/app_router.dart';
import '../theme/app_colors.dart';
import '../widgets/app_button.dart';
import '../widgets/app_text_field.dart';

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đăng ký')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tạo tài khoản mới',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Bắt đầu hành trình quản lý tài chính của bạn',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 28),
              const AppTextField(
                hint: 'Họ và tên',
                prefixIcon: Icon(Icons.person_outline),
              ),
              const SizedBox(height: 16),
              const AppTextField(
                hint: 'Email',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              const SizedBox(height: 16),
              const AppTextField(
                hint: 'Mật khẩu',
                obscureText: true,
                prefixIcon: Icon(Icons.lock_outline),
              ),
              const SizedBox(height: 16),
              const AppTextField(
                hint: 'Nhập lại mật khẩu',
                obscureText: true,
                prefixIcon: Icon(Icons.lock_reset_outlined),
              ),
              const SizedBox(height: 24),
              AppButton(
                text: 'Tạo tài khoản',
                onPressed: () => context.go(AppRouter.home),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Đã có tài khoản? '),
                  GestureDetector(
                    onTap: () => context.go(AppRouter.login),
                    child: const Text(
                      'Đăng nhập',
                      style: TextStyle(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}