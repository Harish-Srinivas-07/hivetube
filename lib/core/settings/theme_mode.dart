import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';

final initialThemeModeProvider = Provider<ThemeMode>((ref) => ThemeMode.system);
final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);

class ThemeModeController extends Notifier<ThemeMode> {
  Future<void> _pending = Future.value();

  @override
  ThemeMode build() => ref.watch(initialThemeModeProvider);

  Future<void> setMode(ThemeMode mode) {
    state = mode;
    final db = ref.read(dbProvider);
    _pending = _pending.then(
      (_) => db.setValue('settings_theme_mode', mode.name),
    );
    return _pending;
  }
}
