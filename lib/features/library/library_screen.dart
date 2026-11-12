import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(LucideIcons.settings),
            title: const Text('Settings'),
            onTap: () => context.push('/settings'),
          ),
          Expanded(
            child: Center(
              child: Text('You', style: Theme.of(context).textTheme.titleLarge),
            ),
          ),
        ],
      ),
    ),
  );
}
