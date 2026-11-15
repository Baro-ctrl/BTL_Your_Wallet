import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'auth_service.dart';

// ==========================================
// MỤC ĐÍCH SỬ DỤNG OTP
// ==========================================

enum PhoneOtpPurpose { signIn, link, resetPassword }

// ==========================================
// PHONE OTP SERVICE
// ==========================================

class PhoneOtpService {
  // ========================================
  // SINGLETON
  // ========================================

  PhoneOtpService._() {
    // Theo dõi trạng thái đăng nhập Firebase.
    // Xóa phiên OTP-reset khi đăng xuất
    // hoặc chuyển sang tài khoản khác.
    //
    // Service là Singleton, tồn tại trong
    // suốt vòng đời của ứng dụng.

    _auth.authStateChanges().listen((user) {
      if (user == null ||
          (_verifiedResetUid != null && user.uid != _verifiedResetUid)) {
        clearResetSession();
      }
    });
  }

  static final PhoneOtpService instance = PhoneOtpService._();

  factory PhoneOtpService() => instance;

  // ========================================
  // FIREBASE INSTANCES
  // ========================================

  final FirebaseAuth _auth = FirebaseAuth.instance;

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ========================================
  // TRẠNG THÁI OTP-RESET
  // ========================================

  String? _verifiedResetUid;
  DateTime? _resetVerifiedAt;

  // ========================================
  // 1. CHUẨN HÓA SỐ ĐIỆN THOẠI
  // ========================================

  static String normalizePhone(String input) {
    final phone = input.replaceAll(RegExp(r'[\s\-()]'), '');

    // Chuyển 0912345678 thành +84912345678.
    if (phone.startsWith('0')) {
      return '+84${phone.substring(1)}';
    }

    return phone;
  }

  // ========================================
  // 2. KIỂM TRA SỐ ĐIỆN THOẠI
  // ========================================

  static bool isValidPhone(String phone) {
    return RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(phone);
  }

  // ========================================
  // 3. GỬI MÃ OTP
  // ========================================

  Future<void> sendOtp({
    required String phone,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(FirebaseAuthException error) onError,
    required void Function(PhoneAuthCredential credential) onAutoVerified,
    int? resendToken,
  }) async {
    if (kIsWeb) {
      throw UnsupportedError('Chức năng OTP này dành cho Android/iOS.');
    }

    if (!isValidPhone(phone)) {
      throw ArgumentError('Số điện thoại không hợp lệ.');
    }

    debugPrint('[OTP] Bắt đầu yêu cầu xác minh.');

    await _auth.verifyPhoneNumber(
      phoneNumber: phone,
      timeout: const Duration(seconds: 60),
      forceResendingToken: resendToken,

      // ------------------------------------
      // TỰ ĐỘNG XÁC MINH TRÊN ANDROID
      // ------------------------------------
      verificationCompleted: (credential) {
        debugPrint('[OTP] Firebase tự động xác minh.');

        onAutoVerified(credential);
      },

      // ------------------------------------
      // LỖI GỬI OTP
      // ------------------------------------
      verificationFailed: (error) {
        debugPrint('[OTP ERROR] Code: ${error.code}');

        debugPrint('[OTP ERROR] Message: ${error.message}');

        onError(error);
      },

      // ------------------------------------
      // FIREBASE ĐÃ CẤP VERIFICATION ID
      // ------------------------------------
      codeSent: (verificationId, token) {
        debugPrint('[OTP] Đã nhận verificationId.');

        onCodeSent(verificationId, token);
      },

      // ------------------------------------
      // HẾT THỜI GIAN TỰ ĐỘNG XÁC MINH
      // ------------------------------------
      codeAutoRetrievalTimeout: (_) {
        debugPrint('[OTP] Hết thời gian tự động xác minh.');
      },
    );
  }

  // ========================================
  // 4. TẠO PHONE CREDENTIAL
  // ========================================

  PhoneAuthCredential createCredential({
    required String verificationId,
    required String smsCode,
  }) {
    if (verificationId.isEmpty) {
      throw ArgumentError('Chưa có mã xác minh từ Firebase.');
    }

    final code = smsCode.trim();

    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      throw ArgumentError('OTP phải gồm đúng 6 chữ số.');
    }

