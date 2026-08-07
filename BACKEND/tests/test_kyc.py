import json
from datetime import date, timedelta
from pathlib import Path

import cv2
import numpy as np
import pytest
import pytesseract

from BACKEND.app.core.config import settings
from BACKEND.app.services.kyc import validation

API_KYC = "/api/v1/kyc/verify"
FIXTURES_DIR = Path(__file__).parent / "fixtures"


def _tiny_jpeg() -> bytes:
    image = np.full((120, 120, 3), 200, dtype=np.uint8)
    ok, buf = cv2.imencode(".jpg", image)
    assert ok
    return buf.tobytes()


def _selfie_frame_files(count: int | None = None) -> list[tuple[str, tuple]]:
    """`count` frames of the same tiny image, as (field_name, file_tuple)
    pairs suitable for passing straight into httpx's `files=[...]` list
    form — repeated 'selfie_frames' entries, the way a real multi-frame
    burst upload would look."""
    n = settings.kyc_min_liveness_frames if count is None else count
    frame = _tiny_jpeg()
    return [
        ("selfie_frames", (f"frame{i}.jpg", frame, "image/jpeg")) for i in range(n)
    ]


def _tesseract_available() -> bool:
    try:
        pytesseract.get_tesseract_version()
        return True
    except Exception:
        return False


@pytest.fixture
def valid_payload() -> dict:
    return {
        "document_type": "KTP",
        "claimed_vehicle": {
            "plate_number": "B 1234 XYZ",
            "vehicle_type": "MOTOR",
            "brand": "Honda",
            "model": "Vario 160",
            "year": 2021,
        },
        "device": {
            "device_id": "device-fingerprint-abc123",
            "location": {"latitude": -6.2, "longitude": 106.8},
        },
    }


# --- Pure business-rule unit tests (no image/OCR dependency) --------------


def test_names_match_allows_minor_typos():
    assert validation.names_match("Budi Santoso", "budi  santoso")
    assert not validation.names_match("Budi Santoso", "Andi Wijaya")


def test_calculate_age():
    today = date(2026, 8, 1)
    assert validation.calculate_age(date(2000, 8, 1), on=today) == 26
    assert validation.calculate_age(date(2000, 8, 2), on=today) == 25


def test_parse_nik_decodes_dob_and_gender():
    # DDMMYY = 150599 -> 1999-05-15, male (day <= 40)
    dob, gender = validation.parse_nik("3173011505990001")
    assert dob == date(1999, 5, 15)
    assert gender == "LAKI_LAKI"

    # +40 on the day encodes female
    dob, gender = validation.parse_nik("3173015505990001")
    assert dob == date(1999, 5, 15)
    assert gender == "PEREMPUAN"


def test_parse_nik_rejects_malformed_input():
    assert validation.parse_nik("123") == (None, None)
    assert validation.parse_nik("31730199999900") == (None, None)


@pytest.mark.parametrize(
    "plate,expected",
    [
        ("B 1234 XYZ", True),
        ("D1A", True),
        ("B1234XYZ", True),
        ("TOOLONGPLATE1234", False),
        ("", False),
    ],
)
def test_plate_format(plate: str, expected: bool):
    assert validation.is_valid_plate_format(plate) is expected


def test_sim_expiry_status_rejects_expiring_soon():
    today = date(2026, 8, 1)
    acceptable, days = validation.sim_expiry_status(today + timedelta(days=10), on=today)
    assert not acceptable
    assert days == 10

    acceptable, days = validation.sim_expiry_status(today + timedelta(days=90), on=today)
    assert acceptable


def test_sim_class_matches_vehicle():
    from BACKEND.app.schemas.kyc import SimClass, VehicleType

    assert validation.sim_class_matches_vehicle(SimClass.C, VehicleType.MOTOR)
    assert not validation.sim_class_matches_vehicle(SimClass.C, VehicleType.MOBIL)
    assert validation.sim_class_matches_vehicle(SimClass.A, VehicleType.MOBIL)


def test_vehicle_age_acceptable():
    today = date(2026, 8, 1)
    assert validation.vehicle_age_acceptable(2020, on=today)
    assert not validation.vehicle_age_acceptable(2010, on=today)


def test_within_service_area_defaults_cover_indonesia():
    assert validation.within_service_area(-6.2, 106.8)  # Jakarta
    assert not validation.within_service_area(40.7, -74.0)  # New York


# --- Multi-frame liveness (pure, no OCR dependency) -------------------------


