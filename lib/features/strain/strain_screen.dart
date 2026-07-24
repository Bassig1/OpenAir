import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../domain/units.dart';
import '../../state/app_controller.dart';
import '../../theme/openair_theme.dart';
import '../../widgets/metric_widgets.dart';

class StrainScreen extends StatelessWidget {
  const StrainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = OpenAirColors.of(context);
    final app = context.watch<AppController>();
    final day = app.selectedDay;
    if (day == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final recent = app.days.length > 7
        ? app.days.sublist(app.days.length - 7)
        : app.days;
    final zones = day.heartRateZones;
    final analysis = app.strainAnalysis;
    final score = analysis?.score ?? day.strainScore ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Strain')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          DayStrip(days: app.days, selected: day, onSelected: app.selectDay),
          const SizedBox(height: 20),
          Text(
            score.toStringAsFixed(1),
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colors.strain,
                ),
          ),
          Text(
            analysis == null
                ? 'Day strain · 0–21'
                : '${analysis.zoneLabel} strain · ${analysis.remaining} capacity left',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colors.textSecondary,
                ),
          ),
          if (analysis != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.border),
              ),
              child: Text(
                analysis.summary,
                style: TextStyle(
                  color: colors.textPrimary,
                  height: 1.45,
                ),
              ),
            ),
            const SizedBox(height: 20),
            const SectionHeader('What drove strain'),
            const SizedBox(height: 12),
            ...analysis.contributions.map(
              (c) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ContributionBar(
                  label: '${c.label} · ${c.detail}',
                  value: (c.points / 21 * 100).clamp(5, 100),
                  color: colors.strain,
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          const SectionHeader('Activity from Google Health'),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.35,
            children: [
              MetricTile(
                label: 'Steps',
                value: NumberFormat.decimalPattern().format(day.steps),
                hint: day.steps <= 0 ? 'sync Fitbit then refresh' : null,
              ),
              MetricTile(
                label: 'Active cal',
                value: day.activeCalories <= 0
                    ? '—'
                    : '${day.activeCalories.round()}',
                accent: colors.strain,
              ),
              MetricTile(
                label: 'Active min',
                value: day.activeMinutes <= 0 ? '—' : '${day.activeMinutes}',
              ),
              MetricTile(
                label: 'Zone min',
                value: day.zoneMinutes <= 0 ? '—' : '${day.zoneMinutes}',
                hint: 'Fitbit AZM',
                accent: colors.strain,
              ),
              MetricTile(
                label: 'Distance',
                value: day.distanceMeters == null
                    ? '—'
                    : Units.distanceMeters(
                        day.distanceMeters,
                        metric: true,
                      ),
              ),
              MetricTile(
                label: 'Floors',
                value: day.floors?.toString() ?? '—',
              ),
              MetricTile(
                label: 'Total cal',
                value: day.totalCalories == null
                    ? '—'
                    : '${day.totalCalories!.round()}',
              ),
              MetricTile(
                label: 'Sedentary',
                value: day.sedentaryMinutes == null
                    ? '—'
                    : formatMinutes(day.sedentaryMinutes!),
              ),
            ],
          ),
          if (zones != null && zones.total > 0) ...[
            const SizedBox(height: 28),
            const SectionHeader('Heart rate zones'),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.95,
              children: [
                MetricTile(
                  label: 'Fat burn',
                  value: '${zones.fatBurnMinutes}m',
                  hint: '${zones.percentOf(zones.fatBurnMinutes)}%',
                  accent: colors.strain,
                ),
                MetricTile(
                  label: 'Cardio',
                  value: '${zones.cardioMinutes}m',
                  hint: '${zones.percentOf(zones.cardioMinutes)}%',
                  accent: colors.heart,
                ),
                MetricTile(
                  label: 'Peak',
                  value: '${zones.peakMinutes}m',
                  hint: '${zones.percentOf(zones.peakMinutes)}%',
                  accent: const Color(0xFFFF6B6B),
                ),
              ],
            ),
          ],
          if (day.exercises.isNotEmpty) ...[
            const SizedBox(height: 28),
            const SectionHeader('Workouts'),
            const SizedBox(height: 12),
            ...day.exercises.map((e) => WorkoutTile(session: e)),
          ],
          if (app.geminiReady) ...[
            const SizedBox(height: 28),
            const SectionHeader('Ask Gemini about strain'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final q in const [
                  'Summarize my strain today with exact numbers',
                  'Do I have capacity left to train?',
                  'What drove my strain this week?',
                ])
                  ActionChip(
                    label: Text(q),
                    onPressed: () async {
                      await app.askCoach(q);
                      if (context.mounted) context.push('/coach');
                    },
                  ),
              ],
            ),
          ],
          const SizedBox(height: 28),
          const SectionHeader('7-day strain'),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= recent.length) {
                          return const SizedBox.shrink();
                        }
                        return Text(
                          DateFormat('E').format(recent[i].date).substring(0, 1),
                          style: TextStyle(
                            color: colors.textMuted,
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < recent.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: recent[i].strainScore ?? 0,
                          color: colors.strain,
                          width: 14,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ],
                    ),
                ],
                maxY: 21,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
