
import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../repositories/user_repository.dart';

class UserProvider extends ChangeNotifier {
  final UserRepository _repository = UserRepository();

  UserModel? user;
  bool isLoading = false;
  String? error;

  Future<void> loadUser(String userId) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      user = await _repository.getUser(userId);
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addUser(UserModel newUser) async {
    error = null;
    try {
      await _repository.addUser(newUser);
      user = newUser;
      notifyListeners();
    } catch (e) {
      error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateUser(UserModel updatedUser) async {
    error = null;
    try {
      await _repository.updateUser(updatedUser);
      user = updatedUser;
      notifyListeners();
    } catch (e) {
      error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteUser(String userId) async {
    error = null;
    try {
      await _repository.deleteUser(userId);
      user = null;
      notifyListeners();
    } catch (e) {
      error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  void clear() {
    user = null;
    error = null;
    notifyListeners();
  }
}
