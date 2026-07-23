import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'features/coach/coach_screen.dart';
import 'features/heart/heart_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/shell/app_shell.dart';
import 'features/sleep/sleep_screen.dart';
import 'features/strain/strain_screen.dart';
import 'features/today/today_screen.dart';
import 'state/app_controller.dart';
import 'theme/openair_theme.dart';

class OpenAirApp extends StatelessWidget {
  const OpenAirApp({super.key});

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      initialLocation: '/today',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return AppShell(navigationShell: navigationShell);
          },
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/today',
                  builder: (context, state) => const TodayScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/sleep',
                  builder: (context, state) => const SleepScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/strain',
                  builder: (context, state) => const StrainScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/heart',
                  builder: (context, state) => const HeartScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/coach',
                  builder: (context, state) => const CoachScreen(),
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
      ],
    );

    return Consumer<AppController>(
      builder: (context, controller, _) {
        return MaterialApp.router(
          title: 'OpenAir',
          debugShowCheckedModeBanner: false,
          theme: OpenAirTheme.dark(),
          routerConfig: router,
        );
      },
    );
  }
}
