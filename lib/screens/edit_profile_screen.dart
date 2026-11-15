import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../app/app_router.dart';
import '../services/auth_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  final _picker = ImagePicker();
  final _authService = AuthService();

  XFile? _selectedImage;
  Uint8List? _imageBytes;

  String _avatarUrl = '';

  bool _loading = false;
  bool _initializing = true;

  User? get _user => FirebaseAuth.instance.currentUser;

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

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // ==========================================
  // TẢI HỒ SƠ
  // ==========================================

  Future<void> _loadProfile() async {
    final user = _user;

    if (user == null) {
      if (mounted) {
        setState(() => _initializing = false);
      }
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!mounted) return;

      final data = snapshot.data() ?? {};

      _nameController.text =
          (data['name'] as String?) ?? user.displayName ?? '';

      _emailController.text = user.email ?? '';

      _phoneController.text =
          user.phoneNumber ?? (data['phone'] as String?) ?? '';

      _avatarUrl = (data['avatarUrl'] as String?) ?? user.photoURL ?? '';
    } catch (error) {
      _showMessage('Không tải được hồ sơ: $error');
    } finally {
      if (mounted) {
        setState(() => _initializing = false);
      }
    }
  }

  // ==========================================
  // CHỌN ẢNH
  // ==========================================

  Future<void> _pickImage() async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 75,
        maxWidth: 800,
        maxHeight: 800,
      );

      if (image == null) return;

      // Chỉ chấp nhận định dạng được Storage Rules
      // cho phép trước khi lưu.
      _imageContentType(image);

      final bytes = await image.readAsBytes();

      if (bytes.length >= 5 * 1024 * 1024) {
        _showMessage('Ảnh phải nhỏ hơn 5 MB.');
        return;
      }

      if (!mounted) return;

      setState(() {
        _selectedImage = image;
        _imageBytes = bytes;
      });
    } catch (error) {
      _showMessage('Không chọn được ảnh: $error');
    }
  }

  // ==========================================
  // KIỂM TRA ĐỊNH DẠNG
  // ==========================================

  String _imageContentType(XFile image) {
    final mime = image.mimeType?.toLowerCase();

    if (mime == 'image/jpeg' || mime == 'image/png' || mime == 'image/webp') {
      return mime!;
    }

    final name = image.name.toLowerCase();

    if (name.endsWith('.jpg') || name.endsWith('.jpeg')) {
      return 'image/jpeg';
    }

    if (name.endsWith('.png')) {
      return 'image/png';
    }

    if (name.endsWith('.webp')) {
      return 'image/webp';
    }

    throw UnsupportedError('Chỉ hỗ trợ ảnh JPG, PNG hoặc WebP.');
  }

  // ==========================================
  // TẢI ẢNH LÊN STORAGE
  // ==========================================

  Future<String> _uploadAvatar(String uid) async {
    if (_selectedImage == null || _imageBytes == null) {
      return _avatarUrl;
    }

    final contentType = _imageContentType(_selectedImage!);

    String extension = 'jpg';

    if (contentType == 'image/png') {
      extension = 'png';
    } else if (contentType == 'image/webp') {
      extension = 'webp';
    }

    final ref = FirebaseStorage.instance.ref().child(
      'avatars/$uid/profile.$extension',
    );

    await ref.putData(_imageBytes!, SettableMetadata(contentType: contentType));

    return ref.getDownloadURL();
  }

  // ==========================================
  // LƯU THÔNG TIN
  // ==========================================

  Future<void> _saveProfile() async {
    if (_loading || !_formKey.currentState!.validate()) {
      return;
    }

    final user = _user;

    if (user == null) {
      _showMessage('Bạn chưa đăng nhập.');
      return;
    }

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();

    setState(() => _loading = true);

    try {
      final oldEmail = user.email ?? '';

      final emailChanged = oldEmail.isNotEmpty && email != oldEmail;

      // ĐỔI EMAIL:
      // Firebase gửi email xác minh trước khi đổi.
      if (emailChanged) {
        await user.verifyBeforeUpdateEmail(email);
      }

      // UPLOAD AVATAR
      final avatarUrl = await _uploadAvatar(user.uid);

      // CẬP NHẬT FIREBASE AUTH
      await user.updateDisplayName(name);

      if (avatarUrl.isNotEmpty) {
        await user.updatePhotoURL(avatarUrl);
      }

      // CẬP NHẬT FIRESTORE
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'id': user.uid,
        'name': name,
        'avatarUrl': avatarUrl,
      }, SetOptions(merge: true));

      if (!mounted) return;

      _showMessage(
        emailChanged
            ? 'Đã lưu hồ sơ. '
                  'Hãy xác minh Email mới trong hộp thư.'
            : 'Cập nhật hồ sơ thành công!',
      );

      context.pop();
    } on FirebaseAuthException catch (error) {
      _showMessage(_authService.getErrorMessage(error));
    } catch (error) {
      _showMessage('Không thể lưu hồ sơ: $error');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  // ==========================================
  // INPUT DECORATION THEME
  // ==========================================

  InputDecoration _decoration(
    BuildContext context,
    String label,
    IconData icon, {
    Widget? suffixIcon,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: scheme.primary),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: scheme.surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    );
  }

  // ==========================================
  // GIAO DIỆN
  // ==========================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    ImageProvider<Object>? avatarImage;

    if (_imageBytes != null) {
      avatarImage = MemoryImage(_imageBytes!);
    } else if (_avatarUrl.isNotEmpty) {
      avatarImage = NetworkImage(_avatarUrl);
    }

    final hasEmail = _user?.email?.isNotEmpty ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Chỉnh sửa hồ sơ'), centerTitle: true),
      body: _initializing
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 430),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ẢNH ĐẠI DIỆN
                          Center(
                            child: GestureDetector(
                              onTap: _loading ? null : _pickImage,
                              child: Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 52,
                                    backgroundColor:
                                        scheme.surfaceContainerHighest,
                                    backgroundImage: avatarImage,
                                    child: avatarImage == null
                                        ? Icon(
                                            Icons.person,
                                            size: 60,
                                            color: scheme.primary,
                                          )
                                        : null,
                                  ),

                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: CircleAvatar(
                                      radius: 17,
                                      backgroundColor: scheme.primary,
                                      child: Icon(
                                        Icons.camera_alt,
                                        size: 18,
                                        color: scheme.onPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          Text(
                            'Nhấn vào ảnh để thay đổi',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),

                          const SizedBox(height: 30),

                          // HỌ VÀ TÊN
                          TextFormField(
                            controller: _nameController,
                            enabled: !_loading,
                            decoration: _decoration(
                              context,
                              'Họ và tên',
                              Icons.person_outline,
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Vui lòng nhập họ tên.';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 16),

                          // EMAIL
                          TextFormField(
                            controller: _emailController,
                            enabled: !_loading && hasEmail,
                            keyboardType: TextInputType.emailAddress,
                            decoration: _decoration(
                              context,
                              'Email',
                              Icons.email_outlined,
                            ),
                            validator: (value) {
                              if (!hasEmail) return null;

                              if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                  .hasMatch(value?.trim() ?? '')) {
                                return 'Email không hợp lệ.';
                              }

                              return null;
                            },
                          ),

                          if (!hasEmail) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Tài khoản Phone chưa có Email. '
                              'Cần liên kết Email/Password riêng.',
                              style: TextStyle(
                                fontSize: 12,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],

                          const SizedBox(height: 16),

                          // SỐ ĐIỆN THOẠI
                          TextFormField(
                            controller: _phoneController,
                            readOnly: true,
                            decoration: _decoration(
                              context,
                              'Số điện thoại',
                              Icons.phone_outlined,
                              suffixIcon: IconButton(
                                tooltip: 'Xác minh số điện thoại',
                                onPressed: _loading
                                    ? null
                                    : () {
                                        context.push(
                                          '${AppRouter.phoneLogin}?mode=link',
                                        );
                                      },
                                icon: const Icon(Icons.verified_user_outlined),
                              ),
                            ),
                          ),

                          const SizedBox(height: 10),

                          Text(
                            'Thay đổi số điện thoại cần '
                            'xác minh bằng OTP.',
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),

                          const SizedBox(height: 30),

                          // NÚT LƯU
                          SizedBox(
                            height: 52,
                            child: FilledButton(
                              onPressed: _loading ? null : _saveProfile,
                              child: _loading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Lưu thay đổi'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
