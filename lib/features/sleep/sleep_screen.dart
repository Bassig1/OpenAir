import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_controller.dart';
import '../../theme/openair_theme.dart';
import '../../widgets/metric_widgets.dart';

class SleepScreen extends StatelessWidget {
  const SleepScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = OpenAirColors.of(context);
    final app = context.watch<AppController>();
    final day = app.selectedDay;
    if (day == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final stages = [
      ('Deep', day.deepSleepMinutes, colors.sleep),
      ('REM', day.remSleepMinutes, const Color(0xFF8BB4FF)),
      ('Light', day.lightSleepMinutes, const Color(0xFF3A4A66)),
      ('Awake', day.awakeMinutes, colors.textMuted),
    ];
    final total = stages.fold<int>(0, (a, b) => a + b.$2).clamp(1, 100000);

    return Scaffold(
      appBar: AppBar(title: const Text('Sleep')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          DayStrip(days: app.days, selected: day, onSelected: app.selectDay),
          const SizedBox(height: 20),
          Text(
            formatMinutes(day.sleepMinutes),
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colors.sleep,
                ),
          ),
          Text(
            'Performance ${day.sleepScore?.toStringAsFixed(0) ?? '—'}  ·  Need ${formatMinutes(day.sleepNeededMinutes ?? 480)}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colors.textSecondary,
                ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 180,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 48,
                sections: [
                  for (final stage in stages)
                    PieChartSectionData(
                      value: stage.$2.toDouble().clamp(0.1, 100000),
                      color: stage.$3,
                      radius: 28,
                      title: '',
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          ...stages.map((stage) {
            final pct = ((stage.$2 / total) * 100).round();
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: stage.$3, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(stage.$1)),
                  Text(
                    '${formatMinutes(stage.$2)}  ·  $pct%',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.textSecondary,
                        ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 20),
          const SectionHeader('Overnight signals'),
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
                label: 'Avg SpO₂',
                value: day.spo2Percent == null
                    ? '—'
                    : '${day.spo2Percent!.toStringAsFixed(1)}%',
                accent: colors.spo2,
              ),
              MetricTile(
                label: 'Resting HR',
                value: day.restingHeartRate == null
                    ? '—'
                    : '${day.restingHeartRate!.round()} bpm',
                accent: colors.heart,
              ),
              MetricTile(
                label: 'Resp. rate',
                value: day.respiratoryRate == null
                    ? '—'
                    : day.respiratoryRate!.toStringAsFixed(1),
                hint: 'br/min',
                accent: colors.sleep,
              ),
              MetricTile(
                label: 'Skin temp Δ',
                value: day.skinTempDeviation == null
                    ? '—'
                    : '${day.skinTempDeviation!.toStringAsFixed(2)}°',
                accent: colors.strain,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
