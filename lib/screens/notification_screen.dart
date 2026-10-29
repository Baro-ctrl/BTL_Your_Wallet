import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/app_router.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/finance_ui.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  DocumentReference<Map<String, dynamic>>? get _userRef {
    final uid = _uid;
    if (uid == null) return null;

    return _db.collection('users').doc(uid);
  }

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

  String _dateText(DateTime? date) {
    if (date == null) return 'Chưa có thời gian';

    final now = DateTime.now();

    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);

    String dateLabel;

    if (day == today) {
      dateLabel = 'Hôm nay';
    } else if (day == today.subtract(const Duration(days: 1))) {
      dateLabel = 'Hôm qua';
    } else {
      dateLabel =
          '${date.day.toString().padLeft(2, '0')}/'
          '${date.month.toString().padLeft(2, '0')}/'
          '${date.year}';
    }

    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$dateLabel - $hour:$minute';
  }

  String _categoryName(Map<String, dynamic> data) {
    final saved = data['categoryName']?.toString().trim() ?? '';

    if (saved.isNotEmpty) return saved;

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

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // ==========================================
  // 2. THÔNG BÁO TỪ GIAO DỊCH
  // ==========================================

  List<_WalletNotice> _transactionNotices(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final sorted = docs.toList();

    sorted.sort((a, b) {
      final aDate =
          _date(a.data()['createdAt']) ??
          _date(a.data()['date']) ??
          DateTime(2000);

      final bDate =
          _date(b.data()['createdAt']) ??
          _date(b.data()['date']) ??
          DateTime(2000);

      return bDate.compareTo(aDate);
    });

    return sorted.take(20).map((doc) {
      final data = doc.data();

      final income = data['type'] == 'income';
      final amount = _amount(data['amount']);
      final category = _categoryName(data);
      final note = data['note']?.toString().trim() ?? '';

      final message =
          '${income ? 'Đã ghi nhận khoản thu' : 'Đã ghi nhận khoản chi'} '
          '${formatVnd(amount)} thuộc danh mục $category.'
          '${note.isEmpty ? '' : ' Ghi chú: $note'}';

      return _WalletNotice(
        id: 'transaction_${doc.id}',
        title: income ? 'Giao dịch thu nhập' : 'Giao dịch chi tiêu',
        message: message,
        date: _date(data['createdAt']) ?? _date(data['date']),
        icon: income ? Icons.south_west : Icons.north_east,
        color: income ? AppColors.income : AppColors.expense,
        transactionId: doc.id,
      );
    }).toList();
  }

  // ==========================================
  // 3. CẢNH BÁO NGÂN SÁCH THÁNG HIỆN TẠI
  // ==========================================

  List<_WalletNotice> _budgetNotices(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> budgets,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> transactions,
  ) {
    final now = DateTime.now();
    final spending = <String, int>{};

    for (final doc in transactions) {
      final data = doc.data();

      if (data['type'] != 'expense') continue;

      final date = _date(data['date']);

      if (date == null || date.year != now.year || date.month != now.month) {
        continue;
      }

      final categoryId = data['categoryId']?.toString();

      if (categoryId == null || categoryId.isEmpty) {
        continue;
      }

      spending[categoryId] =
          (spending[categoryId] ?? 0) + _amount(data['amount']);
    }

    final results = <_WalletNotice>[];

    for (final doc in budgets) {
      final data = doc.data();

      if (_amount(data['month']) != now.month ||
          _amount(data['year']) != now.year) {
        continue;
      }

      final categoryId = data['categoryId']?.toString() ?? '';

      if (categoryId.isEmpty) continue;

      final limit = _amount(data['amount']);
      if (limit <= 0) continue;

      final spent = spending[categoryId] ?? 0;
      final ratio = spent / limit;

      if (ratio < 0.8) continue;

      final name = data['name']?.toString() ?? 'Danh mục';

      final isOver = spent > limit;
      final percent = (ratio * 100).round();

      final title = isOver ? 'Vượt ngân sách $name' : 'Sắp hết ngân sách $name';

      final message = isOver
          ? 'Bạn đã chi ${formatVnd(spent)} '
                'trên hạn mức ${formatVnd(limit)}. '
                'Đã vượt ${formatVnd(spent - limit)}.'
          : 'Bạn đã sử dụng $percent% ngân sách $name '
                '(${formatVnd(spent)} / ${formatVnd(limit)}).';

      results.add(
        _WalletNotice(
          id: 'budget_${doc.id}',
          title: title,
          message: message,
          date: now,
          icon: isOver ? Icons.warning_amber_rounded : Icons.savings_outlined,
          color: isOver ? AppColors.expense : const Color(0xFFFF9800),
          route: AppRouter.setBudget,
          priority: isOver ? 2 : 1,
        ),
      );
    }

    return results;
  }

  // ==========================================
  // 4. THÔNG BÁO ĐÃ LƯU TRONG FIRESTORE
  // ==========================================

  List<_WalletNotice> _savedNotices(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs.map((doc) {
      final data = doc.data();

      final type = data['type']?.toString() ?? 'general';

      IconData icon;
      Color color;

      switch (type) {
        case 'budget':
        case 'budget_warning':
          icon = Icons.savings_outlined;
          color = const Color(0xFFFF9800);
          break;
        case 'expense':
          icon = Icons.north_east;
          color = AppColors.expense;
          break;
        case 'income':
          icon = Icons.south_west;
          color = AppColors.income;
          break;
        default:
          icon = Icons.notifications_outlined;
          color = AppColors.primaryDark;
      }

      return _WalletNotice(
        id: doc.id,
        title: data['title']?.toString() ?? 'Thông báo',
        message: data['message']?.toString() ?? '',
        date: _date(data['createdAt']) ?? _date(data['date']),
        icon: icon,
        color: color,
        isSaved: true,
        isRead: data['isRead'] == true,
      );
    }).toList();
  }

  // ==========================================
  // 5. ĐÁNH DẤU ĐÃ ĐỌC
  // ==========================================

  Future<void> _markAsRead(_WalletNotice notice) async {
    final userRef = _userRef;

    if (!notice.isSaved || notice.isRead || userRef == null) {
      return;
    }

    try {
      await userRef.collection('notifications').doc(notice.id).update({
        'isRead': true,
      });
    } catch (error) {
      _showMessage('Không thể đánh dấu đã đọc: $error');
    }
  }

  Future<void> _openNotice(_WalletNotice notice) async {
    await _markAsRead(notice);

    if (!mounted) return;

    if (notice.transactionId != null) {
      context.push(AppRouter.transactionDetailPath(notice.transactionId!));
    } else if (notice.route != null) {
      context.push(notice.route!);
    }
  }

  // ==========================================
  // 6. THẺ THÔNG BÁO
  // ==========================================

  Widget _noticeTile(_WalletNotice item) {
    final unread = item.isSaved && !item.isRead;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: unread ? const Color(0xFFF1F7FF) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: unread ? AppColors.primary : AppColors.border,
          width: unread ? 1.2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () => _openNotice(item),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(item.icon, color: item.color),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (unread)
                          const CircleAvatar(
                            radius: 4,
                            backgroundColor: AppColors.primary,
                          ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    Text(
                      item.message,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      _dateText(item.date),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),

                    if (item.priority > 0) ...[
                      const SizedBox(height: 8),
                      Text(
                        item.priority == 2
                            ? 'Cần kiểm tra ngân sách'
                            : 'Ngân sách gần đạt giới hạn',
                        style: TextStyle(
                          color: item.color,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
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
  // 7. DANH SÁCH THÔNG BÁO
  // ==========================================

  Widget _buildNoticeList({
    required List<_WalletNotice> saved,
    required List<_WalletNotice> transactions,
    required List<_WalletNotice> budgets,
  }) {
    final notices = [...budgets, ...saved, ...transactions];

    notices.sort((a, b) {
      if (a.priority != b.priority) {
        return b.priority.compareTo(a.priority);
      }

      final dateA = a.date ?? DateTime(2000);
      final dateB = b.date ?? DateTime(2000);

      return dateB.compareTo(dateA);
    });

    if (notices.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.notifications_none,
                size: 56,
                color: AppColors.textSecondary,
              ),
              SizedBox(height: 14),
              Text(
                'Chưa có thông báo',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Giao dịch và cảnh báo ngân sách '
                'sẽ xuất hiện tại đây.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: notices.length,
      itemBuilder: (context, index) {
        return _noticeTile(notices[index]);
      },
    );
  }

  // ==========================================
  // 8. GIAO DIỆN CHÍNH
  // ==========================================

  @override
  Widget build(BuildContext context) {
    final userRef = _userRef;

    if (userRef == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Thông báo')),
        body: const Center(child: Text('Vui lòng đăng nhập.')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bg,

      appBar: AppBar(title: const Text('Thông báo'), centerTitle: true),

      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: userRef.collection('transactions').snapshots(),
          builder: (context, transactionSnapshot) {
            if (transactionSnapshot.hasError) {
              return Center(
                child: Text(
                  'Lỗi tải giao dịch: '
                  '${transactionSnapshot.error}',
                  textAlign: TextAlign.center,
                ),
              );
            }

            if (!transactionSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final transactionDocs = transactionSnapshot.data!.docs;

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: userRef.collection('budgets').snapshots(),
              builder: (context, budgetSnapshot) {
                if (budgetSnapshot.hasError) {
                  return Center(
                    child: Text(
                      'Lỗi tải ngân sách: '
                      '${budgetSnapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                if (!budgetSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: userRef.collection('notifications').snapshots(),
                  builder: (context, noticeSnapshot) {
                    if (noticeSnapshot.hasError) {
                      return Center(
                        child: Text(
                          'Lỗi tải thông báo: '
                          '${noticeSnapshot.error}',
                          textAlign: TextAlign.center,
                        ),
                      );
                    }

                    if (!noticeSnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    return _buildNoticeList(
                      saved: _savedNotices(noticeSnapshot.data!.docs),
                      transactions: _transactionNotices(transactionDocs),
                      budgets: _budgetNotices(
                        budgetSnapshot.data!.docs,
                        transactionDocs,
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),

      bottomNavigationBar: AppBottomNav(
        currentIndex: 2,
        onTap: (index) {
          switch (index) {
            case 0:
              context.go(AppRouter.home);
              break;

            case 1:
              context.go(AppRouter.addExpense);
              break;

            case 2:
              break;

            case 3:
              context.go(AppRouter.profile);
              break;
          }
        },
      ),
    );
  }
}

// ============================================
// 9. DỮ LIỆU THÔNG BÁO
// ============================================

class _WalletNotice {
  final String id;
  final String title;
  final String message;
  final DateTime? date;
  final IconData icon;
  final Color color;

  final bool isSaved;
  final bool isRead;
  final int priority;

  final String? transactionId;
  final String? route;

  const _WalletNotice({
    required this.id,
    required this.title,
    required this.message,
    required this.date,
    required this.icon,
    required this.color,
    this.isSaved = false,
    this.isRead = false,
    this.priority = 0,
    this.transactionId,
    this.route,
  });
}
