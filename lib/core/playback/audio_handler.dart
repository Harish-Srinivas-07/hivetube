import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../streams/stream_selector.dart';
import 'playback_service.dart';

final audioHandlerProvider =
    NotifierProvider<AudioHandlerController, HiveAudioHandler?>(
      AudioHandlerController.new,
    );

class AudioHandlerController extends Notifier<HiveAudioHandler?> {
  AudioHandlerController([this.handler]);
  final HiveAudioHandler? handler;
  @override
  HiveAudioHandler? build() => handler;
}

class HiveAudioHandler extends BaseAudioHandler with SeekHandler {
  PlaybackService? _service;
  Future<void> Function()? onNext;
  Future<void> Function()? onPrevious;

  void bind(PlaybackService service) {
    if (identical(_service, service)) return;
    _service?.removeListener(_update);
    _service = service;
    service.addListener(_update);
    _update();
  }

  void unbind(PlaybackService service) {
    if (!identical(_service, service)) return;
    service.removeListener(_update);
    _service = null;
    playbackState.add(
      PlaybackState(processingState: AudioProcessingState.idle),
    );
  }

  void setMetadata(String id, String title, String channel, {Uri? artUri}) {
    if (_service?.request?.videoId != id && _service?.state.videoId != id) return;
    final previous = mediaItem.valueOrNull;
    final isShort = _service?.state.mode == PlaybackMode.short;
    final displayTitle = title.trim().isNotEmpty
        ? title.trim()
        : (isShort ? 'Short' : 'HiveTube');
    final displayChannel = channel.trim().isNotEmpty
        ? channel.trim()
        : (isShort ? 'YouTube Short' : '');
    if (previous?.id == id &&
        previous?.title == displayTitle &&
        previous?.artist == displayChannel &&
        previous?.artUri == artUri &&
        previous?.duration == _service?.state.duration) {
      return;
    }
    mediaItem.add(
      MediaItem(
        id: id,
        title: displayTitle,
        artist: displayChannel.isNotEmpty ? displayChannel : null,
        artUri: artUri,
        duration: _service?.state.duration,
      ),
    );
  }

  void setShortMetadata({
    required String id,
    required String title,
    required String channel,
    Uri? artUri,
  }) {
    final displayTitle = title.trim().isNotEmpty ? title.trim() : 'Short';
    final displayChannel =
        channel.trim().isNotEmpty ? channel.trim() : 'YouTube Short';
    final previous = mediaItem.valueOrNull;
    if (previous?.id == id &&
        previous?.title == displayTitle &&
        previous?.artist == displayChannel &&
        previous?.artUri == artUri &&
        previous?.duration == _service?.state.duration) {
      return;
    }
    mediaItem.add(
      MediaItem(
        id: id,
        title: displayTitle,
        artist: displayChannel,
        artUri: artUri,
        duration: _service?.state.duration,
      ),
    );
  }

  void _update() {
    final service = _service;
    if (service == null) return;
    final state = service.state;
    final request = service.request;
    final currentItem = mediaItem.valueOrNull;
    if (request != null && currentItem?.id != request.videoId) {
      final isShort = state.mode == PlaybackMode.short;
      mediaItem.add(
        MediaItem(
          id: request.videoId,
          title: isShort ? 'Short' : 'HiveTube',
          artist: isShort ? 'YouTube Short' : null,
          duration: state.duration,
        ),
      );
    } else if (currentItem != null &&
        currentItem.duration != state.duration &&
        state.duration != Duration.zero) {
      mediaItem.add(
        MediaItem(
          id: currentItem.id,
          title: currentItem.title,
          artist: currentItem.artist,
          artUri: currentItem.artUri,
          duration: state.duration,
        ),
      );
    }
    final processing = switch (state.status) {
      PlayerStatus.idle => AudioProcessingState.idle,
      PlayerStatus.loading => AudioProcessingState.loading,
      PlayerStatus.buffering => AudioProcessingState.buffering,
      PlayerStatus.ended => AudioProcessingState.completed,
      PlayerStatus.error => AudioProcessingState.error,
      _ => AudioProcessingState.ready,
    };
    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          state.playing ? MediaControl.pause : MediaControl.play,
          MediaControl.skipToNext,
          MediaControl.stop,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: processing,
        playing: state.playing,
        updatePosition: state.position,
        bufferedPosition: state.buffered,
        speed: state.rate,
      ),
    );
  }

  @override
  Future<void> play() async => _service?.resume();
  @override
  Future<void> pause() async => _service?.pause();
  @override
  Future<void> seek(Duration position) async => _service?.seek(position);
  @override
  Future<void> stop() async => _service?.stop();
  @override
  Future<void> skipToNext() async => onNext?.call();
  @override
  Future<void> skipToPrevious() async => onPrevious?.call();
}
