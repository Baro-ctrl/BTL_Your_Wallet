import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class MomentImageService {
  final FirebaseStorage _storage;

  MomentImageService({FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instance;

  static bool isRemoteUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null && (uri.scheme == 'https' || uri.scheme == 'http');
  }

  Future<String> upload({
    required String userId,
    required String transactionId,
    required String localPath,
  }) async {
    final file = File(localPath);
    if (!await file.exists()) {
      throw FileSystemException('Không tìm thấy ảnh đã chọn.', localPath);
    }
    if (await file.length() > 10 * 1024 * 1024) {
      throw StateError('Ảnh không được vượt quá 10 MB.');
    }

    final extension = path.extension(localPath).toLowerCase();
    final contentType = switch (extension) {
      '.jpg' || '.jpeg' => 'image/jpeg',
      '.png' => 'image/png',
      '.webp' => 'image/webp',
      _ => throw FormatException('Chỉ hỗ trợ ảnh JPG, PNG hoặc WebP.'),
    };

    final ref = _storage.ref().child(
      'users/$userId/transactions/$transactionId/'
      'moment_${DateTime.now().microsecondsSinceEpoch}$extension',
    );

    await ref.putFile(file, SettableMetadata(contentType: contentType));
    return ref.getDownloadURL();
  }

  Future<void> deleteRemote(String? imageUrl) async {
    if (imageUrl == null || !isRemoteUrl(imageUrl)) return;
    await _storage.refFromURL(imageUrl).delete();
  }

  Future<void> deleteImage(String? imagePath) async {
    if (imagePath == null) return;
    if (isRemoteUrl(imagePath)) {
      await deleteRemote(imagePath);
    } else {
      await deleteLocal(imagePath);
    }
  }

  Future<void> deleteLocal(String imagePath) async {
    final appDirectory = await getApplicationDocumentsDirectory();
    final root = path.normalize(path.absolute(appDirectory.path));
    final target = path.normalize(path.absolute(imagePath));
    if (!path.isWithin(root, target)) return;

    final file = File(target);
    if (await file.exists()) await file.delete();
  }

  Future<void> deleteIfReplaced({
    required String? oldImageUrl,
    required String? newImageUrl,
  }) async {
    if (oldImageUrl == null) return;
    if (!isRemoteUrl(oldImageUrl)) {
      if (oldImageUrl != newImageUrl) await deleteLocal(oldImageUrl);
      return;
    }

    final oldRef = _storage.refFromURL(oldImageUrl);
    if (newImageUrl != null && isRemoteUrl(newImageUrl)) {
      final newRef = _storage.refFromURL(newImageUrl);
      if (oldRef.fullPath == newRef.fullPath) return;
    }

    await oldRef.delete();
  }
}
