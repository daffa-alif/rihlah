# RIHLAH Test Checklist
> Use this checklist to manually verify every feature on a physical device.
> Check off each item as you test it. Two devices recommended for cross-device tests (passenger + driver).
> Test phone: `+628123456789` · OTP: `123456`

---

## 1. Authentication

| # | Test | Expected Result | Pass |
|---|------|-----------------|------|
| A1 | Open app cold (not logged in) | Splash → Onboarding screen | o |
| A2 | Tap through onboarding slides | Slides advance, last slide shows Sign In button | o |
| A3 | Enter `812-3456-7890` → tap Continue | OTP screen appears, phone number shown correctly | o |
| A4 | Enter `123456` → tap Verify | Role picker screen appears | o |
| A5 | Select **Passenger** | Passenger home screen loads | o |
| A6 | Kill and reopen app | Splash skips onboarding, goes straight to passenger home | o |
| A7 | Open app with a second account, select **Driver** | Driver home screen loads | o |
| A8 | OTP countdown reaches 0 | "Resend code" button becomes active | o |
| A9 | Tap Resend | New OTP requested, timer resets to 60s | o |

---

## 2. Passenger — Booking Flow

| # | Test | Expected Result | Pass |
|---|------|-----------------|------|
| B1 | Tap search bar on passenger home | Location search screen opens | o |
| B2 | Search for a destination (e.g. "Braga") | Results appear, tap one to select | o |
| B3 | Confirm pickup & dropoff | Services screen shows Car / Bike / Send with fares | o |
| B4 | Check fare breakdown | RIHLAH price shown alongside Gojek / Grab comparison | - |
| B5 | Select Car → tap Book | Confirm booking screen appears | o |
| B6 | Change payment method | Payment methods list opens, selection saved | - |
| B7 | Apply a voucher code | Discount reflected in total | o |
| B8 | Tap Confirm | Searching screen appears with pulsing animation | o |
| B9 | Wait for timeout (~3 min) | "No driver found" dialog appears | o |
| B10 | Tap Cancel on searching screen | Returns to passenger home, trip cancelled in Firestore | o |

---

## 3. Cross-Device — Trip Matching (needs 2 devices)

| # | Test | Expected Result | Pass |
|---|------|-----------------|------|
| C1 | Passenger books a Car trip | Searching screen shows | o |
| C2 | Driver device: go Online | Driver goes online, starts listening for trips | o |
| C3 | Driver receives incoming order popup | Order details match passenger's booking (route, fare) | o |
| C4 | Driver taps Accept | Passenger screen transitions to trip tracking | o |
| C5 | Driver taps Decline / countdown expires | Driver gets next trip; passenger keeps searching | - |

---

## 4. Passenger — Live Tracking

| # | Test | Expected Result | Pass |
|---|------|-----------------|------|
| T1 | After driver accepts, passenger trip screen loads | Map shows driver marker and route | o |
| T2 | Driver moves (or mock GPS updates) | Driver marker moves on passenger map | ☐ |
| T3 | Status bar shows "Driver is on the way" | ETA countdown ticking | ☐ |
| T4 | Driver arrives at pickup | Status updates to "Driver has arrived" | ☐ |
| T5 | Trip starts (inTrip) | Route switches to dropoff leg | ☐ |
| T6 | Tap chat icon | Chat sheet opens, quick-reply chips visible | ☐ |
| T7 | Tap Share Trip | Share sheet opens with tracking link and WhatsApp option | ☐ |
| T8 | Tap SOS button | SOS screen opens with pulse animation | ☐ |

---

## 5. Passenger — Trip Completion & Rating

| # | Test | Expected Result | Pass |
|---|------|-----------------|------|
| R1 | Trip completed | Rating screen appears automatically | ☐ |
| R2 | Select star rating (1–5) | Tag chips update based on rating | ☐ |
| R3 | Select tip amount | Tip added to total | ☐ |
| R4 | Tap Submit | Returns to passenger home, success toast | ☐ |
| R5 | Check Firestore Console | `trips/{id}` document has rating, tip, status=completed | ☐ |
| R6 | Tap Skip | Returns to home without saving rating | ☐ |

