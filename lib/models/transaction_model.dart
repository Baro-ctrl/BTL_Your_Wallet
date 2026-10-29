
class TransactionModel {
  final String id;
  final String userId;
  final String categoryId;
  final String walletId;
  final int amount;
  final String type;
  final String note;
  final DateTime date;

  TransactionModel({
    required this.id,
    required this.userId,
    required this.categoryId,
    required this.walletId,
    required this.amount,
    required this.type,
    required this.note,
    required this.date,
  });

  // Chuyển dữ liệu từ Firestore thành đối tượng Dart
  factory TransactionModel.fromMap(
    Map<String, dynamic> map,
  ) {
    return TransactionModel(
      id: map['id'] as String,
      userId: map['userId'] as String,
      categoryId: map['categoryId'] as String,
      walletId: map['walletId'] as String,
      amount: (map['amount'] as num).toInt(),
      type: map['type'] as String,
      note: map['note'] as String,
      date: DateTime.parse(map['date'] as String),
    );
  }

  // Chuyển đối tượng Dart thành dữ liệu để lưu
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'categoryId': categoryId,
      'walletId': walletId,
      'amount': amount,
      'type': type,
      'note': note,
      'date': date.toIso8601String(),
    };
  }
}
