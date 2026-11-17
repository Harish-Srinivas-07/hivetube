import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/playback/playback_service.dart';
import '../../core/streams/adaptive_quality_policy.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_spacing.dart';
import '../sheets/app_sheet.dart';

/// Keeps sleep-timer state with the player UI, rather than with an open sheet.
class PlayerSettingsSession {
  PlayerSettingsSession(this.service) {
    service.addListener(_onChanged);
  }
  final PlaybackService service;
  Timer? _timer;
  bool sleepAtEnd = false;
  bool get timerActive => _timer?.isActive ?? false;
  void setSleep(Duration? duration, {bool atEnd = false}) {
    _timer?.cancel();
    sleepAtEnd = atEnd;
    if (duration != null) {
      _timer = Timer(duration, () => unawaited(service.pause()));
    }
  }

  void _onChanged() {
    if (sleepAtEnd && service.state.status == PlayerStatus.ended) {
      sleepAtEnd = false;
      unawaited(service.pause());
    }
  }

  void dispose() {
    _timer?.cancel();
    service.removeListener(_onChanged);
  }
}

Future<void> showPlayerSettingsMenu(
  BuildContext context, {
  required PlayerSettingsSession session,
  VoidCallback? onLock,
  bool floating = false,
}) => showAppSheet<void>(
  context,
  fit: true,
  onVideo: true,
  floatingInset: floating,
  extendToBottom: true,
  sideMargin: floating ? AppSpacing.xs : AppSpacing.sm,
  bottomMargin: floating ? AppSpacing.none : AppSpacing.sm,
  showClose: false,
  builder: (_, _) => _PlayerSettingsView(session: session, onLock: onLock),
);

class _PlayerSettingsView extends StatefulWidget {
  const _PlayerSettingsView({required this.session, this.onLock});
  final PlayerSettingsSession session;
  final VoidCallback? onLock;
  @override
  State<_PlayerSettingsView> createState() => _PlayerSettingsViewState();
}

class _PlayerSettingsViewState extends State<_PlayerSettingsView> {
  String page = 'Settings';
  bool _pageChangePending = false;
  bool _selectionClosing = false;
  PlaybackService get service => widget.session.service;
  @override
  void initState() {
    super.initState();
    service.addListener(_refresh);
  }

