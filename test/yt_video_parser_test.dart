import 'package:flutter_test/flutter_test.dart';
import 'package:hivetube/core/yt/parser.dart';

void main() {
  test('parses channel and separate images from a home lockup', () {
    final page = parseVideos({
      'lockupViewModel': {
        'contentId': 'video1',
        'contentImage': {'thumbnailViewModel': {'image': {'sources': [{'url': 'https://i.ytimg.com/vi/video1/hqdefault.jpg'}]}}},
        'metadata': {'lockupMetadataViewModel': {
          'title': {'content': 'Video'},
          'image': {'avatarViewModel': {'image': {'sources': [{'url': '//yt3.ggpht.com/channel'}]}}},
          'metadata': {'contentMetadataViewModel': {'metadataRows': [
            {'metadataParts': [{'text': {'content': 'Channel', 'commandRuns': [{'onTap': {'innertubeCommand': {'browseEndpoint': {'browseId': 'UCchannel'}}}}]}}]},
            {'metadataParts': [{'text': {'content': '1M views'}}]},
          ]}},
        }},
      },
    });
    final video = page.items.single;
    expect(video.channelName, 'Channel');
    expect(video.channelId, 'UCchannel');
    expect(video.channelAvatarUrl, 'https://yt3.ggpht.com/channel');
    expect(video.thumbUrl, 'https://i.ytimg.com/vi/video1/hqdefault.jpg');
  });

  test('parses legacy channel name and logo', () {
    final video = parseVideos({'videoRenderer': {
      'videoId': 'video2',
      'title': {'simpleText': 'Video'},
      'longBylineText': {'runs': [{'text': 'Legacy channel', 'navigationEndpoint': {'browseEndpoint': {'browseId': 'UClegacy'}}}]},
      'channelThumbnailSupportedRenderers': {'channelThumbnailWithLinkRenderer': {'thumbnail': {'thumbnails': [{'url': 'https://yt3.ggpht.com/legacy'}]}}},
    }}).items.single;
    expect(video.channelName, 'Legacy channel');
    expect(video.channelId, 'UClegacy');
    expect(video.channelAvatarUrl, 'https://yt3.ggpht.com/legacy');
    expect(video.thumbUrl, 'https://i.ytimg.com/vi/video2/hqdefault.jpg');
  });
}
