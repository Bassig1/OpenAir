import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../state/app_controller.dart';
import '../../theme/openair_theme.dart';
import '../../widgets/metric_widgets.dart';

class StrainScreen extends StatelessWidget {
  const StrainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final day = app.selectedDay;
    if (day == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final recent = app.days.length > 7
        ? app.days.sublist(app.days.length - 7)
        : app.days;
    final zones = day.heartRateZones;

    return Scaffold(
      appBar: AppBar(title: const Text('Strain')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          DayStrip(days: app.days, selected: day, onSelected: app.selectDay),
          const SizedBox(height: 20),
          Text(
            (day.strainScore ?? 0).toStringAsFixed(1),
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: OpenAirColors.strain,
                ),
          ),
          Text(
            'Day strain · 0–21 scale',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: OpenAirColors.textSecondary,
                ),
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
                label: 'Steps',
                value: NumberFormat.decimalPattern().format(day.steps),
              ),
              MetricTile(
                label: 'Active cal',
                value: '${day.activeCalories.round()}',
                accent: OpenAirColors.strain,
              ),
              MetricTile(label: 'Active min', value: '${day.activeMinutes}'),
              MetricTile(
                label: 'Zone min',
                value: '${day.zoneMinutes}',
                accent: OpenAirColors.strain,
              ),
              MetricTile(
                label: 'Distance',
                value: day.distanceMeters == null
                    ? '—'
                    : '${(day.distanceMeters! / 1000).toStringAsFixed(2)} km',
              ),
              MetricTile(label: 'Floors', value: day.floors?.toString() ?? '—'),
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
          if (zones != null) ...[
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
                  accent: OpenAirColors.strain,
                ),
                MetricTile(
                  label: 'Cardio',
                  value: '${zones.cardioMinutes}m',
                  accent: OpenAirColors.heart,
                ),
                MetricTile(
                  label: 'Peak',
                  value: '${zones.peakMinutes}m',
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
                          style: const TextStyle(
                            color: OpenAirColors.textMuted,
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
                          color: OpenAirColors.strain,
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
