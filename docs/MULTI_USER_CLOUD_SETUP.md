# Multi-user Google Cloud checklist (OpenAir)

Project: `vibrant-petal-503305-b8` (Web Client ID `806833732413-…`)

## Critical: keep consent screen in **Testing**

Google Health scopes are **Restricted**. Publishing to Production without Google’s full verification causes **“This app is blocked”** for sensitive health access.

For personal / private testing:

1. Publishing status = **Testing** (do **not** Publish app yet)
2. Add your Google account under **Test users**
3. Add the Health scopes under **Data Access**
4. Sign in **only from the OpenAir Android app** (not `gcloud`, not random desktop OAuth)

## Console checklist

### 1. Audience — Testing + your account
https://console.cloud.google.com/auth/audience?project=vibrant-petal-503305-b8

1. User type = **External**
2. Status = **Testing**
3. **Test users** → add `your@gmail.com` (the same account linked to Fitbit / Google Health)

### 2. Data Access — Health scopes
https://console.cloud.google.com/auth/scopes?project=vibrant-petal-503305-b8

Add if missing:
- `…/auth/googlehealth.activity_and_fitness.readonly`
- `…/auth/googlehealth.health_metrics_and_measurements.readonly`
- `…/auth/googlehealth.sleep.readonly`
- `…/auth/googlehealth.profile.readonly`

### 3. Clients — Android + Web
https://console.cloud.google.com/auth/clients?project=vibrant-petal-503305-b8

**Android client**
- Package: `com.openair.openair`
- SHA-1: `7E:94:37:DD:EF:47:05:C0:BC:CA:7C:15:A0:98:66:C7:23:03:6A:78`

Keep the existing **Web** client (already baked into the app).

## How to sync / export for Cursor

1. Plug in your phone (USB debugging) **or** run the debug APK on device
2. Open OpenAir → Connect Google Health → approve scopes (you may see a “test app” warning — that’s OK; choose Continue)
3. Pull to refresh on Today
4. Settings → **Export data for Cursor** → paste into chat

Do **not** use `gcloud auth application-default login` with Health scopes — that uses Google’s Cloud SDK client and Google will block it.

## Public launch later

Requires Google OAuth verification (privacy policy, homepage, demo video, security assessment for Restricted scopes). Until then stay in Testing with named test users. Gemini can move to paid / per-user keys at that time without changing the Health sync path.
