import 'package:flutter_riverpod/flutter_riverpod.dart';

class WatchSessionState {
  const WatchSessionState({this.previous = const [], this.watched = const {}});
  final List<String> previous;
  final Set<String> watched;
}

final watchSessionProvider =
    NotifierProvider<WatchSessionController, WatchSessionState>(
      WatchSessionController.new,
    );

class WatchSessionController extends Notifier<WatchSessionState> {
  @override
  WatchSessionState build() => const WatchSessionState();

  void opened(String? previous, String next, {bool record = true}) {
    state = WatchSessionState(
      previous: [
        ...state.previous,
        if (record && previous != null && previous != next) previous,
      ],
      watched: {...state.watched, next},
    );
  }

  String? popPrevious() {
    if (state.previous.isEmpty) return null;
    final id = state.previous.last;
    state = WatchSessionState(
      previous: state.previous.sublist(0, state.previous.length - 1),
      watched: state.watched,
    );
    return id;
  }

  String? firstUnplayed(Iterable<String> ids) {
    for (final id in ids) {
      if (!state.watched.contains(id)) return id;
    }
    return null;
  }
}
