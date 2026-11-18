import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/update/update_controller.dart';
import '../core/update/update_installer.dart';
import '../core/update/update_service.dart';
import '../theme/app_sizes.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_radius.dart';
import 'ui/ui.dart';

Future<void> showUpdateDialog(
  BuildContext context,
  WidgetRef ref,
  UpdateInfo info,
) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _UpdateDialog(info: info),
);

Future<void> checkForUpdates(BuildContext context, WidgetRef ref) async {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _CheckingDialog(),
  );
  await ref.read(updateControllerProvider.notifier).check(manual: true);
  if (!context.mounted) return;
  Navigator.of(context, rootNavigator: true).pop();
  final state = ref.read(updateControllerProvider);
  if (state case UpdateAvailable(:final info)) {
    await showUpdateDialog(context, ref, info);
  } else if (state case UpdateFailed(:final error)) {
    await showDialog<void>(
      context: context,
      builder: (_) => _CheckResultDialog(
        title: 'Check failed',
        message: error.message,
        onRetry: () => checkForUpdates(context, ref),
      ),
    );
  } else {
    await showDialog<void>(
      context: context,
      builder: (_) => const _CheckResultDialog(
        title: 'You\'re up to date',
        message: 'You have the latest HiveTube version.',
      ),
    );
  }
}

class _CheckingDialog extends StatelessWidget {
  const _CheckingDialog();
  @override
  Widget build(BuildContext context) => const AppDialog(
    title: 'Checking for updates',
    content: LinearProgressIndicator(),
  );
}

class _CheckResultDialog extends StatelessWidget {
  const _CheckResultDialog({
    required this.title,
    required this.message,
    this.onRetry,
  });
  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => AppDialog(
    title: title,
    content: Text(message, style: AppTextStyles.body),
    actions: [
      if (onRetry != null) AppButton.text(label: 'Retry', onPressed: onRetry),
      AppButton.text(label: 'Close', onPressed: () => Navigator.pop(context)),
    ],
  );
}

class _UpdateDialog extends ConsumerStatefulWidget {
  const _UpdateDialog({required this.info});
  final UpdateInfo info;

