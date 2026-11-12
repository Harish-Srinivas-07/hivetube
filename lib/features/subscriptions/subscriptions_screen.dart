import 'package:flutter/material.dart';

class SubscriptionsScreen extends StatelessWidget {
  const SubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: Text(
          'Subscriptions',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
    ),
  );
}
