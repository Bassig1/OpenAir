# Health diagnostics for Cursor

You do **not** need to manually tap through every screen.

## Steps

1. Rebuild / hot-restart OpenAir after a Google Health sync (pull-to-refresh on Today).
2. Open **Settings → Export data for Cursor**.
3. The JSON is copied to your clipboard.
4. In Cursor chat, paste it and say something like:

> Review this OpenAir dump. Fix wrong sleep/SpO2/body parsing and make the Whoop-style analysis match the numbers.

Optional: save the paste as `diagnostics/latest.json` in this folder (gitignored).

## What’s in the dump

- Parsed day metrics the app shows
- Body + devices
- Whoop-style recovery / sleep / strain / insight cards
- `sanityFlags` (automatic red flags)
- Truncated **raw** Google Health API samples (so we can verify parsers)

Contains personal health data — share only with your agent, not publicly.
