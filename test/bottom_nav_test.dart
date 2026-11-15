import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:chi_tieu/app/app_router.dart';
import 'package:chi_tieu/widgets/app_bottom_nav.dart';

// ==========================================
// MÀN HÌNH GIẢ LẬP ĐỂ TEST
// ==========================================

Widget testPage(String title) {
  return Scaffold(
    appBar: AppBar(title: Text(title)),
    body: Center(child: Text('Màn $title')),
    bottomNavigationBar: const AppBottomNav(),
  );
}

// ==========================================
// ROUTER DÀNH RIÊNG CHO TEST
// Không cần kết nối Firebase.
// ==========================================

GoRouter createTestRouter() {
  return GoRouter(
    initialLocation: AppRouter.home,
    routes: [
      GoRoute(
        path: AppRouter.home,
        builder: (context, state) => testPage('Trang chủ'),
      ),
      GoRoute(
        path: AppRouter.calendar,
        builder: (context, state) => testPage('Lịch'),
      ),
      GoRoute(
        path: AppRouter.addExpense,
        builder: (context, state) => testPage('Thêm giao dịch'),
      ),
      GoRoute(
        path: AppRouter.statistic,
        builder: (context, state) => testPage('Thống kê'),
      ),
      GoRoute(
        path: AppRouter.profile,
        builder: (context, state) => testPage('Cá nhân'),
      ),
    ],
  );
}

// ==========================================
// CÁC BÀI KIỂM THỬ
// ==========================================

void main() {
  testWidgets('BottomNav hiển thị đúng 5 nút', (tester) async {
    final router = createTestRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    expect(find.byTooltip('Trang chủ'), findsOneWidget);

    expect(find.byTooltip('Lịch'), findsOneWidget);

    expect(find.byTooltip('Thêm giao dịch'), findsOneWidget);

    expect(find.byTooltip('Thống kê'), findsOneWidget);

    expect(find.byTooltip('Cá nhân'), findsOneWidget);

    // Không có nút Thông báo.
    expect(find.byTooltip('Thông báo'), findsNothing);

    // Không có nút Quay lại ở dưới.
    expect(find.byTooltip('Quay về Trang chủ'), findsNothing);
  });

  testWidgets('Chuyển giữa các màn hình chính', (tester) async {
    final router = createTestRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    // Màn Home
    expect(find.text('Màn Trang chủ'), findsOneWidget);

    // Home -> Lịch
    await tester.tap(find.byTooltip('Lịch'));
    await tester.pumpAndSettle();

    expect(find.text('Màn Lịch'), findsOneWidget);

    // Lịch -> Thống kê
    await tester.tap(find.byTooltip('Thống kê'));
    await tester.pumpAndSettle();

    expect(find.text('Màn Thống kê'), findsOneWidget);

    // Thống kê -> Cá nhân
    await tester.tap(find.byTooltip('Cá nhân'));
    await tester.pumpAndSettle();

    expect(find.text('Màn Cá nhân'), findsOneWidget);

    // Cá nhân -> Home
    await tester.tap(find.byTooltip('Trang chủ'));
    await tester.pumpAndSettle();

    expect(find.text('Màn Trang chủ'), findsOneWidget);

    // Home -> Thêm giao dịch
    await tester.tap(find.byTooltip('Thêm giao dịch'));
    await tester.pumpAndSettle();

    expect(find.text('Màn Thêm giao dịch'), findsOneWidget);
  });

  testWidgets('BottomNav hoạt động trong Dark Mode', (tester) async {
    final router = createTestRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(routerConfig: router, theme: ThemeData.dark()),
    );

    final context = tester.element(find.byType(AppBottomNav));

    expect(Theme.of(context).brightness, Brightness.dark);

    expect(find.byTooltip('Thêm giao dịch'), findsOneWidget);
  });
}
