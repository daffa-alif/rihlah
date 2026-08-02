# Rihlah API Reference

Version `0.1.0` · Base URL `http://localhost:8000/api/v1`

Interactive versions of this document are generated from the code and served by
the app itself:

| Surface | URL |
| --- | --- |
| Swagger UI | `http://localhost:8000/docs` |
| ReDoc | `http://localhost:8000/redoc` |
| OpenAPI schema | `http://localhost:8000/api/v1/openapi.json` |

This file is the hand-maintained companion — it explains conventions and
intent that the generated schema does not carry. When you add or change an
endpoint, update the matching section here.

---

## Conventions

**Content type.** All request and response bodies are `application/json`,
except `POST /kyc/verify` which takes `multipart/form-data` (it carries
photo uploads) and returns `application/json`.

**Dates.** `date` fields use `YYYY-MM-DD`. `datetime` fields are ISO 8601 in
UTC, e.g. `2026-08-01T09:30:00Z`.

**Identifiers.** Resource ids are UUID v4 strings.

**Pagination.** List endpoints take `limit` (1–100, default 20) and `offset`
(≥ 0, default 0) and return an envelope:

```json
{
  "items": [],
  "total": 0,
  "limit": 20,
  "offset": 0
}
```

`total` is the count of all matching records, not the length of `items`.

**Errors.** Every error response — including validation and framework errors —
uses one shape:

```json
{
  "error": {
    "code": "not_found",
    "message": "Trip 'abc' was not found.",
    "details": null
  }
}
```

| Status | `code` | Meaning |
| --- | --- | --- |
| 400 | `app_error` | Request was well-formed but violated a business rule. |
| 404 | `not_found` | Resource does not exist. |
| 409 | `conflict` | Request conflicts with current state. |
| 413 | `payload_too_large` | An uploaded file exceeds the configured size limit. |
| 415 | `unsupported_media_type` | An uploaded file isn't an accepted image type. |
| 422 | `validation_error` | Payload failed schema validation; `details` holds the field-level errors. |
| 422 | `unprocessable_entity` | Well-formed request that couldn't be processed (e.g. an undecodable or unreadable photo). |
| 503 | `service_unavailable` | A required external dependency (e.g. the Tesseract OCR engine) is missing. |
| 4xx/5xx | `http_error` | Any other HTTP error raised by the framework. |

**Authentication.** Not implemented yet. All endpoints are currently open.
When auth lands, document the scheme here and add
`security` metadata to the affected routes.

---

## Health

### `GET /health`

Liveness probe. Use for container health checks and uptime monitoring.

**Response `200`**

```json
{
  "status": "ok",
  "version": "0.1.0",
  "environment": "development"
}
```

---

## Trips

A trip is a dated visit to a destination, with optional free-text notes.

### Trip object

| Field | Type | Notes |
| --- | --- | --- |
| `id` | string | UUID, server-generated. |
| `title` | string | 1–120 chars. |
| `destination` | string | 1–120 chars. |
| `start_date` | date | |
| `end_date` | date | Must be on or after `start_date`. |
| `notes` | string \| null | Up to 2000 chars. |
| `created_at` | datetime | Server-generated. |
| `updated_at` | datetime | Server-generated. |

### `GET /trips`

List trips, ordered by `start_date` ascending.

**Query parameters**

| Name | Type | Default | Notes |
| --- | --- | --- | --- |
| `limit` | int | 20 | 1–100. |
| `offset` | int | 0 | ≥ 0. |
| `destination` | string | — | Case-insensitive substring match. |

**Example**

```bash
curl "http://localhost:8000/api/v1/trips?destination=bandung&limit=10"
```

**Response `200`**

```json
{
  "items": [
    {
      "id": "3f1a7c9e-2b64-4d18-9d0a-6f2c1b5e8a11",
      "title": "Weekend in Bandung",
      "destination": "Bandung, Indonesia",
      "start_date": "2026-09-12",
      "end_date": "2026-09-14",
      "notes": "Bring a jacket.",
      "created_at": "2026-08-01T09:30:00Z",
      "updated_at": "2026-08-01T09:30:00Z"
    }
  ],
  "total": 1,
  "limit": 10,
  "offset": 0
}
```

### `POST /trips`

Create a trip.

**Request body** — `title`, `destination`, `start_date`, `end_date` required;
`notes` optional.

