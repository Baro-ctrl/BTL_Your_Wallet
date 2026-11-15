import 'package:cloud_firestore/cloud_firestore.dart';

class TransactionModel {
  final String id;
  final String userId;
  final String categoryId;
  final String walletId;
  final int amount; // Số nguyên (đồng) theo đúng thiết kế của A
  final String type; // 'expense' hoặc 'income'
  final String title;
  final String note;
  final DateTime date;
  final String? imagePath;

  TransactionModel({
    required this.id,
    required this.userId,
    required this.categoryId,
    required this.walletId,
    required this.amount,
    required this.type,
    this.title = '',
    required this.note,
    required this.date,
    this.imagePath,
  });

  // Chuyển dữ liệu từ Firestore thành đối tượng Dart
  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    final rawDate = map['date'];
    final date = switch (rawDate) {
      Timestamp value => value.toDate(),
      DateTime value => value,
      String value when DateTime.tryParse(value) != null =>
        DateTime.parse(value),
      _ => throw FormatException('Invalid transaction date: $rawDate'),
    };

    return TransactionModel(
      id: map['id'] as String,
      userId: map['userId'] as String,
      categoryId: map['categoryId'] as String,
      walletId: map['walletId'] as String,
      amount: (map['amount'] as num).toInt(),
      type: map['type'] as String,
      title: map['title']?.toString() ?? '',
      note: map['note']?.toString() ?? '',
      date: date,
      imagePath: map['imagePath'] as String?,
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
      'title': title,
      'note': note,
      'date': date.toIso8601String(),
      'imagePath': imagePath,
    };
  }
}
