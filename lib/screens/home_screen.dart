import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/app_router.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/finance_ui.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  // ==========================================
  // 1. CHUYỂN ĐỔI DỮ LIỆU
  // ==========================================

  int _toAmount(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();

    return int.tryParse(value?.toString().replaceAll('.', '') ?? '') ?? 0;
  }

  DateTime _toDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;

    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }

    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _dateText(DateTime date) {
    if (date.millisecondsSinceEpoch == 0) {
      return 'Chưa có ngày giao dịch';
    }

    final now = DateTime.now();

    final today = DateTime(now.year, now.month, now.day);

    final transactionDay = DateTime(date.year, date.month, date.day);

    String dayText;

    if (transactionDay == today) {
      dayText = 'Hôm nay';
    } else if (transactionDay == today.subtract(const Duration(days: 1))) {
      dayText = 'Hôm qua';
    } else {
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');

      dayText = '$day/$month/${date.year}';
    }

    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$dayText, $hour:$minute';
  }

  // ==========================================
  // 2. TÊN DANH MỤC GIAO DỊCH
  // ==========================================

  String _categoryName(Map<String, dynamic> data) {
    // Ưu tiên tên danh mục đã lưu trong giao dịch.
    final savedName = data['categoryName']?.toString().trim() ?? '';

    if (savedName.isNotEmpty) {
      return savedName;
    }

    // Hỗ trợ giao dịch cũ chưa có categoryName.
    final categoryId = data['categoryId']?.toString() ?? '';

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

    return defaultNames[categoryId] ?? 'Giao dịch';
  }

  IconData _categoryIcon(Map<String, dynamic> data) {
    final categoryId = data['categoryId']?.toString() ?? '';

    switch (categoryId) {
      case 'food':
        return Icons.restaurant;
      case 'drink':
        return Icons.local_cafe;
      case 'transport':
        return Icons.directions_car;
      case 'shopping':
        return Icons.shopping_bag;
      case 'salary':
        return Icons.payments;
      case 'bonus':
        return Icons.card_giftcard;
      case 'other_income':
        return Icons.account_balance_wallet;
      default:
        return data['type'] == 'income'
            ? Icons.arrow_downward
            : Icons.arrow_upward;
    }
  }

  // ==========================================
  // 3. KẾT NỐI FIREBASE REALTIME
  // ==========================================

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return _loadingScreen();
        }

        final user = authSnapshot.data;

        if (user == null) {
          return _notLoggedInScreen(context);
        }

        final userRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid);

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: userRef.collection('transactions').snapshots(),
          builder: (context, transactionSnapshot) {
            if (transactionSnapshot.hasError) {
              return _errorScreen(
                'Không tải được giao dịch:\n'
                '${transactionSnapshot.error}',
              );
            }

            if (!transactionSnapshot.hasData) {
              return _loadingScreen();
            }

            final transactions = transactionSnapshot.data!.docs.toList();

            // Sắp xếp giao dịch mới nhất lên đầu.
            transactions.sort((a, b) {
              final dateA = _toDate(a.data()['date']);
              final dateB = _toDate(b.data()['date']);

              final comparison = dateB.compareTo(dateA);

              if (comparison != 0) {
                return comparison;
              }

              final createdA = _toDate(a.data()['createdAt']);
              final createdB = _toDate(b.data()['createdAt']);

              return createdB.compareTo(createdA);
            });

            int income = 0;
            int expense = 0;

            for (final doc in transactions) {
              final data = doc.data();
              final amount = _toAmount(data['amount']);

              if (data['type'] == 'income') {
                income += amount;
              } else if (data['type'] == 'expense') {
                expense += amount;
              }
            }

            // Theo dõi thay đổi số dư ví.
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: userRef.collection('wallets').snapshots(),
              builder: (context, walletSnapshot) {
                if (walletSnapshot.hasError) {
                  return _errorScreen(
                    'Không tải được ví:\n'
                    '${walletSnapshot.error}',
                  );
                }

                if (!walletSnapshot.hasData) {
                  return _loadingScreen();
                }

                final wallets = walletSnapshot.data!.docs;

                final walletBalance = wallets.fold<int>(
                  0,
                  (totalAmount, doc) =>
                      totalAmount + _toAmount(doc.data()['balance']),
                );

                return _buildHome(
                  context,
                  walletBalance,
                  income,
                  expense,
                  transactions,
                );
              },
            );
          },
        );
      },
    );
  }

  // ==========================================
  // 4. MÀN HÌNH LOADING
  // ==========================================

  Widget _loadingScreen() {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }

  // ==========================================
  // 5. CHƯA ĐĂNG NHẬP
  // ==========================================

  Widget _notLoggedInScreen(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your Wallet')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.lock_outline,
                size: 56,
                color: AppColors.primaryDark,
              ),
              const SizedBox(height: 16),
              const Text(
                'Bạn chưa đăng nhập',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  context.go(AppRouter.login);
                },
                child: const Text('Đến trang đăng nhập'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 6. HIỂN THỊ LỖI
  // ==========================================

  Widget _errorScreen(String message) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your Wallet')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.expense),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 7. GIAO DIỆN HOME
  // ==========================================

  Widget _buildHome(
    BuildContext context,
    int walletBalance,
    int income,
    int expense,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> transactions,
  ) {
    return Scaffold(
      backgroundColor: AppColors.bg,

      appBar: AppBar(
        title: const Text('Your Wallet'),
        actions: [
          IconButton(
            tooltip: 'Thông báo',
            onPressed: () {
              context.push(AppRouter.notifications);
            },
            icon: const Icon(Icons.notifications_none),
          ),
        ],
      ),

      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            // THẺ TỔNG SỐ DƯ
            _balanceCard(walletBalance, income, expense),

            const SizedBox(height: 24),

            const Text(
              'Tiện ích nhanh',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),

            const SizedBox(height: 14),

            // GIỮ NGUYÊN 8 TIỆN ÍCH NHANH
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.85,
              children: [
                _quickAction(
                  context,
                  Icons.account_balance_wallet,
                  'Ví',
                  AppRouter.wallets,
                ),
                _quickAction(
                  context,
                  Icons.category,
                  'Danh mục',
                  AppRouter.categories,
                ),
                _quickAction(
                  context,
                  Icons.bar_chart,
                  'Thống kê',
                  AppRouter.statistic,
                ),
                _quickAction(
                  context,
                  Icons.calendar_month,
                  'Lịch',
                  AppRouter.calendar,
                ),
                _quickAction(
                  context,
                  Icons.savings,
                  'Ngân sách',
                  AppRouter.setBudget,
                ),
                _quickAction(
                  context,
                  Icons.receipt_long,
                  'Giao dịch',
                  AppRouter.transactions,
                ),
                _quickAction(context, Icons.person, 'Hồ sơ', AppRouter.profile),
                _quickAction(
                  context,
                  Icons.edit,
                  'Sửa hồ sơ',
                  AppRouter.editProfile,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // TIÊU ĐỀ GIAO DỊCH
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Giao dịch gần đây',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                TextButton(
                  onPressed: () {
                    context.push(AppRouter.transactions);
                  },
                  child: const Text('Xem tất cả'),
                ),
              ],
            ),

            const SizedBox(height: 8),

            if (transactions.isEmpty)
              const FinanceCard(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    children: [
                      Icon(
                        Icons.receipt_long_outlined,
                        size: 40,
                        color: AppColors.textSecondary,
                      ),
                      SizedBox(height: 12),
                      Text('Chưa có giao dịch nào'),
                    ],
                  ),
                ),
              ),

            // 5 GIAO DỊCH MỚI NHẤT
            ...transactions
                .take(5)
                .map((doc) => _transactionTile(context, doc)),
          ],
        ),
      ),

      // THANH ĐIỀU HƯỚNG DƯỚI CÙNG
      bottomNavigationBar: AppBottomNav(
        currentIndex: 0,
        onTap: (index) {
          switch (index) {
            case 0:
              context.go(AppRouter.home);
              break;
            case 1:
              context.go(AppRouter.addExpense);
              break;
            case 2:
              context.go(AppRouter.notifications);
              break;
            case 3:
              context.go(AppRouter.profile);
              break;
          }
        },
      ),
    );
  }

  // ==========================================
  // 8. THẺ SỐ DƯ
  // ==========================================

  Widget _balanceCard(int balance, int income, int expense) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tổng số dư ví đang lưu',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),

          const SizedBox(height: 10),

          Text(
            formatVnd(balance),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: _balanceInfo(
                  'Tổng thu giao dịch',
                  income,
                  Icons.arrow_downward,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _balanceInfo(
                  'Tổng chi giao dịch',
                  expense,
                  Icons.arrow_upward,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 9. TỔNG THU VÀ TỔNG CHI
  // ==========================================

  Widget _balanceInfo(String title, int amount, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.white, size: 18),

        const SizedBox(width: 6),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),

              const SizedBox(height: 5),

              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  formatVnd(amount),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================
  // 10. TIỆN ÍCH NHANH
  // ==========================================

  Widget _quickAction(
    BuildContext context,
    IconData icon,
    String title,
    String route,
  ) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          context.push(route);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 26, color: AppColors.primaryDark),

              const SizedBox(height: 8),

              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 11. GIAO DỊCH GẦN ĐÂY
  // ==========================================

  Widget _transactionTile(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();

    final isIncome = data['type'] == 'income';
    final amount = _toAmount(data['amount']);
    final date = _toDate(data['date']);

    final category = _categoryName(data);
    final note = data['note']?.toString().trim() ?? '';

    final icon = _categoryIcon(data);

    final amountText = '${isIncome ? '+' : '-'}${formatVnd(amount)}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () {
          context.push(AppRouter.transactionDetailPath(doc.id));
        },
        borderRadius: BorderRadius.circular(18),
        child: FinanceCard(
          child: Row(
            children: [
              // ICON THEO DANH MỤC
              CircleAvatar(
                backgroundColor: isIncome
                    ? const Color(0xFFDCFCE7)
                    : const Color(0xFFFFEDD5),
                child: Icon(
                  icon,
                  size: 20,
                  color: isIncome ? AppColors.income : AppColors.expense,
                ),
              ),

              const SizedBox(width: 12),

              // TÊN DANH MỤC VÀ GHI CHÚ
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
                      const SizedBox(height: 4),
                      Text(
                        note,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],

                    const SizedBox(height: 5),

                    Text(
                      _dateText(date),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // SỐ TIỀN GIAO DỊCH
              Flexible(
                child: Text(
                  amountText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isIncome ? AppColors.income : AppColors.expense,
                  ),
                ),
              ),

              const SizedBox(width: 4),

              const Icon(Icons.chevron_right, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
