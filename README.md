# OpenAir

Flutter app I built as a Fitbit / Google Health companion. I got tired of opening three apps every morning just to figure out how recovered I was, how hard I could train, and whether my sleep was actually decent.

OpenAir pulls your Google Health cloud data (after Fitbit syncs through the official Fitbit app), then shows recovery, strain, sleep, heart, and a short coach-style summary. Optional Gemini chat if you add an API key.

Sandbox for other devices (Galaxy Watch, Oura, etc.): [OpenAir-lab](https://github.com/Bassig1/OpenAir-lab)

## Built with

| Piece | Tech |
| --- | --- |
| App | **Dart** + **Flutter** |
| Auth | Google Sign-In (OAuth) |
| Health data | Google Health API (v4) |
| State / UI | Provider, go_router, Material |
| Charts | fl_chart |
| Local storage | shared_preferences, flutter_secure_storage |
| Coaching (optional) | Gemini API (`google_generative_ai`) |
| Sync / debug tools | Python scripts under `tool/` |
| Android / iOS shells | Kotlin, Swift (Flutter templates) |

Primary language on GitHub: **Dart**.

## What’s in the app

- **Today** — recovery / strain / sleep rings + plain-English brief
- **Sleep** — stages with exact %, efficiency, overnight SpO₂ / RHR
- **Strain** — 0–21 load, what’s driving it, capacity left
- **Heart** — resting / avg / min–max, HRV, zones, VO₂ when available
- **Insights + Coach** — on-device cards; Gemini if you set a key
- **Body profile** — import height/weight from Google Health (cm/kg)

Scores are my own heuristics for personal use. Not medical advice. Not affiliated with Fitbit or Google.

## Run it

```bash
flutter pub get
flutter run
```

Optional Gemini / OAuth (do not commit keys):

```bash
flutter run --dart-define=GEMINI_API_KEY=your_key_here --dart-define=GOOGLE_WEB_CLIENT_ID=your_web_client_id
```

Or paste both in Settings → Advanced. Connect with the Google account linked to Fitbit, then pull to refresh after the Fitbit app syncs.

You’ll need your own Google Cloud OAuth client (Web client ID + Android package/SHA-1). See `docs/MULTI_USER_CLOUD_SETUP.md` and `tool/SETUP_OAUTH.md`.

For day-to-day builds on your own PC, put keys in `lib/config/local_secrets.dart` and run `git update-index --skip-worktree lib/config/local_secrets.dart` so they never get pushed. The GitHub copy of that file stays empty.

## Notes

I went through a lot of revisions on sync accuracy (sleep stages, calories, HR rollups), cold start, and making strain/insights actually useful. `main` is the Fitbit → Google Health path. Experiments for other wearables live on OpenAir-lab so this repo stays the stable build.
