import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/playback/playback_service.dart';
import '../app_menu.dart';

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
}) => showAppMenu<void>(
  context: context,
  onVideo: true,
  builder: (_) => _PlayerSettingsView(session: session, onLock: onLock),
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

  void _page(String value) => setState(() => page = value);
  Widget _choice(String label, bool selected, VoidCallback action) =>
      AppMenuRow(
        label: label,
        selected: selected,
        onTap: () {
          action();
          setState(() {});
        },
      );
  @override
  Widget build(BuildContext context) {
    final state = service.state;
    final actual = state.videoHeight;
    final quality = state.quality;
    final currentQuality = quality == null
        ? 'Auto${actual == null ? '' : ' (${actual}p)'}'
        : '${quality}p';
    return ListView(
      shrinkWrap: true,
      children: [
        if (page != 'Settings')
          AppMenuRow(
            icon: LucideIcons.chevronLeft,
            label: page,
            onTap: () => _page(
              page == 'Translate captions'
                  ? 'Captions'
                  : page == 'Sleep timer'
                  ? 'More'
                  : 'Settings',
            ),
          ),
        if (page == 'Settings') ...[
          AppMenuRow(
            icon: LucideIcons.slidersHorizontal,
            label: 'Quality',
            value: currentQuality,
            showChevron: true,
            onTap: () => _page('Quality'),
          ),
          AppMenuRow(
            icon: LucideIcons.circlePlay,
            label: 'Playback speed',
            value: '${state.rate}x',
            showChevron: true,
            onTap: () => _page('Playback speed'),
          ),
          if (state.captions.isNotEmpty)
            AppMenuRow(
              icon: LucideIcons.captions,
              label: 'Captions',
              value: state.selectedCaption == null
                  ? 'Off'
                  : '${state.captions[state.selectedCaption!]['languageCode'] ?? ''}',
              showChevron: true,
              onTap: () => _page('Captions'),
            ),
          if (widget.onLock != null)
            AppMenuRow(
              icon: LucideIcons.lock,
              label: 'Lock screen',
              onTap: () {
                Navigator.pop(context);
                widget.onLock!();
              },
            ),
          AppMenuRow(
            icon: LucideIcons.settings,
            label: 'More',
            showChevron: true,
            onTap: () => _page('More'),
          ),
        ],
        if (page == 'Quality') ...[
          _choice('Auto', quality == null, () => service.setQuality(null)),
          for (final height in state.heights.toSet().where((h) => h <= 1080))
            _choice(
              '${height}p',
              quality == height,
              () => service.setQuality(height),
            ),
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
          for (var i = 0; i < state.captions.length; i++)
            _choice(
              '${state.captions[i]['languageCode'] ?? 'Captions'}',
              state.selectedCaption == i,
              () => unawaited(service.setCaption(i)),
            ),
          if (state.captions.any((track) => track['isTranslatable'] == true) &&
              state.captionTranslations.isNotEmpty)
            AppMenuRow(
              icon: LucideIcons.languages,
              label: 'Translate captions',
              showChevron: true,
              onTap: () => _page('Translate captions'),
            ),
        ],
        if (page == 'Translate captions')
          for (final language in state.captionTranslations)
            _choice(
              '${(language['languageName'] is Map ? (language['languageName'] as Map)['simpleText'] : null) ?? language['languageCode'] ?? ''}',
              false,
              () {
                final index = state.captions.indexWhere(
                  (track) => track['isTranslatable'] == true,
                );
                if (index >= 0) {
                  unawaited(
                    service.setCaption(
                      index,
                      translateTo: language['languageCode'] as String?,
                    ),
                  );
                }
              },
            ),
        if (page == 'More') ...[
          AppMenuRow(
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
          AppMenuRow(
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
