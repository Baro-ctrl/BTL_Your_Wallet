import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// Authentication
import '../screens/welcome_screen.dart';
import '../screens/login_screen.dart';
import '../screens/register_screen.dart';
import '../screens/forgot_password_screen.dart';
import '../screens/reset_password_screen.dart';
import '../screens/reset_password_success_screen.dart';

// Phone Authentication
import '../screens/phone_login_screen.dart';
import '../screens/otp_screen.dart';
import '../screens/phone_reset_password_screen.dart';

// Main
import '../screens/home_screen.dart';
import '../screens/add_expense_screen.dart';
import '../screens/notification_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/edit_profile_screen.dart';

// Finance
import '../screens/wallets_screen.dart';
import '../screens/categories_screen.dart';
import '../screens/set_budget_screen.dart';
import '../screens/calendar_screen.dart';
import '../screens/statistic_screen.dart';
import '../screens/transaction_list_screen.dart';
import '../screens/transaction_detail_screen.dart';

// ==========================================
// FIREBASE AUTH NOTIFIER
// ==========================================

class AuthRouterNotifier extends ChangeNotifier {
  late final StreamSubscription<User?> _subscription;

  AuthRouterNotifier() {
    _subscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      debugPrint('[ROUTER] Auth UID: ${user?.uid}');

      notifyListeners();
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

// ==========================================
// APP ROUTER
// ==========================================

class AppRouter {
  AppRouter._();

  // Authentication
  static const String welcome = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';

  static const String resetPassword = '/reset-password';

  static const String resetPasswordSuccess = '/reset-password-success';

  // Phone Authentication
  static const String phoneLogin = '/phone-login';
  static const String otp = '/otp';

  static const String phoneResetPassword = '/phone-reset-password';

  // Main
  static const String home = '/home';
  static const String addExpense = '/add-expense';
  static const String notifications = '/notifications';
  static const String profile = '/profile';
  static const String editProfile = '/edit-profile';

  // Finance
  static const String wallets = '/wallets';
  static const String categories = '/categories';
  static const String setBudget = '/set-budget';
  static const String calendar = '/calendar';
  static const String statistic = '/statistic';
  static const String transactions = '/transactions';

  static const String transactionDetail = '/transaction-detail/:id';

  static String transactionDetailPath(String id) {
    return '/transaction-detail/${Uri.encodeComponent(id)}';
  }

  static final AuthRouterNotifier _authNotifier = AuthRouterNotifier();

  static final GoRouter router = GoRouter(
    initialLocation: welcome,
    refreshListenable: _authNotifier,

    // ======================================
    // REDIRECT
    // ======================================
    redirect: (context, state) {
      final loggedIn = FirebaseAuth.instance.currentUser != null;

      final path = state.matchedLocation;

      const guestRoutes = <String>{welcome, login, register};

      const publicRoutes = <String>{
        welcome,
        login,
        register,
        phoneLogin,
        forgotPassword,
        resetPassword,
        resetPasswordSuccess,
        otp,
      };

      debugPrint('[ROUTER] $path | loggedIn=$loggedIn');

      // OTP cần có thông tin số điện thoại.
      if (path == otp && state.extra is! OtpArguments) {
        return phoneLogin;
      }

      // Không cho liên kết Phone khi chưa Login.
      if (path == phoneLogin &&
          state.uri.queryParameters['mode'] == 'link' &&
          !loggedIn) {
        return login;
      }

      // Phone Reset yêu cầu phiên đăng nhập.
      if (path == phoneResetPassword && !loggedIn) {
        return '$phoneLogin?mode=reset';
      }

      // Chặn truy cập các màn riêng tư.
      if (!loggedIn && !publicRoutes.contains(path)) {
        return welcome;
      }

      // Đã đăng nhập không cần ở Welcome/Login.
      if (loggedIn && guestRoutes.contains(path)) {
        return home;
      }

      return null;
    },

    // ======================================
    // ROUTES
    // ======================================
    routes: [
      // Welcome
      GoRoute(
        path: welcome,
        builder: (context, state) => const WelcomeScreen(),
      ),

      // Login
      GoRoute(path: login, builder: (context, state) => const LoginScreen()),

      // Register
      GoRoute(
        path: register,
        builder: (context, state) => const RegisterScreen(),
      ),

      // Forgot Password
      GoRoute(
        path: forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),

      // Reset Password by Email
      GoRoute(
        path: resetPassword,
        builder: (context, state) {
          final code = state.uri.queryParameters['oobCode'];

          return ResetPasswordScreen(oobCode: code);
        },
      ),

      // Password Success
      GoRoute(
        path: resetPasswordSuccess,
        builder: (context, state) => const ResetPasswordSuccessScreen(),
      ),

      // Phone Login
      GoRoute(
        path: phoneLogin,
        builder: (context, state) {
          final mode = state.uri.queryParameters['mode'] ?? 'login';

          return PhoneLoginScreen(mode: mode);
        },
      ),

      // OTP
      GoRoute(
        path: otp,
        builder: (context, state) {
          final extra = state.extra;

          if (extra is OtpArguments) {
            return OtpScreen(arguments: extra);
          }

          return const PhoneLoginScreen();
        },
      ),

      // Phone Reset Password
      GoRoute(
        path: phoneResetPassword,
        builder: (context, state) => const PhoneResetPasswordScreen(),
      ),

      // Home
      GoRoute(path: home, builder: (context, state) => const HomeScreen()),

      // Add Expense
      GoRoute(
        path: addExpense,
        builder: (context, state) => const AddExpenseScreen(),
      ),

      // Notifications
      GoRoute(
        path: notifications,
        builder: (context, state) => const NotificationScreen(),
      ),

      // Profile
      GoRoute(
        path: profile,
        builder: (context, state) => const ProfileScreen(),
      ),

      // Edit Profile
      GoRoute(
        path: editProfile,
        builder: (context, state) => const EditProfileScreen(),
      ),

      // Wallets
      GoRoute(
        path: wallets,
        builder: (context, state) => const WalletsScreen(),
      ),

      // Categories
      GoRoute(
        path: categories,
        builder: (context, state) => const CategoriesScreen(),
      ),

      // Budget
      GoRoute(
        path: setBudget,
        builder: (context, state) => const SetBudgetScreen(),
      ),

      // Calendar
      GoRoute(
        path: calendar,
        builder: (context, state) => const CalendarScreen(),
      ),

      // Statistics
      GoRoute(
        path: statistic,
        builder: (context, state) => const StatisticScreen(),
      ),

      // Transactions
      GoRoute(
        path: transactions,
        builder: (context, state) => const TransactionListScreen(),
      ),

      // Transaction Detail
      GoRoute(
        path: transactionDetail,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';

          return TransactionDetailScreen(transactionId: id);
        },
      ),
    ],

    // ======================================
    // ERROR PAGE
    // ======================================
    errorBuilder: (context, state) {
      return Scaffold(
        appBar: AppBar(title: const Text('Không tìm thấy trang')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 56, color: Colors.orange),
                const SizedBox(height: 16),
                const Text(
                  'Không thể mở trang này',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text('Đường dẫn: ${state.uri}', textAlign: TextAlign.center),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () {
                    final loggedIn = FirebaseAuth.instance.currentUser != null;

                    context.go(loggedIn ? home : welcome);
                  },
                  child: const Text('Quay lại'),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
