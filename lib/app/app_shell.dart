import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_top_bar.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  static const _destinations = [
    (label: 'Home', icon: Icons.home_outlined, selectedIcon: Icons.home),
    (
      label: 'Shorts',
      icon: Icons.smart_display_outlined,
      selectedIcon: Icons.smart_display,
    ),
    (
      label: 'Subscriptions',
      icon: Icons.subscriptions_outlined,
      selectedIcon: Icons.subscriptions,
    ),
    (
      label: 'Library',
      icon: Icons.video_library_outlined,
      selectedIcon: Icons.video_library,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final wide =
        MediaQuery.sizeOf(context).width >= AppSpacing.navigationBreakpoint;
    void select(int index) => navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const AppTopBar(),
            Expanded(
              child: Row(
                children: [
                  if (wide)
                    NavigationRail(
                      selectedIndex: navigationShell.currentIndex,
                      onDestinationSelected: select,
                      labelType: NavigationRailLabelType.all,
                      destinations: [
                        for (final item in _destinations)
                          NavigationRailDestination(
                            icon: Icon(item.icon),
                            selectedIcon: Icon(item.selectedIcon),
                            label: Text(item.label),
                          ),
                      ],
                    ),
                  Expanded(child: navigationShell),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: select,
              destinations: [
                for (final item in _destinations)
                  NavigationDestination(
                    icon: Icon(item.icon),
                    selectedIcon: Icon(item.selectedIcon),
                    label: item.label,
                  ),
              ],
            ),
    );
  }
}
