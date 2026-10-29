import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/user_model.dart';
import '../repositories/user_repository.dart';
import 'default_data_service.dart';

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  factory AuthService() => instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final UserRepository _userRepository = UserRepository();

  final DefaultDataService _defaultDataService = DefaultDataService();

  // ==========================================
  // 1. THÔNG TIN TÀI KHOẢN
  // ==========================================

  User? get currentUser => _auth.currentUser;

  String? get currentUserId => _auth.currentUser?.uid;

  String? get currentUserEmail => _auth.currentUser?.email;

  bool get isLoggedIn => _auth.currentUser != null;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ==========================================
  // 2. ĐĂNG NHẬP EMAIL / MẬT KHẨU
  // ==========================================

  Future<UserCredential> login({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim();

    if (cleanEmail.isEmpty || password.isEmpty) {
      throw ArgumentError('Vui lòng nhập đầy đủ Email và mật khẩu.');
    }

    try {
      debugPrint('[AUTH] Bắt đầu đăng nhập Email');

      // Xác thực tài khoản trên Firebase
      final credential = await _auth.signInWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );

      final user = credential.user;

      if (user == null) {
        throw StateError('Firebase không trả về tài khoản.');
      }

      debugPrint('[AUTH] Đăng nhập thành công: ${user.uid}');

      // Tạo dữ liệu mặc định nếu chưa có
      await _prepareUserSafely(user);

      return credential;
    } on FirebaseAuthException catch (error) {
      debugPrint('[AUTH] Firebase error: ${error.code}');
      debugPrint('[AUTH] ${error.message}');

      rethrow;
    } catch (error) {
      debugPrint('[AUTH] Login error: $error');

      rethrow;
    }
  }

  // ==========================================
  // 3. ĐĂNG KÝ EMAIL / MẬT KHẨU
  // ==========================================

  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final cleanName = name.trim();
    final cleanEmail = email.trim();

    if (cleanName.isEmpty) {
      throw ArgumentError('Vui lòng nhập họ tên.');
    }

    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(cleanEmail)) {
      throw ArgumentError('Email không hợp lệ.');
    }

    if (password.length < 6) {
      throw ArgumentError('Mật khẩu phải có ít nhất 6 ký tự.');
    }

    debugPrint('[AUTH] Bắt đầu đăng ký');

    final credential = await _auth.createUserWithEmailAndPassword(
      email: cleanEmail,
      password: password,
    );

    final user = credential.user;

    if (user == null) {
      throw StateError('Không tạo được tài khoản Firebase.');
    }

    await user.updateDisplayName(cleanName);

    debugPrint('[AUTH] Đăng ký thành công: ${user.uid}');

    await _prepareUserSafely(user);
  }

  // ==========================================
  // 4. KHỞI TẠO HỒ SƠ VÀ DỮ LIỆU MẶC ĐỊNH
  // ==========================================

  Future<void> prepareUserData(User user) async {
    final userRef = _db.collection('users').doc(user.uid);

    final snapshot = await userRef.get();

    // Chỉ tạo hồ sơ nếu chưa tồn tại
    if (!snapshot.exists) {
      final userModel = UserModel(
        id: user.uid,
        name: user.displayName?.isNotEmpty == true
            ? user.displayName!
            : 'Người dùng Your Wallet',
        email: user.email ?? '',
        phone: user.phoneNumber ?? '',
        avatarUrl: user.photoURL ?? '',
        createdAt: DateTime.now(),
      );

      await _userRepository.addUser(userModel);

      debugPrint('[FIRESTORE] Đã tạo hồ sơ người dùng.');
    } else {
      debugPrint('[FIRESTORE] Hồ sơ đã tồn tại.');
    }

    // Tạo ví và danh mục mặc định
    await _defaultDataService.createDefaultData(user.uid);

    debugPrint('[FIRESTORE] Kiểm tra/khởi tạo dữ liệu hoàn tất.');
  }

  // Xử lý lỗi Firestore riêng
  // Không làm mất phiên đăng nhập Firebase.
  Future<void> _prepareUserSafely(User user) async {
    try {
      await prepareUserData(user);

      debugPrint('[FIRESTORE] INITIALIZATION SUCCESS');
    } on FirebaseException catch (error, stackTrace) {
      debugPrint('[FIRESTORE] ERROR CODE: ${error.code}');
      debugPrint('[FIRESTORE] MESSAGE: ${error.message}');

      debugPrintStack(stackTrace: stackTrace);
    } catch (error, stackTrace) {
      debugPrint('[FIRESTORE] INITIALIZATION FAILED: $error');

      debugPrintStack(stackTrace: stackTrace);
    }
  }

  // ==========================================
  // 5. ĐĂNG NHẬP BẰNG APPLE ID
  // ==========================================

  Future<UserCredential> loginWithApple() async {
    try {
      debugPrint('[AUTH] Bắt đầu Apple Login');

      final provider = AppleAuthProvider()
        ..addScope('email')
        ..addScope('name');

      final UserCredential credential;

      if (kIsWeb) {
        credential = await _auth.signInWithPopup(provider);
      } else {
        credential = await _auth.signInWithProvider(provider);
      }

      final user = credential.user;

      if (user == null) {
        throw StateError('Apple không trả về tài khoản.');
      }

      debugPrint('[AUTH] Apple Login thành công: ${user.uid}');

      await _prepareUserSafely(user);

      return credential;
    } on FirebaseAuthException catch (error) {
      debugPrint('[AUTH] Apple error: ${error.code}');

      rethrow;
    }
  }

  // ==========================================
  // 6. GỬI OTP ĐẾN SỐ ĐIỆN THOẠI
  // ==========================================

  Future<void> sendPhoneOtp({
    required String phoneNumber,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(FirebaseAuthException) onError,
    required void Function(UserCredential) onVerified,
    int? resendToken,
  }) async {
    final phone = phoneNumber.trim();

    if (!RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(phone)) {
      throw ArgumentError('Số điện thoại phải có dạng +84912345678.');
    }

    if (kIsWeb) {
      throw UnsupportedError('Luồng OTP này chỉ hỗ trợ Android/iOS.');
    }

    debugPrint('[AUTH] Bắt đầu xác minh số điện thoại.');

    await _auth.verifyPhoneNumber(
      phoneNumber: phone,
      timeout: const Duration(seconds: 60),
      forceResendingToken: resendToken,

      // Android có thể tự động xác minh OTP
      verificationCompleted: (credential) async {
        try {
          final result = await _auth.signInWithCredential(credential);

          final user = result.user;

          if (user != null) {
            await _prepareUserSafely(user);
          }

          onVerified(result);
        } on FirebaseAuthException catch (error) {
          onError(error);
        } catch (error) {
          onError(
            FirebaseAuthException(
              code: 'phone-login-failed',
              message: error.toString(),
            ),
          );
        }
      },

      verificationFailed: (error) {
        debugPrint('[AUTH] Phone error: ${error.code}');

        onError(error);
      },

      codeSent: (verificationId, token) {
        debugPrint('[AUTH] OTP đã được Firebase xử lý gửi.');

        onCodeSent(verificationId, token);
      },

      codeAutoRetrievalTimeout: (verificationId) {
        debugPrint('[AUTH] Hết thời gian tự nhận OTP.');
      },
    );
  }

  // ==========================================
  // 7. XÁC NHẬN OTP
  // ==========================================

  Future<UserCredential> verifyPhoneOtp({
    required String verificationId,
    required String smsCode,
  }) async {
    if (verificationId.isEmpty) {
      throw ArgumentError('Chưa yêu cầu gửi mã OTP.');
    }

    if (!RegExp(r'^\d{6}$').hasMatch(smsCode.trim())) {
      throw ArgumentError('Mã OTP phải gồm 6 chữ số.');
    }

    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode.trim(),
    );

    final result = await _auth.signInWithCredential(credential);

    final user = result.user;

    if (user != null) {
      debugPrint('[AUTH] Phone Login thành công: ${user.uid}');

      await _prepareUserSafely(user);
    }

    return result;
  }

  // ==========================================
  // 8. KHÔI PHỤC DỮ LIỆU MẶC ĐỊNH
  // ==========================================

  Future<void> retryDefaultData() async {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('Bạn chưa đăng nhập.');
    }

    // Hàm này báo lỗi thật nếu Firestore thất bại,
    // giúp kiểm tra hoặc hiển thị nút thử lại.
    await prepareUserData(user);
  }

  // ==========================================
  // 9. QUÊN MẬT KHẨU
  // ==========================================

  Future<void> resetPassword(String email) async {
    final cleanEmail = email.trim();

    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(cleanEmail)) {
      throw ArgumentError('Email không hợp lệ.');
    }

    await _auth.sendPasswordResetEmail(email: cleanEmail);
  }

  // ==========================================
  // 10. XÁC MINH EMAIL
  // ==========================================

  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('Bạn chưa đăng nhập.');
    }

    if (!user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  Future<bool> checkEmailVerified() async {
    final user = _auth.currentUser;

    if (user == null) {
      return false;
    }

    await user.reload();

    return _auth.currentUser?.emailVerified ?? false;
  }

  // ==========================================
  // 11. ĐĂNG XUẤT
  // ==========================================

  Future<void> logout() async {
    await _auth.signOut();

    debugPrint('[AUTH] Đã đăng xuất thành công.');
  }

  // ==========================================
  // 12. THÔNG BÁO LỖI TIẾNG VIỆT
  // ==========================================

  String getErrorMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'Email không hợp lệ.';

      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
      case 'invalid-login-credentials':
        return 'Email hoặc mật khẩu không chính xác.';

      case 'email-already-in-use':
        return 'Email này đã được đăng ký.';

      case 'weak-password':
        return 'Mật khẩu quá yếu.';

      case 'user-disabled':
        return 'Tài khoản đã bị vô hiệu hóa.';

      case 'too-many-requests':
        return 'Bạn thử quá nhiều lần. '
            'Vui lòng thử lại sau.';

      case 'network-request-failed':
        return 'Không có kết nối Internet.';

      case 'operation-not-allowed':
        return 'Phương thức đăng nhập chưa được bật '
            'trong Firebase Console.';

      case 'invalid-phone-number':
        return 'Số điện thoại không hợp lệ.';

      case 'invalid-verification-code':
        return 'Mã OTP không chính xác.';

      case 'session-expired':
        return 'Mã OTP đã hết hạn.';

      case 'quota-exceeded':
        return 'Đã vượt giới hạn gửi mã OTP.';

      case 'account-exists-with-different-credential':
        return 'Tài khoản này đang sử dụng '
            'phương thức đăng nhập khác.';

      case 'credential-already-in-use':
        return 'Thông tin đăng nhập đã được '
            'liên kết với tài khoản khác.';

      case 'invalid-apple-credential':
        return 'Không thể xác minh Apple ID.';

      case 'cancelled-popup-request':
      case 'popup-closed-by-user':
        return 'Bạn đã hủy quá trình đăng nhập.';

      default:
        return error.message ?? 'Lỗi Firebase: ${error.code}';
    }
  }
}
