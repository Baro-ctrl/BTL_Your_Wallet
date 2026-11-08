import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../models/transaction_model.dart';
import '../models/category_model.dart';
import '../models/wallet_model.dart';

class ExpenseProvider with ChangeNotifier {
  final List<TransactionModel> _transactions = [];

  // Danh mục mẫu khớp chính xác 100% với CategoryModel của Bạn A
  final List<CategoryModel> _defaultCategories = [
    CategoryModel(
      id: 'cat_1',
      userId: 'user_1',
      name: 'Ăn uống',
      type: 'expense',
      icon: 'restaurant',
      color: 0xFFE57373,
      isDefault: true,
    ),
    CategoryModel(
      id: 'cat_2',
      userId: 'user_1',
      name: 'Di chuyển',
      type: 'expense',
      icon: 'directions_car',
      color: 0xFF81C784,
      isDefault: true,
    ),
    CategoryModel(
      id: 'cat_3',
      userId: 'user_1',
      name: 'Mua sắm',
      type: 'expense',
      icon: 'shopping_cart',
      color: 0xFF64B5F6,
      isDefault: true,
    ),
    CategoryModel(
      id: 'cat_4',
      userId: 'user_1',
      name: 'Lương',
      type: 'income',
      icon: 'attach_money',
      color: 0xFFFFB74D,
      isDefault: true,
    ),
  ];

  // Danh sách ví mẫu khớp với WalletModel của Bạn A
  final List<WalletModel> _wallets = [
    WalletModel(
      id: 'w_1',
      userId: 'user_1',
      name: 'Ví Tiền mặt',
      type: 'cash',
      balance: 3000000,
      currency: 'VND',
      isDefault: true,
      createdAt: DateTime.now(),
    ),
    WalletModel(
      id: 'w_2',
      userId: 'user_1',
      name: 'Thẻ Ngân hàng',
      type: 'bank',
      balance: 10000000,
      currency: 'VND',
      isDefault: false,
      createdAt: DateTime.now(),
    ),
  ];

  List<TransactionModel> get transactions => _transactions;
  List<CategoryModel> get defaultCategories => _defaultCategories;
  List<WalletModel> get wallets => _wallets;

  // Lưu ảnh khoảnh khắc vào thư mục riêng của app
  Future<String?> saveImageLocally(XFile imageFile) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}${path.extension(imageFile.path)}';
      final savedImage = await File(imageFile.path).copy('${appDir.path}/$fileName');
      return savedImage.path;
    } catch (e) {
      debugPrint('Lỗi lưu ảnh: $e');
      return null;
    }
  }

  // Thêm giao dịch & tự động cập nhật số dư của WalletModel
  Future<void> addTransaction(TransactionModel tx) async {
    _transactions.add(tx);

    final walletIndex = _wallets.indexWhere((w) => w.id == tx.walletId);
    if (walletIndex != -1) {
      final currentWallet = _wallets[walletIndex];
      int currentBalance = currentWallet.balance;
      int newBalance = tx.type == 'expense'
          ? (currentBalance - tx.amount)
          : (currentBalance + tx.amount);

      _wallets[walletIndex] = WalletModel(
        id: currentWallet.id,
        userId: currentWallet.userId,
        name: currentWallet.name,
        type: currentWallet.type,
        balance: newBalance,
        currency: currentWallet.currency,
        isDefault: currentWallet.isDefault,
        createdAt: currentWallet.createdAt,
      );
    }
    notifyListeners();
  }
}