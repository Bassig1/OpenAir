import '../health_data_provider.dart';

/// Placeholder for Apple HealthKit / Apple Watch.
///
/// Real wiring lives on `feature/apple-health`. Kept here so the registry
/// can list the source without changing the Google Health main path.
class AppleHealthProvider implements HealthDataProvider {
  @override
  HealthSourceId get id => HealthSourceId.appleHealth;

  @override
  String get displayName => 'Apple Health';

  @override
  bool get isSupported => false;

  @override
  Future<bool> get isConnected async => false;

  @override
  Future<bool> connect() async {
    throw UnsupportedError(
      'Apple Health is not enabled on this branch. '
      'See feature/apple-health.',
    );
  }

  @override
  Future<void> disconnect() async {}

  @override
  Future<HealthSyncBundle> syncRecent({int days = 30}) async {
    throw UnsupportedError(
      'Apple Health sync is not enabled on this branch. '
      'See feature/apple-health.',
    );
  }
}
