import '../../domain/models/day_summary.dart';
import '../../domain/models/health_extras.dart';

/// Stable result shape every health source must produce.
class HealthSyncBundle {
  const HealthSyncBundle({
    required this.days,
    this.body,
    this.devices = const [],
  });

  final List<DaySummary> days;
  final BodySnapshot? body;
  final List<PairedDeviceInfo> devices;
}

enum HealthSourceId {
  googleHealth,
  appleHealth,
  samsungHealth,
}

/// Pluggable wearable / health-cloud providers.
///
/// Main uses [GoogleHealth] today. Apple / Samsung live on feature branches
/// and implement this contract without rewriting the app controller.
abstract class HealthDataProvider {
  HealthSourceId get id;

  String get displayName;

  /// Whether this build can attempt a connection on the current platform.
  bool get isSupported;

  Future<bool> get isConnected;

  Future<bool> connect();

  Future<void> disconnect();

  Future<HealthSyncBundle> syncRecent({int days = 30});
}

/// Registry so UI / controller can discover providers without hard-coding.
class HealthProviderRegistry {
  HealthProviderRegistry(List<HealthDataProvider> providers)
      : _providers = List.unmodifiable(providers);

  final List<HealthDataProvider> _providers;

  List<HealthDataProvider> get all => _providers;

  List<HealthDataProvider> get supported =>
      _providers.where((p) => p.isSupported).toList();

  HealthDataProvider? byId(HealthSourceId id) {
    for (final p in _providers) {
      if (p.id == id) return p;
    }
    return null;
  }
}
