import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_controller.dart';
import '../../theme/openair_theme.dart';
import '../../widgets/metric_widgets.dart';
import '../../widgets/score_ring.dart';

class StressScreen extends StatelessWidget {
  const StressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final day = app.selectedDay;
    final colors = OpenAirColors.of(context);
    if (day == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Stress & Readiness')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          DayStrip(days: app.days, selected: day, onSelected: app.selectDay),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ScoreRing(
                label: 'Readiness',
                value: day.readinessScore ?? 0,
                max: 100,
                color: colors.green,
                subtitle: 'Daily readiness',
              ),
              ScoreRing(
                label: 'Stress',
                value: day.stressScore ?? 0,
                max: 100,
                color: colors.heart,
                subtitle: 'Higher = more load',
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
                label: 'Stress mgmt',
                value: day.stressManagementScore?.toStringAsFixed(0) ?? '—',
                hint: '100 − stress',
                accent: colors.sleep,
              ),
              MetricTile(
                label: 'Recovery',
                value: day.recoveryScore?.toStringAsFixed(0) ?? '—',
                accent: colors.green,
              ),
              MetricTile(
                label: 'HRV',
                value: day.hrvMs == null ? '—' : '${day.hrvMs!.round()} ms',
              ),
              MetricTile(
                label: 'Resting HR',
                value: day.restingHeartRate == null
                    ? '—'
                    : '${day.restingHeartRate!.round()} bpm',
                accent: colors.heart,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Readiness blends recovery, sleep, overnight strain, and stress — based on recovery, sleep, and overnight load. Not a medical diagnosis.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}
