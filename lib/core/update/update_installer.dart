import 'dart:io';

import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';

class UpdateInstaller {
  static const _channel = MethodChannel('hivetube/update_install');

  Future<bool> canRequestInstall() async =>
      await _channel.invokeMethod<bool>('canRequestInstall') ?? false;

  Future<void> openPermissionSettings() =>
      _channel.invokeMethod<void>('openPermissionSettings');

  Future<void> install(String path) async {
    if (!Platform.isAndroid) return;
    final result = await OpenFilex.open(
      path,
      type: 'application/vnd.android.package-archive',
    );
    if (result.type != ResultType.done) {
      throw FileSystemException(result.message, path);
    }
  }
}
