import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../providers.dart';
import 'load_guard.dart';
import 'playback_failure_monitor.dart';
import '../db/app_db.dart';
import '../streams/player_client.dart';
import '../streams/relay_server.dart';
import '../streams/stream_cache.dart';
import '../streams/stream_selector.dart';

enum PlayerStatus {
  idle,
  loading,
  buffering,
  ready,
  playing,
  paused,
  ended,
  error,
}

class PlayRequest {
  const PlayRequest({
    required this.videoId,
    required this.mode,
    this.startAt = Duration.zero,
  });
  final String videoId;
  final PlaybackMode mode;
  final Duration startAt;
}

class PlayerUiState {
  PlayerStatus status = PlayerStatus.idle;
  Duration position = Duration.zero,
      buffered = Duration.zero,
      duration = Duration.zero;
  double rate = 1, volume = 100;
  int? videoWidth, videoHeight;
  int? quality;
  bool muted = false, loop = false;
  StreamError? error;
  List<int> heights = [];
}

class PlaybackService extends ChangeNotifier {
  PlaybackService(this.cache, this.relay, this.history) {
    controller = VideoController(player);
    final platform = player.platform;
    if (platform is NativePlayer) {
      unawaited(platform.setProperty('demuxer-max-bytes', '268435456'));
      unawaited(platform.setProperty('cache-secs', '300'));
      unawaited(platform.setProperty('keep-open', 'yes'));
    }
    _listen();
  }
  final StreamCache cache;
  final RelayServer relay;
  final HistoryRepo history;
  final Player player = Player();
  late final VideoController controller;
  final PlayerUiState state = PlayerUiState();
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  PlayRequest? request;
  final _loadGuard = LoadGuard();
  final _budget = RecoveryBudget();
  final _failureMonitor = PlaybackFailureMonitor();
  bool _switching = false, _disposed = false, _userPaused = false;
  bool _visible = true, _resumeAfterVisibility = false;
  DateTime? _lastWrite;
  Timer? _qualityTimer;
  Future<void> _commitTail = Future.value();
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _listen() {
    _subscriptions.add(
      player.stream.position.listen((value) {
        if (_switching) return;
        _failureMonitor.positionChanged(value);
        if (state.status == PlayerStatus.error &&
            value != state.position &&
            player.state.playing) {
          state.status = PlayerStatus.playing;
          state.error = null;
        }
        state.position = value;
        if (state.status == PlayerStatus.playing) {
          _budget.tick(DateTime.now());
        }
        if (request != null &&
            (_lastWrite == null ||
                DateTime.now().difference(_lastWrite!) >=
                    const Duration(seconds: 5))) {
          _lastWrite = DateTime.now();
          unawaited(
            history.save(HistoryEntry(request!.videoId, value, state.duration)),
          );
        }
        _notify();
      }),
    );
    _subscriptions.add(
      player.stream.width.listen((value) {
        state.videoWidth = value;
        _notify();
      }),
    );
    _subscriptions.add(
      player.stream.height.listen((value) {
        state.videoHeight = value;
        _notify();
      }),
    );
    _subscriptions.add(
      player.stream.duration.listen((v) {
        if (!_switching) {
          state.duration = v;
          _notify();
        }
      }),
    );
    _subscriptions.add(
      player.stream.buffer.listen((v) {
        if (!_switching) {
          state.buffered = v;
          _notify();
        }
      }),
    );
    _subscriptions.add(
      player.stream.playing.listen((v) {
        if (!_switching && state.status != PlayerStatus.error) {
          state.status = v ? PlayerStatus.playing : PlayerStatus.paused;
          if (v) {
            _budget.playing(DateTime.now());
          } else {
            _budget.paused();
          }
          _notify();
        }
      }),
    );
    _subscriptions.add(
      player.stream.buffering.listen((v) {
        if (!_switching && state.status != PlayerStatus.error && v) {
          state.status = PlayerStatus.buffering;
          _notify();
        } else if (!_switching &&
            state.status == PlayerStatus.buffering &&
            !v) {
          state.status = player.state.playing
              ? PlayerStatus.playing
              : PlayerStatus.paused;
          _notify();
        }
      }),
    );
    _subscriptions.add(
      player.stream.completed.listen((v) {
        if (v && !_switching && !state.loop) {
          _failureMonitor.cancel();
          state.status = PlayerStatus.ended;
          _notify();
        }
      }),
    );
    _subscriptions.add(
      player.stream.error.listen((v) {
        final current = request;
        if (!_switching &&
            current != null &&
            !_userPaused &&
            state.status != PlayerStatus.error) {
          _failureMonitor.report(state.position, () {
            if (!_disposed &&
                !_switching &&
                !_userPaused &&
                identical(request, current)) {
              unawaited(_recover());
            }
          });
        }
      }),
    );
  }

