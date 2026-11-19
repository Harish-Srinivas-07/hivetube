import 'package:flutter_test/flutter_test.dart';
import 'package:hivetube/widgets/common/thumbnail_with_duration.dart';

void main() {
  test('prefers max resolution for YouTube thumbnails', () {
    expect(
      preferredYoutubeThumbnailUrl(
        'https://i.ytimg.com/vi/abcdefghijk/hqdefault.jpg',
        'abcdefghijk',
      ),
      'https://i.ytimg.com/vi/abcdefghijk/maxresdefault.jpg',
    );
    expect(
      preferredYoutubeThumbnailUrl('https://example.com/thumb.jpg', 'video'),
      'https://example.com/thumb.jpg',
    );
  });
}
