
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

String formatVnd(int amount) {
  final negative = amount < 0;
  final digits = amount.abs().toString();
  final formatted = digits.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (match) => '.',
  );
  return '${negative ? '-' : ''}$formatted đ';
}

class FinanceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const FinanceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

class FinanceTitle extends StatelessWidget {
  final String title;

  const FinanceTitle(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
      ),
    );
  }
}

void showDemoNotice(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text(
        'Đây là giao diện demo. Chưa lưu vào Firebase.',
      ),
    ),
  );
}
