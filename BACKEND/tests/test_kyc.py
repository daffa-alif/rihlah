import json
from datetime import date, timedelta

import cv2
import numpy as np
import pytest

from BACKEND.app.services.kyc import validation

API_KYC = "/api/v1/kyc/verify"


def _tiny_jpeg() -> bytes:
    image = np.full((120, 120, 3), 200, dtype=np.uint8)
    ok, buf = cv2.imencode(".jpg", image)
    assert ok
    return buf.tobytes()


@pytest.fixture
def valid_payload() -> dict:
    return {
        "document_type": "KTP",
        "claimed_identity": {
            "nik": "3173015505990001",
            "full_name": "Budi Santoso",
            "date_of_birth": "1999-05-15",
        },
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


# --- Endpoint-level tests ---------------------------------------------------


def test_verify_rejects_unsupported_content_type(client, valid_payload):
    files = {
        "id_document_photo": ("id.txt", b"not an image", "text/plain"),
        "selfie_photo": ("selfie.jpg", _tiny_jpeg(), "image/jpeg"),
    }
    resp = client.post(API_KYC, data={"payload": json.dumps(valid_payload)}, files=files)
    assert resp.status_code == 415
    assert resp.json()["error"]["code"] == "unsupported_media_type"


def test_verify_rejects_malformed_payload_json(client):
    files = {
        "id_document_photo": ("id.jpg", _tiny_jpeg(), "image/jpeg"),
        "selfie_photo": ("selfie.jpg", _tiny_jpeg(), "image/jpeg"),
    }
    resp = client.post(API_KYC, data={"payload": "{not valid json"}, files=files)
    assert resp.status_code == 422
    assert resp.json()["error"]["code"] == "validation_error"


def test_verify_requires_payload_field(client):
    files = {
        "id_document_photo": ("id.jpg", _tiny_jpeg(), "image/jpeg"),
        "selfie_photo": ("selfie.jpg", _tiny_jpeg(), "image/jpeg"),
    }
    resp = client.post(API_KYC, files=files)
    assert resp.status_code == 422


def test_verify_requires_vehicle_details_without_stnk_photo(client, valid_payload):
    valid_payload["claimed_vehicle"] = {
        "plate_number": "B 1234 XYZ",
        "vehicle_type": "MOTOR",
    }
    files = {
        "id_document_photo": ("id.jpg", _tiny_jpeg(), "image/jpeg"),
        "selfie_photo": ("selfie.jpg", _tiny_jpeg(), "image/jpeg"),
    }
    resp = client.post(API_KYC, data={"payload": json.dumps(valid_payload)}, files=files)
    assert resp.status_code == 422
    assert "stnk_photo" in resp.json()["error"]["message"]


def test_verify_surfaces_missing_ocr_engine_honestly(client, valid_payload):
    """This sandbox has no Tesseract binary installed. The service must
    report that plainly (503) instead of fabricating extracted document data."""
    files = {
        "id_document_photo": ("id.jpg", _tiny_jpeg(), "image/jpeg"),
        "selfie_photo": ("selfie.jpg", _tiny_jpeg(), "image/jpeg"),
    }
    resp = client.post(API_KYC, data={"payload": json.dumps(valid_payload)}, files=files)
    assert resp.status_code == 503
    assert resp.json()["error"]["code"] == "service_unavailable"
