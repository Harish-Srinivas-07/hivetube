import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivetube/core/innertube/innertube_http.dart';
import 'package:hivetube/core/yt/yt_browse.dart';

class _PlaylistHttp extends Fake implements InnertubeHttp {
  final calls = <({String endpoint, Map<String, dynamic> data})>[];

  @override
  Future<dynamic> post(
    String endpoint,
    Map<String, dynamic> data, {
    String clientName = 'WEB',
    bool refreshOnForbidden = true,
    CancelToken? cancelToken,
  }) async {
    calls.add((endpoint: endpoint, data: data));
    if (endpoint == 'browse') {
      return {
        'playlistVideoRenderer': {
          'videoId': 'regular-video',
          'title': {'simpleText': 'Regular video'},
        },
      };
    }
    if (data.containsKey('continuation')) {
      return {
        'appendContinuationItemsAction': {
          'continuationItems': [
            {
              'playlistPanelVideoRenderer': {
                'videoId': 'second',
                'title': {'simpleText': 'Second video'},
              },
            },
          ],
        },
      };
    }
    return {
      'playlist': {
        'playlist': {
          'playlistId': 'RDexample',
          'title': 'A Mix',
          'contents': [
            {
              'playlistPanelVideoRenderer': {
                'videoId': 'first',
                'title': {'simpleText': 'First video'},
                'lengthText': {'simpleText': '3:15'},
              },
            },
            {
              'continuationItemRenderer': {
                'continuationEndpoint': {
                  'continuationCommand': {'token': 'next-page'},
                },
              },
            },
          ],
        },
      },
      'videoRenderer': {
        'videoId': 'unrelated',
        'title': {'simpleText': 'Related video'},
      },
    };
  }
}

void main() {
  test(
    'search Mix opens its playlist panel and regular playlists use browse',
    () async {
      final http = _PlaylistHttp();
      final browse = YtBrowse(http);
      final mix = await browse.playlistPage('RDexample');
      expect(http.calls.first.endpoint, 'next');
      expect(http.calls.first.data, {'playlistId': 'RDexample'});
      expect(mix.title, 'A Mix');
      expect(mix.videos.map((video) => video.id), ['first']);
      expect(mix.videos.single.durationText, '3:15');
      expect(mix.continuation, 'next-page');

      final next = await browse.playlistPage(
        'RDexample',
        continuation: mix.continuation,
      );
      expect(http.calls[1].endpoint, 'next');
      expect(next.videos.map((video) => video.id), ['second']);

      final regular = await browse.playlistPage('PLexample');
      expect(http.calls.last.endpoint, 'browse');
      expect(http.calls.last.data, {'browseId': 'VLPLexample'});
      expect(regular.videos.single.id, 'regular-video');
    },
  );
}
