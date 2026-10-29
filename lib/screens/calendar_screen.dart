import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/app_router.dart';
import '../theme/app_colors.dart';
import '../widgets/finance_ui.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime selectedDate = DateTime.now();

  DateTime visibleMonth = DateTime(DateTime.now().year, DateTime.now().month);

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ==========================================
  // 1. HÀM HỖ TRỢ
  // ==========================================

  int _amount(dynamic value) {
    if (value is num) return value.toInt();

    return int.tryParse(value?.toString().replaceAll('.', '') ?? '') ?? 0;
  }

  DateTime? _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isToday(DateTime date) {
    return _sameDay(date, DateTime.now());
  }

  String _timeText(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  String _categoryName(Map<String, dynamic> data) {
    final saved = data['categoryName']?.toString().trim() ?? '';

    if (saved.isNotEmpty) return saved;

    const defaultNames = <String, String>{
      'food': 'Ăn',
      'drink': 'Uống',
      'transport': 'Di chuyển',
      'shopping': 'Mua sắm',
      'other': 'Khác',
      'salary': 'Lương',
      'bonus': 'Thưởng',
      'other_income': 'Thu nhập khác',
    };

    return defaultNames[data['categoryId']] ?? 'Giao dịch';
  }

  // ==========================================
  // 2. CHUYỂN THÁNG
  // ==========================================

  void _changeMonth(int offset) {
    setState(() {
      visibleMonth = DateTime(visibleMonth.year, visibleMonth.month + offset);

      selectedDate = DateTime(visibleMonth.year, visibleMonth.month, 1);
    });
  }

  // ==========================================
  // 3. LỌC GIAO DỊCH THEO NGÀY
  // ==========================================

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _transactionsOn(
    DateTime date,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> transactions,
  ) {
    final result = transactions.where((doc) {
      final transactionDate = _date(doc.data()['date']);

      return transactionDate != null && _sameDay(transactionDate, date);
    }).toList();

    result.sort((a, b) {
      final dateA = _date(a.data()['date'])!;
      final dateB = _date(b.data()['date'])!;

      return dateB.compareTo(dateA);
    });

    return result;
  }

  // ==========================================
  // 4. THẺ LỊCH THÁNG
  // ==========================================

  Widget _calendarCard(Map<int, int> transactionCounts) {
    final firstDay = DateTime(visibleMonth.year, visibleMonth.month, 1);

    final daysInMonth = DateTime(
      visibleMonth.year,
      visibleMonth.month + 1,
      0,
    ).day;

    // Thứ Hai = 0, Chủ nhật = 6.
    final startOffset = firstDay.weekday - 1;

    final cellCount = ((startOffset + daysInMonth + 6) ~/ 7) * 7;

    return FinanceCard(
      child: Column(
        children: [
          // CHỌN THÁNG
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () => _changeMonth(-1),
                icon: const Icon(Icons.chevron_left, size: 28),
              ),
              Text(
                'Tháng ${visibleMonth.month}/'
                '${visibleMonth.year}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              IconButton(
                onPressed: () => _changeMonth(1),
                icon: const Icon(Icons.chevron_right, size: 28),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // THỨ TRONG TUẦN
          Row(
            children: const ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'].map((
              day,
            ) {
              return Expanded(
                child: Center(
                  child: Text(
                    day,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 12),

          // LƯỚI NGÀY
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cellCount,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 4,
              childAspectRatio: 0.9,
            ),
            itemBuilder: (context, index) {
              final day = index - startOffset + 1;

              if (day < 1 || day > daysInMonth) {
                return const SizedBox.shrink();
              }

              final date = DateTime(visibleMonth.year, visibleMonth.month, day);

              final selected = _sameDay(date, selectedDate);
              final today = _isToday(date);

              final hasTransactions = (transactionCounts[day] ?? 0) > 0;

              return InkWell(
                onTap: () {
                  setState(() {
                    selectedDate = date;
                  });
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: today && !selected
                        ? Border.all(color: AppColors.primary, width: 1.5)
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$day',
                        style: TextStyle(
                          fontWeight: selected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: selected
                              ? Colors.white
                              : AppColors.textPrimary,
                        ),
                      ),

                      const SizedBox(height: 4),

                      if (hasTransactions)
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: selected ? Colors.white : AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 5. THẺ TỔNG THU / CHI TRONG NGÀY
  // ==========================================

  Widget _summaryCard({
    required String title,
    required int amount,
    required bool isIncome,
  }) {
    final color = isIncome ? AppColors.income : AppColors.expense;

    return FinanceCard(
      child: Column(
        children: [
          Icon(
            isIncome ? Icons.arrow_downward : Icons.arrow_upward,
            color: color,
          ),

          const SizedBox(height: 8),

          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),

          const SizedBox(height: 8),

          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                formatVnd(amount),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontSize: 17,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 6. THẺ GIAO DỊCH
  // ==========================================

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
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
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
                      date == null ? 'Chưa có giờ' : _timeText(date),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
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
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isIncome ? AppColors.income : AppColors.expense,
                  ),
                ),
              ),

              const SizedBox(width: 4),

              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 7. GIAO DIỆN LỊCH
  // ==========================================

  Widget _buildCalendar(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> transactions,
  ) {
    final selectedTransactions = _transactionsOn(selectedDate, transactions);

    final transactionCounts = <int, int>{};

    // Đánh dấu ngày có giao dịch trong tháng đang xem.
    for (final doc in transactions) {
      final date = _date(doc.data()['date']);

      if (date == null) continue;

      if (date.year != visibleMonth.year || date.month != visibleMonth.month) {
        continue;
      }

      transactionCounts[date.day] = (transactionCounts[date.day] ?? 0) + 1;
    }

    int totalIncome = 0;
    int totalExpense = 0;

    for (final doc in selectedTransactions) {
      final data = doc.data();
      final amount = _amount(data['amount']);

      if (data['type'] == 'income') {
        totalIncome += amount;
      } else if (data['type'] == 'expense') {
        totalExpense += amount;
      }
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _calendarCard(transactionCounts),

        const SizedBox(height: 24),

        FinanceTitle(
          'Ngày ${selectedDate.day}/'
          '${selectedDate.month}/'
          '${selectedDate.year}',
        ),

        const SizedBox(height: 14),

        Row(
          children: [
            Expanded(
              child: _summaryCard(
                title: 'Thu nhập',
                amount: totalIncome,
                isIncome: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _summaryCard(
                title: 'Chi tiêu',
                amount: totalExpense,
                isIncome: false,
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        const FinanceTitle('Giao dịch trong ngày'),

        const SizedBox(height: 12),

        if (selectedTransactions.isEmpty)
          const FinanceCard(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 42,
                    color: AppColors.textSecondary,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Chưa có giao dịch trong ngày',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),

        ...selectedTransactions.map(_transactionTile),
      ],
    );
  }

  // ==========================================
  // 8. KẾT NỐI FIRESTORE
  // ==========================================

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Lịch chi tiêu')),
        body: const Center(child: Text('Vui lòng đăng nhập.')),
      );
    }

    final transactionsRef = _db
        .collection('users')
        .doc(user.uid)
        .collection('transactions');

    return Scaffold(
      backgroundColor: AppColors.bg,

      appBar: AppBar(title: const Text('Lịch chi tiêu'), centerTitle: true),

      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: transactionsRef.snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Không tải được lịch giao dịch:\n'
                    '${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.expense),
                  ),
                ),
              );
            }

            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            return _buildCalendar(snapshot.data!.docs);
          },
        ),
      ),
    );
  }
}