---

## 6. Passenger — Other Screens

| # | Test | Expected Result | Pass |
|---|------|-----------------|------|
| O1 | Open Activity tab | Trip history list shows past trips | ☐ |
| O2 | Tap a trip → view receipt | Receipt shows fare breakdown and competitor delta | ☐ |
| O3 | Tap Share Receipt | Receipt image generated and share sheet opens | ☐ |
| O4 | Open Saved Addresses | List shows Home / Kantor / custom entries | ☐ |
| O5 | Add a new saved address | Address saved and appears in list | ☐ |
| O6 | Delete a saved address | Address removed from list | ☐ |
| O7 | Open Payment Methods | All providers listed (Cash, QRIS, GoPay, OVO, DANA, ShopeePay) | ☐ |
| O8 | Set a default payment method | Default persists after app restart | ☐ |
| O9 | Open Safety Settings | Emergency contacts section visible | ☐ |
| O10 | Add an emergency contact | Contact saved, appears in list | ☐ |

---

## 7. Driver — Home & Online/Offline

| # | Test | Expected Result | Pass |
|---|------|-----------------|------|
| D1 | Driver home loads | Map shown, status = Offline | o |
| D2 | Toggle Online | Status turns green, GPS starts, RTDB updated | o |
| D3 | Check Firebase RTDB Console | `/driver_locations/{uid}` has lat/lng values | o |
| D4 | Toggle Offline | Status turns grey, RTDB entry cleared | o |
| D5 | Toggle Online/Offline 3× quickly | 4th toggle blocked (cooldown warning shown) | o |

---

## 8. Driver — Incoming Order

| # | Test | Expected Result | Pass |
|---|------|-----------------|------|
| I1 | Passenger books while driver is online | Incoming order screen appears automatically | ☐ |
| I2 | Check order details | Pickup, dropoff, distance, fare, driver earnings all shown | ☐ |
| I3 | Countdown arc visible | 15-second timer counting down | ☐ |
| I4 | Tap Accept | Navigate to driver trip screen | ☐ |
| I5 | Let countdown expire | Screen dismisses, driver stays online waiting for next trip | ☐ |
| I6 | Tap Decline | Same as expire — back to online waiting | ☐ |

---

## 9. Driver — Navigation & Trip

| # | Test | Expected Result | Pass |
|---|------|-----------------|------|
| N1 | After accepting, driver trip screen loads | Map shows route to pickup | ☐ |
| N2 | Voice guidance plays | TTS announces first instruction | ☐ |
| N3 | GPS updates as driver moves | Driver marker moves, route progress updates | ☐ |
| N4 | Tap "Arrived at Pickup" | Status changes to waiting for passenger | ☐ |
| N5 | Tap "Start Trip" | Route switches to dropoff, inTrip phase begins | ☐ |
| N6 | Tap SOS button during trip | SOS screen opens | ☐ |
| N7 | Tap "Complete Trip" | Driver trip complete screen appears | ☐ |

---

## 10. Driver — Trip Complete & Earnings

| # | Test | Expected Result | Pass |
|---|------|-----------------|------|
| E1 | Trip complete screen shows | Earnings breakdown: total fare, platform fee, driver share | ☐ |
| E2 | Competitor comparison visible | Shows how much more driver earns vs Gojek | ☐ |
| E3 | Tap Share Earnings | WhatsApp share sheet opens with receipt | ☐ |
| E4 | Tap Done | Returns to driver home, still online | ☐ |
| E5 | Open Earnings tab | Today's earnings updated | ☐ |
| E6 | Tap Withdraw | Withdraw sheet opens (min Rp 20.000) | ☐ |
| E7 | Check Driver History | Completed trip appears in history list | ☐ |

---

## 11. Firebase Verification (Console checks)

| # | Test | Where to check | Pass |
|---|------|----------------|------|
| F1 | User created after OTP | Firestore → `users/{uid}` document exists with phone + role | ☐ |
| F2 | Trip created on booking | Firestore → `trips/{id}` with status=searching | o |
| F3 | Trip accepted by driver | Firestore → same doc, status=accepted, driverId filled | ☐ |
| F4 | Driver GPS streaming | RTDB → `/driver_locations/{uid}` updates in real time | ☐ |
| F5 | Rating saved | Firestore → `trips/{id}` has rating + tip after passenger rates | ☐ |
| F6 | Trip cancelled | Firestore → `trips/{id}` status=cancelled | o |

