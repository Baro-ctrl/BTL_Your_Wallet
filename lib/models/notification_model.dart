
class NotificationModel {
  final String id;
  final String userId;
  final String title;
  final String message;
  final String type;
  final bool isRead;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    this.isRead = false,
    required this.createdAt,
  });

  factory NotificationModel.fromMap(
      Map<String, dynamic> map,
      ) {
    return NotificationModel(
      id: map['id'] as String,
      userId: map['userId'] as String,
      title: map['title'] as String,
      message: map['message'] as String,
      type: map['type'] as String,
      isRead: map['isRead'] as bool? ?? false,
      createdAt: DateTime.parse(
        map['createdAt'] as String,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'message': message,
      'type': type,
      'isRead': isRead,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
