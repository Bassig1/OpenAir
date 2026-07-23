import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../domain/scores/period_analytics.dart';
import '../../state/app_controller.dart';
import '../../theme/openair_theme.dart';
import '../../widgets/metric_widgets.dart';
import '../../widgets/score_ring.dart';

class TrendsScreen extends StatelessWidget {
  const TrendsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final colors = OpenAirColors.of(context);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Trends'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Daily'),
              Tab(text: 'Week'),
              Tab(text: 'Month'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _PeriodTab(
              summary: app.dailySummary,
              hrv: app.hrvTrends,
              seriesTake: 7,
              app: app,
              colors: colors,
            ),
            _PeriodTab(
              summary: app.weekSummary,
              hrv: app.hrvTrends,
              seriesTake: 7,
              app: app,
              colors: colors,
            ),
            _PeriodTab(
              summary: app.monthSummary,
              hrv: app.hrvTrends,
              seriesTake: 30,
              app: app,
              colors: colors,
            ),
          ],
        ),
      ),
    );
  }
}

class _PeriodTab extends StatelessWidget {
  const _PeriodTab({
    required this.summary,
    required this.hrv,
    required this.seriesTake,
    required this.app,
    required this.colors,
  });

  final PeriodSummary summary;
  final HrvTrendReport hrv;
  final int seriesTake;
  final AppController app;
  final OpenAirColors colors;

  @override
  Widget build(BuildContext context) {
    final range =
        '${DateFormat.MMMd().format(summary.start)} – ${DateFormat.MMMd().format(summary.end)}';
    final recoveryPts = app.recoverySeries(take: seriesTake);
    final sleepPts = app.sleepPerfSeries(take: seriesTake);
    final hrvPts = app.hrvSeries(take: seriesTake);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        Text(range, style: TextStyle(color: colors.textSecondary)),
        const SizedBox(height: 6),
        Text(
          summary.summary,
          style: TextStyle(color: colors.textPrimary, height: 1.35),
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, c) {
            final ring = ((c.maxWidth - 12) / 3).clamp(86.0, 108.0);
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ScoreRing(
                  label: 'Recovery',
                  value: summary.avgRecovery,
                  max: 100,
                  color: colors.green,
                  subtitle: summary.recoveryTrend,
                  size: ring,
                ),
                ScoreRing(
                  label: 'Strain',
                  value: summary.avgStrain,
                  max: 21,
                  color: colors.strain,
                  size: ring,
                ),
                ScoreRing(
                  label: 'Sleep',
                  value: summary.avgSleepPerformance,
                  max: 100,
                  color: colors.sleep,
                  subtitle: 'performance',
                  size: ring,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        const SectionHeader('HRV'),
        const SizedBox(height: 8),
        Text(hrv.summary, style: TextStyle(color: colors.textSecondary)),
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
              label: 'Latest',
              value: hrv.latest?.toStringAsFixed(0) ?? '—',
              hint: 'ms',
              accent: colors.green,
            ),
            MetricTile(
              label: '7-day avg',
              value: hrv.weekAvg?.toStringAsFixed(0) ?? '—',
              hint: hrv.weekDelta == null
                  ? null
                  : '${hrv.weekDelta! >= 0 ? '+' : ''}${hrv.weekDelta!.toStringAsFixed(0)} vs avg',
            ),
            MetricTile(
              label: '30-day avg',
              value: hrv.monthAvg?.toStringAsFixed(0) ?? '—',
              hint: 'ms',
            ),
            MetricTile(
              label: 'Baseline',
              value: hrv.baseline?.toStringAsFixed(0) ?? '—',
              hint: hrv.trendLabel,
              accent: colors.heart,
            ),
          ],
        ),
        const SizedBox(height: 24),
        const SectionHeader('Period averages'),
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
              label: 'Readiness',
              value: summary.avgReadiness.toStringAsFixed(0),
              accent: colors.green,
            ),
            MetricTile(
              label: 'Stress',
              value: summary.avgStress.toStringAsFixed(0),
              accent: colors.heart,
            ),
            MetricTile(
              label: 'Sleep hours',
              value: (summary.avgSleepMinutes / 60).toStringAsFixed(1),
              hint: 'h / night',
              accent: colors.sleep,
            ),
            MetricTile(
              label: 'Resting HR',
              value: summary.avgRhr?.toStringAsFixed(0) ?? '—',
              hint: 'bpm',
            ),
            MetricTile(
              label: 'Steps',
              value: NumberFormat.compact().format(summary.totalSteps),
            ),
            MetricTile(
              label: 'Workouts',
              value: '${summary.totalWorkouts}',
              accent: colors.strain,
            ),
          ],
        ),
        const SizedBox(height: 24),
        const SectionHeader('Recovery trend'),
        const SizedBox(height: 12),
        _MiniChart(points: recoveryPts, color: colors.green),
        const SizedBox(height: 20),
        const SectionHeader('Sleep performance trend'),
        const SizedBox(height: 12),
        _MiniChart(points: sleepPts, color: colors.sleep),
        const SizedBox(height: 20),
        const SectionHeader('HRV trend'),
        const SizedBox(height: 12),
        _MiniChart(points: hrvPts, color: colors.heart),
      ],
    );
  }
}

class _MiniChart extends StatelessWidget {
  const _MiniChart({required this.points, required this.color});

  final List<TrendPoint> points;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = OpenAirColors.of(context);
    if (points.isEmpty) {
      return Text('No points yet', style: TextStyle(color: colors.textMuted));
    }
    return SizedBox(
      height: 160,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (var i = 0; i < points.length; i++)
                  FlSpot(i.toDouble(), points[i].value),
              ],
              isCurved: true,
              color: color,
              barWidth: 3,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: color.withValues(alpha: 0.12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
