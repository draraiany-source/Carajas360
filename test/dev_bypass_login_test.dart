import 'package:flutter_test/flutter_test.dart';
import 'package:carajas_360/core/auth/dev_bypass_auth.dart';
import 'package:carajas_360/core/constants/runtime_config.dart';
import 'package:carajas_360/shared/models/models.dart';

void main() {
  test('DEV_BYPASS_LOGIN default é false', () {
    expect(RuntimeConfig.devBypassLoginDefine, isFalse);
  });

  test('release ignora a flag mesmo com define true', () {
    expect(
      DevBypassAuth.enabledFor(releaseMode: true, defineOn: true),
      isFalse,
    );
    expect(
      DevBypassAuth.enabledFor(releaseMode: true, defineOn: false),
      isFalse,
    );
  });

  test('debug só liga com define true', () {
    expect(
      DevBypassAuth.enabledFor(releaseMode: false, defineOn: true),
      isTrue,
    );
    expect(
      DevBypassAuth.enabledFor(releaseMode: false, defineOn: false),
      isFalse,
    );
  });

  test('mock user é client comum — nunca admin', () {
    final u = DevBypassAuth.mockUser;
    expect(u.id, 'dev-bypass-user');
    expect(u.type, UserType.client);
    expect(u.type, isNot(UserType.admin));
    expect(u.adminRole, isNull);
    expect(u.roles, isNot(contains('admin')));
    expect(u.verified, isFalse);
    expect(u.plan, PlanTier.free);
  });
}