  @override
  ConsumerState<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends ConsumerState<_UpdateDialog>
    with WidgetsBindingObserver {
  final _installer = UpdateInstaller();
  final _dio = Dio();
  CancelToken? _cancelToken;
  bool _waitingPermission = false;
  bool _installing = false;
  bool _installLaunched = false;
  String? _readyPath;
  String? _currentVersion;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _currentVersion = info.version);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dio.close(force: true);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (_waitingPermission) {
      _waitingPermission = false;
      _resumeInstall();
    } else if (_installLaunched) {
      _verifyInstall();
    }
  }

  Future<void> _download() async {
    final url = widget.info.apkUrl;
    if (url == null) return;
    final token = CancelToken();
    _cancelToken = token;
    ref
        .read(updateControllerProvider.notifier)
        .setDownloading(0, widget.info.apkSize);
    try {
      final cache = await getTemporaryDirectory();
      final version = widget.info.version.replaceAll(RegExp(r'[^0-9.]'), '_');
      final file = File(
        '${cache.path}${Platform.pathSeparator}hivetube-$version.apk',
      );
      final part = File('${file.path}.part');
      if (await part.exists()) await part.delete();
      await _dio.download(
        url.toString(),
        part.path,
        cancelToken: token,
        onReceiveProgress: (received, total) => ref
            .read(updateControllerProvider.notifier)
            .setDownloading(received, total > 0 ? total : widget.info.apkSize),
      );
      final digest = widget.info.sha256;
      if (digest != null && digest.isNotEmpty) {
        final actual = sha256.convert(await part.readAsBytes()).toString();
        if (actual.toLowerCase() != digest.toLowerCase()) {
          await part.delete();
          throw const UpdateFailure(
            UpdateFailureKind.badResponse,
            'Downloaded APK failed its SHA-256 check.',
          );
        }
      }
      if (await file.exists()) await file.delete();
      final ready = await part.rename(file.path);
      _readyPath = ready.path;
      ref
          .read(updateControllerProvider.notifier)
          .setReady(widget.info, ready.path);
      await _launchInstaller();
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) {
        ref.read(updateControllerProvider.notifier).cancelDownload();
        return;
      }
      await _failDownload(error);
    } on UpdateFailure catch (error) {
      ref
          .read(updateControllerProvider.notifier)
          .setFailed(error, info: widget.info);
    } catch (error) {
      await _failDownload(error);
    } finally {
      _cancelToken = null;
    }
  }

  Future<void> _failDownload(Object error) async {
    final message =
        error is FileSystemException && error.osError?.errorCode == 28
        ? 'Not enough storage space to download the update.'
        : 'Download failed: $error';
    final cache = await getTemporaryDirectory();
    final version = widget.info.version.replaceAll(RegExp(r'[^0-9.]'), '_');
    final part = File(
      '${cache.path}${Platform.pathSeparator}hivetube-$version.apk.part',
    );
    if (await part.exists()) await part.delete();
    ref
        .read(updateControllerProvider.notifier)
        .setFailed(
          UpdateFailure(UpdateFailureKind.network, message),
          info: widget.info,
        );
  }

  Future<void> _launchInstaller() async {
    final path = _readyPath;
    if (path == null || _installing || !Platform.isAndroid) return;
    _installing = true;
    try {
      if (!await _installer.canRequestInstall()) {
        _waitingPermission = true;
        if (!mounted) return;
        final openSettings = await showDialog<bool>(
          context: context,
          builder: (context) => AppDialog(
            title: 'Allow app installs',
            content: const Text(
              'Allow HiveTube to install this update in Android settings, then return here.',
            ),
            actions: [
              AppButton.text(
                label: 'Later',
                onPressed: () => Navigator.pop(context, false),
              ),
              AppButton.filled(
                label: 'Settings',
                onPressed: () => Navigator.pop(context, true),
              ),
            ],
          ),
        );
        if (openSettings == true) {
          await _installer.openPermissionSettings();
        } else {
          _waitingPermission = false;
        }
        return;
      }
      await _installer.install(path);
      _installLaunched = true;
    } catch (error) {
      ref
          .read(updateControllerProvider.notifier)
          .setFailed(
            UpdateFailure(
              UpdateFailureKind.network,
              'Could not open installer: $error',
            ),
            info: widget.info,
          );
    } finally {
      _installing = false;
    }
  }

  Future<void> _resumeInstall() async {
    if (!mounted || _readyPath == null) return;
    if (await _installer.canRequestInstall()) {
      await _launchInstaller();
      _installLaunched = true;
    }
  }

  Future<void> _verifyInstall() async {
    final package = await PackageInfo.fromPlatform();
    if (_currentVersion != null && package.version != _currentVersion) {
      final file = File(_readyPath!);
      if (await file.exists()) await file.delete();
      ref.read(updateControllerProvider.notifier).reset();
    } else {
      _installLaunched = false;
      ref
          .read(updateControllerProvider.notifier)
          .setFailed(
            const UpdateFailure(
              UpdateFailureKind.http,
              'Installation was cancelled or failed. If Android reports a package conflict, the installed app and update may have different signing keys.',
            ),
            info: widget.info,
          );
    }
  }

  Future<void> _cancelWithConfirmation() async {
    final cancel = await showDialog<bool>(
      context: context,
      builder: (context) => AppDialog(
        title: 'Cancel download?',
        content: const Text(
          'The update download will stop.',
          style: AppTextStyles.body,
        ),
        actions: [
          AppButton.text(
            label: 'Continue',
            onPressed: () => Navigator.pop(context, false),
          ),
          AppButton.filled(
            label: 'Cancel download',
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    if (cancel == true) _cancelDownload();
  }

  void _cancelDownload() {
    _cancelToken?.cancel('Cancelled by user');
    ref.read(updateControllerProvider.notifier).cancelDownload();
  }

  Future<void> _openGitHub() async {
    await launchUrl(
      widget.info.releaseUrl,
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(updateControllerProvider);
    final downloading = state is UpdateDownloading;
    final ready = state is UpdateReady;
    final failed = state is UpdateFailed ? state : null;
    final available = !downloading && !ready && failed == null;
    final theme = Theme.of(context);
    return PopScope(
      canPop: !downloading,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && downloading) _cancelWithConfirmation();
      },
      child: AppDialog(
        title: switch (state) {
          UpdateDownloading() => 'Downloading update',
          UpdateReady() => 'Update ready',
          UpdateFailed() => 'Update failed',
          _ => null,
        },
        content: switch (state) {
          UpdateDownloading(:final received, :final total, :final progress) =>
            _downloadContent(received, total, progress, theme),
          UpdateReady() => const Text(
            'Opening Android installer…',
            style: AppTextStyles.body,
          ),
          UpdateFailed(:final error) => Text(
            error.message,
            style: AppTextStyles.body,
          ),
          _ => _availableContent(theme),
        },
        actions: available
            ? null
            : [
                if (failed != null) ...[
                  AppButton.text(
                    label: 'Close',
                    onPressed: () => Navigator.pop(context),
                  ),
                  AppButton.text(
                    label: 'Retry',
                    onPressed: _readyPath != null
                        ? _launchInstaller
                        : failed.info?.apkUrl == null
                        ? () => checkForUpdates(context, ref)
                        : _download,
                  ),
                ] else if (downloading) ...[
                  AppButton.text(label: 'Cancel', onPressed: _cancelDownload),
                ] else if (ready) ...[
                  AppButton.text(label: 'Open GitHub', onPressed: _openGitHub),
                  AppButton.filled(
                    label: 'Install now',
                    onPressed: _launchInstaller,
                  ),
                ],
              ],
      ),
    );
  }

  Widget _availableContent(ThemeData theme) => SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: AppRadius.xlBorder,
            ),
            child: Icon(
              Icons.system_update_rounded,
              size: AppSizes.iconLg,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        const Text(
          'Update available',
          textAlign: TextAlign.center,
          style: AppTextStyles.pageTitle,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'HiveTube ${widget.info.version} is ready',
          textAlign: TextAlign.center,
          style: AppTextStyles.body.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Version ${_currentVersion ?? 'installed'} → ${widget.info.version}',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyStrong,
        ),
        if (widget.info.apkSize != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Download: ${(widget.info.apkSize! / (1024 * 1024)).toStringAsFixed(1)} MB',
            textAlign: TextAlign.center,
            style: AppTextStyles.meta.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (widget.info.changelog.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: AppRadius.mdBorder,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('What’s new', style: AppTextStyles.bodyStrong),
                const SizedBox(height: AppSpacing.xs),
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: AppSizes.updateChangelogMaxHeight,
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      widget.info.changelog,
                      style: AppTextStyles.body.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        AppButton.filled(
          label: widget.info.apkUrl == null ? 'Open GitHub' : 'Update',
          size: AppButtonSize.large,
          onPressed: widget.info.apkUrl == null ? _openGitHub : _download,
        ),
        if (widget.info.apkUrl != null) ...[
          const SizedBox(height: AppSpacing.xs),
          AppButton.text(
            label: 'Later',
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ],
    ),
  );

  Widget _downloadContent(
    int received,
    int? total,
    double? progress,
    ThemeData theme,
  ) {
    final receivedMb = received / (1024 * 1024);
    final totalMb = total == null ? null : total / (1024 * 1024);
    final amount = totalMb == null
        ? '${receivedMb.toStringAsFixed(1)} MB'
        : '${receivedMb.toStringAsFixed(1)} / ${totalMb.toStringAsFixed(1)} MB';
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(value: progress),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '${progress == null ? '…' : '${(progress * 100).round()}%'} · $amount',
          style: AppTextStyles.meta.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
