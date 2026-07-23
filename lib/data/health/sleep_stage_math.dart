/// Pure sleep-stage totals used by Google Health parsing.
///
/// Google Health sometimes returns duplicate rows in `stagesSummary`
/// (same type twice). We keep one value per stage type — never sum duplicates.
class SleepStageTotals {
  const SleepStageTotals({
    required this.asleepMinutes,
    required this.deepMinutes,
    required this.remMinutes,
    required this.lightMinutes,
    required this.awakeMinutes,
  });

  final int asleepMinutes;
  final int deepMinutes;
  final int remMinutes;
  final int lightMinutes;
  final int awakeMinutes;

  int get stageAsleepSum => deepMinutes + remMinutes + lightMinutes;
}

SleepStageTotals parseSleepStageSummary({
  required List<Map<String, dynamic>> stagesSummary,
  int? minutesAsleep,
  int? minutesAwake,
}) {
  final byType = <String, int>{};
  for (final stage in stagesSummary) {
    final type = '${stage['type'] ?? ''}'.toUpperCase();
    final raw = stage['minutes'];
    final minutes = raw is num
        ? raw.round()
        : int.tryParse('$raw') ?? double.tryParse('$raw')?.round() ?? 0;
    if (type.contains('DEEP')) {
      byType['DEEP'] = minutes;
    } else if (type.contains('REM')) {
      byType['REM'] = minutes;
    } else if (type.contains('LIGHT') || type.contains('ASLEEP')) {
      byType['LIGHT'] = minutes;
    } else if (type.contains('AWAKE') || type.contains('RESTLESS')) {
      byType['AWAKE'] = minutes;
    }
  }
  final deep = byType['DEEP'] ?? 0;
  final rem = byType['REM'] ?? 0;
  final light = byType['LIGHT'] ?? 0;
  final awake = byType['AWAKE'] ?? 0;
  return SleepStageTotals(
    asleepMinutes: minutesAsleep ?? (deep + rem + light),
    deepMinutes: deep,
    remMinutes: rem,
    lightMinutes: light,
    awakeMinutes: minutesAwake ?? awake,
  );
}
