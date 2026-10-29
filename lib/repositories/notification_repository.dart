
import '../models/notification_model.dart';
import 'base_repository.dart';

class NotificationRepository
    extends BaseRepository<NotificationModel> {

  NotificationRepository()
      : super(
    collectionName: 'notifications',
    fromMap: NotificationModel.fromMap,
    toMap: (item) => item.toMap(),
  );

  // Thêm thông báo
  Future<void> addNotification(
      NotificationModel notification,
      ) async {
    await add(
      notification.userId,
      notification.id,
      notification,
    );
  }

  // Lấy tất cả thông báo
  Future<List<NotificationModel>> getNotifications(
      String userId,
      ) {
    return getAll(userId);
  }

  // Lấy thông báo theo ID
  Future<NotificationModel?> getNotification(
      String userId,
      String id,
      ) {
    return getById(userId, id);
  }

  // Sửa thông báo
  Future<void> updateNotification(
      NotificationModel notification,
      ) async {
    await update(
      notification.userId,
      notification.id,
      notification,
    );
  }

  // Xóa thông báo
  Future<void> deleteNotification(
      String userId,
      String id,
      ) async {
    await delete(userId, id);
  }

  // Lấy thông báo chưa đọc
  Future<List<NotificationModel>> getUnread(
      String userId,
      ) async {
    final notifications = await getAll(userId);

    return notifications
        .where((item) => !item.isRead)
        .toList();
  }

  // Lấy thông báo theo ngày
  Future<List<NotificationModel>> getByDate(
      String userId,
      DateTime date,
      ) async {
    final notifications = await getAll(userId);

    return notifications.where((item) {
      return item.createdAt.year == date.year &&
          item.createdAt.month == date.month &&
          item.createdAt.day == date.day;
    }).toList();
  }

  // Lấy thông báo theo tháng
  Future<List<NotificationModel>> getByMonth(
      String userId,
      int year,
      int month,
      ) async {
    final notifications = await getAll(userId);

    return notifications.where((item) {
      return item.createdAt.year == year &&
          item.createdAt.month == month;
    }).toList();
  }

  // Theo dõi thông báo
  Stream<List<NotificationModel>> watchNotifications(
      String userId,
      ) {
    return watchAll(userId);
  }
}
