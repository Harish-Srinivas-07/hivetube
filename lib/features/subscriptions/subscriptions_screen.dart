import 'package:flutter/material.dart';

class SubscriptionsScreen extends StatelessWidget {
  const SubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Text(
        'Subscriptions',
        style: Theme.of(context).textTheme.titleLarge,
      ),
    ),
  );
}
