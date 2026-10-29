import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/finance_ui.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

// ============================================
// CẤU HÌNH BIỂU TƯỢNG VÀ MÀU SẮC
// ============================================

class _CategoryStyle {
  static const icons = <String, IconData>{
    'restaurant': Icons.restaurant,
    'local_cafe': Icons.local_cafe,
    'directions_car': Icons.directions_car,
    'shopping_bag': Icons.shopping_bag,
    'more_horiz': Icons.more_horiz,
    'payments': Icons.payments,
    'card_giftcard': Icons.card_giftcard,
    'account_balance_wallet': Icons.account_balance_wallet,
    'home': Icons.home_outlined,
    'school': Icons.school_outlined,
    'health_and_safety': Icons.health_and_safety,
    'sports_esports': Icons.sports_esports,
    'pets': Icons.pets,
    'flight': Icons.flight,
    'savings': Icons.savings,
    'work': Icons.work_outline,
  };

  static const colors = <int>[
    0xFFFF9800,
    0xFF2196F3,
    0xFF4CAF50,
    0xFF9C27B0,
    0xFF607D8B,
    0xFFE91E63,
    0xFF009688,
    0xFFFF5722,
    0xFF3F51B5,
    0xFF795548,
  ];

  static IconData icon(dynamic name) {
    return icons[name?.toString()] ?? Icons.category_outlined;
  }

  static Color color(dynamic value) {
    if (value is int) {
      return Color(value);
    }

    if (value is num) {
      return Color(value.toInt());
    }

    return const Color(0xFF2196F3);
  }
}

// ============================================
// MÀN HÌNH QUẢN LÝ DANH MỤC
// ============================================

