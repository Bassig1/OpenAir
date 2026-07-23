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

## Google Health setup (live data) — required for Connect

`PlatformException null` / `ApiException: 10` means Cloud OAuth is missing or mismatched for this APK.

### 1. Google Cloud project

1. Open [Google Cloud Console](https://console.cloud.google.com/)
2. Create/select a project
3. Enable **Google Health API**
4. Open **APIs & Services → OAuth consent screen / Audience**
   - User type: External
   - Publishing status: **Testing**
   - Add **your Google email** under Test users (the same account used by Fitbit)
5. Open **Data Access → Add or remove scopes** and add:
   - `.../auth/googlehealth.activity_and_fitness.readonly`
   - `.../auth/googlehealth.health_metrics_and_measurements.readonly`
   - `.../auth/googlehealth.sleep.readonly`
   - `.../auth/googlehealth.profile.readonly`

### 2. Create TWO OAuth clients

**A) Android client** (verifies the installed APK)

- Application type: **Android**
- Package name: `com.openair.openair`
- SHA-1 (debug APK / this machine):

```text
7E:94:37:DD:EF:47:05:C0:BC:CA:7C:15:A0:98:66:C7:23:03:6A:78
```

**B) Web client** (used by the app as `serverClientId`)

- Application type: **Web application**
- Authorized redirect URI (optional for testing): `https://www.google.com`
- Copy the **Client ID** (`….apps.googleusercontent.com`)

### 3. In OpenAir Settings

1. Turn **Use demo data** OFF
2. Paste the **Web** Client ID → **Save Client ID**
3. Tap **Connect Google Health** and approve scopes

Official docs: [Set up Google Cloud and OAuth](https://developers.google.com/health/setup)

### Metrics mapping

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
