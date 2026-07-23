import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'features/coach/coach_screen.dart';
import 'features/heart/heart_screen.dart';
import 'features/insights/insights_screen.dart';
import 'features/journal/journal_screen.dart';
import 'features/more/more_screen.dart';
import 'features/programs/programs_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/shell/app_shell.dart';
import 'features/sleep/sleep_screen.dart';
import 'features/strain/strain_screen.dart';
import 'features/stress/stress_readiness_screen.dart';
import 'features/today/today_screen.dart';
import 'features/weekly/weekly_screen.dart';
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
                  path: '/more',
                  builder: (context, state) => const MoreScreen(),
                ),
              ],
            ),
          ],
        ),
        GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
        GoRoute(path: '/weekly', builder: (context, state) => const WeeklyScreen()),
        GoRoute(path: '/stress', builder: (context, state) => const StressScreen()),
        GoRoute(path: '/journal', builder: (context, state) => const JournalScreen()),
        GoRoute(path: '/insights', builder: (context, state) => const InsightsScreen()),
        GoRoute(path: '/programs', builder: (context, state) => const ProgramsScreen()),
        GoRoute(path: '/coach', builder: (context, state) => const CoachScreen()),
      ],
    );

    return Consumer<AppController>(
      builder: (context, controller, _) {
        return MaterialApp.router(
          title: 'OpenAir',
          debugShowCheckedModeBanner: false,
          theme: OpenAirTheme.light(),
          darkTheme: OpenAirTheme.dark(),
          themeMode: controller.themeMode,
          routerConfig: router,
        );
      },
    );
  }
}
