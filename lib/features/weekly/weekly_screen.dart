import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../state/app_controller.dart';
import '../../theme/openair_theme.dart';
import '../../widgets/metric_widgets.dart';
import '../../widgets/score_ring.dart';

class WeeklyScreen extends StatelessWidget {
  const WeeklyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final report = app.weeklyReport;
    final colors = OpenAirColors.of(context);
    final range =
        '${DateFormat.MMMd().format(report.start)} – ${DateFormat.MMMd().format(report.end)}';

    return Scaffold(
      appBar: AppBar(title: const Text('Weekly Report')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(range, style: TextStyle(color: colors.textSecondary)),
          const SizedBox(height: 8),
          Text(
            'Your week at a glance',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ScoreRing(
                label: 'Recovery',
                value: report.avgRecovery,
                max: 100,
                color: colors.green,
                size: 100,
              ),
              ScoreRing(
                label: 'Strain',
                value: report.avgStrain,
                max: 21,
                color: colors.strain,
                size: 100,
              ),
              ScoreRing(
                label: 'Sleep',
                value: report.avgSleepScore,
                max: 100,
                color: colors.sleep,
                size: 100,
              ),
            ],
          ),
          const SizedBox(height: 24),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.35,
            children: [
              MetricTile(
                label: 'Readiness',
                value: report.avgReadiness.toStringAsFixed(0),
                accent: colors.green,
              ),
              MetricTile(
                label: 'Stress',
                value: report.avgStress.toStringAsFixed(0),
                accent: colors.heart,
              ),
              MetricTile(
                label: 'Steps',
                value: NumberFormat.compact().format(report.totalSteps),
              ),
              MetricTile(
                label: 'Workouts',
                value: '${report.totalWorkouts}',
                accent: colors.strain,
              ),
              MetricTile(
                label: 'Best recovery',
                value: report.bestRecoveryDay,
                accent: colors.green,
              ),
              MetricTile(
                label: 'Hardest day',
                value: report.hardestStrainDay,
                accent: colors.strain,
              ),
            ],
          ),
          const SizedBox(height: 24),
          const SectionHeader('Weekly insights'),
          const SizedBox(height: 12),
          ...report.insights.map(
            (i) => Container(
              width: double.infinity,
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
                  Text(i.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(i.body, style: TextStyle(color: colors.textSecondary)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
