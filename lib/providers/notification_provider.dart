
import 'package:flutter/material.dart';

import '../models/notification_model.dart';
import '../repositories/notification_repository.dart';

class NotificationProvider extends ChangeNotifier {
  final NotificationRepository _repository =
  NotificationRepository();

  List<NotificationModel> notifications = [];

  bool isLoading = false;
  String? error;

  Future<void> loadNotifications(String userId) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      notifications =
      await _repository.getNotifications(userId);
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadByDate(
      String userId,
      DateTime date,
      ) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      notifications = await _repository.getByDate(
        userId,
        date,
      );
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadByMonth(
      String userId,
      int year,
      int month,
      ) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      notifications = await _repository.getByMonth(
        userId,
        year,
        month,
      );
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addNotification(
      NotificationModel notification,
      ) async {
    await _repository.addNotification(notification);
    await loadNotifications(notification.userId);
  }

  Future<void> updateNotification(
      NotificationModel notification,
      ) async {
    await _repository.updateNotification(notification);
    await loadNotifications(notification.userId);
  }

  Future<void> deleteNotification(
      String userId,
      String notificationId,
      ) async {
    await _repository.deleteNotification(
      userId,
      notificationId,
    );
    await loadNotifications(userId);
  }

  int get unreadCount {
    return notifications.where(
          (notification) => !notification.isRead,
    ).length;
  }

  void clear() {
    notifications = [];
    error = null;
    notifyListeners();
  }
}