  Future<void> play(PlayRequest value) async {
    _failureMonitor.cancel();
    _userPaused = false;
    _visible = true;
    _resumeAfterVisibility = false;
    _budget.reset();
    await _load(value, newRequest: true);
  }

  Future<void> _load(
    PlayRequest value, {
    bool newRequest = false,
    bool recovery = false,
  }) async {
    final generation = _loadGuard.next();
    _switching = true;
    request = value;
    state.status = recovery ? PlayerStatus.buffering : PlayerStatus.loading;
    state.error = null;
    if (newRequest) {
      state.position = value.startAt;
      state.videoWidth = null;
      state.videoHeight = null;
      state.duration = Duration.zero;
      state.buffered = Duration.zero;
      state.quality = null;
    }
    _notify();
    await player.pause();
    if (!_loadGuard.isCurrent(generation)) return;
    try {
      final selected = await cache.resolve(
        value.videoId,
        value.mode,
        quality: state.quality,
      );
      if (!_loadGuard.isCurrent(generation)) return;
      state.heights = selected.videos.map((e) => e.height).toList();
      final format = value.mode == PlaybackMode.audio
          ? selected.audio!
          : selected.videos
                    .where((e) => e.height == state.quality)
                    .firstOrNull ??
                selected.videos.first;
      final video = await relay.register(format);
      final audio = value.mode == PlaybackMode.audio
          ? null
          : await relay.register(selected.audio!);
      if (!_loadGuard.isCurrent(generation)) return;
      final previous = _commitTail;
      final done = Completer<void>();
      _commitTail = done.future;
      try {
        await previous;
        if (!_loadGuard.isCurrent(generation)) return;
        await player.open(Media(video.toString()), play: false);
        if (!_loadGuard.isCurrent(generation)) return;
        if (audio != null) {
          await player.setAudioTrack(AudioTrack.uri(audio.toString()));
        }
        if (!_loadGuard.isCurrent(generation)) return;
        if (value.startAt > Duration.zero) await player.seek(value.startAt);
        if (!_loadGuard.isCurrent(generation)) return;
        await player.setPlaylistMode(
          state.loop ? PlaylistMode.single : PlaylistMode.none,
        );
        if (!_loadGuard.isCurrent(generation)) return;
        _switching = false;
        state.status = PlayerStatus.ready;
        _notify();
        if (_visible) {
          await player.play();
        } else {
          state.status = PlayerStatus.paused;
          _notify();
        }
      } finally {
        done.complete();
      }
    } catch (e) {
      debugPrint('Playback load failed: $e');
      if (!_loadGuard.isCurrent(generation)) return;
      _switching = false;
      final code = e is StreamException ? e.code : StreamError.extractionFailed;
      final permanent = [
        StreamError.ageRestricted,
        StreamError.geoRestricted,
        StreamError.unavailable,
        StreamError.noStreams,
        StreamError.noVideo,
        StreamError.botCheck,
      ].contains(code);
      if (recovery && !permanent && _budget.attempts < 3) {
        state.status = PlayerStatus.buffering;
        _notify();
        scheduleMicrotask(_recover);
      } else {
        state.status = PlayerStatus.error;
        state.error = code;
        _notify();
      }
    }
  }

