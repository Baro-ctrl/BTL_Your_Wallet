import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/app_router.dart';
import '../services/moment_image_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/finance_ui.dart';

// ==========================================
// CALENDAR SCREEN
// ==========================================

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
  // 1. QUAY VỀ TRANG CHỦ
  // ==========================================

  void _goHome() {
    context.go(AppRouter.home);
  }

  // ==========================================
  // 2. APP BAR - NÚT QUAY LẠI PHÍA TRÊN
  // ==========================================

  PreferredSizeWidget _buildAppBar() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AppBar(
      automaticallyImplyLeading: false,
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: theme.scaffoldBackgroundColor,
      foregroundColor: scheme.onSurface,

      // NÚT QUAY LẠI GÓC TRÊN BÊN TRÁI
      leading: IconButton(
        tooltip: 'Về Trang chủ',
        icon: const Icon(Icons.arrow_back_rounded, size: 25),
        onPressed: _goHome,
      ),

      // TIÊU ĐỀ Ở GIỮA
      title: const Text(
        'Lịch chi tiêu',
        style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
      ),
    );
  }

  // ==========================================
  // 3. CHUYỂN SỐ TIỀN
  // ==========================================

  int _amount(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString().replaceAll('.', '') ?? '') ?? 0;
  }

  // ==========================================
  // 4. CHUYỂN NGÀY THÁNG
  // ==========================================

  DateTime? _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  // ==========================================
  // 5. SO SÁNH NGÀY
  // ==========================================

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isToday(DateTime date) {
    return _sameDay(date, DateTime.now());
  }

  // ==========================================
  // 6. HIỂN THỊ GIỜ
  // ==========================================

  String _timeText(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  // ==========================================
  // 7. LẤY TÊN DANH MỤC
  // ==========================================

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

    return defaultNames[data['categoryId']?.toString()] ?? 'Giao dịch';
  }

  void _changeMonth(int offset) {
    setState(() {
      visibleMonth = DateTime(visibleMonth.year, visibleMonth.month + offset);
      selectedDate = DateTime(visibleMonth.year, visibleMonth.month, 1);
    });
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _transactionsOn(
    DateTime date,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> transactions,
  ) {
    final result = transactions.where((doc) {
      final transactionDate = _date(doc.data()['date']);
      return transactionDate != null && _sameDay(transactionDate, date);
    }).toList();

    // Sắp xếp giao dịch mới nhất trước
    result.sort((a, b) {
      final dateA = _date(a.data()['date'])!;
      final dateB = _date(b.data()['date'])!;
      return dateB.compareTo(dateA);
    });

    return result;
  }

  // ==========================================
  // 2. DAY DETAIL BOTTOM SHEET (MÀN BẢNG TRƯỢT NGHÈO TỪ DƯỚI LÊN)
  // ==========================================

  void _showDayDetailBottomSheet(
    BuildContext context,
    DateTime date,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> transactions,
  ) {
    final dayTransactions = _transactionsOn(date, transactions);

    int totalIncome = 0;
    int totalExpense = 0;

    for (final doc in dayTransactions) {
      final data = doc.data();
      final amount = _amount(data['amount']);
      if (data['type'] == 'income') {
        totalIncome += amount;
      } else {
        totalExpense += amount;
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          builder: (context, scrollController) {
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                // TIÊU ĐỀ NGÀY
                Text(
                  'Chi tiết ngày ${date.day}/${date.month}/${date.year}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),

                // TỔNG THU / CHI TRONG NGÀY
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'Thu nhập',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.income,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '+${formatVnd(totalIncome)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.income,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEDD5),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'Chi tiêu',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.expense,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '-${formatVnd(totalExpense)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.expense,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                const Text(
                  'Danh sách giao dịch',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                if (dayTransactions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text(
                        'Chưa có giao dịch trong ngày này',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  )
                else
                  ...dayTransactions.map((doc) => _transactionTile(doc)),
              ],
            );
          },
        );
      },
    );
  }

  // ==========================================
  // 3. THẺ LỊCH THÁNG
  // ==========================================

  Widget _calendarCard(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> transactions,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final firstDay = DateTime(visibleMonth.year, visibleMonth.month, 1);
    final daysInMonth = DateTime(
      visibleMonth.year,
      visibleMonth.month + 1,
      0,
    ).day;
    final startOffset = firstDay.weekday - 1;
    final cellCount = ((startOffset + daysInMonth + 6) ~/ 7) * 7;

    // Đánh dấu số lượng giao dịch và ảnh theo ngày trong tháng
    final transactionCounts = <int, int>{};
    final dayImagePaths = <int, String>{};

    for (final doc in transactions) {
      final date = _date(doc.data()['date']);
      if (date == null) continue;
      if (date.year != visibleMonth.year || date.month != visibleMonth.month) {
        continue;
      }

      transactionCounts[date.day] = (transactionCounts[date.day] ?? 0) + 1;

      final img = doc.data()['imagePath']?.toString();
      if (img != null &&
          img.isNotEmpty &&
          !dayImagePaths.containsKey(date.day)) {
        dayImagePaths[date.day] = img;
      }
    }

    return FinanceCard(
      child: Column(
        children: [
          // ==================================
          // CHỌN THÁNG
          // ==================================

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                tooltip: 'Tháng trước',
                onPressed: () => _changeMonth(-1),
                icon: const Icon(Icons.chevron_left, size: 28),
              ),

              Text(
                'Tháng ${visibleMonth.month}/${visibleMonth.year}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: scheme.onSurface,
                ),
              ),

              IconButton(
                tooltip: 'Tháng sau',
                onPressed: () => _changeMonth(1),
                icon: const Icon(Icons.chevron_right, size: 28),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ==================================
          // THỨ TRONG TUẦN
          // ==================================
          Row(
            children: const ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'].map((
              day,
            ) {
              return Expanded(
                child: Center(
                  child: Text(
                    day,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          // ==================================
          // LƯỚI NGÀY TRONG THÁNG
          // ==================================
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cellCount,

            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 4,
              childAspectRatio: 0.85,
            ),

            itemBuilder: (context, index) {
              final day = index - startOffset + 1;
              if (day < 1 || day > daysInMonth) {
                return const SizedBox.shrink();
              }

              final date = DateTime(visibleMonth.year, visibleMonth.month, day);
              final selected = _sameDay(date, selectedDate);

              final today = _isToday(date);
              final count = transactionCounts[day] ?? 0;
              final imagePath = dayImagePaths[day];

              return InkWell(
                onTap: () {
                  setState(() {
                    selectedDate = date;
                  });
                  _showDayDetailBottomSheet(context, date, transactions);
                },

                borderRadius: BorderRadius.circular(12),

                child: Container(
                  decoration: BoxDecoration(
                    color: selected ? scheme.primary : Colors.transparent,

                    borderRadius: BorderRadius.circular(12),

                    border: today && !selected
                        ? Border.all(color: scheme.primary, width: 1.5)
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
                      const SizedBox(height: 2),

                      if (imagePath != null &&
                          (MomentImageService.isRemoteUrl(imagePath) ||
                              File(imagePath).existsSync()))
                        Icon(
                          Icons.photo_camera,
                          size: 14,
                          color: selected ? Colors.white : AppColors.primary,
                        )
                      else if (count > 0)
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: selected ? scheme.onPrimary : scheme.primary,
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
  // 4. THẺ GIAO DỊCH
  // ==========================================

  Widget _transactionTile(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final isIncome = data['type'] == 'income';

    final amount = _amount(data['amount']);
    final date = _date(data['date']);
    final category = _categoryName(data);
    final note = data['title']?.toString().trim().isNotEmpty == true
        ? data['title'].toString().trim()
        : data['note']?.toString().trim() ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),

      child: InkWell(
        borderRadius: BorderRadius.circular(18),

        onTap: () {
          Navigator.pop(context); // đóng bottom sheet
          context.push(AppRouter.transactionDetailPath(doc.id));
        },

        child: FinanceCard(
          child: Row(
            children: [
              // BIỂU TƯỢNG THU / CHI
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
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
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
                      date == null ? 'Chưa có giờ' : _timeText(date),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
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
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isIncome ? AppColors.income : AppColors.expense,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 18,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 5. GIAO DIỆN LỊCH
  // ==========================================

  Widget _buildCalendar(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> transactions,
  ) {
    final scheme = Theme.of(context).colorScheme;

    // LẤY GIAO DỊCH CỦA NGÀY ĐƯỢC CHỌN
    final selectedTransactions = _transactionsOn(selectedDate, transactions);

    final monthExpense = transactions.fold<int>(0, (total, doc) {
      final data = doc.data();
      final date = _date(data['date']);
      if (date == null ||
          date.year != visibleMonth.year ||
          date.month != visibleMonth.month ||
          data['type'] != 'expense') {
        return total;
      }
      return total + _amount(data['amount']);
    });

    int totalIncome = 0;
    int totalExpense = 0;
    for (final doc in selectedTransactions) {
      final data = doc.data();

      final amount = _amount(data['amount']);
      if (data['type'] == 'income') {
        totalIncome += amount;
      } else {
        totalExpense += amount;
      }
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _calendarCard(transactions),

        const SizedBox(height: 20),

        FinanceCard(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Tổng chi tháng này',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                formatVnd(monthExpense),
                style: const TextStyle(
                  color: AppColors.expense,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            FinanceTitle(
              'Ngày ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
            ),
            TextButton.icon(
              onPressed: () => _showDayDetailBottomSheet(
                context,
                selectedDate,
                transactions,
              ),
              icon: const Icon(Icons.unfold_more, size: 18),
              label: const Text('Xem bảng trượt'),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // THU NHẬP - CHI TIÊU
        Row(
          children: [
            Expanded(
              child: FinanceCard(
                child: Column(
                  children: [
                    const Icon(
                      Icons.arrow_downward,
                      color: AppColors.income,
                      size: 20,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Thu nhập',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        formatVnd(totalIncome),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.income,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: FinanceCard(
                child: Column(
                  children: [
                    const Icon(
                      Icons.arrow_upward,
                      color: AppColors.expense,
                      size: 20,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Chi tiêu',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        formatVnd(totalExpense),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.expense,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        FinanceTitle('Giao dịch trong ngày (${selectedTransactions.length})'),
        const SizedBox(height: 12),

        // CHƯA CÓ GIAO DỊCH
        if (selectedTransactions.isEmpty)
          FinanceCard(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),

              child: Column(
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 40,
                    color: AppColors.textSecondary,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Chưa có giao dịch trong ngày này',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),

        // DANH SÁCH GIAO DỊCH
        ...selectedTransactions.map(_transactionTile),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    // CHƯA ĐĂNG NHẬP
    if (user == null) {
      return Scaffold(
        appBar: _buildAppBar(),
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
            // LỖI TẢI DỮ LIỆU
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Không tải được lịch giao dịch:\n${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.expense),
                  ),
                ),
              );
            }

            // ĐANG TẢI DỮ LIỆU
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            // HIỂN THỊ LỊCH
            return _buildCalendar(snapshot.data!.docs);
          },
        ),
      ),

      // ======================================
      // THANH ĐIỀU HƯỚNG 5 NÚT
      // ======================================
      bottomNavigationBar: const AppBottomNav(),
    );
  }
}
