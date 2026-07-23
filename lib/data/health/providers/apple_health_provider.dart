import '../health_data_provider.dart';

/// Apple HealthKit / Apple Watch — work in progress on this branch.
///
/// Implement HealthKit reads here; map results into [HealthSyncBundle]
/// so the rest of OpenAir (scores, Insights, UI) stays unchanged.
class AppleHealthProvider implements HealthDataProvider {
  @override
  HealthSourceId get id => HealthSourceId.appleHealth;

  @override
  String get displayName => 'Apple Health';

  /// TODO: return `true` on iOS once HealthKit entitlements are configured.
  @override
  bool get isSupported => false;

  @override
  Future<bool> get isConnected async {
    // TODO: check HealthKit authorization status
    return false;
  }

  @override
  Future<bool> connect() async {
    // TODO: request HealthKit read authorization for:
    // heart rate, resting HR, HRV, sleep analysis, steps, workouts, SpO2
    throw UnimplementedError(
      'Wire HealthKit authorization on feature/apple-health.',
    );
  }

  @override
  Future<void> disconnect() async {
    // HealthKit has no global disconnect; clear local auth flags if any.
  }

  @override
  Future<HealthSyncBundle> syncRecent({int days = 30}) async {
    // TODO:
    // 1. Query samples for the last [days]
    // 2. Aggregate into List<DaySummary> (+ HealthExtras / body)
    // 3. Return HealthSyncBundle(days: ..., body: ..., devices: ...)
    throw UnimplementedError(
      'Map HealthKit samples to HealthSyncBundle on this branch.',
    );
  }
}
