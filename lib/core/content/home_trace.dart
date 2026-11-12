abstract class ChangeNotifier {
  final List<void Function()> _listeners = [];
  void addListener(void Function() listener) => _listeners.add(listener);
  void removeListener(void Function() listener) => _listeners.remove(listener);
  void notifyListeners() {
    for (final listener in List.of(_listeners)) {
      listener();
    }
  }
}

class HomeTraceItem {
  HomeTraceItem({
    required this.id,
    required this.title,
    required this.channelName,
    required this.source,
    this.scriptVerdict,
    this.lexiconVerdict,
    this.channelVoteVerdict,
    this.probeVerdict,
    required this.finalLanguage,
    required this.kept,
    required this.reason,
    this.matchedWords = const [],
    this.isAmbiguous = false,
  });

  final String id;
  final String title;
  final String channelName;
  final String source;
  final String? scriptVerdict;
  final String? lexiconVerdict;
  final String? channelVoteVerdict;
  final String? probeVerdict;
  final String finalLanguage;
  final bool kept;
  final String reason;
  final List<String> matchedWords;
  final bool isAmbiguous;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'channel': channelName,
    'source': source,
    'script': scriptVerdict,
    'lexicon': lexiconVerdict,
    'channelVotes': channelVoteVerdict,
    'probe': probeVerdict,
    'finalLanguage': finalLanguage,
    'kept': kept,
    'reason': reason,
    'matchedWords': matchedWords,
    'isAmbiguous': isAmbiguous,
  };

  @override
  String toString() =>
      '[$finalLanguage] ${kept ? "KEPT" : "DROPPED ($reason)"} | src=$source | "${title.length > 40 ? "${title.substring(0, 40)}..." : title}" by $channelName (script=$scriptVerdict, lex=$lexiconVerdict, ch=$channelVoteVerdict, probe=$probeVerdict)';
}

class HomeTraceStore extends ChangeNotifier {
  static final HomeTraceStore instance = HomeTraceStore._();
  HomeTraceStore._();

  final List<HomeTraceItem> _traces = [];

  List<HomeTraceItem> get traces => List.unmodifiable(_traces);

  void clear() {
    _traces.clear();
    notifyListeners();
  }

  void record(HomeTraceItem trace) {
    _traces.add(trace);
    if (_traces.length > 500) {
      _traces.removeRange(0, _traces.length - 500);
    }
    notifyListeners();
  }

  String dumpLog() {
    final buffer = StringBuffer('=== HOME TRACE DUMP (${_traces.length} items) ===\n');
    for (var i = 0; i < _traces.length; i++) {
      buffer.writeln('${i + 1}. ${_traces[i]}');
    }
    return buffer.toString();
  }
}

