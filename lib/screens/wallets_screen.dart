import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/finance_ui.dart';

class WalletsScreen extends StatefulWidget {
  const WalletsScreen({super.key});

  @override
  State<WalletsScreen> createState() => _WalletsScreenState();
}

class _WalletsScreenState extends State<WalletsScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  bool _busy = false;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference<Map<String, dynamic>>? get _walletsRef {
    final uid = _uid;

    if (uid == null) return null;

    return _db.collection('users').doc(uid).collection('wallets');
  }

  // ==========================================
  // 1. HÀM HỖ TRỢ
  // ==========================================

  int _amount(dynamic value) {
    if (value is num) return value.toInt();

    return int.tryParse(value?.toString().replaceAll('.', '') ?? '') ?? 0;
  }

  String _walletTypeName(String type) {
    switch (type) {
      case 'cash':
        return 'Tiền mặt';
      case 'bank':
        return 'Ngân hàng';
      case 'ewallet':
        return 'Ví điện tử';
      default:
        return 'Ví khác';
    }
  }

  IconData _walletIcon(String type) {
    switch (type) {
      case 'cash':
        return Icons.payments_outlined;
      case 'bank':
        return Icons.account_balance_outlined;
      case 'ewallet':
        return Icons.phone_android_outlined;
      default:
        return Icons.account_balance_wallet_outlined;
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  // ==========================================
  // 2. FORM THÊM / SỬA VÍ
  // ==========================================

  Future<Map<String, String>?> _showWalletDialog({
    String? initialName,
    String? initialType,
  }) async {
    String name = initialName ?? '';
    String type = initialType ?? 'cash';

    const validTypes = ['cash', 'bank', 'ewallet', 'other'];

    if (!validTypes.contains(type)) {
      type = 'other';
    }

    final formKey = GlobalKey<FormState>();

    return showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(initialName == null ? 'Thêm ví mới' : 'Chỉnh sửa ví'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: name,
                  autofocus: true,
                  maxLength: 50,
                  decoration: const InputDecoration(
                    labelText: 'Tên ví',
                    hintText: 'Ví dụ: MB Bank',
                    prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Vui lòng nhập tên ví';
                    }
                    return null;
                  },
                  onChanged: (value) {
                    name = value;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Loại ví',
                    prefixIcon: Icon(Icons.category_outlined),
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('Tiền mặt')),
                    DropdownMenuItem(value: 'bank', child: Text('Ngân hàng')),
                    DropdownMenuItem(
                      value: 'ewallet',
                      child: Text('Ví điện tử'),
                    ),
                    DropdownMenuItem(value: 'other', child: Text('Ví khác')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      type = value;
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () {
                if (!(formKey.currentState?.validate() ?? false)) {
                  return;
                }

                Navigator.of(dialogContext)
                    .pop({'name': name.trim(), 'type': type});
              },
              child: const Text('Lưu'),
            ),
          ],
        );
      },
    );
  }

  // ==========================================
  // 3. THÊM VÍ MỚI
  // ==========================================

  Future<void> _addWallet() async {
    if (_busy || _uid == null) return;

    final result = await _showWalletDialog();

    if (result == null || !mounted) return;

    setState(() {
      _busy = true;
    });

    try {
      final walletsRef = _walletsRef!;
      final uid = _uid!;

      final existing = await walletsRef.get();

      final walletRef = walletsRef.doc();

      await walletRef.set({
        'id': walletRef.id,
        'userId': uid,
        'name': result['name'],
        'type': result['type'],
        'balance': 0,
        'isDefault': existing.docs.isEmpty,
        'createdAt': Timestamp.fromDate(DateTime.now()),
      });

      _showMessage('Đã tạo ví mới thành công.');
    } on FirebaseException catch (error) {
      _showMessage('Không thể tạo ví: ${error.message ?? error.code}');
    } catch (error) {
      _showMessage('Không thể tạo ví: $error');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  // ==========================================
  // 4. CHỈNH SỬA TÊN VÀ LOẠI VÍ
  // ==========================================

  Future<void> _editWallet(
    QueryDocumentSnapshot<Map<String, dynamic>> wallet,
  ) async {
    if (_busy) return;

    final data = wallet.data();

    final result = await _showWalletDialog(
      initialName: data['name']?.toString() ?? '',
      initialType: data['type']?.toString() ?? 'cash',
    );

    if (result == null || !mounted) return;

    setState(() {
      _busy = true;
    });

    try {
      await wallet.reference.update({
        'name': result['name'],
        'type': result['type'],
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _showMessage('Đã cập nhật thông tin ví.');
    } catch (error) {
      _showMessage('Không thể sửa ví: $error');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  // ==========================================
  // 5. ĐẶT VÍ MẶC ĐỊNH
  // ==========================================

  Future<void> _setDefaultWallet(String walletId) async {
    if (_busy || _uid == null) return;

    setState(() {
      _busy = true;
    });

    try {
      final walletsRef = _walletsRef!;

      // Lấy danh sách ví thuộc tài khoản.
      final query = await walletsRef.get();

      if (!query.docs.any((doc) => doc.id == walletId)) {
        throw StateError('Ví không tồn tại.');
      }

      // Cập nhật đồng bộ cờ isDefault.
      await _db.runTransaction((tx) async {
        final snapshots = <DocumentSnapshot<Map<String, dynamic>>>[];

        // Đọc tất cả trước khi ghi.
        for (final doc in query.docs) {
          snapshots.add(await tx.get(walletsRef.doc(doc.id)));
        }

        for (final snapshot in snapshots) {
          if (!snapshot.exists) continue;

          tx.update(snapshot.reference, {'isDefault': snapshot.id == walletId});
        }
      });

      _showMessage('Đã đặt ví mặc định.');
    } catch (error) {
      _showMessage('Không thể đặt ví mặc định: $error');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  // ==========================================
  // 6. MENU QUẢN LÝ TỪNG VÍ
  // ==========================================

  Future<void> _showWalletOptions(
    QueryDocumentSnapshot<Map<String, dynamic>> wallet,
  ) async {
    if (_busy) return;

    final isDefault = wallet.data()['isDefault'] == true;

    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Quản lý ví',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Chỉnh sửa ví'),
                  onTap: () {
                    Navigator.pop(sheetContext, 'edit');
                  },
                ),
                if (!isDefault)
                  ListTile(
                    leading: const Icon(Icons.star_outline),
                    title: const Text('Đặt làm ví mặc định'),
                    onTap: () {
                      Navigator.pop(sheetContext, 'default');
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.close),
                  title: const Text('Đóng'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted) return;

    if (action == 'edit') {
      await _editWallet(wallet);
    } else if (action == 'default') {
      await _setDefaultWallet(wallet.id);
    }
  }

  // ==========================================
  // 7. THẺ TỔNG SỐ DƯ
  // ==========================================

  Widget _balanceCard(int total) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.account_balance_wallet,
            color: Colors.white,
            size: 42,
          ),
          const SizedBox(height: 12),
          const Text('Tổng số dư', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              formatVnd(total),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 8. THẺ TỪNG VÍ
  // ==========================================

  Widget _walletTile(QueryDocumentSnapshot<Map<String, dynamic>> wallet) {
    final data = wallet.data();

    final name = data['name']?.toString() ?? 'Ví';
    final type = data['type']?.toString() ?? 'other';
    final balance = _amount(data['balance']);
    final isDefault = data['isDefault'] == true;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: _busy ? null : () => _showWalletOptions(wallet),
        child: FinanceCard(
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: const Color(0xFFE7F2FF),
                child: Icon(_walletIcon(type), color: AppColors.primaryDark),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      isDefault ? 'Ví mặc định' : _walletTypeName(type),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  formatVnd(balance),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.more_vert, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 9. MÀN HÌNH QUẢN LÝ VÍ
  // ==========================================

  @override
  Widget build(BuildContext context) {
    final walletsRef = _walletsRef;

    if (walletsRef == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Quản lý ví')),
        body: const Center(child: Text('Vui lòng đăng nhập.')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Quản lý ví')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: walletsRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Không tải được danh sách ví:\n'
                  '${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final wallets = snapshot.data!.docs.toList();

          // Ví mặc định lên đầu, sau đó theo tên.
          wallets.sort((a, b) {
            final aDefault = a.data()['isDefault'] == true;
            final bDefault = b.data()['isDefault'] == true;

            if (aDefault != bDefault) {
              return aDefault ? -1 : 1;
            }

            final aName = a.data()['name']?.toString() ?? '';
            final bName = b.data()['name']?.toString() ?? '';

            return aName.compareTo(bName);
          });

          final total = wallets.fold<int>(
            0,
            (totalAmount, wallet) =>
                totalAmount + _amount(wallet.data()['balance']),
          );

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _balanceCard(total),

              const SizedBox(height: 24),

              const FinanceTitle('Ví của bạn'),

              const SizedBox(height: 12),

              if (wallets.isEmpty)
                const FinanceCard(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(
                      child: Text(
                        'Bạn chưa có ví nào. '
                        'Hãy tạo ví đầu tiên.',
                      ),
                    ),
                  ),
                ),

              ...wallets.map(_walletTile),

              const SizedBox(height: 20),

              SizedBox(
                height: 50,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _addWallet,
                  icon: const Icon(Icons.add),
                  label: Text(_busy ? 'Đang xử lý...' : 'Thêm ví mới'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
