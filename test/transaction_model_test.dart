import 'package:chi_tieu/models/transaction_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> transactionMap(Object date) => {
  'id': 'transaction-1',
  'userId': 'user-1',
  'categoryId': 'food',
  'walletId': 'cash',
  'amount': 12000,
  'type': 'expense',
  'title': 'Lunch',
  'note': 'With coworkers',
  'date': date,
};

void main() {
  group('TransactionModel.fromMap', () {
    test('reads Firestore Timestamp dates and title', () {
      final date = DateTime(2026, 11, 15, 12, 30);
      final transaction = TransactionModel.fromMap(
        transactionMap(Timestamp.fromDate(date)),
      );

      expect(transaction.date, date);
      expect(transaction.title, 'Lunch');
      expect(transaction.note, 'With coworkers');
    });

    test('continues reading ISO date strings from repository maps', () {
      final date = DateTime(2026, 11, 15, 12, 30);
      final transaction = TransactionModel.fromMap(
        transactionMap(date.toIso8601String()),
      );

      expect(transaction.date, date);
    });
  });
}
