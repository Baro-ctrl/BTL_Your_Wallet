
import '../models/transaction_model.dart';
import 'base_repository.dart';

class TransactionRepository
    extends BaseRepository<TransactionModel> {

  TransactionRepository()
      : super(
    collectionName: 'transactions',
    fromMap: TransactionModel.fromMap,
    toMap: (item) => item.toMap(),
  );

  // Thêm giao dịch
  Future<void> addTransaction(
      TransactionModel transaction,
      ) async {
    await add(
      transaction.userId,
      transaction.id,
      transaction,
    );
  }

  // Lấy giao dịch theo ID
  Future<TransactionModel?> getTransaction(
      String userId,
      String id,
      ) {
    return getById(userId, id);
  }

  // Sửa giao dịch
  Future<void> updateTransaction(
      TransactionModel transaction,
      ) async {
    await update(
      transaction.userId,
      transaction.id,
      transaction,
    );
  }

  // Xóa giao dịch
  Future<void> deleteTransaction(
      String userId,
      String id,
      ) async {
    await delete(userId, id);
  }

  // Lấy giao dịch theo ngày
  Future<List<TransactionModel>> getByDate(
      String userId,
      DateTime date,
      ) async {
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
      return item.date.year == year &&
          item.date.month == month;
    }).toList();
  }

  // Theo dõi giao dịch
  Stream<List<TransactionModel>> watchTransactions(
      String userId,
      ) {
    return watchAll(userId);
  }

  // Tính tổng thu
  Future<int> getTotalIncome(
      String userId,
      int year,
      int month,
      ) async {
    final transactions = await getByMonth(
      userId,
      year,
      month,
    );

    return transactions
        .where((item) => item.type == 'income')
        .fold<int>(0, (sum, item) => sum + item.amount);
  }

  // Tính tổng chi
  Future<int> getTotalExpense(
      String userId,
      int year,
      int month,
      ) async {
    final transactions = await getByMonth(
      userId,
      year,
      month,
    );

    return transactions
        .where((item) => item.type == 'expense')
        .fold<int>(0, (sum, item) => sum + item.amount);
  }
}
