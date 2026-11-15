import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/app_router.dart';
import '../services/theme_controller.dart';
import '../widgets/app_bottom_nav.dart';

// ==========================================
// PROFILE SCREEN
// ==========================================

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  bool _dailyReminder = false;
  bool _loggingOut = false;

  User? get _user => _auth.currentUser;

  // ==========================================
  // 1. KHỞI TẠO
  // ==========================================

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  // ==========================================
  // 2. ĐỌC CÀI ĐẶT ĐÃ LƯU
  // ==========================================

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (!mounted) return;

      setState(() {
        _dailyReminder = prefs.getBool('daily_reminder') ?? false;
      });
    } catch (error) {
      debugPrint('[PROFILE] Không tải được cài đặt: $error');
    }
  }

  // ==========================================
  // 3. BẬT / TẮT NHẮC NHỞ
  // ==========================================

  Future<void> _setDailyReminder(bool value) async {
    setState(() {
      _dailyReminder = value;
    });

    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setBool('daily_reminder', value);
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _dailyReminder = !value;
      });

      _showMessage('Không lưu được cài đặt nhắc nhở.');
    }
  }

  // ==========================================
  // 4. BẬT / TẮT DARK MODE
  // ==========================================

  void _setDarkMode(bool value) {
    ThemeController.instance.setDarkMode(value);
  }

  // ==========================================
  // 5. HIỂN THỊ THÔNG BÁO
  // ==========================================

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  // ==========================================
  // 6. QUAY VỀ TRANG CHỦ
  // ==========================================

  void _goHome() {
    context.go(AppRouter.home);
  }

  // ==========================================
  // 7. APP BAR
  // ==========================================

  PreferredSizeWidget _buildAppBar() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AppBar(
      automaticallyImplyLeading: false,

      centerTitle: true,

      elevation: 0,
      scrolledUnderElevation: 0,

      backgroundColor: theme.scaffoldBackgroundColor,
      foregroundColor: scheme.onSurface,

      // NÚT QUAY VỀ HOME
      leading: IconButton(
        tooltip: 'Về Trang chủ',
        icon: const Icon(Icons.arrow_back_rounded, size: 25),
        onPressed: _goHome,
      ),

      title: const Text(
        'Hồ sơ cá nhân',
        style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
      ),
    );
  }

  // ==========================================
  // 8. HỖ TRỢ CHUYỂN NGÀY FIRESTORE
  // ==========================================

  DateTime? _toDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
  }

  // ==========================================
  // 9. ĐỌC NGÀY GIAO DỊCH
  // ==========================================

  DateTime? _transactionDate(Map<String, dynamic> data) {
    return _toDate(data['date']) ??
        _toDate(data['transactionDate']) ??
        _toDate(data['createdAt']);
  }

  // ==========================================
  // 10. KIỂM TRA ẢNH GIAO DỊCH
  // ==========================================

  bool _hasImage(Map<String, dynamic> data) {
    final candidates = [
      data['imageUrl'],
      data['receiptImageUrl'],
      data['photoUrl'],
    ];

    for (final value in candidates) {
      if (value is String && value.trim().isNotEmpty) {
        return true;
      }
    }

    final images = data['imageUrls'];

    if (images is List && images.isNotEmpty) {
      return true;
    }

    return false;
  }

  // ==========================================
  // 11. ĐẾM NGÀY GHI CHÉP LIÊN TIẾP
  // ==========================================

  int _calculateStreak(List<DateTime> dates) {
    if (dates.isEmpty) return 0;

    final uniqueDays = dates.map((date) {
      return DateTime(date.year, date.month, date.day);
    }).toSet();

    final now = DateTime.now();

    final today = DateTime(now.year, now.month, now.day);

    DateTime cursor = today;

    // Nếu hôm nay chưa ghi chép, vẫn tính
    // chuỗi liên tiếp kết thúc vào hôm qua.
    if (!uniqueDays.contains(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));

      if (!uniqueDays.contains(cursor)) {
        return 0;
      }
    }

    int streak = 0;

    while (uniqueDays.contains(cursor)) {
      streak++;

      cursor = cursor.subtract(const Duration(days: 1));
    }

    return streak;
  }

  // ==========================================
  // 12. THẺ THỐNG KÊ
  // ==========================================

  Widget _statCard({required String value, required String label}) {
    final scheme = Theme.of(context).colorScheme;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: scheme.primary,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 13. THỐNG KÊ FIRESTORE
  // ==========================================

  Widget _buildStatistics(String uid) {
    final transactionsRef = _db
        .collection('users')
        .doc(uid)
        .collection('transactions');

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: transactionsRef.snapshots(),

      builder: (context, snapshot) {
        int transactionCount = 0;
        int imageCount = 0;
        int streak = 0;

        if (snapshot.hasData) {
          final docs = snapshot.data!.docs;

          transactionCount = docs.length;

          final dates = <DateTime>[];

          for (final doc in docs) {
            final data = doc.data();

            final date = _transactionDate(data);

            if (date != null) {
              dates.add(date);
            }

            if (_hasImage(data)) {
              imageCount++;
            }
          }

          streak = _calculateStreak(dates);
        }

        return Row(
          children: [
            _statCard(value: '$transactionCount', label: 'Giao dịch'),

            const SizedBox(width: 10),

            _statCard(value: '$imageCount', label: 'Ảnh đính kèm'),

            const SizedBox(width: 10),

            _statCard(value: '$streak', label: 'Ngày liên tiếp'),
          ],
        );
      },
    );
  }

  // ==========================================
  // 14. AVATAR
  // ==========================================

  Widget _buildAvatar(String avatarUrl) {
    final scheme = Theme.of(context).colorScheme;

    final imageProvider = avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null;

    return CircleAvatar(
      radius: 48,
      backgroundColor: scheme.primaryContainer,
      backgroundImage: imageProvider,

      child: imageProvider == null
          ? Icon(Icons.person_rounded, size: 52, color: scheme.primary)
          : null,
    );
  }

  // ==========================================
  // 15. THÔNG TIN NGƯỜI DÙNG
  // ==========================================

  Widget _buildUserInfo(User user, Map<String, dynamic> data) {
    final scheme = Theme.of(context).colorScheme;

    final name = (data['name']?.toString().trim().isNotEmpty ?? false)
        ? data['name'].toString()
        : (user.displayName?.isNotEmpty ?? false)
        ? user.displayName!
        : 'Người dùng Your Wallet';

    final email = user.email ?? data['email']?.toString() ?? '';

    final phone = user.phoneNumber ?? data['phone']?.toString() ?? '';

    final avatarUrl = (data['avatarUrl']?.toString().isNotEmpty ?? false)
        ? data['avatarUrl'].toString()
        : user.photoURL ?? '';

    return Column(
      children: [
        _buildAvatar(avatarUrl),

        const SizedBox(height: 14),

        Text(
          name,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.bold,
            color: scheme.onSurface,
          ),
        ),

        if (email.isNotEmpty) ...[
          const SizedBox(height: 6),

          Text(
            email,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
          ),
        ],

        if (phone.isNotEmpty) ...[
          const SizedBox(height: 6),

          Text(
            phone,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
          ),
        ],

        const SizedBox(height: 14),

        OutlinedButton.icon(
          onPressed: () {
            context.push(AppRouter.editProfile);
          },
          icon: const Icon(Icons.edit_outlined, size: 17),
          label: const Text('Chỉnh sửa hồ sơ'),
        ),
      ],
    );
  }

  // ==========================================
  // 16. MENU ĐIỀU HƯỚNG
  // ==========================================

  Widget _menuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surface,

      borderRadius: BorderRadius.circular(12),

      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),

        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),

          child: Row(
            children: [
              Icon(icon, color: scheme.primary, size: 22),

              const SizedBox(width: 14),

              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: scheme.onSurface,
                  ),
                ),
              ),

              Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 17. MENU CÔNG CỤ QUẢN LÝ
  // ==========================================

  Widget _buildManagementMenu() {
    return Column(
      children: [
        _menuItem(
          icon: Icons.flag_outlined,
          title: 'Đặt mục tiêu / Ngân sách',
          onTap: () {
            context.push(AppRouter.setBudget);
          },
        ),

        const SizedBox(height: 8),

        _menuItem(
          icon: Icons.category_outlined,
          title: 'Quản lý danh mục',
          onTap: () {
            context.push(AppRouter.categories);
          },
        ),

        const SizedBox(height: 8),

        _menuItem(
          icon: Icons.account_balance_wallet_outlined,
          title: 'Quản lý ví',
          onTap: () {
            context.push(AppRouter.wallets);
          },
        ),
      ],
    );
  }

  // ==========================================
  // 18. CÀI ĐẶT NHẮC NHỞ
  // ==========================================

  Widget _buildReminderSetting() {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
      ),

      child: SwitchListTile(
        secondary: Icon(
          Icons.notifications_active_outlined,
          color: scheme.primary,
        ),

        title: const Text(
          'Nhắc nhở chi tiêu hằng ngày',
          style: TextStyle(fontSize: 14),
        ),

        value: _dailyReminder,
        onChanged: _setDailyReminder,

        activeThumbColor: scheme.primary,
      ),
    );
  }

  // ==========================================
  // 19. CÀI ĐẶT DARK MODE
  // ==========================================

  Widget _buildDarkModeSetting() {
    final scheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: ThemeController.instance,

      builder: (context, _) {
        return Container(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(14),
          ),

          child: SwitchListTile(
            secondary: Icon(Icons.dark_mode_outlined, color: scheme.primary),

            title: const Text('Giao diện tối', style: TextStyle(fontSize: 14)),

            subtitle: const Text(
              'Thay đổi giao diện toàn ứng dụng',
              style: TextStyle(fontSize: 12),
            ),

            value: ThemeController.instance.isDark,

            onChanged: _setDarkMode,

            activeThumbColor: scheme.primary,
          ),
        );
      },
    );
  }

  // ==========================================
  // 20. HỘP THOẠI XÁC NHẬN ĐĂNG XUẤT
  // ==========================================

  Future<bool> _confirmLogout() async {
    final result = await showDialog<bool>(
      context: context,

      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Đăng xuất'),

          content: const Text(
            'Bạn có chắc chắn muốn đăng xuất '
            'khỏi tài khoản không?',
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Hủy'),
            ),

            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Đăng xuất'),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  // ==========================================
  // 21. ĐĂNG XUẤT
  // ==========================================

  Future<void> _logout() async {
    if (_loggingOut) return;

    final confirmed = await _confirmLogout();

    if (!confirmed || !mounted) {
      return;
    }

    setState(() {
      _loggingOut = true;
    });

    try {
      await _auth.signOut();

      if (!mounted) return;

      context.go(AppRouter.login);
    } catch (error) {
      _showMessage('Đăng xuất thất bại: $error');
    } finally {
      if (mounted) {
        setState(() {
          _loggingOut = false;
        });
      }
    }
  }

  // ==========================================
  // 22. NÚT ĐĂNG XUẤT
  // ==========================================

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,

      child: FilledButton.icon(
        onPressed: _loggingOut ? null : _logout,

        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFFEF4444),
          foregroundColor: Colors.white,

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),

        icon: _loggingOut
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.logout_rounded),

        label: Text(_loggingOut ? 'Đang đăng xuất...' : 'Đăng xuất'),
      ),
    );
  }

  // ==========================================
  // 23. GIAO DIỆN HỒ SƠ CHÍNH
  // ==========================================

  @override
  Widget build(BuildContext context) {
    final user = _user;

    final theme = Theme.of(context);

    // CHƯA ĐĂNG NHẬP
    if (user == null) {
      return Scaffold(
        appBar: _buildAppBar(),

        body: const Center(child: Text('Vui lòng đăng nhập.')),
      );
    }

    final userRef = _db.collection('users').doc(user.uid);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,

      // NÚT QUAY VỀ HOME Ở GÓC TRÊN TRÁI
      appBar: _buildAppBar(),

      // ======================================
      // NỘI DUNG PROFILE
      // ======================================
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: userRef.snapshots(),

          builder: (context, snapshot) {
            final userData = snapshot.data?.data() ?? <String, dynamic>{};

            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),

              children: [
                // THÔNG TIN NGƯỜI DÙNG
                _buildUserInfo(user, userData),

                const SizedBox(height: 24),

                // THỐNG KÊ GIAO DỊCH
                _buildStatistics(user.uid),

                const SizedBox(height: 24),

                // MENU QUẢN LÝ
                _buildManagementMenu(),

                const SizedBox(height: 20),

                // NHẮC NHỞ HẰNG NGÀY
                _buildReminderSetting(),

                const SizedBox(height: 8),

                // DARK MODE
                _buildDarkModeSetting(),

                const SizedBox(height: 24),

                // ĐĂNG XUẤT
                _buildLogoutButton(),

                const SizedBox(height: 24),
              ],
            );
          },
        ),
      ),

      // ======================================
      // THANH ĐIỀU HƯỚNG 5 NÚT
      // ======================================
      bottomNavigationBar: const AppBottomNav(),
    );
  }
}
