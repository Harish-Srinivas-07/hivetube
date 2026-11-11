import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivetube/core/yt/parser.dart';
import 'package:hivetube/core/yt/yt_reel.dart';

dynamic fixture(String name) =>
    jsonDecode(File('test/fixtures/$name.json').readAsStringSync());
void main() {
  test('fresh sequence contains one id and continuation', () {
    final data = fixture('reel_first');
    expect(parseReelEntries(data).map((e) => e.id), ['first']);
    expect(reelContinuation(data), 'next1');
  });
  test('continuation has twelve entries and next token', () {
    final data = fixture('reel_next');
    expect(parseReelEntries(data), hasLength(12));
    expect(reelContinuation(data), 'next2');
  });
  test('duplicate ids are removed', () {
    expect(parseReelEntries(fixture('reel_duplicates')).map((e) => e.id), [
      'first',
      'second',
    ]);
  });
  test('malformed response has no entries or token', () {
    expect(parseReelEntries(fixture('reel_bad')), isEmpty);
    expect(reelContinuation(fixture('reel_bad')), isNull);
    expect(parseReelEntries('not JSON'), isEmpty);
  });
}
