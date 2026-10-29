
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/welcome_screen.dart';
import '../screens/login_screen.dart';
import '../screens/register_screen.dart';
import '../screens/phone_login_screen.dart';

import '../screens/home_screen.dart';
import '../screens/add_expense_screen.dart';
import '../screens/notification_screen.dart';
import '../screens/profile_screen.dart';

import '../screens/wallets_screen.dart';
import '../screens/categories_screen.dart';
import '../screens/set_budget_screen.dart';
import '../screens/calendar_screen.dart';
import '../screens/statistic_screen.dart';
import '../screens/transaction_list_screen.dart';
import '../screens/transaction_detail_screen.dart';
import '../screens/edit_profile_screen.dart';

// =============================================
// THÔNG BÁO ROUTER KHI FIREBASE AUTH THAY ĐỔI
// =============================================

class AuthRouterNotifier extends ChangeNotifier {
  late final StreamSubscription<User?> _subscription;

  AuthRouterNotifier() {
    _subscription = FirebaseAuth.instance
        .authStateChanges()
        .listen((user) {
      debugPrint(
        '[ROUTER] Auth changed: ${user?.uid}',
      );
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

// =============================================
// TOÀN BỘ ĐƯỜNG DẪN ỨNG DỤNG
// =============================================

class AppRouter {
  AppRouter._();

  static const String welcome = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String phoneLogin = '/phone-login';

  static const String home = '/home';
  static const String addExpense = '/add-expense';
  static const String notifications = '/notifications';
  static const String profile = '/profile';

  static const String wallets = '/wallets';
  static const String categories = '/categories';
  static const String setBudget = '/set-budget';
  static const String calendar = '/calendar';
  static const String statistic = '/statistic';
  static const String transactions = '/transactions';
  static const String editProfile = '/edit-profile';

  static const String transactionDetail =
      '/transaction-detail/:id';

  static String transactionDetailPath(String id) {
    return '/transaction-detail/${Uri.encodeComponent(id)}';
  }

  static final AuthRouterNotifier _authNotifier =
  AuthRouterNotifier();

  static final GoRouter router = GoRouter(
    initialLocation: welcome,
    refreshListenable: _authNotifier,

    redirect: (context, state) {
      final user = FirebaseAuth.instance.currentUser;
      final loggedIn = user != null;
      final path = state.matchedLocation;

      const publicRoutes = <String>{
        welcome,
        login,
        register,
        phoneLogin,
      };

      final publicPage = publicRoutes.contains(path);

      debugPrint(
        '[ROUTER] path=$path, loggedIn=$loggedIn',
      );

      // Người chưa đăng nhập không được vào Home.
      if (!loggedIn && !publicPage) {
        return login;
      }

      // Người đã đăng nhập không cần ở màn Login.
      if (loggedIn && publicPage) {
        return home;
      }

      return null;
    },

    routes: [
      GoRoute(
        path: welcome,
        builder: (context, state) =>
        const WelcomeScreen(),
      ),

      GoRoute(
        path: login,
        builder: (context, state) =>
        const LoginScreen(),
      ),

      GoRoute(
        path: register,
        builder: (context, state) =>
        const RegisterScreen(),
      ),

      GoRoute(
        path: phoneLogin,
        builder: (context, state) =>
        const PhoneLoginScreen(),
      ),

      GoRoute(
        path: home,
        builder: (context, state) =>
        const HomeScreen(),
      ),

      GoRoute(
        path: addExpense,
        builder: (context, state) =>
        const AddExpenseScreen(),
      ),

      GoRoute(
        path: notifications,
        builder: (context, state) =>
        const NotificationScreen(),
      ),

      GoRoute(
        path: profile,
        builder: (context, state) =>
        const ProfileScreen(),
      ),

      GoRoute(
        path: wallets,
        builder: (context, state) =>
        const WalletsScreen(),
      ),

      GoRoute(
        path: categories,
        builder: (context, state) =>
        const CategoriesScreen(),
      ),

      GoRoute(
        path: setBudget,
        builder: (context, state) =>
        const SetBudgetScreen(),
      ),

      GoRoute(
        path: calendar,
        builder: (context, state) =>
        const CalendarScreen(),
      ),

      GoRoute(
        path: statistic,
        builder: (context, state) =>
        const StatisticScreen(),
      ),

      GoRoute(
        path: transactions,
        builder: (context, state) =>
        const TransactionListScreen(),
      ),

      GoRoute(
        path: editProfile,
        builder: (context, state) =>
        const EditProfileScreen(),
      ),

      GoRoute(
        path: transactionDetail,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';

          return TransactionDetailScreen(
            transactionId: id,
          );
        },
      ),
    ],

    errorBuilder: (context, state) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Không tìm thấy trang'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 54,
                  color: Colors.orange,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Không thể mở trang này',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Đường dẫn: ${state.uri}',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () {
                    final loggedIn =
                        FirebaseAuth.instance.currentUser !=
                            null;

                    context.go(
                      loggedIn ? home : login,
                    );
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
