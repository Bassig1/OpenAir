import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_controller.dart';
import '../../theme/openair_theme.dart';
import '../../widgets/metric_widgets.dart';

class HeartScreen extends StatelessWidget {
  const HeartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final day = app.today;
    if (day == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final samples = day.heartSamples;

    return Scaffold(
      appBar: AppBar(title: const Text('Heart')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.35,
            children: [
              MetricTile(
                label: 'Resting',
                value: day.restingHeartRate == null
                    ? '—'
                    : '${day.restingHeartRate!.round()}',
                hint: 'bpm',
                accent: OpenAirColors.heart,
              ),
              MetricTile(
                label: 'HRV',
                value: day.hrvMs == null ? '—' : '${day.hrvMs!.round()}',
                hint: 'ms',
                accent: OpenAirColors.recovery,
              ),
              MetricTile(
                label: 'Avg HR',
                value: day.avgHeartRate == null
                    ? '—'
                    : '${day.avgHeartRate!.round()}',
                hint: 'bpm',
              ),
              MetricTile(
                label: 'SpO₂',
                value: day.spo2Percent == null
                    ? '—'
                    : day.spo2Percent!.toStringAsFixed(1),
                hint: '%',
                accent: OpenAirColors.spo2,
              ),
            ],
          ),
          const SizedBox(height: 28),
          const SectionHeader('Heart rate today'),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: samples.isEmpty
                ? const Center(child: Text('No heart samples yet'))
                : LineChart(
                    LineChartData(
                      minY: 40,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: OpenAirColors.border.withValues(alpha: 0.6),
                          strokeWidth: 1,
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      titlesData: const FlTitlesData(
                        topTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 36,
                          ),
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          isCurved: true,
                          color: OpenAirColors.heart,
                          barWidth: 2.5,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: OpenAirColors.heart.withValues(alpha: 0.12),
                          ),
                          spots: [
                            for (var i = 0; i < samples.length; i++)
                              FlSpot(i.toDouble(), samples[i].value),
                          ],
                        ),
                      ],
                    ),
                  ),
          ),
          if (day.spo2Samples.isNotEmpty) ...[
            const SizedBox(height: 28),
            const SectionHeader('Overnight SpO₂'),
            const SizedBox(height: 16),
            SizedBox(
              height: 160,
              child: LineChart(
                LineChartData(
                  minY: 90,
                  maxY: 100,
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      isCurved: true,
                      color: OpenAirColors.spo2,
                      barWidth: 2.5,
                      dotData: const FlDotData(show: false),
                      spots: [
                        for (var i = 0; i < day.spo2Samples.length; i++)
                          FlSpot(i.toDouble(), day.spo2Samples[i].value),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
