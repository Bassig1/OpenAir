# Samsung Health / Galaxy Watch (feature branch)

This branch is for experimenting with Samsung Health without changing `main`.

## Goal
Map Samsung Health / Health Connect (Samsung-sourced) data into OpenAir's shared `HealthSyncBundle`.

## Do not
- Rewrite the Google Health production path on main
- Merge until `SamsungHealthProvider` returns real days on a Galaxy device

## Implementation checklist
1. Prefer Android Health Connect where possible; Samsung Health SDK only if needed
2. Request read types aligned with Google Health bundle (HR, sleep, steps, etc.)
3. Fill in `lib/data/health/providers/samsung_health_provider.dart`
4. Optional settings toggle via `HealthProviderRegistry`
5. Keep Google Health as the default on main

## Files to touch
- `lib/data/health/providers/samsung_health_provider.dart`
- Android permissions / Health Connect declarations
- optional: settings UI to pick source
