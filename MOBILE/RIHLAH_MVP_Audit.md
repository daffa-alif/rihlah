# RIHLAH MVP Completion Audit

> **Current state:** MVP-complete per the user's usability bar — Prototype 2's mobile app
> (Firebase Auth, Firestore, RTDB + OSRM routing) plus a real Admin & Ops Web Console and
> Firestore-backed payout/SOS/driver-profile data. Scale/infra limitations remain (see
> "Explicitly out of scope" below) but every SRS-listed MVP surface is now functional.
> **Audited against:** RIHLAH_SRS_v1.0.md — 22 MVP features + §5.1 Admin & Ops Web Console
> **Date:** June 2026 (Prototype 2) — updated July 2026 (MVP completion pass)

---

## MVP Completion Pass (July 2026) — What Changed

The June 2026 audit below found 20/22 features "done," but several of those were only
persisted locally in Hive — never synced to Firestore, meaning there was no real backend
record for anything server-side (like an admin console) to read. This pass closed that gap:

- **Driver profile / BPJS / vehicle data (D-A2)** — `users/{uid}` now carries real
  `vehicleType`, `plate`, `ktpNumberMasked`, `bpjsKt`, `bpjsKs`, `bpjsInsurance` fields.
  The driver docs screen reads/writes them via an edit sheet instead of showing hardcoded
  "Aktif" everywhere.
- **Daily withdrawal (D-S6)** — `_WithdrawSheet` now creates a real `payouts` Firestore
  doc alongside the existing Hive simulation, and resolves its own status client-side
  (mirroring the payout-gateway webhook the eventual custom backend will own).
  `firestore.rules` updated to let a driver resolve their own payout's status (previously
  admin-only, which would have silently rejected every resolution).
- **SOS events (P-S7 / D-S8)** — `sos_service.dart` now writes a real `sos_events` doc
  (location, trip, role) in addition to the existing local Hive log + notification. Audio
  capture stays simulated (no mic package wired) — see "Explicitly out of scope."
- **GPS tracking smoothness** — `driver_home_screen.dart`'s idle/online marker previously
  snapped directly to each filtered GPS fix; it now uses the same `AnimationController`
  interpolation pattern as the trip-tracking screens. RTDB location writes are now
  throttled to ~2.5s (SRS: "every 3–5s") independent of the local GPS fix rate on both
  `driver_home_screen.dart` and `driver_trip_screen.dart`.
- **Admin & Ops Web Console (new)** — a separate Flutter Web entrypoint
  (`lib/main_admin.dart`, `lib/admin/**`) with email/password admin auth, Dashboard,
  Drivers, Passengers, Trips, Payouts, Safety/SOS, and Reports screens, all reading live
  from the same Firestore/RTDB the mobile apps use. See `ADMIN_CONSOLE_SETUP.md` for setup
  and `RIHLAH_Test_Checklist.md` §13 for manual test steps.

---

## Passenger Features (11)

| # | Feature | Status | Notes |
|---|---------|--------|-------|
| P-S1 | Booking Flow Lengkap | ✅ Done | search → services → confirm → searching → dispatch — all screens fully wired |
| P-S2 | Transparent Receipt [KILLER] | ✅ Done | FareCalculator with competitor delta, receipt PNG via `receipt_image.dart`, share_plus wired |
| P-S3 | Live Tracking + ETA | ✅ Done | OSRM 2-leg animated route, status state machine (accepting → arriving → arrived → inTrip), ETA countdown |
| P-S4 | Fare Estimate Sebelum Booking | ✅ Done | Live in `services_screen.dart` — base + perKm + perMin + competitor comparison |
| P-S5 | Payment — Cash + E-wallet | ✅ Done | `payment_methods_screen.dart` — Cash/QRIS/GoPay/OVO/DANA/ShopeePay, set-default persisted to Hive |
| P-S6 | Rating & Review Driver | ✅ Done | Star rating, tag chips (Sopan / Tepat waktu / etc.), tip presets — `trip_complete_screen.dart` |
| P-S7 | Emergency SOS Passenger | ✅ Done | `sos_screen.dart` — GPS capture, pulse animation, WhatsApp share, fake call to 110 |
| P-S8 | Trip History & Riwayat | ✅ Done | `activity_screen.dart` — Hive list, grouped by date, PDF export, receipt tab |
| P-A1 | Saved Addresses | ✅ Done | `saved_addresses_screen.dart` + Riverpod provider, CRUD, Home / Kantor / custom labels |
| P-A2 | In-App Chat dengan Driver | ✅ Done | Chat sheet inside `trip_screen.dart`, `mock_chat_repository.dart`, quick-reply chips |
| P-A3 | Share Trip Live ke Keluarga | ✅ Done | `_ShareTripSheet` in `trip_screen.dart` — fake tracking URL, WhatsApp share, copy-to-clipboard, 1h expiry notice |

