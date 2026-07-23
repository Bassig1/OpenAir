import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../state/app_controller.dart';
import '../../theme/openair_theme.dart';
import '../../widgets/metric_widgets.dart';

class HeartScreen extends StatelessWidget {
  const HeartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = OpenAirColors.of(context);
    final app = context.watch<AppController>();
    final day = app.selectedDay;
    if (day == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final samples = day.heartSamples;
    final body = app.effectiveBody;

    return Scaffold(
      appBar: AppBar(title: const Text('Heart')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          DayStrip(days: app.days, selected: day, onSelected: app.selectDay),
          const SizedBox(height: 20),
          if (app.heartbeatAnalysis != null) ...[
            const SectionHeader('Heartbeat analysis'),
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
                  label: 'Resting',
                  value: app.heartbeatAnalysis!.restingHr == null
                      ? '—'
                      : '${app.heartbeatAnalysis!.restingHr!.round()}',
                  hint: 'bpm · ${app.heartbeatAnalysis!.rhrTrend}',
                  accent: colors.heart,
                ),
                MetricTile(
                  label: 'HRV',
                  value: app.heartbeatAnalysis!.hrvMs == null
                      ? '—'
                      : '${app.heartbeatAnalysis!.hrvMs!.round()}',
                  hint: 'ms · ${app.heartbeatAnalysis!.hrvTrend}',
                  accent: colors.green,
                ),
                MetricTile(
                  label: 'Min / Max',
                  value: '${app.heartbeatAnalysis!.minHr?.round() ?? '—'} / ${app.heartbeatAnalysis!.maxHr?.round() ?? '—'}',
                  hint: 'bpm',
                ),
                MetricTile(
                  label: 'Zones',
                  value: '${app.heartbeatAnalysis!.fatBurnMinutes}/${app.heartbeatAnalysis!.cardioMinutes}/${app.heartbeatAnalysis!.peakMinutes}',
                  hint: 'fat/cardio/peak min',
                  accent: colors.strain,
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
          Builder(
            builder: (context) {
              final hrv = app.hrvTrends;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader('HRV trends'),
                  const SizedBox(height: 8),
                  Text(
                    hrv.summary,
                    style: TextStyle(color: colors.textSecondary, height: 1.35),
                  ),
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
                        label: 'Today',
                        value: hrv.latest?.toStringAsFixed(0) ?? '—',
                        hint: 'ms',
                        accent: colors.green,
                      ),
                      MetricTile(
                        label: 'Week avg',
                        value: hrv.weekAvg?.toStringAsFixed(0) ?? '—',
                        hint: hrv.trendLabel,
                      ),
                      MetricTile(
                        label: 'Month avg',
                        value: hrv.monthAvg?.toStringAsFixed(0) ?? '—',
                        hint: 'ms',
                      ),
                      MetricTile(
                        label: 'Baseline',
                        value: hrv.baseline?.toStringAsFixed(0) ?? '—',
                        hint: hrv.weekDelta == null
                            ? null
                            : '${hrv.weekDelta! >= 0 ? '+' : ''}${hrv.weekDelta!.toStringAsFixed(0)} vs 7d',
                        accent: colors.heart,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              );
            },
          ),
          if (app.oxygenAnalysis != null) ...[
            const SectionHeader('Blood oxygen analysis'),
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
                  value: app.oxygenAnalysis!.averagePercent == null
                      ? '—'
                      : '${app.oxygenAnalysis!.averagePercent!.toStringAsFixed(1)}%',
                  hint: app.oxygenAnalysis!.statusLabel,
                  accent: colors.spo2,
                ),
                MetricTile(
                  label: 'Min / Max',
                  value:
                      '${app.oxygenAnalysis!.minPercent?.toStringAsFixed(1) ?? '—'} / ${app.oxygenAnalysis!.maxPercent?.toStringAsFixed(1) ?? '—'}',
                ),
                MetricTile(
                  label: 'Samples',
                  value: '${app.oxygenAnalysis!.sampleCount}',
                ),
                MetricTile(
                  label: 'Resp. rate',
                  value: app.oxygenAnalysis!.respiratoryRate == null
                      ? '—'
                      : app.oxygenAnalysis!.respiratoryRate!.toStringAsFixed(1),
                  hint: 'br/min',
                  accent: colors.sleep,
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
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
                accent: colors.heart,
              ),
              MetricTile(
                label: 'HRV',
                value: day.hrvMs == null ? '—' : '${day.hrvMs!.round()}',
                hint: 'ms',
                accent: colors.green,
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
                accent: colors.spo2,
              ),
              MetricTile(
                label: 'VO₂ max',
                value: day.vo2Max == null
                    ? (body.vo2Max == null
                        ? '—'
                        : body.vo2Max!.toStringAsFixed(1))
                    : day.vo2Max!.toStringAsFixed(1),
                accent: colors.green,
              ),
              MetricTile(
                label: 'Max HR',
                value: day.maxHeartRate == null
                    ? '—'
                    : '${day.maxHeartRate!.round()}',
                hint: app.profile.estimatedMaxHeartRate == null
                    ? 'bpm'
                    : 'est max ${app.profile.estimatedMaxHeartRate!.round()}',
                accent: colors.heart,
              ),
            ],
          ),
          const SizedBox(height: 28),
          const SectionHeader('Body'),
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
                label: 'Weight',
                value: body.weightKg == null
                    ? '—'
                    : '${body.weightKg!.toStringAsFixed(1)} kg',
              ),
              MetricTile(
                label: 'Height',
                value: body.heightCm == null
                    ? '—'
                    : '${body.heightCm!.toStringAsFixed(0)} cm',
              ),
              MetricTile(
                label: 'Body fat',
                value: body.bodyFatPercent == null
                    ? '—'
                    : '${body.bodyFatPercent!.toStringAsFixed(1)}%',
              ),
              MetricTile(
                label: 'Age',
                value: app.profile.ageYears?.toString() ?? '—',
                hint: 'set in profile',
              ),
            ],
          ),
          if (body.measuredAt != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Measured ${DateFormat.yMMMd().format(body.measuredAt!)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.textMuted,
                    ),
              ),
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
                          color: colors.border.withValues(alpha: 0.6),
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
                          color: colors.heart,
                          barWidth: 2.5,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: colors.heart.withValues(alpha: 0.12),
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
                      color: colors.spo2,
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
