import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';

import '../app/app_router.dart';
import '../services/auth_service.dart';
import '../services/phone_otp_service.dart';

// ==========================================
// OTP ARGUMENTS
// ==========================================

class OtpArguments {
  final String phoneNumber;
  final PhoneOtpPurpose purpose;

  const OtpArguments({required this.phoneNumber, required this.purpose});
}

// ==========================================
// OTP SCREEN
// ==========================================

class OtpScreen extends StatefulWidget {
  final OtpArguments arguments;

  const OtpScreen({super.key, required this.arguments});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _controller = TextEditingController();

  final _phoneService = PhoneOtpService();
  final _authService = AuthService();

  Timer? _timer;

  String? _verificationId;
  int? _resendToken;

  int _seconds = 0;

  bool _sending = false;
  bool _verifying = false;
  bool _completed = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _sendOtp();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
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
  // LOG FIREBASE
  // ==========================================

  void _logFirebaseError(FirebaseAuthException error) {
    debugPrint('========== OTP ERROR ==========');
    debugPrint('CODE: ${error.code}');
    debugPrint('MESSAGE: ${error.message}');
    debugPrint('PLUGIN: ${error.plugin}');
    debugPrint('================================');
  }

  void _checkFirebaseProject() {
    final options = Firebase.app().options;

    debugPrint('======= FIREBASE CONFIG =======');
    debugPrint('PROJECT ID: ${options.projectId}');
    debugPrint('APP ID: ${options.appId}');
    debugPrint('================================');
  }

  // ==========================================
  // ĐẾM NGƯỢC
  // ==========================================

  void _startCountdown() {
    _timer?.cancel();

    setState(() {
      _seconds = 60;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_seconds <= 1) {
        timer.cancel();

        setState(() {
          _seconds = 0;
        });
      } else {
        setState(() {
          _seconds--;
        });
      }
    });
  }

  // ==========================================
  // GỬI OTP
  // ==========================================

  Future<void> _sendOtp() async {
    if (_sending || _verifying || _completed) {
      return;
    }

    _timer?.cancel();
    _controller.clear();

    setState(() {
      _sending = true;
      _verificationId = null;
      _seconds = 0;
    });

    _checkFirebaseProject();

    debugPrint('========== SEND OTP ==========');
    debugPrint('PURPOSE: ${widget.arguments.purpose.name}');

    try {
      await _phoneService.sendOtp(
        phone: widget.arguments.phoneNumber,
        resendToken: _resendToken,

        onCodeSent: (verificationId, token) {
          if (!mounted || _completed) return;

          setState(() {
            _verificationId = verificationId;
            _resendToken = token;
            _sending = false;
          });

          _startCountdown();

          debugPrint('[OTP] Mã đã được gửi.');
        },

        onError: (error) {
          if (!mounted || _completed) return;

          _logFirebaseError(error);

          setState(() {
            _sending = false;
            _seconds = 0;
          });

          _showMessage(_authService.getErrorMessage(error));
        },

        onAutoVerified: (credential) {
          debugPrint('[OTP] Android tự động xác minh.');

          _finishVerification(credential);
        },
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted || _completed) return;

      _logFirebaseError(error);

      setState(() {
        _sending = false;
        _seconds = 0;
      });

      _showMessage(_authService.getErrorMessage(error));
    } catch (error) {
      if (!mounted || _completed) return;

      setState(() {
        _sending = false;
        _seconds = 0;
      });

      _showMessage(error.toString());
    }
  }

  // ==========================================
  // XÁC MINH OTP
  // ==========================================

  Future<void> _verifyOtp() async {
    if (_sending || _verifying || _completed) {
      return;
    }

    final verificationId = _verificationId;

    if (verificationId == null) {
      _showMessage('OTP chưa được gửi thành công.');
      return;
    }

    final code = _controller.text.trim();

    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      _showMessage('Vui lòng nhập đủ 6 chữ số.');
      return;
    }

    final credential = _phoneService.createCredential(
      verificationId: verificationId,
      smsCode: code,
    );

    await _finishVerification(credential);
  }

  // ==========================================
  // HOÀN THÀNH XÁC MINH
  // ==========================================

  Future<void> _finishVerification(PhoneAuthCredential credential) async {
    if (_verifying || _completed || !mounted) {
      return;
    }

    setState(() => _verifying = true);

    try {
      await _phoneService.complete(
        credential: credential,
        purpose: widget.arguments.purpose,
      );

      if (!mounted) return;

      _completed = true;
      _timer?.cancel();

      debugPrint('[OTP] VERIFY SUCCESS');

      switch (widget.arguments.purpose) {
        case PhoneOtpPurpose.signIn:
          context.go(AppRouter.home);
          break;

        case PhoneOtpPurpose.link:
          context.go(AppRouter.profile);
          break;

        case PhoneOtpPurpose.resetPassword:
          context.go(AppRouter.phoneResetPassword);
          break;
      }
    } on FirebaseAuthException catch (error) {
      _logFirebaseError(error);

      _showMessage(_authService.getErrorMessage(error));
    } catch (error) {
      _showMessage('Xác minh thất bại: $error');
    } finally {
      if (mounted && !_completed) {
        setState(() => _verifying = false);
      }
    }
  }

  // ==========================================
  // GIAO DIỆN DARK MODE
  // ==========================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // LẤY MÀU TỰ ĐỘNG TỪ THEME
    final pinTheme = PinTheme(
      width: 46,
      height: 56,
      textStyle: TextStyle(
        fontSize: 21,
        fontWeight: FontWeight.bold,
        color: scheme.onSurface,
      ),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border.all(color: scheme.outline),
        borderRadius: BorderRadius.circular(10),
      ),
    );

    final focusedPinTheme = pinTheme.copyWith(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border.all(color: scheme.primary, width: 2),
        borderRadius: BorderRadius.circular(10),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Xác thực OTP'), centerTitle: true),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                children: [
                  Icon(
                    Icons.verified_user_outlined,
                    size: 78,
                    color: scheme.primary,
                  ),

                  const SizedBox(height: 24),

                  Text(
                    'Nhập mã xác thực',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 12),

                  Text(
                    'Mã OTP gồm 6 chữ số được gửi đến:',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    widget.arguments.phoneNumber,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: scheme.primary,
                    ),
                  ),

                  const SizedBox(height: 30),

                  // OTP 6 Ô
                  Pinput(
                    controller: _controller,
                    length: 6,
                    defaultPinTheme: pinTheme,
                    focusedPinTheme: focusedPinTheme,
                    keyboardType: TextInputType.number,
                    enabled: !_verifying && !_completed,
                    onCompleted: (_) => _verifyOtp(),
                  ),

                  const SizedBox(height: 28),

                  // ĐẾM NGƯỢC
                  if (_sending)
                    const CircularProgressIndicator()
                  else if (_seconds > 0)
                    Text(
                      'Gửi lại mã sau $_seconds giây',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    )
                  else
                    TextButton(
                      onPressed: _verifying ? null : _sendOtp,
                      child: const Text('Gửi lại OTP'),
                    ),

                  const SizedBox(height: 24),

                  // XÁC NHẬN
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed:
                          _verifying || _sending || _verificationId == null
                          ? null
                          : _verifyOtp,
                      child: _verifying
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Xác nhận'),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ĐỔI SỐ ĐIỆN THOẠI
                  TextButton(
                    onPressed: _verifying
                        ? null
                        : () {
                            if (context.canPop()) {
                              context.pop();
                            } else {
                              context.go(AppRouter.phoneLogin);
                            }
                          },
                    child: const Text('Đổi số điện thoại'),
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
