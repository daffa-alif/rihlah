# Rihlah KYC test harness (Svelte)

A small Svelte + Vite app for exercising the backend's `POST /kyc/verify`
endpoint with a real device camera. It exists purely for manual testing —
it is not the Rihlah product frontend.

## What it does

1. Collects the driver's claimed vehicle/financial/device data in a form —
   **no identity fields**: NIK/name/date of birth are read entirely off the
   KTP/SIM photo by the backend's OCR and confirmed via a Dukcapil stub,
   there's nothing to type here.
2. Opens the device camera to capture a live KTP/SIM photo, a **burst of
   selfie frames** (8 stills over ~1.6s, for the backend's frame-by-frame
   liveness check — blink + natural movement + sharpness), and (optionally)
   a live STNK photo — each captured frame lives only as an in-memory
   `Blob` (via `canvas.toBlob`), never written to disk or `localStorage`.
3. Sends everything once, as `multipart/form-data`, to
   `POST {VITE_API_BASE_URL}/kyc/verify`.
4. Renders the full verification result (status, extracted OCR fields,
   biometric + liveness scores, Dukcapil confirmation, cross-validation
   table, rejection reasons).
5. Drops its in-memory photo/frame references as soon as the request
   settles and resets the camera components, so testing another attempt
   always starts from a fresh capture — mirroring the backend's "process
   once, never persist" behavior on the client side.

This burst-capture flow is a stand-in for the real one: the production
client is a Flutter mobile app that extracts frames from a few seconds of
live camera video rather than a JS-timer burst of still snapshots, but the
wire contract (`selfie_frames` as an ordered set of images) is the same.

The only thing this app persists locally is `device_id`, a random UUID
kept in `localStorage` so the backend can recognize repeat submissions from
the same browser (this is an opaque fingerprint, not a photo or document
data).

## Setup

```powershell
npm install
Copy-Item .env.example .env
```

Edit `.env` if the backend isn't at the default `http://localhost:8000/api/v1`.

## Run

```powershell
npm run dev
```

Then open the printed local URL. Camera access requires either `localhost`
or HTTPS — browsers refuse `getUserMedia` on a plain HTTP LAN address, so
test from the same machine running `npm run dev`, or serve over HTTPS if
you need another device.

Make sure the backend is running and has `CORS_ORIGINS` including this
app's origin (the Vite default `http://localhost:5173` is already in the
backend's default config). Its imports are `BACKEND.app.*`, so it must run
with the repo root on `PYTHONPATH` — `uvicorn app.main:app` from inside
`BACKEND/` will not resolve. From `BACKEND/` (so its `.env` is found):

```powershell
$env:PYTHONPATH = (Resolve-Path ..).Path
uvicorn BACKEND.app.main:app --reload
```

## Layout

```
src/
  main.js              mounts App.svelte into #app
  app.css              shared design tokens (--border, --ok, --bad, ...)
  App.svelte           form state, payload building, submit — the page
  lib/
    CameraCapture.svelte  single-shot capture (KTP/SIM photo, STNK photo)
    BurstCapture.svelte   multi-frame capture for the selfie liveness burst
    ResultView.svelte     renders one KycVerificationResponse
    api.js                builds the multipart request, calls /kyc/verify
    deviceId.js            the one thing this app persists — an opaque UUID
    geolocation.js          thin wrapper over navigator.geolocation
```

Adding a response field: update `ResultView.svelte` to display it. Adding a
request field: update `App.svelte`'s payload builder and `canSubmit` check.
Keep this in sync with [BACKEND/docs/API.md](../BACKEND/docs/API.md#kyc) —
that's the source of truth for the wire contract.
