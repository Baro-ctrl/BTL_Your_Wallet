
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_model.dart';

class UserRepository {
  final FirebaseFirestore firestore;

  UserRepository({FirebaseFirestore? firestore})
      : firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _users =>
      firestore.collection('users');

  // Tạo hồ sơ người dùng
  Future<void> addUser(UserModel user) async {
    await _users.doc(user.id).set(user.toMap());
  }

  // Lấy thông tin người dùng
  Future<UserModel?> getUser(String userId) async {
    final doc = await _users.doc(userId).get();

    if (!doc.exists || doc.data() == null) {
      return null;
    }

    return UserModel.fromMap(doc.data()!);
  }

  // Cập nhật hồ sơ
  Future<void> updateUser(UserModel user) async {
    await _users.doc(user.id).update(user.toMap());
  }

  // Xóa hồ sơ
  Future<void> deleteUser(String userId) async {
    await _users.doc(userId).delete();
  }

  // Theo dõi thay đổi hồ sơ
  Stream<UserModel?> watchUser(String userId) {
    return _users.doc(userId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) {
        return null;
      }

      return UserModel.fromMap(doc.data()!);
    });
  }
}