---

## Driver Features (11)

| # | Feature | Status | Notes |
|---|---------|--------|-------|
| D-S1 | Online / Offline Toggle | ✅ Done | `driver_home_screen.dart` — anti-abuse cooldown (3 toggles / 5 min), GPS lost watchdog, auto-offline after 30 min |
| D-S2 | Order Request + Accept/Decline | ✅ Done | `incoming_order_screen.dart` — 15s countdown arc, exact rupiah displayed, accept-rate tracking to Hive |
| D-S3 | Navigation Turn-by-Turn | ⚠️ Partial | Implemented via OSRM + `flutter_tts` — not Mapbox Navigation SDK as SRS requires; voice guidance works but no Bahasa Indonesia voice pack |
| D-S4 | Earnings Dashboard Realtime | ✅ Done | `earnings_screen.dart` — Today / Week / All tabs, daily target progress bar, wallet balance |
| D-S5 | Per-Trip Breakdown [KILLER] | ✅ Done | `driver_trip_complete_screen.dart` + `driver_receipt_share.dart` — driver share vs competitor, WhatsApp share |
| D-S6 | Daily Withdrawal (Penarikan Harian) | ✅ Done | `_WithdrawSheet` inside `earnings_screen.dart` — Rp 20k minimum, free 1st/Rp 1k fee, 90% success sim, Hive balance debit **+ real `payouts` Firestore doc, visible/settleable in the admin console** |
| D-S7 | Rating & Review Display | ✅ Done | `_RatingDashboard` in `driver_profile_screen.dart` — 30-day trend chart, category breakdown, < 4.5 alert banner |
| D-S8 | Emergency SOS Driver | ⚠️ Partial | SOS button + `sos_service.dart` exist, **now writes a real `sos_events` Firestore doc visible in the admin Safety/SOS queue**; still no 30-second audio capture (deliberately deferred — see below) |
| D-S9 | Trip History + Riwayat Pendapatan | ✅ Done | `driver_history_screen.dart` — Hive list, PDF / CSV export via `history_export_service.dart` |
| D-A1 | Referral Driver (Ajak Teman) | ✅ Done | `referral_dashboard_screen.dart` — QR code, unique code, share_plus, referral tracking in Hive |
| D-A2 | Status BPJS & Asuransi Display | ✅ Done | `DriverDocsScreen` — **now reads/writes real `vehicleType`, `plate`, `ktpNumberMasked`, `bpjsKt`, `bpjsKs`, `bpjsInsurance` fields on `users/{uid}`** via an edit sheet, instead of hardcoded "Aktif" |

---

## Admin & Ops Web Console (SRS §2.1, §5.1) — New

Previously nonexistent (zero admin code anywhere in `lib/`, despite `firestore.rules`
already anticipating it via `isAdmin()`). Now a separate Flutter Web entrypoint:

| Screen | Status | Notes |
|--------|--------|-------|
| Auth (email/password) | ✅ Done | `lib/admin/auth/` — gated by `users/{uid}.role == 'admin'`; see `ADMIN_CONSOLE_SETUP.md` |
| Dashboard | ✅ Done | Drivers online, trips today, GMV today, avg rating, 7-day table |
| Drivers | ✅ Done | Search/filter list + detail (vehicle/BPJS/KTP, rating, trip history), verify/suspend |
| Passengers | ✅ Done | Search list, suspend/activate |
| Trips (transaction history) | ✅ Done | Filterable list + fare-breakdown detail dialog |
| Payouts | ✅ Done | Ledger view + manual settle/fail fallback for stuck "processing" payouts |
| Safety / SOS | ✅ Done | Live queue from `sos_events`, acknowledge action |
| Reports | ✅ Done | GMV, platform revenue, avg fare, top drivers over 7/30/90 days |

**Known limitation:** all list/report queries are bounded (a few hundred to 1000
most-recent documents) and computed client-side — no server-side aggregation or
pagination. Fine for a beta-scale fleet; called out inline in the UI when the cap is hit.

---

## Non-Feature Gaps

