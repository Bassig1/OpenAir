import '../health_data_provider.dart';

/// Samsung Health / Galaxy Watch — work in progress on this branch.
///
/// Prefer Health Connect for shared Android types; use Samsung SDK only
/// when a metric is not available elsewhere. Map into [HealthSyncBundle].
class SamsungHealthProvider implements HealthDataProvider {
  @override
  HealthSourceId get id => HealthSourceId.samsungHealth;

  @override
  String get displayName => 'Samsung Health';

  /// TODO: return `true` on Android once Health Connect / Samsung SDK is wired.
  @override
  bool get isSupported => false;

  @override
  Future<bool> get isConnected async {
    // TODO: check Health Connect / Samsung authorization
    return false;
  }

  @override
  Future<bool> connect() async {
    // TODO: request read permissions for HR, sleep, steps, workouts, SpO2
    throw UnimplementedError(
      'Wire Samsung / Health Connect authorization on feature/samsung-health.',
    );
  }

  @override
  Future<void> disconnect() async {
    // Clear local auth flags if any.
  }

  @override
  Future<HealthSyncBundle> syncRecent({int days = 30}) async {
    // TODO:
    // 1. Query samples for the last [days]
    // 2. Aggregate into List<DaySummary> (+ HealthExtras / body)
    // 3. Return HealthSyncBundle(days: ..., body: ..., devices: ...)
    throw UnimplementedError(
      'Map Samsung Health samples to HealthSyncBundle on this branch.',
    );
  }
}
