"""
One-shot: OAuth into Google Health, pull Fitbit-reconciled data, write diagnostics/latest.json
and a parsed OpenAir-style summary for Cursor review.

Uses a desktop OAuth client JSON at tool/oauth_client.json if present; otherwise
prints instructions / uses env OPENAIR_OAUTH_CLIENT_JSON.
"""
from __future__ import annotations

import json
import os
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

from google_auth_oauthlib.flow import InstalledAppFlow
from google.auth.transport.requests import AuthorizedSession

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "diagnostics" / "latest.json"
CLIENT_CANDIDATES = [
    ROOT / "tool" / "oauth_client.json",
    ROOT / "tool" / "client_secret.json",
    Path(os.environ.get("OPENAIR_OAUTH_CLIENT_JSON", "")),
]

SCOPES = [
    "openid",
    "https://www.googleapis.com/auth/userinfo.email",
    "https://www.googleapis.com/auth/googlehealth.activity_and_fitness.readonly",
    "https://www.googleapis.com/auth/googlehealth.health_metrics_and_measurements.readonly",
    "https://www.googleapis.com/auth/googlehealth.sleep.readonly",
    "https://www.googleapis.com/auth/googlehealth.profile.readonly",
]

BASE = "https://health.googleapis.com/v4"
WEARABLES = "users/me/dataSourceFamilies/google-wearables"


def ymd(dt: datetime) -> str:
    return dt.strftime("%Y-%m-%d")


def civil(dt: datetime) -> dict:
    return {
        "date": {"year": dt.year, "month": dt.month, "day": dt.day},
        "time": {"hours": 0, "minutes": 0, "seconds": 0, "nanos": 0},
    }


def find_client() -> Path:
    for p in CLIENT_CANDIDATES:
        if p and p.is_file():
            return p
    raise SystemExit(
        "Missing OAuth client JSON. Save a Desktop OAuth client as tool/oauth_client.json\n"
        "from https://console.cloud.google.com/apis/credentials?project=vibrant-petal-503305-b8"
    )


def load_client_config(path: Path) -> dict:
    raw = json.loads(path.read_text(encoding="utf-8-sig"))
    # Accept Desktop ("installed") or Web downloads; prefer loopback redirect.
    if "installed" in raw:
        cfg = {"installed": dict(raw["installed"])}
        redirects = list(cfg["installed"].get("redirect_uris") or [])
        for r in ("http://localhost:8765/", "http://localhost:8765", "http://127.0.0.1:8765/"):
            if r not in redirects:
                redirects.append(r)
        cfg["installed"]["redirect_uris"] = redirects
        return cfg
    if "web" in raw:
        web = dict(raw["web"])
        redirects = list(web.get("redirect_uris") or [])
        for r in ("http://localhost:8765/", "http://localhost:8765", "http://127.0.0.1:8765/"):
            if r not in redirects:
                redirects.append(r)
        web["redirect_uris"] = redirects
        # InstalledAppFlow accepts web configs when redirect matches.
        return {"web": web}
    raise SystemExit(f"Unrecognized OAuth client JSON keys in {path}: {list(raw)}")


def get_session():
    # Google often adds userinfo.profile; don't fail the sync on that.
    os.environ["OAUTHLIB_RELAX_TOKEN_SCOPE"] = "1"

    client = find_client()
    config = load_client_config(client)
    flow = InstalledAppFlow.from_client_config(config, SCOPES)

    # Force the Google account picker so Chrome doesn't silently use the wrong profile.
    print("")
    print("=== IMPORTANT ===")
    print("A browser will open. Choose the Google account that is LINKED TO FITBIT / Google Health.")
    print("If the wrong account is already selected, click 'Switch account' first.")
    print("=================")
    print("")

    creds = flow.run_local_server(
        port=8765,
        prompt="select_account consent",
        access_type="offline",
        include_granted_scopes="true",
        authorization_prompt_message=(
            "OpenAir: pick your Fitbit-linked Google account, then Allow Health access."
        ),
        success_message="OpenAir authorized. Close this tab and return to Cursor.",
        open_browser=True,
    )

    session = AuthorizedSession(creds)
    # Verify which account we got before pulling health data.
    try:
        info = session.get("https://www.googleapis.com/oauth2/v2/userinfo", timeout=30).json()
        email = info.get("email", "unknown")
        print(f"Authorized as: {email}")
        print("If that is NOT your Fitbit Google account, re-run and choose the other account.")
    except Exception as e:
        print(f"Could not read account email: {e}")
    return session, creds


