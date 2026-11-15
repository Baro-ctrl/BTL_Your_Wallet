import 'package:flutter/material.dart';

class LogoutDialog extends StatelessWidget {
  const LogoutDialog({super.key});

  // ==========================================
  // HIỂN THỊ DIALOG
  // ==========================================

  static Future<bool> show(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return const LogoutDialog();
      },
    );

    return result ?? false;
  }

  // ==========================================
  // GIAO DIỆN
  // ==========================================

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),

      title: const Row(
        children: [
          Icon(Icons.logout, color: Colors.red),
          SizedBox(width: 10),
          Text('Đăng xuất?'),
        ],
      ),

      content: const Text(
        'Bạn có chắc chắn muốn đăng xuất '
        'khỏi tài khoản Your Wallet không?',
      ),

      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(false);
          },
          child: const Text('Hủy'),
        ),

        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            Navigator.of(context).pop(true);
          },
          child: const Text('Đăng xuất'),
        ),
      ],
    );
  }
}
