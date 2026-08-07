# Rihlah Backend

FastAPI service for the Rihlah trip planning platform.

## Requirements

- Python 3.12+ (developed against 3.14)
- [Tesseract OCR](https://github.com/UB-Mannheim/tesseract/wiki) installed and
  on `PATH` (or pointed to via `KYC_TESSERACT_CMD`) — only needed for the
  `/kyc/verify` endpoint. Without it, that endpoint returns `503` rather than
  fabricating extracted document data.

## Setup

```powershell
py -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements-dev.txt
Copy-Item .env.example .env
```

## Run

Imports throughout this app are `BACKEND.app.*` (absolute from the repo
root), so `BACKEND` must be importable — running `uvicorn app.main:app`
from inside this folder will fail with `ModuleNotFoundError`. From this
folder (so `.env` is found via its default relative path), point
`PYTHONPATH` at the repo root instead:

```powershell
$env:PYTHONPATH = (Resolve-Path ..).Path
uvicorn BACKEND.app.main:app --reload
```

| Surface | URL |
| --- | --- |
| API root | http://localhost:8000/api/v1 |
| Swagger UI | http://localhost:8000/docs |
| ReDoc | http://localhost:8000/redoc |
| OpenAPI schema | http://localhost:8000/api/v1/openapi.json |

## Test

```powershell
pytest
```

## Lint

```powershell
ruff check .
ruff format .
```

## Layout

```
app/
  main.py              app factory: CORS, error handlers, router mounting
  api/
    router.py          aggregates all route modules
    deps.py            shared FastAPI dependencies
    routes/            one module per resource
  core/
    config.py          env-backed settings
    exceptions.py      domain errors + unified error response shape
  models/              domain models (swap for ORM models when the DB lands)
  schemas/             pydantic request/response models
  services/            business logic; routes stay thin
    kyc/               one-shot KYC verification (vision/ocr/validation/service)
docs/API.md            hand-written API reference
tests/                 pytest suite over the HTTP surface
```

## Notes

- `TripService` stores trips in a dict so the API runs end to end without a
  database. Replace it with a real repository when persistence is added — the
  routes depend only on its method signatures.
- No authentication yet. See the auth section in [docs/API.md](docs/API.md).
- Adding an endpoint: schema in `app/schemas/` → logic in `app/services/` →
  route in `app/api/routes/` → register in `app/api/router.py` → tests →
  document it in `docs/API.md`.

## KYC verification (`POST /kyc/verify`)

One-shot driver KYC: a live KTP/SIM photo + an ordered burst of live selfie
frames (+ optional STNK photo) are decoded in memory, run through face
detection/matching, frame-by-frame liveness analysis, and OCR, then
discarded — nothing is written to disk or persisted. Identity is never
driver-typed: it's read entirely off the document by OCR, then confirmed
against Dukcapil. See [docs/API.md](docs/API.md#kyc) for the full
payload/response shape and business rules (SIM expiry, vehicle age,
geofence, etc).

Three honesty constraints worth knowing before relying on this in production:

- **Face match is a classical OpenCV heuristic** (histogram + ORB keypoint
  correlation), not a deep-learning face embedding model. It's fully
  offline and explainable, but not biometric-grade — swap in a proper
  face-recognition SDK before trusting this for real fraud prevention.
- **Liveness is behavior-based across a frame burst, not a single-frame
  guess**: it looks for an actual open→closed→open blink, natural
  face-position drift between frames, and average sharpness (see
  `analyze_liveness_frames` in
  [app/services/kyc/vision.py](app/services/kyc/vision.py)). Still classical
  CV, not a dedicated anti-spoofing model — the client is expected to supply
  a genuine live burst (e.g. frames extracted from a few seconds of camera
  video in the Flutter app), not a set of unrelated photos.
- **Dukcapil confirmation is currently a stub** — this project has no real
  Dukcapil API credential. `dukcapil.confirm_identity()` in
  [app/services/kyc/dukcapil.py](app/services/kyc/dukcapil.py) always echoes
  the OCR-extracted identity back as `MATCHED` (marked `source: "STUB"` in
  the response) rather than performing a real registry check. Likewise,
  **OCR field parsing is a best-effort layout reader** for Indonesian
  KTP/SIM/STNK formats, not a certified Korlantas integration — if a required
  field can't be read off the photo, the endpoint fails loudly (`422`/`503`)
  instead of guessing. A synthetic test KTP with OCR-friendly text is at
  [tests/fixtures/sample_ktp.jpg](tests/fixtures/sample_ktp.jpg) (regenerate
  via `tests/fixtures/generate_ktp_fixture.py`) for exercising the parser
  without a real ID.

Requires the Tesseract OCR binary (see Requirements above).

The production client for this endpoint is a Flutter mobile app (captures
the live selfie burst from the device camera) — not yet in this repo. The
sibling [`testing/`](../testing) folder is a small Svelte web harness for
manually exercising `/kyc/verify` against a browser camera in the
meantime; it is not the product frontend.
