import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_colors.dart';
import '../widgets/finance_ui.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final TextEditingController _nameController = TextEditingController();

  final TextEditingController _emailController = TextEditingController();

  final TextEditingController _phoneController = TextEditingController();

  String _photoUrl = '';

  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // ==========================================
  // 1. KIỂM TRA ĐƯỜNG DẪN ẢNH
  // ==========================================

  bool _isValidImageUrl(String value) {
    if (value.isEmpty) return true;

    final uri = Uri.tryParse(value);

    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
  }

  // ==========================================
  // 2. TẢI THÔNG TIN TÀI KHOẢN
  // ==========================================

  Future<void> _loadProfile() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      final user = _auth.currentUser;

      if (user == null) {
        throw StateError('Bạn chưa đăng nhập.');
      }

      final profile = await _db.collection('users').doc(user.uid).get();

      final data = profile.data() ?? {};

      final firestoreName = data['name']?.toString().trim() ?? '';

      final authName = user.displayName?.trim() ?? '';

      final firestorePhone = data['phone']?.toString().trim() ?? '';

      final firestorePhoto = data['avatarUrl']?.toString().trim() ?? '';

      if (!mounted) return;

      setState(() {
        _nameController.text = firestoreName.isNotEmpty
            ? firestoreName
            : authName;

        _emailController.text = user.email ?? '';

        _phoneController.text = firestorePhone.isNotEmpty
            ? firestorePhone
            : (user.phoneNumber ?? '');

        _photoUrl = firestorePhoto.isNotEmpty
            ? firestorePhoto
            : (user.photoURL ?? '');

        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loadError = error.toString();
        _loading = false;
      });

      debugPrint('[PROFILE] Load error: $error');
    }
  }

  // ==========================================
  // 3. HIỂN THỊ THÔNG BÁO
  // ==========================================

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  // ==========================================
  // 4. THAY ĐỔI URL ẢNH ĐẠI DIỆN
  // ==========================================

  Future<void> _changeAvatar() async {
    if (_saving) return;

    final controller = TextEditingController(text: _photoUrl);

    try {
      final result = await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Ảnh đại diện'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Nhập đường dẫn HTTPS của ảnh '
                  'bạn muốn dùng làm ảnh đại diện.',
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'URL ảnh',
                    hintText: 'https://example.com/avatar.jpg',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.link),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Để trống nếu muốn bỏ ảnh đại diện.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Hủy'),
              ),
              FilledButton(
                onPressed: () {
                  final url = controller.text.trim();

                  if (!_isValidImageUrl(url)) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(
                        content: Text('Vui lòng nhập URL HTTPS hợp lệ.'),
                      ),
                    );
                    return;
                  }

                  Navigator.pop(dialogContext, url);
                },
                child: const Text('Chọn ảnh'),
              ),
            ],
          );
        },
      );

      if (!mounted || result == null) return;

      setState(() {
        _photoUrl = result;
      });

      _showMessage(
        'Đã chọn ảnh. Nhấn Lưu thay đổi '
        'để cập nhật hồ sơ.',
      );
    } finally {
      // Chờ khung hình kế tiếp sau khi hộp thoại
      // đã đóng trước khi hủy controller.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.dispose();
      });
    }
  }

  // ==========================================
  // 5. LƯU HỒ SƠ LÊN FIREBASE
  // ==========================================

  Future<void> _saveProfile() async {
    if (_saving || _loading) return;

    final user = _auth.currentUser;

    if (user == null) {
      _showMessage('Bạn chưa đăng nhập.');
      return;
    }

    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final photo = _photoUrl.trim();

    if (name.isEmpty) {
      _showMessage('Vui lòng nhập họ và tên.');
      return;
    }

    if (name.length > 100) {
      _showMessage('Họ tên tối đa 100 ký tự.');
      return;
    }

    if (phone.isNotEmpty && !RegExp(r'^\+?[0-9]{9,15}$').hasMatch(phone)) {
      _showMessage('Số điện thoại chưa đúng định dạng.');
      return;
    }

    if (!_isValidImageUrl(photo)) {
      _showMessage('URL ảnh đại diện không hợp lệ.');
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      // BƯỚC 1: Lưu thông tin hồ sơ Firestore.
      // Không ghi đè dữ liệu ví, danh mục, giao dịch.
      final profileRef = _db.collection('users').doc(user.uid);

      await profileRef.set({
        'id': user.uid,
        'name': name,
        'phone': phone,
        'avatarUrl': photo,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('[PROFILE] Firestore updated');

      // BƯỚC 2: Đồng bộ tên Firebase Authentication.
      if (user.displayName != name) {
        await user.updateDisplayName(name);
      }

      // BƯỚC 3: Đồng bộ URL ảnh Firebase Authentication.
      if ((user.photoURL ?? '') != photo) {
        await user.updatePhotoURL(photo.isEmpty ? null : photo);
      }

      await user.reload();

      debugPrint('[PROFILE] Auth profile updated');

      if (!mounted) return;

      _showMessage('Đã cập nhật hồ sơ thành công!');

      // Quay lại màn Hồ sơ.
      if (context.canPop()) {
        context.pop();
      }
    } on FirebaseAuthException catch (error) {
      _showMessage(
        'Không thể đồng bộ tài khoản: '
        '${error.message ?? error.code}',
      );
    } on FirebaseException catch (error) {
      _showMessage(
        'Lỗi Firestore: '
        '${error.message ?? error.code}',
      );
    } catch (error) {
      _showMessage('Không thể lưu hồ sơ: $error');
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  // ==========================================
  // 6. ẢNH ĐẠI DIỆN
  // ==========================================

  Widget _avatar() {
    return CircleAvatar(
      key: ValueKey(_photoUrl),
      radius: 46,
      backgroundColor: const Color(0xFFE3F2FD),
      child: ClipOval(
        child: _photoUrl.isNotEmpty
            ? Image.network(
                _photoUrl,
                width: 92,
                height: 92,
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
  // 7. TRƯỜNG NHẬP
  // ==========================================

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    String? helper,
  }) {
    return InputDecoration(
      labelText: label,
      helperText: helper,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    );
  }

  // ==========================================
  // 8. GIAO DIỆN CHÍNH
  // ==========================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Chỉnh sửa hồ sơ')),
      body: _loading
          ? Center(
              child: _loadError == null
                  ? const CircularProgressIndicator()
                  : Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Không tải được hồ sơ:\n$_loadError',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: _loadProfile,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Thử lại'),
                          ),
                        ],
                      ),
                    ),
            )
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    FinanceCard(
                      child: Column(
                        children: [
                          _avatar(),

                          const SizedBox(height: 10),

                          TextButton.icon(
                            onPressed: _saving ? null : _changeAvatar,
                            icon: const Icon(Icons.camera_alt_outlined),
                            label: const Text('Đổi ảnh đại diện'),
                          ),

                          const SizedBox(height: 24),

                          TextField(
                            controller: _nameController,
                            enabled: !_saving,
                            textCapitalization: TextCapitalization.words,
                            decoration: _inputDecoration(
                              label: 'Họ và tên',
                              icon: Icons.person_outline,
                            ),
                          ),

                          const SizedBox(height: 16),

                          TextField(
                            controller: _phoneController,
                            enabled: !_saving,
                            keyboardType: TextInputType.phone,
                            decoration: _inputDecoration(
                              label: 'Số điện thoại liên hệ',
                              icon: Icons.phone_outlined,
                              helper: 'Không thay đổi số OTP đã xác minh.',
                            ),
                          ),

                          const SizedBox(height: 16),

                          TextField(
                            controller: _emailController,
                            readOnly: true,
                            decoration: _inputDecoration(
                              label: 'Email đăng nhập',
                              icon: Icons.email_outlined,
                              helper:
                                  'Email đăng nhập được quản lý '
                                  'trong Firebase Authentication.',
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _saveProfile,
                        icon: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(_saving ? 'Đang lưu...' : 'Lưu thay đổi'),
                      ),
                    ),

                    const SizedBox(height: 12),

                    const Text(
                      'Thông tin hồ sơ được lưu trên '
                      'Firebase và có thể dùng lại '
                      'sau khi đăng nhập.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
