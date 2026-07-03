# SecureCity — AI-Powered Smart Urban Safety System

Final Year Project (BS Computer Science, 2023–2027) — COMSATS University Islamabad, Sahiwal Campus.

A prototype safety platform that watches CCTV feeds in real time for weapons,
fights, and abnormal crowd behaviour, and pairs that with a citizen-facing
emergency app for panic alerts, live location sharing, and safety
notifications. Built and evaluated on sample datasets in a test-lab setting —
not a city-wide deployment.

## Repository layout

```
Securecity/
├── lib/                # Flutter citizen/emergency app
│   ├── core/            # colors, theme, shared utils (time-ago, severity colors)
│   ├── models/           # Alert, Camera, Notification, EmergencyContact
│   ├── services/          # AppDataStore — in-memory live data + simulated feed
│   ├── screens/
│   │   ├── splash/ onboarding/ auth/    # boot flow
│   │   ├── home/                        # shell: bottom nav + SOS button
│   │   ├── dashboard/                   # overview: stats, map preview, recent alerts
│   │   ├── alerts/                      # full alert list with severity filters
│   │   ├── map/                         # live camera + alert map (flutter_map)
│   │   ├── notifications/               # notification inbox (read/unread, dismiss)
│   │   └── profile/                     # emergency contacts + safety preferences
│   └── widgets/         # shared building blocks (alert tile, info sheet, logo)
├── backend/             # FastAPI detection service + admin dashboard
│   ├── app/
│   │   ├── detection/    # YOLOv8 inference loop, tracker, fight/crowd/weapon detectors
│   │   ├── main.py        # REST API, MJPEG stream, WebSocket alert feed
│   │   ├── database.py     # SQLite persistence for alerts/stats
│   │   └── config.py       # thresholds, camera registry, paths
│   ├── admin/            # static admin monitoring dashboard (HTML/CSS/JS)
│   └── run.py            # entry point — `python run.py` → http://localhost:8000
└── test/                # Flutter widget tests
```

## The 6 project modules

| # | Module | Owner |
|---|--------|-------|
| 1 | AI-Based CCTV Surveillance (YOLOv8 weapon/person detection, event logging) | Baidar Bakhat |
| 2 | Fight & Abnormal Crowd Detection (fights, panic movement, overcrowding, running) | Muhammad Ahmad |
| 3 | Smart Emergency Mobile App (panic button, live location sharing, contacts) | Eman Khalid |
| 4 | Smart Risk Analysis & Safety Alerts (event categorization, prioritization) | Eman Khalid |
| 5 | Admin Monitoring & Alert Management (dashboard, incident records) | Muhammad Ahmad |
| 6 | AI Detection & Data Processing (frame extraction, model pipeline) | Baidar Bakhat |

**Explicitly out of scope:** face recognition, biometric identification,
predictive crime analysis, direct integration with government/law-enforcement
systems.

Supervisor: Mr. Bilal Shabbir Qaisar · Co-supervisor: Dr. Yawar Abbas Abid.

## Flutter app

Each module/feature is its own screen, all reading from and mutating a single
shared `AppDataStore` (`lib/services/app_data_store.dart`) so state stays
consistent across the app instead of being re-mocked per screen:

- **Dashboard** — live stats (online camera count, critical alerts, computed
  risk level), an embedded live map, and the 3 most recent alerts.
- **Alerts** — the full alert feed with working High/Medium/Low filter chips
  and an acknowledge action.
- **Map** — real `flutter_map` tiles (CartoDB dark) with tappable camera and
  alert markers, a legend, and a recenter button.
- **Notifications** — a real inbox: unread badge count on the bell icon,
  tap-to-read, swipe-to-dismiss, mark-all-read.
- **Profile** — emergency contacts you can add (dialog form) or remove
  (swipe), and safety preference toggles.
- **SOS** — panic button that shares location with contacts and logs a
  notification.

The data store also runs a simulated live monitoring feed (a timer that
occasionally emits a new detection event from the camera network), so the
dashboard/alerts/notifications feel like a running system rather than a
frozen mock — there's no live backend wiring from the Flutter app yet, so this
stands in for the real-time alert stream the FastAPI backend will eventually
push.

### Color scheme — Royal Navy Blue / Gold / White

| Role | Color | Hex |
|---|---|---|
| Background | Navy | `#0A1628` |
| Surface | Navy (mid) | `#0D1F3C` |
| Card | Navy (light) | `#132040` |
| Primary / Brand | Gold | `#C9A84C` |
| Primary (light) | Gold (light) | `#E8C76A` |
| Accent (info / low severity) | Royal Blue | `#4A7FC4` |
| Text | White | `#FFFFFF` |
| Danger (high severity) | Red | `#EF4444` |
| Warning (medium severity) | Amber | `#F59E0B` |

Defined once in `lib/core/constants/app_colors.dart` and mirrored in the admin
dashboard's `style.css` and the detection engine's overlay colors so the
mobile app, admin panel, and CCTV overlays all match. Red/amber are kept for
alert severity — a safety app needs universally recognizable danger/warning
colors regardless of brand palette.

### Getting started

```bash
flutter pub get
flutter run              # pick a connected device/emulator
flutter test              # run widget tests
flutter analyze           # static analysis
```

## Backend (FastAPI + YOLOv8)

```bash
cd backend
pip install -r requirements.txt
python run.py              # → http://localhost:8000 (admin dashboard + API)
```

Serves the REST API (`/api/alerts`, `/api/cameras`, `/api/stats`, …), an MJPEG
live stream (`/api/stream`), a WebSocket alert feed (`/ws/alerts`), and the
static admin monitoring dashboard. The camera registry in `app/config.py`
stays in sync with the Flutter app's demo camera pins (CAM-01 … CAM-06).

## Tech stack

Flutter 3.x / Dart 3.x · Python 3.11 · FastAPI · YOLOv8 (Ultralytics) ·
OpenCV · SQLite · flutter_map + CartoDB dark tiles · Google Fonts
(Orbitron/Inter).
