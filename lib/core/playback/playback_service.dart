import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../providers.dart';
import 'load_guard.dart';
import 'playback_failure_monitor.dart';
import 'seek_controller.dart';
import 'audio_handler.dart';
import '../db/app_db.dart';
import '../streams/player_client.dart';
import '../streams/relay_server.dart';
import '../streams/stream_cache.dart';
import '../streams/stream_selector.dart';
import '../streams/net_family.dart';
import '../innertube/innertube_http.dart';
import '../yt/captions.dart';

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

enum SeekState {
  idle,
  seeking,
  buffering,
  ready,
}

class PlayRequest {
  const PlayRequest({
    required this.videoId,
    required this.mode,
    this.startAt = Duration.zero,
    this.play = true,
  });
  final String videoId;
  final PlaybackMode mode;
  final Duration startAt;
  final bool play;
}

class PlaybackSnapshot {
  PlayerStatus status = PlayerStatus.idle;
  SeekState seekState = SeekState.idle;
  Duration? seekTarget;
  Duration position = Duration.zero,
      buffered = Duration.zero,
      duration = Duration.zero;
  double rate = 1, volume = 100;
  int? videoWidth, videoHeight;
  int? quality;
  bool muted = false, loop = false;
  bool recovering = false;
  StreamError? error;
  List<int> heights = [];
  List<Map<String, dynamic>> captions = [];
  int? selectedCaption;
  bool captionError = false;
  Uint8List? frozenFrame;

  Duration get displayPosition => seekTarget ?? position;
}

class PlaybackService extends ChangeNotifier {
  PlaybackService(this.cache, this.relay, this.history) {
    _seekController = SeekController(
      player: player,
      getDuration: () => state.duration,
      getPosition: () => state.position,
      getStatus: () => state.status,
      isUserPaused: () => _userPaused,
      onSeekStateChanged: (s, target) {
        state.seekState = s;
        state.seekTarget = target;
        _notify();
      },
      onRecovery: _recover,
      onAudioSyncCheck: () async {
        if (_currentAudioUri != null) {
          final platform = player.platform;
          if (platform is NativePlayer) {
            final coreIdle = await platform.getProperty('core-idle');
            if (coreIdle == 'yes' && player.state.playing) {
              _debugLog('audio core-idle detected after seek; re-attaching audio track');
              await player.setAudioTrack(AudioTrack.uri(_currentAudioUri.toString()));
            }
          }
        }
      },
      onPlaybackResume: () async {
        state.status = PlayerStatus.playing;
        if (!_userPaused && _visible && await _activateAudioFocus()) {
          await player.play();
        }
        _notify();
      },
    );
    final platform = player.platform;
    if (platform is NativePlayer) {
      unawaited(platform.setProperty('demuxer-max-bytes', '268435456'));
      unawaited(platform.setProperty('cache-secs', '300'));
      unawaited(platform.setProperty('keep-open', 'yes'));
      unawaited(
        platform.observeProperty('seeking', (val) async {
          _mpvSeeking = val == 'yes';
          _seekController.updateMpvProperties(seeking: _mpvSeeking);
          _debugLog('mpv property seeking = $val');
        }),
      );
      unawaited(
        platform.observeProperty('paused-for-cache', (val) async {
          _seekController.updateMpvProperties(pausedForCache: val == 'yes');
          _debugLog('mpv property paused-for-cache = $val');
        }),
      );
      for (final prop in [
        'core-idle',
        'demuxer-cache-time',
      ]) {
        unawaited(
          platform.observeProperty(prop, (val) async {
            _debugLog('mpv property $prop = $val');
          }),
        );
      }
    }
    _listen();
    _audioFocus.setMethodCallHandler(_onAudioFocus);
  }

  void _debugLog(String msg) {
    stdout.writeln('[PlaybackService] $msg');
  }
  final StreamCache cache;
  final RelayServer relay;
  final HistoryRepo history;
  final Player player = Player();
  late final VideoController controller = VideoController(player);
  final PlaybackSnapshot state = PlaybackSnapshot();
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  PlayRequest? request;
  final _loadGuard = LoadGuard();
  final _budget = RecoveryBudget();
  final _failureMonitor = PlaybackFailureMonitor();
  late final SeekController _seekController;
  bool _switching = false, _disposed = false, _userPaused = false;
  bool _visible = true, _resumeAfterVisibility = false;
  bool _resumeAfterFocus = false;
  bool _mpvSeeking = false;
  Uri? _currentAudioUri;
  static const _audioFocus = MethodChannel('hivetube/audio_focus');

