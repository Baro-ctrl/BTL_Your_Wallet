
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends ChangeNotifier {
  ThemeController._();

  static final ThemeController instance =
  ThemeController._();

  SharedPreferences? _prefs;
  StreamSubscription<User?>? _authSubscription;

  String? _currentUid;

  bool _isDark = false;
  bool _initialized = false;

  bool get isDark => _isDark;

  ThemeMode get themeMode =>
      _isDark ? ThemeMode.dark : ThemeMode.light;

  // ==========================================
  // KHỞI TẠO THEME
  // ==========================================

  Future<void> initialize() async {
    if (_initialized) return;

    _prefs = await SharedPreferences.getInstance();

    _currentUid =
        FirebaseAuth.instance.currentUser?.uid;

    _isDark = _prefs!.getBool(
      _key(_currentUid),
    ) ??
        false;

    _initialized = true;

    // Khi chuyển tài khoản, tải giao diện
    // đã được lưu cho tài khoản đó.
    _authSubscription = FirebaseAuth.instance
        .authStateChanges()
        .listen((user) {
      final uid = user?.uid;

      if (uid == _currentUid) return;

      _currentUid = uid;

      _isDark = _prefs?.getBool(
        _key(uid),
      ) ??
          false;

      notifyListeners();
    });
  }

  // ==========================================
  // TẠO KEY LƯU THEO USER
  // ==========================================

  String _key(String? uid) {
    return '${uid ?? 'guest'}_dark_mode';
  }

  // ==========================================
  // BẬT / TẮT DARK MODE
  // ==========================================

  Future<void> setDarkMode(bool value) async {
    if (!_initialized) {
      await initialize();
    }

    if (_isDark == value) return;

    final oldValue = _isDark;
    final savingUid = _currentUid;

    // Cập nhật ngay giao diện.
    _isDark = value;
    notifyListeners();

    try {
      final saved = await _prefs!.setBool(
        _key(savingUid),
        value,
      );

      if (!saved) {
        throw StateError(
          'Không lưu được lựa chọn giao diện.',
        );
      }
    } catch (_) {
      // Khôi phục trạng thái nếu lưu thất bại.
      if (_currentUid == savingUid) {
        _isDark = oldValue;
        notifyListeners();
      }

      rethrow;
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
