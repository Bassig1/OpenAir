# Samsung Health / Galaxy Watch (feature branch)

This branch experiments with Galaxy Watch / Samsung Health **without changing `main`**.

`main` stays the Fitbit → Google Health production path.

## Goal

Map Samsung-sourced metrics into OpenAir’s shared `HealthSyncBundle` so recovery, sleep, strain, Gemini analysis, and notifications reuse the same UI.

## Do not

- Rewrite or destabilize the Google Health path on `main`
- Merge into `main` until `SamsungHealthProvider` returns real days on a Galaxy device
- Invent sleep / SpO₂ / HRV when the platform has no samples

## Preferred stack

1. **Android Health Connect** first (read steps, HR, sleep stages, SpO₂, workouts, RHR when present)
2. **Samsung Health Data / Partner SDK** only for metrics Health Connect lacks on Galaxy
3. Aggregate into `DaySummary` + body + devices — same contract as Google Health

## Metric parity checklist

| OpenAir field | Health Connect / Samsung source |
| --- | --- |
| Steps | Steps |
| Sleep minutes + stages | SleepSession / SleepStage |
| Resting HR | RestingHeartRate |
| HRV | HeartRateVariabilityRmssd (if available) |
| SpO₂ | OxygenSaturation |
| Workouts | ExerciseSession |
| Weight / height | Weight / Height |
| Respiratory / skin temp | When available; else leave null |

## Implementation phases

### Phase 1 — Health Connect scaffold
- Add Health Connect permissions in AndroidManifest
- Wire `health` / Health Connect Flutter plugin on this branch only
- Implement `connect()` permission request
- `isSupported => true` on Android API 28+

### Phase 2 — Day aggregation
- Fill `SamsungHealthProvider.syncRecent`
- Prefer main overnight sleep (exclude naps), same as Google Health
- Deduplicate stage rows if the API double-counts
- Return devices entry for Galaxy Watch when identifiable

### Phase 3 — App wiring
- Register provider in `HealthProviderRegistry`
- Settings: optional “Data source” picker (Google Health default)
- Keep Gemini / scores / notifications unchanged

### Phase 4 — Validate on device
- Compare OpenAir day totals vs Samsung Health app for 3+ nights
- Export diagnostics JSON and run sanity checks
- Only then consider a PR into `main` behind a source toggle

## Files to touch

- `lib/data/health/providers/samsung_health_provider.dart`
- `lib/data/health/health_data_provider.dart` / registry (if needed)
- Android Health Connect permissions + privacy policy URL
- Optional: Settings source picker UI

## Status

- Stub provider present; `isSupported` is `false`
- Branch includes latest `main` production baseline (accurate Google Health sync, Whoop-style analysis, categorized notifications)
- Ready for Phase 1 when a Galaxy Watch test device is available
