# OpenAir-lab

Experimental fork of [OpenAir](https://github.com/Bassig1/OpenAir) for **additional smart health sources**.

Production Fitbit → Google Health stays on `OpenAir` `main`. This fork is where we try:

- Samsung Health / **Galaxy Watch**
- **Oura**
- Apple Health / Apple Watch
- Multi-source merge / source picker UI

## Rules

1. Do not break the Google Health path needed for daily personal use on `OpenAir` main
2. Prefer Health Connect / official APIs; map everything into `HealthSyncBundle`
3. Merge validated providers back to `OpenAir` behind a source toggle

## Status

Scaffolded from production OpenAir. See `docs/INTEGRATIONS.md` and `docs/SAMSUNG_HEALTH_BRANCH.md` (when present on `feature/samsung-health`).

## Run

Same as OpenAir:

```bash
flutter pub get
flutter run
```
