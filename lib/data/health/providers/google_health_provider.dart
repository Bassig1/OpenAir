import '../google_health_client.dart';
import '../health_data_provider.dart';

/// Production provider: Fitbit / Pixel via Google Health cloud.
class GoogleHealthProvider implements HealthDataProvider {
  GoogleHealthProvider(this._client);

  final GoogleHealthClient _client;

  @override
  HealthSourceId get id => HealthSourceId.googleHealth;

  @override
  String get displayName => 'Google Health';

  @override
  bool get isSupported => true;

  @override
  Future<bool> get isConnected async => _client.currentUser != null;

  @override
  Future<bool> connect() async {
    final account = await _client.signIn();
    return account != null;
  }

  @override
  Future<void> disconnect() => _client.signOut();

  @override
  Future<HealthSyncBundle> syncRecent({int days = 30}) async {
    final result = await _client.syncRecent(days: days);
    return HealthSyncBundle(
      days: result.days,
      body: result.body,
      devices: result.devices,
    );
  }
}
