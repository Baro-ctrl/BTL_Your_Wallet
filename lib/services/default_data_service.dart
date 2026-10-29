import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/category_model.dart';
import '../models/wallet_model.dart';

class DefaultDataService {
  final FirebaseFirestore _firestore;

  DefaultDataService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  // ==========================================
  // KHỞI TẠO DỮ LIỆU MẶC ĐỊNH
  // ==========================================

  Future<void> createDefaultData(String userId) async {
    if (userId.trim().isEmpty) {
      throw ArgumentError('userId cannot be empty');
    }

    final userRef = _firestore.collection('users').doc(userId);

    final markerRef = userRef.collection('metadata').doc('setup');

    // DANH MỤC CHI TIÊU
    final categories = <CategoryModel>[
      CategoryModel(
        id: 'food',
        userId: userId,
        name: 'Ăn',
        type: 'expense',
        icon: 'restaurant',
        color: 0xFFFF9800,
        isDefault: true,
      ),
      CategoryModel(
        id: 'drink',
        userId: userId,
        name: 'Uống',
        type: 'expense',
        icon: 'local_cafe',
        color: 0xFF2196F3,
        isDefault: true,
      ),
      CategoryModel(
        id: 'transport',
        userId: userId,
        name: 'Di chuyển',
        type: 'expense',
        icon: 'directions_car',
        color: 0xFF4CAF50,
        isDefault: true,
      ),
      CategoryModel(
        id: 'shopping',
        userId: userId,
        name: 'Mua sắm',
        type: 'expense',
        icon: 'shopping_bag',
        color: 0xFF9C27B0,
        isDefault: true,
      ),
      CategoryModel(
        id: 'other',
        userId: userId,
        name: 'Khác',
        type: 'expense',
        icon: 'more_horiz',
        color: 0xFF607D8B,
        isDefault: true,
      ),

      // DANH MỤC THU NHẬP
      CategoryModel(
        id: 'salary',
        userId: userId,
        name: 'Lương',
        type: 'income',
        icon: 'payments',
        color: 0xFF4CAF50,
        isDefault: true,
      ),
      CategoryModel(
        id: 'bonus',
        userId: userId,
        name: 'Thưởng',
        type: 'income',
        icon: 'card_giftcard',
        color: 0xFF2196F3,
        isDefault: true,
      ),
      CategoryModel(
        id: 'other_income',
        userId: userId,
        name: 'Thu nhập khác',
        type: 'income',
        icon: 'account_balance_wallet',
        color: 0xFF009688,
        isDefault: true,
      ),
    ];

    // VÍ MẶC ĐỊNH
    final defaultWallet = WalletModel(
      id: 'cash',
      userId: userId,
      name: 'Tiền mặt',
      type: 'cash',
      balance: 0,
      isDefault: true,
      createdAt: DateTime.now(),
    );

    // ==========================================
    // FIRESTORE TRANSACTION
    // ==========================================

    await _firestore.runTransaction((transaction) async {
      // BƯỚC 1: ĐỌC TẤT CẢ DOCUMENT TRƯỚC KHI GHI
      final markerSnapshot = await transaction.get(markerRef);

      if (markerSnapshot.exists) {
        return;
      }

      final walletRef = userRef.collection('wallets').doc(defaultWallet.id);

      final walletSnapshot = await transaction.get(walletRef);

      final categoryRefs = categories
          .map((category) => userRef.collection('categories').doc(category.id))
          .toList();

      final categorySnapshots = <DocumentSnapshot<Map<String, dynamic>>>[];

      for (final ref in categoryRefs) {
        categorySnapshots.add(await transaction.get(ref));
      }

      // BƯỚC 2: CHỈ TẠO DANH MỤC CHƯA TỒN TẠI
      for (var index = 0; index < categories.length; index++) {
        if (!categorySnapshots[index].exists) {
          transaction.set(categoryRefs[index], categories[index].toMap());
        }
      }

      // BƯỚC 3: CHỈ TẠO VÍ KHI CHƯA TỒN TẠI
      if (!walletSnapshot.exists) {
        transaction.set(walletRef, defaultWallet.toMap());
      }

      // BƯỚC 4: ĐÁNH DẤU ĐÃ KHỞI TẠO
      transaction.set(markerRef, {
        'initialized': true,
        'version': 2,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
