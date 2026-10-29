import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../app/app_router.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav.dart';

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController _amountController = TextEditingController();

  final TextEditingController _noteController = TextEditingController();

  String _type = 'expense';
  String? _selectedCategoryId;
  String? _selectedWalletId;

  DateTime _selectedDate = DateTime.now();

  bool _loading = true;
  bool _saving = false;

  String? _loadError;

  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _wallets = [];

  User? get _user => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  // =========================================
  // 1. HỖ TRỢ CHUYỂN ĐỔI DỮ LIỆU
  // =========================================

  int _readAmount(dynamic value) {
    if (value is num) {
      return value.toInt();
    }

    if (value is String) {
      return int.tryParse(value) ?? 0;
    }

    return 0;
  }

  String _formatMoney(int amount) {
    final negative = amount < 0;
    final text = amount.abs().toString();

    final buffer = StringBuffer();

    for (int i = 0; i < text.length; i++) {
      if (i > 0 && (text.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(text[i]);
    }

    return '${negative ? '-' : ''}${buffer.toString()} đ';
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  // =========================================
  // 2. LẤY DANH MỤC VÀ VÍ TỪ FIRESTORE
  // =========================================

  Future<void> _loadData() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      final user = _user;

      if (user == null) {
        throw StateError('Bạn chưa đăng nhập.');
      }

      // Tạo ví và danh mục mặc định nếu chưa có.
      // DefaultDataService phải bảo vệ dữ liệu đã tồn tại.
      await AuthService().retryDefaultData();

      final userRef = _firestore.collection('users').doc(user.uid);

      final results = await Future.wait([
        userRef.collection('categories').get(),
        userRef.collection('wallets').get(),
      ]);

      final categorySnapshot = results[0];
      final walletSnapshot = results[1];

      final categories = categorySnapshot.docs.map((doc) {
        return <String, dynamic>{...doc.data(), 'id': doc.id};
      }).toList();

      final wallets = walletSnapshot.docs.map((doc) {
        return <String, dynamic>{...doc.data(), 'id': doc.id};
      }).toList();

      if (!mounted) return;

      setState(() {
        _categories = categories;
        _wallets = wallets;

        final walletExists = _wallets.any(
          (wallet) => wallet['id'] == _selectedWalletId,
        );

        if (!walletExists) {
          final defaults = _wallets.where(
            (wallet) => wallet['isDefault'] == true,
          );

          _selectedWalletId = defaults.isNotEmpty
              ? defaults.first['id'] as String
              : (_wallets.isNotEmpty ? _wallets.first['id'] as String : null);
        }

        _updateSelectedCategory();
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loadError = error.toString();
        _loading = false;
      });

      debugPrint('[ADD_TRANSACTION] Load error: $error');
    }
  }

  List<Map<String, dynamic>> get _filteredCategories {
    return _categories.where((category) {
      return category['type'] == _type;
    }).toList();
  }

  void _updateSelectedCategory() {
    final available = _filteredCategories;

    if (available.isEmpty) {
      _selectedCategoryId = null;
      return;
    }

    final exists = available.any(
      (category) => category['id'] == _selectedCategoryId,
    );

    if (!exists) {
      _selectedCategoryId = available.first['id'] as String;
    }
  }

  void _changeType(String type) {
    if (_saving) return;

    setState(() {
      _type = type;
      _selectedCategoryId = null;
      _updateSelectedCategory();
    });
  }

  // =========================================
  // 3. CHỌN NGÀY
  // =========================================

  Future<void> _pickDate() async {
    if (_saving) return;

    final result = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Chọn ngày giao dịch',
      cancelText: 'Hủy',
      confirmText: 'Chọn',
    );

    if (result != null && mounted) {
      setState(() {
        _selectedDate = result;
      });
    }
  }

  // =========================================
  // 4. LƯU GIAO DỊCH VÀ CẬP NHẬT SỐ DƯ
  // =========================================

  Future<void> _saveTransaction() async {
    if (_saving || _loading) return;

    final user = _user;

    if (user == null) {
      _showMessage('Bạn cần đăng nhập trước.');
      return;
    }

    final rawAmount = _amountController.text
        .trim()
        .replaceAll('.', '')
        .replaceAll(',', '')
        .replaceAll(' ', '');

    final amount = int.tryParse(rawAmount);

    if (amount == null || amount <= 0) {
      _showMessage('Vui lòng nhập số tiền lớn hơn 0.');
      return;
    }

    if (_selectedCategoryId == null) {
      _showMessage('Vui lòng chọn danh mục.');
      return;
    }

    if (_selectedWalletId == null) {
      _showMessage('Vui lòng chọn ví.');
      return;
    }

    final selectedCategory = _filteredCategories.where(
      (category) => category['id'] == _selectedCategoryId,
    );

    final selectedWallet = _wallets.where(
      (wallet) => wallet['id'] == _selectedWalletId,
    );

    if (selectedCategory.isEmpty || selectedWallet.isEmpty) {
      _showMessage('Danh mục hoặc ví không hợp lệ.');
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final userRef = _firestore.collection('users').doc(user.uid);

      final walletRef = userRef.collection('wallets').doc(_selectedWalletId!);

      final transactionRef = userRef.collection('transactions').doc();

      final categoryId = _selectedCategoryId!;
      final categoryName = selectedCategory.first['name']?.toString() ?? 'Khác';

      final walletId = _selectedWalletId!;
      final note = _noteController.text.trim();

      final delta = _type == 'income' ? amount : -amount;

      // Firestore Transaction:
      // Tạo giao dịch và thay đổi số dư cùng lúc.
      await _firestore.runTransaction((transaction) async {
        final walletSnapshot = await transaction.get(walletRef);

        if (!walletSnapshot.exists) {
          throw StateError('Ví không tồn tại. Vui lòng tải lại dữ liệu.');
        }

        final walletData = walletSnapshot.data();

        if (walletData == null || walletData['userId'] != user.uid) {
          throw StateError('Không thể xác minh ví của tài khoản.');
        }

        final oldBalance = _readAmount(walletData['balance']);

        final newBalance = oldBalance + delta;

        transaction.set(transactionRef, {
          'id': transactionRef.id,
          'userId': user.uid,
          'type': _type,
          'amount': amount,
          'categoryId': categoryId,
          'categoryName': categoryName,
          'walletId': walletId,
          'note': note,
          'date': Timestamp.fromDate(_selectedDate),
          'createdAt': FieldValue.serverTimestamp(),
        });

        transaction.update(walletRef, {'balance': newBalance});
      });

      debugPrint(
        '[ADD_TRANSACTION] Saved: '
        '${transactionRef.id}, amount=$amount, type=$_type',
      );

      if (!mounted) return;

      _showMessage('Đã lưu giao dịch thành công!');

      // Về Home để xem số dư đã thay đổi.
      context.go(AppRouter.home);
    } on FirebaseException catch (error) {
      debugPrint(
        '[ADD_TRANSACTION] Firebase error: '
        '${error.code} - ${error.message}',
      );

      if (!mounted) return;

      if (error.code == 'permission-denied') {
        _showMessage(
          'Firestore từ chối quyền ghi. '
          'Vui lòng kiểm tra Rules.',
        );
      } else {
        _showMessage(
          'Không lưu được giao dịch: ${error.message ?? error.code}',
        );
      }
    } catch (error) {
      debugPrint('[ADD_TRANSACTION] Save error: $error');

      _showMessage('Không thể lưu giao dịch: $error');
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  // =========================================
  // 5. NÚT CHỌN THU / CHI
  // =========================================

  Widget _typeChip({required String text, required String type}) {
    final active = _type == type;

    return InkWell(
      onTap: _saving ? null : () => _changeType(type),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 46,
        decoration: BoxDecoration(
          color: active ? AppColors.primary : AppColors.bg,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: TextStyle(
            color: active ? Colors.white : AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  // =========================================
  // 6. GIAO DIỆN NHẬP LIỆU
  // =========================================

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: AppColors.primary),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );
  }

  Widget _buildForm() {
    final categories = _filteredCategories;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // CHỌN THU NHẬP HOẶC CHI TIÊU
          Row(
            children: [
              Expanded(
                child: _typeChip(text: 'Chi tiêu', type: 'expense'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _typeChip(text: 'Thu nhập', type: 'income'),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // SỐ TIỀN
          TextField(
            controller: _amountController,
            enabled: !_saving,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: _inputDecoration(
              hint: 'Số tiền (VNĐ)',
              icon: Icons.payments_outlined,
            ),
          ),

          const SizedBox(height: 14),

          // GHI CHÚ
          TextField(
            controller: _noteController,
            enabled: !_saving,
            maxLines: 2,
            minLines: 1,
            decoration: _inputDecoration(
              hint: 'Ghi chú',
              icon: Icons.edit_note,
            ),
          ),

          const SizedBox(height: 14),

          // DANH MỤC
          DropdownButtonFormField<String>(
            key: ValueKey('category_$_type'),
            initialValue: _selectedCategoryId,
            isExpanded: true,
            decoration: _inputDecoration(
              hint: 'Danh mục',
              icon: Icons.category_outlined,
            ),
            items: categories.map((category) {
              return DropdownMenuItem<String>(
                value: category['id'] as String,
                child: Text(
                  category['name']?.toString() ?? 'Danh mục',
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: _saving
                ? null
                : (value) {
                    setState(() {
                      _selectedCategoryId = value;
                    });
                  },
          ),

          if (categories.isEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              'Chưa có danh mục cho loại giao dịch này.',
              style: TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ],

          const SizedBox(height: 14),

          // VÍ
          DropdownButtonFormField<String>(
            initialValue: _selectedWalletId,
            isExpanded: true,
            decoration: _inputDecoration(
              hint: 'Chọn ví',
              icon: Icons.account_balance_wallet_outlined,
            ),
            items: _wallets.map((wallet) {
              final balance = _readAmount(wallet['balance']);

              final name = wallet['name']?.toString() ?? 'Ví';

              return DropdownMenuItem<String>(
                value: wallet['id'] as String,
                child: Text(
                  '$name (${_formatMoney(balance)})',
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: _saving
                ? null
                : (value) {
                    setState(() {
                      _selectedWalletId = value;
                    });
                  },
          ),

          const SizedBox(height: 14),

          // NGÀY GIAO DỊCH
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(14),
            child: InputDecorator(
              decoration: _inputDecoration(
                hint: 'Ngày',
                icon: Icons.calendar_today_outlined,
              ),
              child: Text(
                _formatDate(_selectedDate),
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),

          const SizedBox(height: 22),

          // NÚT LƯU
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _saving ? null : _saveTransaction,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Lưu giao dịch',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================
  // 7. GIAO DIỆN CHÍNH
  // =========================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,

      appBar: AppBar(title: const Text('Thêm giao dịch')),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          child: _loading
              ? const Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: Center(child: CircularProgressIndicator()),
                )
              : _loadError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.redAccent,
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Không tải được dữ liệu',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(_loadError!, textAlign: TextAlign.center),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _loadData,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  ),
                )
              : _buildForm(),
        ),
      ),

      bottomNavigationBar: AppBottomNav(
        currentIndex: 1,
        onTap: (index) {
          if (_saving) return;

          if (index == 0) {
            context.go(AppRouter.home);
          }

          if (index == 1) {
            context.go(AppRouter.addExpense);
          }

          if (index == 2) {
            context.go(AppRouter.notifications);
          }

          if (index == 3) {
            context.go(AppRouter.profile);
          }
        },
      ),
    );
  }
}
