import 'dart:typed_data';

import 'firestore_facade.dart';

abstract final class StorageService {
  static Future<String?> uploadUserPhoto(Uint8List bytes, String fileName) =>
      FS.uploadUserPhoto(bytes, fileName);
  static Future<String?> uploadProviderFile(
          Uint8List bytes, String fileName, String kind) =>
      FS.uploadProviderFile(bytes, fileName, kind);
}
