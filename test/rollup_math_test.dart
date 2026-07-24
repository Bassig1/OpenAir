import 'package:flutter_test/flutter_test.dart';
import 'package:openair/data/health/rollup_math.dart';

void main() {
  test('parses nested civil dates from Google Health', () {
    expect(
      civilDate({
        'date': {'year': 2026, 'month': 7, 'day': 23},
        'time': {},
      }),
      DateTime(2026, 7, 23),
    );
    expect(
      civilDate({'year': 2026, 'month': 7, 'day': 22}),
      DateTime(2026, 7, 22),
    );
  });

  test('parses live Google Health rollup field names', () {
    expect(
      extractSteps({
        'steps': {'countSum': '3895'},
      }),
      3895,
    );
    expect(
      extractActiveEnergyKcal({
        'activeEnergyBurned': {'kcalSum': 264.82},
      }),
      closeTo(264.82, 0.01),
    );
    expect(
      extractActiveMinutes({
        'activeMinutes': {
          'activeMinutesRollupByActivityLevel': [
            {'activityLevel': 'LIGHT', 'activeMinutesSum': '105'},
            {'activityLevel': 'MODERATE', 'activeMinutesSum': '17'},
            {'activityLevel': 'VIGOROUS', 'activeMinutesSum': '6'},
          ],
        },
      }),
      128,
    );
    final azm = extractActiveZoneMinutes({
      'activeZoneMinutes': {
        'sumInCardioHeartZone': '0',
        'sumInPeakHeartZone': '0',
        'sumInFatBurnHeartZone': '19',
      },
    });
    expect(azm?.total, 19);
    expect(azm?.fat, 19);

    final hr = extractHeartRateRollup({
      'heartRate': {
        'beatsPerMinuteAvg': 92.8,
        'beatsPerMinuteMax': 135,
        'beatsPerMinuteMin': 63,
      },
    });
    expect(hr.avg, closeTo(92.8, 0.1));
    expect(hr.max, 135);
    expect(hr.min, 63);
  });
}
