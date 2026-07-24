# Multi-source health integrations

OpenAir’s **production `main`** stays Google Health (Fitbit / Pixel cloud).

To add Galaxy Watch, Oura, Apple Watch, etc. without risking the shipping app:

1. Work on the **`OpenAir-lab`** fork (or a feature branch there)
2. Implement `HealthDataProvider` in `lib/data/health/providers/`
3. Keep returning `HealthSyncBundle` so scoring / UI stay shared
4. Merge back to `OpenAir` `main` only when a device path is validated

## Repos

| Repo | Purpose |
| --- | --- |
| [`Bassig1/OpenAir`](https://github.com/Bassig1/OpenAir) `main` | Production Fitbit → Google Health companion |
| [`Bassig1/OpenAir-lab`](https://github.com/Bassig1/OpenAir-lab) | Experiments: Samsung Health / Galaxy Watch, Oura, Apple Health |

## Branches (inside a repo)

| Branch | Purpose |
| --- | --- |
| `main` | Stable Google Health path |
| `feature/samsung-health` | Galaxy Watch / Samsung Health scaffolding |
| `feature/apple-health` | Apple HealthKit scaffolding |
| `feature/oura` (lab) | Oura API experiments |

## Contract

See `lib/data/health/health_data_provider.dart`:

- `connect` / `disconnect`
- `syncRecent(days:)` → days + body + devices
- `isSupported` gates platform availability

Production continues to call `GoogleHealthClient` directly. Lab forks can swap / compose providers through `HealthProviderRegistry` when ready.
