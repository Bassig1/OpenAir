# One-time OAuth setup (personal OpenAir)

Google blocked `gcloud` because that is **Google’s Cloud SDK app**, not OpenAir.
Create a **Desktop** OAuth client in **your** Google Cloud project, then sync locally.

## Do this once (≈2 minutes)

1. **Audience (Testing)** — Google Cloud Console → Audience  
   - Status: **Testing** (do not Publish)  
   - **Test users** → add your Gmail (Fitbit-linked account)

2. **Data Access** — add Google Health readonly scopes if missing  
   (activity, metrics, sleep, profile).

3. **Create Desktop client** — Clients → Create → **Desktop app**  
   - Name: `OpenAir Desktop Sync`  
   - Create → **Download JSON**  
   - Save as `tool/oauth_client.json` (gitignored — never commit)

4. Tell Cursor “oauth ready” (or wait — the watcher picks it up).

## After that

```powershell
powershell -File tool/watch_and_sync.ps1
```

A browser window opens for **OpenAir** consent (Continue past the test-app warning).  
Then `diagnostics/latest.json` is written and validated automatically.