  Future<void> _onAudioFocus(MethodCall call) async {
    if (call.method == 'focusLoss') {
      _resumeAfterFocus = player.state.playing && !_userPaused;
      if (_resumeAfterFocus) await player.pause();
    } else if (call.method == 'focusGain') {
      if (_resumeAfterFocus && !_userPaused && request != null && _visible) {
        _resumeAfterFocus = false;
        await player.play();
      }
    } else if (call.method == 'noisy') {
      _resumeAfterFocus = false;
      await pause();
    }
  }

  Future<bool> _activateAudioFocus() async {
    if (kIsWeb || Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return true;
    }
    if (defaultTargetPlatform != TargetPlatform.android) return true;
    try {
      return await _audioFocus.invokeMethod<bool>('activate') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return true;
    } catch (_) {
      return true;
    }
  }

  String? _captionLanguage;
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
        final gap = (value - state.position).abs();
        if (gap > const Duration(seconds: 2)) {
          _debugLog(
            'position stream gap: old=${state.position} new=$value (gap=${gap.inMilliseconds}ms)',
          );
        }
        if (state.frozenFrame != null &&
            value != state.position &&
            player.state.playing) {
          state.frozenFrame = null;
        }
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
        try {
          unawaited(WakelockPlus.toggle(enable: v).catchError((_) {}));
        } catch (_) {}
        if (!_switching &&
            state.status != PlayerStatus.error &&
            (v || state.status != PlayerStatus.ended)) {
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
        _debugLog('player stream error: $v');
        if (v.contains('audio device') || v.contains('no sound')) return;
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
    await _saveProgress();
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
    if (!newRequest && state.position > Duration.zero) {
      Uint8List? frame;
      try {
        frame = await player
            .screenshot(format: 'image/png')
            .timeout(const Duration(seconds: 2));
      } catch (_) {}
      if (!_loadGuard.isCurrent(generation)) return;
      state.frozenFrame = frame;
    }
    request = value;
    state.status = recovery ? PlayerStatus.buffering : PlayerStatus.loading;
    state.recovering = recovery;
    state.error = null;
    if (newRequest) {
      state.frozenFrame = null;
      state.position = value.startAt;
      state.videoWidth = null;
      state.videoHeight = null;
      state.duration = Duration.zero;
      state.buffered = Duration.zero;
      state.captions = [];
      state.selectedCaption = null;
      state.captionError = false;
    }
    _notify();
    if (player.state.playing) {
      await player.pause();
    }
    if (!_loadGuard.isCurrent(generation)) return;
    try {
      _debugLog('_load: resolving streams for ${value.videoId}...');
      final selected = await cache.resolve(
        value.videoId,
        value.mode,
        quality: state.quality,
      );
      _debugLog('_load: resolved streams for ${value.videoId}.');
      if (!_loadGuard.isCurrent(generation)) return;
      state.heights = selected.videos.map((e) => e.height).toList();
      state.captions = cache.captionTracks(value.videoId);
      if (_captionLanguage != null) {
        final matches =
            state.captions
                .asMap()
                .entries
                .where((e) => e.value['languageCode'] == _captionLanguage)
                .toList()
              ..sort(
                (a, b) => (a.value['kind'] == 'asr' ? 1 : 0).compareTo(
                  b.value['kind'] == 'asr' ? 1 : 0,
                ),
              );
        if (matches.isNotEmpty) state.selectedCaption = matches.first.key;
      }
      if (state.captions.isEmpty) {
        unawaited(
          _transcript(value.videoId)
              .then((vtt) {
                if (request?.videoId == value.videoId && vtt.isNotEmpty) {
                  state.captions = [
                    {'languageCode': cache.player.hl, 'transcriptVtt': vtt},
                  ];
                  _notify();
                }
              })
              .catchError((Object _) {}),
        );
      }
      final format = value.mode == PlaybackMode.audio
          ? selected.audio!
          : selected.videos
                    .where((e) => e.height == state.quality)
                    .firstOrNull ??
                selected.videos.first;
      _debugLog('_load: registering video on relay...');
      final video = await relay.register(format);
      _debugLog('_load: registered video: $video');
      final audio = value.mode == PlaybackMode.audio
          ? null
          : await relay.register(selected.audio!);
      _currentAudioUri = audio;
      _debugLog('_load: registered audio: $audio');
      if (!_loadGuard.isCurrent(generation)) return;
      final previous = _commitTail;
      final done = Completer<void>();
      _commitTail = done.future;
      try {
        await previous;
        if (!_loadGuard.isCurrent(generation)) return;
        final isShort = value.mode == PlaybackMode.short;
        await player.setPlaylistMode(
          (isShort || state.loop) ? PlaylistMode.single : PlaylistMode.none,
        );
        if (player.platform is NativePlayer) {
          unawaited((player.platform as NativePlayer).setProperty(
            'loop-file',
            (isShort || state.loop) ? 'inf' : 'no',
          ));
        }
        _debugLog('_load: calling player.open($video)...');
        final shouldPlay = value.play && _visible && !_userPaused;
        await player.open(Media(video.toString()), play: shouldPlay);
        _debugLog('_load: player.open finished.');
        if (!_loadGuard.isCurrent(generation)) return;
        if (audio != null) {
          _debugLog('_load: calling player.setAudioTrack...');
          await player.setAudioTrack(AudioTrack.uri(audio.toString()));
          _debugLog('_load: player.setAudioTrack finished.');
        }
        if (!_loadGuard.isCurrent(generation)) return;
        if (value.startAt > Duration.zero) await player.seek(value.startAt);
        if (!_loadGuard.isCurrent(generation)) return;
        _switching = false;
        state.recovering = false;
        state.status = PlayerStatus.ready;
        _notify();
        final caption = state.selectedCaption;
        if (caption != null) {
          unawaited(setCaption(caption));
        }
        final focus = await _activateAudioFocus();
        _debugLog('_load: shouldPlay=$shouldPlay (play=${value.play}, visible=$_visible, userPaused=$_userPaused) focus=$focus');
        if (shouldPlay && focus) {
          state.status = PlayerStatus.playing;
          _notify();
          _debugLog('_load: calling player.play()...');
          await player.play();
          _debugLog('_load: player.play() finished.');
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
        state.recovering = false;
        state.error = code;
        _notify();
      }
    }
  }

  Future<void> _recover() async {
    if (_switching || request == null) return;
    _debugLog(
      'recovery event: attempts=${_budget.attempts} videoId=${request?.videoId} position=${state.position}',
    );
    if (!_budget.take()) {
      state.status = PlayerStatus.error;
      state.recovering = false;
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
    _resumeAfterFocus = false;
    _failureMonitor.cancel();
    _budget.paused();
    state.status = PlayerStatus.paused;
    _notify();
    await player.pause();
    await _saveProgress();
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
      state.status = PlayerStatus.playing;
      _notify();
      if (await _activateAudioFocus()) await player.play();
    }
  }

  Future<void> seek(Duration v) => seekTo(v);

  Future<void> seekTo(Duration v) => _seekController.seekTo(v);

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

  Future<String> _transcript(String id) async {
    final config = cache.player.clients['WEB_REMIX'];
    final bytes = utf8.encode(id);
    if (bytes.length > 127) return '';
    final params = base64Encode([10, bytes.length, ...bytes]);
    final uri = Uri.https('music.youtube.com', '/youtubei/v1/get_transcript', {
      'prettyPrint': 'false',
    });
    final req = await cache.player.network.client.postUrl(uri);
    req.headers.contentType = ContentType.json;
    req.headers.set(HttpHeaders.userAgentHeader, config['ua']);
    req.write(
      jsonEncode({
        'context': {
          'client': {
            'clientName': config['clientName'],
            'clientVersion': config['clientVersion'],
            'hl': 'en',
            'gl': cache.player.gl,
          },
        },
        'params': params,
      }),
    );
    final response = await req.close().timeout(const Duration(seconds: 15));
    final body = await utf8.decodeStream(response);
    if (response.statusCode != 200) return '';
    return transcriptToVtt(jsonDecode(body));
  }

  Future<void> setCaption(int? index) async {
    if (index == null) {
      await player.setSubtitleTrack(SubtitleTrack.no());
      state.selectedCaption = null;
      _captionLanguage = null;
      state.captionError = false;
      _notify();
      return;
    }
    if (index < 0 || index >= state.captions.length) return;
    final current = request;
    final track = state.captions[index];
    try {
      if (track['transcriptVtt'] is String) {
        await player.setSubtitleTrack(
          SubtitleTrack.data(
            track['transcriptVtt'] as String,
            language: track['languageCode'] as String?,
          ),
        );
        state.selectedCaption = index;
        _captionLanguage = track['languageCode'] as String?;
        state.captionError = false;
        _notify();
        return;
      }
      final base = Uri.parse(track['baseUrl'] as String);
      final uri = base.replace(
        queryParameters: {
          ...base.queryParameters,
          'fmt': 'vtt',
        },
      );
      final httpRequest = await cache.player.network.client.getUrl(uri);
      httpRequest.headers.set(
        HttpHeaders.userAgentHeader,
        cache.player.clients['VISIONOS']['ua'],
      );
      final response = await httpRequest.close().timeout(
        const Duration(seconds: 15),
      );
      final body = await utf8.decodeStream(response);
      if (response.statusCode != 200 || !body.trimLeft().startsWith('WEBVTT')) {
        throw const FormatException();
      }
      if (!identical(current, request)) return;
      await player.setSubtitleTrack(
        SubtitleTrack.data(
          cleanVtt(body),
          language: track['languageCode'] as String?,
        ),
      );
      state.selectedCaption = index;
      _captionLanguage = track['languageCode'] as String?;
      state.captionError = false;
    } catch (_) {
      if (!identical(current, request)) return;
      try {
        final vtt = current == null ? '' : await _transcript(current.videoId);
        if (!identical(current, request)) return;
        if (vtt.isEmpty) throw const FormatException();
        await player.setSubtitleTrack(SubtitleTrack.data(vtt));
        state.selectedCaption = index;
        state.captionError = false;
      } catch (_) {
        state.captionError = true;
      }
    }
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
    final generation = _loadGuard.next();
    _switching = false;
    await _saveProgress();
    if (!_loadGuard.isCurrent(generation)) return;
    request = null;
    state.frozenFrame = null;
    await player.stop();
    state.status = PlayerStatus.idle;
    _notify();
  }

  @override
  void dispose() {
    unawaited(_saveProgress());
    unawaited(WakelockPlus.disable());
    _audioFocus.setMethodCallHandler(null);
    if (defaultTargetPlatform == TargetPlatform.android) {
      unawaited(
        _audioFocus.invokeMethod<void>('deactivate').catchError((Object _) {}),
      );
    }
    _disposed = true;
    _seekController.dispose();
    _failureMonitor.cancel();
    _qualityTimer?.cancel();
    for (final s in _subscriptions) {
      unawaited(s.cancel());
    }
    unawaited(player.dispose());
    unawaited(relay.close());
    super.dispose();
  }

  Future<void> _saveProgress() async {
    final current = request;
    if (current != null && state.duration > Duration.zero) {
      await history.save(
        HistoryEntry(current.videoId, state.position, state.duration),
      );
    }
  }
}

final playbackProvider = NotifierProvider<PlaybackController, PlaybackService?>(
  PlaybackController.new,
);

class PlaybackController extends Notifier<PlaybackService?> {
  PlaybackService? _service;
  HiveAudioHandler? _handler;
  NetworkFamily? _network;
  InnertubeHttp? _currentHttp;
  VoidCallback? _networkHook, _networkPrevious;

