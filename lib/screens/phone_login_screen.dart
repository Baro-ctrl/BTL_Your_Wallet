
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/app_router.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';

class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  State<PhoneLoginScreen> createState() =>
      _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final _authService = AuthService();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  String? _verificationId;
  String? _errorMessage;

  int? _resendToken;

  bool _otpSent = false;
  bool _loading = false;
  bool _finished = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  // CHUYỂN SỐ VIỆT NAM SANG +84

  String _normalizePhone(String input) {
    final phone =
    input.replaceAll(RegExp(r'[\s\-()]'), '');

    if (phone.startsWith('0')) {
      return '+84${phone.substring(1)}';
    }

    if (phone.startsWith('84')) {
      return '+$phone';
    }

    return phone;
  }

  // HIỂN THỊ LỖI

  void _handleError(Object error) {
    if (!mounted || _finished) return;

    setState(() {
      _loading = false;

      if (error is FirebaseAuthException) {
        _errorMessage =
            _authService.getErrorMessage(error);
      } else {
        _errorMessage = error.toString();
      }
    });
  }

  // ĐĂNG NHẬP THÀNH CÔNG

  void _loginSuccess() {
    if (!mounted || _finished) return;

    _finished = true;

    context.go(AppRouter.home);
  }

  // GỬI OTP

  Future<void> _sendOtp({
    bool resend = false,
  }) async {
    if (_loading) return;

    final phone =
    _normalizePhone(_phoneController.text);

    if (!RegExp(r'^\+[1-9]\d{7,14}$')
        .hasMatch(phone)) {
      _handleError(
        'Số điện thoại chưa đúng. '
            'Ví dụ: 0912345678 hoặc +84912345678',
      );
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      await _authService.sendPhoneOtp(
        phoneNumber: phone,
        resendToken: resend ? _resendToken : null,

        onCodeSent: (verificationId, token) {
          if (!mounted || _finished) return;

          setState(() {
            _verificationId = verificationId;
            _resendToken = token;
            _otpSent = true;
            _loading = false;
          });
        },

        onError: (error) {
          _handleError(error);
        },

        onVerified: (credential) {
          _loginSuccess();
        },
      );
    } catch (error) {
      _handleError(error);
    }
  }

  // XÁC NHẬN OTP

  Future<void> _verifyOtp() async {
    if (_loading || _finished) return;

    final verificationId = _verificationId;
    final otp = _otpController.text.trim();

    if (verificationId == null) {
      _handleError('Vui lòng gửi mã OTP trước.');
      return;
    }

    if (!RegExp(r'^\d{6}$').hasMatch(otp)) {
      _handleError('OTP phải gồm 6 chữ số.');
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      await _authService.verifyPhoneOtp(
        verificationId: verificationId,
        smsCode: otp,
      );

      _loginSuccess();
    } catch (error) {
      _handleError(error);
    }
  }

  // ĐỔI SỐ ĐIỆN THOẠI

  void _changePhone() {
    setState(() {
      _otpSent = false;
      _verificationId = null;
      _resendToken = null;
      _errorMessage = null;
      _otpController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(
          _otpSent
              ? 'Xác minh OTP'
              : 'Đăng nhập số điện thoại',
        ),
        centerTitle: true,
      ),

      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints:
              const BoxConstraints(maxWidth: 430),
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.stretch,
                children: [
                  const CircleAvatar(
                    radius: 45,
                    backgroundColor: Color(0xFFE7F2FF),
                    child: Icon(
                      Icons.phone_android,
                      size: 42,
                      color: AppColors.primaryDark,
                    ),
                  ),

                  const SizedBox(height: 24),

                  Text(
                    _otpSent
                        ? 'Nhập mã xác thực'
                        : 'Đăng nhập bằng điện thoại',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),

                  const SizedBox(height: 12),

                  Text(
                    _otpSent
                        ? 'Nhập mã OTP gửi đến '
                        '${_normalizePhone(_phoneController.text)}'
                        : 'Nhập số điện thoại để '
                        'nhận mã xác minh từ Firebase.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),

                  const SizedBox(height: 28),

                  if (!_otpSent)
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Số điện thoại',
                        hintText: '0912345678',
                        prefixIcon:
                        Icon(Icons.phone_outlined),
                      ),
                    ),

                  if (_otpSent)
                    TextField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Mã OTP',
                        hintText: '6 chữ số',
                        prefixIcon:
                        Icon(Icons.lock_outline),
                      ),
                    ),

                  if (_errorMessage != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.red,
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      onPressed: _loading
                          ? null
                          : _otpSent
                          ? _verifyOtp
                          : _sendOtp,
                      child: _loading
                          ? const SizedBox(
                        width: 22,
                        height: 22,
                        child:
                        CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                          : Text(
                        _otpSent
                            ? 'Xác nhận và đăng nhập'
                            : 'Gửi mã OTP',
                      ),
                    ),
                  ),

                  if (_otpSent) ...[
                    const SizedBox(height: 14),

                    TextButton(
                      onPressed: _loading
                          ? null
                          : () => _sendOtp(resend: true),
                      child: const Text('Gửi lại mã OTP'),
                    ),

                    TextButton(
                      onPressed:
                      _loading ? null : _changePhone,
                      child: const Text(
                        'Đổi số điện thoại',
                      ),
                    ),
                  ],

                  const SizedBox(height: 14),

                  TextButton(
                    onPressed: _loading
                        ? null
                        : () => context.go(AppRouter.login),
                    child: const Text(
                      'Quay lại đăng nhập Email',
                    ),
                  ),

                  const SizedBox(height: 16),

                  const Text(
                    'Bằng việc tiếp tục, bạn đồng ý '
                        'để số điện thoại được Firebase xử lý '
                        'phục vụ xác minh đăng nhập.',
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
    );
  }
}
