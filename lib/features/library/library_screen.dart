import 'package:flutter/material.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Text('Library', style: Theme.of(context).textTheme.titleLarge),
    ),
  );
}
