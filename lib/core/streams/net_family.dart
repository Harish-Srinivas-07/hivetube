import 'dart:io';

/// Owns the single pool used for player extraction, probes, and relay requests.
class NetworkFamily {
  NetworkFamily({this.savePreference, this.preferIpv4 = true}) {
    _create();
  }
  final Future<void> Function(bool)? savePreference;
  void Function()? onChanged;
  bool preferIpv4;
  late HttpClient client;
  final List<HttpClient> _retired = [];
  void _create() {
    final preferred = preferIpv4
        ? InternetAddressType.IPv4
        : InternetAddressType.IPv6;
    client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    client.connectionFactory = (uri, proxyHost, proxyPort) async {
      final host = proxyHost ?? uri.host;
      final port = proxyPort ?? uri.port;
      var addresses = await InternetAddress.lookup(host, type: preferred);
      if (addresses.isEmpty) {
        throw const SocketException('No address for selected network family');
      }
      return proxyHost == null && uri.scheme == 'https'
          ? SecureSocket.startConnect(
              addresses.first,
              port,
              supportedProtocols: ['http/1.1'],
            )
          : Socket.startConnect(addresses.first, port);
    };
  }

  Future<void> flip(bool previous) async {
    if (previous != preferIpv4) return;
    preferIpv4 = !preferIpv4;
    final old = client;
    _retired.add(old);
    old.close();
    _create();
    onChanged?.call();
    await savePreference?.call(preferIpv4);
  }

  void close() {
    client.close(force: true);
    for (final old in _retired) {
      old.close(force: true);
    }
  }
}
