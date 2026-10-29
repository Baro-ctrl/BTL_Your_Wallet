import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/finance_ui.dart';

class StatisticScreen extends StatefulWidget {
  const StatisticScreen({super.key});

  @override
  State<StatisticScreen> createState() => _StatisticScreenState();
}

class _StatisticScreenState extends State<StatisticScreen> {
  DateTime selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const List<Color> chartColors = [
    Color(0xFF3B82F6),
    Color(0xFFFF9800),
    Color(0xFF4CAF50),
    Color(0xFF9C27B0),
    Color(0xFFE53935),
    Color(0xFF009688),
    Color(0xFFFFC107),
    Color(0xFF6366F1),
  ];

  // ==========================================
  // 1. HÀM HỖ TRỢ
  // ==========================================

  void changeMonth(int offset) {
    setState(() {
      selectedMonth = DateTime(
        selectedMonth.year,
        selectedMonth.month + offset,
      );
    });
  }

  int toAmount(dynamic value) {
    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString().replaceAll('.', '') ?? '') ?? 0;
  }

  DateTime? toDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
  }

  String categoryName(
    String id,
    Map<String, String> names,
    Map<String, String> savedNames,
  ) {
    final saved = savedNames[id];

    if (saved != null && saved.isNotEmpty) {
      return saved;
    }

    final current = names[id];

    if (current != null && current.isNotEmpty) {
      return current;
    }

    const defaults = <String, String>{
      'food': 'Ăn',
      'drink': 'Uống',
      'transport': 'Di chuyển',
      'shopping': 'Mua sắm',
      'other': 'Khác',
      'salary': 'Lương',
      'bonus': 'Thưởng',
      'other_income': 'Thu nhập khác',
    };

    return defaults[id] ?? 'Khác';
  }

  // ==========================================
  // 2. TÍNH TOÁN THỐNG KÊ
  // ==========================================

  _StatisticData calculateStatistics(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> transactions,
  ) {
    int income = 0;
    int expense = 0;

    final expensesByCategory = <String, int>{};
    final savedCategoryNames = <String, String>{};

    final dailyIncome = <int, int>{};
    final dailyExpense = <int, int>{};

    int transactionCount = 0;

    for (final doc in transactions) {
      final data = doc.data();

      final date = toDate(data['date']);

      if (date == null ||
          date.year != selectedMonth.year ||
          date.month != selectedMonth.month) {
        continue;
      }

      final amount = toAmount(data['amount']);

      if (amount <= 0) continue;

      transactionCount++;

      final type = data['type'];

      if (type == 'income') {
        income += amount;

        dailyIncome[date.day] = (dailyIncome[date.day] ?? 0) + amount;
      } else if (type == 'expense') {
        expense += amount;

        dailyExpense[date.day] = (dailyExpense[date.day] ?? 0) + amount;

        final id = data['categoryId']?.toString() ?? 'other';

        expensesByCategory[id] = (expensesByCategory[id] ?? 0) + amount;

        final savedName = data['categoryName']?.toString().trim() ?? '';

        if (savedName.isNotEmpty) {
          savedCategoryNames[id] = savedName;
        }
      }
    }

    return _StatisticData(
      income: income,
      expense: expense,
      transactionCount: transactionCount,
      expensesByCategory: expensesByCategory,
      savedCategoryNames: savedCategoryNames,
      dailyIncome: dailyIncome,
      dailyExpense: dailyExpense,
    );
  }

  // ==========================================
  // 3. THẺ TỔNG QUAN
  // ==========================================

  Widget summaryCard(String title, int amount, Color color, IconData icon) {
    return FinanceCard(
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                formatVnd(amount),
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 4. BỘ CHỌN THÁNG
  // ==========================================

  Widget monthSelector() {
    return FinanceCard(
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
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          IconButton(
            onPressed: () => changeMonth(1),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 5. THẺ CHÊNH LỆCH THU CHI
  // ==========================================

  Widget balanceDifference(_StatisticData data) {
    final difference = data.income - data.expense;

    final positive = difference >= 0;

    return FinanceCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: positive
                ? const Color(0xFFDCFCE7)
                : const Color(0xFFFFEDD5),
            child: Icon(
              positive ? Icons.trending_up : Icons.trending_down,
              color: positive ? AppColors.income : AppColors.expense,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Chênh lệch thu - chi trong tháng',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${difference > 0 ? '+' : ''}'
                  '${formatVnd(difference)}',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: positive ? AppColors.income : AppColors.expense,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 6. BIỂU ĐỒ TRÒN CHI TIÊU
  // ==========================================

  Widget expensePieChart(
    _StatisticData data,
    Map<String, String> categoryNames,
  ) {
    final entries = data.expensesByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return FinanceCard(
      child: Column(
        children: [
          SizedBox(
            height: 210,
            child: Center(
              child: SizedBox(
                width: 190,
                height: 190,
                child: CustomPaint(
                  painter: _ExpensePiePainter(
                    values: entries.map((entry) => entry.value).toList(),
                    colors: chartColors,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Tổng chi',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 6),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            formatVnd(data.expense),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 19,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          if (entries.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Chưa có dữ liệu chi tiêu tháng này',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),

          ...entries.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;

            final name = categoryName(
              item.key,
              categoryNames,
              data.savedCategoryNames,
            );

            final percent = data.expense == 0
                ? 0.0
                : item.value / data.expense * 100;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 6,
                    backgroundColor: chartColors[index % chartColors.length],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${percent.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      formatVnd(item.value),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ==========================================
  // 7. BIỂU ĐỒ THU CHI THEO NGÀY
  // ==========================================

  Widget dailyChart(_StatisticData data) {
    final daysInMonth = DateTime(
      selectedMonth.year,
      selectedMonth.month + 1,
      0,
    ).day;

    final maxAmount = math.max(
      data.dailyIncome.values.fold<int>(
        0,
        (largest, value) => math.max(largest, value),
      ),
      data.dailyExpense.values.fold<int>(
        0,
        (largest, value) => math.max(largest, value),
      ),
    );

    return FinanceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Thu chi theo ngày',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 8),

          const Text(
            'Kéo ngang để xem toàn bộ các ngày trong tháng',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              _legend('Thu nhập', AppColors.income),
              const SizedBox(width: 18),
              _legend('Chi tiêu', AppColors.expense),
            ],
          ),

          const SizedBox(height: 20),

          SizedBox(
            height: 190,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(daysInMonth, (index) {
                  final day = index + 1;

                  final income = data.dailyIncome[day] ?? 0;

                  final expense = data.dailyExpense[day] ?? 0;

                  final incomeHeight = maxAmount == 0
                      ? 0.0
                      : income / maxAmount * 145;

                  final expenseHeight = maxAmount == 0
                      ? 0.0
                      : expense / maxAmount * 145;

                  return Container(
                    width: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        SizedBox(
                          height: 145,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Container(
                                  height: incomeHeight,
                                  decoration: const BoxDecoration(
                                    color: AppColors.income,
                                    borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(4),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Container(
                                  height: expenseHeight,
                                  decoration: const BoxDecoration(
                                    color: AppColors.expense,
                                    borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(4),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$day',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ),

          if (maxAmount == 0) ...[
            const SizedBox(height: 12),
            const Center(
              child: Text(
                'Chưa có giao dịch trong tháng này',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _legend(String name, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 11,
          height: 11,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          name,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
      ],
    );
  }

  // ==========================================
  // 8. GIAO DIỆN THỐNG KÊ CHÍNH
  // ==========================================

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Thống kê')),
        body: const Center(child: Text('Vui lòng đăng nhập.')),
      );
    }

    final userRef = _db.collection('users').doc(user.uid);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Thống kê')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: userRef.collection('transactions').snapshots(),
        builder: (context, transactionSnapshot) {
          if (transactionSnapshot.hasError) {
            return Center(
              child: Text(
                'Không tải được giao dịch:\n'
                '${transactionSnapshot.error}',
                textAlign: TextAlign.center,
              ),
            );
          }

          if (!transactionSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: userRef.collection('categories').snapshots(),
            builder: (context, categorySnapshot) {
              if (categorySnapshot.hasError) {
                return Center(
                  child: Text(
                    'Không tải được danh mục:\n'
                    '${categorySnapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                );
              }

              if (!categorySnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              // Tên danh mục từ Firestore.
              final categoryNames = <String, String>{};

              for (final doc in categorySnapshot.data!.docs) {
                categoryNames[doc.id] =
                    doc.data()['name']?.toString() ?? 'Khác';
              }

              // Tính từ giao dịch của tháng được chọn.
              final data = calculateStatistics(transactionSnapshot.data!.docs);

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  monthSelector(),

                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: summaryCard(
                          'Thu nhập',
                          data.income,
                          AppColors.income,
                          Icons.south_west,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: summaryCard(
                          'Chi tiêu',
                          data.expense,
                          AppColors.expense,
                          Icons.north_east,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  balanceDifference(data),

                  const SizedBox(height: 22),

                  const FinanceTitle('Phân bổ chi tiêu'),

                  const SizedBox(height: 12),

                  expensePieChart(data, categoryNames),

                  const SizedBox(height: 24),

                  dailyChart(data),

                  const SizedBox(height: 22),

                  Center(
                    child: Text(
                      '${data.transactionCount} giao dịch '
                      'trong ${selectedMonth.month}/'
                      '${selectedMonth.year}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

// ============================================
// 9. DỮ LIỆU THỐNG KÊ ĐÃ TÍNH
// ============================================

class _StatisticData {
  final int income;
  final int expense;
  final int transactionCount;

  final Map<String, int> expensesByCategory;
  final Map<String, String> savedCategoryNames;

  final Map<int, int> dailyIncome;
  final Map<int, int> dailyExpense;

  const _StatisticData({
    required this.income,
    required this.expense,
    required this.transactionCount,
    required this.expensesByCategory,
    required this.savedCategoryNames,
    required this.dailyIncome,
    required this.dailyExpense,
  });
}

// ============================================
// 10. VẼ BIỂU ĐỒ TRÒN
// ============================================

class _ExpensePiePainter extends CustomPainter {
  final List<int> values;
  final List<Color> colors;

  _ExpensePiePainter({required this.values, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<int>(
      0,
      (totalAmount, value) => totalAmount + value,
    );

    final center = Offset(size.width / 2, size.height / 2);

    final radius = math.min(size.width, size.height) / 2 - 12;

    final rect = Rect.fromCircle(center: center, radius: radius);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 27
      ..strokeCap = StrokeCap.butt;

    if (total <= 0) {
      paint.color = const Color(0xFFE5ECF6);
      canvas.drawCircle(center, radius, paint);
      return;
    }

    double startAngle = -math.pi / 2;

    for (var i = 0; i < values.length; i++) {
      final sweepAngle = values[i] / total * 2 * math.pi;

      paint.color = colors[i % colors.length];

      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _ExpensePiePainter oldDelegate) {
    if (oldDelegate.values.length != values.length ||
        oldDelegate.colors.length != colors.length) {
      return true;
    }

    for (var i = 0; i < values.length; i++) {
      if (values[i] != oldDelegate.values[i]) {
        return true;
      }
    }

    for (var i = 0; i < colors.length; i++) {
      if (colors[i] != oldDelegate.colors[i]) {
        return true;
      }
    }

    return false;
  }
}
