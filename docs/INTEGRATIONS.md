# Multi-source health integrations

OpenAir’s **main** path stays Google Health (Fitbit / Pixel cloud).

To add other devices later without rewriting the whole app:

1. Implement `HealthDataProvider` in `lib/data/health/providers/`
2. Register it in a feature branch (do not flip main defaults)
3. Keep returning `HealthSyncBundle` so scoring / UI stay shared

## Branches

| Branch | Purpose |
| --- | --- |
| `main` | Google Health production path + provider interface |
| `feature/apple-health` | Apple HealthKit / Apple Watch experiments |
| `feature/samsung-health` | Samsung Health / Galaxy Watch experiments |

## Contract

See `lib/data/health/health_data_provider.dart`:

- `connect` / `disconnect`
- `syncRecent(days:)` → days + body + devices
- `isSupported` gates platform availability

Main continues to call `GoogleHealthClient` directly today. Feature branches can swap / compose providers through `HealthProviderRegistry` when ready.
