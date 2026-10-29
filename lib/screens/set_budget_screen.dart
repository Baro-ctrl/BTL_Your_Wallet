import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../widgets/finance_ui.dart';

class SetBudgetScreen extends StatefulWidget {
  const SetBudgetScreen({super.key});

  @override
  State<SetBudgetScreen> createState() => _SetBudgetScreenState();
}

class _SetBudgetScreenState extends State<SetBudgetScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final TextEditingController _amountController = TextEditingController();

  String? _categoryId;

  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  bool _saving = false;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  DocumentReference<Map<String, dynamic>>? get _userRef {
    final uid = _uid;
    if (uid == null) return null;

    return _db.collection('users').doc(uid);
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  // ==========================================
  // 1. HÀM HỖ TRỢ
  // ==========================================

  int _toAmount(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();

    return int.tryParse(
          value?.toString().replaceAll('.', '').replaceAll(',', '').trim() ??
              '',
        ) ??
        0;
  }

  DateTime? _toDate(dynamic value) {
    if (value is Timestamp) return value.toDate();

    if (value is DateTime) return value;

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
  }

  String _monthText(DateTime date) {
    return 'Tháng ${date.month}/${date.year}';
  }

  String _budgetId(String categoryId) {
    final month = _selectedMonth.month.toString().padLeft(2, '0');

    return '${categoryId}_${_selectedMonth.year}_$month';
  }

  void _message(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  // ==========================================
  // 2. CHỌN THÁNG
  // ==========================================

  void _changeMonth(int offset) {
    if (_saving) return;

    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + offset,
      );
    });
  }

  Future<void> _pickMonth() async {
    if (_saving) return;

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Chọn tháng áp dụng',
    );

    if (picked == null || !mounted) return;

    setState(() {
      _selectedMonth = DateTime(picked.year, picked.month);
    });
  }

  // ==========================================
  // 3. LƯU NGÂN SÁCH
  // ==========================================

  Future<void> _saveBudget(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> categories,
  ) async {
    if (_saving) return;

    final uid = _uid;
    final userRef = _userRef;

    if (uid == null || userRef == null) {
      _message('Vui lòng đăng nhập.');
      return;
    }

    final categoryId = _categoryId;

    if (categoryId == null) {
      _message('Vui lòng chọn danh mục chi tiêu.');
      return;
    }

    final amount = int.tryParse(
      _amountController.text
          .trim()
          .replaceAll('.', '')
          .replaceAll(',', '')
          .replaceAll(' ', ''),
    );

    if (amount == null || amount <= 0) {
      _message('Giới hạn chi tiêu phải lớn hơn 0.');
      return;
    }

    final matchingCategories = categories.where(
      (doc) => doc.id == categoryId && doc.data()['type'] == 'expense',
    );

    if (matchingCategories.isEmpty) {
      _message('Danh mục không còn tồn tại.');
      return;
    }

    final categoryName =
        matchingCategories.first.data()['name']?.toString() ?? 'Danh mục';

    setState(() {
      _saving = true;
    });

    try {
      final id = _budgetId(categoryId);

      final budgetRef = userRef.collection('budgets').doc(id);

      // Đọc trước để phân biệt tạo mới và cập nhật.
      final existing = await budgetRef.get();

      if (existing.exists) {
        // Chỉ thay đổi hạn mức và tên hiển thị.
        // Không tự chỉnh số dư ví.
        await budgetRef.update({
          'name': categoryName,
          'amount': amount,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await budgetRef.set({
          'id': id,
          'userId': uid,
          'name': categoryName,
          'categoryId': categoryId,
          'amount': amount,
          'month': _selectedMonth.month,
          'year': _selectedMonth.year,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) return;

      _amountController.clear();

      _message(
        existing.exists
            ? 'Đã cập nhật ngân sách.'
            : 'Đã tạo ngân sách thành công.',
      );
    } on FirebaseException catch (error) {
      _message(
        'Không lưu được ngân sách: '
        '${error.message ?? error.code}',
      );
    } catch (error) {
      _message('Không lưu được ngân sách: $error');
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  // ==========================================
  // 4. CHỌN NGÂN SÁCH ĐỂ SỬA
  // ==========================================

  void _editBudget(QueryDocumentSnapshot<Map<String, dynamic>> budget) {
    final data = budget.data();

    final categoryId = data['categoryId']?.toString();

    if (categoryId == null || categoryId.isEmpty) {
      _message('Ngân sách cũ thiếu mã danh mục.');
      return;
    }

    setState(() {
      _selectedMonth = DateTime(
        _toAmount(data['year']),
        _toAmount(data['month']),
      );

      _categoryId = categoryId;

      _amountController.text = _toAmount(data['amount']).toString();
    });

    _message(
      'Đã điền thông tin. '
      'Bạn có thể sửa hạn mức rồi nhấn Lưu ngân sách.',
    );
  }

  // ==========================================
  // 5. TÍNH SỐ TIỀN ĐÃ CHI
  // ==========================================

  Map<String, int> _calculateSpending(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> transactions,
  ) {
    final spending = <String, int>{};

    for (final doc in transactions) {
      final data = doc.data();

      if (data['type'] != 'expense') {
        continue;
      }

      final date = _toDate(data['date']);

      if (date == null) continue;

      if (date.year != _selectedMonth.year ||
          date.month != _selectedMonth.month) {
        continue;
      }

      final categoryId = data['categoryId']?.toString();

      if (categoryId == null || categoryId.isEmpty) {
        continue;
      }

      final amount = _toAmount(data['amount']);

      spending[categoryId] = (spending[categoryId] ?? 0) + amount;
    }

    return spending;
  }

  // ==========================================
  // 6. THẺ GIỚI THIỆU
  // ==========================================

  Widget _headerCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Column(
        children: [
          Icon(Icons.savings, color: Colors.white, size: 48),
          SizedBox(height: 10),
          Text(
            'Kiểm soát chi tiêu',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Lập kế hoạch ngân sách hằng tháng',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 7. FORM THIẾT LẬP NGÂN SÁCH
  // ==========================================

  Widget _budgetForm(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> categories,
  ) {
    final availableCategories = categories
        .where((doc) => doc.data()['type'] == 'expense')
        .toList();

    // Chỉ đưa vào dropdown một ID đang tồn tại.
    final selectedValue =
        availableCategories.any((doc) => doc.id == _categoryId)
        ? _categoryId
        : null;

    return FinanceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Danh mục', style: TextStyle(fontWeight: FontWeight.w600)),

          const SizedBox(height: 8),

          DropdownButtonFormField<String>(
            key: ValueKey('budget_category_$selectedValue'),
            initialValue: selectedValue,
            isExpanded: true,
            hint: const Text('Chọn danh mục'),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.category_outlined),
              border: OutlineInputBorder(),
            ),
            items: availableCategories.map((category) {
              final data = category.data();

              return DropdownMenuItem<String>(
                value: category.id,
                child: Text(
                  data['name']?.toString() ?? 'Danh mục',
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: _saving
                ? null
                : (value) {
                    setState(() {
                      _categoryId = value;
                    });
                  },
          ),

          if (availableCategories.isEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              'Chưa có danh mục chi tiêu. '
              'Hãy tạo danh mục trước.',
              style: TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ],

          const SizedBox(height: 18),

          const Text(
            'Giới hạn chi tiêu',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),

          const SizedBox(height: 8),

          TextField(
            controller: _amountController,
            enabled: !_saving,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              hintText: 'Ví dụ: 2000000',
              suffixText: 'VNĐ',
              prefixIcon: Icon(Icons.payments_outlined),
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 18),

          const Text(
            'Tháng áp dụng',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),

          const SizedBox(height: 8),

          Row(
            children: [
              IconButton(
                onPressed: _saving ? null : () => _changeMonth(-1),
                icon: const Icon(Icons.chevron_left),
              ),

              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _saving ? null : _pickMonth,
                  icon: const Icon(Icons.calendar_month, size: 18),
                  label: Text(_monthText(_selectedMonth)),
                ),
              ),

              IconButton(
                onPressed: _saving ? null : () => _changeMonth(1),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),

          const SizedBox(height: 24),

          SizedBox(
            height: 50,
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _saving ? null : () => _saveBudget(categories),
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_saving ? 'Đang lưu...' : 'Lưu ngân sách'),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 8. THẺ TIẾN ĐỘ NGÂN SÁCH
  // ==========================================

  Widget _budgetTile(
    QueryDocumentSnapshot<Map<String, dynamic>> budget,
    int spent,
  ) {
    final data = budget.data();

    final limit = _toAmount(data['amount']);

    final categoryName = data['name']?.toString() ?? 'Danh mục';

    final ratio = limit > 0 ? spent / limit : 0.0;

    final progress = ratio.clamp(0.0, 1.0).toDouble();

    final percent = (ratio * 100).round();

    final remaining = limit - spent;

    final isOver = spent > limit;
    final isWarning = spent >= limit * 0.8 && !isOver;

    final Color progressColor;

    if (isOver) {
      progressColor = AppColors.expense;
    } else if (isWarning) {
      progressColor = const Color(0xFFFF9800);
    } else {
      progressColor = AppColors.primary;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: _saving ? null : () => _editBudget(budget),
        borderRadius: BorderRadius.circular(18),
        child: FinanceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Color(0xFFE7F2FF),
                    child: Icon(
                      Icons.savings_outlined,
                      color: AppColors.primaryDark,
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          categoryName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tháng ${data['month']}/'
                          '${data['year']}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Icon(
                    Icons.edit_outlined,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                ],
              ),

              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Đã chi',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    '$percent%',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: progressColor,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 6),

              Row(
                children: [
                  Expanded(
                    child: Text(
                      formatVnd(spent),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Flexible(
                    child: Text(
                      '/ ${formatVnd(limit)}',
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 10,
                  backgroundColor: const Color(0xFFE8EDF5),
                  valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                ),
              ),

              const SizedBox(height: 12),

              if (isOver)
                Text(
                  'Đã vượt ngân sách '
                  '${formatVnd(spent - limit)}',
                  style: const TextStyle(
                    color: AppColors.expense,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                )
              else if (isWarning)
                const Text(
                  'Cảnh báo: Đã sử dụng ít nhất '
                  '80% ngân sách.',
                  style: TextStyle(
                    color: Color(0xFFFF9800),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                )
              else
                Text(
                  'Còn lại ${formatVnd(remaining)}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 9. HIỂN THỊ DANH SÁCH NGÂN SÁCH
  // ==========================================

  Widget _budgetList(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> budgets,
    Map<String, int> spending,
  ) {
    final currentBudgets = budgets.where((doc) {
      final data = doc.data();

      return _toAmount(data['year']) == _selectedMonth.year &&
          _toAmount(data['month']) == _selectedMonth.month;
    }).toList();

    currentBudgets.sort((a, b) {
      final nameA = a.data()['name']?.toString() ?? '';

      final nameB = b.data()['name']?.toString() ?? '';

      return nameA.compareTo(nameB);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const FinanceTitle('Ngân sách đã đặt'),
            Text(
              _monthText(_selectedMonth),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        if (currentBudgets.isEmpty)
          const FinanceCard(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: Text('Chưa có ngân sách trong tháng này.')),
            ),
          ),

        ...currentBudgets.map((budget) {
          final categoryId = budget.data()['categoryId']?.toString() ?? '';

          final spent = spending[categoryId] ?? 0;

          return _budgetTile(budget, spent);
        }),
      ],
    );
  }

  // ==========================================
  // 10. GIAO DIỆN CHÍNH
  // ==========================================

  @override
  Widget build(BuildContext context) {
    final userRef = _userRef;

    if (userRef == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Đặt ngân sách')),
        body: const Center(child: Text('Vui lòng đăng nhập.')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bg,

      appBar: AppBar(title: const Text('Đặt ngân sách')),

      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: userRef.collection('categories').snapshots(),
        builder: (context, categorySnapshot) {
          if (categorySnapshot.hasError) {
            return Center(
              child: Text(
                'Lỗi tải danh mục: '
                '${categorySnapshot.error}',
              ),
            );
          }

          if (!categorySnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final categories = categorySnapshot.data!.docs;

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: userRef.collection('budgets').snapshots(),
            builder: (context, budgetSnapshot) {
              if (budgetSnapshot.hasError) {
                return Center(
                  child: Text(
                    'Lỗi tải ngân sách: '
                    '${budgetSnapshot.error}',
                  ),
                );
              }

              if (!budgetSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final budgets = budgetSnapshot.data!.docs;

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: userRef.collection('transactions').snapshots(),
                builder: (context, transactionSnapshot) {
                  if (transactionSnapshot.hasError) {
                    return Center(
                      child: Text(
                        'Lỗi tải giao dịch: '
                        '${transactionSnapshot.error}',
                      ),
                    );
                  }

                  if (!transactionSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final transactions = transactionSnapshot.data!.docs;

                  final spending = _calculateSpending(transactions);

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _headerCard(),

                        const SizedBox(height: 24),

                        const FinanceTitle('Thiết lập ngân sách'),

                        const SizedBox(height: 12),

                        _budgetForm(categories),

                        const SizedBox(height: 24),

                        _budgetList(budgets, spending),

                        const SizedBox(height: 24),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
