class HomeRefreshGuard {
  bool _touched = false;
  void interact() => _touched = true;
  bool get canApply => !_touched;
}

class PaginationGuard {
  bool _running = false;
  bool begin() {
    if (_running) return false;
    _running = true;
    return true;
  }

  void end() => _running = false;
}