    return PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: code,
    );
  }

  // ========================================
  // 5. HOÀN THÀNH XÁC MINH OTP
  // ========================================

  Future<void> complete({
    required PhoneAuthCredential credential,
    required PhoneOtpPurpose purpose,
  }) async {
    switch (purpose) {
      // ====================================
      // TRƯỜNG HỢP 1:
      // ĐĂNG NHẬP BẰNG SỐ ĐIỆN THOẠI
      // ====================================

      case PhoneOtpPurpose.signIn:
        clearResetSession();

        final result = await _auth.signInWithCredential(credential);

        final user = result.user;

        if (user == null) {
          throw StateError('Đăng nhập bằng số điện thoại thất bại.');
        }

        // Chuẩn bị hồ sơ và dữ liệu mặc định.
        await AuthService().prepareUserData(user);

        debugPrint('[OTP] Đăng nhập thành công.');

        return;

      // ====================================
      // TRƯỜNG HỢP 2:
      // LIÊN KẾT PHONE VỚI EMAIL
      // ====================================

      case PhoneOtpPurpose.link:
        clearResetSession();

        final user = _auth.currentUser;

        if (user == null) {
          throw StateError(
            'Bạn cần đăng nhập trước khi '
            'liên kết số điện thoại.',
          );
        }

        // Chưa có số điện thoại:
        // liên kết Phone vào UID hiện tại.
        if (user.phoneNumber == null) {
          await user.linkWithCredential(credential);
        } else {
          // Đã có số điện thoại:
          // cập nhật sang số mới.
          await user.updatePhoneNumber(credential);
        }

        await user.reload();

        final updatedUser = _auth.currentUser;

        if (updatedUser == null) {
          throw StateError('Không tải được thông tin tài khoản.');
        }

        // Đồng bộ số điện thoại vào Firestore.
        await _db.collection('users').doc(updatedUser.uid).set({
          'id': updatedUser.uid,
          'phone': updatedUser.phoneNumber ?? '',
        }, SetOptions(merge: true));

        debugPrint('[OTP] Liên kết số điện thoại thành công.');

        return;

      // ====================================
      // TRƯỜNG HỢP 3:
      // OTP KHÔI PHỤC MẬT KHẨU
      // ====================================

      case PhoneOtpPurpose.resetPassword:
        clearResetSession();

        // Đăng nhập lại bằng Phone Credential
        // để Firebase xác thực số điện thoại.
        final result = await _auth.signInWithCredential(credential);

        final user = result.user;

        if (user == null) {
          throw StateError('Xác minh OTP thất bại.');
        }

        // Nếu số chưa có tài khoản, Firebase
        // có thể tự tạo một Phone User mới.
        // Không cho phép tài khoản mới dùng
        // luồng khôi phục mật khẩu.
        if (result.additionalUserInfo?.isNewUser == true) {
          try {
            await user.delete();
          } catch (error) {
            debugPrint(
              '[OTP] Không thể xóa tài khoản '
              'Phone vừa được tạo: $error',
            );
          } finally {
            await _auth.signOut();
          }

          throw StateError(
            'Số điện thoại chưa liên kết với '
            'tài khoản cần khôi phục.',
          );
        }

        await user.reload();

        final currentUser = _auth.currentUser;

        if (currentUser == null) {
          throw StateError('Không tìm thấy tài khoản.');
        }

        // Kiểm tra tài khoản có liên kết
        // Email/Password hay không.
        final hasPasswordProvider = currentUser.providerData.any(
          (provider) => provider.providerId == 'password',
        );

        if (currentUser.phoneNumber == null || !hasPasswordProvider) {
          await _auth.signOut();

          throw StateError(
            'Tài khoản chưa liên kết '
            'Email/Mật khẩu và số điện thoại. '
            'Vui lòng sử dụng khôi phục qua Email.',
          );
        }

        // Lưu trạng thái vừa xác minh OTP.
        _verifiedResetUid = currentUser.uid;
        _resetVerifiedAt = DateTime.now();

        debugPrint('[OTP] Xác minh khôi phục thành công.');

        return;
    }
  }

  // ========================================
  // 6. KIỂM TRA PHIÊN OTP-RESET
  // ========================================

  bool get canResetPassword {
    final user = _auth.currentUser;

    // Chưa xác minh hoặc đã đăng xuất.
    if (user == null || _verifiedResetUid == null || _resetVerifiedAt == null) {
      return false;
    }

    // Không được đổi mật khẩu cho UID khác.
    if (user.uid != _verifiedResetUid) {
      clearResetSession();
      return false;
    }

    final elapsed = DateTime.now().difference(_resetVerifiedAt!);

    // Phiên OTP-reset chỉ hợp lệ trong 5 phút.
    if (elapsed.isNegative || elapsed >= const Duration(minutes: 5)) {
      clearResetSession();
      return false;
    }

    return true;
  }

  // ========================================
  // 7. XÓA PHIÊN OTP-RESET
  // ========================================

  void clearResetSession() {
    _verifiedResetUid = null;
    _resetVerifiedAt = null;
  }

  // ========================================
  // 8. ĐỔI MẬT KHẨU SAU OTP
  // ========================================

  Future<void> updatePasswordAfterOtp(String newPassword) async {
    // ------------------------------------
    // BƯỚC 1: KIỂM TRA PHIÊN XÁC MINH
    // ------------------------------------

    if (!canResetPassword) {
      throw StateError(
        'Phiên xác minh OTP không hợp lệ '
        'hoặc đã hết hạn. Vui lòng xác minh lại.',
      );
    }

    // ------------------------------------
    // BƯỚC 2: KIỂM TRA MẬT KHẨU MỚI
    // ------------------------------------

    if (newPassword.length < 6) {
      throw ArgumentError('Mật khẩu phải có ít nhất 6 ký tự.');
    }

    // ------------------------------------
    // BƯỚC 3: LẤY USER
    // ------------------------------------

    final user = _auth.currentUser;

    if (user == null) {
      clearResetSession();

      throw StateError('Phiên đăng nhập không còn hợp lệ.');
    }

    // ------------------------------------
    // BƯỚC 4: KIỂM TRA PROVIDER
    // ------------------------------------

    final hasPasswordProvider = user.providerData.any(
      (provider) => provider.providerId == 'password',
    );

    if (user.phoneNumber == null || !hasPasswordProvider) {
      clearResetSession();

      throw StateError(
        'Tài khoản không hỗ trợ khôi phục '
        'mật khẩu bằng số điện thoại.',
      );
    }

    // ------------------------------------
    // BƯỚC 5: FIREBASE UPDATE PASSWORD
    // ------------------------------------

    // Firebase sẽ kiểm tra phiên xác thực
    // đủ mới (recent login).
    await user.updatePassword(newPassword);

    // ------------------------------------
    // BƯỚC 6: HOÀN TẤT
    // ------------------------------------

    clearResetSession();

    debugPrint('[OTP] Cập nhật mật khẩu thành công.');

    // Không đăng xuất ngay tại đây.
    // Màn ResetPasswordSuccessScreen
    // sẽ thực hiện đăng xuất khi người dùng
    // nhấn nút "Về đăng nhập".
  }
}
