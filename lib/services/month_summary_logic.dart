import '../models/budget_model.dart';

enum BudgetStatus { normal, nearLimit, exceeded }

/// nearLimit: đã chi từ 90% hạn mức trở lên nhưng chưa vượt.
/// exceeded: chi vượt hạn mức.
BudgetStatus budgetStatus({required int spent, required int limit}) {
  if (limit <= 0) return BudgetStatus.normal;
  if (spent > limit) return BudgetStatus.exceeded;
  if (spent * 10 >= limit * 9) return BudgetStatus.nearLimit;
  return BudgetStatus.normal;
}

class CategoryProgress {
  final String categoryId;
  final String name;
  final int spent;
  final int limit;
  final BudgetStatus status;

  const CategoryProgress({
    required this.categoryId,
    required this.name,
    required this.spent,
    required this.limit,
    required this.status,
  });

  /// Tỉ lệ đã chi (0.0 đến 1.0) để vẽ thanh tiến độ.
  double get ratio => limit <= 0 ? 0 : (spent / limit).clamp(0.0, 1.0);
}

class MonthSummary {
  final int totalBudget;
  final int totalSpent;
  final List<CategoryProgress> categories;
  final String? topCategoryName;
  final int topCategorySpent;

  const MonthSummary({
    required this.totalBudget,
    required this.totalSpent,
    required this.categories,
    required this.topCategoryName,
    required this.topCategorySpent,
  });

  /// Dương: tiết kiệm được. Âm: chi vượt mục tiêu.
  int get difference => totalBudget - totalSpent;

  bool get isOverBudget => totalBudget > 0 && totalSpent > totalBudget;
}

/// budgets: danh sách hạn mức (có thể lẫn nhiều tháng, hàm tự lọc).
/// spentByCategoryId: tổng chi của từng danh mục trong tháng.
/// categoryNames: tên danh mục, dùng cho mục "chi nhiều nhất".
MonthSummary buildMonthSummary({
  required List<BudgetModel> budgets,
  required Map<String, int> spentByCategoryId,
  required Map<String, String> categoryNames,
  required int year,
  required int month,
  int? totalBudgetOverride,
}) {
  final limits = <String, int>{};
  final budgetNames = <String, String>{};

  for (final b in budgets) {
    if (!b.isActive || b.year != year || b.month != month) continue;
    limits[b.categoryId] = (limits[b.categoryId] ?? 0) + b.amount;
    budgetNames[b.categoryId] = b.name;
  }

  final rows = <CategoryProgress>[];
  for (final entry in limits.entries) {
    final spent = spentByCategoryId[entry.key] ?? 0;
    rows.add(
      CategoryProgress(
        categoryId: entry.key,
        name: budgetNames[entry.key] ?? '',
        spent: spent,
        limit: entry.value,
        status: budgetStatus(spent: spent, limit: entry.value),
      ),
    );
  }

  final categoryBudgetTotal = limits.values.fold<int>(
    0,
    (sum, value) => sum + value,
  );

  final totalBudget = totalBudgetOverride ?? categoryBudgetTotal;
  final totalSpent = spentByCategoryId.values.fold<int>(0, (sum, v) => sum + v);

  String? topId;
  int topSpent = 0;
  for (final entry in spentByCategoryId.entries) {
    if (entry.value > topSpent) {
      topId = entry.key;
      topSpent = entry.value;
    }
  }

  String? topName;
  if (topId != null) {
    topName = categoryNames[topId] ?? budgetNames[topId] ?? 'Khác';
  }

  return MonthSummary(
    totalBudget: totalBudget,
    totalSpent: totalSpent,
    categories: rows,
    topCategoryName: topName,
    topCategorySpent: topSpent,
  );
}
