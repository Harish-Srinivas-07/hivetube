import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  bool get eligible {
    final service = ref.read(playbackProvider);
    final settings = ref.read(appSettingsProvider);
    return settings.pictureInPicture &&
        !settings.audioOnly &&
        service?.state.mode == PlaybackMode.video &&
        service?.state.playing == true;
  }

  @override
  bool build() {
    if (!Platform.isAndroid) return false;
    _channel.setMethodCallHandler(_handleMethod);
    ref.listen(playbackProvider, (_, _) => _sync());
    ref.listen(appSettingsProvider, (_, _) => _sync());
    ref.onDispose(() => _channel.setMethodCallHandler(null));
    scheduleMicrotask(_sync);
    return false;
  }

  void _sync() {
    final service = ref.read(playbackProvider);
    unawaited(
      _channel
          .invokeMethod<void>('update', {
            'eligible': eligible,
            'playing': service?.state.playing == true,
          })
          .catchError((Object _) {}),
    );
  }

  Future<void> _handleMethod(MethodCall call) async {
    switch (call.method) {
      case 'entering':
        entering = true;
      case 'changed':
        entering = false;
        state = call.arguments == true;
        if (state) _backgroundPending = false;
        if (!state && _backgroundPending) {
          _backgroundPending = false;
          if (WidgetsBinding.instance.lifecycleState !=
              AppLifecycleState.resumed) {
            _backgroundWithoutPip();
          }
        }
      case 'backgroundWithoutPip':
        if (state || entering) {
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
    if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      return;
    }
    final service = ref.read(playbackProvider);
    if (ref.read(appSettingsProvider).backgroundPlay) {
      unawaited(service?.enterBackgroundAudioMode());
    } else {
      unawaited(service?.pause());
    }
  }
}
