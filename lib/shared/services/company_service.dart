import '../models/models.dart';
import 'firestore_facade.dart';

abstract final class CompanyService {
  static Future<void> saveCompany(CompanyModel c) => FS.saveCompany(c);
  static Future<CompanyModel?> getCompanyByOwner(String ownerId) =>
      FS.getCompanyByOwner(ownerId);
  static Stream<CompanyModel?> companyStream(String id) => FS.companyStream(id);
}
