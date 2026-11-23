import 'package:flutter/widgets.dart';

/// Root dispatcher hook that gives the expanded player first chance at Back.
class PlayerBackButtonDispatcher extends RootBackButtonDispatcher {
  Future<bool> Function()? onPlayerBack;

  @override
  Future<bool> didPopRoute() async {
    if (await onPlayerBack?.call() ?? false) return true;
    return super.didPopRoute();
  }
}

final playerBackButtonDispatcher = PlayerBackButtonDispatcher();
