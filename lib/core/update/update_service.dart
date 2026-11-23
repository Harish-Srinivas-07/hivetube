import 'dart:async';
import 'dart:convert';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

const githubLatestReleaseApi =
    'https://api.github.com/repos/Harish-Srinivas-07/hivetube/releases/latest';
const githubLatestReleasePage =
    'https://github.com/Harish-Srinivas-07/hivetube/releases/latest';

@immutable
class UpdateInfo {
  const UpdateInfo({
    required this.available,
    required this.version,
    required this.releaseUrl,
    required this.apkUrl,
    required this.apkSize,
    required this.changelog,
    this.sha256,
  });

  final bool available;
  final String version;
  final Uri releaseUrl;
  final Uri? apkUrl;
  final int? apkSize;
  final String changelog;
  final String? sha256;
}

enum UpdateFailureKind { network, http, badResponse, badTag }

@immutable
class UpdateFailure implements Exception {
  const UpdateFailure(this.kind, this.message);

  final UpdateFailureKind kind;
  final String message;

  @override
  String toString() => message;
}

class UpdateService {
  UpdateService({http.Client? client, this.packageInfo})
    : _client = client ?? http.Client();

  final http.Client _client;
  final PackageInfo? packageInfo;

  void close() => _client.close();

  Future<UpdateInfo> check() async {
    try {
      final response = await _client
          .get(
            Uri.parse(githubLatestReleaseApi),
            headers: const {'Accept': 'application/vnd.github+json'},
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        throw UpdateFailure(
          UpdateFailureKind.http,
          'GitHub returned HTTP ${response.statusCode}.',
        );
      }

      final json = jsonDecode(response.body);
      if (json is! Map<String, dynamic>) {
        throw const UpdateFailure(
          UpdateFailureKind.badResponse,
          'GitHub returned an invalid release response.',
        );
      }
      final tag = json['tag_name'];
      if (tag is! String || parseVersion(tag) == null) {
        throw const UpdateFailure(
          UpdateFailureKind.badTag,
          'GitHub release has an invalid version tag.',
        );
      }
      final current = packageInfo ?? await PackageInfo.fromPlatform();
      final releaseVersion = parseVersion(tag)!;
      final currentVersion = parseVersion(current.version);
      if (currentVersion == null) {
        throw const UpdateFailure(
          UpdateFailureKind.badTag,
          'Installed app version is invalid.',
        );
      }

      final assets = json['assets'];
      final asset = await _pickAsset(assets is List ? assets : const []);
      final releaseString = json['html_url'];
      final releaseUrl = releaseString is String
          ? Uri.tryParse(releaseString)
          : null;
      final uri = releaseUrl != null && _isGitHubReleasePage(releaseUrl)
          ? releaseUrl
          : Uri.parse(githubLatestReleasePage);
      return UpdateInfo(
        available: compareVersions(releaseVersion, currentVersion) > 0,
        version: tag.replaceFirst(RegExp(r'^[vV]'), ''),
        releaseUrl: uri,
        apkUrl: asset?.url,
        apkSize: asset?.size,
        changelog: json['body'] is String ? json['body'] as String : '',
        sha256: asset?.sha256,
      );
    } on UpdateFailure {
      rethrow;
    } on TimeoutException {
      throw const UpdateFailure(
        UpdateFailureKind.network,
        'GitHub update check timed out.',
      );
    } on http.ClientException catch (error) {
      throw UpdateFailure(UpdateFailureKind.network, error.message);
    } on FormatException {
      throw const UpdateFailure(
        UpdateFailureKind.badResponse,
        'GitHub returned invalid release data.',
      );
    } catch (error) {
      throw UpdateFailure(UpdateFailureKind.network, error.toString());
    }
  }

  Future<_ApkAsset?> _pickAsset(List<dynamic> rawAssets) async {
    final assets = rawAssets
        .whereType<Map<String, dynamic>>()
        .map((json) {
          final name = json['name'];
          final url = json['browser_download_url'];
          final parsedUrl = url is String ? Uri.tryParse(url) : null;
          if (name is! String || !name.toLowerCase().endsWith('.apk')) {
            return null;
          }
          if (parsedUrl == null || !_isGitHub(parsedUrl)) return null;
          final digest = json['digest'];
          return _ApkAsset(
            name,
            parsedUrl,
            json['size'] is int ? json['size'] as int : null,
            digest is String && digest.startsWith('sha256:')
                ? digest.substring('sha256:'.length).toLowerCase()
                : null,
          );
        })
        .whereType<_ApkAsset>()
        .toList();
    if (assets.isEmpty) return null;

    final abis = await _supportedAbis();
    final selectedName = selectAssetName(
      assets.map((asset) => asset.name),
      abis,
    );
    if (selectedName == null) return null;
    return assets.firstWhere((asset) => asset.name == selectedName);
  }

  Future<List<String>> _supportedAbis() async {
    try {
      return (await DeviceInfoPlugin().androidInfo).supportedAbis;
    } catch (_) {
      return const [];
    }
  }

  static List<int>? parseVersion(String value) {
    var normalized = value.trim().replaceFirst(RegExp(r'^[vV]'), '');
    normalized = normalized.split('+').first;
    if (normalized.isEmpty || !RegExp(r'^\d+(\.\d+)*$').hasMatch(normalized)) {
      return null;
    }
    return normalized.split('.').map(int.parse).toList();
  }

  static int compareVersions(List<int> left, List<int> right) {
    final length = left.length > right.length ? left.length : right.length;
    for (var index = 0; index < length; index++) {
      final a = index < left.length ? left[index] : 0;
      final b = index < right.length ? right[index] : 0;
      if (a != b) return a.compareTo(b);
    }
    return 0;
  }

  static String? selectAssetName(
    Iterable<String> names,
    Iterable<String> abis,
  ) {
    final apks = names
        .where((name) => name.toLowerCase().endsWith('.apk'))
        .toList();
    for (final abi in abis) {
      for (final name in apks) {
        if (name.toLowerCase().contains(abi.toLowerCase())) return name;
      }
      if (abi.toLowerCase() == 'arm64-v8a') {
        for (final name in apks) {
          if (RegExp(
            r'(^|[_-])common\.apk$',
            caseSensitive: false,
          ).hasMatch(name)) {
            return name;
          }
        }
      }
    }
    for (final name in apks) {
      if (RegExp(r'universal|\ball\b', caseSensitive: false).hasMatch(name)) {
        return name;
      }
    }
    return apks
        .where(
          (name) => !RegExp(
            r'(^|[_-])(common|arm64-v8a|armeabi-v7a|x86_64|x86)\.apk$',
            caseSensitive: false,
          ).hasMatch(name),
        )
        .firstOrNull;
  }

  static bool _isGitHub(Uri uri) =>
      uri.scheme == 'https' &&
      (uri.host == 'github.com' || uri.host == 'objects.githubusercontent.com');

  static bool _isGitHubReleasePage(Uri uri) =>
      uri.scheme == 'https' && uri.host == 'github.com';
}

class _ApkAsset {
  const _ApkAsset(this.name, this.url, this.size, this.sha256);

  final String name;
  final Uri url;
  final int? size;
  final String? sha256;
}
