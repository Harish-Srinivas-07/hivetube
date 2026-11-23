import 'json_find.dart';

String? continuationToken(dynamic json) {
  for (final item in findAll(json, 'continuationItemRenderer')) {
    final token = safeNav(item, [
      'continuationEndpoint',
      'continuationCommand',
      'token',
    ]);
    if (token is String && token.isNotEmpty) return token;
  }
  return null;
}
