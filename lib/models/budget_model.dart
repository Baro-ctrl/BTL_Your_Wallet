
class BudgetModel {
  final String id;
  final String userId;
  final String categoryId;
  final String name;
  final int amount;
  final int month;
  final int year;
  final bool isActive;
  final DateTime createdAt;

  BudgetModel({
    required this.id,
    required this.userId,
    required this.categoryId,
    required this.name,
    required this.amount,
    required this.month,
    required this.year,
    this.isActive = true,
    required this.createdAt,
  });

  factory BudgetModel.fromMap(
      Map<String, dynamic> map,
      ) {
    return BudgetModel(
      id: map['id'] as String,
      userId: map['userId'] as String,
      categoryId: map['categoryId'] as String,
      name: map['name'] as String,
      amount: (map['amount'] as num).toInt(),
      month: (map['month'] as num).toInt(),
      year: (map['year'] as num).toInt(),
      isActive: map['isActive'] as bool? ?? true,
      createdAt: DateTime.parse(
        map['createdAt'] as String,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'categoryId': categoryId,
      'name': name,
      'amount': amount,
      'month': month,
      'year': year,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
