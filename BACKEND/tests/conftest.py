import pytest
from fastapi.testclient import TestClient

from BACKEND.app.core.config import settings
from BACKEND.app.main import app
from BACKEND.app.services.trip_service import trip_service

API = settings.api_v1_prefix


@pytest.fixture
def client() -> TestClient:
    trip_service.clear()
    with TestClient(app) as c:
        yield c
    trip_service.clear()


@pytest.fixture
def sample_trip() -> dict:
    return {
        "title": "Weekend in Bandung",
        "destination": "Bandung, Indonesia",
        "start_date": "2026-09-12",
        "end_date": "2026-09-14",
        "notes": "Bring a jacket.",
    }