  @override
  void dispose() {
    service.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _page(String value) {
    if (_pageChangePending) return;
    _pageChangePending = true;
    unawaited(
      Future<void>.delayed(AppMotion.imageFade, () {
        if (!mounted) return;
        setState(() {
          page = value;
          _pageChangePending = false;
        });
      }),
    );
  }

  Widget _choice(String label, bool selected, VoidCallback action) =>
      AppSheetRow(
        label: label,
        selected: selected,
        onTap: () {
          if (_selectionClosing) return;
          _selectionClosing = true;
          action();
          setState(() {});
          unawaited(
            Future<void>.delayed(AppMotion.imageFade, () {
              if (mounted) {
                Navigator.of(context, rootNavigator: true).pop();
              }
            }),
          );
        },
      );
  @override
  Widget build(BuildContext context) {
    final state = service.state;
    final quality = state.quality;
    final liveQuality = state.autoQualityHeight ?? state.heights.firstOrNull;
    final parentPage = switch (page) {
      'Sleep timer' => 'More',
      'Advanced quality' => 'Quality',
      _ => 'Settings',
    };
    final currentQuality = quality != null
        ? '${quality}p'
        : switch (service.qualityPreference) {
            VideoQualityPreference.auto =>
              'Auto${liveQuality == null ? '' : ' (${liveQuality}p)'}',
            VideoQualityPreference.always1080 =>
              '${AdaptiveQualityPolicy.quality1080}p',
            VideoQualityPreference.always720 =>
              '${AdaptiveQualityPolicy.quality720}p',
            VideoQualityPreference.always480 =>
              '${AdaptiveQualityPolicy.quality480}p',
            VideoQualityPreference.always360 =>
              '${AdaptiveQualityPolicy.quality360}p',
            VideoQualityPreference.dataSaver => 'Data saver',
          };
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.all(AppSpacing.none),
      children: [
        if (page != 'Settings')
          AppSheetRow(
            icon: LucideIcons.chevronLeft,
            label: page,
            onTap: () => _page(parentPage),
          ),
        if (page == 'Settings') ...[
          AppSheetRow(
            icon: LucideIcons.slidersHorizontal,
            label: 'Quality',
            value: currentQuality,
            showChevron: true,
            onTap: () => _page('Quality'),
          ),
          AppSheetRow(
            icon: LucideIcons.circlePlay,
            label: 'Playback speed',
            value: '${state.rate}x',
            showChevron: true,
            onTap: () => _page('Playback speed'),
          ),
          if (state.captions.isNotEmpty)
            AppSheetRow(
              icon: LucideIcons.captions,
              label: 'Captions',
              value: state.selectedCaption == null
                  ? 'Off'
                  : '${state.captions[state.selectedCaption!]['languageCode'] ?? ''}',
              showChevron: true,
              onTap: () => _page('Captions'),
            ),
          if (widget.onLock != null)
            AppSheetRow(
              icon: LucideIcons.lock,
              label: 'Lock screen',
              onTap: () {
                Navigator.pop(context);
                widget.onLock!();
              },
            ),
          AppSheetRow(
            icon: LucideIcons.settings,
            label: 'More',
            showChevron: true,
            onTap: () => _page('More'),
          ),
        ],
        if (page == 'Quality') ...[
          _choice(
            'Auto${liveQuality == null ? '' : ' (${liveQuality}p)'}',
            quality == null &&
                service.qualityPreference == VideoQualityPreference.auto,
            () => unawaited(
              service.setQualityPreference(VideoQualityPreference.auto),
            ),
          ),
          _choice(
            '${AdaptiveQualityPolicy.quality1080}p',
            quality == null &&
                service.qualityPreference == VideoQualityPreference.always1080,
            () => unawaited(
              service.setQualityPreference(VideoQualityPreference.always1080),
            ),
          ),
          _choice(
            '${AdaptiveQualityPolicy.quality720}p',
            quality == null &&
                service.qualityPreference == VideoQualityPreference.always720,
            () => unawaited(
              service.setQualityPreference(VideoQualityPreference.always720),
            ),
          ),
          _choice(
            '${AdaptiveQualityPolicy.quality480}p',
            quality == null &&
                service.qualityPreference == VideoQualityPreference.always480,
            () => unawaited(
              service.setQualityPreference(VideoQualityPreference.always480),
            ),
          ),
          _choice(
            '${AdaptiveQualityPolicy.quality360}p',
            quality == null &&
                service.qualityPreference == VideoQualityPreference.always360,
            () => unawaited(
              service.setQualityPreference(VideoQualityPreference.always360),
            ),
          ),
          _choice(
            'Data saver',
            quality == null &&
                service.qualityPreference == VideoQualityPreference.dataSaver,
            () => unawaited(
              service.setQualityPreference(VideoQualityPreference.dataSaver),
            ),
          ),
          AppSheetRow(
            label: 'Advanced options',
            showChevron: true,
            onTap: () => _page('Advanced quality'),
          ),
        ],
        if (page == 'Advanced quality') ...[
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: Text(
              'For this video',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          for (final height in state.heights.toSet().where(
            (h) => h <= AdaptiveQualityPolicy.maxVideoHeight,
          ))
            _choice(
              '${height}p',
              quality == height,
              () => service.setQuality(height),
            ),
          if (state.heights.isEmpty)
            const AppSheetRow(label: 'No quality options available'),
        ],
        if (page == 'Playback speed')
          for (final speed in [.25, .5, .75, 1.0, 1.25, 1.5, 1.75, 2.0])
            _choice(
              '${speed}x',
              state.rate == speed,
              () => unawaited(service.setRate(speed)),
            ),
        if (page == 'Captions') ...[
          _choice(
            'Off',
            state.selectedCaption == null,
            () => unawaited(service.setCaption(null)),
          ),
          for (var i = 0; i < state.captions.length; i++) ...[
            Builder(
              builder: (context) {
                final track = state.captions[i];
                final name =
                    (track['name'] is Map
                        ? (track['name'] as Map)['simpleText']
                        : null) ??
                    track['languageCode'] ??
                    'Captions';
                final isAsr =
                    track['kind'] == 'asr' ||
                    (track['vssId'] as String? ?? '').startsWith('a.');
                final label =
                    isAsr && !name.toString().contains('auto-generated')
                    ? '$name (auto-generated)'
                    : '$name';
                return _choice(
                  label,
                  state.selectedCaption == i,
                  () => unawaited(service.setCaption(i)),
                );
              },
            ),
          ],
        ],
        if (page == 'More') ...[
          AppSheetRow(
            icon: LucideIcons.timer,
            label: 'Sleep timer',
            value: widget.session.sleepAtEnd
                ? 'End of video'
                : widget.session.timerActive
                ? 'On'
                : 'Off',
            showChevron: true,
            onTap: () => _page('Sleep timer'),
          ),
          SwitchListTile(
            secondary: const Icon(LucideIcons.repeat),
            title: const Text('Loop'),
            value: state.loop,
            onChanged: (value) => unawaited(service.setLoop(value)),
          ),
          AppSheetRow(
            icon: LucideIcons.info,
            label: 'Stats for nerds',
            subtitle:
                'Resolution: ${state.videoWidth ?? '—'} × ${state.videoHeight ?? '—'}',
          ),
        ],
        if (page == 'Sleep timer') ...[
          _choice(
            'Off',
            !widget.session.timerActive && !widget.session.sleepAtEnd,
            () => widget.session.setSleep(null),
          ),
          for (final minutes in [10, 20, 30, 45, 60])
            _choice(
              '$minutes minutes',
              false,
              () => widget.session.setSleep(Duration(minutes: minutes)),
            ),
          _choice(
            'End of video',
            widget.session.sleepAtEnd,
            () => widget.session.setSleep(null, atEnd: true),
          ),
        ],
      ],
    );
  }
}
