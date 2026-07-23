import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import '../../domain/models/day_summary.dart';
import '../../domain/models/health_extras.dart';

class HealthSyncResult {
  const HealthSyncResult({
    required this.days,
    this.body,
    this.devices = const [],
  });

  final List<DaySummary> days;
  final BodySnapshot? body;
  final List<PairedDeviceInfo> devices;
}

/// Reads Fitbit/Pixel data via Google Health API after OAuth consent.
///
/// Accurate sync path (from Google docs):
/// Fitbit device → official Fitbit app → Google Health cloud → this client.
/// Uses wearable-preferring dailyRollUp + filtered list for Fitbit-parity numbers.
class GoogleHealthClient {
  GoogleHealthClient({
    GoogleSignIn? googleSignIn,
    http.Client? httpClient,
    String? serverClientId,
  })  : _http = httpClient ?? http.Client(),
        _serverClientId = _normalizeClientId(serverClientId),
        _googleSignIn = googleSignIn ??
            _buildSignIn(_normalizeClientId(serverClientId));

  static const healthScopes = <String>[
    'https://www.googleapis.com/auth/googlehealth.activity_and_fitness.readonly',
    'https://www.googleapis.com/auth/googlehealth.health_metrics_and_measurements.readonly',
    'https://www.googleapis.com/auth/googlehealth.sleep.readonly',
    'https://www.googleapis.com/auth/googlehealth.profile.readonly',
  ];

  /// Debug APK signing fingerprint for the Android OAuth client in Cloud Console.
  static const debugSha1 =
      '7E:94:37:DD:EF:47:05:C0:BC:CA:7C:15:A0:98:66:C7:23:03:6A:78';
  static const androidPackageName = 'com.openair.openair';

  static const _base = 'https://health.googleapis.com/v4';
  static const _wearablesFamily =
      'users/me/dataSourceFamilies/google-wearables';

  GoogleSignIn _googleSignIn;
  final http.Client _http;
  String? _serverClientId;

  GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;

  String? get serverClientId => _serverClientId;

