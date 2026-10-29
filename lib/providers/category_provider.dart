
import 'package:flutter/material.dart';

import '../models/category_model.dart';
import '../repositories/category_repository.dart';

class CategoryProvider extends ChangeNotifier {
  final CategoryRepository _repository =
  CategoryRepository();

  List<CategoryModel> categories = [];
  bool isLoading = false;
  String? error;

  Future<void> loadCategories(String userId) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      categories = await _repository.getCategories(userId);
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addCategory(CategoryModel category) async {
    await _repository.addCategory(category);
    await loadCategories(category.userId);
  }

  Future<void> updateCategory(CategoryModel category) async {
    await _repository.updateCategory(category);
    await loadCategories(category.userId);
  }

  Future<void> deleteCategory(
      String userId,
      String categoryId,
      ) async {
    await _repository.deleteCategory(
      userId,
      categoryId,
    );
    await loadCategories(userId);
  }

  List<CategoryModel> get expenseCategories {
    return categories
        .where((category) => category.type == 'expense')
        .toList();
  }

  List<CategoryModel> get incomeCategories {
    return categories
        .where((category) => category.type == 'income')
        .toList();
  }

  void clear() {
    categories = [];
    error = null;
    notifyListeners();
  }
}
