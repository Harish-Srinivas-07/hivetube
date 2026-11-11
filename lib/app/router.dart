import 'package:go_router/go_router.dart';
import '../features/home/home_screen.dart';
import '../features/watch/watch_screen.dart';
import '../features/shorts/shorts_screen.dart';
import '../features/subscriptions/subscriptions_screen.dart';
import '../features/library/library_screen.dart';
import '../features/search/search_screen.dart';
import '../features/settings/settings_screen.dart';
import 'app_shell.dart';

final appRouter = GoRouter(
  initialLocation: '/home',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          AppShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const HomeScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/shorts',
              builder: (context, state) => const ShortsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/subscriptions',
              builder: (context, state) => const SubscriptionsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/library',
              builder: (context, state) => const LibraryScreen(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/watch/:id',
      builder: (context, state) => WatchScreen(id: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(path: '/search', builder: (context, state) => const SearchScreen()),
  ],
);
