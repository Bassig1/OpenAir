# OpenAir

Whoop-inspired Fitbit companion for Android (iOS-ready Flutter codebase).

OpenAir reads your Fitbit data from the **Google Health API** after the official Fitbit app syncs your device, then shows Recovery / Strain / Sleep rings, heart rate, SpO₂, fitness, and sleep — plus an optional **Gemini** coach.

> Not affiliated with Whoop or Fitbit/Google. Scores are OpenAir heuristics inspired by that UX style.

## Features

- **Today** — Recovery, Strain, and Sleep rings
- **Sleep** — duration, stages, overnight SpO₂ / resting HR
- **Strain** — steps, active calories/minutes, 7-day strain chart
- **Heart** — resting HR, HRV, SpO₂, HR timeline
- **Coach** — ask Gemini about your metrics (your API key)
- **Demo mode** — full UI without OAuth so you can explore immediately

## Requirements

- Flutter 3.24+ / Dart 3.5+
- Android device or emulator
- Official Fitbit app signed into the same Google account (for live data)
- Google Cloud project with Google Health API (for live data)
- Optional: [Gemini API key](https://aistudio.google.com/)

## Quick start (demo UI)

```bash
git clone https://github.com/Bassig1/OpenAir.git
cd OpenAir
flutter pub get
flutter run
```

Demo data is on by default. Open **Settings** (gear on Today) to connect Google Health and paste a Gemini key.

## Connect Google Health (live Fitbit data)

1. Keep your Fitbit paired and syncing in the **official Fitbit app**.
2. In [Google Cloud Console](https://console.cloud.google.com/):
   - Create a project
   - Enable **Google Health API**
   - Configure **OAuth consent screen** → External → **Testing**
   - Add your Google account as a **test user**
   - Add scopes:
     - `.../auth/googlehealth.activity_and_fitness.readonly`
     - `.../auth/googlehealth.health_metrics_and_measurements.readonly`
     - `.../auth/googlehealth.sleep.readonly`
     - `.../auth/googlehealth.profile.readonly`
   - Create an **OAuth client ID** → Android
     - Package name: `com.openair.openair`
     - SHA-1: from `cd android && ./gradlew signingReport` (debug keystore)
3. In OpenAir → Settings → turn off demo data → **Connect**.

Notes:

- Health scopes are Restricted. Testing mode is enough for personal use (refresh tokens may expire ~7 days).
- OpenAir does **not** replace Fitbit Bluetooth sync.

## Gemini Coach

1. Create a key at [Google AI Studio](https://aistudio.google.com/)
2. Settings → paste key → Save
3. Coach tab → ask questions about recovery, sleep, strain, SpO₂, HRV

The key is stored in on-device secure storage and never committed to git.

## Project layout

```
lib/
  features/     # Today, Sleep, Strain, Heart, Coach, Settings
  data/         # Google Health client, demo repo, Gemini, settings
  domain/       # models + Recovery/Strain/Sleep score engine
  theme/        # dark Whoop-inspired theme
  widgets/      # rings, metric tiles
```

## iOS later

The `ios/` folder is already generated. When you are ready:

1. Add an iOS OAuth client in Google Cloud
2. Configure URL schemes / `Info.plist` for Google Sign-In
3. `flutter run` on a Mac with Xcode

## Disclaimer

OpenAir is for personal fitness insight only. It is not a medical device and does not provide medical advice.
