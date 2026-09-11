SOFTWARE REQUIREMENTS SPECIFICATION

RIHLAH

Ride-Hailing Platform Indonesia

“Karena Setiap Perjalanan Bermakna”

Version 1.0 — MVP Scope

Document Type: Software Requirements Specification (IEEE 830 adapted)

Date: 2026

1. Introduction

## 1.1 Purpose

This Software Requirements Specification (SRS) describes the functional and non-functional requirements for RIHLAH, an Indonesian ride-hailing platform competing in the same market as Gojek, Grab, and InDrive. It covers the MVP scope (22 features) targeted for a Day-1 launch in Bandung, West Java, with subsequent expansion phases through v2.0.

The intended audience includes the founding engineering team, product managers, designers, QA engineers, investors, and external development partners.

## 1.2 Product Scope

RIHLAH is a two-sided marketplace mobile application connecting passengers with motorcycle (ojek) and car drivers in Indonesia. The platform differentiates itself through three structural moats:

Radical Transparency — every receipt shows platform fee (5%), driver share (95%), and side-by-side comparison vs Gojek and InDrive for the same trip.

Daily Driver Withdrawal — drivers cash out daily versus competitors’ weekly (Gojek) or T+3 (InDrive) cycles.

Community Trust Layer — drivers verified through real-world social networks (mosque councils, RT/RW, ojol associations) rather than purely algorithmic scoring.

## 1.3 Definitions, Acronyms, and Abbreviations

| Term | Definition |
| --- | --- |
| Ojek / Ojol | Motorcycle taxi (Indonesian); ojol = ojek online |
| Penumpang | Passenger (Indonesian) |
| Driver / Mitra | Driver / partner driver |
| MVP | Minimum Viable Product — the 22 features that must ship at launch |
| Tier S/A/B/C | Feature priority tiers: S=Mission Critical, A=High Value, B=Good to Have, C=Future Vision |
| KILLER | Differentiator feature designed to be screenshot-shared on WhatsApp/Instagram |
| Perpres 27/2026 | Indonesian Presidential Regulation requiring driver insurance and safety standards |
| BPJS | Indonesian state social security (Ketenagakerjaan = employment, Kesehatan = health) |
| QRIS | Quick Response Code Indonesian Standard — universal QR payment |
| E-wallet | Digital wallet (GoPay, OVO, DANA, ShopeePay) |
| Provincial Captain | Regional driver coordinator/leader in RIHLAH community structure |
| FCM | Firebase Cloud Messaging |
| ETA | Estimated Time of Arrival |
| SOS | Emergency safety button feature |

## 1.4 References

RIHLAH Feature Architecture & MVP Blueprint 2026 (internal document, 57 features)

IEEE Std 830-1998 — Recommended Practice for Software Requirements Specifications

Perpres 27/2026 — Indonesian regulation on online transport driver protection

Mapbox Navigation SDK documentation

Midtrans / Xendit payment gateway documentation

## 1.5 Overview

Section 2 presents the overall product description: actors, environment, constraints, and assumptions. Section 3 details functional requirements grouped by user role and feature ID. Section 4 specifies non-functional requirements (performance, security, regulatory, etc). Section 5 covers external interfaces. Section 6 describes the system architecture. Sections 7–9 cover data, deployment, and acceptance criteria.

2. Overall Description

## 2.1 Product Perspective

RIHLAH is a new, self-contained system. It consists of four major deployable components:

Passenger Mobile App (Android-first, iOS Phase 1)

Driver Mobile App (Android-first, iOS deferred)

Backend API & Realtime Services (matching engine, fare calculator, payment, notifications)

Admin & Operations Web Console (user/driver management, dispatch monitoring, payouts, fraud review)

## 2.2 Product Functions (Summary)

MVP (22 features) covers the core ride-hailing loop end-to-end:

Passenger: account, search/book a ride, see fare estimate, pay (cash/QRIS/e-wallet), track driver in real time, share trip, chat, rate, view history, SOS, save addresses.

Driver: account, go online/offline, accept/decline orders with transparent earnings, in-app navigation, see realtime earnings, daily payout, rate, view trip and earning history, SOS, refer drivers, BPJS status display.

Platform: matching/dispatch, fare calculation, payment processing, transparent receipt generation, comparison-vs-competitor calculation, push notifications, geofencing for service area.

## 2.3 User Classes and Characteristics

| User Class | Description | Tech Skill | Volume Target (Y1) |
| --- | --- | --- | --- |
| Passenger | End user booking rides. Mostly daily commuters in Bandung area, students, working professionals, women preferring female drivers. | Low to medium. Familiar with Gojek/Grab UX patterns. | 50,000 MAU |
| Driver (Mitra) | Motorcycle/car driver, often migrating from Gojek or InDrive. Indonesia-based, smartphone literate but often older Android devices. | Low to medium. Needs forgiving UX, large touch targets. | 5,000 active drivers |
| Admin / Ops | RIHLAH staff handling driver onboarding, fraud review, payouts, customer support. | High. Trained on internal tools. | 20–40 staff |
| Provincial Captain | Senior driver acting as community leader, dispute mediator, recruiter. | Medium. Receives bonus dashboards. | 20–50 captains |

## 2.4 Operating Environment

Mobile clients: Android 8.0+ (covers ~95% of Indonesian smartphones), iOS 14+ (Phase 1).

Backend: Cloud-hosted (recommend GCP Jakarta region for latency, with Singapore failover).

Database: PostgreSQL with PostGIS for geospatial queries; Redis for live driver positions; Firebase Realtime Database / Firestore for chat and live tracking streams.

Network: 3G/4G mobile internet (intermittent connectivity expected); offline tolerance required for the driver app.

## 2.5 Design and Implementation Constraints

Regulatory: Must comply with Perpres 27/2026 — driver insurance display, SOS button, trip data retention 30+ days.

Data residency: User PII and trip data stored in Indonesia or ASEAN region per UU PDP (Indonesian Personal Data Protection Law).

Languages: Bahasa Indonesia primary; English secondary for admin tools.

Currency & timezone: IDR (Indonesian Rupiah), Asia/Jakarta (WIB, UTC+7) primary; Asia/Makassar (WITA, UTC+8) and Asia/Jayapura (WIT, UTC+9) supported.

Map provider: Mapbox (per source document) — used for tiles, navigation SDK, and distance/matrix API. Routing algorithm cannot be customized; if motorcycle-specific routing becomes critical, plan to migrate routing service to GraphHopper or Valhalla self-hosted.

Payment: Indonesian payment rails — QRIS mandatory, GoPay/OVO/DANA/ShopeePay via Midtrans or Xendit aggregator, cash as default.

Team & timeline: 2 engineers, 2–3 month MVP window.

## 2.6 Assumptions and Dependencies

Mapbox SDK and APIs remain available at expected pricing through 2026.

