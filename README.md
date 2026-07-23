# OpenAir (private source)

Private source repository for the OpenAir Android/iOS Flutter app.

**Public overview (screenshots + summary):** https://github.com/Bassig1/OpenAir-showcase

## What this app does

Whoop-inspired Fitbit companion. Reads your Fitbit data from the **Google Health API** after the official Fitbit app syncs the device, then shows Recovery / Strain / Sleep, heart, SpO₂, fitness, sleep stages, and an optional Gemini coach.

> Fitbit devices cannot sync directly to third-party apps (Google’s documented limitation). Keep the official Fitbit app syncing; OpenAir reads the cloud copy accurately via Google Health.

## Quick start

```bash
flutter pub get
flutter run
```

Demo data is on by default. Connect Google Health + paste a Gemini key in Settings.

## Google Health setup (live data)

1. Fitbit app syncing on the same Google account
2. Cloud Console → enable **Google Health API**
3. OAuth consent (Testing) + your account as test user
4. Android OAuth client: package `com.openair.openair` + debug SHA-1
5. Scopes:
   - `googlehealth.activity_and_fitness.readonly`
   - `googlehealth.health_metrics_and_measurements.readonly`
   - `googlehealth.sleep.readonly`
   - `googlehealth.profile.readonly`

OpenAir uses official `dailyRollUp` (POST) + filtered `list` calls, prefers `google-wearables` sources, and maps:

| Metric | Google Health data type |
| --- | --- |
| Steps | `steps` |
| Active calories | `active-energy-burned` |
| Active / zone minutes | `active-minutes`, `active-zone-minutes` |
| Distance / floors | `distance`, `floors` |
| Resting HR | `daily-resting-heart-rate` |
| HRV | `daily-heart-rate-variability` |
| SpO₂ | `daily-oxygen-saturation` + `oxygen-saturation` |
| Respiratory rate | `daily-respiratory-rate` |
| Sleep + stages | `sleep` |
| Intraday HR | `heart-rate` |

## Gemini Coach

Paste a free key from https://aistudio.google.com in Settings. Stored only on-device.

## Disclaimer

Personal fitness insight only. Not affiliated with Whoop or Fitbit/Google. Not a medical device.
