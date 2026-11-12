import 'package:flutter_test/flutter_test.dart';
import 'package:hivetube/core/yt/captions.dart';
import 'package:hivetube/core/yt/watch_info.dart';
import 'package:hivetube/core/yt/yt_comments.dart';
import 'package:hivetube/core/yt/models.dart';
import 'package:hivetube/features/watch/watch_rules.dart';

void main() {
  test('parses watch metadata, related videos and chapters', () {
    final info = parseWatchInfo({
      'videoPrimaryInfoRenderer': {
        'title': {
          'runs': [
            {'text': 'Title'},
          ],
        },
        'videoViewCountRenderer': {
          'viewCount': {'simpleText': '123 views'},
        },
        'segmentedLikeDislikeButtonViewModel': {
          'buttonViewModel': {'iconName': 'LIKE', 'title': '42'},
        },
      },
      'videoSecondaryInfoRenderer': {
        'videoOwnerRenderer': {
          'title': {'simpleText': 'Channel'},
          'navigationEndpoint': {
            'browseEndpoint': {'browseId': 'UCtest'},
          },
        },
        'description': {'simpleText': 'Description'},
      },
      'secondaryResults': {
        'results': [
          {
            'compactVideoRenderer': {
              'videoId': 'video2',
              'title': {'simpleText': 'Next'},
            },
          },
        ],
      },
      'markersMap': [
        {
          'chapterRenderer': {
            'title': {'simpleText': 'Chapter'},
            'timeRangeStartMillis': 5000,
          },
        },
      ],
    }, 'video1');
    expect(info.title, 'Title');
    expect(info.likes, '42');
    expect(info.views, '123 views');
    expect(info.related.items.single.id, 'video2');
    expect(info.chapters.single.start, const Duration(seconds: 5));
  });
  test('joins comment entity to thread and reply token', () {
    final page = parseComments({
      'commentEntityPayload': {
        'key': 'key',
        'properties': {
          'commentId': 'c1',
          'content': {'content': 'Hello'},
          'publishedTime': '1 day ago',
        },
        'author': {
          'displayName': '@author',
          'avatarThumbnailUrl': 'https://example.com/a',
          'isVerified': true,
        },
        'toolbar': {'likeCountNotliked': '42', 'replyCount': '2'},
      },
      'commentThreadRenderer': {
        'commentViewModel': {'commentKey': 'key', 'pinnedText': 'Pinned'},
        'replies': {
          'continuationCommand': {'token': 'reply-token'},
        },
      },
    });
    expect(page.items.single.author, '@author');
    expect(page.items.single.replyToken, 'reply-token');
    expect(page.items.single.verified, true);
  });
  test('cleans timed karaoke markup', () {
    expect(cleanVtt('WEBVTT\n<00:00:15.080><c>hello</c>'), 'WEBVTT\nhello');
    expect(
      transcriptToVtt({
        'transcriptCueRenderer': {
          'startOffsetMs': '1000',
          'durationMs': '2000',
          'cue': {'simpleText': 'Hello'},
        },
      }),
      contains('00:00:01.000 --> 00:00:03.000\nHello'),
    );
  });
  test('back handling respects lock, fullscreen, panel, page order', () {
    expect(
      watchBackAction(locked: true, fullscreen: true, panelOpen: true),
      WatchBackAction.locked,
    );
    expect(
      watchBackAction(locked: false, fullscreen: true, panelOpen: true),
      WatchBackAction.fullscreen,
    );
    expect(
      watchBackAction(locked: false, fullscreen: false, panelOpen: true),
      WatchBackAction.panel,
    );
    expect(
      watchBackAction(locked: false, fullscreen: false, panelOpen: false),
      WatchBackAction.page,
    );
  });
  test('up next prefers queue and skips finished, live and Shorts', () {
    const queue = VideoItem(id: 'queue', title: 'Queue');
    const valid = VideoItem(id: 'valid', title: 'Valid');
    const candidates = [
      VideoItem(id: 'done', title: ''),
      VideoItem(id: 'live', title: '', isLive: true),
      VideoItem(id: 'short', title: '', isShort: true),
      valid,
    ];
    expect(
      selectUpNext(
        queue: [queue],
        related: candidates,
        finished: {'done'},
        currentId: 'now',
      ),
      queue,
    );
    expect(
      selectUpNext(
        queue: [],
        related: candidates,
        finished: {'done'},
        currentId: 'now',
      ),
      valid,
    );
  });
}
