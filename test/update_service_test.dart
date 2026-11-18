import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:hivetube/core/update/update_service.dart';

void main() {
  group('UpdateService version comparison', () {
    test('pads missing dotted parts', () {
      expect(
        UpdateService.compareVersions(
          UpdateService.parseVersion('v1.2.0')!,
          UpdateService.parseVersion('1.2')!,
        ),
        0,
      );
    });

    test('compares numeric parts as integers', () {
      expect(
        UpdateService.compareVersions(
          UpdateService.parseVersion('1.10')!,
          UpdateService.parseVersion('1.9')!,
        ),
        greaterThan(0),
      );
    });

    test('ignores build number', () {
      expect(UpdateService.parseVersion('v1.2.3+91'), [1, 2, 3]);
    });

    test('rejects invalid tags', () {
      expect(UpdateService.parseVersion('release-one'), isNull);
      expect(UpdateService.parseVersion('1.2.beta'), isNull);
    });
  });

  test('selects compatible APKs, including common for ARM64', () {
    const names = [
      'hivetube-x86_64.apk',
      'HiveTube_1.4.0_common.apk',
      'hivetube-universal.apk',
      'hivetube-arm64-v8a.apk',
      'notes.txt',
    ];
    expect(
      UpdateService.selectAssetName(names, ['arm64-v8a']),
      'hivetube-arm64-v8a.apk',
    );
    expect(
      UpdateService.selectAssetName(
        ['HiveTube_1.4.0_common.apk', 'HiveTube_1.4.0_universal.apk'],
        ['arm64-v8a', 'armeabi-v7a'],
      ),
      'HiveTube_1.4.0_common.apk',
    );
    expect(
      UpdateService.selectAssetName([
        'HiveTube_1.4.0_common.apk',
        'HiveTube_1.4.0_universal.apk',
      ], []),
      'HiveTube_1.4.0_universal.apk',
    );
    expect(
      UpdateService.selectAssetName(['HiveTube_1.4.0_common.apk'], ['x86_64']),
      isNull,
    );
    expect(
      UpdateService.selectAssetName(['notes.txt', 'hivetube.apk'], []),
      'hivetube.apk',
    );
  });

  group('UpdateService failure mapping', () {
    final packageInfo = PackageInfo(
      appName: 'HiveTube',
      packageName: 'com.hiveminds.hivetube',
      version: '1.0.0',
      buildNumber: '1',
    );

    test('maps a non-200 response to an HTTP failure', () async {
      final service = UpdateService(
        packageInfo: packageInfo,
        client: MockClient((_) async => http.Response('unavailable', 503)),
      );
      await expectLater(
        service.check(),
        throwsA(
          isA<UpdateFailure>().having(
            (failure) => failure.kind,
            'kind',
            UpdateFailureKind.http,
          ),
        ),
      );
    });

    test('maps an invalid release tag to a bad-tag failure', () async {
      final service = UpdateService(
        packageInfo: packageInfo,
        client: MockClient(
          (_) async => http.Response(jsonEncode({'tag_name': 'latest'}), 200),
        ),
      );
      await expectLater(
        service.check(),
        throwsA(
          isA<UpdateFailure>().having(
            (failure) => failure.kind,
            'kind',
            UpdateFailureKind.badTag,
          ),
        ),
      );
    });

    test('maps client exceptions to a network failure', () async {
      final service = UpdateService(
        packageInfo: packageInfo,
        client: MockClient((_) async => throw http.ClientException('offline')),
      );
      await expectLater(
        service.check(),
        throwsA(
          isA<UpdateFailure>().having(
            (failure) => failure.kind,
            'kind',
            UpdateFailureKind.network,
          ),
        ),
      );
    });
  });
}