def get_json(session: AuthorizedSession, url: str, params: dict | None = None):
    r = session.get(url, params=params or {}, timeout=60)
    return r.status_code, (r.json() if r.content else {})


def post_json(session: AuthorizedSession, url: str, body: dict):
    r = session.post(url, json=body, timeout=60)
    return r.status_code, (r.json() if r.content else {})


def truncate(obj, max_points=3):
    if isinstance(obj, dict) and isinstance(obj.get("dataPoints"), list):
        pts = obj["dataPoints"]
        if len(pts) > max_points:
            obj = dict(obj)
            obj["dataPoints"] = pts[:max_points]
            obj["_truncatedNote"] = f"Showing {max_points} of {len(pts)} dataPoints"
    return obj


def list_reconcile(session, data_type: str, filter_expr: str, page_size=25, max_pages=10):
    url = f"{BASE}/users/me/dataTypes/{data_type}/dataPoints:reconcile"
    points = []
    token = None
    pages = 0
    while True:
        params = {
            "dataSourceFamily": WEARABLES,
            "filter": filter_expr,
            "pageSize": str(page_size),
        }
        if token:
            params["pageToken"] = token
        status, body = get_json(session, url, params)
        if status >= 400:
            # fall back to plain list
            url2 = f"{BASE}/users/me/dataTypes/{data_type}/dataPoints"
            status, body = get_json(session, url2, {k: v for k, v in params.items() if k != "dataSourceFamily"})
            if status >= 400:
                return status, points, body
        points.extend(body.get("dataPoints") or [])
        token = body.get("nextPageToken") or None
        pages += 1
        if not token or pages >= max_pages:
            return status, points, {"count": len(points)}
    return status, points, {}


def parse_sleep_summary(sleep: dict) -> dict | None:
    summary = sleep.get("summary") or {}
    # Google Health sometimes returns duplicate rows in stagesSummary — keep one per type.
    by_type: dict[str, int] = {}
    for s in summary.get("stagesSummary") or []:
        t = str(s.get("type", "")).upper()
        m = int(float(s.get("minutes") or 0))
        if "DEEP" in t:
            by_type["DEEP"] = m
        elif "REM" in t:
            by_type["REM"] = m
        elif "LIGHT" in t or "ASLEEP" in t:
            by_type["LIGHT"] = m
        elif "AWAKE" in t or "RESTLESS" in t:
            by_type["AWAKE"] = m
    stages = {
        "deep": by_type.get("DEEP", 0),
        "rem": by_type.get("REM", 0),
        "light": by_type.get("LIGHT", 0),
        "awake": by_type.get("AWAKE", 0),
    }
    asleep = summary.get("minutesAsleep")
    asleep_m = int(float(asleep)) if asleep is not None else stages["deep"] + stages["rem"] + stages["light"]
    awake_m = int(float(summary["minutesAwake"])) if summary.get("minutesAwake") is not None else stages["awake"]
    interval = sleep.get("interval") or {}
    civil_end = ((interval.get("civilEndTime") or {}).get("date")) or {}
    if civil_end.get("year"):
        day = f"{civil_end['year']:04d}-{civil_end['month']:02d}-{civil_end['day']:02d}"
    else:
        end = interval.get("endTime")
        # Apply utc offset when present so the wake calendar day matches Fitbit/Google Health.
        day = None
        if end:
            from datetime import datetime, timedelta, timezone
            try:
                et = datetime.fromisoformat(end.replace("Z", "+00:00"))
                off = (interval.get("endUtcOffset") or "0s").rstrip("s")
                et_local = et + timedelta(seconds=float(off))
                day = et_local.strftime("%Y-%m-%d")
            except Exception:
                day = end[:10]
    meta = sleep.get("metadata") or {}
    return {
        "date": day,
        "sleepMinutes": asleep_m,
        "deepSleepMinutes": stages["deep"],
        "remSleepMinutes": stages["rem"],
        "lightSleepMinutes": stages["light"],
        "awakeMinutes": awake_m,
        "isMain": meta.get("main") is True,
        "isNap": meta.get("nap") is True,
        "minutesInSleepPeriod": summary.get("minutesInSleepPeriod"),
    }


