
import 'package:flutter/material.dart';

import '../models/budget_model.dart';
import '../repositories/budget_repository.dart';

class BudgetProvider extends ChangeNotifier {
  final BudgetRepository _repository = BudgetRepository();

  List<BudgetModel> budgets = [];

  bool isLoading = false;
  String? error;

  Future<void> loadBudgets(String userId) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      budgets = await _repository.getBudgets(userId);
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadByMonth(
      String userId,
      int year,
      int month,
      ) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      budgets = await _repository.getByMonth(
        userId,
        year,
        month,
      );
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addBudget(BudgetModel budget) async {
    await _repository.addBudget(budget);
    await loadBudgets(budget.userId);
  }

  Future<void> updateBudget(BudgetModel budget) async {
    await _repository.updateBudget(budget);
    await loadBudgets(budget.userId);
  }

  Future<void> deleteBudget(
      String userId,
      String budgetId,
      ) async {
    await _repository.deleteBudget(userId, budgetId);
    await loadBudgets(userId);
  }

  int get totalBudget {
    return budgets.fold<int>(
      0,
          (sum, budget) => sum + budget.amount,
    );
  }

  List<BudgetModel> get activeBudgets {
    return budgets
        .where((budget) => budget.isActive)
        .toList();
  }

  void clear() {
    budgets = [];
    error = null;
    notifyListeners();
  }
}
