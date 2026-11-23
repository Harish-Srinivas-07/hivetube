import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../providers.dart';
import 'update_service.dart';

sealed class UpdateState {
  const UpdateState();
}

class UpdateIdle extends UpdateState {
  const UpdateIdle();
}

class UpdateChecking extends UpdateState {
  const UpdateChecking();
}

class UpdateUpToDate extends UpdateState {
  const UpdateUpToDate(this.info);
  final UpdateInfo info;
}

class UpdateAvailable extends UpdateState {
  const UpdateAvailable(this.info, {this.automatic = false});
  final UpdateInfo info;
  final bool automatic;
}

class UpdateDownloading extends UpdateState {
  const UpdateDownloading({required this.received, this.total});
  final int received;
  final int? total;
  double? get progress =>
      total == null || total == 0 ? null : received / total!;
}

class UpdateReady extends UpdateState {
  const UpdateReady(this.info, this.path);
  final UpdateInfo info;
  final String path;
}

class UpdateFailed extends UpdateState {
  const UpdateFailed(this.error, {this.info});
  final UpdateFailure error;
  final UpdateInfo? info;
}

final updateServiceProvider = Provider<UpdateService>((ref) {
  final service = UpdateService();
  ref.onDispose(service.close);
  return service;
});

Future<bool> updateConnectionAvailable(WidgetRef ref) async {
  final subscription = ref.listenManual(connectivityProvider, (_, _) {});
  try {
    final connections = await ref.read(connectivityProvider.future);
    return connections.any(
      (connection) => connection != ConnectivityResult.none,
    );
  } catch (_) {
    return false;
  } finally {
    subscription.close();
  }
}

final updateControllerProvider =
    NotifierProvider<UpdateController, UpdateState>(UpdateController.new);

class UpdateController extends Notifier<UpdateState> {
  Future<void>? _activeCheck;

  @override
  UpdateState build() => const UpdateIdle();

  Future<void> check({bool manual = false}) async {
    if (state is UpdateChecking) {
      await _activeCheck;
      if (!manual) return;
    }
    final check = _performCheck(manual);
    _activeCheck = check;
    try {
      await check;
    } finally {
      if (identical(_activeCheck, check)) _activeCheck = null;
    }
  }

  Future<void> _performCheck(bool manual) async {
    state = const UpdateChecking();
    try {
      final info = await ref.read(updateServiceProvider).check();
      state = info.available
          ? UpdateAvailable(info, automatic: !manual)
          : UpdateUpToDate(info);
    } on UpdateFailure catch (error) {
      state = UpdateFailed(error);
    } catch (error) {
      state = UpdateFailed(
        UpdateFailure(UpdateFailureKind.network, error.toString()),
      );
    }
  }

  void setDownloading(int received, int? total) {
    state = UpdateDownloading(received: received, total: total);
  }

  void setReady(UpdateInfo info, String path) =>
      state = UpdateReady(info, path);

  void setFailed(UpdateFailure error, {UpdateInfo? info}) =>
      state = UpdateFailed(error, info: info);

  void cancelDownload() => state = const UpdateIdle();

  void reset() => state = const UpdateIdle();
}
