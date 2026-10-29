
class CategoryModel {
  final String id;
  final String userId;
  final String name;
  final String type;
  final String icon;
  final int color;
  final bool isDefault;

  CategoryModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
    required this.icon,
    required this.color,
    this.isDefault = false,
  });

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      id: map['id'] as String,
      userId: map['userId'] as String,
      name: map['name'] as String,
      type: map['type'] as String,
      icon: map['icon'] as String,
      color: (map['color'] as num).toInt(),
      isDefault: map['isDefault'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'type': type,
      'icon': icon,
      'color': color,
      'isDefault': isDefault,
    };
  }
}
