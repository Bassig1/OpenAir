import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import '../../config/oauth_config.dart';
import '../../domain/models/day_summary.dart';
import '../../domain/models/health_extras.dart';
import 'rollup_math.dart';
import 'sleep_stage_math.dart';

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
        _googleSignInOverride = googleSignIn;

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

  /// Google Health caps these types at 14 days per request.
  static const _fourteenDayTypes = {
    'heart-rate',
    'active-minutes',
    'total-calories',
  };

  static const _requestTimeout = Duration(seconds: 25);

  final GoogleSignIn? _googleSignInOverride;
  GoogleSignIn? _googleSignInLazy;
  final http.Client _http;
  String? _serverClientId;

  GoogleSignIn get _googleSignIn {
    return _googleSignInOverride ??
        (_googleSignInLazy ??= _buildSignIn(_serverClientId));
  }

  set _googleSignIn(GoogleSignIn value) {
    _googleSignInLazy = value;
  }

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

  /// Update Web client ID without signing the user out (keeps session across launches).
  Future<void> configure({String? serverClientId}) async {
    final next = _normalizeClientId(serverClientId) ??
        _normalizeClientId(OAuthConfig.defaultWebClientId);
    if (next == null || next.isEmpty) {
      throw StateError(
        'Google Web OAuth Client ID is not set. Paste it in Settings → Advanced, '
        'or build with --dart-define=GOOGLE_WEB_CLIENT_ID=...',
      );
    }
    if (next == _serverClientId) return;
    _serverClientId = next;
    _googleSignIn = _buildSignIn(next);
  }

  Future<GoogleSignInAccount?> signIn() async {
    try {
      if (_serverClientId == null || _serverClientId!.isEmpty) {
        await configure(serverClientId: OAuthConfig.defaultWebClientId);
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

  /// Restore the previous Google session. Does not force a UI prompt.
  Future<GoogleSignInAccount?> signInSilently() async {
    try {
      if (_serverClientId == null || _serverClientId!.isEmpty) {
        await configure(serverClientId: OAuthConfig.defaultWebClientId);
      }
      var account = await _googleSignIn.signInSilently();
      account ??= _googleSignIn.currentUser;
      if (account == null) return null;

      final auth = await account.authentication;
      if (auth.accessToken == null || auth.accessToken!.isEmpty) {
        return null;
      }
      return account;
    } on PlatformException {
      return null;
    }
  }

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
      _activeZoneDailyRollup(headers: headers, start: startDay, end: endDay),
      _dailyRollup(headers: headers, dataType: 'distance', start: startDay, end: endDay),
      _dailyRollup(headers: headers, dataType: 'floors', start: startDay, end: endDay),
      _dailyRollup(headers: headers, dataType: 'sedentary-period', start: startDay, end: endDay),
      _heartRateDailyRollup(headers: headers, start: startDay, end: endDay),
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
      _dailyRollup(headers: headers, dataType: 'run-vo2-max', start: startDay, end: endDay),
    ]);

    final steps = results[0] as Map<DateTime, double>;
    final activeEnergy = results[1] as Map<DateTime, double>;
    final totalCalories = results[2] as Map<DateTime, double>;
    final activeMinutes = results[3] as Map<DateTime, double>;
    final azmBundle = results[4] as ({
      Map<DateTime, double> totals,
      Map<DateTime, HeartRateZones> zones,
    });
    final zoneMinutes = azmBundle.totals;
    final distance = results[5] as Map<DateTime, double>;
    final floors = results[6] as Map<DateTime, double>;
    final sedentary = results[7] as Map<DateTime, double>;
    final hrDaily = results[8] as Map<DateTime, _HrRollup>;
    final rhr = results[9] as Map<DateTime, double>;
    final hrv = results[10] as Map<DateTime, double>;
    final spo2Daily = results[11] as Map<DateTime, double>;
    final respRate = results[12] as Map<DateTime, double>;
    final vo2 = results[13] as Map<DateTime, double>;
    final skinTemp = results[14] as Map<DateTime, double>;
    final zonesByDay = <DateTime, HeartRateZones>{
      ...azmBundle.zones,
      ...(results[15] as Map<DateTime, HeartRateZones>),
    };
    final sleepByDay = results[16] as Map<DateTime, _SleepDay>;
    final heartSamples = results[17] as List<MetricSample>;
    final spo2Samples = results[18] as List<MetricSample>;
    final exercises = results[19] as List<ExerciseSession>;
    var body = results[20] as BodySnapshot?;
    final devices = results[21] as List<PairedDeviceInfo>;
    final runVo2 = results[22] as Map<DateTime, double>;

    // Prefer daily VO₂; fall back to run VO₂ samples/rollups.
    for (final entry in runVo2.entries) {
      vo2.putIfAbsent(entry.key, () => entry.value);
    }
    if (body != null && body.vo2Max == null && vo2.isNotEmpty) {
      final latestVo2 = (vo2.entries.toList()
            ..sort((a, b) => b.key.compareTo(a.key)))
          .first
          .value;
      body = BodySnapshot(
        weightKg: body.weightKg,
        bodyFatPercent: body.bodyFatPercent,
        heightCm: body.heightCm,
        vo2Max: latestVo2,
        measuredAt: body.measuredAt,
      );
    }

    final dates = <DateTime>{
      ...steps.keys,
      ...activeEnergy.keys,
      ...activeMinutes.keys,
      ...zoneMinutes.keys,
      ...distance.keys,
      ...hrDaily.keys,
      ...rhr.keys,
      ...hrv.keys,
      ...spo2Daily.keys,
      ...vo2.keys,
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
      final hrRollup = hrDaily[date];

      final avgHr = dayHeart.isEmpty
          ? hrRollup?.avg
          : dayHeart.map((e) => e.value).reduce((a, b) => a + b) /
              dayHeart.length;
      final maxHr = dayHeart.isEmpty
          ? hrRollup?.max
          : dayHeart.map((e) => e.value).reduce((a, b) => a > b ? a : b);
      final minHr = dayHeart.isEmpty
          ? hrRollup?.min
          : dayHeart.map((e) => e.value).reduce((a, b) => a < b ? a : b);
      final spo2 = _normalizeSpo2(spo2Daily[date]) ??
          (daySpo2.isEmpty
              ? null
              : _normalizeSpo2(
                  daySpo2.map((e) => e.value).reduce((a, b) => a + b) /
                      daySpo2.length,
                ));

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
        minHeartRate: minHr,
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
    final maxDays = _fourteenDayTypes.contains(dataType) ? 14 : 90;
    final span = end.difference(start).inDays;
    if (span > maxDays) {
      final out = <DateTime, double>{};
      var cursor = start;
      while (cursor.isBefore(end)) {
        final chunkEnd = cursor.add(Duration(days: maxDays));
        final actualEnd = chunkEnd.isAfter(end) ? end : chunkEnd;
        out.addAll(await _dailyRollupOnce(
          headers: headers,
          dataType: dataType,
          start: cursor,
          end: actualEnd,
        ));
        cursor = actualEnd;
      }
      return out;
    }
    return _dailyRollupOnce(
      headers: headers,
      dataType: dataType,
      start: start,
      end: end,
    );
  }

  Future<Map<DateTime, double>> _dailyRollupOnce({
    required Map<String, String> headers,
    required String dataType,
    required DateTime start,
    required DateTime end,
  }) async {
    final uri = Uri.parse(
      '$_base/users/me/dataTypes/$dataType/dataPoints:dailyRollUp',
    );
    final withWearables = jsonEncode({
      'range': {
        'start': _civil(start),
        'end': _civil(end),
      },
      'windowSizeDays': 1,
      'dataSourceFamily': _wearablesFamily,
    });
    final withoutWearables = jsonEncode({
      'range': {'start': _civil(start), 'end': _civil(end)},
      'windowSizeDays': 1,
    });

    final response =
        await _timedPost(uri, headers: headers, body: withWearables);
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw HttpException(
        'Health API auth failed (${response.statusCode}). Reconnect Google Health.',
      );
    }

    Map<DateTime, double> parsed = {};
    if (response.statusCode < 400) {
      parsed = _parseRollup(response.body, dataType);
    }

    // Prefer wearables; if empty/failed, fall back to all sources (phone + cloud).
    if (parsed.isEmpty ||
        response.statusCode == 400 ||
        response.statusCode == 404) {
      final fallback =
          await _timedPost(uri, headers: headers, body: withoutWearables);
      if (fallback.statusCode == 401 || fallback.statusCode == 403) {
        throw HttpException(
          'Health API auth failed (${fallback.statusCode}). Reconnect Google Health.',
        );
      }
      if (fallback.statusCode < 400) {
        final alt = _parseRollup(fallback.body, dataType);
        if (alt.isNotEmpty) parsed = alt;
      }
    }
    return parsed;
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
        return extractSteps(point);
      case 'active-energy-burned':
        return extractActiveEnergyKcal(point);
      case 'total-calories':
        return extractTotalCaloriesKcal(point);
      case 'sedentary-period':
        return _durationMinutes(point['sedentaryPeriod']) ??
            rollupNum(point['sedentaryPeriod'], const [
              'durationSum',
              'minutesSum',
              'minutes_sum',
              'sum',
            ]);
      case 'active-minutes':
        return extractActiveMinutes(point);
      case 'active-zone-minutes':
        return extractActiveZoneMinutes(point)?.total;
      case 'distance':
        final mm = rollupNum(point['distance'], const [
          'millimetersSum',
          'distanceMillimetersSum',
          'millimeters_sum',
          'sum',
        ]);
        return mm == null ? null : mm / 1000.0; // meters
      case 'floors':
        return rollupNum(point['floors'], const [
          'floorsSum',
          'floors_sum',
          'sum',
        ]);
      case 'heart-rate':
        return extractHeartRateRollup(point).avg;
      case 'run-vo2-max':
        return rollupNum(point['runVo2Max'], const [
          'runVo2Max',
          'run_vo2_max',
          'vo2Max',
          'vo2_max',
          'average',
          'value',
        ]);
      default:
        return _firstNumeric(point);
    }
  }

  HeartRateZones? _zonesFromActiveZoneRollup(Map<String, dynamic> point) {
    final azm = extractActiveZoneMinutes(point);
    if (azm == null) return null;
    if (azm.fat + azm.cardio + azm.peak <= 0) return null;
    return HeartRateZones(
      fatBurnMinutes: azm.fat,
      cardioMinutes: azm.cardio,
      peakMinutes: azm.peak,
    );
  }

  ({double? avg, double? min, double? max}) _extractHeartRateRollup(
    Map<String, dynamic> point,
  ) =>
      extractHeartRateRollup(point);

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

    // Same path the Google Health app uses: wearable-reconciled stream first.
    final reconciled = await _listDataPointsPaged(
      headers: headers,
      dataType: dataType,
      filter: filter,
      pageSize: '100',
      maxPages: 5,
      reconcileWearables: true,
    );
    var out = _mapDailySummaries(reconciled, dataType);
    if (out.isEmpty) {
      final plain = await _listDataPointsPaged(
        headers: headers,
        dataType: dataType,
        filter: filter,
        pageSize: '100',
        maxPages: 5,
        reconcileWearables: false,
      );
      out = _mapDailySummaries(plain, dataType);
    }
    return out;
  }

  Map<DateTime, double> _mapDailySummaries(
    List<Map<String, dynamic>> points,
    String dataType,
  ) {
    final out = <DateTime, double>{};
    for (final point in points) {
      DateTime? date = _dateFromPoint(point);
      if (date == null) {
        final nested = point[_camel(dataType)];
        if (nested is Map) {
          date = _dateFromCivil(nested['date'] as Map?);
        }
      }
      date ??= _dateFromCivil(point['date'] as Map?);
      if (date == null) continue;
      final value = _extractDailySummary(point, dataType);
      if (value != null) out[date] = value;
    }
    return out;
  }

  Future<List<Map<String, dynamic>>> _listDataPointsPaged({
    required Map<String, String> headers,
    required String dataType,
    required String filter,
    required String pageSize,
    required int maxPages,
    required bool reconcileWearables,
  }) async {
    final out = <Map<String, dynamic>>[];
    String? pageToken;
    var pages = 0;
    final path = reconcileWearables
        ? '$_base/users/me/dataTypes/$dataType/dataPoints:reconcile'
        : '$_base/users/me/dataTypes/$dataType/dataPoints';

    do {
      final params = <String, String>{
        'filter': filter,
        'pageSize': pageSize,
      };
      if (reconcileWearables) {
        params['dataSourceFamily'] = _wearablesFamily;
      }
      if (pageToken != null) params['pageToken'] = pageToken;

      final uri = Uri.parse(path).replace(queryParameters: params);
      final response = await _timedGet(uri, headers: headers);
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw HttpException(
          'Health API auth failed (${response.statusCode}). Reconnect Google Health.',
        );
      }
      if (response.statusCode >= 400) break;

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final points = (body['dataPoints'] as List<dynamic>? ?? const []);
      for (final raw in points) {
        out.add(Map<String, dynamic>.from(raw as Map));
      }
      pageToken = body['nextPageToken'] as String?;
      if (pageToken != null && pageToken.isEmpty) pageToken = null;
      pages++;
      if (pages >= maxPages) break;
    } while (pageToken != null);

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
        // API field is averagePercentage (0–100), not saturationPercentage.
        return _normalizeSpo2(
          _numAt(map, [
            'averagePercentage',
            'saturationPercentage',
            'oxygenSaturationPercentage',
            'percentage',
            'average',
          ]),
        );
      case 'daily-respiratory-rate':
        return _numAt(map, [
          'breathsPerMinute',
          'respiratoryRate',
          'average',
        ]);
      case 'daily-vo2-max':
        return _numAt(map, [
          'vo2Max',
          'vo2_max',
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

  Future<Map<DateTime, _HrRollup>> _heartRateDailyRollup({
    required Map<String, String> headers,
    required DateTime start,
    required DateTime end,
  }) async {
    final raw = await _dailyRollupRaw(
      headers: headers,
      dataType: 'heart-rate',
      start: start,
      end: end,
    );
    final out = <DateTime, _HrRollup>{};
    for (final point in raw) {
      final date = _dateFromCivil(point['civilStartTime'] as Map?);
      if (date == null) continue;
      final hr = _extractHeartRateRollup(point);
      if (hr.avg == null && hr.min == null && hr.max == null) continue;
      out[date] = _HrRollup(avg: hr.avg, min: hr.min, max: hr.max);
    }
    return out;
  }

  Future<({Map<DateTime, double> totals, Map<DateTime, HeartRateZones> zones})>
      _activeZoneDailyRollup({
    required Map<String, String> headers,
    required DateTime start,
    required DateTime end,
  }) async {
    final raw = await _dailyRollupRaw(
      headers: headers,
      dataType: 'active-zone-minutes',
      start: start,
      end: end,
    );
    final totals = <DateTime, double>{};
    final zones = <DateTime, HeartRateZones>{};
    for (final point in raw) {
      final date = _dateFromCivil(point['civilStartTime'] as Map?);
      if (date == null) continue;
      final azm = extractActiveZoneMinutes(point);
      if (azm != null) totals[date] = azm.total;
      final z = _zonesFromActiveZoneRollup(point);
      if (z != null) zones[date] = z;
    }
    return (totals: totals, zones: zones);
  }

  Future<List<Map<String, dynamic>>> _dailyRollupRaw({
    required Map<String, String> headers,
    required String dataType,
    required DateTime start,
    required DateTime end,
  }) async {
    final maxDays = _fourteenDayTypes.contains(dataType) ? 14 : 90;
    final span = end.difference(start).inDays;
    if (span > maxDays) {
      final out = <Map<String, dynamic>>[];
      var cursor = start;
      while (cursor.isBefore(end)) {
        final chunkEnd = cursor.add(Duration(days: maxDays));
        final actualEnd = chunkEnd.isAfter(end) ? end : chunkEnd;
        out.addAll(await _dailyRollupRawOnce(
          headers: headers,
          dataType: dataType,
          start: cursor,
          end: actualEnd,
        ));
        cursor = actualEnd;
      }
      return out;
    }
    return _dailyRollupRawOnce(
      headers: headers,
      dataType: dataType,
      start: start,
      end: end,
    );
  }

  Future<List<Map<String, dynamic>>> _dailyRollupRawOnce({
    required Map<String, String> headers,
    required String dataType,
    required DateTime start,
    required DateTime end,
  }) async {
    final uri = Uri.parse(
      '$_base/users/me/dataTypes/$dataType/dataPoints:dailyRollUp',
    );
    final withWearables = jsonEncode({
      'range': {
        'start': _civil(start),
        'end': _civil(end),
      },
      'windowSizeDays': 1,
      'dataSourceFamily': _wearablesFamily,
    });
    final withoutWearables = jsonEncode({
      'range': {'start': _civil(start), 'end': _civil(end)},
      'windowSizeDays': 1,
    });

    Future<List<Map<String, dynamic>>> parse(http.Response response) async {
      if (response.statusCode >= 400) return const [];
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return (body['rollupDataPoints'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    final response =
        await _timedPost(uri, headers: headers, body: withWearables);
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw HttpException(
        'Health API auth failed (${response.statusCode}). Reconnect Google Health.',
      );
    }
    var parsed = await parse(response);
    if (parsed.isEmpty ||
        response.statusCode == 400 ||
        response.statusCode == 404) {
      final fallback =
          await _timedPost(uri, headers: headers, body: withoutWearables);
      if (fallback.statusCode == 401 || fallback.statusCode == 403) {
        throw HttpException(
          'Health API auth failed (${fallback.statusCode}). Reconnect Google Health.',
        );
      }
      final alt = await parse(fallback);
      if (alt.isNotEmpty) parsed = alt;
    }
    return parsed;
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
    final response = await _timedGet(uri, headers: headers);
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
    final response = await _timedGet(uri, headers: headers);
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

  /// Public entry so Profile can refresh body without a full day sync.
  Future<BodySnapshot?> fetchLatestBody() async {
    final token = await _accessToken();
    if (token == null) {
      throw StateError('Not signed in to Google Health');
    }
    return _fetchBody(headers: {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    });
  }

  /// Truncated raw Google Health payloads for Cursor diagnostics (no secrets).
  Future<Map<String, dynamic>> fetchDiagnosticRaw() async {
    final token = await _accessToken();
    if (token == null) {
      throw StateError('Not signed in to Google Health');
    }
    final headers = {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    };
    final now = DateTime.now().toUtc();
    final start = now.subtract(const Duration(days: 14));
    final end = now.add(const Duration(days: 1));
    final civilStart = DateTime.now().subtract(const Duration(days: 14));
    final civilEnd = DateTime.now().add(const Duration(days: 1));

    Future<Map<String, dynamic>> snap(
      String label,
      String dataType,
      String filter, {
      String pageSize = '5',
      bool reconcile = false,
    }) async {
      final path = reconcile
          ? '$_base/users/me/dataTypes/$dataType/dataPoints:reconcile'
          : '$_base/users/me/dataTypes/$dataType/dataPoints';
      final params = <String, String>{
        'filter': filter,
        'pageSize': pageSize,
      };
      if (reconcile) params['dataSourceFamily'] = _wearablesFamily;
      final uri = Uri.parse(path).replace(queryParameters: params);
      try {
        final response = await _timedGet(uri, headers: headers);
        final decoded = response.statusCode < 400
            ? jsonDecode(response.body)
            : {'error': response.body};
        return {
          'status': response.statusCode,
          'dataType': dataType,
          'reconcile': reconcile,
          'body': _truncateJson(decoded, maxPoints: 3),
        };
      } catch (e) {
        return {'status': 'error', 'dataType': dataType, 'error': '$e'};
      }
    }

    final weightStart = now.subtract(const Duration(days: 365));
    return {
      'capturedAt': DateTime.now().toIso8601String(),
      'samples': {
        'weight': await snap(
          'weight',
          'weight',
          'weight.sample_time.physical_time >= "${weightStart.toIso8601String()}" '
              'AND weight.sample_time.physical_time < "${end.toIso8601String()}"',
        ),
        'height': await snap(
          'height',
          'height',
          'height.sample_time.physical_time >= "${weightStart.toIso8601String()}" '
              'AND height.sample_time.physical_time < "${end.toIso8601String()}"',
        ),
        'bodyFat': await snap(
          'body-fat',
          'body-fat',
          'body_fat.sample_time.physical_time >= "${weightStart.toIso8601String()}" '
              'AND body_fat.sample_time.physical_time < "${end.toIso8601String()}"',
        ),
        'sleep': await snap(
          'sleep',
          'sleep',
          'sleep.interval.civil_end_time >= "${_ymd(civilStart)}" '
              'AND sleep.interval.civil_end_time < "${_ymd(civilEnd)}"',
          pageSize: '3',
          reconcile: true,
        ),
        'dailyOxygen': await snap(
          'daily-oxygen-saturation',
          'daily-oxygen-saturation',
          'daily_oxygen_saturation.date >= "${_ymd(civilStart)}" '
              'AND daily_oxygen_saturation.date < "${_ymd(civilEnd)}"',
          pageSize: '7',
        ),
        'oxygenSamples': await snap(
          'oxygen-saturation',
          'oxygen-saturation',
          'oxygen_saturation.sample_time.physical_time >= "${start.toIso8601String()}" '
              'AND oxygen_saturation.sample_time.physical_time < "${end.toIso8601String()}"',
          pageSize: '10',
        ),
        'dailyHrv': await snap(
          'daily-heart-rate-variability',
          'daily-heart-rate-variability',
          'daily_heart_rate_variability.date >= "${_ymd(civilStart)}" '
              'AND daily_heart_rate_variability.date < "${_ymd(civilEnd)}"',
          pageSize: '7',
        ),
        'dailyRhr': await snap(
          'daily-resting-heart-rate',
          'daily-resting-heart-rate',
          'daily_resting_heart_rate.date >= "${_ymd(civilStart)}" '
              'AND daily_resting_heart_rate.date < "${_ymd(civilEnd)}"',
          pageSize: '7',
        ),
      },
    };
  }

  dynamic _truncateJson(dynamic node, {int maxPoints = 3}) {
    if (node is Map) {
      final map = Map<String, dynamic>.from(node);
      final points = map['dataPoints'];
      if (points is List && points.length > maxPoints) {
        map['dataPoints'] = points.take(maxPoints).toList();
        map['_truncatedNote'] =
            'Showing $maxPoints of ${points.length} dataPoints';
      }
      return map;
    }
    return node;
  }

  Future<BodySnapshot?> _fetchBody({
    required Map<String, String> headers,
  }) async {
    final now = DateTime.now().toUtc();
    final start = now.subtract(const Duration(days: 365));
    final end = now.add(const Duration(days: 1));

    // Google Health schema: weightGrams, heightMillimeters, bodyFat.percentage.
    final weightPoint = await _latestDataPoint(
      headers: headers,
      dataType: 'weight',
      filter:
          'weight.sample_time.physical_time >= "${start.toIso8601String()}" '
          'AND weight.sample_time.physical_time < "${end.toIso8601String()}"',
    );
    final fatPoint = await _latestDataPoint(
      headers: headers,
      dataType: 'body-fat',
      filter:
          'body_fat.sample_time.physical_time >= "${start.toIso8601String()}" '
          'AND body_fat.sample_time.physical_time < "${end.toIso8601String()}"',
    );
    final heightPoint = await _latestDataPoint(
      headers: headers,
      dataType: 'height',
      filter:
          'height.sample_time.physical_time >= "${start.toIso8601String()}" '
          'AND height.sample_time.physical_time < "${end.toIso8601String()}"',
    );

    final weightKg = _parseWeightKg(weightPoint);
    final heightCm = _parseHeightCm(heightPoint);
    final fat = _parseBodyFatPercent(fatPoint);
    if (weightKg == null && fat == null && heightCm == null) return null;

    return BodySnapshot(
      weightKg: weightKg,
      bodyFatPercent: fat,
      heightCm: heightCm,
      measuredAt: _sampleTime(weightPoint ?? {}, dataType: 'weight') ??
          _sampleTime(fatPoint ?? {}, dataType: 'body-fat') ??
          _sampleTime(heightPoint ?? {}, dataType: 'height'),
    );
  }

  Future<Map<String, dynamic>?> _latestDataPoint({
    required Map<String, String> headers,
    required String dataType,
    required String filter,
  }) async {
    final uri = Uri.parse('$_base/users/me/dataTypes/$dataType/dataPoints')
        .replace(queryParameters: {
      'filter': filter,
      'pageSize': '25',
    });
    final response = await _timedGet(uri, headers: headers);
    if (response.statusCode >= 400) return null;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final points = (body['dataPoints'] as List<dynamic>? ?? const []);
    if (points.isEmpty) return null;

    Map<String, dynamic>? best;
    DateTime? bestTime;
    for (final raw in points) {
      final point = Map<String, dynamic>.from(raw as Map);
      final time = _sampleTime(point, dataType: dataType);
      if (time == null) continue;
      if (bestTime == null || time.isAfter(bestTime)) {
        bestTime = time;
        best = point;
      }
    }
    return best ?? Map<String, dynamic>.from(points.first as Map);
  }

  double? _parseWeightKg(Map<String, dynamic>? point) {
    if (point == null) return null;
    final nested = point['weight'] as Map<String, dynamic>? ?? point;
    final grams = _numAt(nested, const [
      'weightGrams',
      'grams',
      'weightKilograms',
      'kilograms',
      'weightPounds',
      'pounds',
    ]);
    if (grams == null) return null;
    // Prefer grams (API required field). Large values are grams.
    if (nested.containsKey('weightGrams') || nested.containsKey('grams')) {
      return grams / 1000.0;
    }
    if (nested.containsKey('weightKilograms') ||
        nested.containsKey('kilograms')) {
      return grams;
    }
    if (nested.containsKey('weightPounds') || nested.containsKey('pounds')) {
      return grams / 2.2046226218;
    }
    // Heuristic when only a bare number is present.
    if (grams > 200) return grams / 1000.0; // grams
    if (grams > 100) return grams / 2.2046226218; // pounds
    return grams; // kg
  }

  double? _parseHeightCm(Map<String, dynamic>? point) {
    if (point == null) return null;
    final nested = point['height'] as Map<String, dynamic>? ?? point;
    final raw = _numAt(nested, const [
      'heightMillimeters',
      'millimeters',
      'heightMeters',
      'meters',
      'inches',
      'centimeters',
    ]);
    if (raw == null) return null;
    if (nested.containsKey('heightMillimeters') ||
        nested.containsKey('millimeters')) {
      return raw / 10.0;
    }
    if (nested.containsKey('heightMeters') || nested.containsKey('meters')) {
      return raw * 100.0;
    }
    if (nested.containsKey('inches')) return raw * 2.54;
    if (raw > 500) return raw / 10.0; // mm
    if (raw < 3.5) return raw * 100.0; // m
    if (raw < 100) return raw * 2.54; // in
    return raw; // cm
  }

  double? _parseBodyFatPercent(Map<String, dynamic>? point) {
    if (point == null) return null;
    final nested = point['bodyFat'] as Map<String, dynamic>? ?? point;
    return _numAt(nested, const ['percentage', 'bodyFatPercentage', 'value']);
  }

  Future<List<PairedDeviceInfo>> _listPairedDevices({
    required Map<String, String> headers,
  }) async {
    final uri = Uri.parse('$_base/users/me/pairedDevices');
    final response = await _timedGet(uri, headers: headers);
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
    // Match Google Health app: wearable reconcile + main overnight session.
    final filter =
        'sleep.interval.civil_end_time >= "${_ymd(start)}" '
        'AND sleep.interval.civil_end_time < "${_ymd(end)}"';

    var points = await _listDataPointsPaged(
      headers: headers,
      dataType: 'sleep',
      filter: filter,
      pageSize: '25',
      maxPages: 40,
      reconcileWearables: true,
    );
    if (points.isEmpty) {
      points = await _listDataPointsPaged(
        headers: headers,
        dataType: 'sleep',
        filter: filter,
        pageSize: '25',
        maxPages: 40,
        reconcileWearables: false,
      );
    }
    if (points.isEmpty) {
      final physical =
          'sleep.interval.end_time >= "${start.toUtc().toIso8601String()}" '
          'AND sleep.interval.end_time < "${end.toUtc().toIso8601String()}"';
      points = await _listDataPointsPaged(
        headers: headers,
        dataType: 'sleep',
        filter: physical,
        pageSize: '25',
        maxPages: 40,
        reconcileWearables: true,
      );
      if (points.isEmpty) {
        points = await _listDataPointsPaged(
          headers: headers,
          dataType: 'sleep',
          filter: physical,
          pageSize: '25',
          maxPages: 40,
          reconcileWearables: false,
        );
      }
    }

    // Collect candidates per wake-up day, then pick the main overnight sleep
    // (same behavior as Google Health / Fitbit — do not sum naps into the night).
    final byDay = <DateTime, List<_SleepCandidate>>{};
    for (final point in points) {
      final sleep = point['sleep'] as Map<String, dynamic>? ?? point;
      final interval = sleep['interval'] as Map<String, dynamic>? ?? {};
      DateTime? day = _dateFromCivil(interval['civilEndTime'] as Map?);
      if (day == null) {
        final endTime = DateTime.tryParse('${interval['endTime']}')?.toLocal();
        if (endTime != null) {
          day = DateTime(endTime.year, endTime.month, endTime.day);
        }
      }
      if (day == null) continue;

      final stages = _parseSleepStages(sleep);
      if (stages.totalMinutes <= 0 &&
          stages.deepMinutes + stages.remMinutes + stages.lightMinutes <= 0) {
        continue;
      }
      final meta = sleep['metadata'] as Map<String, dynamic>? ?? const {};
      final isMain = meta['main'] == true;
      final isNap = meta['nap'] == true;
      byDay.putIfAbsent(day, () => []).add(
            _SleepCandidate(
              stages: stages,
              isMain: isMain,
              isNap: isNap,
            ),
          );
    }

    final out = <DateTime, _SleepDay>{};
    for (final entry in byDay.entries) {
      final picked = _pickMainSleep(entry.value);
      if (picked != null) out[entry.key] = picked;
    }
    return out;
  }

  _SleepDay? _pickMainSleep(List<_SleepCandidate> candidates) {
    if (candidates.isEmpty) return null;
    final mains = candidates.where((c) => c.isMain).toList();
    final pool = mains.isNotEmpty
        ? mains
        : candidates.where((c) => !c.isNap).toList();
    final use = pool.isNotEmpty ? pool : candidates;
    use.sort((a, b) => b.stages.totalMinutes.compareTo(a.stages.totalMinutes));
    return use.first.stages;
  }

  _SleepDay _parseSleepStages(Map<String, dynamic> sleep) {
    // Prefer API summary: minutesAsleep excludes AWAKE (correct Fitbit-style total).
    // NOTE: Google Health sometimes duplicates stagesSummary rows — dedupe by type.
    final summary = sleep['summary'] as Map<String, dynamic>?;
    if (summary != null) {
      final stageSummaries =
          (summary['stagesSummary'] as List<dynamic>? ?? const [])
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
      final totals = parseSleepStageSummary(
        stagesSummary: stageSummaries,
        minutesAsleep: _intish(summary['minutesAsleep']),
        minutesAwake: _intish(summary['minutesAwake']),
      );
      return _SleepDay(
        totalMinutes: totals.asleepMinutes,
        deepMinutes: totals.deepMinutes,
        remMinutes: totals.remMinutes,
        lightMinutes: totals.lightMinutes,
        awakeMinutes: totals.awakeMinutes,
      );
    }

    var deep = 0, rem = 0, light = 0, awake = 0;
    final stageList = sleep['stages'] as List<dynamic>? ??
        sleep['sleepStages'] as List<dynamic>? ??
        const [];

    for (final raw in stageList) {
      if (raw is! Map) continue;
      final stage = Map<String, dynamic>.from(raw);
      final type = '${stage['type'] ?? stage['stage'] ?? ''}'.toUpperCase();
      final minutes = _stageMinutes(stage);
      if (type.contains('DEEP')) {
        deep += minutes;
      } else if (type.contains('REM')) {
        rem += minutes;
      } else if (type.contains('LIGHT') || type.contains('ASLEEP')) {
        light += minutes;
      } else if (type.contains('AWAKE') ||
          type.contains('WAKE') ||
          type.contains('RESTLESS')) {
        awake += minutes;
      }
    }

    var total = deep + rem + light;
    if (total == 0) {
      // Interval length includes awake time — only use as last resort.
      final duration = sleep['interval'];
      final period = _durationMinutes(duration)?.round() ?? 0;
      total = (period - awake).clamp(0, period);
    }

    return _SleepDay(
      totalMinutes: total,
      deepMinutes: deep,
      remMinutes: rem,
      lightMinutes: light,
      awakeMinutes: awake,
    );
  }

  int? _intish(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String) return int.tryParse(value) ?? double.tryParse(value)?.round();
    return null;
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
    return _listSamplesChunked(
      headers: headers,
      dataType: 'heart-rate',
      start: start,
      end: end,
      maxDays: 14,
      filterFor: (chunkStart, chunkEnd) =>
          'heart_rate.sample_time.physical_time >= "${chunkStart.toUtc().toIso8601String()}" '
          'AND heart_rate.sample_time.physical_time < "${chunkEnd.toUtc().toIso8601String()}"',
      valueKeys: const ['beatsPerMinute', 'beats_per_minute', 'bpm'],
    );
  }

  Future<List<MetricSample>> _listSpo2Samples({
    required Map<String, String> headers,
    required DateTime start,
    required DateTime end,
  }) async {
    final raw = await _listSamplesChunked(
      headers: headers,
      dataType: 'oxygen-saturation',
      start: start,
      end: end,
      maxDays: 90,
      filterFor: (chunkStart, chunkEnd) =>
          'oxygen_saturation.sample_time.physical_time >= "${chunkStart.toUtc().toIso8601String()}" '
          'AND oxygen_saturation.sample_time.physical_time < "${chunkEnd.toUtc().toIso8601String()}"',
      valueKeys: const [
        'percentage',
        'saturationPercentage',
        'oxygenSaturationPercentage',
        'averagePercentage',
      ],
    );
    final out = <MetricSample>[];
    for (final s in raw) {
      final pct = _normalizeSpo2(s.value);
      if (pct == null) continue;
      out.add(MetricSample(time: s.time, value: pct));
    }
    return out;
  }

  Future<List<MetricSample>> _listSamplesChunked({
    required Map<String, String> headers,
    required String dataType,
    required DateTime start,
    required DateTime end,
    required int maxDays,
    required String Function(DateTime start, DateTime end) filterFor,
    required List<String> valueKeys,
  }) async {
    final span = end.difference(start).inDays;
    if (span <= maxDays) {
      return _listSamples(
        headers: headers,
        dataType: dataType,
        filter: filterFor(start, end),
        valueKeys: valueKeys,
      );
    }

    final out = <MetricSample>[];
    var cursor = start;
    while (cursor.isBefore(end)) {
      final chunkEnd = cursor.add(Duration(days: maxDays));
      final actualEnd = chunkEnd.isAfter(end) ? end : chunkEnd;
      out.addAll(await _listSamples(
        headers: headers,
        dataType: dataType,
        filter: filterFor(cursor, actualEnd),
        valueKeys: valueKeys,
      ));
      cursor = actualEnd;
    }
    return out;
  }

  Future<List<MetricSample>> _listSamples({
    required Map<String, String> headers,
    required String dataType,
    required String filter,
    required List<String> valueKeys,
  }) async {
    final out = <MetricSample>[];
    String? pageToken;
    var pages = 0;

    do {
      final params = <String, String>{
        'filter': filter,
        'pageSize': '1000',
      };
      if (pageToken != null) params['pageToken'] = pageToken;

      final uri = Uri.parse('$_base/users/me/dataTypes/$dataType/dataPoints')
          .replace(queryParameters: params);
      final response = await _timedGet(uri, headers: headers);
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw HttpException(
          'Health API auth failed (${response.statusCode}). Reconnect Google Health.',
        );
      }
      if (response.statusCode >= 400) break;

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final points = (body['dataPoints'] as List<dynamic>? ?? const []);
      for (final raw in points) {
        final point = raw as Map<String, dynamic>;
        final time = _sampleTime(point, dataType: dataType);
        if (time == null) continue;

        // Only read numbers from the typed payload — never the whole point
        // (dataSource / timestamps used to leak garbage into SpO2 & body).
        final typed = point[_camel(dataType)];
        double? value;
        if (typed is Map) {
          final typedMap = Map<String, dynamic>.from(typed);
          value = _numAt(typedMap, valueKeys);
        } else {
          value = _numAt(point['value'], valueKeys);
        }
        if (value == null) continue;
        if (dataType == 'oxygen-saturation') {
          value = _normalizeSpo2(value);
          if (value == null) continue;
        }
        out.add(MetricSample(time: time, value: value));
      }
      pageToken = body['nextPageToken'] as String?;
      if (pageToken != null && pageToken.isEmpty) pageToken = null;
      pages++;
      // Cap pages so a dense Fitbit feed can't hang the UI forever.
      if (pages >= 20) break;
    } while (pageToken != null);

    return out;
  }

  Future<http.Response> _timedGet(
    Uri uri, {
    required Map<String, String> headers,
  }) {
    return _http.get(uri, headers: headers).timeout(_requestTimeout);
  }

  Future<http.Response> _timedPost(
    Uri uri, {
    required Map<String, String> headers,
    required String body,
  }) {
    return _http
        .post(uri, headers: headers, body: body)
        .timeout(_requestTimeout);
  }

  Map<String, dynamic> _civil(DateTime dt) => {
        'date': {
          'year': dt.year,
          'month': dt.month,
          'day': dt.day,
        },
        'time': {
          'hours': 0,
          'minutes': 0,
          'seconds': 0,
          'nanos': 0,
        },
      };

  String _ymd(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-'
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';

  /// Accepts both flat `{year,month,day}` and nested `{date:{year,month,day}}`
  /// (Google Health CivilDateTime responses use the nested form).
  DateTime? _dateFromCivil(Map? civil) => civilDate(civil);

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

  /// Google nests sampleTime under the typed payload (e.g. heartRate.sampleTime).
  DateTime? _sampleTime(Map<String, dynamic> point, {String? dataType}) {
    if (dataType != null) {
      final nested = point[_camel(dataType)];
      if (nested is Map) {
        final fromNested =
            _readSampleTime(Map<String, dynamic>.from(nested));
        if (fromNested != null) return fromNested;
      }
    }
    for (final value in point.values) {
      if (value is Map &&
          (value.containsKey('sampleTime') ||
              value.containsKey('sample_time'))) {
        final fromNested =
            _readSampleTime(Map<String, dynamic>.from(value));
        if (fromNested != null) return fromNested;
      }
    }
    return _readSampleTime(point);
  }

  DateTime? _readSampleTime(Map<String, dynamic> node) {
    final sample = node['sampleTime'] as Map<String, dynamic>? ??
        node['sample_time'] as Map<String, dynamic>?;
    if (sample != null) {
      final physical = DateTime.tryParse(
        '${sample['physicalTime'] ?? sample['physical_time']}',
      );
      if (physical != null) return physical.toLocal();
      final civilNode = sample['civilTime'] ?? sample['civil_time'];
      if (civilNode is Map) {
        final dateMap = civilNode['date'] is Map
            ? Map<String, dynamic>.from(civilNode['date'] as Map)
            : Map<String, dynamic>.from(civilNode);
        final civil = _dateFromCivil(dateMap);
        if (civil != null) {
          final time = civilNode['time'];
          if (time is Map) {
            return DateTime(
              civil.year,
              civil.month,
              civil.day,
              (time['hours'] as num?)?.toInt() ?? 0,
              (time['minutes'] as num?)?.toInt() ?? 0,
              (time['seconds'] as num?)?.toInt() ?? 0,
            );
          }
          return civil;
        }
      }
    }
    return DateTime.tryParse('${node['startTime']}')?.toLocal();
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// SpO2 must be 0–100%. Some feeds send 0–1 fractions or junk from bad keys.
  double? _normalizeSpo2(double? raw) {
    if (raw == null || raw.isNaN || raw.isInfinite) return null;
    var v = raw;
    if (v > 0 && v <= 1.0) v *= 100.0;
    if (v < 70 || v > 100) return null;
    return double.parse(v.toStringAsFixed(1));
  }

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

class _SleepCandidate {
  const _SleepCandidate({
    required this.stages,
    required this.isMain,
    required this.isNap,
  });

  final _SleepDay stages;
  final bool isMain;
  final bool isNap;
}

class _HrRollup {
  const _HrRollup({this.avg, this.min, this.max});

  final double? avg;
  final double? min;
  final double? max;
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
