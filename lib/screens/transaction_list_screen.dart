import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/app_router.dart';
import '../theme/app_colors.dart';
import '../widgets/finance_ui.dart';

class TransactionListScreen extends StatefulWidget {
  const TransactionListScreen({super.key});

  @override
  State<TransactionListScreen> createState() => _TransactionListScreenState();
}

class _TransactionListScreenState extends State<TransactionListScreen> {
  String filter = 'all';
  String selectedCategoryFilter = 'all';

  DateTime selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  void changeMonth(int offset) {
    setState(() {
      selectedMonth = DateTime(
        selectedMonth.year,
        selectedMonth.month + offset,
      );
    });
  }

  int _amount(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString().replaceAll('.', '') ?? '') ?? 0;
  }

  DateTime _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _categoryName(Map<String, dynamic> data) {
    final name = data['categoryName']?.toString().trim() ?? '';

    if (name.isNotEmpty) return name;

    const names = <String, String>{
      'food': 'Ăn',
      'drink': 'Uống',
      'transport': 'Di chuyển',
      'shopping': 'Mua sắm',
      'other': 'Khác',
      'salary': 'Lương',
      'bonus': 'Thưởng',
      'other_income': 'Thu nhập khác',
    };

    return names[data['categoryId']] ?? 'Giao dịch';
  }

  String _dateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDay = DateTime(date.year, date.month, date.day);

    final dayStr = date.day.toString().padLeft(2, '0');
    final monthStr = date.month.toString().padLeft(2, '0');
    final formattedDate = '$dayStr/$monthStr/${date.year}';

    if (targetDay == today) {
      return 'Hôm nay, $formattedDate';
    } else if (targetDay == today.subtract(const Duration(days: 1))) {
      return 'Hôm qua, $formattedDate';
    }

    return formattedDate;
  }

  String _timeText(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Widget _filterButton(String text, String value) {
    final selected = filter == value;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => filter = value),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _transactionTile(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final isIncome = data['type'] == 'income';
    final amount = _amount(data['amount']);
    final date = _date(data['date']);
    final category = _categoryName(data);
    final note = data['note']?.toString().trim() ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          context.push(AppRouter.transactionDetailPath(doc.id));
        },
        child: FinanceCard(
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: isIncome
                    ? const Color(0xFFDCFCE7)
                    : const Color(0xFFFFEDD5),
                child: Icon(
                  isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                  size: 20,
                  color: isIncome ? AppColors.income : AppColors.expense,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    if (note.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        note,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      _timeText(date),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  '${isIncome ? '+' : '-'}${formatVnd(amount)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isIncome ? AppColors.income : AppColors.expense,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Lịch sử giao dịch')),
        body: const Center(child: Text('Vui lòng đăng nhập.')),
      );
    }

    final transactionsRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('transactions');

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Lịch sử giao dịch')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: transactionsRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Không tải được giao dịch:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          // Lọc theo tháng đang chọn
          final allDocs = snapshot.data!.docs;

          final monthDocs = allDocs.where((doc) {
            final date = _date(doc.data()['date']);
            return date.year == selectedMonth.year &&
                date.month == selectedMonth.month;
          }).toList();

          // Thu thập danh sách các danh mục có trong tháng này để tạo Filter Chips
          final categoriesSet = <String>{};
          for (final doc in monthDocs) {
            categoriesSet.add(_categoryName(doc.data()));
          }
          final availableCategories = categoriesSet.toList()..sort();

          // Áp dụng bộ lọc Thu/Chi và Bộ lọc Danh mục
          final filteredDocs = monthDocs.where((doc) {
            final data = doc.data();
            final matchesType = (filter == 'all' || data['type'] == filter);
            final catName = _categoryName(data);
            final matchesCategory = (selectedCategoryFilter == 'all' ||
                catName == selectedCategoryFilter);
            return matchesType && matchesCategory;
          }).toList()
            ..sort((a, b) => _date(b.data()['date']).compareTo(_date(a.data()['date'])));

          // Gom nhóm giao dịch theo ngày (YYYY-MM-DD)
          final groupedTransactions = <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
          for (final doc in filteredDocs) {
            final date = _date(doc.data()['date']);
            final dayKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
            groupedTransactions.putIfAbsent(dayKey, () => []).add(doc);
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // BỘ CHỌN THÁNG
              FinanceCard(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () => changeMonth(-1),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Text(
                      'Tháng ${selectedMonth.month}/${selectedMonth.year}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                    IconButton(
                      onPressed: () => changeMonth(1),
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // CHIP LỌC LOẠI (TẤT CẢ / THU / CHI)
              Row(
                children: [
                  _filterButton('Tất cả', 'all'),
                  const SizedBox(width: 8),
                  _filterButton('Thu', 'income'),
                  const SizedBox(width: 8),
                  _filterButton('Chi', 'expense'),
                ],
              ),
              const SizedBox(height: 12),

              // CHIP LỌC DANH MỤC (NẰM NGANG)
              if (availableCategories.isNotEmpty) ...[
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: const Text('Tất cả danh mục'),
                          selected: selectedCategoryFilter == 'all',
                          onSelected: (selected) {
                            if (selected) setState(() => selectedCategoryFilter = 'all');
                          },
                          selectedColor: AppColors.primary,
                          labelStyle: TextStyle(
                            color: selectedCategoryFilter == 'all'
                                ? Colors.white
                                : AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      ...availableCategories.map((catName) {
                        final isSelected = selectedCategoryFilter == catName;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(catName),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                selectedCategoryFilter = selected ? catName : 'all';
                              });
                            },
                            selectedColor: AppColors.primary,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // TỔNG SỐ GIAO DỊCH
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${filteredDocs.length} giao dịch',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  if (selectedCategoryFilter != 'all')
                    TextButton(
                      onPressed: () => setState(() => selectedCategoryFilter = 'all'),
                      child: const Text('Xóa lọc danh mục', style: TextStyle(fontSize: 12)),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              if (filteredDocs.isEmpty)
                const FinanceCard(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'Không có giao dịch trong tháng này',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                ),

              // GIAO DỊCH GOM NHÓM THEO NGÀY
              ...groupedTransactions.entries.map((entry) {
                final dayDocs = entry.value;
                final firstDate = _date(dayDocs.first.data()['date']);

                int dayIncome = 0;
                int dayExpense = 0;
                for (final doc in dayDocs) {
                  final data = doc.data();
                  final amount = _amount(data['amount']);
                  if (data['type'] == 'income') {
                    dayIncome += amount;
                  } else {
                    dayExpense += amount;
                  }
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // TIÊU ĐỀ NGÀY KÈM TỔNG TIỀN NGÀY
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      margin: const EdgeInsets.only(top: 8, bottom: 8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _dateHeader(firstDate),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: AppColors.primaryDark,
                            ),
                          ),
                          Row(
                            children: [
                              if (dayIncome > 0)
                                Text(
                                  '+${formatVnd(dayIncome)} ',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: AppColors.income,
                                  ),
                                ),
                              if (dayExpense > 0)
                                Text(
                                  '-${formatVnd(dayExpense)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: AppColors.expense,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    ...dayDocs.map(_transactionTile),
                  ],
                );
              }),
            ],
          );
        },
      ),
    );
  }
}
