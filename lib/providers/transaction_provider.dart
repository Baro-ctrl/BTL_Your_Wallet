
import 'package:flutter/material.dart';

import '../models/transaction_model.dart';
import '../repositories/transaction_repository.dart';

class TransactionProvider extends ChangeNotifier {
  final TransactionRepository _repository =
  TransactionRepository();

  List<TransactionModel> transactions = [];

  bool isLoading = false;
  String? error;

  int totalIncome = 0;
  int totalExpense = 0;

  Future<void> loadTransactions(String userId) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      transactions = await _repository.getAll(userId);
      _calculateTotals();
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadByDate(
      String userId,
      DateTime date,
      ) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      transactions = await _repository.getByDate(
        userId,
        date,
      );
      _calculateTotals();
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
      transactions = await _repository.getByMonth(
        userId,
        year,
        month,
      );
      _calculateTotals();
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addTransaction(
      TransactionModel transaction,
      ) async {
    await _repository.addTransaction(transaction);
    await loadTransactions(transaction.userId);
  }

  Future<void> updateTransaction(
      TransactionModel transaction,
      ) async {
    await _repository.updateTransaction(transaction);
    await loadTransactions(transaction.userId);
  }

  Future<void> deleteTransaction(
      String userId,
      String transactionId,
      ) async {
    await _repository.deleteTransaction(
      userId,
      transactionId,
    );
    await loadTransactions(userId);
  }

  void _calculateTotals() {
    totalIncome = 0;
    totalExpense = 0;

    for (final transaction in transactions) {
      if (transaction.type == 'income') {
        totalIncome += transaction.amount;
      } else if (transaction.type == 'expense') {
        totalExpense += transaction.amount;
      }
    }
  }

  int get balance => totalIncome - totalExpense;

  void clear() {
    transactions = [];
    totalIncome = 0;
    totalExpense = 0;
    error = null;
    notifyListeners();
  }
}
