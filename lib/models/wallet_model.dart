
class WalletModel {
  final String id;
  final String userId;
  final String name;
  final String type;
  final int balance;
  final String currency;
  final bool isDefault;
  final DateTime createdAt;

  WalletModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
    required this.balance,
    this.currency = 'VND',
    this.isDefault = false,
    required this.createdAt,
  });

  factory WalletModel.fromMap(
      Map<String, dynamic> map,
      ) {
    return WalletModel(
      id: map['id'] as String,
      userId: map['userId'] as String,
      name: map['name'] as String,
      type: map['type'] as String,
      balance: (map['balance'] as num).toInt(),
      currency: map['currency'] as String? ?? 'VND',
      isDefault: map['isDefault'] as bool? ?? false,
      createdAt: DateTime.parse(
        map['createdAt'] as String,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'type': type,
      'balance': balance,
      'currency': currency,
      'isDefault': isDefault,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
