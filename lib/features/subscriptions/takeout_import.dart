import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_db.dart';
import '../../core/providers.dart';
import '../../core/yt/takeout_parser.dart';

Future<void> importSubscriptionsFromTakeout(
  BuildContext context,
  WidgetRef ref,
) async {
  try {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (file == null) return;
    if (!context.mounted) return;

    final content = file.path != null
        ? await File(file.path!).readAsString()
        : await file.xFile.readAsString();
    final parsed = parseTakeoutCsv(content);
    if (parsed.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No subscriptions found in CSV file.')),
        );
      }
      return;
    }

    final db = ref.read(dbProvider);
    final now = DateTime.now().millisecondsSinceEpoch;
    var added = 0;
    await db.transaction(() async {
      for (final item in parsed) {
        final existing = await db.subscriptionsDao.getSubscription(
          item.channelId,
        );
        if (existing == null) {
          await db
              .into(db.subscriptions)
              .insert(
                SubscriptionsCompanion.insert(
                  channelId: item.channelId,
                  name: item.title,
                  avatarUrl: '',
                  subscribedAt: now,
                  lastFeedAt: const Value(0),
                ),
              );
          added++;
        } else if ((existing.name.isEmpty ||
                existing.name == existing.channelId) &&
            item.title != item.channelId) {
          await (db.update(db.subscriptions)
                ..where((row) => row.channelId.equals(item.channelId)))
              .write(SubscriptionsCompanion(name: Value(item.title)));
        }
      }
    });

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Added $added subscriptions${parsed.length > added ? ' (${parsed.length - added} already existed)' : ''}. Refreshing feed...',
          ),
        ),
      );
    }

    await ref.read(subscriptionsFeedServiceProvider).refreshFeed(force: true);
    ref.invalidate(subscriptionsStreamProvider);
    ref.invalidate(feedItemsStreamProvider);
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Import failed: $error')));
    }
  }
}
