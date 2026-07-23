# Multi-user Google Cloud checklist (OpenAir)

Project: `YOUR_GCP_PROJECT` (matches Web Client ID `806833732413-…`)

## Already done by automation
- Google Health API enabled on this project
- Web OAuth Client ID baked into the OpenAir APK
- App supports any Google account sign-in + optional Gemini key

## You must click once in Console (opened in your browser)

### 1. Audience — publish for other Google accounts
https://console.cloud.google.com/auth/audience?project=YOUR_GCP_PROJECT

1. Confirm **User type = External**
2. Click **Publish app** → confirm **In production**

### 2. Data Access — Health scopes
https://console.cloud.google.com/auth/scopes?project=YOUR_GCP_PROJECT

Add all four if missing:
- `…/auth/googlehealth.activity_and_fitness.readonly`
- `…/auth/googlehealth.health_metrics_and_measurements.readonly`
- `…/auth/googlehealth.sleep.readonly`
- `…/auth/googlehealth.profile.readonly`

### 3. Clients — Android (required for the APK)
https://console.cloud.google.com/auth/clients?project=YOUR_GCP_PROJECT

**Create client → Android**
- Package: `com.openair.openair`
- SHA-1: `7E:94:37:DD:EF:47:05:C0:BC:CA:7C:15:A0:98:66:C7:23:03:6A:78`

Keep the existing **Web** client (already in the app). Do not replace it.

## What other users do
1. Install your OpenAir APK  
2. Tap **Connect Google Health** → sign in with *their* Google/Fitbit account  
3. (Optional) paste their own Gemini key in Settings  

They do **not** need Cloud Console access.

## Google’s hard limit (cannot be skipped by us)
Health data scopes are restricted. Until Google **verifies** the app (privacy policy URL, homepage, demo video, security review — often days/weeks):
- Users may see an **unverified app** warning, or
- Access may stay capped (~100 users / testing rules)

Publishing to production is still the right next step so any Google account can attempt sign-in. Full “no warning, unlimited users” requires Google’s verification process — not something an agent can finish without your public privacy policy and review submission.
