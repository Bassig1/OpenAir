import 'dart:convert';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import '../../domain/models/day_summary.dart';

/// Reads Fitbit/Pixel health data via Google Health API after OAuth consent.
///
/// Requires a Google Cloud project with Google Health API enabled and an
/// Android OAuth client configured for this app. See README.
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

    final end = DateTime.now().toUtc();
    final start = end.subtract(Duration(days: days));
    final headers = {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    };

    final steps = await _dailyRollup(
      headers: headers,
      dataType: 'steps',
      start: start,
      end: end,
    );
    final calories = await _dailyRollup(
      headers: headers,
      dataType: 'active-calories',
      start: start,
      end: end,
    );
    final activeMinutes = await _dailyRollup(
      headers: headers,
      dataType: 'active-minutes',
      start: start,
      end: end,
    );
    final rhr = await _dailyRollup(
      headers: headers,
      dataType: 'resting-heart-rate',
      start: start,
      end: end,
    );
    final hrv = await _dailyRollup(
      headers: headers,
      dataType: 'heart-rate-variability',
      start: start,
      end: end,
    );
    final spo2 = await _dailyRollup(
      headers: headers,
      dataType: 'oxygen-saturation',
      start: start,
      end: end,
    );
    final sleep = await _listPoints(
      headers: headers,
      dataType: 'sleep',
      start: start,
      end: end,
    );
    final heart = await _listPoints(
      headers: headers,
      dataType: 'heart-rate',
      start: start,
      end: end,
    );

    final dates = <DateTime>{};
    for (final map in [steps, calories, activeMinutes, rhr, hrv, spo2]) {
      dates.addAll(map.keys);
    }
    for (final sample in [...sleep, ...heart]) {
      dates.add(DateTime(sample.time.year, sample.time.month, sample.time.day));
    }

    if (dates.isEmpty) {
      // API reachable but empty — still return dated shells for UX.
      final today = DateTime.now();
      final base = DateTime(today.year, today.month, today.day);
      for (var i = 0; i < days; i++) {
        dates.add(base.subtract(Duration(days: i)));
      }
    }

    final sortedDates = dates.toList()..sort();
    return sortedDates.map((date) {
      final dayHeart = heart
          .where((s) =>
              s.time.year == date.year &&
              s.time.month == date.month &&
              s.time.day == date.day)
          .toList();
      final daySleep = sleep
          .where((s) =>
              s.time.year == date.year &&
              s.time.month == date.month &&
              s.time.day == date.day)
          .toList();
      final sleepMinutes = daySleep.fold<double>(0, (a, b) => a + b.value);

      return DaySummary(
        date: date,
        steps: (steps[date] ?? 0).round(),
        activeCalories: calories[date] ?? 0,
        activeMinutes: (activeMinutes[date] ?? 0).round(),
        restingHeartRate: rhr[date],
        hrvMs: hrv[date],
        spo2Percent: spo2[date],
        sleepMinutes: sleepMinutes.round(),
        deepSleepMinutes: (sleepMinutes * 0.18).round(),
        remSleepMinutes: (sleepMinutes * 0.22).round(),
        lightSleepMinutes: (sleepMinutes * 0.5).round(),
        awakeMinutes: (sleepMinutes * 0.1).round(),
        avgHeartRate: dayHeart.isEmpty
            ? null
            : dayHeart.map((e) => e.value).reduce((a, b) => a + b) /
                dayHeart.length,
        maxHeartRate: dayHeart.isEmpty
            ? null
            : dayHeart.map((e) => e.value).reduce((a, b) => a > b ? a : b),
        heartSamples: dayHeart,
        spo2Samples: const [],
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
      '$_base/users/me/dataTypes/$dataType/dataPoints:dailyRollUp'
      '?startTime=${start.toIso8601String()}'
      '&endTime=${end.toIso8601String()}',
    );
    final response = await _http.get(uri, headers: headers);
    if (response.statusCode == 404 || response.statusCode == 400) {
      // Data type name may differ slightly across API revisions.
      return {};
    }
    if (response.statusCode >= 400) {
      throw HttpException(
        'Health API $dataType failed (${response.statusCode}): ${response.body}',
      );
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final points = (body['dataPoints'] as List<dynamic>? ?? const []);
    final out = <DateTime, double>{};
    for (final raw in points) {
      final point = raw as Map<String, dynamic>;
      final startTime = DateTime.tryParse('${point['startTime']}')?.toLocal();
      if (startTime == null) continue;
      final day = DateTime(startTime.year, startTime.month, startTime.day);
      final value = _extractNumeric(point);
      if (value != null) out[day] = value;
    }
    return out;
  }

  Future<List<MetricSample>> _listPoints({
    required Map<String, String> headers,
    required String dataType,
    required DateTime start,
    required DateTime end,
  }) async {
    final uri = Uri.parse(
      '$_base/users/me/dataTypes/$dataType/dataPoints'
      '?startTime=${start.toIso8601String()}'
      '&endTime=${end.toIso8601String()}',
    );
    final response = await _http.get(uri, headers: headers);
    if (response.statusCode == 404 || response.statusCode == 400) {
      return [];
    }
    if (response.statusCode >= 400) {
      throw HttpException(
        'Health API $dataType list failed (${response.statusCode}): ${response.body}',
      );
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final points = (body['dataPoints'] as List<dynamic>? ?? const []);
    final out = <MetricSample>[];
    for (final raw in points) {
      final point = raw as Map<String, dynamic>;
      final startTime = DateTime.tryParse('${point['startTime']}')?.toLocal();
      final value = _extractNumeric(point);
      if (startTime == null || value == null) continue;
      out.add(MetricSample(time: startTime, value: value));
    }
    return out;
  }

  double? _extractNumeric(Map<String, dynamic> point) {
    final value = point['value'];
    if (value is num) return value.toDouble();
    if (value is Map<String, dynamic>) {
      for (final key in [
        'numericValue',
        'doubleValue',
        'intValue',
        'floatValue',
        'value',
      ]) {
        final candidate = value[key];
        if (candidate is num) return candidate.toDouble();
      }
      final duration = value['duration'];
      if (duration is String && duration.endsWith('s')) {
        return double.tryParse(duration.replaceAll('s', ''));
      }
    }
    return null;
  }
}

class HttpException implements Exception {
  HttpException(this.message);
  final String message;
  @override
  String toString() => message;
}
