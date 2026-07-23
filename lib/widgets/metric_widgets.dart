import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../domain/models/day_summary.dart';
import '../domain/models/health_extras.dart';
import '../theme/openair_theme.dart';

class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.label,
    required this.value,
    this.hint,
    this.accent,
  });

  final String label;
  final String value;
  final String? hint;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final colors = OpenAirColors.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.textMuted,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: accent ?? colors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
          ),
          if (hint != null) ...[
            const SizedBox(height: 6),
            Text(
              hint!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class DayStrip extends StatelessWidget {
  const DayStrip({
    super.key,
    required this.days,
    required this.selected,
    required this.onSelected,
  });

  final List<DaySummary> days;
  final DaySummary? selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = OpenAirColors.of(context);
    final fmt = DateFormat('E');
    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final day = days[index];
          final isSelected = selected?.date == day.date;
          final recovery = day.recoveryScore ?? 0;
          final color = recovery >= 67
              ? colors.green
              : recovery >= 34
                  ? colors.strain
                  : colors.heart;
          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => onSelected(index),
              child: Container(
                width: 52,
                decoration: BoxDecoration(
                  color: isSelected ? colors.surfaceElevated : colors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? color : colors.border,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      fmt.format(day.date).substring(0, 1),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: colors.textSecondary,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${day.date.day}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 6,
                      height: 6,
                      decoration:
                          BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class ContributionBar extends StatelessWidget {
  const ContributionBar({
    super.key,
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = OpenAirColors.of(context);
    final progress = (value / 100).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label)),
              Text(
                value.toStringAsFixed(0),
                style: TextStyle(color: color, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: colors.border,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class WorkoutTile extends StatelessWidget {
  const WorkoutTile({super.key, required this.session});

  final ExerciseSession session;

  @override
  Widget build(BuildContext context) {
    final colors = OpenAirColors.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: colors.surfaceElevated,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.fitness_center, color: colors.green),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  '${session.durationMinutes} min'
                  '${session.calories == null ? '' : ' · ${session.calories!.round()} kcal'}'
                  '${session.avgHeartRate == null ? '' : ' · ${session.avgHeartRate!.round()} bpm'}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                ),
              ],
            ),
          ),
          Text(
            DateFormat('h:mm a').format(session.start),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.textMuted,
                ),
          ),
        ],
      ),
    );
  }
}

class LiveBadge extends StatelessWidget {
  const LiveBadge({super.key, required this.live, this.syncing = false});

  final bool live;
  final bool syncing;

  @override
  Widget build(BuildContext context) {
    final colors = OpenAirColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: live
            ? colors.green.withValues(alpha: 0.15)
            : colors.surfaceElevated,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: live ? colors.green : colors.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (syncing)
            SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: colors.green,
              ),
            )
          else
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: live ? colors.green : colors.textMuted,
                shape: BoxShape.circle,
              ),
            ),
          const SizedBox(width: 6),
          Text(
            live ? 'LIVE' : 'DEMO',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: live ? colors.green : colors.textMuted,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
          ),
        ],
      ),
    );
  }
}

String formatMinutes(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return '${h}h ${m.toString().padLeft(2, '0')}m';
}
