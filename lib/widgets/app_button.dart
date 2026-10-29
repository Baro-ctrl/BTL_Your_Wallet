import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final Color? color;
  final Color? textColor;
  final IconData? icon;

  const AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.color,
    this.textColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: icon != null
            ? Icon(icon, color: textColor ?? Colors.white, size: 20)
            : const SizedBox.shrink(),
        label: Text(
          text,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: textColor ?? Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
      ),
    );
  }
}