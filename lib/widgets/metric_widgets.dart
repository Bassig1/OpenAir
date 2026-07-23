import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../domain/models/day_summary.dart';
import '../theme/openair_theme.dart';

class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.label,
    required this.value,
    this.hint,
    this.accent = OpenAirColors.textPrimary,
  });

  final String label;
  final String value;
  final String? hint;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: OpenAirColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: OpenAirColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: OpenAirColors.textMuted,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w700,
                ),
          ),
          if (hint != null) ...[
            const SizedBox(height: 6),
            Text(
              hint!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: OpenAirColors.textSecondary,
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
  const DayStrip({super.key, required this.days, required this.selected});

  final List<DaySummary> days;
  final DaySummary? selected;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('E');
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final day = days[index];
          final isSelected = selected?.date == day.date;
          final recovery = day.recoveryScore ?? 0;
          final color = recovery >= 67
              ? OpenAirColors.recovery
              : recovery >= 34
                  ? OpenAirColors.strain
                  : OpenAirColors.heart;
          return Container(
            width: 52,
            decoration: BoxDecoration(
              color: isSelected
                  ? OpenAirColors.surfaceElevated
                  : OpenAirColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? color : OpenAirColors.border,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  fmt.format(day.date).substring(0, 1),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: OpenAirColors.textSecondary,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${day.date.day}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

String formatMinutes(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return '${h}h ${m.toString().padLeft(2, '0')}m';
}
