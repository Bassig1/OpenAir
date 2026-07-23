# One-time OAuth setup (personal OpenAir)

Google blocked `gcloud` because that is **Google’s Cloud SDK app**, not OpenAir.
You must create a **Desktop** OAuth client in **your** project, then we sync automatically.

## Do this once (≈2 minutes)

Browser tabs should already be open. If not:

1. **Audience (Testing)**  
   https://console.cloud.google.com/auth/audience?project=YOUR_GCP_PROJECT  
   - Status: **Testing** (do not Publish)  
   - **Test users** → add your Gmail (Fitbit-linked account)

2. **Data Access**  
   https://console.cloud.google.com/auth/scopes?project=YOUR_GCP_PROJECT  
   Add Google Health readonly scopes if missing (activity, metrics, sleep, profile).

3. **Create Desktop client**  
   https://console.cloud.google.com/auth/clients/create?project=YOUR_GCP_PROJECT  
   - Application type: **Desktop app**  
   - Name: `OpenAir Desktop Sync`  
   - Create → **Download JSON**  
   - Save the file as:

```
C:\Users\gurja\Projects\OpenAir\tool\oauth_client.json
```

4. Tell Cursor “oauth ready” (or just wait — the watcher picks it up).

## After that

```powershell
powershell -File tool/watch_and_sync.ps1
```

A browser window opens for **OpenAir** consent (Continue past the test-app warning).  
Then `diagnostics/latest.json` is written and validated automatically.
