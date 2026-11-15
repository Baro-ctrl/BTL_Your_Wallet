import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/app_router.dart';

class AppBottomNav extends StatelessWidget {
  // Giữ tương thích với các màn hình cũ
  // đang truyền AppBottomNav(onTap: ...).
  final ValueChanged<int>? onTap;
  final int? currentIndex;

  const AppBottomNav({super.key, this.onTap, this.currentIndex});

  // ==========================================
  // XÁC ĐỊNH TAB ĐANG CHỌN
  // ==========================================

  int _selectedIndex(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;

    if (path == AppRouter.home) return 0;
    if (path == AppRouter.calendar) return 1;
    if (path == AppRouter.addExpense) return 2;
    if (path == AppRouter.statistic) return 3;

    if (path == AppRouter.profile || path == AppRouter.editProfile) {
      return 4;
    }

    return currentIndex ?? -1;
  }

  // ==========================================
  // ĐIỀU HƯỚNG
  // ==========================================

  void _navigate(BuildContext context, int index) {
    final selected = _selectedIndex(context);

    // Không mở lại màn hình đang chọn.
    if (index == selected) return;

    // Tương thích callback của thanh cũ:
    // 0 = Home
    // 1 = Thêm giao dịch
    // 2 = Thông báo
    // 3 = Cá nhân
    //
    // Nút Thông báo đã bị loại bỏ.
    if (onTap != null) {
      switch (index) {
        case 0:
          onTap!(0);
          return;

        case 2:
          onTap!(1);
          return;

        case 4:
          onTap!(3);
          return;
      }
    }

    // Điều hướng bằng GoRouter
    switch (index) {
      case 0:
        context.go(AppRouter.home);
        break;

      case 1:
        context.go(AppRouter.calendar);
        break;

      case 2:
        context.push(AppRouter.addExpense);
        break;

      case 3:
        context.go(AppRouter.statistic);
        break;

      case 4:
        context.go(AppRouter.profile);
        break;
    }
  }

  // ==========================================
  // NÚT ĐIỀU HƯỚNG THƯỜNG
  // ==========================================

  Widget _navItem({
    required BuildContext context,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
    required bool selected,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return Expanded(
      child: Tooltip(
        message: label,
        child: Semantics(
          button: true,
          selected: selected,
          label: label,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _navigate(context, index),
              borderRadius: BorderRadius.circular(14),
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: selected
                        ? scheme.primaryContainer
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    selected ? activeIcon : icon,
                    color: selected ? scheme.primary : scheme.onSurfaceVariant,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // NÚT + MÀU VÀNG
  // ==========================================

  Widget _addButton(BuildContext context) {
    return SizedBox(
      width: 58,
      child: Center(
        child: Tooltip(
          message: 'Thêm giao dịch',
          child: Material(
            color: const Color(0xFFFFBF3F),
            shape: const CircleBorder(),
            elevation: 3,
            shadowColor: const Color(0x55FFBF3F),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => _navigate(context, 2),
              child: const SizedBox(
                width: 50,
                height: 50,
                child: Icon(Icons.add_rounded, color: Colors.white, size: 30),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // GIAO DIỆN THANH ĐIỀU HƯỚNG
  // ==========================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final isDark = theme.brightness == Brightness.dark;

    final selected = _selectedIndex(context);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
        child: Container(
          height: 66,
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? const Color(0x44000000)
                    : const Color(0x16000000),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // 1. TRANG CHỦ
              _navItem(
                context: context,
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                label: 'Trang chủ',
                index: 0,
                selected: selected == 0,
              ),

              // 2. LỊCH
              _navItem(
                context: context,
                icon: Icons.calendar_today_outlined,
                activeIcon: Icons.calendar_month,
                label: 'Lịch',
                index: 1,
                selected: selected == 1,
              ),

              // 3. THÊM GIAO DỊCH
              _addButton(context),

              // 4. THỐNG KÊ
              _navItem(
                context: context,
                icon: Icons.bar_chart_outlined,
                activeIcon: Icons.bar_chart_rounded,
                label: 'Thống kê',
                index: 3,
                selected: selected == 3,
              ),

              // 5. CÁ NHÂN
              _navItem(
                context: context,
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                label: 'Cá nhân',
                index: 4,
                selected: selected == 4,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
