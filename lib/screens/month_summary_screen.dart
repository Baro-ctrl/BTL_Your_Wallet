import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/app_router.dart';
import '../models/budget_model.dart';
import '../services/month_summary_logic.dart';
import '../theme/app_colors.dart';
import '../widgets/finance_ui.dart';

class MonthSummaryScreen extends StatefulWidget {
  const MonthSummaryScreen({super.key});

  @override
  State<MonthSummaryScreen> createState() => _MonthSummaryScreenState();
}

class _MonthSummaryScreenState extends State<MonthSummaryScreen> {
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  DocumentReference<Map<String, dynamic>>? get _userRef {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance.collection('users').doc(uid);
  }

  int _number(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  DateTime? _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  String get _monthlyGoalId {
    final month = _selectedMonth.month.toString().padLeft(2, '0');
    return '${_selectedMonth.year}_$month';
  }

  String get _monthLabel =>
      'Tháng ${_selectedMonth.month}/${_selectedMonth.year}';

  void _changeMonth(int offset) {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + offset,
      );
    });
  }

  List<BudgetModel> _toBudgets(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    String uid,
  ) {
    return docs.map((doc) {
      final data = doc.data();
      return BudgetModel(
        id: doc.id,
        userId: data['userId']?.toString() ?? uid,
        categoryId: data['categoryId']?.toString() ?? '',
        name: data['name']?.toString() ?? 'Danh mục',
        amount: _number(data['amount']),
        month: _number(data['month']),
        year: _number(data['year']),
        isActive: data['isActive'] != false,
        createdAt: _date(data['createdAt']) ?? DateTime(2000),
      );
    }).toList();
  }

  Map<String, int> _spentByCategory(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final result = <String, int>{};

    for (final doc in docs) {
      final data = doc.data();
      if (data['type'] != 'expense') continue;

      final date = _date(data['date']);
      if (date == null ||
          date.year != _selectedMonth.year ||
          date.month != _selectedMonth.month) {
        continue;
      }

      final categoryId = data['categoryId']?.toString() ?? '';
      if (categoryId.isEmpty) continue;

      result[categoryId] = (result[categoryId] ?? 0) + _number(data['amount']);
    }

    return result;
  }

  Map<String, String> _categoryNames(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> categoryDocs,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> transactionDocs,
  ) {
    final names = <String, String>{};

    for (final doc in categoryDocs) {
      names[doc.id] = doc.data()['name']?.toString() ?? 'Danh mục';
    }

    // Dùng tên được lưu kèm giao dịch nếu danh mục hiện không còn trong danh sách.
    for (final doc in transactionDocs) {
      final data = doc.data();
      final id = data['categoryId']?.toString() ?? '';
      final name = data['categoryName']?.toString().trim() ?? '';
      if (id.isNotEmpty && name.isNotEmpty) {
        names.putIfAbsent(id, () => name);
      }
    }

    return names;
  }

  Color _statusColor(BudgetStatus status) {
    switch (status) {
      case BudgetStatus.normal:
        return AppColors.income;
      case BudgetStatus.nearLimit:
        return const Color(0xFFFF9800);
      case BudgetStatus.exceeded:
        return AppColors.expense;
    }
  }

  Widget _statCard(String title, int amount, Color color) {
    return Expanded(
      child: FinanceCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            Text(
              formatVnd(amount),
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryContent(MonthSummary summary) {
    final positive = summary.difference >= 0;
    final differenceColor = positive ? AppColors.income : AppColors.expense;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => _changeMonth(-1),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                _monthLabel,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            IconButton(
              onPressed: () => _changeMonth(1),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          color: positive ? AppColors.income : AppColors.expense,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  positive ? 'Bạn đã tiết kiệm' : 'Bạn đã chi vượt mục tiêu',
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  formatVnd(summary.difference.abs()),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _statCard('Mục tiêu', summary.totalBudget, AppColors.primary),
            const SizedBox(width: 8),
            _statCard('Đã chi', summary.totalSpent, AppColors.expense),
            const SizedBox(width: 8),
            _statCard('Chênh lệch', summary.difference, differenceColor),
          ],
        ),
        const SizedBox(height: 24),
        const FinanceTitle('Chi tiêu theo danh mục'),
        const SizedBox(height: 12),
        if (summary.categories.isEmpty)
          const FinanceCard(child: Text('Tháng này chưa có hạn mức danh mục.'))
        else
          ...summary.categories.map((item) {
            final color = _statusColor(item.status);
            final percent = item.limit > 0
                ? (item.spent * 100 / item.limit).round()
                : 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: FinanceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Text(
                          '$percent%',
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: item.ratio,
                      color: color,
                      backgroundColor: AppColors.border,
                    ),
                    const SizedBox(height: 8),
                    Text('${formatVnd(item.spent)} / ${formatVnd(item.limit)}'),
                  ],
                ),
              ),
            );
          }),
        const SizedBox(height: 16),
        FinanceCard(
          child: Text(
            summary.topCategoryName == null
                ? 'Chưa có khoản chi trong tháng này.'
                : 'Mục chi nhiều nhất: ${summary.topCategoryName} '
                      '(${formatVnd(summary.topCategorySpent)})',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () {
            final nextMonth = DateTime(
              _selectedMonth.year,
              _selectedMonth.month + 1,
            );

            context.push(AppRouter.setBudget, extra: nextMonth);
          },
          icon: const Icon(Icons.flag_outlined),
          label: const Text('Đặt mục tiêu tháng sau'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final userRef = _userRef;

    if (userRef == null) {
      return const Scaffold(body: Center(child: Text('Vui lòng đăng nhập.')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Tổng kết tháng')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: userRef.collection('budgets').snapshots(),
        builder: (context, budgetSnapshot) {
          if (budgetSnapshot.hasError) {
            return const Center(child: Text('Không tải được ngân sách.'));
          }
          if (!budgetSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: userRef.collection('transactions').snapshots(),
            builder: (context, transactionSnapshot) {
              if (transactionSnapshot.hasError) {
                return const Center(child: Text('Không tải được giao dịch.'));
              }
              if (!transactionSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: userRef.collection('categories').snapshots(),
                builder: (context, categorySnapshot) {
                  if (categorySnapshot.hasError) {
                    return const Center(
                      child: Text('Không tải được danh mục.'),
                    );
                  }
                  if (!categorySnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final uid = FirebaseAuth.instance.currentUser!.uid;
                  final transactions = transactionSnapshot.data!.docs;
                  final spent = _spentByCategory(transactions);

                  return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: userRef
                        .collection('monthly_budget_totals')
                        .doc(_monthlyGoalId)
                        .snapshots(),
                    builder: (context, monthlyGoalSnapshot) {
                      if (monthlyGoalSnapshot.hasError) {
                        return Center(
                          child: Text(
                            'Không tải được mục tiêu tháng:\n${monthlyGoalSnapshot.error}',
                            textAlign: TextAlign.center,
                          ),
                        );
                      }

                      if (!monthlyGoalSnapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final monthlyGoal = _number(
                        monthlyGoalSnapshot.data!.data()?['amount'],
                      );

                      final summary = buildMonthSummary(
                        budgets: _toBudgets(budgetSnapshot.data!.docs, uid),
                        spentByCategoryId: spent,
                        categoryNames: _categoryNames(
                          categorySnapshot.data!.docs,
                          transactions,
                        ),
                        year: _selectedMonth.year,
                        month: _selectedMonth.month,
                        totalBudgetOverride: monthlyGoal > 0
                            ? monthlyGoal
                            : null,
                      );

                      return _summaryContent(summary);
                    },
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
