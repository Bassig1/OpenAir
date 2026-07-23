import 'package:flutter_test/flutter_test.dart';
import 'package:openair/data/health/sleep_stage_math.dart';

void main() {
  test('dedupes duplicate stagesSummary rows (Google Health quirk)', () {
    final totals = parseSleepStageSummary(
      stagesSummary: [
        {'type': 'DEEP', 'minutes': 56},
        {'type': 'REM', 'minutes': 150},
        {'type': 'LIGHT', 'minutes': 380},
        {'type': 'AWAKE', 'minutes': 60},
        // Duplicate rows must not be summed.
        {'type': 'DEEP', 'minutes': 56},
        {'type': 'REM', 'minutes': 150},
        {'type': 'LIGHT', 'minutes': 380},
        {'type': 'AWAKE', 'minutes': 60},
      ],
      minutesAsleep: 586,
      minutesAwake: 60,
    );

    expect(totals.asleepMinutes, 586);
    expect(totals.deepMinutes, 56);
    expect(totals.remMinutes, 150);
    expect(totals.lightMinutes, 380);
    expect(totals.awakeMinutes, 60);
    expect(totals.stageAsleepSum, 586);
  });

  test('falls back to stage sum when minutesAsleep missing', () {
    final totals = parseSleepStageSummary(
      stagesSummary: [
        {'type': 'SLEEP_DEEP', 'minutes': 40},
        {'type': 'SLEEP_REM', 'minutes': 80},
        {'type': 'SLEEP_LIGHT', 'minutes': 200},
        {'type': 'SLEEP_AWAKE', 'minutes': 15},
      ],
    );

    expect(totals.asleepMinutes, 320);
    expect(totals.awakeMinutes, 15);
  });
}