  Future<void> _recover() async {
    if (_switching || request == null) return;
    if (!_budget.take()) {
      state.status = PlayerStatus.error;
      state.error = StreamError.extractionFailed;
      _notify();
      return;
    }
    cache.clearCache();
    await _load(
      PlayRequest(
        videoId: request!.videoId,
        mode: request!.mode,
        startAt: state.position,
      ),
      recovery: true,
    );
  }

  Future<void> retry() async {
    if (request != null) {
      _budget.reset();
      cache.clearCache();
      await _load(
        PlayRequest(
          videoId: request!.videoId,
          mode: request!.mode,
          startAt: state.position,
        ),
      );
    }
  }

  Future<void> preResolve(String id, PlaybackMode mode) async {
    try {
      await cache.resolve(id, mode);
    } catch (_) {}
  }

  Future<void> setVisible(bool visible) async {
    if (_visible == visible) return;
    _visible = visible;
    if (!visible) {
      _resumeAfterVisibility = request != null && !_userPaused;
      _failureMonitor.cancel();
      await player.pause();
    } else if (_resumeAfterVisibility &&
        request != null &&
        !_switching &&
        !_userPaused &&
        state.status != PlayerStatus.error) {
      _resumeAfterVisibility = false;
      await player.play();
    }
  }

  Future<void> pause() async {
    _userPaused = true;
    _failureMonitor.cancel();
    _budget.paused();
    await player.pause();
  }

  Future<void> resume() async {
    _userPaused = false;
    if (!_visible) {
      _resumeAfterVisibility = true;
      return;
    }
    if (state.status == PlayerStatus.error) {
      await retry();
    } else {
      await player.play();
    }
  }

  Future<void> seek(Duration v) =>
      player.seek(v < Duration.zero ? Duration.zero : v);
  Future<void> setRate(double v) async {
    state.rate = v;
    await player.setRate(v);
    _notify();
  }

  Future<void> setVolume(double v) async {
    state.volume = v.clamp(0, 100);
    state.muted = state.volume == 0;
    await player.setVolume(state.volume);
    _notify();
  }

  Future<void> setMuted(bool v) async {
    state.muted = v;
    await player.setVolume(
      v
          ? 0
          : state.volume == 0
          ? 100
          : state.volume,
    );
    _notify();
  }

  Future<void> setLoop(bool v) async {
    state.loop = v;
    await player.setPlaylistMode(v ? PlaylistMode.single : PlaylistMode.none);
    _notify();
  }

  void setQuality(int? value) {
    _qualityTimer?.cancel();
    _qualityTimer = Timer(const Duration(milliseconds: 300), () {
      if (request == null) return;
      state.quality = value;
      unawaited(
        _load(
          PlayRequest(
            videoId: request!.videoId,
            mode: request!.mode,
            startAt: state.position,
          ),
        ),
      );
    });
  }

  Future<void> stop() async {
    _failureMonitor.cancel();
    _loadGuard.next();
    _switching = false;
    request = null;
    await player.stop();
    state.status = PlayerStatus.idle;
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _failureMonitor.cancel();
    _qualityTimer?.cancel();
    for (final s in _subscriptions) {
      unawaited(s.cancel());
    }
    unawaited(player.dispose());
    unawaited(relay.close());
    super.dispose();
  }
}

final playbackProvider = ChangeNotifierProvider<PlaybackService?>((ref) {
  final http = ref.watch(innertubeProvider).value;
  final network = ref.watch(networkFamilyProvider).value;
  if (http == null ||
      network == null ||
      ref.watch(visitorDataProvider).value == null) {
    return null;
  }
  final client = PlayerClient(
    network,
    http.clients,
    () => http.visitorData,
    () async {
      await http.refreshVisitor?.call();
    },
    hl: http.hl,
    gl: http.gl,
  );
  final cache = StreamCache(client);
  final previousNetworkChange = network.onChanged;
  network.onChanged = () {
    previousNetworkChange?.call();
    cache.clearCache();
  };
  ref.onDispose(() {
    network.onChanged = previousNetworkChange;
  });
  return PlaybackService(
    cache,
    RelayServer(network, http.clients['VISIONOS']['ua']),
    ref.read(historyRepoProvider),
  );
});
