# RIHLAH Admin & Ops Console — Setup

The admin console is a separate Flutter Web entrypoint (`lib/main_admin.dart`) that
reuses the same Firebase project as the passenger/driver mobile app. It provides
driver management, passenger management, trip/transaction history, payouts, a
safety (SOS) review queue, and basic operational reports — the "Admin & Ops Web
Console" component described in the SRS (§2.1, §5.1).

## 1. Create the first admin account

The console has no self-registration — admin accounts are provisioned manually:

1. Open the [Firebase Console](https://console.firebase.google.com) → your RIHLAH
   project → **Authentication** → **Sign-in method** → enable **Email/Password**
   (the mobile app uses phone OTP; the admin console uses email/password instead,
   since it's a desktop back-office tool).
2. **Authentication** → **Users** → **Add user** → enter an email and password
   for the first ops staff member. Copy the generated **User UID**.
3. **Firestore Database** → `users` collection → create (or edit) a document with
   that UID as the document ID, with at least:
   ```json
   {
     "uid": "<paste the UID>",
     "phone": "",
     "name": "Ops Admin",
     "role": "admin",
     "accountStatus": "active"
   }
   ```
   `role: "admin"` is what `firestore.rules`' `isAdmin()` check and the admin
   router's redirect guard both key off — without it, sign-in succeeds but the
   console immediately signs the user back out with "Akun ini tidak memiliki
   akses admin."
4. Repeat step 2–3 for each additional ops/finance/captain staff member. (The
   SRS's Super Admin / Ops / Finance / Captain role distinction is not enforced
   at the permission level yet — every `role: "admin"` account currently has
   full access. Finer-grained roles are a documented follow-up, not MVP scope.)

## 2. Run the console

```bash
flutter run -d chrome -t lib/main_admin.dart
```

To build a deployable web bundle:

```bash
flutter build web -t lib/main_admin.dart
```

The output lands in `build/web` — host it on Firebase Hosting, GCS, or any
static host. It talks directly to Firestore/Realtime Database via the Firebase
client SDK (same pattern as the mobile app), so no separate backend deploy is
needed for the console itself.

## 3. What it covers

- **Dashboard** — drivers online now, trips today, GMV today, avg driver
  rating, last-7-days trip/GMV table.
- **Drivers** — searchable list, per-driver detail (vehicle, BPJS/KTP status,
  rating, trip history), verify/suspend account.
- **Passengers** — searchable list, suspend/activate account.
- **Trips** — full trip list with status/date, per-trip fare breakdown dialog
  (platform fee, driver share, payment method, rating).
- **Payouts** — driver withdrawal ledger; manually settle/fail any withdrawal
  stuck in "processing" (the mobile app's payout simulation auto-resolves
  ~1.5s after request, so this is mainly a manual fallback).
- **Safety / SOS** — real-time queue of SOS events from the driver app, with
  an acknowledge action. (Audio capture stays simulated — see SRS §10.1.2 /
  the main MVP audit for why real mic recording is out of scope.)
- **Reports** — GMV, platform revenue, average fare, and top drivers by trip
  count over a selectable 7/30/90-day window.

## 4. Known MVP limitations

- List/report queries are bounded (a few hundred to 1000 most-recent
  documents) and computed client-side rather than via server-side
  aggregation — fine for a beta-scale fleet, not for high volume. This is
  called out inline in the Dashboard/Reports screens when the cap is hit.
- No pagination — "load more" beyond the bounded fetch isn't implemented.
- Admin roles are binary (`admin` or not) — the SRS's Super
  Admin/Ops/Finance/Captain distinction isn't enforced per-permission.
