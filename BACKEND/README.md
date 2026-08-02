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

```powershell
uvicorn app.main:app --reload
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

One-shot driver KYC: a live KTP/SIM photo + a live selfie (+ optional STNK
photo) are decoded in memory, run through face detection/matching, a
liveness heuristic, and OCR, then discarded — nothing is written to disk or
persisted. See [docs/API.md](docs/API.md#kyc) for the full payload/response
shape and business rules (SIM expiry, vehicle age, geofence, etc).

Two honesty constraints worth knowing before relying on this in production:

- **Face match / liveness are classical OpenCV heuristics** (histogram +
  ORB keypoint correlation; sharpness + frequency-domain analysis), not a
  deep-learning face embedding or a multi-frame anti-spoofing model. They're
  fully offline and explainable, but not biometric-grade — swap in a proper
  face-recognition/liveness SDK before trusting this for real fraud
  prevention.
- **OCR field parsing is a best-effort layout reader** for Indonesian
  KTP/SIM/STNK formats, not a certified Dukcapil/Korlantas integration. If a
  required field can't be read off the photo, the endpoint fails loudly
  (`422`/`503`) instead of guessing.

Requires the Tesseract OCR binary (see Requirements above).
