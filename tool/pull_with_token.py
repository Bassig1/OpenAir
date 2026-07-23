import json
import os
from pathlib import Path

from google.auth.transport.requests import AuthorizedSession, Request
from google.oauth2.credentials import Credentials

ROOT = Path(__file__).resolve().parents[1]
os.chdir(ROOT)

token = json.loads((ROOT / "diagnostics/token.json").read_text(encoding="utf-8"))
creds = Credentials.from_authorized_user_info(token)
if creds.expired and creds.refresh_token:
    creds.refresh(Request())
session = AuthorizedSession(creds)
info = session.get("https://www.googleapis.com/oauth2/v2/userinfo", timeout=30).json()
print("Authorized as:", info.get("email"))

code = (ROOT / "tool/sync_google_health.py").read_text(encoding="utf-8")
ns = {"__file__": str(ROOT / "tool/sync_google_health.py"), "__name__": "sync_google_health"}
exec(compile(code, "sync_google_health.py", "exec"), ns)


def get_session_override():
    return session, creds


ns["get_session"] = get_session_override
ns["main"]()
