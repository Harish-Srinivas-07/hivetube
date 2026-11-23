import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/watch/watch_panel.dart';
import '../../widgets/logger.dart';
import '../settings/app_settings.dart';
import '../streams/stream_selector.dart';
import 'playback_service.dart';

final pictureInPictureProvider =
    NotifierProvider<PictureInPictureController, bool>(
      PictureInPictureController.new,
    );

class PictureInPictureController extends Notifier<bool> {
  static const _channel = MethodChannel('hivetube/picture_in_picture');
  bool entering = false;
  bool _backgroundPending = false;
  Rect? _sourceRect;
  Timer? _backgroundDebounce;
  @visibleForTesting
  bool isSupportedPlatform = Platform.isAndroid;

  bool get eligible {
    final service = ref.read(playbackProvider);
    final settings = ref.read(appSettingsProvider);
    return settings.pictureInPicture &&
        ref.read(watchPanelProvider) != null &&
        !settings.audioOnly &&
        service?.state.mode == PlaybackMode.video &&
        service?.state.playing == true;
  }

  Future<bool> enter() async {
    if (!isSupportedPlatform || !eligible) return false;
    try {
      entering = true;
      final result = await _channel.invokeMethod<bool>('enter');
      if (result != true) {
        entering = false;
      }
      return result ?? false;
    } on PlatformException catch (e) {
      entering = false;
      Logger.log('PiP', 'enter failed: $e');
      return false;
    }
  }

  void updateSourceRect(Rect? rect) {
    if (_sourceRect == rect) return;
    _sourceRect = rect;
    if (eligible) {
      _sync();
    }
  }

  @override
  bool build() {
    if (!Platform.isAndroid) return false;
    _channel.setMethodCallHandler(_handleMethod);
    ref.listen(playbackProvider, (_, _) => _sync());
    ref.listen(appSettingsProvider, (_, _) => _sync());
    ref.listen(watchPanelProvider, (_, _) => _sync());
    ref.onDispose(() {
      _backgroundDebounce?.cancel();
      _channel.setMethodCallHandler(null);
    });
    scheduleMicrotask(_sync);
    return false;
  }

  void _sync() {
    final service = ref.read(playbackProvider);
    final width = service?.controller.player.state.width;
    final height = service?.controller.player.state.height;
    final aspect = width != null && width > 0 && height != null && height > 0
        ? width / height
        : 16 / 9;
    final args = <String, dynamic>{
      'eligible': eligible,
      'playing': service?.state.playing == true,
      'aspect': aspect,
    };
    final rect = _sourceRect;
    if (rect != null && rect.width > 0 && rect.height > 0) {
      args['sourceRect'] = {
        'left': rect.left.round(),
        'top': rect.top.round(),
        'right': rect.right.round(),
        'bottom': rect.bottom.round(),
      };
    }
    unawaited(
      _channel
          .invokeMethod<void>('update', args)
          .catchError((Object error) => Logger.log('PiP', error)),
    );
  }

  Future<void> _handleMethod(MethodCall call) async {
    switch (call.method) {
      case 'entering':
        entering = true;
      case 'changed':
        entering = false;
        state = call.arguments == true;
        if (state) {
          _backgroundPending = false;
          _backgroundDebounce?.cancel();
        }
        if (!state && _backgroundPending) {
          _backgroundPending = false;
          if (WidgetsBinding.instance.lifecycleState !=
              AppLifecycleState.resumed) {
            _backgroundWithoutPip();
          }
        }
      case 'backgroundWithoutPip':
        if (state || entering || eligible) {
          _backgroundPending = true;
        } else {
          _backgroundWithoutPip();
        }
      case 'playPause':
        final service = ref.read(playbackProvider);
        if (service != null) {
          if (service.state.playing) {
            await service.pause();
          } else {
            await service.resume();
          }
        }
    }
  }

  void _backgroundWithoutPip() {
    if (state || entering) return;
    _backgroundDebounce?.cancel();
    _backgroundDebounce = Timer(const Duration(milliseconds: 350), () {
      if (state || entering) return;
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        return;
      }
      final service = ref.read(playbackProvider);
      final settings = ref.read(appSettingsProvider);
      final isAudioMode = settings.audioOnly ||
          service?.state.mode == PlaybackMode.audio ||
          (service?.audioOnlyPreference?.call() ?? false);
      if (isAudioMode) {
        return;
      }
      if (settings.backgroundPlay) {
        unawaited(service?.enterBackgroundAudioMode());
      } else {
        unawaited(service?.pause());
      }
    });
  }
}