class _CategoriesScreenState extends State<CategoriesScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String selectedType = 'expense';
  bool _busy = false;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference<Map<String, dynamic>>? get _categoriesRef {
    final uid = _uid;

    if (uid == null) return null;

    return _db.collection('users').doc(uid).collection('categories');
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  // ==========================================
  // 1. THÊM DANH MỤC
  // ==========================================

  Future<void> _addCategory() async {
    if (_busy || _uid == null) return;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return _CategoryEditDialog(type: selectedType);
      },
    );

    if (!mounted || result == null) return;

    setState(() {
      _busy = true;
    });

    try {
      final categoriesRef = _categoriesRef!;

      final categoryRef = categoriesRef.doc();

      await categoryRef.set({
        'id': categoryRef.id,
        'userId': _uid!,
        'name': result['name'],
        'type': result['type'],
        'icon': result['icon'],
        'color': result['color'],
        'isDefault': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _showMessage('Đã thêm danh mục thành công.');
    } on FirebaseException catch (error) {
      _showMessage(
        'Không thể thêm danh mục: '
        '${error.message ?? error.code}',
      );
    } catch (error) {
      _showMessage('Không thể thêm danh mục: $error');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  // ==========================================
  // 2. CHỈNH SỬA DANH MỤC
  // ==========================================

  Future<void> _editCategory(
    QueryDocumentSnapshot<Map<String, dynamic>> category,
  ) async {
    if (_busy) return;

    final data = category.data();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return _CategoryEditDialog(
          type: data['type']?.toString() ?? selectedType,
          original: data,
        );
      },
    );

    if (!mounted || result == null) return;

    setState(() {
      _busy = true;
    });

    try {
      // Không đổi ID, UID, loại hoặc trạng thái mặc định.
      await category.reference.update({
        'name': result['name'],
        'icon': result['icon'],
        'color': result['color'],
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _showMessage('Đã cập nhật danh mục.');
    } on FirebaseException catch (error) {
      _showMessage(
        'Không thể sửa danh mục: '
        '${error.message ?? error.code}',
      );
    } catch (error) {
      _showMessage('Không thể sửa danh mục: $error');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  // ==========================================
  // 3. TAB THU NHẬP / CHI TIÊU
  // ==========================================

  Widget _tab(String label, String type) {
    final selected = selectedType == type;

    return Expanded(
      child: InkWell(
        onTap: _busy
            ? null
            : () {
                setState(() {
                  selectedType = type;
                });
              },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.bg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: selected ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 4. THẺ DANH MỤC
  // ==========================================

  Widget _categoryTile(QueryDocumentSnapshot<Map<String, dynamic>> category) {
    final data = category.data();

    final name = data['name']?.toString() ?? 'Danh mục';

    final isDefault = data['isDefault'] == true;

    final icon = _CategoryStyle.icon(data['icon']);

    final color = _CategoryStyle.color(data['color']);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: _busy ? null : () => _editCategory(category),
        borderRadius: BorderRadius.circular(18),
        child: FinanceCard(
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.14),
                child: Icon(icon, color: color),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),

              if (isDefault)
                const Text(
                  'Mặc định',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),

              const SizedBox(width: 8),

              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 5. GIAO DIỆN CHÍNH
  // ==========================================

  @override
  Widget build(BuildContext context) {
    final categoriesRef = _categoriesRef;

    if (categoriesRef == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Quản lý danh mục')),
        body: const Center(child: Text('Vui lòng đăng nhập.')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bg,

      appBar: AppBar(title: const Text('Quản lý danh mục')),

      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: categoriesRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Không tải được danh mục:\n'
                  '${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final categories = snapshot.data!.docs.where((doc) {
            return doc.data()['type'] == selectedType;
          }).toList();

          // Danh mục mặc định lên đầu.
          categories.sort((a, b) {
            final aDefault = a.data()['isDefault'] == true;

            final bDefault = b.data()['isDefault'] == true;

            if (aDefault != bDefault) {
              return aDefault ? -1 : 1;
            }

            final aName = a.data()['name']?.toString().toLowerCase() ?? '';

            final bName = b.data()['name']?.toString().toLowerCase() ?? '';

            return aName.compareTo(bName);
          });

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              FinanceCard(
                child: Row(
                  children: [
                    _tab('Chi tiêu', 'expense'),
                    const SizedBox(width: 12),
                    _tab('Thu nhập', 'income'),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              const FinanceTitle('Danh sách danh mục'),

              const SizedBox(height: 12),

              if (categories.isEmpty)
                const FinanceCard(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: Text('Chưa có danh mục')),
                  ),
                ),

              ...categories.map(_categoryTile),

              const SizedBox(height: 18),

              SizedBox(
                height: 50,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _addCategory,
                  icon: const Icon(Icons.add),
                  label: Text(_busy ? 'Đang xử lý...' : 'Thêm danh mục'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ============================================
// 6. FORM THÊM / SỬA DANH MỤC
// ============================================

class _CategoryEditDialog extends StatefulWidget {
  final String type;
  final Map<String, dynamic>? original;

  const _CategoryEditDialog({required this.type, this.original});

  @override
  State<_CategoryEditDialog> createState() => _CategoryEditDialogState();
}

class _CategoryEditDialogState extends State<_CategoryEditDialog> {
  late final TextEditingController _nameController;

  late String _selectedIcon;
  late int _selectedColor;

  bool get _isEditing => widget.original != null;

  @override
  void initState() {
    super.initState();

    final original = widget.original;

    _nameController = TextEditingController(
      text: original?['name']?.toString() ?? '',
    );

    final originalIcon = original?['icon']?.toString();

    _selectedIcon = _CategoryStyle.icons.containsKey(originalIcon)
        ? originalIcon!
        : widget.type == 'income'
        ? 'payments'
        : 'restaurant';

    final originalColor = original?['color'];

    _selectedColor = originalColor is num
        ? originalColor.toInt()
        : widget.type == 'income'
        ? 0xFF4CAF50
        : 0xFFFF9800;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      _showError('Vui lòng nhập tên danh mục.');
      return;
    }

    if (name.length > 50) {
      _showError('Tên danh mục tối đa 50 ký tự.');
      return;
    }

    Navigator.of(context).pop({
      'name': name,
      'type': widget.type,
      'icon': _selectedIcon,
      'color': _selectedColor,
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),

      title: Text(_isEditing ? 'Chỉnh sửa danh mục' : 'Thêm danh mục'),

      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameController,
                autofocus: true,
                maxLength: 50,
                decoration: const InputDecoration(
                  labelText: 'Tên danh mục',
                  hintText: 'Ví dụ: Du lịch',
                  prefixIcon: Icon(Icons.edit_outlined),
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 12),

              const Text(
                'Chọn biểu tượng',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 12),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _CategoryStyle.icons.entries.map((entry) {
                  final selected = entry.key == _selectedIcon;

                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedIcon = entry.key;
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 45,
                      width: 45,
                      decoration: BoxDecoration(
                        color: selected ? AppColors.primary : AppColors.bg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected
                              ? AppColors.primary
                              : AppColors.border,
                        ),
                      ),
                      child: Icon(
                        entry.value,
                        color: selected ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 22),

              const Text(
                'Chọn màu sắc',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 12),

              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _CategoryStyle.colors.map((colorValue) {
                  final selected = colorValue == _selectedColor;

                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedColor = colorValue;
                      });
                    },
                    borderRadius: BorderRadius.circular(30),
                    child: Container(
                      height: 38,
                      width: 38,
                      decoration: BoxDecoration(
                        color: Color(colorValue),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected
                              ? AppColors.textPrimary
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: selected
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 22,
                            )
                          : null,
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 16),

              const Text(
                'Tên, biểu tượng và màu sắc '
                'sẽ hiển thị trong danh sách danh mục.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),

      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(_isEditing ? 'Lưu thay đổi' : 'Thêm danh mục'),
        ),
      ],
    );
  }
}
