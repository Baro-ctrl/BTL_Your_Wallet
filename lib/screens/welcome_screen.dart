
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/app_router.dart';
import '../theme/app_colors.dart';
import '../widgets/app_button.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 20,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 420,
              ),
              child: Column(
                children: [
                  const Spacer(),

                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(
                        alpha: 0.15,
                      ),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      size: 58,
                      color: AppColors.primaryDark,
                    ),
                  ),

                  const SizedBox(height: 24),

                  const Text(
                    'Your Wallet',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),

                  const SizedBox(height: 12),

                  const Text(
                    'Quản lý chi tiêu thông minh\n'
                        'và kiểm soát tài chính cá nhân',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 36),

                  AppButton(
                    text: 'Đăng nhập',
                    onPressed: () {
                      context.go(AppRouter.login);
                    },
                  ),

                  const SizedBox(height: 14),

                  AppButton(
                    text: 'Tạo tài khoản mới',
                    color: Colors.white,
                    textColor: AppColors.primaryDark,
                    onPressed: () {
                      context.go(AppRouter.register);
                    },
                  ),

                  const Spacer(),

                  const Text(
                    'Quản lý tài chính dễ dàng mỗi ngày',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
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
