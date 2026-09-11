# RIHLAH MVP Launch Checklist

> Complete each item before the Bandung beta launch.
> Target: 50 drivers, 200 passengers, 2-week dogfooding period.

---

## Infrastructure

- [ ] **Cloud SQL PostgreSQL 15 + PostGIS** provisioned in asia-southeast2
  - [ ] Private IP + VPC connector for Cloud Run
  - [ ] `DATABASE_URL` set in Secret Manager
  - [ ] `prisma migrate deploy` run successfully
  - [ ] `prisma seed` run (fare formulas, service areas, promos)
- [ ] **Redis 7 (Memorystore)** provisioned
  - [ ] `REDIS_URL` set in Secret Manager
  - [ ] Connected to same VPC as Cloud Run
- [ ] **Cloud Run API** deployed
  - [ ] Health check endpoint responds
  - [ ] CORS configured for admin console domain
  - [ ] Autoscaling tested (min 1, max 20)
- [ ] **Cloud Run Matching Worker** deployed
- [ ] **Firebase Cloud Function** deployed (`onLocationWrite`)
- [ ] **Cloud Storage** buckets created
  - [ ] `rihlah-kyc` — driver KTP/vehicle photos
  - [ ] `rihlah-sos-audio` — SOS emergency recordings
  - [ ] `rihlah-receipts` — receipt PNGs
- [ ] **Firebase Hosting** configured for admin web console
- [ ] **Secret Manager** configured with all secrets:
  - [ ] `DATABASE_URL`
  - [ ] `REDIS_URL`
  - [ ] `ENCRYPTION_KEY` (64 hex chars)
  - [ ] `MIDTRANS_SERVER_KEY`
  - [ ] `MIDTRANS_CLIENT_KEY`
  - [ ] `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`
  - [ ] `FIREBASE_PROJECT_ID`

## Security

- [ ] Firestore security rules deployed (production version)
- [ ] RTDB security rules deployed
- [ ] Firebase App Check enabled (Play Integrity for Android)
- [ ] OWASP Mobile Top 10 review passed — no Critical/High findings
- [ ] PII encryption verified (spot-check encrypted fields in DB)
- [ ] Audit log table verified (mutating API calls produce log entries)
- [ ] Rate limiting verified (5+ rapid requests → 429 response)

## Payment Gateway

- [ ] Midtrans KYB approved (production keys obtained)
- [ ] Xendit KYB applied (backup gateway)
- [ ] Sandbox end-to-end: QRIS payment completes → webhook → trip status updates
- [ ] Cash flow: driver confirms → payment → CASH_CONFIRMED
- [ ] Payout flow: withdraw → disburse → driver balance debited
- [ ] Webhook signature verification tested with invalid signatures
- [ ] Idempotency tested (duplicate payment request → 409)

## Feature Verification (Real Devices)

- [ ] Two physical phones: passenger books → driver accepts → live tracking → complete → receipt shareable
- [ ] SOS trigger: creates Firestore event, admin console sees it
- [ ] In-app chat: messages sync between passenger and driver
- [ ] Rating: 5-star + tags + tip persist and recompute driver average
- [ ] Saved addresses: sync across app reinstall (Firestore-backed)
- [ ] Earning dashboard: updates after each completed trip
- [ ] Withdrawal: min Rp 20k, first-free/subsequent-fee, balance validation
- [ ] Online/offline toggle: anti-abuse cooldown, GPS watchdog
- [ ] Trip history export: PDF + CSV generate correctly

## Admin Console

- [ ] Dashboard KPIs match database aggregates
- [ ] Driver list/search/suspend works
- [ ] Passenger list/search/suspend works
- [ ] Trip list filters by status
- [ ] Payout manual settle/fail resolves stuck payouts
- [ ] SOS queue shows live events with acknowledge action
- [ ] Reports: 7/30/90 day aggregations match raw data

## Performance

- [ ] Cold start ≤ 3s on Xiaomi Redmi 9 (or equivalent)
- [ ] Driver match latency median ≤ 4s, p95 ≤ 8s
- [ ] API response median ≤ 200ms, p95 ≤ 600ms
- [ ] Live location update latency median ≤ 2s
- [ ] Crash-free session rate ≥ 99.5% (Firebase Crashlytics)

## Pre-Launch

- [ ] 50 beta drivers onboarded with real KYC
- [ ] 200+ test trips completed in 2 weeks
- [ ] < 1% failure rate (cancellations, crashes, payment failures)
- [ ] Indonesian-language strings reviewed by native speaker
- [ ] Flutter app built in release mode, APK signed
- [ ] Play Store listing draft ready
- [ ] Cash-only soft launch tested as fallback (no Midtrans dependency)

## Go/No-Go Criteria

| Criterion | Threshold | Status |
|-----------|-----------|--------|
| Trip completion rate | ≥ 98% | ☐ |
| Payment success rate (online) | ≥ 95% | ☐ |
| Crash-free rate | ≥ 99.5% | ☐ |
| Driver match success | ≥ 90% within 90s | ☐ |
| SOS events processed | 100% within 60s | ☐ |
| Security review | 0 Critical, 0 High | ☐ |
