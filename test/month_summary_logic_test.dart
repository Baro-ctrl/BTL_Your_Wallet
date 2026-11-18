import 'package:flutter_test/flutter_test.dart';
import 'package:chi_tieu/models/budget_model.dart';
import 'package:chi_tieu/services/month_summary_logic.dart';

BudgetModel budget(
  String id,
  String categoryId,
  String name,
  int amount, {
  int month = 11,
  int year = 2026,
  bool isActive = true,
}) {
  return BudgetModel(
    id: id,
    userId: 'u1',
    categoryId: categoryId,
    name: name,
    amount: amount,
    month: month,
    year: year,
    isActive: isActive,
    createdAt: DateTime(2026, 11, 1),
  );
}

void main() {
  group('budgetStatus', () {
    test('dưới 90% là bình thường', () {
      expect(budgetStatus(spent: 4499999, limit: 5000000), BudgetStatus.normal);
    });
    test('đúng 90% là gần đạt', () {
      expect(
        budgetStatus(spent: 4500000, limit: 5000000),
        BudgetStatus.nearLimit,
      );
    });
    test('đúng bằng hạn mức vẫn chưa vượt', () {
      expect(
        budgetStatus(spent: 5000000, limit: 5000000),
        BudgetStatus.nearLimit,
      );
    });
    test('quá hạn mức là vượt', () {
      expect(
        budgetStatus(spent: 5000001, limit: 5000000),
        BudgetStatus.exceeded,
      );
    });
    test('hạn mức bằng 0 luôn bình thường', () {
      expect(budgetStatus(spent: 100, limit: 0), BudgetStatus.normal);
    });
  });

  group('buildMonthSummary', () {
    final names = {'c1': 'Ăn', 'c2': 'Uống', 'c3': 'Khác'};

    test('tính tổng, chênh lệch, mục chi nhiều nhất', () {
      final s = buildMonthSummary(
        budgets: [
          budget('b1', 'c1', 'Ăn', 2000000),
          budget('b2', 'c2', 'Uống', 600000),
        ],
        spentByCategoryId: {'c1': 1600000, 'c2': 640000, 'c3': 160000},
        categoryNames: names,
        year: 2026,
        month: 11,
      );
      expect(s.totalBudget, 2600000);
      expect(s.totalSpent, 2400000);
      expect(s.difference, 200000);
      expect(s.isOverBudget, false);
      expect(s.topCategoryName, 'Ăn');
      expect(s.topCategorySpent, 1600000);
      expect(s.categories.length, 2);
      expect(s.categories[0].status, BudgetStatus.normal);
      expect(s.categories[1].status, BudgetStatus.exceeded);
    });

    test('chi vượt tổng mục tiêu', () {
      final s = buildMonthSummary(
        budgets: [budget('b1', 'c1', 'Ăn', 2600000)],
        spentByCategoryId: {'c1': 3000000},
        categoryNames: names,
        year: 2026,
        month: 11,
      );
      expect(s.isOverBudget, true);
      expect(s.difference, -400000);
    });

    test('bỏ qua hạn mức đã tắt và hạn mức của tháng khác', () {
      final s = buildMonthSummary(
        budgets: [
          budget('b1', 'c1', 'Ăn', 2000000),
          budget('b2', 'c2', 'Uống', 600000, isActive: false),
          budget('b3', 'c3', 'Mua sắm', 800000, month: 10),
        ],
        spentByCategoryId: {},
        categoryNames: names,
        year: 2026,
        month: 11,
      );
      expect(s.totalBudget, 2000000);
      expect(s.categories.length, 1);
    });

    test('hai hạn mức cùng danh mục được cộng lại', () {
      final s = buildMonthSummary(
        budgets: [
          budget('b1', 'c1', 'Ăn', 1000000),
          budget('b2', 'c1', 'Ăn', 500000),
        ],
        spentByCategoryId: {'c1': 100000},
        categoryNames: names,
        year: 2026,
        month: 11,
      );
      expect(s.categories.length, 1);
      expect(s.categories[0].limit, 1500000);
    });

    test('chưa có chi tiêu thì không có mục chi nhiều nhất', () {
      final s = buildMonthSummary(
        budgets: [budget('b1', 'c1', 'Ăn', 2000000)],
        spentByCategoryId: {},
        categoryNames: names,
        year: 2026,
        month: 11,
      );
      expect(s.totalSpent, 0);
      expect(s.topCategoryName, isNull);
    });
  });
}