  @override
  bool updateShouldNotify(PlaybackService? previous, PlaybackService? next) =>
      true;

  @override
  PlaybackService? build() {
    ref.listen(innertubeProvider, (_, _) => _ensureService());
    ref.listen(networkFamilyProvider, (_, _) => _ensureService());
    ref.listen(visitorDataProvider, (_, _) => _ensureService());
    ref.onDispose(() {
      final service = _service;
      if (service != null) {
        service.removeListener(_changed);
        _handler?.unbind(service);
        service.dispose();
      }
      final network = _network;
      if (network != null && identical(network.onChanged, _networkHook)) {
        network.onChanged = _networkPrevious;
      }
    });
    return _createService();
  }

  void _changed() => state = _service;

  void _ensureService() {
    if (_service != null) {
      final http = ref.read(innertubeProvider).value;
      if (http != null &&
          ref.read(visitorDataProvider).value != null &&
          !identical(_currentHttp, http)) {
        _currentHttp = http;
        _service!.cache.player.gl = http.gl;
        _service!.cache.clearCache();
      }
      _installNetworkHook();
      return;
    }
    final service = _createService();
    if (service != null) state = service;
  }

  PlaybackService? _createService() {
    if (_service != null) return _service;
    final http = ref.read(innertubeProvider).value;
    final network = ref.read(networkFamilyProvider).value;
    if (http == null ||
        network == null ||
        ref.read(visitorDataProvider).value == null) {
      return null;
    }
    _currentHttp = http;
    final client = PlayerClient(
      network,
      http.clients,
      () => _currentHttp?.visitorData,
      () async {
        await _currentHttp?.refreshVisitor?.call();
      },
      hl: http.hl,
      gl: http.gl,
    );
    final cache = StreamCache(client);
    final service = PlaybackService(
      cache,
      RelayServer(network, http.clients['VISIONOS']['ua']),
      ref.read(historyRepoProvider),
    );
    final handler = ref.read(audioHandlerProvider);
    _handler = handler;
    handler?.bind(service);
    _service = service;
    _network = network;
    _installNetworkHook();
    service.addListener(_changed);
    return service;
  }

  void _installNetworkHook() {
    final network = _network;
    final service = _service;
    if (network == null ||
        service == null ||
        identical(network.onChanged, _networkHook)) {
      return;
    }
    final previous = network.onChanged;
    _networkPrevious = previous;
    void changed() {
      previous?.call();
      service.cache.clearCache();
    }

    _networkHook = changed;
    network.onChanged = changed;
  }
}
