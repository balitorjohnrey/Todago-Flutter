import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class ProfilePhotoService {
  static const passengerPhotoKey = 'passenger_profile_photo_path';
  static const driverPhotoKey = 'driver_profile_photo_path';

  static const _storage = FlutterSecureStorage();
  static final ImagePicker _picker = ImagePicker();

  static Future<String?> getPhotoPath(String key) async {
    final path = await _storage.read(key: key);
    if (path == null || path.isEmpty) return null;
    return File(path).existsSync() ? path : null;
  }

  static Future<String?> pickAndSavePhoto(String key) async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 86,
    );
    if (picked == null) return null;

    final supportDir = await getApplicationSupportDirectory();
    final photosDir = Directory(
      '${supportDir.path}${Platform.pathSeparator}profile_photos',
    );
    await photosDir.create(recursive: true);

    final ext = _extensionFor(picked.path);
    final destination = File(
      '${photosDir.path}${Platform.pathSeparator}$key$ext',
    );
    await File(picked.path).copy(destination.path);
    await _storage.write(key: key, value: destination.path);
    return destination.path;
  }

  static Future<void> removePhoto(String key) async {
    final path = await _storage.read(key: key);
    if (path != null && path.isNotEmpty) {
      final file = File(path);
      if (file.existsSync()) {
        await file.delete();
      }
    }
    await _storage.delete(key: key);
  }

  static String _extensionFor(String path) {
    final dot = path.lastIndexOf('.');
    if (dot == -1 || dot == path.length - 1) return '.jpg';
    final ext = path.substring(dot).toLowerCase();
    return ext.length <= 5 ? ext : '.jpg';
  }
}
