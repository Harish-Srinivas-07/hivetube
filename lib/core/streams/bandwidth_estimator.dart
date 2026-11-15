import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'adaptive_quality_policy.dart';
import 'stream_selector.dart';

/// Measures stream throughput and maintains a smoothed estimate in Mbps.
class BandwidthEstimator {
  BandwidthEstimator(this._dio);

  final Dio _dio;
  double? _ewmaMbps;
  final Set<CancelToken> _activeProbes = {};

  double? get ewmaMbps => _ewmaMbps;

  double? addSample(int bytes, Duration elapsed) {
    if (bytes <= 0 || elapsed <= Duration.zero) return _ewmaMbps;
    final sampleMbps = bytes * 8 / elapsed.inMicroseconds;
    _ewmaMbps = _ewmaMbps == null
        ? sampleMbps
        : _ewmaMbps! +
              AdaptiveQualityPolicy.ewmaAlpha * (sampleMbps - _ewmaMbps!);
    return _ewmaMbps;
  }

  Future<double?> probe(
    StreamFormat format, {
    Duration timeout = AdaptiveQualityPolicy.probeTimeout,
  }) async {
    final token = CancelToken();
    _activeProbes.add(token);
    try {
      return await _probe(format, token).timeout(timeout);
    } on TimeoutException {
      token.cancel('Bandwidth probe timed out');
      return null;
    } catch (_) {
      return null;
    } finally {
      _activeProbes.remove(token);
    }
  }

  Future<double?> _probe(StreamFormat format, CancelToken token) async {
    final stopwatch = Stopwatch()..start();
    final response = await _dio.get<ResponseBody>(
      format.url.toString(),
      cancelToken: token,
      options: Options(
        responseType: ResponseType.stream,
        headers: {
          'Range': 'bytes=0-${AdaptiveQualityPolicy.probeBytes - 1}',
          if (format.userAgent != null) 'User-Agent': format.userAgent,
        },
        validateStatus: (status) => status != null && status < 500,
      ),
    );
    if (response.statusCode != 206 || response.data == null) return null;

    final iterator = StreamIterator<Uint8List>(response.data!.stream);
    var bytes = 0;
    try {
      while (bytes < AdaptiveQualityPolicy.probeBytes &&
          await iterator.moveNext()) {
        bytes += iterator.current.length;
      }
    } finally {
      await iterator.cancel();
    }
    stopwatch.stop();
    return addSample(bytes, stopwatch.elapsed);
  }

  void dispose() {
    for (final token in _activeProbes) {
      token.cancel('Bandwidth estimator disposed');
    }
    _activeProbes.clear();
  }
}
