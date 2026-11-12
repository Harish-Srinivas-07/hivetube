import 'package:flutter_test/flutter_test.dart';
import 'package:hivetube/core/yt/parser.dart';

void main() {
  test('parses channel and separate images from a home lockup', () {
    final page = parseVideos({
      'lockupViewModel': {
        'contentId': 'video1',
        'contentImage': {
          'thumbnailViewModel': {
            'image': {
              'sources': [
                {'url': 'https://i.ytimg.com/vi/video1/hqdefault.jpg'},
              ],
            },
          },
        },
        'metadata': {
          'lockupMetadataViewModel': {
            'title': {'content': 'Video'},
            'image': {
              'avatarViewModel': {
                'image': {
                  'sources': [
                    {'url': '//yt3.ggpht.com/channel'},
                  ],
                },
              },
            },
            'metadata': {
              'contentMetadataViewModel': {
                'metadataRows': [
                  {
                    'metadataParts': [
                      {
                        'text': {
                          'content': 'Channel',
                          'commandRuns': [
                            {
                              'onTap': {
                                'innertubeCommand': {
                                  'browseEndpoint': {'browseId': 'UCchannel'},
                                },
                              },
                            },
                          ],
                        },
                      },
                    ],
                  },
                  {
                    'metadataParts': [
                      {
                        'text': {'content': '1M views'},
                      },
                    ],
                  },
                ],
              },
            },
          },
        },
      },
    });
    final video = page.items.single;
    expect(video.channelName, 'Channel');
    expect(video.channelId, 'UCchannel');
    expect(video.channelAvatarUrl, 'https://yt3.ggpht.com/channel');
    expect(video.thumbUrl, 'https://i.ytimg.com/vi/video1/hqdefault.jpg');
  });

  test('parses legacy channel name and logo', () {
    final video = parseVideos({
      'videoRenderer': {
        'videoId': 'video2',
        'title': {'simpleText': 'Video'},
        'longBylineText': {
          'runs': [
            {
              'text': 'Legacy channel',
              'navigationEndpoint': {
                'browseEndpoint': {'browseId': 'UClegacy'},
              },
            },
          ],
        },
        'channelThumbnailSupportedRenderers': {
          'channelThumbnailWithLinkRenderer': {
            'thumbnail': {
              'thumbnails': [
                {'url': 'https://yt3.ggpht.com/legacy'},
              ],
            },
          },
        },
      },
    }).items.single;
    expect(video.channelName, 'Legacy channel');
    expect(video.channelId, 'UClegacy');
    expect(video.channelAvatarUrl, 'https://yt3.ggpht.com/legacy');
    expect(video.thumbUrl, 'https://i.ytimg.com/vi/video2/hqdefault.jpg');
  });

  test(
    'selects largest renderer image and normalizes protocol relative URL',
    () {
      final video = parseVideos({
        'videoRenderer': {
          'videoId': 'v3',
          'title': {'simpleText': 'Video'},
          'channelThumbnail': {
            'thumbnails': [
              {'url': '//yt3.ggpht.com/small', 'width': 40},
              {'url': 'http://yt3.ggpht.com/large', 'width': 120},
            ],
          },
        },
      }).items.single;
      expect(video.channelAvatarUrl, 'https://yt3.ggpht.com/large');
    },
  );

  test('missing avatar remains empty without throwing', () {
    final video = parseVideos({
      'videoRenderer': {
        'videoId': 'v4',
        'title': {'simpleText': 'Video'},
        'ownerText': {
          'runs': [
            {
              'text': 'Channel',
              'navigationEndpoint': {
                'browseEndpoint': {'browseId': 'UCmissing'},
              },
            },
          ],
        },
      },
    }).items.single;
    expect(video.channelAvatarUrl, isEmpty);
    expect(video.channelId, 'UCmissing');
  });

  test('parses decorated lockup avatar recursively', () {
    final video = parseVideos({
      'lockupViewModel': {
        'contentId': 'v5',
        'metadata': {
          'lockupMetadataViewModel': {
            'title': {'content': 'Video'},
            'decoratedAvatarViewModel': {
              'avatar': {
                'avatarViewModel': {
                  'image': {
                    'sources': [
                      {'url': 'https://yt3.ggpht.com/decorated', 'width': 90},
                    ],
                  },
                },
              },
            },
          },
        },
      },
    }).items.single;
    expect(video.channelAvatarUrl, 'https://yt3.ggpht.com/decorated');
  });
}
