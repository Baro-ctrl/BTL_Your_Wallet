import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/app_router.dart';
import '../services/phone_otp_service.dart';
import '../theme/app_colors.dart';
import 'otp_screen.dart';

class PhoneLoginScreen extends StatefulWidget {
  final String mode;

  const PhoneLoginScreen({super.key, this.mode = 'login'});

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  PhoneOtpPurpose get _purpose {
    switch (widget.mode) {
      case 'link':
        return PhoneOtpPurpose.link;

      case 'reset':
        return PhoneOtpPurpose.resetPassword;

      default:
        return PhoneOtpPurpose.signIn;
    }
  }

  String get _title {
    switch (widget.mode) {
      case 'link':
        return 'Liên kết số điện thoại';

      case 'reset':
        return 'Khôi phục bằng OTP';

      default:
        return 'Đăng nhập bằng số điện thoại';
    }
  }

  void _continue() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final phone = PhoneOtpService.normalizePhone(_phoneController.text);

    context.push(
      AppRouter.otp,
      extra: OtpArguments(phoneNumber: phone, purpose: _purpose),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(_title),
        centerTitle: true,
        backgroundColor: AppColors.bg,
      ),
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
                    const Icon(
                      Icons.phone_android,
                      size: 80,
                      color: AppColors.primary,
                    ),

                    const SizedBox(height: 24),

                    Text(
                      _title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),

                    const SizedBox(height: 12),

                    const Text(
                      'Nhập số điện thoại của bạn '
                      'để nhận mã xác thực OTP.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),

                    const SizedBox(height: 30),

                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _continue(),
                      decoration: InputDecoration(
                        labelText: 'Số điện thoại',
                        hintText: '0912345678',
                        prefixIcon: const Icon(Icons.phone_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      validator: (value) {
                        final phone = PhoneOtpService.normalizePhone(
                          value ?? '',
                        );

                        if (!PhoneOtpService.isValidPhone(phone)) {
                          return 'Số điện thoại không hợp lệ.';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 12),

                    const Text(
                      'Ví dụ: 0912345678 sẽ được '
                      'chuyển thành +84912345678.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),

                    const SizedBox(height: 24),

                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed: _continue,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                        ),
                        child: const Text('Tiếp tục'),
                      ),
                    ),

                    const SizedBox(height: 16),

                    TextButton(
                      onPressed: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go(AppRouter.login);
                        }
                      },
                      child: const Text('Quay lại'),
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