---

## 12. Edge Cases

| # | Test | Expected Result | Pass |
|---|------|-----------------|------|
| X1 | Kill app mid-booking, reopen | Splash detects existing auth, goes to correct home screen | ☐ |
| X2 | Enter wrong OTP (`000000`) | Error toast shown, can retry | ☐ |
| X3 | Book a trip with no internet | Graceful error toast, no crash | ☐ |
| X4 | 5-tap on splash screen logo | Dev menu opens | ☐ |
| X5 | Dev menu → Reset All Data | App resets to onboarding | ☐ |
| X6 | Change language (if supported) | UI language switches | ☐ |

---

## 13. Admin & Ops Console

> Run with `flutter run -d chrome -t lib/main_admin.dart`. See `ADMIN_CONSOLE_SETUP.md`
> for how to provision the first admin account (`role: "admin"` on a `users/{uid}` doc,
> Firebase Auth email/password sign-in).

| # | Test | Expected Result | Pass |
|---|------|-----------------|------|
| AD1 | Open console, sign in with a non-admin email/password account | Sign-in succeeds then immediately signs back out with "Akun ini tidak memiliki akses admin." | ☐ |
| AD2 | Sign in with a `role: "admin"` account | Redirects to Dashboard | ☐ |
| AD3 | Dashboard loads | KPI cards show drivers online, trips today, GMV today, avg rating; 7-day table populated | ☐ |
| AD4 | Open Drivers tab | Table lists all driver accounts; search by name/phone/plate filters | ☐ |
| AD5 | Open a driver's Detail page | Vehicle, BPJS/KTP, rating, and trip history all shown | ☐ |
| AD6 | Tap "Tangguhkan Akun" on a driver | Status pill flips to "Ditangguhkan"; driver's `accountStatus` updates in Firestore | ☐ |
| AD7 | Open Passengers tab | Table lists all passenger accounts; suspend/activate works | ☐ |
| AD8 | Open Trips tab, filter by status | Table filters correctly; tapping "Detail" opens fare breakdown dialog (platform fee, driver share, payment method) | ☐ |
| AD9 | Driver app: complete a withdrawal | A new `payouts` doc appears in the admin Payouts tab within a few seconds, resolving to "success" or "failed" | ☐ |
| AD10 | Payouts tab: find a payout stuck on "processing" | "Selesaikan"/"Gagalkan" buttons manually resolve it | ☐ |
| AD11 | Driver app: trigger SOS (long-press SOS button) | A new `sos_events` doc appears in the admin Safety/SOS tab, flagged "Terbuka" | ☐ |
| AD12 | Safety/SOS tab: tap "Tandai Ditangani" | Event flips to "Ditangani" | ☐ |
| AD13 | Open Reports tab, change date range | KPI totals and top-driver table recompute for 7/30/90 days | ☐ |
| AD14 | Sign out via the nav rail logout icon | Returns to the login screen | ☐ |

---

## Summary

| Section | Total | Passed | Failed |
|---------|-------|--------|--------|
| 1. Authentication | 9 | | |
| 2. Passenger Booking | 10 | | |
| 3. Cross-Device Trip Matching | 5 | | |
| 4. Passenger Live Tracking | 8 | | |
| 5. Rating & Completion | 6 | | |
| 6. Passenger Other Screens | 10 | | |
| 7. Driver Home | 5 | | |
| 8. Driver Incoming Order | 6 | | |
| 9. Driver Navigation | 7 | | |
| 10. Driver Earnings | 7 | | |
| 11. Firebase Verification | 6 | | |
| 12. Edge Cases | 6 | | |
| 13. Admin & Ops Console | 14 | | |
| **Total** | **99** | | |

---

*Generated: June 2026 — RIHLAH Prototype 2*
*Section 13 added: MVP completion pass — admin console, real payout/SOS/driver-profile backend data, GPS smoothing polish.*
