import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

/// E2E real (emuladores): createOrder → upload Storage → attach photoUrls →
/// leitura cliente/pro → negação a estranho → delete.
///
/// Requer Auth :9099, Firestore :8080, Storage :9199.
/// Ex.: `npx firebase-tools@latest emulators:exec --only auth,firestore,storage "flutter test test/order_photos_emulator_e2e_test.dart"`

class _AllowHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (_, __, ___) => true;
  }
}

const _projectId = 'carajas360-a17c5';
const _bucket = 'carajas360-a17c5.firebasestorage.app';
const _apiKey = 'fake-api-key';

Future<bool> _portOpen(int port) async {
  try {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
    final req = await client.getUrl(
      Uri(scheme: 'http', host: '127.0.0.1', port: port, path: '/'),
    );
    final res = await req.close().timeout(const Duration(seconds: 3));
    await res.drain<void>();
    client.close(force: true);
    return true;
  } catch (_) {
    return false;
  }
}

Future<Map<String, dynamic>> _httpJson(
  String method,
  Uri uri,
  Object? body, {
  String? bearer,
  String? contentType,
  bool expectError = false,
}) async {
  final client = HttpClient();
  try {
    final req = await client.openUrl(method, uri);
    if (contentType != null) {
      req.headers.set(HttpHeaders.contentTypeHeader, contentType);
    } else if (body is Map || body is List) {
      req.headers.contentType = ContentType.json;
    }
    if (bearer != null) {
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $bearer');
    }
    if (body is List<int>) {
      req.add(body);
    } else if (body != null) {
      req.write(jsonEncode(body));
    }
    final res = await req.close();
    final text = await res.transform(utf8.decoder).join();
    final decoded = text.isEmpty
        ? <String, dynamic>{}
        : (jsonDecode(text) is Map
            ? Map<String, dynamic>.from(jsonDecode(text) as Map)
            : <String, dynamic>{'raw': text});
    final ok = res.statusCode >= 200 && res.statusCode < 300;
    if (expectError) {
      if (ok) {
        throw StateError('Expected HTTP error, got ${res.statusCode}: $text');
      }
      return {'statusCode': res.statusCode, 'body': decoded};
    }
    if (!ok) {
      throw HttpException('HTTP ${res.statusCode}: $text', uri: uri);
    }
    return decoded;
  } finally {
    client.close(force: true);
  }
}

Future<int> _httpStatus(
  String method,
  Uri uri, {
  String? bearer,
  Object? body,
  String? contentType,
}) async {
  final client = HttpClient();
  try {
    final req = await client.openUrl(method, uri);
    if (contentType != null) {
      req.headers.set(HttpHeaders.contentTypeHeader, contentType);
    } else if (body is Map) {
      req.headers.contentType = ContentType.json;
    }
    if (bearer != null) {
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $bearer');
    }
    if (body is List<int>) {
      req.add(body);
    } else if (body != null) {
      req.write(jsonEncode(body));
    }
    final res = await req.close();
    await res.drain<void>();
    return res.statusCode;
  } finally {
    client.close(force: true);
  }
}

Future<({String uid, String token})> _signUp(String email) async {
  final res = await _httpJson(
    'POST',
    Uri.parse(
      'http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signUp?key=$_apiKey',
    ),
    {
      'email': email,
      'password': 'Senha123!',
      'returnSecureToken': true,
    },
  );
  return (uid: res['localId'] as String, token: res['idToken'] as String);
}

/// Minimal JPEG (1x1) — válido para content-type image/jpeg.
Uint8List get _tinyJpeg => Uint8List.fromList([
      0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01,
      0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0xFF, 0xDB, 0x00, 0x43,
      0x00, 0x08, 0x06, 0x06, 0x07, 0x06, 0x05, 0x08, 0x07, 0x07, 0x07, 0x09,
      0x09, 0x08, 0x0A, 0x0C, 0x14, 0x0D, 0x0C, 0x0B, 0x0B, 0x0C, 0x19, 0x12,
      0x13, 0x0F, 0x14, 0x1D, 0x1A, 0x1F, 0x1E, 0x1D, 0x1A, 0x1C, 0x1C, 0x20,
      0x24, 0x2E, 0x27, 0x20, 0x22, 0x2C, 0x23, 0x1C, 0x1C, 0x28, 0x37, 0x29,
      0x2C, 0x30, 0x31, 0x34, 0x34, 0x34, 0x1F, 0x27, 0x39, 0x3D, 0x38, 0x32,
      0x3C, 0x2E, 0x33, 0x34, 0x32, 0xFF, 0xC0, 0x00, 0x0B, 0x08, 0x00, 0x01,
      0x00, 0x01, 0x01, 0x01, 0x11, 0x00, 0xFF, 0xC4, 0x00, 0x14, 0x00, 0x01,
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
      0x00, 0x00, 0x00, 0x03, 0xFF, 0xC4, 0x00, 0x14, 0x10, 0x01, 0x00, 0x00,
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
      0x00, 0x00, 0xFF, 0xDA, 0x00, 0x08, 0x01, 0x01, 0x00, 0x00, 0x3F, 0x00,
      0x37, 0xFF, 0xD9,
    ]);