def daily_value(point: dict, data_type: str):
    # nested camel key
    parts = data_type.split("-")
    camel = parts[0] + "".join(p[:1].upper() + p[1:] for p in parts[1:])
    nested = point.get(camel) or point.get("value") or point
    if not isinstance(nested, dict):
        return None
    if data_type == "daily-oxygen-saturation":
        v = nested.get("averagePercentage")
        return float(v) if v is not None else None
    if data_type == "daily-resting-heart-rate":
        v = nested.get("beatsPerMinute")
        return float(v) if v is not None else None
    if data_type == "daily-heart-rate-variability":
        v = nested.get("averageHeartRateVariabilityMilliseconds") or nested.get("hrvMilliseconds")
        return float(v) if v is not None else None
    return None


def date_of_daily(point: dict, data_type: str) -> str | None:
    parts = data_type.split("-")
    camel = parts[0] + "".join(p[:1].upper() + p[1:] for p in parts[1:])
    nested = point.get(camel) or {}
    d = (nested.get("date") if isinstance(nested, dict) else None) or point.get("date")
    if isinstance(d, dict) and d.get("year"):
        return f"{d['year']:04d}-{d['month']:02d}-{d['day']:02d}"
    if isinstance(d, str):
        return d[:10]
    return None


def main():
    print("Opening browser for Google Health consent…")
    session, creds = get_session()
    email = "unknown"
    try:
        r = session.get("https://www.googleapis.com/oauth2/v2/userinfo", timeout=30)
        email = r.json().get("email", email)
    except Exception:
        pass
    print(f"Signed in as {email}")

    now = datetime.now(timezone.utc)
    start = now - timedelta(days=30)
    end = now + timedelta(days=1)
    civil_start = datetime.now() - timedelta(days=30)
    civil_end = datetime.now() + timedelta(days=1)

    # Steps daily rollup (wearables)
    steps_status, steps_body = post_json(
        session,
        f"{BASE}/users/me/dataTypes/steps/dataPoints:dailyRollUp",
        {
            "range": {"start": civil(civil_start.replace(hour=0, minute=0, second=0, microsecond=0)),
                      "end": civil(civil_end.replace(hour=0, minute=0, second=0, microsecond=0))},
            "windowSizeDays": 1,
            "dataSourceFamily": WEARABLES,
        },
    )

    sleep_filter = (
        f'sleep.interval.civil_end_time >= "{ymd(civil_start)}" '
        f'AND sleep.interval.civil_end_time < "{ymd(civil_end)}"'
    )
    spo2_filter = (
        f'daily_oxygen_saturation.date >= "{ymd(civil_start)}" '
        f'AND daily_oxygen_saturation.date < "{ymd(civil_end)}"'
    )
    hrv_filter = (
        f'daily_heart_rate_variability.date >= "{ymd(civil_start)}" '
        f'AND daily_heart_rate_variability.date < "{ymd(civil_end)}"'
    )
    rhr_filter = (
        f'daily_resting_heart_rate.date >= "{ymd(civil_start)}" '
        f'AND daily_resting_heart_rate.date < "{ymd(civil_end)}"'
    )

    sleep_status, sleep_points, sleep_meta = list_reconcile(session, "sleep", sleep_filter, page_size=25, max_pages=20)
    spo2_status, spo2_points, _ = list_reconcile(session, "daily-oxygen-saturation", spo2_filter, page_size=100)
    hrv_status, hrv_points, _ = list_reconcile(session, "daily-heart-rate-variability", hrv_filter, page_size=100)
    rhr_status, rhr_points, _ = list_reconcile(session, "daily-resting-heart-rate", rhr_filter, page_size=100)

    # Body
    w_start = (now - timedelta(days=365)).isoformat().replace("+00:00", "Z")
    w_end = end.isoformat().replace("+00:00", "Z")
    _, weight_body = get_json(
        session,
        f"{BASE}/users/me/dataTypes/weight/dataPoints",
        {
            "filter": f'weight.sample_time.physical_time >= "{w_start}" AND weight.sample_time.physical_time < "{w_end}"',
            "pageSize": "10",
        },
    )
    _, height_body = get_json(
        session,
        f"{BASE}/users/me/dataTypes/height/dataPoints",
        {
            "filter": f'height.sample_time.physical_time >= "{w_start}" AND height.sample_time.physical_time < "{w_end}"',
            "pageSize": "10",
        },
    )

    # Parse sleep → prefer main per day
    sleep_by_day: dict[str, list] = {}
    for p in sleep_points:
        sleep = p.get("sleep") or p
        parsed = parse_sleep_summary(sleep)
        if not parsed or not parsed.get("date"):
            continue
        sleep_by_day.setdefault(parsed["date"], []).append(parsed)

    days = []
    all_dates = set(sleep_by_day.keys())
    for p in spo2_points:
        d = date_of_daily(p, "daily-oxygen-saturation")
        if d:
            all_dates.add(d)
    for p in hrv_points:
        d = date_of_daily(p, "daily-heart-rate-variability")
        if d:
            all_dates.add(d)
    for p in rhr_points:
        d = date_of_daily(p, "daily-resting-heart-rate")
        if d:
            all_dates.add(d)

    spo2_map = {}
    for p in spo2_points:
        d = date_of_daily(p, "daily-oxygen-saturation")
        v = daily_value(p, "daily-oxygen-saturation")
        if d and v is not None:
            spo2_map[d] = v
    hrv_map = {}
    for p in hrv_points:
        d = date_of_daily(p, "daily-heart-rate-variability")
        v = daily_value(p, "daily-heart-rate-variability")
        if d and v is not None:
            hrv_map[d] = v
    rhr_map = {}
    for p in rhr_points:
        d = date_of_daily(p, "daily-resting-heart-rate")
        v = daily_value(p, "daily-resting-heart-rate")
        if d and v is not None:
            rhr_map[d] = v

    steps_map = {}
    for rp in (steps_body.get("rollupDataPoints") or []):
        civil_s = ((rp.get("civilStartTime") or {}).get("date")) or {}
        if civil_s.get("year"):
            d = f"{civil_s['year']:04d}-{civil_s['month']:02d}-{civil_s['day']:02d}"
            steps_map[d] = float((rp.get("steps") or {}).get("countSum") or 0)

    for d in sorted(all_dates):
        cands = sleep_by_day.get(d, [])
        mains = [c for c in cands if c.get("isMain")]
        pool = mains or [c for c in cands if not c.get("isNap")] or cands
        sleep = max(pool, key=lambda c: c.get("sleepMinutes") or 0) if pool else None
        day = {
            "date": d,
            "steps": int(steps_map.get(d, 0)),
            "spo2Percent": spo2_map.get(d),
            "hrvMs": hrv_map.get(d),
            "restingHeartRate": rhr_map.get(d),
            "sleepMinutes": (sleep or {}).get("sleepMinutes", 0),
            "deepSleepMinutes": (sleep or {}).get("deepSleepMinutes", 0),
            "remSleepMinutes": (sleep or {}).get("remSleepMinutes", 0),
            "lightSleepMinutes": (sleep or {}).get("lightSleepMinutes", 0),
            "awakeMinutes": (sleep or {}).get("awakeMinutes", 0),
            "sleepIsMain": (sleep or {}).get("isMain"),
        }
        days.append(day)

    # Body parse
    def latest_weight_kg():
        pts = weight_body.get("dataPoints") or []
        best = None
        best_t = None
        for p in pts:
            w = p.get("weight") or {}
            grams = w.get("weightGrams")
            t = ((w.get("sampleTime") or {}).get("physicalTime"))
            if grams is None:
                continue
            if best_t is None or (t or "") > (best_t or ""):
                best_t = t
                best = float(grams) / 1000.0
        return best, best_t

    def latest_height_cm():
        pts = height_body.get("dataPoints") or []
        best = None
        best_t = None
        for p in pts:
            h = p.get("height") or {}
            mm = h.get("heightMillimeters")
            t = ((h.get("sampleTime") or {}).get("physicalTime"))
            if mm is None:
                continue
            if best_t is None or (t or "") > (best_t or ""):
                best_t = t
                best = float(mm) / 10.0
        return best, best_t

    wkg, wt = latest_weight_kg()
    hcm, ht = latest_height_cm()

    sanity = []
    for day in days:
        stage = day["deepSleepMinutes"] + day["remSleepMinutes"] + day["lightSleepMinutes"]
        if day["sleepMinutes"] and stage and abs(day["sleepMinutes"] - stage) > 45:
            sanity.append({"date": day["date"], "field": "sleepMinutes", "issue": "stage sum mismatch", "sleep": day["sleepMinutes"], "stages": stage})
        spo2 = day.get("spo2Percent")
        if spo2 is not None and (spo2 < 70 or spo2 > 100):
            sanity.append({"date": day["date"], "field": "spo2Percent", "issue": "out of range", "value": spo2})
    if wkg is not None and (wkg < 30 or wkg > 250):
        sanity.append({"field": "weightKg", "issue": "out of range", "value": wkg})
    if hcm is not None and (hcm < 100 or hcm > 250):
        sanity.append({"field": "heightCm", "issue": "out of range", "value": hcm})

    dump = {
        "exportVersion": 2,
        "exportedAt": datetime.now().isoformat(),
        "source": "tool/sync_google_health.py (wearable reconcile — Google Health parity)",
        "accountEmail": email,
        "connection": {
            "googleConnected": True,
            "dayCount": len(days),
            "hasBody": wkg is not None or hcm is not None,
            "sleepPoints": len(sleep_points),
            "apiStatus": {
                "stepsRollup": steps_status,
                "sleep": sleep_status,
                "spo2": spo2_status,
                "hrv": hrv_status,
                "rhr": rhr_status,
            },
        },
        "bodyFromGoogleHealth": {
            "weightKg": wkg,
            "heightCm": hcm,
            "measuredAt": wt or ht,
        },
        "days": days,
        "sanityFlags": sanity,
        "rawGoogleHealth": {
            "sleepSample": truncate({"dataPoints": sleep_points[:1]}),
            "spo2Sample": truncate({"dataPoints": spo2_points[:2]}),
            "hrvSample": truncate({"dataPoints": hrv_points[:2]}),
            "rhrSample": truncate({"dataPoints": rhr_points[:2]}),
            "weightSample": truncate(weight_body),
            "heightSample": truncate(height_body),
            "stepsRollupSample": {
                "status": steps_status,
                "points": (steps_body.get("rollupDataPoints") or [])[:3],
            },
        },
        "googleHealthParityNotes": [
            "Sleep uses dataPoints:reconcile + google-wearables and prefers metadata.main",
            "Daily SpO2/HRV/RHR use reconcile wearables stream",
            "Steps use dailyRollUp with google-wearables",
            "Compare these day totals to the Google Health / Fitbit app for the same dates",
        ],
    }

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(dump, indent=2), encoding="utf-8")
    print(f"Wrote {OUT} ({OUT.stat().st_size} bytes)")
    print(f"Days: {len(days)}  Sanity flags: {len(sanity)}")
    if days:
        last = days[-1]
        print(
            f"Latest {last['date']}: sleep {last['sleepMinutes']}m "
            f"SpO2 {last.get('spo2Percent')} HRV {last.get('hrvMs')} "
            f"RHR {last.get('restingHeartRate')} steps {last.get('steps')}"
        )
    if wkg or hcm:
        print(f"Body: {wkg} kg · {hcm} cm")
    for s in sanity[:10]:
        print(f"  FLAG {s}")


if __name__ == "__main__":
    main()
