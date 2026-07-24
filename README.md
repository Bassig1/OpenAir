# OpenAir

**A clearer morning read for smart health devices.**

OpenAir turns the dense feed from Fitbit → Google Health into a recovery-first companion: one Today view, exact sleep and heart percentages, strain capacity, and Gemini coaching that cites *your* numbers.

> Wearables sync through their official apps. OpenAir reads the **Google Health** cloud copy — then scores, explains, and coaches on top.

**Public overview (screenshots):** https://github.com/Bassig1/OpenAir-showcase  
**Experiment fork (Galaxy / Oura / multi-source):** https://github.com/Bassig1/OpenAir-lab

---

## Product (what shipped)

| Surface | What you get |
| --- | --- |
| **Today** | Recovery / strain / sleep rings, plain-English brief, Ask Gemini chips |
| **Sleep** | Stages with **exact %**, efficiency, restorative, overnight SpO₂ / RHR |
| **Strain** | 0–21 load, capacity left, drivers (AZM, calories, steps, workouts) |
| **Heart** | Resting / avg / min–max HR, HRV vs baseline, VO₂, zones |
| **Insights** | On-device breakdown cards + Gemini daily narrative |
| **Coach** | Ask for summaries against the last ~14 days of metrics |
| **Body** | Import height/weight from Google Health in **cm / kg** |

Scores are OpenAir heuristics for personal insight — not medical advice, not affiliated with Fitbit or Google.

---

## Design principles (after many revisions)

1. **Lead with Today** — one headline, three rings, then “what this means.” Detail lives on Sleep / Strain / Heart.
2. **Parity with Google Health** — same cloud numbers (sleep stages deduped, kcalSum, AZM zone sums, HR avg/min/max).
3. **Honest sync** — if Fitbit hasn’t uploaded, we don’t invent data; UI says when the feed is thin.
4. **Fast cold start** — show last cached day immediately; refresh Google Health in the background.
5. **Gemini built-in** — after Google Health sign-in, deeper analysis and Ask chips work without API-key tinkering (personal build).

---

## Stack

Flutter · Google Sign-In · Google Health API v4 · on-device scoring / insights · Gemini coaching · local notifications (Sleep / Heart / Workouts / Recovery)

---

## Run (private source)

```bash
flutter pub get
flutter run
```

Connect with the Google account linked to Fitbit. Pull to refresh after the Fitbit app syncs.

---

## Repo layout

| Repo / branch | Role |
| --- | --- |
| **`Bassig1/OpenAir` `main`** | Production Fitbit / Google Health companion |
| **`Bassig1/OpenAir-lab`** | Fork for Galaxy Watch, Oura, Apple Health experiments |
| **`Bassig1/OpenAir-showcase`** | Public screenshots + write-up |

See `docs/INTEGRATIONS.md` for the multi-source provider contract.
