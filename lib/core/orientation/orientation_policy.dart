import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

final appRouteObserver = RouteObserver<ModalRoute<dynamic>>();
final homeRouteObserver = RouteObserver<ModalRoute<dynamic>>();

bool _homeScreenVisible = false;
bool _videoFullscreen = false;
bool _videoFullscreenLandscape = false;
Future<void> _orientationRequest = Future<void>.value();

Future<void> setHomeScreenOrientationEnabled(bool enabled) {
  _homeScreenVisible = enabled;
  return _applyOrientationPolicy();
}

Future<void> setVideoFullscreenOrientation(
  bool fullscreen, {
  required bool landscapeVideo,
}) {
  _videoFullscreen = fullscreen;
  _videoFullscreenLandscape = fullscreen && landscapeVideo;
  return _applyOrientationPolicy();
}

Future<void> lockPortraitForFullscreenExit() {
  _videoFullscreen = false;
  _videoFullscreenLandscape = false;
  return _setPreferredOrientations(const [DeviceOrientation.portraitUp]);
}

Future<void> reapplyCurrentOrientationPolicy() => _applyOrientationPolicy();

Future<void> _applyOrientationPolicy() {
  final orientations = _videoFullscreen
      ? _videoFullscreenLandscape
            ? const [
                DeviceOrientation.landscapeLeft,
                DeviceOrientation.landscapeRight,
              ]
            : const [DeviceOrientation.portraitUp]
      : _homeScreenVisible
      ? const [
          DeviceOrientation.portraitUp,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]
      : const [DeviceOrientation.portraitUp];
  return _setPreferredOrientations(orientations);
}

Future<void> _setPreferredOrientations(List<DeviceOrientation> orientations) {
  _orientationRequest = _orientationRequest.catchError((Object _) {}).then((
    _,
  ) async {
    await SystemChrome.setPreferredOrientations(orientations);
  });
  return _orientationRequest;
}
