import json, os, threading, webbrowser
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from urllib.parse import urlparse, parse_qs

os.environ["OAUTHLIB_RELAX_TOKEN_SCOPE"] = "1"
from google_auth_oauthlib.flow import InstalledAppFlow

ROOT = Path(__file__).resolve().parents[1]
client = json.loads((ROOT / "tool/oauth_client.json").read_text(encoding="utf-8-sig"))
web = dict(client["web"])
for r in ("http://localhost:8765/", "http://localhost:8765"):
    if r not in web.setdefault("redirect_uris", []):
        web["redirect_uris"].append(r)
config = {"web": web}
SCOPES = [
    "openid",
    "https://www.googleapis.com/auth/userinfo.email",
    "https://www.googleapis.com/auth/userinfo.profile",
    "https://www.googleapis.com/auth/googlehealth.activity_and_fitness.readonly",
    "https://www.googleapis.com/auth/googlehealth.health_metrics_and_measurements.readonly",
    "https://www.googleapis.com/auth/googlehealth.sleep.readonly",
    "https://www.googleapis.com/auth/googlehealth.profile.readonly",
]
flow = InstalledAppFlow.from_client_config(config, SCOPES)
flow.redirect_uri = "http://localhost:8765/"
auth_url, state = flow.authorization_url(prompt="select_account consent", access_type="offline", include_granted_scopes="true")
(ROOT / "diagnostics").mkdir(exist_ok=True)
(ROOT / "diagnostics/auth_url.txt").write_text(auth_url, encoding="utf-8")
print("AUTH_URL_WRITTEN")
print(auth_url[:120] + "...")

code_holder = {"code": None, "err": None}

class H(BaseHTTPRequestHandler):
    def do_GET(self):
        q = parse_qs(urlparse(self.path).query)
        if "code" in q:
            code_holder["code"] = q["code"][0]
            self.send_response(200); self.end_headers()
            self.wfile.write(b"OpenAir authorized. Return to Cursor.")
        else:
            code_holder["err"] = q.get("error", ["unknown"])[0]
            self.send_response(400); self.end_headers()
            self.wfile.write(b"Auth failed")
    def log_message(self, *a): pass

httpd = HTTPServer(("127.0.0.1", 8765), H)
t = threading.Thread(target=httpd.handle_request, daemon=True)
t.start()
webbrowser.open(auth_url)
print("Waiting for browser Allow (Fitbit-linked account)...")
t.join(timeout=300)
httpd.server_close()
if not code_holder["code"]:
    raise SystemExit(f"No code received: {code_holder}")
flow.fetch_token(code=code_holder["code"])
(ROOT / "diagnostics/token.json").write_text(flow.credentials.to_json(), encoding="utf-8")
print("TOKEN_SAVED")
print("email check next via sync")
