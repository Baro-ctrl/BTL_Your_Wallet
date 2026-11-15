import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/transaction_model.dart';
import 'base_repository.dart';

class TransactionRepository extends BaseRepository<TransactionModel> {
  TransactionRepository({super.firestore})
    : super(
        collectionName: 'transactions',
        fromMap: TransactionModel.fromMap,
        toMap: (item) => item.toMap(),
      );

  int _readAmount(dynamic value) {
    if (value is int) return value;
    if (value is num && value.isFinite && value == value.toInt()) {
      return value.toInt();
    }
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;
    }
    throw FormatException('Invalid wallet amount: $value');
  }

  int _effect(String type, int amount) {
    if (type == 'income') return amount;
    if (type == 'expense') return -amount;
    throw ArgumentError.value(type, 'type', 'Expected income or expense');
  }

  Future<void> addTransactionWithWalletUpdate(
    TransactionModel transaction, {
    required String categoryName,
  }) async {
    if (transaction.amount <= 0) {
      throw ArgumentError.value(transaction.amount, 'amount');
    }

    final transactionRef = collection(transaction.userId).doc(transaction.id);
    final walletRef = firestore
        .collection('users')
        .doc(transaction.userId)
        .collection('wallets')
        .doc(transaction.walletId);

    await firestore.runTransaction((tx) async {
      final existingTransaction = await tx.get(transactionRef);
      final walletSnapshot = await tx.get(walletRef);
      if (existingTransaction.exists) {
        throw StateError('Mã giao dịch đã tồn tại.');
      }
      if (!walletSnapshot.exists ||
          walletSnapshot.data()?['userId'] != transaction.userId) {
        throw StateError('Ví không tồn tại hoặc không thuộc tài khoản.');
      }

      final balance = _readAmount(walletSnapshot.data()?['balance']);
      final data = toMap(transaction);
      data['categoryName'] = categoryName;
      data['date'] = Timestamp.fromDate(transaction.date);
      data['createdAt'] = FieldValue.serverTimestamp();

      tx.set(transactionRef, data);
      tx.update(walletRef, {
        'balance': balance + _effect(transaction.type, transaction.amount),
      });
    });
  }

  Future<void> updateTransactionWithWalletUpdate(
    String userId,
    String transactionId,
    Map<String, dynamic> changed,
  ) async {
    final transactionRef = collection(userId).doc(transactionId);

    await firestore.runTransaction((tx) async {
      final latestTransaction = await tx.get(transactionRef);
      if (!latestTransaction.exists ||
          latestTransaction.data()?['userId'] != userId) {
        throw StateError('Giao dịch không tồn tại hoặc không thuộc tài khoản.');
      }

      final old = latestTransaction.data()!;
      final oldWalletId = old['walletId']?.toString() ?? '';
      final newWalletId = changed['walletId']?.toString() ?? '';
      final oldAmount = _readAmount(old['amount']);
      final newAmount = _readAmount(changed['amount']);
      final oldType = old['type']?.toString() ?? '';
      final newType = changed['type']?.toString() ?? '';
      if (oldWalletId.isEmpty ||
          newWalletId.isEmpty ||
          oldAmount <= 0 ||
          newAmount <= 0) {
        throw StateError('Thông tin ví hoặc số tiền không hợp lệ.');
      }

      final oldWalletRef = firestore
          .collection('users')
          .doc(userId)
          .collection('wallets')
          .doc(oldWalletId);
      final newWalletRef = firestore
          .collection('users')
          .doc(userId)
          .collection('wallets')
          .doc(newWalletId);
      final oldWalletSnapshot = await tx.get(oldWalletRef);
      final newWalletSnapshot = oldWalletId == newWalletId
          ? oldWalletSnapshot
          : await tx.get(newWalletRef);

      if (!oldWalletSnapshot.exists ||
          !newWalletSnapshot.exists ||
          oldWalletSnapshot.data()?['userId'] != userId ||
          newWalletSnapshot.data()?['userId'] != userId) {
        throw StateError('Không tìm thấy ví hợp lệ.');
      }

      final oldBalance = _readAmount(oldWalletSnapshot.data()?['balance']);
      final oldEffect = _effect(oldType, oldAmount);
      final newEffect = _effect(newType, newAmount);
      if (oldWalletId == newWalletId) {
        tx.update(oldWalletRef, {
          'balance': oldBalance - oldEffect + newEffect,
        });
      } else {
        final newBalance = _readAmount(newWalletSnapshot.data()?['balance']);
        tx.update(oldWalletRef, {'balance': oldBalance - oldEffect});
        tx.update(newWalletRef, {'balance': newBalance + newEffect});
      }

      tx.update(transactionRef, {
        ...changed,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<String?> deleteTransactionWithWalletUpdate(
    String userId,
    String transactionId,
  ) async {
    final transactionRef = collection(userId).doc(transactionId);

    return firestore.runTransaction<String?>((tx) async {
      final snapshot = await tx.get(transactionRef);
      if (!snapshot.exists || snapshot.data()?['userId'] != userId) {
        throw StateError('Giao dịch không tồn tại hoặc không thuộc tài khoản.');
      }

      final data = snapshot.data()!;
      final walletId = data['walletId']?.toString() ?? '';
      final amount = _readAmount(data['amount']);
      if (walletId.isEmpty || amount <= 0) {
        throw StateError('Thông tin ví hoặc số tiền không hợp lệ.');
      }

      final walletRef = firestore
          .collection('users')
          .doc(userId)
          .collection('wallets')
          .doc(walletId);
      final walletSnapshot = await tx.get(walletRef);
      if (!walletSnapshot.exists ||
          walletSnapshot.data()?['userId'] != userId) {
        throw StateError('Không tìm thấy ví hợp lệ.');
      }

      final effect = _effect(data['type']?.toString() ?? '', amount);
      final balance = _readAmount(walletSnapshot.data()?['balance']);
      tx.update(walletRef, {'balance': balance - effect});
      tx.delete(transactionRef);
      return data['imagePath']?.toString();
    });
  }

  // Thêm giao dịch
  Future<void> addTransaction(TransactionModel transaction) async {
    await addTransactionWithWalletUpdate(
      transaction,
      categoryName: transaction.categoryName,
    );
  }

  // Lấy giao dịch theo ID
  Future<TransactionModel?> getTransaction(String userId, String id) {
    return getById(userId, id);
  }

  // Sửa giao dịch
  Future<void> updateTransaction(TransactionModel transaction) async {
    await updateTransactionWithWalletUpdate(
      transaction.userId,
      transaction.id,
      toMap(transaction),
    );
  }

  // Xóa giao dịch
  Future<void> deleteTransaction(String userId, String id) async {
    await deleteTransactionWithWalletUpdate(userId, id);
  }

  // Lấy giao dịch theo ngày
  Future<List<TransactionModel>> getByDate(String userId, DateTime date) async {
    final transactions = await getAll(userId);

    return transactions.where((item) {
      return item.date.year == date.year &&
          item.date.month == date.month &&
          item.date.day == date.day;
    }).toList();
  }

  // Lấy giao dịch theo tháng
  Future<List<TransactionModel>> getByMonth(
    String userId,
    int year,
    int month,
  ) async {
    final transactions = await getAll(userId);

    return transactions.where((item) {
      return item.date.year == year && item.date.month == month;
    }).toList();
  }

  // Theo dõi giao dịch
  Stream<List<TransactionModel>> watchTransactions(String userId) {
    return watchAll(userId);
  }

  // Tính tổng thu
  Future<int> getTotalIncome(String userId, int year, int month) async {
    final transactions = await getByMonth(userId, year, month);

    return transactions
        .where((item) => item.type == 'income')
        .fold<int>(0, (total, item) => total + item.amount);
  }

  // Tính tổng chi
  Future<int> getTotalExpense(String userId, int year, int month) async {
    final transactions = await getByMonth(userId, year, month);

    return transactions
        .where((item) => item.type == 'expense')
        .fold<int>(0, (total, item) => total + item.amount);
  }
}
