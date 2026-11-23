import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hivetube/core/playback/player_ui_state.dart';
import 'package:hivetube/features/watch/player_back_scope.dart';
import 'package:hivetube/features/watch/watch_panel.dart';

class _TestPanel extends WatchPanelController {
  @override
  String? build() => null;
}

class _TestPlayerUi extends PlayerUiController {
  @override
  PlayerUiState build() => const PlayerUiState();
}

void main() {
  testWidgets('expanded player minimizes before a root route pops', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        watchPanelProvider.overrideWith(_TestPanel.new),
        playerUiProvider.overrideWith(_TestPlayerUi.new),
      ],
    );
    addTearDown(container.dispose);
    final dispatcher = PlayerBackButtonDispatcher();
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) => const Scaffold(body: Text('Home')),
        ),
        GoRoute(
          path: '/channel',
          builder: (context, state) => const Scaffold(body: Text('Channel')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routeInformationProvider: router.routeInformationProvider,
          routeInformationParser: router.routeInformationParser,
          routerDelegate: router.routerDelegate,
          backButtonDispatcher: dispatcher,
        ),
      ),
    );
    router.push('/channel');
    await tester.pumpAndSettle();
    expect(find.text('Channel'), findsOneWidget);
    container.read(watchPanelProvider.notifier).open('video');
    container
        .read(playerUiProvider.notifier)
        .setPanelMode(PlayerPanelMode.expanded);
    await tester.pump();

    dispatcher.onPlayerBack = () async {
      if (container.read(watchPanelProvider) == null) return false;
      if (container.read(playerUiProvider).panelMode ==
          PlayerPanelMode.expanded) {
        container.read(watchPanelExpandProvider.notifier).minimize();
        return true;
      }
      return false;
    };
    expect(await dispatcher.didPopRoute(), isTrue);
    expect(find.text('Channel'), findsOneWidget);
    expect(container.read(watchPanelExpandProvider), -1);

    container
        .read(playerUiProvider.notifier)
        .setPanelMode(PlayerPanelMode.mini);
    expect(await dispatcher.didPopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
  });
}
