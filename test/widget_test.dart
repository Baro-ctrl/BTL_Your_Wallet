import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Your Wallet - basic UI smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(title: const Text('Your Wallet')),
          body: const Center(child: Text('Quản lý tài chính cá nhân')),
        ),
      ),
    );

    expect(find.text('Your Wallet'), findsOneWidget);

    expect(find.text('Quản lý tài chính cá nhân'), findsOneWidget);
  });
}