Midtrans or Xendit completes KYB onboarding for the operating entity within 30 days.

Driver acquisition partner (community/koperasi) supplies first 200 drivers via existing network.

Bandung Kota and Cimahi are launch cities; service area expansion is out of MVP scope.

3. Functional Requirements

Each feature is uniquely identified using the original feature codes (P-S1, D-S1, etc.). Codes prefixed with P = passenger features; D = driver features. S = Tier S (mission critical), A = Tier A (high value).

## 3.1 Passenger Functional Requirements (MVP — 11 features)

P-S1 — Booking Flow Lengkap

Priority: S / Easy / MVP

Description: Allow a passenger to book a ride end-to-end: select pickup and destination, choose service tier, see fare estimate, confirm, get matched with a driver.

Inputs: Pickup point (GPS or pin or saved address); destination (search, pin, or saved); service type (Motor, Mobil, Kurir); payment method.

Process: System geocodes locations → calculates distance and fare → searches for drivers within radius (start 1.5 km, expand to 5 km) → sends order to top-ranked driver → 15 second timeout → cascades to next driver.

Outputs: Booking confirmation with driver name, photo, vehicle plate, ETA, and live tracking link.

Business Rules:

Pickup must be inside the service area polygon (Bandung Kota + Cimahi for MVP).

Maximum trip distance 50 km for motorcycle, 100 km for car.

If no driver accepts within 90 seconds total, show 'No drivers available' and refund any held funds.

P-S2 — Transparent Receipt [KILLER]

Priority: S / Easy / MVP

Description: After every completed trip, generate a shareable receipt showing total fare, exact amount to driver (95%), platform fee (5%), and a competitor comparison.

Inputs: Completed trip record (distance, duration, fare, surge factor=0).

Process: Calculate driver share = fare × 0.95. Platform fee = fare × 0.05. Look up calibrated Gojek/InDrive fare for same distance/time and display side-by-side delta. Render a styled receipt image (PNG, square 1080×1080) optimized for WhatsApp/Instagram Stories.

Outputs: Visual receipt + plain-text receipt + share intent (WhatsApp, IG, copy-to-clipboard).

Business Rules:

Competitor fare estimates use a published, dated formula and must show 'Estimasi' label for legal safety.

Receipt must be regeneratable from trip history at any time.

P-S3 — Live Tracking + ETA

Priority: S / Med / MVP

Description: Show the driver's real-time position on a map, ETA, and trip status (Driver on way → Arrived → On trip → Done).

Inputs: Driver GPS stream (every 3–5 s when active), trip status events.

Process: Driver app pushes location to Firebase Realtime DB (or equivalent). Passenger app subscribes. Map view interpolates positions for smoothness. ETA recalculated every 30 s using Mapbox Directions API.

Outputs: Map view with moving driver marker, status banner, audible chime on status change.

Business Rules:

Position update frequency reduces to 10 s when battery saver detected.

If GPS lost > 60 s, show 'Connection lost — last seen 30 s ago' state.

P-S4 — Fare Estimate Sebelum Booking

Priority: S / Easy / MVP

Description: Show calculated fare before the passenger confirms a booking, with a comparison vs Gojek and InDrive.

Inputs: Pickup, destination, service type, time of day.

Process: Use Mapbox Directions to compute distance and duration → apply RIHLAH fare formula (base + perKm × distance + perMin × duration) → compare to competitor formula.

Outputs: Estimated fare in IDR (rounded to nearest 500), low–high range ±10%, competitor delta.

Business Rules:

No surge multiplier in MVP — RIHLAH explicitly markets 'no surge'.

Fare formula version must be stored in trip record for auditability.

P-S5 — Payment — Cash + E-wallet

Priority: S / Med / MVP

Description: Support cash (default), QRIS, and major e-wallets (GoPay, OVO, DANA, ShopeePay).

Inputs: Selected method at booking; for QRIS/e-wallet, transaction completion callback from gateway.

Process: Cash → no online action; driver confirms cash receipt at trip end. QRIS → generate dynamic QR via Midtrans/Xendit; passenger scans; webhook updates trip to Paid. E-wallet → deeplink to wallet app for approval.

Outputs: Payment status (Pending, Paid, Failed) on trip record; receipt updated.

Business Rules:

A trip cannot be marked Completed unless payment status is Paid (e-wallet/QRIS) or Cash-Confirmed.

All payment events logged with idempotency key for reconciliation.

P-S6 — Rating & Review Driver

Priority: S / Easy / MVP

Description: Passenger rates driver 1–5 stars and selects optional category tags (Sopan, Tepat waktu, Jalan aman, Kendaraan bersih) plus free-text comment.

Inputs: Star rating (required), category tags (multi-select), comment (optional, ≤ 280 chars).

Process: Persist to driver profile; recompute rolling 30-day and lifetime average; if rating < 3, route to support review queue.

Outputs: Updated driver rating; thank-you screen.

Business Rules:

Passenger can rate up to 7 days after trip completion.

Passenger cannot book the same driver again if they last rated 1 star (auto-prefer different driver).

P-S7 — Emergency SOS Button

Priority: S / Easy / MVP

Description: One-tap button during a trip that sends location and trip details to pre-saved emergency contacts and to RIHLAH ops.

Inputs: SOS tap with optional confirmation (3-second hold to prevent accidental).

Process: Capture current GPS, trip ID, driver ID, vehicle plate. Send SMS/WhatsApp to up to 3 emergency contacts. Notify RIHLAH ops dashboard with red alert. Log full event with audio metadata.

Outputs: Confirmation screen 'Bantuan dikirim'. Live link for contacts to follow trip.

Business Rules:

Required by Perpres 27/2026.
    
Must work even with poor connectivity — queue and retry SMS sending.

P-S8 — Trip History & Riwayat

Priority: S / Easy / MVP

Description: List all trips (paginated) with full details and PDF export for office reimbursement.

Inputs: User ID; optional date range filter.

Process: Query trips table; render list with date, route, fare, driver, status. PDF export uses templated layout with company-friendly format.

Outputs: Trip list view; PDF download.

Business Rules:

Re-order from history must respect current pricing and availability, not historical.

P-A1 — Saved Addresses

Priority: A / Easy / MVP

Description: Save Home, Office, and up to 8 custom labeled addresses for one-tap selection.

Inputs: Address (search or pin), label.

Process: Persist per-user; auto-suggest in pickup/destination fields.

Outputs: List of saved addresses; quick-select chips on home screen.

Business Rules:

Maximum 10 saved addresses per user.

P-A2 — In-App Chat dengan Driver

Priority: A / Easy / MVP

Description: Real-time chat between passenger and driver during pickup phase, with phone numbers masked.

Inputs: Text message ≤ 500 chars; optional quick-replies ('Saya di pintu depan').

