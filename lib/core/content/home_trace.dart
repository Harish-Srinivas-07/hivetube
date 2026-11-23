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
    this.detectionSource = 'unknown',
    this.confidence = 0,
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
  final String detectionSource;
  final double confidence;

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
    'detectionSource': detectionSource,
    'confidence': confidence,
  };

  @override
  String toString() =>
      '[$finalLanguage] ${kept ? "KEPT" : "DROPPED"} ($reason) | src=$source | "${title.length > 40 ? "${title.substring(0, 40)}..." : title}" by $channelName (detector=$detectionSource, confidence=${confidence.toStringAsFixed(2)}, script=$scriptVerdict, lex=$lexiconVerdict, ch=$channelVoteVerdict, probe=$probeVerdict)';
}

class HomeTraceStore extends ChangeNotifier {
  static final HomeTraceStore instance = HomeTraceStore._();
  HomeTraceStore._();

  final List<HomeTraceItem> _traces = [];
  final Set<String> _warnings = {};

  List<HomeTraceItem> get traces => List.unmodifiable(_traces);
  List<String> get warnings => List.unmodifiable(_warnings);

  void warnMissingLatinLexicon(String code) {
    if (_warnings.add('no latin lexicon for $code')) notifyListeners();
  }

  void clear() {
    _traces.clear();
    _warnings.clear();
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
    final buffer = StringBuffer(
      '=== HOME TRACE DUMP (${_traces.length} items) ===\n',
    );
    for (final warning in _warnings) {
      buffer.writeln('WARNING: $warning');
    }
    final uniqueIds = <String>{};
    var keptCount = 0;
    var droppedCount = 0;
    var unknownKeptCount = 0;
    final sourceCounts = <String, ({int total, int kept})>{};

    for (var i = 0; i < _traces.length; i++) {
      final t = _traces[i];
      uniqueIds.add(t.id);
      if (t.kept) {
        keptCount++;
        if (t.finalLanguage == 'unknown') unknownKeptCount++;
      } else {
        droppedCount++;
      }
      final s = sourceCounts[t.source] ?? (total: 0, kept: 0);
      sourceCounts[t.source] = (
        total: s.total + 1,
        kept: s.kept + (t.kept ? 1 : 0),
      );
      buffer.writeln('${i + 1}. $t');
    }

    final unknownPercent = keptCount == 0
        ? 0.0
        : (unknownKeptCount / keptCount * 100);

    buffer.writeln('\n=== TRACE SUMMARY ===');
    buffer.writeln('Total processed: ${_traces.length}');
    buffer.writeln('Unique items: ${uniqueIds.length}');
    buffer.writeln(
      'Kept: $keptCount (${_traces.isEmpty ? 0 : (keptCount / _traces.length * 100).toStringAsFixed(1)}%)',
    );
    buffer.writeln('Dropped: $droppedCount');
    buffer.writeln(
      'Unknown kept: $unknownKeptCount (${unknownPercent.toStringAsFixed(1)}% of kept feed)',
    );
    buffer.writeln('Source breakdown:');
    for (final entry in sourceCounts.entries) {
      buffer.writeln(
        '  - ${entry.key}: ${entry.value.kept} kept / ${entry.value.total} total',
      );
    }
    return buffer.toString();
  }
}
