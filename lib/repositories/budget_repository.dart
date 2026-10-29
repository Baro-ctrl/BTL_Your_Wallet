
import '../models/budget_model.dart';
import 'base_repository.dart';

class BudgetRepository extends BaseRepository<BudgetModel> {

  BudgetRepository()
      : super(
    collectionName: 'budgets',
    fromMap: BudgetModel.fromMap,
    toMap: (item) => item.toMap(),
  );

  // Thêm ngân sách
  Future<void> addBudget(BudgetModel budget) async {
    await add(
      budget.userId,
      budget.id,
      budget,
    );
  }

  // Lấy ngân sách theo ID
  Future<BudgetModel?> getBudget(
      String userId,
      String id,
      ) {
    return getById(userId, id);
  }

  // Lấy tất cả ngân sách
  Future<List<BudgetModel>> getBudgets(String userId) {
    return getAll(userId);
  }

  // Sửa ngân sách
  Future<void> updateBudget(BudgetModel budget) async {
    await update(
      budget.userId,
      budget.id,
      budget,
    );
  }

  // Xóa ngân sách
  Future<void> deleteBudget(
      String userId,
      String id,
      ) async {
    await delete(userId, id);
  }

  // Lấy ngân sách theo tháng
  Future<List<BudgetModel>> getByMonth(
      String userId,
      int year,
      int month,
      ) async {
    final budgets = await getAll(userId);

    return budgets.where((item) {
      return item.year == year &&
          item.month == month;
    }).toList();
  }

  // Lấy ngân sách theo danh mục
  Future<List<BudgetModel>> getByCategory(
      String userId,
      String categoryId,
      ) async {
    final budgets = await getAll(userId);

    return budgets
        .where((item) => item.categoryId == categoryId)
        .toList();
  }

  // Theo dõi ngân sách
  Stream<List<BudgetModel>> watchBudgets(String userId) {
    return watchAll(userId);
  }
}
