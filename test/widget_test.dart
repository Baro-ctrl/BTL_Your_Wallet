
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chi_tieu/screens/logout_dialog.dart';

void main() {
  // ========================================
  // TEST 1: HỦY ĐĂNG XUẤT
  // ========================================

  testWidgets(
    'LogoutDialog - Nhan Huy tra ve false',
        (tester) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    result = await LogoutDialog.show(
                      context,
                    );
                  },
                  child: const Text('Mo dialog'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Mo dialog'));
      await tester.pumpAndSettle();

      expect(
        find.text('Đăng xuất?'),
        findsOneWidget,
      );

      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();

      expect(result, false);
      expect(
        find.text('Đăng xuất?'),
        findsNothing,
      );
    },
  );

  // ========================================
  // TEST 2: XÁC NHẬN ĐĂNG XUẤT
  // ========================================

  testWidgets(
    'LogoutDialog - Xac nhan tra ve true',
        (tester) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    result = await LogoutDialog.show(
                      context,
                    );
                  },
                  child: const Text('Mo dialog'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Mo dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Đăng xuất'));
      await tester.pumpAndSettle();

      expect(result, true);
      expect(
        find.text('Đăng xuất?'),
        findsNothing,
      );
    },
  );
}
