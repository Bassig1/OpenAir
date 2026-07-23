# Apple Health / Apple Watch (feature branch)

This branch is for experimenting with HealthKit without changing `main`.

## Goal
Map Apple Health samples into OpenAir's shared `HealthSyncBundle` so Today / Sleep / Heart / Insights keep working unchanged.

## Do not
- Rewrite `GoogleHealthClient` or flip main defaults
- Merge until `AppleHealthProvider.isSupported` works on a real device and returns real days

## Implementation checklist
1. Add HealthKit plugin / entitlements (iOS only)
2. Request read types: HR, HRV, sleep, steps, workouts, resting HR, SpO2 if available
3. Fill in `lib/data/health/providers/apple_health_provider.dart`
4. Optionally register via `HealthProviderRegistry` in a debug settings toggle
5. Keep Google Health as fallback on Android / when Apple is unavailable

## Files to touch
- `lib/data/health/providers/apple_health_provider.dart`
- iOS entitlements / Info.plist privacy strings
- optional: settings UI to pick source