void _pass(String step) {
  // ignore: avoid_print
  print('PASS: $step');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = _AllowHttpOverrides();

  test('order photos: upload + attach + ACL + delete (emulators)', () async {
    final ok = await _portOpen(9099) &&
        await _portOpen(8080) &&
        await _portOpen(9199);
    if (!ok) {
      markTestSkipped(
        'Emulators Auth:9099 / Firestore:8080 / Storage:9199 not reachable',
      );
      return;
    }

    final ts = DateTime.now().millisecondsSinceEpoch;
    final client = await _signUp('client_photos_$ts@test.com');
    final provider = await _signUp('pro_photos_$ts@test.com');
    final stranger = await _signUp('stranger_photos_$ts@test.com');
    _pass('auth: client=${client.uid} provider=${provider.uid}');

    final orderId = 'ord_photos_$ts';
    final orderUri = Uri.parse(
      'http://127.0.0.1:8080/v1/projects/$_projectId/databases/(default)/documents/orders/$orderId',
    );

    await _httpJson(
      'PATCH',
      orderUri,
      {
        'fields': {
          'clientId': {'stringValue': client.uid},
          'providerId': {'stringValue': provider.uid},
          'status': {'stringValue': 'pending'},
          'paymentStatus': {'stringValue': 'unpaid'},
          'payoutProcessed': {'booleanValue': false},
          'category': {'stringValue': 'eletrica'},
          'title': {'stringValue': 'Troca de tomada'},
          'description': {
            'stringValue': 'Ambiente com tomada danificada na sala.',
          },
          'address': {'stringValue': 'Rua Teste 100'},
          'urgent': {'booleanValue': false},
          'siteVisitRequested': {'booleanValue': true},
          'photoUrls': {
            'arrayValue': {'values': []},
          },
          'photoCount': {'integerValue': '0'},
          'type': {'stringValue': 'service'},
        },
      },
      bearer: client.token,
    );
    _pass('firestore: orders/$orderId created (pending + visita)');

    final objectPath =
        'orders/$orderId/photos/${ts}_${client.uid}.jpg';
    final encodedName = Uri.encodeComponent(objectPath);
    final uploadUri = Uri.parse(
      'http://127.0.0.1:9199/v0/b/$_bucket/o?name=$encodedName',
    );
    final upload = await _httpJson(
      'POST',
      uploadUri,
      _tinyJpeg,
      bearer: client.token,
      contentType: 'image/jpeg',
    );
    expect(upload['name'], objectPath);
    _pass('storage: uploaded $objectPath');

    final mediaUri = Uri.parse(
      'http://127.0.0.1:9199/v0/b/$_bucket/o/$encodedName?alt=media',
    );
    final clientRead = await _httpStatus('GET', mediaUri, bearer: client.token);
    expect(clientRead, anyOf(200, 206));
    _pass('storage: client can read photo ($clientRead)');

    final providerRead =
        await _httpStatus('GET', mediaUri, bearer: provider.token);
    expect(providerRead, anyOf(200, 206));
    _pass('storage: provider can read photo ($providerRead)');

    final strangerRead =
        await _httpStatus('GET', mediaUri, bearer: stranger.token);
    expect(strangerRead, anyOf(403, 401));
    _pass('storage: stranger denied ($strangerRead)');

    final downloadUrl =
        'http://127.0.0.1:9199/v0/b/$_bucket/o/$encodedName?alt=media&token=emulator';
    await _httpJson(
      'PATCH',
      Uri.parse('$orderUri?updateMask.fieldPaths=photoUrls&updateMask.fieldPaths=photoCount&updateMask.fieldPaths=siteVisitRequested'),
      {
        'fields': {
          'photoUrls': {
            'arrayValue': {
              'values': [
                {'stringValue': downloadUrl},
              ],
            },
          },
          'photoCount': {'integerValue': '1'},
          'siteVisitRequested': {'booleanValue': true},
        },
      },
      bearer: client.token,
    );
    final snap = await _httpJson('GET', orderUri, null, bearer: client.token);
    final fields = snap['fields'] as Map<String, dynamic>;
    final urls = (((fields['photoUrls'] as Map)['arrayValue']
        as Map)['values'] as List);
    expect(urls, hasLength(1));
    expect((fields['photoCount'] as Map)['integerValue'], '1');
    expect((fields['siteVisitRequested'] as Map)['booleanValue'], isTrue);
    _pass('firestore: photoUrls/photoCount/siteVisit associated');

    final proOrder =
        await _httpJson('GET', orderUri, null, bearer: provider.token);
    expect(proOrder['fields'], isNotNull);
    _pass('firestore: provider can view order with photos');

    final strangerOrder = await _httpStatus('GET', orderUri, bearer: stranger.token);
    expect(strangerOrder, anyOf(403, 401));
    _pass('firestore: stranger cannot view order ($strangerOrder)');

    final delStatus =
        await _httpStatus('DELETE', Uri.parse(
          'http://127.0.0.1:9199/v0/b/$_bucket/o/$encodedName',
        ), bearer: client.token);
    expect(delStatus, anyOf(200, 204));
    _pass('storage: client deleted photo ($delStatus)');

    // ignore: avoid_print
    print('E2E_ORDER_PHOTOS_OK orderId=$orderId object=$objectPath');
  }, timeout: const Timeout(Duration(minutes: 2)));
}
