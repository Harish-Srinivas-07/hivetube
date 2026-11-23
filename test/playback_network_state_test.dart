import 'package:flutter_test/flutter_test.dart';
import 'package:hivetube/core/playback/playback_network_state.dart';

void main() {
  test('deferred recovery runs once when network returns', () {
    final network = PlaybackNetworkState();
    expect(network.updateOnline(false), isFalse);
    network.deferRecovery();

    expect(network.updateOnline(true), isTrue);
    expect(network.updateOnline(true), isFalse);
  });

  test('network recovery without a deferred error does not reload', () {
    final network = PlaybackNetworkState();
    expect(network.updateOnline(false), isFalse);
    expect(network.updateOnline(true), isFalse);
  });
}
