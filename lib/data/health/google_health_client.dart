import 'dart:convert';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import '../../domain/models/day_summary.dart';

/// Reads Fitbit/Pixel data via Google Health API after OAuth consent.
///
/// Accurate sync path (from Google docs):
/// Fitbit device → official Fitbit app → Google Health cloud → this client.
/// Devices cannot talk directly to third-party apps.
class GoogleHealthClient {
  GoogleHealthClient({
    GoogleSignIn? googleSignIn,
    http.Client? httpClient,
  })  : _http = httpClient ?? http.Client(),
        _googleSignIn = googleSignIn ??
            GoogleSignIn(
              scopes: const [
                'https://www.googleapis.com/auth/googlehealth.activity_and_fitness.readonly',
                'https://www.googleapis.com/auth/googlehealth.health_metrics_and_measurements.readonly',
                'https://www.googleapis.com/auth/googlehealth.sleep.readonly',
                'https://www.googleapis.com/auth/googlehealth.profile.readonly',
              ],
            );

  static const _base = 'https://health.googleapis.com/v4';
  // Prefer wearable/tracker sources (Fitbit) over mixed manual entries.
  static const _wearablesFamily =
      'users/me/dataSourceFamilies/google-wearables';

  final GoogleSignIn _googleSignIn;
  final http.Client _http;

  GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;

  Future<GoogleSignInAccount?> signIn() => _googleSignIn.signIn();

  Future<GoogleSignInAccount?> signInSilently() =>
      _googleSignIn.signInSilently();

  Future<void> signOut() => _googleSignIn.signOut();

  Future<String?> _accessToken() async {
    final user = _googleSignIn.currentUser;
    if (user == null) return null;
    final auth = await user.authentication;
    return auth.accessToken;
  }

  Future<List<DaySummary>> fetchRecentDays({int days = 14}) async {
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

    // Parallel daily rollups / lists for accurate Fitbit metrics.
    final results = await Future.wait([
      _dailyRollup(headers: headers, dataType: 'steps', start: startDay, end: endDay),
      _dailyRollup(
        headers: headers,
        dataType: 'active-energy-burned',
        start: startDay,
        end: endDay,
      ),
      _dailyRollup(
        headers: headers,
        dataType: 'active-minutes',
        start: startDay,
        end: endDay,
      ),
      _dailyRollup(
        headers: headers,
        dataType: 'active-zone-minutes',
        start: startDay,
        end: endDay,
      ),
      _dailyRollup(
        headers: headers,
        dataType: 'distance',
        start: startDay,
        end: endDay,
      ),
      _dailyRollup(
        headers: headers,
        dataType: 'floors',
        start: startDay,
        end: endDay,
      ),
      _dailyRollup(
        headers: headers,
        dataType: 'heart-rate',
        start: startDay,
        end: endDay,
      ),
      _listDailySummaries(
        headers: headers,
        dataType: 'daily-resting-heart-rate',
        filterName: 'daily_resting_heart_rate',
        start: startDay,
        end: endDay,
      ),
      _listDailySummaries(
        headers: headers,
        dataType: 'daily-heart-rate-variability',
        filterName: 'daily_heart_rate_variability',
        start: startDay,
        end: endDay,
      ),
      _listDailySummaries(
        headers: headers,
        dataType: 'daily-oxygen-saturation',
        filterName: 'daily_oxygen_saturation',
        start: startDay,
        end: endDay,
      ),
      _listDailySummaries(
        headers: headers,
        dataType: 'daily-respiratory-rate',
        filterName: 'daily_respiratory_rate',
        start: startDay,
        end: endDay,
      ),
      _listSleepSessions(headers: headers, start: startDay, end: endDay),
      _listHeartSamples(headers: headers, start: startDay, end: endDay),
      _listSpo2Samples(headers: headers, start: startDay, end: endDay),
    ]);

    final steps = results[0] as Map<DateTime, double>;
    final activeEnergy = results[1] as Map<DateTime, double>;
    final activeMinutes = results[2] as Map<DateTime, double>;
    final zoneMinutes = results[3] as Map<DateTime, double>;
    final distance = results[4] as Map<DateTime, double>;
    final floors = results[5] as Map<DateTime, double>;
    final hrDaily = results[6] as Map<DateTime, double>;
    final rhr = results[7] as Map<DateTime, double>;
    final hrv = results[8] as Map<DateTime, double>;
    final spo2Daily = results[9] as Map<DateTime, double>;
    final respRate = results[10] as Map<DateTime, double>;
    final sleepByDay = results[11] as Map<DateTime, _SleepDay>;
    final heartSamples = results[12] as List<MetricSample>;
    final spo2Samples = results[13] as List<MetricSample>;

    final dates = <DateTime>{
      ...steps.keys,
      ...activeEnergy.keys,
      ...activeMinutes.keys,
      ...zoneMinutes.keys,
      ...distance.keys,
      ...floors.keys,
      ...hrDaily.keys,
      ...rhr.keys,
      ...hrv.keys,
      ...spo2Daily.keys,
      ...respRate.keys,
      ...sleepByDay.keys,
    };

    if (dates.isEmpty) {
      for (var i = 0; i < days; i++) {
        dates.add(endDay.subtract(Duration(days: i + 1)));
      }
    }

    final sorted = dates.toList()..sort();
    return sorted.map((date) {
      final dayHeart = heartSamples
          .where((s) => _sameDay(s.time, date))
          .toList()
        ..sort((a, b) => a.time.compareTo(b.time));
      final daySpo2 = spo2Samples
          .where((s) => _sameDay(s.time, date))
          .toList()
        ..sort((a, b) => a.time.compareTo(b.time));
      final sleep = sleepByDay[date];

      final avgHr = dayHeart.isEmpty
          ? hrDaily[date]
          : dayHeart.map((e) => e.value).reduce((a, b) => a + b) /
              dayHeart.length;
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
        activeMinutes: (activeMinutes[date] ?? 0).round(),
        zoneMinutes: (zoneMinutes[date] ?? 0).round(),
        distanceMeters: distance[date],
        floors: floors[date]?.round(),
        restingHeartRate: rhr[date],
        hrvMs: hrv[date],
        spo2Percent: spo2,
        respiratoryRate: respRate[date],
        sleepMinutes: sleep?.totalMinutes ?? 0,
        deepSleepMinutes: sleep?.deepMinutes ?? 0,
        remSleepMinutes: sleep?.remMinutes ?? 0,
        lightSleepMinutes: sleep?.lightMinutes ?? 0,
        awakeMinutes: sleep?.awakeMinutes ?? 0,
        avgHeartRate: avgHr,
        maxHeartRate: maxHr,
        heartSamples: dayHeart,
        spo2Samples: daySpo2,
      );
    }).toList();
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
      default:
        return _firstNumeric(map);
    }
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
