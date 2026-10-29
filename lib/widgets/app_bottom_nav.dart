
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: onTap,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.primary.withValues(
        alpha: 0.12,
      ),
      height: 70,
      labelBehavior:
      NavigationDestinationLabelBehavior.alwaysShow,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(
            Icons.home,
            color: AppColors.primaryDark,
          ),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.add_circle_outline),
          selectedIcon: Icon(
            Icons.add_circle,
            color: AppColors.primaryDark,
          ),
          label: 'Thêm',
        ),
        NavigationDestination(
          icon: Icon(Icons.notifications_none),
          selectedIcon: Icon(
            Icons.notifications,
            color: AppColors.primaryDark,
          ),
          label: 'TB',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(
            Icons.person,
            color: AppColors.primaryDark,
          ),
          label: 'Tôi',
        ),
      ],
    );
  }
}
