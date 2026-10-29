
import 'package:flutter/material.dart';

import '../models/wallet_model.dart';
import '../repositories/wallet_repository.dart';

class WalletProvider extends ChangeNotifier {
  final WalletRepository _repository = WalletRepository();

  List<WalletModel> wallets = [];

  bool isLoading = false;
  String? error;

  Future<void> loadWallets(String userId) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      wallets = await _repository.getWallets(userId);
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addWallet(WalletModel wallet) async {
    await _repository.addWallet(wallet);
    await loadWallets(wallet.userId);
  }

  Future<void> updateWallet(WalletModel wallet) async {
    await _repository.updateWallet(wallet);
    await loadWallets(wallet.userId);
  }

  Future<void> deleteWallet(
      String userId,
      String walletId,
      ) async {
    await _repository.deleteWallet(userId, walletId);
    await loadWallets(userId);
  }

  int get totalBalance {
    return wallets.fold<int>(
      0,
          (sum, wallet) => sum + wallet.balance,
    );
  }

  WalletModel? getWalletById(String walletId) {
    for (final wallet in wallets) {
      if (wallet.id == walletId) {
        return wallet;
      }
    }
    return null;
  }

  void clear() {
    wallets = [];
    error = null;
    notifyListeners();
  }
}
