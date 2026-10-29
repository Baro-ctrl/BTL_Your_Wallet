
import '../models/wallet_model.dart';
import 'base_repository.dart';

class WalletRepository extends BaseRepository<WalletModel> {

  WalletRepository()
      : super(
    collectionName: 'wallets',
    fromMap: WalletModel.fromMap,
    toMap: (item) => item.toMap(),
  );

  // Thêm ví
  Future<void> addWallet(WalletModel wallet) async {
    await add(
      wallet.userId,
      wallet.id,
      wallet,
    );
  }

  // Lấy danh sách ví
  Future<List<WalletModel>> getWallets(String userId) {
    return getAll(userId);
  }

  // Lấy ví theo ID
  Future<WalletModel?> getWallet(
      String userId,
      String walletId,
      ) {
    return getById(userId, walletId);
  }

  // Sửa thông tin ví
  Future<void> updateWallet(WalletModel wallet) async {
    await update(
      wallet.userId,
      wallet.id,
      wallet,
    );
  }

  // Xóa ví
  Future<void> deleteWallet(
      String userId,
      String walletId,
      ) async {
    await delete(userId, walletId);
  }

  // Tính tổng số dư các ví
  Future<int> getTotalBalance(String userId) async {
    final wallets = await getAll(userId);

    return wallets.fold<int>(
      0,
          (sum, wallet) => sum + wallet.balance,
    );
  }

  // Theo dõi danh sách ví
  Stream<List<WalletModel>> watchWallets(String userId) {
    return watchAll(userId);
  }
}
