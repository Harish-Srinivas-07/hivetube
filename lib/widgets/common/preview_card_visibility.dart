import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../core/playback/preview_coordinator.dart';

class PreviewCardVisibility extends ConsumerStatefulWidget {
  const PreviewCardVisibility({
    super.key,
    required this.videoId,
    required this.enabled,
    required this.child,
  });

  final String videoId;
  final bool enabled;
  final Widget child;

  @override
  ConsumerState<PreviewCardVisibility> createState() =>
      _PreviewCardVisibilityState();
}

class _PreviewCardVisibilityState extends ConsumerState<PreviewCardVisibility> {
  late final String _candidateId = UniqueKey().toString();
  double _visibleFraction = 0;
  double _centerDistance = 0;
  bool _hasVisibility = false;
  bool _deactivated = false;
  PreviewCoordinator? _coordinator;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _deactivated = false;
    _reportVisibility();
  }

  @override
  void deactivate() {
    _deactivated = true;
    _coordinator?.removeCandidate(_candidateId);
    super.deactivate();
  }

  @override
  void didUpdateWidget(PreviewCardVisibility oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoId != widget.videoId ||
        oldWidget.enabled != widget.enabled) {
      _reportVisibility();
    }
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    if (!mounted || _deactivated) return;
    final viewportCenter = MediaQuery.sizeOf(context).center(Offset.zero);
    _visibleFraction = info.visibleFraction;
    _centerDistance = (info.visibleBounds.center - viewportCenter).distance;
    _hasVisibility = true;
    _reportVisibility();
  }

  void _reportVisibility() {
    if (_deactivated) return;
    final currentRoute = ModalRoute.of(context)?.isCurrent ?? true;
    final tickerActive = TickerMode.valuesOf(context).enabled;
    if (!_hasVisibility) return;
    final coordinator = _coordinator;
    if (coordinator == null) return;
    if (!widget.enabled || !currentRoute || !tickerActive) {
      coordinator.removeCandidate(_candidateId);
      return;
    }
    coordinator.reportCandidate(
      id: _candidateId,
      visibleFraction: _visibleFraction,
      centerDistance: _centerDistance,
    );
  }

  @override
  void dispose() {
    _coordinator?.removeCandidate(_candidateId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isActive = ref.watch(
      previewCoordinatorProvider.select((activeId) => activeId == _candidateId),
    );
    _coordinator ??= ref.read(previewCoordinatorProvider.notifier);
    return PreviewCardScope(
      videoId: widget.videoId,
      isActive: isActive,
      child: VisibilityDetector(
        key: ValueKey(_candidateId),
        onVisibilityChanged: _onVisibilityChanged,
        child: widget.child,
      ),
    );
  }
}

class PreviewCardScope extends InheritedWidget {
  const PreviewCardScope({
    super.key,
    required this.videoId,
    required this.isActive,
    required super.child,
  });

  final String videoId;
  final bool isActive;

  static PreviewCardScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PreviewCardScope>();

  @override
  bool updateShouldNotify(PreviewCardScope oldWidget) =>
      videoId != oldWidget.videoId || isActive != oldWidget.isActive;
}