def test_analyze_liveness_frames_on_faceless_frames_reports_no_face():
    from BACKEND.app.services.kyc import vision

    blank = np.full((200, 200, 3), 200, dtype=np.uint8)
    result = vision.analyze_liveness_frames([blank] * settings.kyc_min_liveness_frames)

    assert result.frames_received == settings.kyc_min_liveness_frames
    assert result.frames_with_face == 0
    assert result.blink_detected is False
    assert result.best_face_crop is None


# --- Endpoint-level tests ---------------------------------------------------


def test_verify_rejects_unsupported_content_type(client, valid_payload):
    files = [
        ("id_document_photo", ("id.txt", b"not an image", "text/plain")),
        *_selfie_frame_files(),
    ]
    resp = client.post(API_KYC, data={"payload": json.dumps(valid_payload)}, files=files)
    assert resp.status_code == 415
    assert resp.json()["error"]["code"] == "unsupported_media_type"


def test_verify_rejects_malformed_payload_json(client):
    files = [
        ("id_document_photo", ("id.jpg", _tiny_jpeg(), "image/jpeg")),
        *_selfie_frame_files(),
    ]
    resp = client.post(API_KYC, data={"payload": "{not valid json"}, files=files)
    assert resp.status_code == 422
    assert resp.json()["error"]["code"] == "validation_error"


def test_verify_requires_payload_field(client):
    files = [
        ("id_document_photo", ("id.jpg", _tiny_jpeg(), "image/jpeg")),
        *_selfie_frame_files(),
    ]
    resp = client.post(API_KYC, files=files)
    assert resp.status_code == 422


def test_verify_requires_vehicle_details_without_stnk_photo(client, valid_payload):
    valid_payload["claimed_vehicle"] = {
        "plate_number": "B 1234 XYZ",
        "vehicle_type": "MOTOR",
    }
    files = [
        ("id_document_photo", ("id.jpg", _tiny_jpeg(), "image/jpeg")),
        *_selfie_frame_files(),
    ]
    resp = client.post(API_KYC, data={"payload": json.dumps(valid_payload)}, files=files)
    assert resp.status_code == 422
    assert "stnk_photo" in resp.json()["error"]["message"]


def test_verify_rejects_too_few_selfie_frames(client, valid_payload):
    files = [
        ("id_document_photo", ("id.jpg", _tiny_jpeg(), "image/jpeg")),
        *_selfie_frame_files(settings.kyc_min_liveness_frames - 1),
    ]
    resp = client.post(API_KYC, data={"payload": json.dumps(valid_payload)}, files=files)
    assert resp.status_code == 422
    assert "selfie_frames" in resp.json()["error"]["message"]


def test_verify_surfaces_missing_ocr_engine_honestly(client, valid_payload):
    """This sandbox has no Tesseract binary installed. The service must
    report that plainly (503) instead of fabricating extracted document data."""
    if _tesseract_available():
        pytest.skip("Tesseract is installed in this environment; 503 path not reachable.")
    files = [
        ("id_document_photo", ("id.jpg", _tiny_jpeg(), "image/jpeg")),
        *_selfie_frame_files(),
    ]
    resp = client.post(API_KYC, data={"payload": json.dumps(valid_payload)}, files=files)
    assert resp.status_code == 503
    assert resp.json()["error"]["code"] == "service_unavailable"


@pytest.mark.skipif(not _tesseract_available(), reason="Tesseract OCR is not installed")
def test_verify_reads_ktp_fixture_and_confirms_via_dukcapil_stub(client, valid_payload):
    """End-to-end OCR + Dukcapil-stub check against the synthetic KTP fixture
    (see tests/fixtures/generate_ktp_fixture.py). Only runs where Tesseract
    is actually installed."""
    ktp_bytes = (FIXTURES_DIR / "sample_ktp.jpg").read_bytes()
    files = [
        ("id_document_photo", ("ktp.jpg", ktp_bytes, "image/jpeg")),
        *_selfie_frame_files(),
    ]
    resp = client.post(API_KYC, data={"payload": json.dumps(valid_payload)}, files=files)
    assert resp.status_code == 200
    body = resp.json()

    assert body["ktp"]["nik"] == "3173011505990001"
    assert body["ktp"]["full_name"] == "BUDI SANTOSO"
    assert body["ktp"]["date_of_birth"] == "1999-05-15"

    assert body["dukcapil"]["status"] == "MATCHED"
    assert body["dukcapil"]["source"] == "STUB"
    assert body["dukcapil"]["nik"] == "3173011505990001"
