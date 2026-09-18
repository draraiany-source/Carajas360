import '../models/models.dart';
import 'firestore_facade.dart';

/// Fachada de perfil. Implementação atual em [FS] (próximo corte move o corpo).
abstract final class UserService {
  static Future<void> saveUser(UserModel u) => FS.saveUser(u);
  static Future<UserModel?> getUser([String? id]) => FS.getUser(id);
  static Stream<UserModel?> userStream([String? id]) => FS.userStream(id);
  static Future<void> updateUser(Map<String, dynamic> data) =>
      FS.updateUser(data);
  static Future<Map<String, dynamic>> exportMyData() => FS.exportMyData();
  static Future<void> deleteMyAccountData() => FS.deleteMyAccountData();
  static Future<bool> switchProfileType(String type) =>
      FS.switchProfileType(type);
}
