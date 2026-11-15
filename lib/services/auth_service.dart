import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

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

  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  Future<void>? _googleInitialization;

  // ==========================================
  // THÔNG TIN TÀI KHOẢN
  // ==========================================

  User? get currentUser => _auth.currentUser;

  String? get currentUserId => _auth.currentUser?.uid;

  String? get currentUserEmail => _auth.currentUser?.email;

  bool get isLoggedIn => _auth.currentUser != null;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ==========================================
  // ĐĂNG NHẬP EMAIL
  // ==========================================

  Future<UserCredential> login({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim();

    if (cleanEmail.isEmpty || password.isEmpty) {
      throw ArgumentError('Vui lòng nhập đầy đủ Email và mật khẩu.');
    }

    final result = await _auth.signInWithEmailAndPassword(
      email: cleanEmail,
      password: password,
    );

    final user = result.user;

    if (user == null) {
      throw StateError('Firebase không trả về tài khoản.');
    }

    await _prepareUserSafely(user);

    debugPrint('[AUTH] Email Login: ${user.uid}');

    return result;
  }

  // ==========================================
  // ĐĂNG KÝ EMAIL
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

    final result = await _auth.createUserWithEmailAndPassword(
      email: cleanEmail,
      password: password,
    );

    final user = result.user;

    if (user == null) {
      throw StateError('Không tạo được tài khoản Firebase.');
    }

    await user.updateDisplayName(cleanName);

    await _prepareUserSafely(user);

    debugPrint('[AUTH] Đăng ký thành công: ${user.uid}');
  }

  // ==========================================
  // GOOGLE SIGN-IN
  // google_sign_in 7.x
  // ==========================================

  Future<void> _initializeGoogle() {
    return _googleInitialization ??= _googleSignIn.initialize();
  }

  Future<UserCredential> loginWithGoogle() async {
    if (kIsWeb) {
      final provider = GoogleAuthProvider();

      final result = await _auth.signInWithPopup(provider);

      final user = result.user;

      if (user == null) {
        throw StateError('Google không trả về tài khoản.');
      }

      await _prepareUserSafely(user);
      return result;
    }

    await _initializeGoogle();

    final googleUser = await _googleSignIn.authenticate();

    final googleAuth = googleUser.authentication;

    final idToken = googleAuth.idToken;

    if (idToken == null) {
      throw StateError(
        'Không nhận được Google ID Token. '
        'Kiểm tra Firebase và cấu hình Google Sign-In.',
      );
    }

    final credential = GoogleAuthProvider.credential(idToken: idToken);

    final result = await _auth.signInWithCredential(credential);

    final user = result.user;

    if (user == null) {
      throw StateError('Google không trả về tài khoản.');
    }

    await _prepareUserSafely(user);

    debugPrint('[AUTH] Google Login: ${user.uid}');

    return result;
  }

  // ==========================================
  // APPLE SIGN-IN
  // ==========================================

  Future<UserCredential> loginWithApple() async {
    final provider = AppleAuthProvider()
      ..addScope('email')
      ..addScope('name');

    final UserCredential result;

    if (kIsWeb) {
      result = await _auth.signInWithPopup(provider);
    } else {
      result = await _auth.signInWithProvider(provider);
    }

    final user = result.user;

    if (user == null) {
      throw StateError('Apple không trả về tài khoản.');
    }

    await _prepareUserSafely(user);

    debugPrint('[AUTH] Apple Login: ${user.uid}');

    return result;
  }

  // ==========================================
  // TẠO HỒ SƠ VÀ DỮ LIỆU MẶC ĐỊNH
  // ==========================================

  Future<void> prepareUserData(User user) async {
    final userRef = _db.collection('users').doc(user.uid);

    final snapshot = await userRef.get();

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

      debugPrint('[FIRESTORE] Đã tạo hồ sơ.');
    }

    await _defaultDataService.createDefaultData(user.uid);

    debugPrint('[FIRESTORE] Khởi tạo dữ liệu hoàn tất.');
  }

  Future<void> _prepareUserSafely(User user) async {
    try {
      await prepareUserData(user);
    } on FirebaseException catch (error, stackTrace) {
      debugPrint('[FIRESTORE] ${error.code}: ${error.message}');
      debugPrintStack(stackTrace: stackTrace);
    } catch (error, stackTrace) {
      debugPrint('[FIRESTORE] $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> retryDefaultData() async {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('Bạn chưa đăng nhập.');
    }

    await prepareUserData(user);
  }

  // ==========================================
  // PHONE AUTHENTICATION
  // ==========================================

  Future<UserCredential> _authenticatePhoneCredential(
    PhoneAuthCredential credential, {
    required bool linkToCurrentUser,
  }) async {
    if (linkToCurrentUser) {
      final user = _auth.currentUser;

      if (user == null) {
        throw StateError('Cần đăng nhập trước khi liên kết số điện thoại.');
      }

      return user.linkWithCredential(credential);
    }

    return _auth.signInWithCredential(credential);
  }

  Future<void> sendPhoneOtp({
    required String phoneNumber,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(FirebaseAuthException) onError,
    required void Function(UserCredential) onVerified,
    int? resendToken,
    bool linkToCurrentUser = false,
  }) async {
    final phone = phoneNumber.trim();

    if (!RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(phone)) {
      throw ArgumentError('Số điện thoại phải có dạng +84912345678.');
    }

    if (kIsWeb) {
      throw UnsupportedError('Luồng OTP hiện tại chỉ hỗ trợ Android/iOS.');
    }

    await _auth.verifyPhoneNumber(
      phoneNumber: phone,
      timeout: const Duration(seconds: 60),
      forceResendingToken: resendToken,

      verificationCompleted: (credential) async {
        try {
          final result = await _authenticatePhoneCredential(
            credential,
            linkToCurrentUser: linkToCurrentUser,
          );

          final user = result.user;

          if (user != null) {
            await _prepareUserSafely(user);
          }

          onVerified(result);
        } on FirebaseAuthException catch (e) {
          onError(e);
        } catch (e) {
          onError(
            FirebaseAuthException(
              code: 'phone-login-failed',
              message: e.toString(),
            ),
          );
        }
      },

      verificationFailed: (error) {
        debugPrint('[AUTH] Phone OTP error: ${error.code}');
        onError(error);
      },

      codeSent: (verificationId, token) {
        debugPrint('[AUTH] OTP đã được xử lý gửi.');

        onCodeSent(verificationId, token);
      },

      codeAutoRetrievalTimeout: (verificationId) {
        debugPrint('[AUTH] Hết thời gian tự động nhận OTP.');
      },
    );
  }

  Future<UserCredential> verifyPhoneOtp({
    required String verificationId,
    required String smsCode,
    bool linkToCurrentUser = false,
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

    final result = await _authenticatePhoneCredential(
      credential,
      linkToCurrentUser: linkToCurrentUser,
    );

    final user = result.user;

    if (user != null) {
      await _prepareUserSafely(user);
    }

    return result;
  }

  // ==========================================
  // QUÊN MẬT KHẨU
  // ==========================================

  Future<void> resetPassword(String email) async {
    final cleanEmail = email.trim();

    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(cleanEmail)) {
      throw ArgumentError('Email không hợp lệ.');
    }

    await _auth.sendPasswordResetEmail(email: cleanEmail);
  }

  // ==========================================
  // KIỂM TRA MÃ KHÔI PHỤC
  // ==========================================

  Future<String> verifyResetCode(String code) async {
    if (code.trim().isEmpty) {
      throw ArgumentError('Thiếu mã khôi phục mật khẩu.');
    }

    return _auth.verifyPasswordResetCode(code.trim());
  }

  // ==========================================
  // XÁC NHẬN MẬT KHẨU MỚI
  // ==========================================

  Future<void> confirmResetPassword({
    required String oobCode,
    required String newPassword,
  }) async {
    if (oobCode.trim().isEmpty) {
      throw ArgumentError('Thiếu mã khôi phục mật khẩu.');
    }

    if (newPassword.length < 6) {
      throw ArgumentError('Mật khẩu phải có ít nhất 6 ký tự.');
    }

    await _auth.confirmPasswordReset(
      code: oobCode.trim(),
      newPassword: newPassword,
    );
  }

  // ==========================================
  // XÁC MINH EMAIL
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
  // ĐĂNG XUẤT
  // ==========================================

  Future<void> logout() async {
    await _auth.signOut();

    if (!kIsWeb && _googleInitialization != null) {
      try {
        await _googleInitialization;
        await _googleSignIn.signOut();
      } catch (error) {
        debugPrint('[AUTH] Google signOut: $error');
      }
    }

    debugPrint('[AUTH] Đăng xuất thành công.');
  }

  // ==========================================
  // THÔNG BÁO LỖI TIẾNG VIỆT
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
        return 'Bạn đã thử quá nhiều lần. '
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
        return 'Tài khoản sử dụng phương thức '
            'đăng nhập khác.';

      case 'credential-already-in-use':
        return 'Thông tin đăng nhập đã được '
            'liên kết với tài khoản khác.';

      case 'invalid-action-code':
        return 'Liên kết khôi phục không hợp lệ '
            'hoặc đã được sử dụng.';

      case 'expired-action-code':
        return 'Liên kết khôi phục đã hết hạn.';

      case 'requires-recent-login':
        return 'Vui lòng đăng nhập lại để '
            'thực hiện thao tác này.';

      case 'invalid-apple-credential':
        return 'Không thể xác minh Apple ID.';

      case 'cancelled-popup-request':
      case 'popup-closed-by-user':
        return 'Bạn đã hủy đăng nhập.';

      default:
        return error.message ?? 'Lỗi Firebase: ${error.code}';
    }
  }
}
