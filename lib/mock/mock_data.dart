
import '../models/user_model.dart';
import '../models/transaction_model.dart';
import '../models/category_model.dart';
import '../models/wallet_model.dart';
import '../models/budget_model.dart';
import '../models/notification_model.dart';

class MockData {
  static const String userId = 'mock_user_001';

  // Người dùng giả
  static final UserModel user = UserModel(
    id: userId,
    name: 'Nguyễn Văn A',
    email: 'demo@example.com',
    phone: '0901234567',
    avatarUrl: '',
    createdAt: DateTime(2026, 10, 1),
  );

  // Danh mục giả
  static final List<CategoryModel> categories = [
    CategoryModel(
      id: 'food',
      userId: userId,
      name: 'Ăn',
      type: 'expense',
      icon: 'restaurant',
      color: 0xFFFF9800,
      isDefault: true,
    ),
    CategoryModel(
      id: 'drink',
      userId: userId,
      name: 'Uống',
      type: 'expense',
      icon: 'local_cafe',
      color: 0xFF2196F3,
      isDefault: true,
    ),
    CategoryModel(
      id: 'transport',
      userId: userId,
      name: 'Di chuyển',
      type: 'expense',
      icon: 'directions_car',
      color: 0xFF4CAF50,
      isDefault: true,
    ),
    CategoryModel(
      id: 'shopping',
      userId: userId,
      name: 'Mua sắm',
      type: 'expense',
      icon: 'shopping_bag',
      color: 0xFF9C27B0,
      isDefault: true,
    ),
    CategoryModel(
      id: 'other',
      userId: userId,
      name: 'Khác',
      type: 'expense',
      icon: 'more_horiz',
      color: 0xFF607D8B,
      isDefault: true,
    ),
  ];

  // Ví giả
  static final List<WalletModel> wallets = [
    WalletModel(
      id: 'cash',
      userId: userId,
      name: 'Tiền mặt',
      type: 'cash',
      balance: 1500000,
      isDefault: true,
      createdAt: DateTime(2026, 10, 1),
    ),
  ];

  // Giao dịch giả
  static final List<TransactionModel> transactions = [
    TransactionModel(
      id: 'tx001',
      userId: userId,
      categoryId: 'food',
      walletId: 'cash',
      amount: 35000,
      type: 'expense',
      note: 'Ăn sáng',
      date: DateTime(2026, 10, 29, 7, 30),
    ),
    TransactionModel(
      id: 'tx002',
      userId: userId,
      categoryId: 'drink',
      walletId: 'cash',
      amount: 25000,
      type: 'expense',
      note: 'Cà phê',
      date: DateTime(2026, 10, 29, 9),
    ),
    TransactionModel(
      id: 'tx003',
      userId: userId,
      categoryId: 'transport',
      walletId: 'cash',
      amount: 70000,
      type: 'expense',
      note: 'Đổ xăng',
      date: DateTime(2026, 10, 28),
    ),
    TransactionModel(
      id: 'tx004',
      userId: userId,
      categoryId: 'shopping',
      walletId: 'cash',
      amount: 250000,
      type: 'expense',
      note: 'Mua quần áo',
      date: DateTime(2026, 10, 27),
    ),
  ];

  // Ngân sách giả
  static final List<BudgetModel> budgets = [
    BudgetModel(
      id: 'budget001',
      userId: userId,
      categoryId: 'food',
      name: 'Ngân sách ăn uống',
      amount: 2000000,
      month: 10,
      year: 2026,
      createdAt: DateTime(2026, 10, 1),
    ),
  ];

  // Thông báo giả
  static final List<NotificationModel> notifications = [
    NotificationModel(
      id: 'noti001',
      userId: userId,
      title: 'Chào mừng!',
      message: 'Chào mừng bạn đến với Your Wallet.',
      type: 'system',
      createdAt: DateTime(2026, 10, 29),
    ),
  ];
}
