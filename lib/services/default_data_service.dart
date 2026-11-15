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

    // ==========================================
    // 1. DANH MỤC CHI TIÊU MẶC ĐỊNH
    // ==========================================

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

      // ======================================
      // 2. DANH MỤC THU NHẬP
      // ======================================
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

    // ==========================================
    // 3. VÍ TIỀN MẶT MẶC ĐỊNH
    // ==========================================

    final defaultWallet = WalletModel(
      id: 'cash',
      userId: userId,
      name: 'Tiền mặt',
      type: 'cash',
      balance: 0,
      isDefault: true,
      createdAt: DateTime.now(),
    );

    final walletRef = userRef.collection('wallets').doc('cash');

    final categoryRefs = categories.map((category) {
      return userRef.collection('categories').doc(category.id);
    }).toList();

    // ==========================================
    // 4. FIRESTORE TRANSACTION
    // ==========================================

    await _firestore.runTransaction((transaction) async {
      // ======================================
      // BƯỚC 1: ĐỌC TẤT CẢ DOCUMENT
      // ======================================

      final markerSnapshot = await transaction.get(markerRef);

      final walletSnapshot = await transaction.get(walletRef);

      final categorySnapshots = <DocumentSnapshot<Map<String, dynamic>>>[];

      for (final ref in categoryRefs) {
        final snapshot = await transaction.get(ref);
        categorySnapshots.add(snapshot);
      }

      // ======================================
      // BƯỚC 2: KIỂM TRA DANH MỤC
      // ======================================

      for (var i = 0; i < categories.length; i++) {
        if (!categorySnapshots[i].exists) {
          transaction.set(categoryRefs[i], categories[i].toMap());
        }
      }

      // ======================================
      // BƯỚC 3: KIỂM TRA VÍ TIỀN MẶT
      // ======================================

      if (!walletSnapshot.exists) {
        transaction.set(walletRef, defaultWallet.toMap());
      }

      // ======================================
      // BƯỚC 4: KIỂM TRA METADATA
      // ======================================

      final markerData = markerSnapshot.data();

      final currentVersion = markerData?['version'] is int
          ? markerData!['version'] as int
          : 0;

      if (!markerSnapshot.exists ||
          currentVersion < 2 ||
          markerData?['initialized'] != true) {
        transaction.set(markerRef, {
          'initialized': true,
          'version': 2,
          if (!markerSnapshot.exists) 'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    });
  }
}
