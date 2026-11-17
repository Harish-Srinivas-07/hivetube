import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../settings/app_settings.dart';
import '../streams/adaptive_quality_policy.dart';
import '../../theme/app_motion.dart';
import 'player_ui_state.dart';

final previewPlaybackAllowedProvider = Provider<bool>((ref) {
  final settings = ref.watch(
    contentPrefsProvider.select(
      (value) => (
        enabled: value.previewsEnabled,
        wifiOnly: value.previewsWifiOnly,
        dataSaver:
            value.videoQualityPreference == VideoQualityPreference.dataSaver,
      ),
    ),
  );
  if (!settings.enabled || settings.dataSaver) return false;

  final playerPlaying = ref.watch(
    playerUiProvider.select((value) => value.playing),
  );
  if (playerPlaying) return false;

  final connections = ref.watch(connectivityProvider).asData?.value ?? const [];
  final wifi = connections.contains(ConnectivityResult.wifi);
  final mobile = connections.any(
    (connection) => connection == ConnectivityResult.mobile,
  );
  if (settings.wifiOnly && mobile && !wifi) return false;
  if (wifi) return true;
  if (mobile) return !settings.wifiOnly;
  // Some platforms do not expose connectivity status; do not disable previews
  // solely because the plugin is unavailable.
  return true;
});

final previewCoordinatorProvider =
    NotifierProvider<PreviewCoordinator, String?>(PreviewCoordinator.new);

final ValueNotifier<bool> _previewModalOpen = ValueNotifier(false);
final previewNavigatorObserver = _PreviewNavigatorObserver();

class _PreviewNavigatorObserver extends NavigatorObserver {
  int _popupCount = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute) _changePopupCount(1);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute) _changePopupCount(-1);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute) _changePopupCount(-1);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute is PopupRoute) _changePopupCount(-1);
    if (newRoute is PopupRoute) _changePopupCount(1);
  }

  void _changePopupCount(int delta) {
    _popupCount = (_popupCount + delta).clamp(0, 1 << 20);
    _previewModalOpen.value = _popupCount > 0;
  }
}

class PreviewCoordinator extends Notifier<String?> with WidgetsBindingObserver {
  static const minVisibleFraction = 0.6;

  final Map<String, _PreviewCandidate> _candidates = {};
  Timer? _electionTimer;
  bool _scrolling = false;
  bool _appActive = true;
  bool _playbackAllowed = false;
  bool _modalOpen = false;
  bool _activeUpdateScheduled = false;
  String? _pendingActiveId;

  @override
  String? build() {
    _playbackAllowed = ref.read(previewPlaybackAllowedProvider);
    _modalOpen = _previewModalOpen.value;
    ref.listen(previewPlaybackAllowedProvider, (_, allowed) {
      _playbackAllowed = allowed;
      if (!allowed) {
        _electionTimer?.cancel();
        _setActive(null);
      } else {
        _scheduleElection();
      }
    });
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(this);
      _electionTimer?.cancel();
    });
    return null;
  }

  void reportCandidate({
    required String id,
    required double visibleFraction,
    required double centerDistance,
  }) {
    if (visibleFraction <= 0) {
      removeCandidate(id);
      return;
    }
    final next = _PreviewCandidate(
      visibleFraction: visibleFraction,
      centerDistance: centerDistance,
    );
    if (_candidates[id] == next) return;
    _candidates[id] = next;
    _scheduleElection();
  }

  void removeCandidate(String id) {
    if (!ref.mounted) return;
    final removed = _candidates.remove(id);
    if (removed == null) return;
    if (state == id) _setActive(null);
    _scheduleElection();
  }

  void scrollStarted() {
    if (_scrolling) return;
    _scrolling = true;
    _electionTimer?.cancel();
    _setActive(null);
  }

  void scrollEnded() {
    if (!_scrolling) return;
    _scrolling = false;
    _scheduleElection();
  }

  void setModalOpen(bool value) {
    if (_modalOpen == value) return;
    _modalOpen = value;
    if (value) {
      _electionTimer?.cancel();
      _setActive(null);
    } else {
      _scheduleElection();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appActive = state == AppLifecycleState.resumed;
    if (!_appActive) {
      _electionTimer?.cancel();
      _setActive(null);
    } else {
      _scheduleElection();
    }
  }

  void _scheduleElection() {
    if (_candidates.isEmpty) {
      _electionTimer?.cancel();
      return;
    }
    if (_scrolling || !_appActive || !_playbackAllowed || _modalOpen) return;
    _electionTimer?.cancel();
    _electionTimer = Timer(AppMotion.previewElectionDebounce, _electWinner);
  }

  void _electWinner() {
    if (_scrolling || !_appActive || !_playbackAllowed || _modalOpen) {
      _setActive(null);
      return;
    }
    _PreviewCandidateEntry? winner;
    for (final entry in _candidates.entries) {
      if (entry.value.visibleFraction < minVisibleFraction) continue;
      final current = winner;
      if (current == null ||
          entry.value.visibleFraction > current.candidate.visibleFraction ||
          (entry.value.visibleFraction == current.candidate.visibleFraction &&
              entry.value.centerDistance < current.candidate.centerDistance)) {
        winner = _PreviewCandidateEntry(entry.key, entry.value);
      }
    }
    _setActive(winner?.id);
  }

  void _setActive(String? id) {
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase != SchedulerPhase.idle &&
        phase != SchedulerPhase.postFrameCallbacks) {
      _pendingActiveId = id;
      if (_activeUpdateScheduled) return;
      _activeUpdateScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!ref.mounted) return;
        _activeUpdateScheduled = false;
        final pendingId = _pendingActiveId;
        _pendingActiveId = null;
        if (state != pendingId) state = pendingId;
      });
      return;
    }
    if (state != id) state = id;
  }
}

class _PreviewCandidate {
  const _PreviewCandidate({
    required this.visibleFraction,
    required this.centerDistance,
  });

  final double visibleFraction;
  final double centerDistance;

  @override
  bool operator ==(Object other) =>
      other is _PreviewCandidate &&
      other.visibleFraction == visibleFraction &&
      other.centerDistance == centerDistance;

  @override
  int get hashCode => Object.hash(visibleFraction, centerDistance);
}

class _PreviewCandidateEntry {
  const _PreviewCandidateEntry(this.id, this.candidate);

  final String id;
  final _PreviewCandidate candidate;
}

/// Captures scrolling notifications across every route without rebuilding lists.
class PreviewScrollListener extends ConsumerStatefulWidget {
  const PreviewScrollListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PreviewScrollListener> createState() =>
      _PreviewScrollListenerState();
}

class _PreviewScrollListenerState extends ConsumerState<PreviewScrollListener> {
  @override
  void initState() {
    super.initState();
    _previewModalOpen.addListener(_updateModalState);
  }

  void _updateModalState() {
    ref
        .read(previewCoordinatorProvider.notifier)
        .setModalOpen(_previewModalOpen.value);
  }

  @override
  void dispose() {
    _previewModalOpen.removeListener(_updateModalState);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          final coordinator = ref.read(previewCoordinatorProvider.notifier);
          if (notification is ScrollStartNotification ||
              notification is ScrollUpdateNotification) {
            coordinator.scrollStarted();
          } else if (notification is ScrollEndNotification) {
            coordinator.scrollEnded();
          }
          return false;
        },
        child: widget.child,
      );
}
