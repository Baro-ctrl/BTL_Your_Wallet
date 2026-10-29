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

  String _dateText(DateTime date) {
    if (date.millisecondsSinceEpoch == 0) {
      return 'Chưa có ngày';
    }

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  Widget _filterButton(String text, String value) {
    final selected = filter == value;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => filter = value),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
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
                radius: 24,
                backgroundColor: isIncome
                    ? const Color(0xFFDCFCE7)
                    : const Color(0xFFFFEDD5),
                child: Icon(
                  isIncome ? Icons.arrow_downward : Icons.arrow_upward,
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
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (note.isNotEmpty) ...[
                      const SizedBox(height: 4),
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
                    const SizedBox(height: 5),
                    Text(
                      _dateText(date),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  '${isIncome ? '+' : '-'}'
                  '${formatVnd(amount)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isIncome ? AppColors.income : AppColors.expense,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right),
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
                  'Không tải được giao dịch:\n'
                  '${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final transactions =
              snapshot.data!.docs.where((doc) {
                final data = doc.data();
                final date = _date(data['date']);

                final sameMonth =
                    date.year == selectedMonth.year &&
                    date.month == selectedMonth.month;

                return sameMonth && (filter == 'all' || data['type'] == filter);
              }).toList()..sort((a, b) {
                return _date(b.data()['date'])
                    .compareTo(_date(a.data()['date']));
              });

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              FinanceCard(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () => changeMonth(-1),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Text(
                      'Tháng ${selectedMonth.month}/'
                      '${selectedMonth.year}',
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
              const SizedBox(height: 16),
              Row(
                children: [
                  _filterButton('Tất cả', 'all'),
                  const SizedBox(width: 8),
                  _filterButton('Thu', 'income'),
                  const SizedBox(width: 8),
                  _filterButton('Chi', 'expense'),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                '${transactions.length} giao dịch',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
              const SizedBox(height: 12),
              if (transactions.isEmpty)
                const FinanceCard(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(
                      child: Text('Không có giao dịch trong tháng này'),
                    ),
                  ),
                ),
              ...transactions.map(_transactionTile),
            ],
          );
        },
      ),
    );
  }
}
