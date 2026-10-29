import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/app_router.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  bool _isLoggingOut = false;

  // ==========================================
  // 1. HIỂN THỊ THÔNG BÁO LỖI
  // ==========================================

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.danger),
    );
  }

  // ==========================================
  // 2. XÁC NHẬN VÀ THỰC HIỆN ĐĂNG XUẤT
  // ==========================================

  Future<void> _handleLogout() async {
    if (_isLoggingOut) return;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.logout, color: AppColors.danger),
              SizedBox(width: 10),
              Text('Đăng xuất'),
            ],
          ),
          content: const Text(
            'Bạn có chắc chắn muốn đăng xuất khỏi '
            'tài khoản Your Wallet không?',
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
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              child: const Text('Đăng xuất'),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed != true) return;

    setState(() {
      _isLoggingOut = true;
    });

    try {
      await _authService.logout();

      if (!mounted) return;

      context.go(AppRouter.login);
    } on FirebaseAuthException catch (error) {
      _showError(_authService.getErrorMessage(error));
    } catch (error) {
      _showError('Đăng xuất thất bại: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isLoggingOut = false;
        });
      }
    }
  }

  // ==========================================
  // 3. MENU HỒ SƠ - SỬA CẢNH BÁO LISTTILE
  // ==========================================

  Widget _menuTile({
    required IconData icon,
    required String title,
    required VoidCallback? onTap,
    Color? color,
  }) {
    final itemColor = color ?? AppColors.textPrimary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: ListTile(
            onTap: onTap,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 2,
            ),
            leading: Icon(icon, color: itemColor),
            title: Text(
              title,
              style: TextStyle(fontWeight: FontWeight.w600, color: itemColor),
            ),
            trailing: Icon(Icons.chevron_right, color: itemColor),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 4. ẢNH ĐẠI DIỆN
  // ==========================================

  Widget _buildAvatar(String photoUrl) {
    return CircleAvatar(
      radius: 45,
      backgroundColor: const Color(0xFFE3F2FD),
      child: ClipOval(
        child: photoUrl.isNotEmpty
            ? Image.network(
                photoUrl,
                width: 90,
                height: 90,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.person,
                    size: 48,
                    color: AppColors.primaryDark,
                  );
                },
              )
            : const Icon(Icons.person, size: 48, color: AppColors.primaryDark),
      ),
    );
  }

  // ==========================================
  // 5. THẺ THÔNG TIN TÀI KHOẢN
  // ==========================================

  Widget _profileCard({
    required String name,
    required String email,
    required String photoUrl,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _buildAvatar(photoUrl),

          const SizedBox(height: 14),

          Text(
            name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            email,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),

          const SizedBox(height: 18),

          OutlinedButton.icon(
            onPressed: _isLoggingOut
                ? null
                : () {
                    context.push(AppRouter.editProfile);
                  },
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Chỉnh sửa hồ sơ'),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 6. DANH SÁCH MENU
  // ==========================================

  Widget _profileContent({
    required String name,
    required String email,
    required String photoUrl,
  }) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _profileCard(name: name, email: email, photoUrl: photoUrl),

        const SizedBox(height: 24),

        const Text(
          'Quản lý tài chính',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),

        const SizedBox(height: 14),

        _menuTile(
          icon: Icons.account_balance_wallet_outlined,
          title: 'Quản lý ví',
          onTap: _isLoggingOut ? null : () => context.push(AppRouter.wallets),
        ),

        _menuTile(
          icon: Icons.category_outlined,
          title: 'Quản lý danh mục',
          onTap: _isLoggingOut
              ? null
              : () => context.push(AppRouter.categories),
        ),

        _menuTile(
          icon: Icons.savings_outlined,
          title: 'Thiết lập ngân sách',
          onTap: _isLoggingOut ? null : () => context.push(AppRouter.setBudget),
        ),

        _menuTile(
          icon: Icons.receipt_long_outlined,
          title: 'Lịch sử giao dịch',
          onTap: _isLoggingOut
              ? null
              : () => context.push(AppRouter.transactions),
        ),

        const SizedBox(height: 16),

        const Text(
          'Tài khoản',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),

        const SizedBox(height: 14),

        _menuTile(
          icon: Icons.logout,
          title: _isLoggingOut ? 'Đang đăng xuất...' : 'Đăng xuất',
          color: AppColors.danger,
          onTap: _isLoggingOut ? null : _handleLogout,
        ),
      ],
    );
  }

  // ==========================================
  // 7. GIAO DIỆN CHÍNH - FIRESTORE REALTIME
  // ==========================================

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AppColors.bg,

      appBar: AppBar(title: const Text('Hồ sơ cá nhân'), centerTitle: true),

      body: SafeArea(
        child: user == null
            ? const Center(child: Text('Vui lòng đăng nhập để xem hồ sơ.'))
            : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: _db.collection('users').doc(user.uid).snapshots(),
                builder: (context, snapshot) {
                  // Firebase Auth dùng làm dữ liệu dự phòng.
                  final authName = user.displayName?.trim() ?? '';

                  final authEmail =
                      user.email ??
                      user.phoneNumber ??
                      'Chưa cập nhật thông tin';

                  final authPhoto = user.photoURL ?? '';

                  // Không có dữ liệu Firestore:
                  // vẫn hiển thị hồ sơ Auth.
                  if (!snapshot.hasData) {
                    if (snapshot.hasError) {
                      return Column(
                        children: [
                          const Padding(
                            padding: EdgeInsets.all(12),
                            child: Text(
                              'Không đồng bộ được hồ sơ từ '
                              'Firestore. Đang hiển thị '
                              'thông tin tài khoản.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.danger,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Expanded(
                            child: _profileContent(
                              name: authName.isNotEmpty
                                  ? authName
                                  : 'Người dùng Your Wallet',
                              email: authEmail,
                              photoUrl: authPhoto,
                            ),
                          ),
                        ],
                      );
                    }

                    return const Center(child: CircularProgressIndicator());
                  }

                  final data = snapshot.data!.data() ?? {};

                  final savedName = data['name']?.toString().trim() ?? '';

                  final savedPhoto = data['avatarUrl']?.toString().trim() ?? '';

                  final name = savedName.isNotEmpty
                      ? savedName
                      : authName.isNotEmpty
                      ? authName
                      : 'Người dùng Your Wallet';

                  final photoUrl = savedPhoto.isNotEmpty
                      ? savedPhoto
                      : authPhoto;

                  return _profileContent(
                    name: name,
                    email: authEmail,
                    photoUrl: photoUrl,
                  );
                },
              ),
      ),

      // GIỮ NGUYÊN THANH ĐIỀU HƯỚNG
      bottomNavigationBar: AppBottomNav(
        currentIndex: 3,
        onTap: (index) {
          if (_isLoggingOut) return;

          switch (index) {
            case 0:
              context.go(AppRouter.home);
              break;

            case 1:
              context.go(AppRouter.addExpense);
              break;

            case 2:
              context.go(AppRouter.notifications);
              break;

            case 3:
              break;
          }
        },
      ),
    );
  }
}
