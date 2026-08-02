# Rihlah KYC test harness (Svelte)

A small Svelte + Vite app for exercising the backend's `POST /kyc/verify`
endpoint with a real device camera. It exists purely for manual testing —
it is not the Rihlah product frontend.

## What it does

1. Collects the driver's claimed identity/vehicle/financial/device data in a
   form.
2. Opens the device camera to capture a live KTP/SIM photo, a live selfie,
   and (optionally) a live STNK photo — each captured frame lives only as an
   in-memory `Blob` (via `canvas.toBlob`), never written to disk or
   `localStorage`.
3. Sends everything once, as `multipart/form-data`, to
   `POST {VITE_API_BASE_URL}/kyc/verify`.
4. Renders the full verification result (status, extracted OCR fields,
   biometric scores, cross-validation table, rejection reasons).
5. Drops its in-memory photo references as soon as the request settles and
   resets the camera components, so testing another attempt always starts
   from a fresh capture — mirroring the backend's "process once, never
   persist" behavior on the client side.

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

Make sure the backend is running (`uvicorn app.main:app --reload` from the
repo root) and has `CORS_ORIGINS` including this app's origin (the Vite
default `http://localhost:5173` is already in the backend's default config).