Process: Firebase Cloud Messaging + Firestore for messages. Auto-purge messages 7 days after trip end.

Outputs: Chat thread; push notification to recipient.

Business Rules:

Phone numbers in chat are auto-redacted to discourage off-platform contact.

Quick-reply templates available in Bahasa Indonesia.

P-A3 — Share Trip Live ke Keluarga

Priority: A / Easy / MVP

Description: Generate a public, time-limited tracking link viewable in any browser without app install.

Inputs: Trip ID; share intent.

Process: Generate signed URL with trip token; web view shows minimal map, driver name (first name only), plate, ETA. Auto-expire 1 h after trip completion.

Outputs: Shareable link, default share target WhatsApp.

Business Rules:

Link does not expose passenger PII.

Link revoked immediately if trip is canceled or SOS triggered.

## 3.2 Driver Functional Requirements (MVP — 11 features)

D-S1 — Online / Offline Toggle

Priority: S / Easy / MVP

Description: Single large toggle to enter/exit dispatch eligibility, synced realtime to backend.

Inputs: Toggle tap.

Process: Update driver status in Firebase + Redis live presence. Apply anti-abuse cooldown (max 3 toggles in 5 minutes).

Outputs: Visual state change; status indicator on dashboard.

Business Rules:

Auto-set Offline if app backgrounded > 30 minutes or GPS lost > 5 minutes.

Cannot go Online if BPJS status is invalid for > 30 days (warning only in MVP).

D-S2 — Order Request + Accept/Decline

Priority: S / Easy / MVP

Description: Notify driver of incoming order with full transparent breakdown of what they will earn (not just total fare).

Inputs: New order event; driver tap on Accept or Decline.

Process: Push notification + in-app overlay shows: distance to pickup, distance of trip, estimated trip duration, exact rupiah amount driver receives (after platform fee). 15-second countdown then auto-decline.

Outputs: If accepted: navigate to pickup. If declined or timeout: order routed to next driver.

Business Rules:

Driver accept rate is tracked; < 50% acceptance over 50 orders triggers ops review.

Auto-decline never counts as a manual decline.

D-S3 — Navigasi Mapbox Turn-by-Turn

Priority: S / Med / MVP

Description: In-app turn-by-turn navigation with Bahasa Indonesia voice guidance.

Inputs: Pickup or destination coordinates.

Process: Mapbox Navigation SDK Android (and iOS) with Bahasa Indonesia voice pack. Route deviations recalculated automatically.

Outputs: Map with route overlay, voice prompts, ETA.

Business Rules:

Offline map tiles cached for service area (Bandung Kota + Cimahi).

If Navigation SDK fails, fall back to deeplink to Google Maps with logged event.

D-S4 — Earnings Dashboard Realtime

Priority: S / Easy / MVP

Description: Show today / this week / this month earnings, trip count, average per trip, and progress toward driver-set daily target.

Inputs: User-set daily target (default Rp 200,000).

Process: Aggregate trips collection; display widgets refresh on each completed trip.

Outputs: Dashboard with progress bar; mini chart of last 7 days.

Business Rules:

All numbers exclude tips for transparency; tips shown separately.

D-S5 — Per-Trip Breakdown [KILLER]

Priority: S / Easy / MVP

Description: Per-completed-trip popup with exact rupiah received vs Gojek and InDrive estimates for the same trip.

Inputs: Trip completed event.

Process: Calculate driver share, platform fee, and competitor reference numbers using shared fare module from P-S2.

Outputs: Sharable image (driver receipt); WhatsApp share button prominent.

Business Rules:

Same fare/competitor formula version as passenger receipt for consistency.

Image template visually optimized for WhatsApp group sharing.

D-S6 — Daily Withdrawal (Penarikan Harian)

Priority: S / Med / MVP

