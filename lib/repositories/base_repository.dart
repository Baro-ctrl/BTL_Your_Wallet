
import 'package:cloud_firestore/cloud_firestore.dart';

class BaseRepository<T> {
  final FirebaseFirestore firestore;
  final String collectionName;
  final T Function(Map<String, dynamic>) fromMap;
  final Map<String, dynamic> Function(T) toMap;

  BaseRepository({
    required this.collectionName,
    required this.fromMap,
    required this.toMap,
    FirebaseFirestore? firestore,
  }) : firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> collection(
      String userId,
      ) {
    return firestore
        .collection('users')
        .doc(userId)
        .collection(collectionName);
  }

  // Thêm dữ liệu mới
  Future<void> add(
      String userId,
      String id,
      T item,
      ) async {
    await collection(userId).doc(id).set(toMap(item));
  }

  // Đọc dữ liệu theo ID
  Future<T?> getById(
      String userId,
      String id,
      ) async {
    final doc = await collection(userId).doc(id).get();

    if (!doc.exists || doc.data() == null) {
      return null;
    }

    return fromMap(doc.data()!);
  }

  // Đọc tất cả dữ liệu
  Future<List<T>> getAll(String userId) async {
    final snapshot = await collection(userId).get();

    return snapshot.docs
        .map((doc) => fromMap(doc.data()))
        .toList();
  }

  // Sửa dữ liệu
  Future<void> update(
      String userId,
      String id,
      T item,
      ) async {
    await collection(userId).doc(id).update(toMap(item));
  }

  // Xóa dữ liệu
  Future<void> delete(
      String userId,
      String id,
      ) async {
    await collection(userId).doc(id).delete();
  }

  // Theo dõi dữ liệu thời gian thực
  Stream<List<T>> watchAll(String userId) {
    return collection(userId).snapshots().map(
          (snapshot) => snapshot.docs
          .map((doc) => fromMap(doc.data()))
          .toList(),
    );
  }
}
