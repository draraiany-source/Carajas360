import '../models/models.dart';
import 'firestore_facade.dart';

abstract final class ProviderService {
  static Stream<List<ProviderModel>> providersStream(
          {String? category, int limit = 20}) =>
      FS.providersStream(category: category, limit: limit);
  static Future<void> createProviderProfile({
    required String userId,
    required String name,
    required List<String> categories,
    String? city,
    List<String> modalities = const ['presential'],
    double? minPrice,
    String? photoUrl,
    String? documentUrl,
    String? selfieUrl,
    List<String> certificates = const [],
    List<String> serviceAreas = const [],
  }) =>
      FS.createProviderProfile(
        userId: userId,
        name: name,
        categories: categories,
        city: city,
        modalities: modalities,
        minPrice: minPrice,
        photoUrl: photoUrl,
        documentUrl: documentUrl,
        selfieUrl: selfieUrl,
        certificates: certificates,
        serviceAreas: serviceAreas,
      );
  static Stream<ProviderModel?> myProviderStream() => FS.myProviderStream();
  static Future<void> setProviderOnline(String providerId, bool online) =>
      FS.setProviderOnline(providerId, online);
}
