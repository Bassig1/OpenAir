# OpenAir (private source)

Private Flutter source for OpenAir.

**Public overview (screenshots + write-up):** https://github.com/Bassig1/OpenAir-showcase

## What this app does

Fitbit / Google Health companion focused on a usable morning read: recovery, strain, sleep performance, heart/HRV context, insights, and optional Gemini coaching.

> Fitbit devices sync through the official Fitbit app. OpenAir reads the Google Health cloud copy after that.

## Quick start

```bash
flutter pub get
flutter run
```

Connect Google Health once (OAuth is baked into the debug build). Gemini coaching uses the project free tier after sign-in.

## Notes

Personal fitness insight only. Not affiliated with Fitbit/Google. Not a medical device.
