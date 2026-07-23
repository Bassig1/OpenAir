import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_controller.dart';
import '../../theme/openair_theme.dart';
import '../../widgets/metric_widgets.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final colors = OpenAirColors.of(context);
    final day = app.selectedDay;
    final insights = app.todaysInsights;

    return Scaffold(
      appBar: AppBar(title: const Text('Insights')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          if (day != null)
            DayStrip(days: app.days, selected: day, onSelected: app.selectDay),
          const SizedBox(height: 16),
          Text(
            'Live coaching cues from recovery, strain, sleep, and stress — Premium-style guidance.',
            style: TextStyle(color: colors.textSecondary),
          ),
          const SizedBox(height: 16),
          if (insights.isEmpty)
            Text('No insights yet for this day.', style: TextStyle(color: colors.textMuted))
          else
            ...insights.map(
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
                    Text(
                      i.category.toUpperCase(),
                      style: TextStyle(
                        color: colors.green,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 6),
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
