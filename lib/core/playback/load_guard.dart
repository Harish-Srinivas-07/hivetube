class LoadGuard {
  int _generation = 0;
  int? _intentionalGeneration;
  int next({bool intentional = false}) {
    _intentionalGeneration = null;
    final generation = ++_generation;
    if (intentional) _intentionalGeneration = generation;
    return generation;
  }

  bool isCurrent(int generation) => generation == _generation;
  bool isIntentional(int generation) => _intentionalGeneration == generation;
}

class RecoveryBudget {
  int _attempts = 0;
  DateTime? _playingSince;
  int get attempts => _attempts;
  void playing(DateTime now) {
    _playingSince ??= now;
  }

  void paused() {
    _playingSince = null;
  }

  void tick(DateTime now) {
    if (_playingSince != null &&
        now.difference(_playingSince!) >= const Duration(seconds: 60)) {
      _attempts = 0;
      _playingSince = now;
    }
  }

  bool take() {
    if (_attempts >= 3) return false;
    _attempts++;
    return true;
  }

  void reset() {
    _attempts = 0;
    _playingSince = null;
  }
}
