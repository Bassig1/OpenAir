import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../domain/models/health_extras.dart';
import '../../state/app_controller.dart';
import '../../theme/openair_theme.dart';
import 'workout_catalog.dart';

class WorkoutsScreen extends StatelessWidget {
  const WorkoutsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final colors = OpenAirColors.of(context);
    final logged = app.allRecentWorkouts;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Workouts'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Logged'),
              Tab(text: 'All types'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                Text(
                  'Sessions from Fitbit via Google Health — same exercise stream as Premium.',
                  style: TextStyle(color: colors.textSecondary),
                ),
                const SizedBox(height: 12),
                if (logged.isEmpty)
                  Text(
                    'No workouts in the last 14 days yet. Log activity in Fitbit, sync, then pull to refresh.',
                    style: TextStyle(color: colors.textMuted),
                  )
                else
                  ...logged.map((e) => _LoggedTile(session: e)),
              ],
            ),
            ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                Text(
                  'Full activity catalog (Fitbit / Google Health Premium style). Logged sessions appear under Logged.',
                  style: TextStyle(color: colors.textSecondary),
                ),
                const SizedBox(height: 12),
                for (final category in WorkoutCatalog.categories) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 8),
                    child: Text(
                      category.toUpperCase(),
                      style: TextStyle(
                        color: colors.green,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  ...WorkoutCatalog.activities
                      .where((a) => a.category == category)
                      .map(
                        (a) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: colors.green.withValues(alpha: 0.15),
                            child: Icon(a.icon, color: colors.green),
                          ),
                          title: Text(a.name),
                          subtitle: Text(
                            logged.any((e) =>
                                    e.name.toLowerCase().contains(a.name.toLowerCase()) ||
                                    a.name.toLowerCase().contains(e.name.toLowerCase()))
                                ? 'Logged recently'
                                : 'Available when tracked on Fitbit',
                            style: TextStyle(color: colors.textMuted, fontSize: 12),
                          ),
                        ),
                      ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LoggedTile extends StatelessWidget {
  const _LoggedTile({required this.session});

  final ExerciseSession session;

  @override
  Widget build(BuildContext context) {
    final colors = OpenAirColors.of(context);
    final pace = session.paceMinPerKm;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  session.name,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
              Text(
                DateFormat('MMM d · h:mm a').format(session.start),
                style: TextStyle(color: colors.textMuted, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _chip(colors, '${session.durationMinutes} min'),
              if (session.calories != null)
                _chip(colors, '${session.calories!.round()} kcal'),
              if (session.distanceMeters != null)
                _chip(
                  colors,
                  '${(session.distanceMeters! / 1000).toStringAsFixed(2)} km',
                ),
              if (session.avgHeartRate != null)
                _chip(colors, 'avg ${session.avgHeartRate!.round()} bpm'),
              if (session.maxHeartRate != null)
                _chip(colors, 'max ${session.maxHeartRate!.round()} bpm'),
              if (session.minHeartRate != null)
                _chip(colors, 'min ${session.minHeartRate!.round()} bpm'),
              if (pace != null)
                _chip(colors, '${pace.toStringAsFixed(1)} min/km'),
              if (session.elevationGainMeters != null)
                _chip(
                  colors,
                  '+${session.elevationGainMeters!.round()} m elev',
                ),
              if (session.zoneMinutes != null)
                _chip(colors, '${session.zoneMinutes} zone min'),
              if (session.steps != null) _chip(colors, '${session.steps} steps'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(OpenAirColors colors, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: colors.border),
      ),
      child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}