  static String? _normalizeClientId(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  static GoogleSignIn _buildSignIn(String? serverClientId) {
    return GoogleSignIn(
      scopes: healthScopes,
      serverClientId: serverClientId,
    );
  }

  /// Call after the user pastes a Web OAuth client ID from Cloud Console.
  Future<void> configure({String? serverClientId}) async {
    final next = _normalizeClientId(serverClientId);
    if (next == _serverClientId) return;
    await _googleSignIn.signOut();
    _serverClientId = next;
    _googleSignIn = _buildSignIn(next);
  }

  Future<GoogleSignInAccount?> signIn() async {
    try {
      if (_serverClientId == null) {
        throw StateError(
          'Missing Web OAuth Client ID. Create a Web application OAuth client '
          'in Google Cloud Console, then paste its Client ID in Settings.',
        );
      }
      final account = await _googleSignIn.signIn();
      if (account == null) return null;

      final granted = await _googleSignIn.requestScopes(healthScopes);
      if (!granted) {
        throw StateError(
          'Google Health scopes were not granted. In Cloud Console → Data Access, '
          'add the four googlehealth.*.readonly scopes, add yourself as a Test user, '
          'then try Connect again.',
        );
      }
      return account;
    } on PlatformException catch (e) {
      throw StateError(_formatPlatformException(e));
    }
  }

  Future<GoogleSignInAccount?> signInSilently() =>
      _googleSignIn.signInSilently();

  Future<void> signOut() => _googleSignIn.signOut();

  static String _formatPlatformException(PlatformException e) {
    final code = e.code.trim();
    final message = (e.message ?? '').trim();
    final details = '${e.details ?? ''}'.trim();
    final blob = '$code $message $details'.toLowerCase();

    if (blob.contains('10') ||
        blob.contains('developer_error') ||
        (code.isEmpty && message.isEmpty) ||
        message == 'null') {
      return 'Android OAuth mismatch (usually ApiException:10 / PlatformException null).\n'
          'Cloud Console checklist:\n'
          '• Enable Google Health API\n'
          '• Android OAuth client — package $androidPackageName\n'
          '  SHA-1: $debugSha1\n'
          '• Web OAuth client — paste that Client ID in OpenAir Settings\n'
          '• Audience = Testing + your Google email as Test user\n'
          '• Data Access → add googlehealth activity/metrics/sleep/profile readonly scopes\n'
          'Raw: code=${code.isEmpty ? 'null' : code} message=${message.isEmpty ? 'null' : message}';
    }
    if (blob.contains('12501') || blob.contains('sign_in_canceled')) {
      return 'Sign-in was canceled.';
    }
    if (blob.contains('12500')) {
      return 'Google Sign-In failed (12500). Use the Web client ID in Settings '
          '(not the Android client ID), and verify OAuth consent branding.';
    }
    return 'Google Sign-In failed. code=${code.isEmpty ? 'null' : code} '
        'message=${message.isEmpty ? 'null' : message}'
        '${details.isEmpty ? '' : ' details=$details'}';
  }

  Future<String?> _accessToken() async {
    final user = _googleSignIn.currentUser;
    if (user == null) return null;
    final auth = await user.authentication;
    return auth.accessToken;
  }

  Future<HealthSyncResult> syncRecent({int days = 14}) async {
    final token = await _accessToken();
    if (token == null) {
      throw StateError('Not signed in to Google Health');
    }

    final headers = {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };

    final endLocal = DateTime.now();
    final endDay = DateTime(endLocal.year, endLocal.month, endLocal.day)
        .add(const Duration(days: 1));
    final startDay = endDay.subtract(Duration(days: days));

    final results = await Future.wait([
      _dailyRollup(headers: headers, dataType: 'steps', start: startDay, end: endDay),
      _dailyRollup(headers: headers, dataType: 'active-energy-burned', start: startDay, end: endDay),
      _dailyRollup(headers: headers, dataType: 'total-calories', start: startDay, end: endDay),
      _dailyRollup(headers: headers, dataType: 'active-minutes', start: startDay, end: endDay),
      _dailyRollup(headers: headers, dataType: 'active-zone-minutes', start: startDay, end: endDay),
      _dailyRollup(headers: headers, dataType: 'distance', start: startDay, end: endDay),
      _dailyRollup(headers: headers, dataType: 'floors', start: startDay, end: endDay),
      _dailyRollup(headers: headers, dataType: 'sedentary-period', start: startDay, end: endDay),
      _dailyRollup(headers: headers, dataType: 'heart-rate', start: startDay, end: endDay),
      _listDailySummaries(headers: headers, dataType: 'daily-resting-heart-rate', filterName: 'daily_resting_heart_rate', start: startDay, end: endDay),
      _listDailySummaries(headers: headers, dataType: 'daily-heart-rate-variability', filterName: 'daily_heart_rate_variability', start: startDay, end: endDay),
      _listDailySummaries(headers: headers, dataType: 'daily-oxygen-saturation', filterName: 'daily_oxygen_saturation', start: startDay, end: endDay),
      _listDailySummaries(headers: headers, dataType: 'daily-respiratory-rate', filterName: 'daily_respiratory_rate', start: startDay, end: endDay),
      _listDailySummaries(headers: headers, dataType: 'daily-vo2-max', filterName: 'daily_vo2_max', start: startDay, end: endDay),
      _listDailySummaries(headers: headers, dataType: 'daily-sleep-temperature-derivations', filterName: 'daily_sleep_temperature_derivations', start: startDay, end: endDay),
      _listHeartRateZones(headers: headers, start: startDay, end: endDay),
      _listSleepSessions(headers: headers, start: startDay, end: endDay),
      _listHeartSamples(headers: headers, start: startDay, end: endDay),
      _listSpo2Samples(headers: headers, start: startDay, end: endDay),
      _listExercises(headers: headers, start: startDay, end: endDay),
      _fetchBody(headers: headers),
      _listPairedDevices(headers: headers),
    ]);

    final steps = results[0] as Map<DateTime, double>;
    final activeEnergy = results[1] as Map<DateTime, double>;
    final totalCalories = results[2] as Map<DateTime, double>;
    final activeMinutes = results[3] as Map<DateTime, double>;
    final zoneMinutes = results[4] as Map<DateTime, double>;
    final distance = results[5] as Map<DateTime, double>;
    final floors = results[6] as Map<DateTime, double>;
    final sedentary = results[7] as Map<DateTime, double>;
    final hrDaily = results[8] as Map<DateTime, double>;
    final rhr = results[9] as Map<DateTime, double>;
    final hrv = results[10] as Map<DateTime, double>;
    final spo2Daily = results[11] as Map<DateTime, double>;
    final respRate = results[12] as Map<DateTime, double>;
    final vo2 = results[13] as Map<DateTime, double>;
    final skinTemp = results[14] as Map<DateTime, double>;
    final zonesByDay = results[15] as Map<DateTime, HeartRateZones>;
    final sleepByDay = results[16] as Map<DateTime, _SleepDay>;
    final heartSamples = results[17] as List<MetricSample>;
    final spo2Samples = results[18] as List<MetricSample>;
    final exercises = results[19] as List<ExerciseSession>;
    final body = results[20] as BodySnapshot?;
    final devices = results[21] as List<PairedDeviceInfo>;

    final dates = <DateTime>{
      ...steps.keys,
      ...activeEnergy.keys,
      ...activeMinutes.keys,
      ...zoneMinutes.keys,
      ...distance.keys,
      ...rhr.keys,
      ...hrv.keys,
      ...spo2Daily.keys,
      ...sleepByDay.keys,
      ...exercises.map((e) => DateTime(e.end.year, e.end.month, e.end.day)),
    };

    if (dates.isEmpty) {
      for (var i = 0; i < days; i++) {
        dates.add(endDay.subtract(Duration(days: i + 1)));
      }
    }

    final sorted = dates.toList()..sort();
    final daySummaries = sorted.map((date) {
      final dayHeart = heartSamples.where((s) => _sameDay(s.time, date)).toList()
        ..sort((a, b) => a.time.compareTo(b.time));
      final daySpo2 = spo2Samples.where((s) => _sameDay(s.time, date)).toList()
        ..sort((a, b) => a.time.compareTo(b.time));
      final sleep = sleepByDay[date];
      final dayExercises = exercises
          .where((e) => _sameDay(e.end, date) || _sameDay(e.start, date))
          .toList();

      final avgHr = dayHeart.isEmpty
          ? hrDaily[date]
          : dayHeart.map((e) => e.value).reduce((a, b) => a + b) / dayHeart.length;
      final maxHr = dayHeart.isEmpty
          ? null
          : dayHeart.map((e) => e.value).reduce((a, b) => a > b ? a : b);
      final spo2 = spo2Daily[date] ??
          (daySpo2.isEmpty
              ? null
              : daySpo2.map((e) => e.value).reduce((a, b) => a + b) /
                  daySpo2.length);

      return DaySummary(
        date: date,
        steps: (steps[date] ?? 0).round(),
        activeCalories: activeEnergy[date] ?? 0,
        totalCalories: totalCalories[date],
        activeMinutes: (activeMinutes[date] ?? 0).round(),
        zoneMinutes: (zoneMinutes[date] ?? 0).round(),
        sedentaryMinutes: sedentary[date]?.round(),
        distanceMeters: distance[date],
        floors: floors[date]?.round(),
        restingHeartRate: rhr[date],
        hrvMs: hrv[date],
        spo2Percent: spo2,
        respiratoryRate: respRate[date],
        skinTempDeviation: skinTemp[date],
        vo2Max: vo2[date],
        heartRateZones: zonesByDay[date],
        sleepMinutes: sleep?.totalMinutes ?? 0,
        deepSleepMinutes: sleep?.deepMinutes ?? 0,
        remSleepMinutes: sleep?.remMinutes ?? 0,
        lightSleepMinutes: sleep?.lightMinutes ?? 0,
        awakeMinutes: sleep?.awakeMinutes ?? 0,
        avgHeartRate: avgHr,
        maxHeartRate: maxHr,
        heartSamples: dayHeart,
        spo2Samples: daySpo2,
        exercises: dayExercises,
      );
    }).toList();

    return HealthSyncResult(
      days: daySummaries,
      body: body,
      devices: devices,
    );
  }

  @Deprecated('Use syncRecent')
  Future<List<DaySummary>> fetchRecentDays({int days = 14}) async {
    final result = await syncRecent(days: days);
    return result.days;
  }

  Future<Map<DateTime, double>> _dailyRollup({
    required Map<String, String> headers,
    required String dataType,
    required DateTime start,
    required DateTime end,
  }) async {
    final uri = Uri.parse(
      '$_base/users/me/dataTypes/$dataType/dataPoints:dailyRollUp',
    );
    final body = jsonEncode({
      'range': {
        'start': _civil(start),
        'end': _civil(end),
      },
      'windowSizeDays': 1,
      'dataSourceFamily': _wearablesFamily,
    });

    final response = await _http.post(uri, headers: headers, body: body);
    if (response.statusCode == 400 || response.statusCode == 404) {
      // Retry without wearables filter (some accounts only have mixed sources).
      final fallback = await _http.post(
        uri,
        headers: headers,
        body: jsonEncode({
          'range': {'start': _civil(start), 'end': _civil(end)},
          'windowSizeDays': 1,
        }),
      );
      if (fallback.statusCode >= 400) return {};
      return _parseRollup(fallback.body, dataType);
    }
    if (response.statusCode >= 400) {
      throw HttpException(
        'Health API dailyRollUp/$dataType failed '
        '(${response.statusCode}): ${response.body}',
      );
    }
    return _parseRollup(response.body, dataType);
  }

  Map<DateTime, double> _parseRollup(String rawBody, String dataType) {
    final body = jsonDecode(rawBody) as Map<String, dynamic>;
    final points =
        (body['rollupDataPoints'] as List<dynamic>? ?? const []);
    final out = <DateTime, double>{};

    for (final raw in points) {
      final point = raw as Map<String, dynamic>;
      final civil = point['civilStartTime'] as Map<String, dynamic>?;
      final date = _dateFromCivil(civil);
      if (date == null) continue;
      final value = _extractRollupValue(point, dataType);
      if (value != null) out[date] = value;
    }
    return out;
  }

  double? _extractRollupValue(Map<String, dynamic> point, String dataType) {
    switch (dataType) {
      case 'steps':
        return _numAt(point['steps'], ['countSum', 'count_sum', 'sum']);
      case 'active-energy-burned':
        return _numAt(point['activeEnergyBurned'], [
              'kilocaloriesSum',
              'kilocalories_sum',
              'energyKilocaloriesSum',
            ]) ??
            _numAt(point['activeEnergyBurned'], ['sum']);
      case 'total-calories':
        return _numAt(point['totalCalories'], [
          'kilocaloriesSum',
          'kilocalories_sum',
          'sum',
        ]);
      case 'sedentary-period':
        return _durationMinutes(point['sedentaryPeriod']) ??
            _numAt(point['sedentaryPeriod'], ['minutesSum', 'minutes_sum', 'sum']);
      case 'active-minutes':
        return _durationMinutes(point['activeMinutes']) ??
            _numAt(point['activeMinutes'], ['minutesSum', 'minutes_sum', 'sum']);
      case 'active-zone-minutes':
        return _numAt(point['activeZoneMinutes'], [
              'minutesSum',
              'zoneMinutesSum',
              'minutes_sum',
              'sum',
            ]);
      case 'distance':
        final mm = _numAt(point['distance'], [
          'distanceMillimetersSum',
          'millimetersSum',
          'sum',
        ]);
        return mm == null ? null : mm / 1000.0; // meters
      case 'floors':
        return _numAt(point['floors'], ['floorsSum', 'floors_sum', 'sum']);
      case 'heart-rate':
        return _numAt(point['heartRate'], [
          'beatsPerMinuteAverage',
          'beats_per_minute_average',
          'average',
        ]);
      default:
        return _firstNumeric(point);
    }
  }

  Future<Map<DateTime, double>> _listDailySummaries({
    required Map<String, String> headers,
    required String dataType,
    required String filterName,
    required DateTime start,
    required DateTime end,
  }) async {
    final startStr = _ymd(start);
    final endStr = _ymd(end);
    final filter =
        '$filterName.date >= "$startStr" AND $filterName.date < "$endStr"';
    final uri = Uri.parse(
      '$_base/users/me/dataTypes/$dataType/dataPoints',
    ).replace(queryParameters: {
      'filter': filter,
      'pageSize': '100',
    });

    final response = await _http.get(uri, headers: headers);
    if (response.statusCode >= 400) return {};

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final points = (body['dataPoints'] as List<dynamic>? ?? const []);
    final out = <DateTime, double>{};

    for (final raw in points) {
      final point = raw as Map<String, dynamic>;
      final date = _dateFromPoint(point) ?? _dateFromCivil(point['date'] as Map?);
      if (date == null) continue;
      final value = _extractDailySummary(point, dataType);
      if (value != null) out[date] = value;
    }
    return out;
  }

  double? _extractDailySummary(Map<String, dynamic> point, String dataType) {
    final nested = point[dataType.replaceAll('-', '')] ??
        point[_camel(dataType)] ??
        point['value'] ??
        point;

    if (nested is! Map) {
      return _firstNumeric(point);
    }
    final map = Map<String, dynamic>.from(nested);

    switch (dataType) {
      case 'daily-resting-heart-rate':
        return _numAt(map, [
              'beatsPerMinute',
              'beats_per_minute',
              'restingHeartRate',
            ]) ??
            _avgPair(map, 'beatsPerMinuteMin', 'beatsPerMinuteMax');
      case 'daily-heart-rate-variability':
        return _numAt(map, [
              'averageHeartRateVariabilityMilliseconds',
              'hrvMilliseconds',
              'milliseconds',
            ]) ??
            _avgPair(
              map,
              'averageHeartRateVariabilityMillisecondsMin',
              'averageHeartRateVariabilityMillisecondsMax',
            );
      case 'daily-oxygen-saturation':
        return _numAt(map, [
          'saturationPercentage',
          'oxygenSaturationPercentage',
          'percentage',
          'average',
        ]);
      case 'daily-respiratory-rate':
        return _numAt(map, [
          'breathsPerMinute',
          'respiratoryRate',
          'average',
        ]);
      case 'daily-vo2-max':
        return _numAt(map, [
          'vo2Max',
          'millilitersPerMinutePerKilogram',
          'value',
        ]);
      case 'daily-sleep-temperature-derivations':
        return _numAt(map, [
          'temperatureDeviationCelsius',
          'deviationCelsius',
          'relativeSkinTemperatureCelsius',
          'value',
        ]);
      default:
        return _firstNumeric(map);
    }
  }

  Future<Map<DateTime, HeartRateZones>> _listHeartRateZones({
    required Map<String, String> headers,
    required DateTime start,
    required DateTime end,
  }) async {
    final filter =
        'daily_heart_rate_zones.date >= "${_ymd(start)}" AND daily_heart_rate_zones.date < "${_ymd(end)}"';
    final uri = Uri.parse(
      '$_base/users/me/dataTypes/daily-heart-rate-zones/dataPoints',
    ).replace(queryParameters: {'filter': filter, 'pageSize': '100'});
    final response = await _http.get(uri, headers: headers);
    if (response.statusCode >= 400) return {};
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final points = (body['dataPoints'] as List<dynamic>? ?? const []);
    final out = <DateTime, HeartRateZones>{};
    for (final raw in points) {
      final point = raw as Map<String, dynamic>;
      final date = _dateFromPoint(point) ?? _dateFromCivil(point['date'] as Map?);
      if (date == null) continue;
      final zones = point['dailyHeartRateZones'] as Map<String, dynamic>? ??
          point['value'] as Map<String, dynamic>? ??
          point;
      out[date] = HeartRateZones(
        outOfRangeMinutes: _zoneMinutes(zones, const [
          'outOfRangeMinutes',
          'belowMinutes',
          'outOfZoneMinutes',
        ]),
        fatBurnMinutes: _zoneMinutes(zones, const [
          'fatBurnMinutes',
          'fatBurnZoneMinutes',
          'lightMinutes',
        ]),
        cardioMinutes: _zoneMinutes(zones, const [
          'cardioMinutes',
          'cardioZoneMinutes',
          'moderateMinutes',
        ]),
        peakMinutes: _zoneMinutes(zones, const [
          'peakMinutes',
          'peakZoneMinutes',
          'vigorousMinutes',
        ]),
      );
    }
    return out;
  }

  int _zoneMinutes(Map<String, dynamic> map, List<String> keys) {
    final v = _numAt(map, keys);
    return v?.round() ?? 0;
  }

  Future<List<ExerciseSession>> _listExercises({
    required Map<String, String> headers,
    required DateTime start,
    required DateTime end,
  }) async {
    final filter =
        'exercise.interval.civil_start_time >= "${_ymd(start)}" '
        'AND exercise.interval.civil_start_time < "${_ymd(end)}"';
    final uri = Uri.parse('$_base/users/me/dataTypes/exercise/dataPoints')
        .replace(queryParameters: {'filter': filter, 'pageSize': '25'});
    final response = await _http.get(uri, headers: headers);
    if (response.statusCode >= 400) return [];
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final points = (body['dataPoints'] as List<dynamic>? ?? const []);
    final out = <ExerciseSession>[];
    for (final raw in points) {
      final point = raw as Map<String, dynamic>;
      final exercise = point['exercise'] as Map<String, dynamic>? ?? point;
      final interval = exercise['interval'] as Map<String, dynamic>? ?? {};
      final startTime =
          DateTime.tryParse('${interval['startTime']}')?.toLocal() ??
              _dateFromCivil(interval['civilStartTime'] as Map?);
      final endTime = DateTime.tryParse('${interval['endTime']}')?.toLocal() ??
          _dateFromCivil(interval['civilEndTime'] as Map?) ??
          startTime;
      if (startTime == null || endTime == null) continue;
      final name = '${exercise['activityName'] ?? exercise['name'] ?? exercise['type'] ?? 'Workout'}';
      out.add(
        ExerciseSession(
          id: '${point['name'] ?? startTime.millisecondsSinceEpoch}',
          name: name,
          start: startTime,
          end: endTime,
          calories: _numAt(exercise, const [
            'calories',
            'activeEnergyKilocalories',
            'kilocalories',
          ]),
          distanceMeters: () {
            final mm = _numAt(exercise, const [
              'distanceMillimeters',
              'distance_mm',
            ]);
            if (mm != null) return mm / 1000.0;
            return _numAt(exercise, const ['distanceMeters', 'distance']);
          }(),
          avgHeartRate: _numAt(exercise, const [
            'averageHeartRate',
            'avgHeartRate',
            'beatsPerMinuteAverage',
          ]),
          maxHeartRate: _numAt(exercise, const [
            'maxHeartRate',
            'maximumHeartRate',
            'beatsPerMinuteMax',
          ]),
          minHeartRate: _numAt(exercise, const [
            'minHeartRate',
            'minimumHeartRate',
            'beatsPerMinuteMin',
          ]),
          steps: _numAt(exercise, const ['steps', 'stepCount'])?.round(),
          elevationGainMeters: () {
            final mm = _numAt(exercise, const [
              'elevationGainMillimeters',
              'elevationMillimeters',
            ]);
            if (mm != null) return mm / 1000.0;
            return _numAt(exercise, const ['elevationGainMeters', 'elevation']);
          }(),
          zoneMinutes: _numAt(exercise, const [
            'activeZoneMinutes',
            'zoneMinutes',
          ])?.round(),
          speedMetersPerSecond: _numAt(exercise, const [
            'averageSpeedMetersPerSecond',
            'speedMetersPerSecond',
            'speed',
          ]),
        ),
      );
    }
    return out;
  }

  Future<BodySnapshot?> _fetchBody({
    required Map<String, String> headers,
  }) async {
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 90));
    final weight = await _latestSample(
      headers: headers,
      dataType: 'weight',
      filter:
          'weight.sample_time.physical_time >= "${start.toUtc().toIso8601String()}"',
      keys: const ['weightKilograms', 'kilograms', 'value'],
    );
    final fat = await _latestSample(
      headers: headers,
      dataType: 'body-fat',
      filter:
          'body_fat.sample_time.physical_time >= "${start.toUtc().toIso8601String()}"',
      keys: const ['percentage', 'bodyFatPercentage', 'value'],
    );
    final height = await _latestSample(
      headers: headers,
      dataType: 'height',
      filter:
          'height.sample_time.physical_time >= "${start.toUtc().toIso8601String()}"',
      keys: const ['heightMeters', 'meters', 'value'],
    );
    if (weight == null && fat == null && height == null) return null;
    return BodySnapshot(
      weightKg: weight?.value,
      bodyFatPercent: fat?.value,
      heightCm: height == null ? null : height.value * 100,
      measuredAt: weight?.time ?? fat?.time ?? height?.time,
    );
  }

  Future<MetricSample?> _latestSample({
    required Map<String, String> headers,
    required String dataType,
    required String filter,
    required List<String> keys,
  }) async {
    final samples = await _listSamples(
      headers: headers,
      dataType: dataType,
      filter: filter,
      valueKeys: keys,
    );
    if (samples.isEmpty) return null;
    samples.sort((a, b) => b.time.compareTo(a.time));
    return samples.first;
  }

  Future<List<PairedDeviceInfo>> _listPairedDevices({
    required Map<String, String> headers,
  }) async {
    final uri = Uri.parse('$_base/users/me/pairedDevices');
    final response = await _http.get(uri, headers: headers);
    if (response.statusCode >= 400) return [];
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final devices = (body['pairedDevices'] as List<dynamic>? ??
        body['devices'] as List<dynamic>? ??
        const []);
    return devices.map((raw) {
      final d = raw as Map<String, dynamic>;
      return PairedDeviceInfo(
        id: '${d['name'] ?? d['id'] ?? d.hashCode}',
        name: '${d['displayName'] ?? d['name'] ?? 'Fitbit'}',
        model: d['model']?.toString() ?? d['productName']?.toString(),
        lastSync: DateTime.tryParse('${d['lastSyncTime'] ?? d['updateTime']}'),
      );
    }).toList();
  }

  Future<Map<DateTime, _SleepDay>> _listSleepSessions({
    required Map<String, String> headers,
    required DateTime start,
    required DateTime end,
  }) async {
    final filter =
        'sleep.interval.end_time >= "${start.toUtc().toIso8601String()}" '
        'AND sleep.interval.end_time < "${end.toUtc().toIso8601String()}"';
    final uri = Uri.parse('$_base/users/me/dataTypes/sleep/dataPoints')
        .replace(queryParameters: {
      'filter': filter,
      'pageSize': '25',
    });

    final response = await _http.get(uri, headers: headers);
    if (response.statusCode >= 400) return {};

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final points = (body['dataPoints'] as List<dynamic>? ?? const []);
    final out = <DateTime, _SleepDay>{};

    for (final raw in points) {
      final point = raw as Map<String, dynamic>;
      final sleep = point['sleep'] as Map<String, dynamic>? ?? point;
      final interval = sleep['interval'] as Map<String, dynamic>? ?? {};
      final endTime = DateTime.tryParse('${interval['endTime']}')?.toLocal() ??
          _dateFromCivil(interval['civilEndTime'] as Map?);
      if (endTime == null) continue;
      final day = DateTime(endTime.year, endTime.month, endTime.day);

      final stages = _parseSleepStages(sleep);
      final existing = out[day];
      if (existing == null) {
        out[day] = stages;
      } else {
        out[day] = existing + stages;
      }
    }
    return out;
  }

  _SleepDay _parseSleepStages(Map<String, dynamic> sleep) {
    var deep = 0, rem = 0, light = 0, awake = 0, total = 0;

    final stageList = sleep['sleepStages'] as List<dynamic>? ??
        sleep['stages'] as List<dynamic>? ??
        const [];

    for (final raw in stageList) {
      if (raw is! Map) continue;
      final stage = Map<String, dynamic>.from(raw);
      final type = '${stage['type'] ?? stage['stage'] ?? ''}'.toLowerCase();
      final minutes = _stageMinutes(stage);
      total += minutes;
      if (type.contains('deep')) {
        deep += minutes;
      } else if (type.contains('rem')) {
        rem += minutes;
      } else if (type.contains('light') || type.contains('core')) {
        light += minutes;
      } else if (type.contains('awake') || type.contains('wake')) {
        awake += minutes;
      }
    }

    if (total == 0) {
      final duration = sleep['duration'] ?? sleep['interval'];
      total = _durationMinutes(duration)?.round() ?? 0;
    }

    return _SleepDay(
      totalMinutes: total,
      deepMinutes: deep,
      remMinutes: rem,
      lightMinutes: light,
      awakeMinutes: awake,
    );
  }

  int _stageMinutes(Map<String, dynamic> stage) {
    final direct = stage['durationMinutes'] ?? stage['minutes'];
    if (direct is num) return direct.round();
    final seconds = _durationSeconds(stage['duration'] ?? stage['interval']);
    if (seconds != null) return (seconds / 60).round();
    final start = DateTime.tryParse('${stage['startTime']}');
    final end = DateTime.tryParse('${stage['endTime']}');
    if (start != null && end != null) {
      return end.difference(start).inMinutes.abs();
    }
    return 0;
  }

  Future<List<MetricSample>> _listHeartSamples({
    required Map<String, String> headers,
    required DateTime start,
    required DateTime end,
  }) async {
    // Intraday HR is capped at 14-day windows — we already request ≤14 days.
    final filter =
        'heart_rate.sample_time.physical_time >= "${start.toUtc().toIso8601String()}" '
        'AND heart_rate.sample_time.physical_time < "${end.toUtc().toIso8601String()}"';
    return _listSamples(
      headers: headers,
      dataType: 'heart-rate',
      filter: filter,
      valueKeys: const ['beatsPerMinute', 'beats_per_minute', 'bpm'],
    );
  }

  Future<List<MetricSample>> _listSpo2Samples({
    required Map<String, String> headers,
    required DateTime start,
    required DateTime end,
  }) async {
    final filter =
        'oxygen_saturation.sample_time.physical_time >= "${start.toUtc().toIso8601String()}" '
        'AND oxygen_saturation.sample_time.physical_time < "${end.toUtc().toIso8601String()}"';
    return _listSamples(
      headers: headers,
      dataType: 'oxygen-saturation',
      filter: filter,
      valueKeys: const [
        'saturationPercentage',
        'percentage',
        'oxygenSaturationPercentage',
      ],
    );
  }

  Future<List<MetricSample>> _listSamples({
    required Map<String, String> headers,
    required String dataType,
    required String filter,
    required List<String> valueKeys,
  }) async {
    final out = <MetricSample>[];
    String? pageToken;

    do {
      final params = <String, String>{
        'filter': filter,
        'pageSize': '1000',
      };
      if (pageToken != null) params['pageToken'] = pageToken;

      final uri = Uri.parse('$_base/users/me/dataTypes/$dataType/dataPoints')
          .replace(queryParameters: params);
      final response = await _http.get(uri, headers: headers);
      if (response.statusCode >= 400) break;

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final points = (body['dataPoints'] as List<dynamic>? ?? const []);
      for (final raw in points) {
        final point = raw as Map<String, dynamic>;
        final time = _sampleTime(point);
        final value = _numAt(point[_camel(dataType)], valueKeys) ??
            _numAt(point['value'], valueKeys) ??
            _firstNumeric(point);
        if (time == null || value == null) continue;
        out.add(MetricSample(time: time, value: value));
      }
      pageToken = body['nextPageToken'] as String?;
      if (pageToken != null && pageToken.isEmpty) pageToken = null;
    } while (pageToken != null);

    return out;
  }

  Map<String, dynamic> _civil(DateTime dt) => {
        'year': dt.year,
        'month': dt.month,
        'day': dt.day,
      };

  String _ymd(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-'
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';

  DateTime? _dateFromCivil(Map? civil) {
    if (civil == null) return null;
    final y = civil['year'];
    final m = civil['month'];
    final d = civil['day'];
    if (y is! num || m is! num || d is! num) return null;
    return DateTime(y.toInt(), m.toInt(), d.toInt());
  }

  DateTime? _dateFromPoint(Map<String, dynamic> point) {
    final date = point['date'];
    if (date is String) {
      final parsed = DateTime.tryParse(date);
      if (parsed != null) {
        return DateTime(parsed.year, parsed.month, parsed.day);
      }
    }
    if (date is Map) return _dateFromCivil(date);
    return null;
  }

  DateTime? _sampleTime(Map<String, dynamic> point) {
    final sample = point['sampleTime'] as Map<String, dynamic>?;
    if (sample != null) {
      final physical = DateTime.tryParse('${sample['physicalTime']}');
      if (physical != null) return physical.toLocal();
      final civil = _dateFromCivil(sample['civilTime'] as Map?);
      if (civil != null) return civil;
    }
    return DateTime.tryParse('${point['startTime']}')?.toLocal();
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _camel(String kebab) {
    final parts = kebab.split('-');
    if (parts.isEmpty) return kebab;
    return parts.first +
        parts.skip(1).map((p) => p.isEmpty ? p : '${p[0].toUpperCase()}${p.substring(1)}').join();
  }

  double? _numAt(dynamic node, List<String> keys) {
    if (node is num) return node.toDouble();
    if (node is! Map) return null;
    final map = Map<String, dynamic>.from(node);
    for (final key in keys) {
      final v = map[key];
      if (v is num) return v.toDouble();
      if (v is String) {
        final parsed = double.tryParse(v.replaceAll(RegExp(r'[^0-9.\-]'), ''));
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  double? _avgPair(Map<String, dynamic> map, String minKey, String maxKey) {
    final min = map[minKey];
    final max = map[maxKey];
    if (min is num && max is num) return (min + max) / 2.0;
    return null;
  }

  double? _durationMinutes(dynamic node) {
    final seconds = _durationSeconds(node);
    return seconds == null ? null : seconds / 60.0;
  }

  double? _durationSeconds(dynamic node) {
    if (node is num) return node.toDouble();
    if (node is String) {
      if (node.endsWith('s')) {
        return double.tryParse(node.substring(0, node.length - 1));
      }
      return double.tryParse(node);
    }
    if (node is Map) {
      final map = Map<String, dynamic>.from(node);
      for (final key in ['seconds', 'duration', 'durationSeconds']) {
        final v = map[key];
        if (v is num) return v.toDouble();
        if (v is String) return _durationSeconds(v);
      }
      final start = DateTime.tryParse('${map['startTime']}');
      final end = DateTime.tryParse('${map['endTime']}');
      if (start != null && end != null) {
        return end.difference(start).inSeconds.abs().toDouble();
      }
    }
    return null;
  }

  double? _firstNumeric(Map<String, dynamic> map) {
    for (final value in map.values) {
      if (value is num) return value.toDouble();
      if (value is Map) {
        final nested = _firstNumeric(Map<String, dynamic>.from(value));
        if (nested != null) return nested;
      }
    }
    return null;
  }
}

class _SleepDay {
  const _SleepDay({
    required this.totalMinutes,
    required this.deepMinutes,
    required this.remMinutes,
    required this.lightMinutes,
    required this.awakeMinutes,
  });

  final int totalMinutes;
  final int deepMinutes;
  final int remMinutes;
  final int lightMinutes;
  final int awakeMinutes;

  _SleepDay operator +(_SleepDay other) => _SleepDay(
        totalMinutes: totalMinutes + other.totalMinutes,
        deepMinutes: deepMinutes + other.deepMinutes,
        remMinutes: remMinutes + other.remMinutes,
        lightMinutes: lightMinutes + other.lightMinutes,
        awakeMinutes: awakeMinutes + other.awakeMinutes,
      );
}

class HttpException implements Exception {
  HttpException(this.message);
  final String message;
  @override
  String toString() => message;
}