Description: Driver can withdraw earnings to bank account or e-wallet daily (vs Gojek's weekly).

Inputs: Withdraw request with destination account.

Process: Validate balance ≥ Rp 20,000 minimum. First withdrawal of the day free; subsequent Rp 1,000 fee. Disburse via Xendit/Midtrans payout API. Update driver balance with idempotency key.

Outputs: Confirmation; payout status (Processing → Success/Failed) push notification.

Business Rules:

Withdrawal cutoff times by destination bank (BI-FAST 24/7, others may have cut-offs).

Failed payouts auto-refund to driver balance within 1 business day.

D-S7 — Rating & Review Display

Priority: S / Easy / MVP

Description: Show driver's average rating, breakdown by category, 30-day trend, and frequently-praised tags.

Inputs: Driver profile view.

Process: Aggregate from rating events; display chart and category counts.

Outputs: Rating dashboard; alerts if rating drops below 4.5.

Business Rules:

Drivers cannot see individual passenger names attached to ratings (privacy).

D-S8 — Emergency SOS Driver

Priority: S / Easy / MVP

Description: Driver SOS that captures location + 30 s audio + notifies emergency contacts and Provincial Captain.

Inputs: Long-press SOS button (3 s).

Process: Record audio to local storage and upload to secure bucket. Send notification with full trip context to RIHLAH ops, emergency contacts, and assigned Provincial Captain.

Outputs: Confirmation; ops dashboard high-priority alert.

Business Rules:

Audio retained 90 days then deleted unless flagged.

Required by Perpres 27/2026.

D-S9 — Trip History + Riwayat Pendapatan

Priority: S / Easy / MVP

Description: Full trip history with route, fare, commission, plus PDF/CSV monthly export for tax or cooperative loan applications.

Inputs: Date range; export format.

Process: Generate PDF/CSV from trip records. PDF includes summary table and totals.

Outputs: Downloadable file.

Business Rules:

Passenger names are anonymized in exports.

D-A1 — Referral Driver (Ajak Teman)

Priority: A / Easy / MVP

Description: Driver shares unique code; new driver who completes 20 trips in first month earns referrer Rp 15,000–30,000.

Inputs: Referral code at new driver signup.

Process: Track referral chain; trigger payout when milestone met.

Outputs: Referral dashboard with status of each invitee.

Business Rules:

One referrer per new driver; first claim wins.

D-A2 — Status BPJS & Asuransi Display

Priority: A / Easy / MVP

Description: Display status of BPJS Ketenagakerjaan, BPJS Kesehatan, and Perpres 27/2026 accident insurance with deep links to enrollment.

Inputs: Driver-uploaded BPJS numbers; insurance partner status feed.

Process: Validate format; show Active/Expired/Not Registered. Reminder push 14 days before expiry.

Outputs: Compliance card on driver home; deep link to BPJS portal.

Business Rules:

MVP scope: display only; no automatic enrollment yet.

4. Non-Functional Requirements

## 4.1 Performance

Driver match latency: median ≤ 4 s, p95 ≤ 8 s from booking to driver notification.

API response time: median ≤ 200 ms, p95 ≤ 600 ms for non-search endpoints.

Live location update latency: median ≤ 2 s end-to-end.

App cold start ≤ 3 s on a Xiaomi Redmi 9 (representative low-mid Android).

Concurrent users at MVP launch: 1,000 passengers + 500 drivers online simultaneously.

## 4.2 Reliability & Availability

Target uptime 99.5% in MVP, 99.9% from v1.0 onward.

RPO (data loss tolerance) ≤ 5 minutes for trip and payment data.

RTO (recovery time) ≤ 30 minutes for full service restoration.

Driver app must continue trip locally if backend unreachable up to 10 minutes; sync on reconnection.

## 4.3 Security

All transport over TLS 1.2+.

Authentication via OTP (SMS or WhatsApp Business API). Session tokens via JWT, 30-day refresh, 1-hour access.

PII encryption at rest (AES-256) — full names, phone numbers, KTP numbers, bank details.

Payment data tokenized via PCI-DSS-compliant gateway (Midtrans or Xendit); RIHLAH never stores card data.

Rate limiting on all auth and payment endpoints (e.g., 5 OTP/hour/phone).

Admin actions logged in immutable audit trail (append-only).

## 4.4 Privacy & Data Protection

Compliant with UU PDP (Indonesian Personal Data Protection Law) — explicit consent for location, contacts, notifications.

Data residency: primary storage in Indonesia (GCP Jakarta) or ASEAN.

Right to delete: user can request account deletion; trip history anonymized but retained 7 years for tax/regulation.

Trip data retained 30 days minimum (Perpres 27/2026).

## 4.5 Regulatory Compliance

Perpres 27/2026: SOS, BPJS display, accident insurance enrollment path, audio capture during emergency.

UU ITE & UU PDP: data handling and consent.

Bank Indonesia QRIS standards for QR payments.

Pajak (PPh 23): 2% withholding on driver income; platform issues bukti potong via export.

## 4.6 Localization & Accessibility

Bahasa Indonesia primary; all user-facing strings externalized in i18n bundles.

Currency formatting: Rp 1.500 (period thousands separator).

Date format: DD MMM YYYY (e.g., 8 Mei 2026).

Touch targets ≥ 48 dp; supports system text scaling up to 130%.

Color contrast WCAG AA minimum.

## 4.7 Maintainability & Observability

Centralized logging (e.g., Sentry + GCP Cloud Logging).

Distributed tracing for booking flow and payment flow (OpenTelemetry).

Crash-free session rate ≥ 99.5% (Firebase Crashlytics).

Feature flags for staged rollout (e.g., LaunchDarkly or self-hosted).

CI/CD: trunk-based, automated tests gating merge, weekly release cadence with hotfix path.

5. External Interface Requirements

## 5.1 User Interfaces

Passenger App: Bottom-tab nav (Beranda, Riwayat, Promo, Akun). Booking flow as a single sheet from home.

Driver App: Single primary screen — large Online toggle, earnings widgets, incoming order overlay.

Admin Console: Web dashboard with role-based access (Super Admin, Ops, Finance, Captain).

## 5.2 Hardware Interfaces

GPS / Fused Location Provider on Android; Core Location on iOS.

Camera (driver KYC document upload, vehicle photo).

Microphone (SOS audio capture, voice features in v2).

Push notification services: FCM (Android), APNS (iOS).

## 5.3 Software Interfaces (External Services)

| Service | Purpose | Protocol | Notes |
| --- | --- | --- | --- |
| Mapbox Maps + Navigation SDK | Tiles, turn-by-turn nav, geocoding | REST + native SDK | Plan migration path to GraphHopper if motorcycle routing needed |
| Mapbox Directions + Matrix API | Route, ETA, distance for fare | REST | Cache hot routes for cost control |
| Midtrans / Xendit | QRIS, e-wallet, payouts | REST + Webhooks | Choose one; both supported by spec |
| Firebase Cloud Messaging | Push notifications | FCM API | — |
| Firebase Realtime DB / Firestore | Live driver positions, chat | Firebase SDK | Cost grows with active drivers; plan migration to Redis pub/sub at scale |
| WhatsApp Business API (or Twilio) | OTP, SOS notifications, share links | REST | Required for Indonesia OTP cost optimization |
| BPJS Ketenagakerjaan portal | Status display (deep link only in MVP) | Deep link | API integration deferred |
| Sentry + Crashlytics | Crash & error reporting | SDK | — |

## 5.4 Communication Interfaces

REST/JSON over HTTPS for all client–server APIs.

WebSocket or Firebase Realtime for live tracking and chat.

Webhooks (signed) from payment gateways for transaction state.

6. System Architecture (Reference)

## 6.1 Recommended Stack

Mobile (Passenger + Driver): Flutter (single codebase, Android-first) OR React Native if existing JS team. Native Android (Kotlin) acceptable if iOS deferred.

Backend: Node.js (NestJS) or Go (Gin) — choose Node.js for faster MVP if team is JS-strong; Go for performance if scaling beyond 5k drivers.

Database: PostgreSQL 15 + PostGIS extension for geospatial queries (driver search radius, service area polygon).

Live state: Redis 7 (driver positions, presence, rate limiting).

Realtime to clients: Firebase Realtime Database (MVP simplicity) → migrate to self-hosted WebSocket cluster at scale.

File storage: Google Cloud Storage (driver KYC, SOS audio, receipt images).

CI/CD: GitHub Actions → GCP Cloud Run (backend) + Play Store / TestFlight.

Monitoring: Sentry (errors), Grafana + Prometheus (infra), Mixpanel or Amplitude (product analytics).

## 6.2 High-Level Component Diagram (textual)

Passenger App ⇄ API Gateway ⇄ Booking Service ⇄ Matching Engine ⇄ Driver App

Booking Service writes to PostgreSQL (trips, users, drivers) and publishes events to Redis Streams.

Live Location Service reads driver GPS from Driver App via Firebase, fans out to Passenger App live trackers.

Payment Service integrates with Midtrans/Xendit, handles webhooks, updates trip state, triggers payout queue.

Receipt Service generates transparent receipt images using a server-side Canvas/Skia renderer.

Notification Service abstracts FCM, APNS, WhatsApp, SMS.

## 6.3 Matching / Dispatch Algorithm (MVP)

Spatial query: drivers Online within radius_step (1.5 km, 3 km, 5 km, 8 km) ordered by composite score.

Composite score = w1·proximity + w2·rating + w3·acceptance_rate + w4·trips_today_inverse (to spread orders).

Send to top-1 driver, 15-s timeout, cascade to next. Total budget 90 s.

Smart Dispatch (D-A7) replaces this in v1.5 with ML-driven score.

7. Data Model (MVP Core Entities)

| Entity | Key Fields | Notes |
| --- | --- | --- |
| users | id, phone, name, email?, photo_url, created_at | Passengers and drivers share auth but have separate profile tables. |
| passengers | user_id, default_payment, saved_addresses[], emergency_contacts[] | 1:1 with users. |
| drivers | user_id, ktp_number_enc, vehicle_type, plate, photo, rating_avg, status, online_at, last_lat, last_lng, bpjs_* | 1:1 with users. |
| trips | id, passenger_id, driver_id, pickup, dropoff, distance_m, duration_s, fare_idr, driver_share_idr, status, fare_formula_version, created_at, completed_at | Core ledger; immutable once Completed. |
| payments | id, trip_id, method, amount_idr, gateway_ref, status, idempotency_key, created_at | — |
| payouts | id, driver_id, amount_idr, destination, gateway_ref, status, requested_at, paid_at | — |
| ratings | id, trip_id, by_user_id, target_user_id, stars, tags[], comment, created_at | — |
| sos_events | id, trip_id, by_user_id, lat, lng, audio_url?, contacts_notified[], created_at | — |
| fare_formulas | version, base_idr, per_km_idr, per_min_idr, valid_from | Versioned for auditability. |
| service_area_polygons | id, name, geojson, active | Bandung Kota, Cimahi for MVP. |

8. Acceptance Criteria & Test Strategy

## 8.1 MVP Definition of Done

All 22 MVP features pass acceptance tests (per-feature in Section 3).

End-to-end happy path: passenger books → driver accepts → trip completes → payment succeeds → both rate → receipt is shareable. < 5 min total in test environment.

Load test: 200 concurrent bookings/min sustained for 10 minutes with no errors above 0.5%.

Security: OWASP Mobile Top 10 review passed; no Critical or High findings.

Crash-free rate ≥ 99.5% on internal beta (50 drivers, 200 passengers).

## 8.2 Test Levels

Unit tests on backend services — coverage target 70%+ on fare, payment, matching modules.

Integration tests on booking + payment + payout flow with sandbox gateway.

E2E mobile tests via Maestro or Detox on critical flows.

Manual exploratory testing in Bandung with 20 internal beta drivers.

Pre-launch dogfooding 2 weeks with founders + ops team using real money.

## 8.3 Out-of-Scope (MVP)

iOS app (planned Phase 1 month 4-6).

Surge pricing — explicitly excluded from product strategy.

Group bookings, voice booking, AURUM savings, AI-powered features (planned Phase 2/3).

Multi-city expansion beyond Bandung Kota + Cimahi.

RIHLAH FOOD (Phase 3).

9. Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
| --- | --- | --- | --- |
| Mapbox cost spike at scale | High | Medium | Cache hot routes; plan migration path to GraphHopper for routing/matrix APIs in Phase 1. |
| Driver supply too low at launch | High | High | Pre-onboard 200 drivers via existing community partner before launch; bonus structure first 90 days. |
| Payment gateway KYB delay | High | Medium | Apply to both Midtrans and Xendit in parallel; cash-only soft launch as fallback. |
| GPS accuracy in dense urban Bandung | Medium | High | Use fused location provider; UI tolerant of pickup pin adjustments. |
| Regulatory change (Perpres updates) | High | Medium | Compliance officer on retainer; feature flags for fast policy changes. |
| Competitor undercutting | Medium | High | Moat is structural (transparency, daily payout) — cannot be matched without breaking competitor unit economics. |
| Fraud (fake bookings, GPS spoofing) | High | Medium | Manual review queue in MVP; AI fraud detection (D-B4) in Phase 2. |
| Two-engineer team capacity overrun | High | Medium | Strict MVP scope; defer all Tier B and C features; consider third contractor for navigation SDK integration. |

10. Prototype Tracks (Pre-MVP)

Two pre-MVP prototype tracks are introduced to de-risk product, design, and engineering decisions before committing to the full MVP build. Both tracks deliver the same 22 features that comprise the MVP, but with progressively more backend complexity. Work done in Prototype 1 (UI-only Flutter) is reused in Prototype 2 (Flutter + Firebase) and again in the MVP — only the data and service layers are swapped.

Prototype 1 (P1) is a UI-only Flutter app with no backend. All data is mocked locally. Its purpose is to validate UX, gather stakeholder buy-in, and iterate flows without infrastructure cost. Timeline: 2–3 weeks for one or two developers.

Prototype 2 (P2) is a Flutter front-end with Firebase as the entire backend (Authentication, Firestore, Realtime Database, Cloud Storage, Cloud Functions, FCM). There is no custom server. Its purpose is to demonstrate real end-to-end behavior with internal beta drivers and passengers on separate devices, support investor demos, and validate the matching and dispatch loop. Timeline: 4–6 weeks for two developers.

Both prototypes deliberately defer real payment integration (sandbox/stubs only) and real telco SMS OTP. Firebase Phone Auth handles SMS in P2; P1 mocks OTP entirely.

## 10.1 Prototype 1 — UI-Only Flutter (No Backend)

### 10.1.1 Goal

A click-through prototype that runs offline. Every screen renders with realistic but mocked data. Stakeholders can experience the full passenger and driver flow without any server dependency. Mock data is bundled in app assets and a local SQLite/Hive store. The prototype must look and feel like the real product so that user testing is meaningful.

### 10.1.2 Scope — Features Implemented (UI-Only)

All 22 MVP features are present as fully rendered screens with mocked behavior. Passenger features:

P-S1 Booking Flow — pickup and destination picker, service tier selection, fare confirmation; mocked driver match with a simulated 5–8 s delay.

P-S2 Transparent Receipt [KILLER] — fully rendered with hardcoded competitor fare lookup table; share-to-WhatsApp via the share_plus package.

P-S3 Live Tracking — animated driver marker following a predefined polyline; ETA countdown timer.

P-S4 Fare Estimate — local fare calculator using the documented formula (base + perKm × distance + perMin × duration).

P-S5 Payment — UI only; all methods (cash, QRIS, GoPay, OVO, DANA, ShopeePay) show success after a 2-second fake processing animation.

P-S6 Rating — UI works; data is discarded on app restart.

P-S7 SOS — UI only; shows "Bantuan dikirim" confirmation without actually sending anything.

P-S8 Trip History — list seeded from local JSON; PDF export uses the pdf package locally.

P-A1 Saved Addresses — SharedPreferences persistence; Home, Office, and custom labels.

P-A2 In-App Chat — local message echo only; quick-reply chips functional.

P-A3 Share Trip — copy-to-clipboard with a fake tracking URL.

Driver features:

D-S1 Online/Offline Toggle — local state only; no real backend signal.

D-S2 Order Request — triggered manually via a debug menu; full breakdown UI showing exact rupiah received.

D-S3 Mapbox Navigation — the Mapbox Navigation SDK can be used standalone with a free public API key, or fall back to flutter_map with OSM tiles and a static polyline.

D-S4 Earnings Dashboard — calculated from local trip JSON; daily-target setter functional.

D-S5 Per-Trip Breakdown [KILLER] — same renderer as P-S2 with driver perspective.

D-S6 Daily Withdrawal — UI only; "processing" animation transitions to "success" after 3 s.

D-S7 Rating Display — static mock data showing 4.8 average and category breakdown chart.

D-S8 Emergency SOS Driver — UI only; mock recording animation.

D-S9 Trip History + Riwayat Pendapatan — local JSON; CSV/PDF export via local rendering.

D-A1 Referral — UI only with QR code generation via qr_flutter.

D-A2 BPJS Status Display — hardcoded "Aktif" state with a mocked deep link.

### 10.1.3 Tech Stack

Flutter 3.x (Android-first; iOS optional).

State management: Riverpod (recommended) or Provider.

Routing: go_router.

Local storage: shared_preferences for settings; Hive or sqflite for mock trip data.

Maps: flutter_map with OpenStreetMap tiles (no API key, cheapest path), or the Mapbox SDK if exact production parity is needed.

Mocked data: JSON files bundled in /assets/mock/.

Fake network delay: Future.delayed wrapper in the repository layer (simulate 200 ms – 8 s based on operation).

Animations: Lottie for SOS, success states, loading spinners.

Sharing: share_plus, screenshot packages.

PDF: pdf and printing packages.

### 10.1.4 Recommended Project Structure

lib/

├── core/ theme, localization (id/en), formatters, constants

├── data/ repositories (Mock*), models (freezed), mock JSON loaders

├── features/

│ ├── auth/ OTP screens (mocked, always succeeds)

│ ├── passenger/ booking, tracking, receipt, history, addresses, chat

│ ├── driver/ dashboard, order_request, earnings, withdrawal, history

│ └── shared/ sos, rating, profile

└── main.dart

assets/

├── mock/ trips.json, drivers.json, addresses.json, competitor_fares.json

├── images/ brand assets, mock driver photos

└── lottie/ sos.json, success.json, loading.json

### 10.1.5 Mocking Approach

All repositories implement a Dart interface (e.g., TripRepository). The mock implementation loads seed data from /assets/mock/trips.json at startup, holds state in memory (lost on app restart unless persisted to Hive), wraps every operation in a Future.delayed of 200–800 ms to simulate network latency, and randomly throws a simulated network error with 5% probability to exercise error states.

For the multi-step booking flow, a MockDispatchService runs a state machine on a Timer: at T+0 s "Searching for driver", T+2 s "Driver found — Pak Ahmad", T+4 s "Driver on the way" with polyline animation starting, T+30 s "Driver arrived", T+33 s "On trip" with route progress animation, T+60 s "Trip complete" transitioning to the receipt screen. The same MockDispatchService drives both the passenger live-tracking screen and the driver app's order-request notification, so a single device can demo both perspectives.

### 10.1.6 Acceptance Criteria for P1

All 22 MVP screens are reachable and visually polished.

Passenger end-to-end happy path demo-able in under 3 minutes.

Driver end-to-end happy path demo-able in under 3 minutes.

App runs on an Android emulator and a physical low-mid device (e.g., Redmi 9) without internet after first launch.

Mock data resets to a clean state via a hidden dev menu.

No real PII; no real phone numbers; all driver photos and names are placeholders.

All Indonesian-language strings reviewed by a native speaker.

Brand identity (colors, logo, typography) applied consistently.

### 10.1.7 Out of Scope for P1

Real authentication (use any 6-digit OTP or a "skip" button).

Real or sandbox payment integration.

Persistent server-side data.

Cross-device flows (passenger on phone A interacting with driver on phone B).

Real GPS tracking — only animated polyline.

Real push notifications — in-app banners only.

iOS build (optional; Android-first).

### 10.1.8 3-Week Build Plan (1–2 Developers)

Week 1 — Foundations. Days 1–2: project bootstrap, theme system, localization, navigation skeleton. Days 3–4: mock auth flow (login, OTP, role selection). Day 5: home screens (passenger + driver), bottom navigation.

Week 2 — Core Flows. Days 6–7: passenger booking flow (pickup/destination picker, fare estimate). Day 8: live tracking animation (polyline-based). Day 9: transparent receipt rendering and share. Day 10: driver online toggle, mock order request, dashboard.

Week 3 — Polish and Edge Features. Days 11–12: SOS UI, in-app chat, share trip link. Day 13: trip history (passenger + driver), withdrawal flow. Day 14: referral, BPJS display, error states, dev menu. Day 15: final QA, animation polish, stakeholder demo.

## 10.2 Prototype 2 — Flutter + Firebase (No Custom Backend)

### 10.2.1 Goal

A functional end-to-end app where a passenger on one phone and a driver on another phone complete real trips against a Firebase backend. All backend concerns are delegated to Firebase. This prototype is suitable for an internal beta with 20–50 testers in Bandung and for investor demos using two physical phones.

### 10.2.2 Firebase Services Used

Firebase Authentication (Phone OTP) — real SMS to real Indonesian numbers; free quota in test mode.

Cloud Firestore — primary data store for users, drivers, trips, payments, ratings; multi-region (asia-southeast2 Jakarta).

Firebase Realtime Database — live driver GPS, online presence, order offers (chosen over Firestore for low-latency high-frequency updates).

Cloud Storage — driver KYC documents, SOS audio recordings, receipt PNG images.

Firebase Cloud Functions (Node.js or Python, 2nd generation) — server-side logic for matching, fare calculation, payout simulation, receipt rendering.

Firebase Cloud Messaging — push notifications to passenger and driver apps.

Firebase Crashlytics — crash reporting.

Firebase Analytics — product analytics, funnel tracking.

Firebase App Check — abuse prevention (Play Integrity for Android, DeviceCheck for iOS).

Firebase Remote Config — feature flags, fare formula tuning without app updates.

### 10.2.3 Architecture (Textual Diagram)

[Passenger App] ←→ Firebase Auth ←→ [Driver App]

│ │

└──────→ Cloud Firestore ←────────┘

(users, drivers, trips, payments, ratings)

│

Cloud Functions

- createBooking

- acceptOrder / declineOrder

- completeTrip

- requestWithdrawal

- renderReceipt

│

Realtime Database

/presence/drivers, /active_trips, /order_offers

│

Cloud Storage + FCM + Mapbox SDK (client-direct)

### 10.2.4 Firestore Schema

/users/{userId}

phone, name, photoUrl, role: "passenger" | "driver" | "both", createdAt

/passengers/{userId}

defaultPayment, savedAddresses[], emergencyContacts[]

/drivers/{userId}

ktpNumberEnc, vehicleType, plate, ratingAvg, status,

bpjsKt, bpjsKs, balanceIdr, online (bool)

/trips/{tripId}

passengerId, driverId, pickup {lat,lng,address}, dropoff {...},

distanceM, durationS, fareIdr, driverShareIdr,

status, fareFormulaVersion, createdAt, completedAt

/trips/{tripId}/events/{eventId} (subcollection)

type: "matched"|"arrived"|"started"|"completed", timestamp, data

/payments/{paymentId}

tripId, method, amountIdr, gatewayRef, status, idempotencyKey

/payouts/{payoutId}

driverId, amountIdr, destination, status, requestedAt, paidAt

/ratings/{ratingId}

tripId, byUserId, targetUserId, stars, tags[], comment

/sos_events/{eventId}

tripId, byUserId, lat, lng, audioUrl, contactsNotified[], createdAt

/fare_formulas/{version}

baseIdr, perKmIdr, perMinIdr, validFrom

/service_areas/{areaId}

name, geojson, active

### 10.2.5 Realtime Database Schema

Realtime DB is used for high-frequency, low-latency data that does not need transactional guarantees.

/presence/drivers/{driverId}

lat, lng, heading, accuracy, updatedAt, online

(written by driver app every 3–5 seconds when online)

/active_trips/{tripId}

driverLat, driverLng, status, etaSeconds, updatedAt

(fanned out by Cloud Function; subscribed by passenger app)

/order_offers/{driverId}

tripId, expiresAt, offerData

(written by createBooking; driver app subscribes to its own slot)

### 10.2.6 Required Cloud Functions

createBooking (HTTPS callable). Validates the caller is an authenticated passenger via custom claim. Validates pickup point is inside an active service_area polygon. Computes fare via the latest fare_formula. Queries online drivers within radius (Realtime DB GeoFire or Firestore geohash query) expanding 1.5 → 3 → 5 → 8 km. Scores drivers (proximity, rating, acceptance_rate, trips_today_inverse). Writes the top-1 driver's slot in /order_offers/{driverId} with expiresAt = now + 15 s. Uses Cloud Tasks to schedule a follow-up function at expiry; if not accepted, cascades to the next driver. Total budget 90 s; returns tripId to the passenger immediately.

acceptOrder (HTTPS callable, driver-side). Transactionally reads /order_offers/{driverId}, validates not expired, deletes the offer, creates /trips/{tripId} with status = "matched", and sends an FCM push to the passenger with driver details.

onLocationWrite (Realtime DB trigger on /presence/drivers/{driverId}). If the driver has an active trip, mirrors location to /active_trips/{tripId} and recomputes ETA via the Mapbox Directions API (cached aggressively; only called every 30 s).

completeTrip (HTTPS callable, driver-side; idempotent via idempotency key). Validates trip status is "on_trip". Computes final fare from actual distance and duration. Persists driver share and platform fee. Generates a receipt PNG via a Cloud Function using node-canvas or @vercel/og. Uploads the PNG to /receipts/{tripId}.png in Cloud Storage. Updates trip status to "completed". Sends FCM pushes to both passenger and driver.

requestWithdrawal (HTTPS callable, driver-side). Validates balance ≥ Rp 20,000. Atomically debits driver balance. Writes a /payouts doc with status = "processing". STUB: schedules a follow-up after 30 s that flips status to "success" (real Midtrans/Xendit integration is deferred to MVP). Sends FCM push when status flips.

cascadeOrderExpiry (Cloud Task callback). If /order_offers/{driverId} still exists and is expired, deletes it and offers to the next driver in the candidate list (passed as task payload). If the candidate list is exhausted, marks the trip as "no_drivers_available" and notifies the passenger.

sosTrigger (HTTPS callable). Validates the caller is on an active trip. Creates a /sos_events doc. Uploads optional audio (driver SOS) to /sos_audio/{eventId}.m4a. Sends notifications to passenger emergency contacts via FCM data message to a stub contact app (or via a free-tier Twilio trial if integrated) and to the ops dashboard FCM topic.

### 10.2.7 Security Rules (Must-Have)

Firestore rules:

/users/{uid}: read by self only; write by self for non-system fields.

/trips/{tripId}: read by passengerId or driverId only; writes allowed only via Cloud Functions admin SDK.

/drivers/{uid}: writes own status and online flag only; balanceIdr writable only via Functions.

/payments and /payouts: client writes denied; only via Functions.

/ratings/{ratingId}: writable only by the trip counterpart, only after status = "completed", and only within 7 days.

Realtime DB rules:

/presence/drivers/{driverId}: writable by self only (auth uid matches); readable by users with active trip linkage.

Storage rules:

/kyc/{uid}/*: writable by self; readable only by admins (via custom claim).

/receipts/{tripId}.png: readable by trip participants.

/sos_audio/{eventId}.m4a: writable via Functions only; readable only by ops staff.

### 10.2.8 Authentication Flow

Phone OTP via Firebase Auth — Firebase handles SMS delivery (free quota in test mode; paid pricing roughly USD 0.06 per SMS at production scale). After first signup, a Cloud Function setUserRole (called from the app post-OTP) sets a custom claim role = "passenger" or "driver". Custom claims drive role-based access in security rules. In the prototype, passenger and driver are separate Firebase Auth accounts on separate phone numbers; the MVP may unify them.

### 10.2.9 Maps and Navigation

The Mapbox SDK is used directly from Flutter. The Mapbox key is stored in flutter_secure_storage and pulled via Remote Config at app start. The Directions API is called from the client (acceptable in prototype; in the MVP, move it behind a Cloud Function to protect the key). Cache aggressively to control Mapbox cost; common Bandung routes (under 5 km between common points) cached server-side via Firestore for 1 hour.

### 10.2.10 Payment Strategy

Cash: full UI flow; driver confirms manually; trip transitions to "completed" on driver tap — fully functional.

QRIS / E-wallet: STUBBED. A Cloud Function simulates a Midtrans webhook with a 5 s delay and marks payment "paid". No real money moves.

Driver payouts: same stub pattern (30 s delay then "success").

Rationale: real payment integration is the riskiest non-trivial work, and KYB with Midtrans or Xendit takes 30+ days. Defer it to the MVP.

### 10.2.11 What P2 Lacks vs MVP

Real payment gateway integration (P2 stubs all online payment).

Real SMS to emergency contacts (P2 uses FCM data messages or a Twilio trial).

Real BPJS portal integration (display only, no enrollment).

Admin / Ops web console (use the Firebase Console UI for prototype operations).

High-concurrency tuning (P2 supports about 100 concurrent users; MVP targets 1,500).

Multi-region failover.

Production-grade observability beyond Firebase and Crashlytics.

PII encryption keys are managed by Firebase in P2; MVP introduces customer-managed keys for KTP and bank details.

### 10.2.12 Migration Path P2 → MVP

The MVP introduces a custom backend (Node.js with NestJS, or Go with Gin) primarily for: real Midtrans/Xendit integration with proper webhook handling, higher-performance matching with Redis, PostgreSQL with PostGIS for complex geospatial queries, an admin console, and stronger PII protection.

Migration steps:

Step 1 (weeks 1–2): add an API gateway in front of Firestore — clients call the new API; the API writes Firestore in a dual-write phase.

Step 2: migrate Cloud Function business logic to backend services; Cloud Functions become thin webhook receivers.

Step 3 (weeks 3–4): move the trip ledger to PostgreSQL; keep Firestore as a read-cache for mobile clients.

Step 4: Realtime Database stays for live location (or migrate to a self-hosted WebSocket cluster only if cost becomes an issue).

Step 5: Cloud Storage and FCM stay.

Step 6: Mapbox calls move from client to API gateway for key protection.

### 10.2.13 Cost Estimate (P2 Monthly, 50 Drivers + 200 Passengers Beta)

Firebase Auth: free under 10k SMS/month.

Firestore: approximately USD 2–10 (50k reads + 20k writes daily).

Realtime Database: approximately USD 1–5 (driver presence streams).

Cloud Storage: approximately USD 1 (receipt PNGs + occasional SOS audio).

Cloud Functions: approximately USD 2–10 (invocations + compute, mostly free tier).

Cloud Messaging: free.

Mapbox: approximately USD 50–150 (Maps + Directions API).

Total: approximately USD 60–180 per month.

### 10.2.14 Acceptance Criteria for P2

Two physical phones complete a real trip end-to-end (passenger and driver on separate devices, separate Firebase accounts).

Live location visible on the passenger phone within 3 s of driver movement.

Receipt PNG generated by a Cloud Function and shareable to WhatsApp.

Withdrawal flow ends with simulated payout marked "success".

Crashlytics reports under 5 crashes per 100 sessions.

Firebase security rules pass adversarial review — no unauthorized cross-user reads detected by tooling (e.g., firebase-rules-unit-testing).

## 50 internal beta drivers run 200+ trips in 2 weeks with under 1% failure rate.

### 10.2.15 6-Week Build Plan (2 Developers)

Week 1 — Foundations. Days 1–2: Firebase projects (dev/staging/prod), baseline security rules, Phone Auth integration. Day 3: custom claim assignment, role gating in UI. Days 4–5: Firestore schema creation, seed data, model classes (freezed) with Firestore converters.

Week 2 — Driver Presence and Booking. Days 6–7: driver app online/offline plus presence stream to Realtime DB. Days 8–9: passenger booking screen calling the createBooking Cloud Function; matching v0 (radius-only, no scoring yet). Day 10: order offer flow with 15 s timeout.

Week 3 — Trip Lifecycle. Days 11–12: driver accept and decline; trip creation; status transitions. Days 13–14: live tracking via Realtime DB subscriptions in passenger app; map updates. Day 15: ETA recalculation via Mapbox Directions; in-app chat via Firestore subcollection.

Week 4 — Payment and Receipt. Days 16–17: cash flow end-to-end; payment status writes; trip completion. Day 18: QRIS/e-wallet stub Cloud Function. Days 19–20: receipt rendering Cloud Function plus Storage upload; sharing UX.

Week 5 — Earnings and Safety. Day 21: earnings dashboard wired to Firestore. Days 22–23: withdrawal flow with stub Cloud Function. Days 24–25: rating flow, SOS event capture and audio upload, FCM notifications wired throughout.

Week 6 — Hardening. Days 26–27: security rule hardening; adversarial testing with firebase-rules-unit-testing. Day 28: load test (10 concurrent drivers, 30 simultaneous bookings). Day 29: beta deployment; Crashlytics and Analytics verification. Day 30: internal demo to founders and ops team.

## 10.3 Track Comparison

The three delivery tracks differ across several dimensions:

Backend — P1: none. P2: Firebase only. MVP: custom backend plus Firebase.

Real authentication — P1: no (mocked). P2: yes (Firebase Phone). MVP: yes (custom OTP via WhatsApp Business).

Real payments — P1: no. P2: stubbed. MVP: yes (Midtrans / Xendit).

Cross-device flows — P1: no. P2: yes. MVP: yes.

Persistence — P1: local only. P2: Firestore. MVP: PostgreSQL with Firestore as read cache.

Push notifications — P1: in-app simulation. P2: FCM. MVP: FCM plus WhatsApp plus SMS.

Admin console — P1: none. P2: Firebase Console. MVP: custom web console.

Target users — P1: stakeholders, designers, internal review. P2: 50 beta testers in Bandung. MVP: public launch (50k MAU year-1 target).

Timeline — P1: 2–3 weeks. P2: 4–6 weeks. MVP: 8–12 weeks.

Monthly cost — P1: zero. P2: USD 60–180. MVP: TBD (USD 1k–5k initial).

Team — P1: 1–2 devs. P2: 2 devs. MVP: 2 devs plus ops and finance.

## 10.4 Reuse Strategy Across Prototypes

The investment in P1 is not throwaway. The Flutter UI, navigation, theme, animations, copy, and asset pipeline are reused 100% in P2 and the MVP. Only the data layer (repositories) changes:

P1 ships with MockTripRepository implementing the TripRepository interface.

P2 ships FirestoreTripRepository implementing the same interface.

MVP ships ApiTripRepository implementing the same interface.

This is enforced by keeping all Firebase or backend calls behind repository interfaces from day one of P1. Domain models (Trip, User, Driver) are defined with freezed and are storage-agnostic.

The same principle applies to Cloud Functions in P2 — they encode business rules (fare calculation, matching scoring) that translate directly to backend services in MVP. Write them in a way that can be lifted out (no Firebase-specific shortcuts in the core algorithm).

11. Phased Delivery Roadmap

This SRS focuses on MVP. The full roadmap from the source feature architecture document is preserved here for context.

Phase 0 — MVP (Months 1–3)

### 22 features. Day-1 launchable ride-hailing with transparent receipts, daily withdrawal, SOS, in-app navigation, cash + QRIS payment.

Phase 1 — v1.0 Growth (Months 4–6)

E-wallet payment, schedule/advance booking, female driver filter, promo system, fuel cost tracker, achievement badges, demand heatmap (AI-light), multi-stop, passenger referral.

Phase 2 — v1.5 Ecosystem (Months 7–12)

Smart dispatch AI, AURUM auto-save, RIHLAH Pass subscription, driver community forum, KIFAYAH micro-takaful, driver tier system, AI fraud detection, RIHLAH for Business, AI review moderation.

Phase 3 — v2.0 Full Ecosystem (Months 13–24)

RIHLAH FOOD, Group Booking, LEVANTA loan integration, voice booking Bahasa Indonesia, predictive trip suggestion, route optimization for couriers, accessibility for difabel users, driver koperasi share.

— End of Document —