```bash
curl -X POST http://localhost:8000/api/v1/trips \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Weekend in Bandung",
    "destination": "Bandung, Indonesia",
    "start_date": "2026-09-12",
    "end_date": "2026-09-14"
  }'
```

**Responses** — `201` with the created trip · `422` if `end_date` precedes
`start_date` or a field fails validation.

### `GET /trips/{trip_id}`

Fetch one trip.

**Responses** — `200` with the trip · `404` if it does not exist.

### `PATCH /trips/{trip_id}`

Partial update. Only the fields present in the body are changed; omitted
fields keep their current values.

```bash
curl -X PATCH http://localhost:8000/api/v1/trips/3f1a7c9e-2b64-4d18-9d0a-6f2c1b5e8a11 \
  -H "Content-Type: application/json" \
  -d '{"notes": "Booked the hotel."}'
```

**Responses** — `200` with the updated trip · `400` if the resulting date range
is invalid · `404` if it does not exist · `422` on field validation failure.

### `DELETE /trips/{trip_id}`

Delete a trip.

**Responses** — `204` with an empty body · `404` if it does not exist.

---

## KYC

One-shot driver identity verification. A live-captured KTP or SIM photo, a
live selfie, and an optional STNK photo are decoded **in memory**, run
through OCR + face detection/matching + a liveness check, cross-validated
against the driver's claimed data, and then discarded. **No photo bytes are
ever written to disk, cached, or persisted anywhere** — the response is the
only record of the check having happened.

