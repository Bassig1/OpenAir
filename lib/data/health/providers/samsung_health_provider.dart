import '../health_data_provider.dart';

/// Placeholder for Samsung Health / Galaxy Watch.
///
/// Real wiring lives on `feature/samsung-health`. Kept here so the registry
/// can list the source without changing the Google Health main path.
class SamsungHealthProvider implements HealthDataProvider {
  @override
  HealthSourceId get id => HealthSourceId.samsungHealth;

  @override
  String get displayName => 'Samsung Health';

  @override
  bool get isSupported => false;

  @override
  Future<bool> get isConnected async => false;

  @override
  Future<bool> connect() async {
    throw UnsupportedError(
      'Samsung Health is not enabled on this branch. '
      'See feature/samsung-health.',
    );
  }

  @override
  Future<void> disconnect() async {}

  @override
  Future<HealthSyncBundle> syncRecent({int days = 30}) async {
    throw UnsupportedError(
      'Samsung Health sync is not enabled on this branch. '
      'See feature/samsung-health.',
    );
  }
}