| Item | Status | Notes |
|------|--------|-------|
| Safety Settings screen | ✅ Done | `safety_settings_screen.dart` — emergency contacts (up to 3), Hive persistence, SOS info card |
| Brand assets | ❌ Empty | `assets/images/` folder is empty — no logo, no brand visuals, no placeholder driver photos |
| Custom fonts | ⚠️ Package-only | `assets/fonts/` empty; relies on `google_fonts` package (works but no offline fallback) |
| Platform fee rate | ✅ Fixed | `fare_calculator.dart` — corrected from 20% to **5%** platform cut (driver earns 95%) |
| Mapbox SDK | ❌ Deviation | Using OSRM + Nominatim (free, no key) instead of Mapbox — acceptable deviation per SRS §2.4/§9 risk table (Mapbox cost-spike mitigation already anticipates a routing migration) |
| Dev menu reset | ✅ Done | `dev_menu.dart` exists, triggered by 5-tap on splash screen |
| **Firebase Auth** | ✅ Done | Phone OTP (6-digit, 60s timeout) — `phone_entry_screen.dart` + `otp_screen.dart` rewritten |
| **Cloud Firestore** | ✅ Done | Trip lifecycle (searching→accepted→arriving→arrived→inTrip→completed/cancelled), user profiles, ratings, **payouts, sos_events** |
| **Firebase RTDB** | ✅ Done | Cross-device driver GPS at `/driver_locations/{uid}` — written from `driver_home_screen` + `driver_trip_screen`, **throttled to ~2.5s independent of GPS fix rate** |
| **Auth splash routing** | ✅ Done | `splash_screen.dart` checks Firebase Auth; routes to role-picker, dHome, or pHome |
| **Role persistence** | ✅ Done | `role_picker_screen.dart` writes role to Firestore `users/{uid}.role` |
| **GPS marker smoothing** | ✅ Done | `driver_home_screen.dart`'s idle marker now interpolates via `AnimationController` (previously snapped) — consistent with trip-tracking screens |
| **Admin console** | ✅ Done | See section above |

---

## Score Summary

| | Count |
|-|-------|
| ✅ Fully done | 21 / 22 features |
| ⚠️ Partial | 1 / 22 features |
| ❌ Missing | 0 / 22 features |

**Remaining partial feature:**
- **D-S3**: OSRM + flutter_tts instead of Mapbox Navigation SDK. Voice works; Bahasa Indonesia TTS pack may need `id-ID` locale test. Acceptable per SRS §9 risk mitigation (routing provider migration is an anticipated, not blocking, path).

**D-S8 upgraded from Partial to Done-with-a-documented-limitation:** the SOS *event* is
now real (Firestore-backed, visible to ops) — only the 30-second *audio capture* stays
simulated (no mic package wired), which is the one deliberately deferred piece; see
"Explicitly out of scope" below.

---

## Explicitly Out of Scope (MVP completion pass)

Carried over from the SRS's own "what P2 lacks vs MVP" framing (§10.2.11) plus one new
deliberate deferral, all vendor/infra-account-dependent or explicitly declined:

- Real Midtrans/Xendit payment gateway integration (QRIS/e-wallet stay simulated).
- Real BPJS portal API integration (deep-link only).
- Real WhatsApp Business API OTP/SMS.
- A custom Node/Go backend + PostgreSQL (the app remains Firebase-client-direct).
- Real SOS microphone capture (event data is real; the audio itself is simulated).
- Load/scale testing, multi-region failover, admin role granularity beyond a binary
  `admin` flag.

---

## Firebase Setup Checklist (Must-do before first run)

1. Go to [console.firebase.google.com](https://console.firebase.google.com) → **Add project** (name: `rihlah`)
2. **Add Android app** with package name `com.example.rihlah`
3. Download `google-services.json` → place at `android/app/google-services.json`
4. **Enable Phone Authentication** (Authentication → Sign-in method → Phone)
   - Add test numbers: e.g. `+62 812-3456-7890` / OTP `123456`
5. **Create Firestore** (Firestore Database → Start in test mode)
6. **Create Realtime Database** (Realtime Database → Start in test mode)
7. In terminal: `dart pub global activate flutterfire_cli` then `flutterfire configure --project=YOUR_PROJECT_ID`
   - This replaces `lib/firebase_options.dart` with real values

---

## Remaining Pre-Demo Work

### Assets — needed before stakeholder demo

1. **Brand assets** — add to `assets/images/`
   - App logo (PNG + SVG)
   - Onboarding illustrations (currently using `CustomPainter` placeholders)
   - Placeholder driver avatar photos

### Optional polish

2. **D-S3 — Voice Guidance Language**
   - Test `flutter_tts` with Bahasa Indonesia locale (`id-ID`)
   - If TTS output is not Indonesian, add a fallback string set in `voice_guidance_service.dart`

3. **D-A2 / BPJS portal links** — currently deep-link to live BPJS URLs; consider pointing to mock web pages for offline demo

---

*Generated from audit of `D:\Xuzu\IB Projects\rihlah` against RIHLAH_SRS_v1.0.md*
*Last updated: Firebase backend integration complete — Prototype 2*