See the [README's KYC section](../README.md#kyc-verification-post-kycverify)
for the honesty constraints on face-match/liveness accuracy and OCR field
extraction before relying on this for production fraud prevention.

### `POST /kyc/verify`

`multipart/form-data` with four parts:

| Part | Type | Required | Notes |
| --- | --- | --- | --- |
| `payload` | text (JSON) | yes | A JSON-encoded `KycVerificationRequest` (see below). |
| `id_document_photo` | file | yes | Live photo of the KTP or SIM. `image/jpeg`, `image/png` or `image/webp`, ≤ 8MB. |
| `selfie_photo` | file | yes | Live selfie for face match + liveness. Same type/size limits. |
| `stnk_photo` | file | no | Live STNK photo. If omitted, `claimed_vehicle.brand`/`model`/`year` become required in `payload` instead. |

**`payload` shape (`KycVerificationRequest`)**

```json
{
  "document_type": "KTP",
  "claimed_identity": {
    "nik": "3173015505990001",
    "full_name": "Budi Santoso",
    "date_of_birth": "1999-05-15",
    "sim_number": "990412345678",
    "sim_class": "C"
  },
  "claimed_vehicle": {
    "plate_number": "B 1234 XYZ",
    "vehicle_type": "MOTOR",
    "brand": "Honda",
    "model": "Vario 160",
    "year": 2021
  },
  "financial": {
    "bank_name": "BCA",
    "bank_account_number": "1234567890",
    "bank_account_holder_name": "Budi Santoso",
    "skck_number": "SKCK/2026/001234",
    "skck_valid_until": "2026-12-01"
  },
  "device": {
    "device_id": "device-fingerprint-abc123",
    "location": { "latitude": -6.2, "longitude": 106.8 }
  }
}
```

`document_type` is `KTP` or `SIM` and selects which OCR parser reads
`id_document_photo`. `claimed_identity.sim_number` is required when
`document_type` is `SIM`. `financial` is optional. `device.device_id` is
client-supplied; `ip_address` and `user_agent` in the response are read
server-side from the request instead, since a client can't be trusted to
self-report those honestly.

**Example**

```bash
curl -X POST http://localhost:8000/api/v1/kyc/verify \
  -F "payload=$(cat payload.json)" \
  -F "id_document_photo=@ktp.jpg;type=image/jpeg" \
  -F "selfie_photo=@selfie.jpg;type=image/jpeg"
```

**Response `200` (`KycVerificationResponse`)**

```json
{
  "request_id": "b3f1c9e2-...-e8a11",
  "status": "VERIFIED",
  "document_type": "KTP",
  "ktp": {
    "nik": "3173015505990001",
    "full_name": "BUDI SANTOSO",
    "place_of_birth": "JAKARTA",
    "date_of_birth": "1999-05-15",
    "gender": "LAKI_LAKI",
    "address": {
      "street": "JL. MERDEKA NO. 17",
      "rt_rw": "003/005",
      "village": "CIKINI",
      "district": "MENTENG",
      "city": "MENTENG"
    },
    "religion": "ISLAM",
    "marital_status": "BELUM_KAWIN",
    "occupation": "KARYAWAN SWASTA",
    "nationality": "WNI",
    "valid_until": "SEUMUR HIDUP",
    "raw_ocr_text": "...",
    "ocr_confidence": 0.87
  },
  "sim": null,
  "vehicle": {
    "plate_number": "B 1234 XYZ",
    "owner_name": "Budi Santoso",
    "brand": "Honda",
    "model": "Vario 160",
    "year": 2021,
    "color": null,
    "tax_valid_until": null,
    "source": "MANUAL",
    "raw_ocr_text": null,
    "ocr_confidence": null
  },
  "biometrics": {
    "id_face_detected": true,
    "selfie_face_detected": true,
    "face_match_score": 0.81,
    "face_match_passed": true,
    "liveness_confidence_score": 0.73,
    "liveness_passed": true,
    "verified_at": "2026-08-01T20:45:00Z"
  },
  "device": {
    "device_id": "device-fingerprint-abc123",
    "location": { "latitude": -6.2, "longitude": 106.8 },
    "ip_address": "203.0.113.10",
    "user_agent": "Mozilla/5.0 ...",
    "within_service_area": true
  },
  "financial": { "...": "..." },
  "cross_validation": [
    { "field": "nik", "extracted_value": "3173015505990001", "claimed_value": "3173015505990001", "matched": true }
  ],
  "rejection_reasons": [],
  "processed_at": "2026-08-01T20:45:00Z",
  "image_retention_notice": "Uploaded photos were decoded in memory, processed once, and discarded. No image bytes were written to disk or persisted in any datastore."
}
```

`status` is `REJECTED` whenever `rejection_reasons` is non-empty — the
response body is otherwise identical, so a caller always gets back the full
extracted/cross-validated data regardless of outcome.

### Business rules enforced

| Rule | Detail |
| --- | --- |
| NIK format & structure | 16 digits; birth date/gender encoded in digits 7–12 must match the claimed date of birth. |
| Identity cross-check | Extracted NIK/name/DOB vs claimed — name uses fuzzy match (`KYC_NAME_MATCH_THRESHOLD`), NIK/DOB require exact match. |
| Minimum driver age | `KYC_MIN_DRIVER_AGE` (default 17), plus a higher per-SIM-class minimum (e.g. SIM B2 Umum requires 23). |
| SIM expiry | Rejected if expired or expiring within `KYC_SIM_EXPIRY_WARNING_DAYS` (default 30). |
| SIM class vs vehicle type | e.g. SIM C only authorizes `MOTOR`, SIM A/B authorizes `MOBIL`. |
| Plate number format | Must match the Indonesian plate pattern. |
| Vehicle age | Rejected if older than `KYC_MAX_VEHICLE_AGE_YEARS` (default 10). |
| STNK tax validity | Rejected if expired, or unknown (no `stnk_photo` provided). |
| Bank account holder name | Must exactly match the verified identity name (not fuzzy — financial data needs a stricter bar). |
| SKCK expiry | Rejected if `skck_valid_until` is in the past. |
| Geofence | `device.location` must fall inside `KYC_SERVICE_AREA_*` (default: all of Indonesia). |
| Face match | `face_match_score >= KYC_FACE_MATCH_THRESHOLD` (default 0.55). |
| Liveness | `liveness_confidence_score >= KYC_LIVENESS_THRESHOLD` (default 0.5). |

A mismatched vehicle owner name (vs. the verified identity) is recorded in
`cross_validation` but does **not** reject the request — Indonesian
practice allows driving someone else's vehicle with a power-of-attorney
letter, which this endpoint has no way to verify.

**Responses** — `200` always (status is `VERIFIED`/`REJECTED` in the body) ·
`413` if a photo exceeds the size limit · `415` if a photo isn't an accepted
image type · `422` if the payload fails schema validation, or a required
field couldn't be extracted from a photo · `503` if the Tesseract OCR engine
isn't installed.

---

## Changelog

| Version | Change |
| --- | --- |
| 0.1.0 | Initial scaffold: health probe and trips CRUD. |
| 0.1.0 | Added `POST /kyc/verify`: one-shot driver KYC (KTP/SIM + selfie + optional STNK), processed in memory, never persisted. |
